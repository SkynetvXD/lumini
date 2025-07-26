// lib/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firestore_service.dart';
import 'patient_auth_service.dart';
import 'auth_service.dart';
import '../models/learner.dart';
import '../models/training_stats.dart';

enum SyncStatus { idle, syncing, success, error, offline }

class SyncService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static Timer? _syncTimer;
  
  static bool _isOnline = false;
  static bool _isInitialized = false;
  static SyncStatus _status = SyncStatus.idle;
  static String? _lastError;
  static DateTime? _lastSyncTime;
  
  // Stream controllers para UI reagir às mudanças
  static final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast();
  static final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  
  static const bool _debugMode = kDebugMode;
  static const Duration _syncInterval = Duration(minutes: 3);

  static void _log(String message) {
    if (_debugMode) {
      print('🔄 SyncService: $message');
    }
  }

  // 🚀 INICIALIZAÇÃO

  /// Inicializar serviço de sincronização
  static Future<void> initialize() async {
    if (_isInitialized) {
      _log('SyncService já inicializado');
      return;
    }

    try {
      _log('Inicializando SyncService...');
      
      // Verificar conectividade inicial
      await _checkConnectivity();
      
      // Configurar listeners
      _setupConnectivityListener();
      
      // Tentar sincronização inicial se estiver online
      if (_isOnline) {
        _scheduleSync();
      }
      
      // Iniciar timer de sincronização periódica
      _startPeriodicSync();
      
      _isInitialized = true;
      _log('SyncService inicializado com sucesso');
    } catch (e) {
      _log('ERRO na inicialização: $e');
      _updateStatus(SyncStatus.error, 'Erro na inicialização: $e');
    }
  }

  /// Configurar listener de conectividade
  static void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      _log('Conectividade mudou: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      _connectivityController.add(_isOnline);
      
      // Se voltou online, fazer sync imediatamente
      if (!wasOnline && _isOnline) {
        _log('Reconectado - iniciando sincronização');
        _scheduleSync();
      }
      
      // Se ficou offline, atualizar status
      if (wasOnline && !_isOnline) {
        _updateStatus(SyncStatus.offline);
      }
    });
  }

  /// Verificar conectividade atual
  static Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      _log('Status de conectividade: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      
      // Verificar se Firestore está realmente acessível
      if (_isOnline) {
        _isOnline = await FirestoreService.isAvailable();
        _log('Firestore disponível: $_isOnline');
      }
    } catch (e) {
      _log('ERRO ao verificar conectividade: $e');
      _isOnline = false;
    }
  }

  /// Iniciar sincronização periódica
  static void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_isOnline && _status != SyncStatus.syncing) {
        _log('Timer de sincronização ativado');
        _scheduleSync();
      }
    });
  }

  // 🔄 SINCRONIZAÇÃO

  /// Agendar sincronização (não bloqueia)
  static void _scheduleSync() {
    if (_status == SyncStatus.syncing) {
      _log('Sincronização já em andamento, pulando');
      return;
    }

    // Executar sync em background
    Future.microtask(() => _performFullSync());
  }

  /// Sincronização manual (aguarda conclusão)
  static Future<bool> syncNow() async {
    if (!_isOnline) {
      _log('Tentativa de sync manual sem conexão');
      _updateStatus(SyncStatus.offline);
      return false;
    }

    if (_status == SyncStatus.syncing) {
      _log('Sincronização já em andamento');
      return false;
    }

    try {
      await _performFullSync();
      return _status == SyncStatus.success;
    } catch (e) {
      _log('ERRO no sync manual: $e');
      return false;
    }
  }

  /// Executar sincronização completa
  static Future<void> _performFullSync() async {
    if (!_isOnline) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    _updateStatus(SyncStatus.syncing);
    
    try {
      _log('=== INICIANDO SINCRONIZAÇÃO COMPLETA ===');
      
      // 1. Sync de terapeutas
      await _syncTherapistData();
      
      // 2. Sync de pacientes
      await _syncPatientsData();
      
      // 3. Sync de progresso dos treinos
      await _syncTrainingData();
      
      // 4. Criar backup local
      await _createLocalBackup();
      
      _lastSyncTime = DateTime.now();
      _updateStatus(SyncStatus.success);
      
      _log('=== SINCRONIZAÇÃO CONCLUÍDA COM SUCESSO ===');
    } catch (e) {
      _log('=== ERRO NA SINCRONIZAÇÃO: $e ===');
      _updateStatus(SyncStatus.error, e.toString());
    }
  }

  /// Sincronizar dados do terapeuta
  static Future<void> _syncTherapistData() async {
    try {
      final therapistData = await AuthService.getTherapistData();
      if (therapistData != null) {
        _log('Sincronizando dados do terapeuta: ${therapistData['name']}');
        
        await FirestoreService.createOrUpdateTherapistProfile(therapistData);
        await FirestoreService.updateTherapistLastAccess(therapistData['uid']);
        
        _log('Dados do terapeuta sincronizados');
      }
    } catch (e) {
      _log('ERRO ao sincronizar terapeuta: $e');
      // Não interromper sync por erro de terapeuta
    }
  }

  /// Sincronizar dados de pacientes
  static Future<void> _syncPatientsData() async {
    try {
      // Verificar se é paciente autenticado
      final isPatientLoggedIn = await PatientAuthService.isPatientLoggedIn();
      if (isPatientLoggedIn) {
        final patient = await PatientAuthService.getPatientData();
        if (patient != null && patient.therapistId != null) {
          _log('Sincronizando dados do paciente: ${patient.name}');
          
          await FirestoreService.updatePatientLastAccess(
            patient.therapistId!,
            patient.id,
          );
          
          _log('Dados do paciente sincronizados');
        }
      }
      
      // Migrar dados locais se necessário
      await _migrateLocalDataIfNeeded();
    } catch (e) {
      _log('ERRO ao sincronizar pacientes: $e');
    }
  }

  /// Sincronizar dados de treinos
  static Future<void> _syncTrainingData() async {
    try {
      // Verificar se há dados de treino pendentes para sincronizar
      final pendingData = await _getPendingTrainingData();
      
      if (pendingData.isNotEmpty) {
        _log('Sincronizando ${pendingData.length} sessões de treino pendentes');
        
        for (final sessionData in pendingData) {
          await _syncTrainingSession(sessionData);
        }
        
        // Limpar dados pendentes após sincronização
        await _clearPendingTrainingData();
        
        _log('Dados de treino sincronizados');
      }
    } catch (e) {
      _log('ERRO ao sincronizar treinos: $e');
    }
  }

  /// Sincronizar sessão de treino específica
  static Future<void> _syncTrainingSession(Map<String, dynamic> sessionData) async {
    try {
      final patient = await PatientAuthService.getPatientData();
      if (patient != null && patient.therapistId != null) {
        final stats = TrainingStats(
          successes: sessionData['successes'],
          errors: sessionData['errors'],
          totalAttempts: sessionData['totalAttempts'],
          date: DateTime.parse(sessionData['date']),
        );
        
        await FirestoreService.saveTrainingSession(
          therapistId: patient.therapistId!,
          patientId: patient.id,
          trainingType: sessionData['trainingType'],
          stats: stats,
        );
      }
    } catch (e) {
      _log('ERRO ao sincronizar sessão de treino: $e');
      // Não remove da fila se houver erro
      rethrow;
    }
  }

  // 📦 BACKUP LOCAL

  /// Criar backup local dos dados Firestore
  static Future<void> _createLocalBackup() async {
    try {
      final patient = await PatientAuthService.getPatientData();
      if (patient != null && patient.therapistId != null) {
        _log('Criando backup local dos dados Firestore');
        
        // Baixar progresso do Firestore
        final progress = await FirestoreService.getPatientProgress(
          patient.therapistId!,
          patient.id,
        );
        
        // Baixar sessões recentes
        final sessions = await FirestoreService.getTrainingSessions(
          patient.therapistId!,
          patient.id,
          limit: 100,
        );
        
        // Salvar backup local
        final prefs = await SharedPreferences.getInstance();
        final backup = {
          'timestamp': DateTime.now().toIso8601String(),
          'patientId': patient.id,
          'therapistId': patient.therapistId,
          'progress': progress,
          'sessions': sessions,
        };
        
        await prefs.setString('firestore_backup', jsonEncode(backup));
        _log('Backup local criado com sucesso');
      }
    } catch (e) {
      _log('ERRO ao criar backup local: $e');
    }
  }

  // 🔄 MIGRAÇÃO DE DADOS

  /// Migrar dados locais para Firestore se necessário
  static Future<void> _migrateLocalDataIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationCompleted = prefs.getBool('migration_completed') ?? false;
      
      if (!migrationCompleted) {
        _log('Iniciando migração de dados locais para Firestore');
        await _migrateLocalData();
        await prefs.setBool('migration_completed', true);
        _log('Migração concluída');
      }
    } catch (e) {
      _log('ERRO na migração: $e');
    }
  }

  /// Executar migração de dados locais
  static Future<void> _migrateLocalData() async {
    // Implementar migração específica dos dados existentes
    // Por enquanto, apenas marcar como migrado
    _log('Migração de dados locais executada');
  }

  // 📊 DADOS PENDENTES

  /// Adicionar dados de treino à fila de sincronização
  static Future<void> addPendingTrainingData({
    required String trainingType,
    required TrainingStats stats,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingList = prefs.getStringList('pending_training_data') ?? [];
      
      final sessionData = {
        'trainingType': trainingType,
        'successes': stats.successes,
        'errors': stats.errors,
        'totalAttempts': stats.totalAttempts,
        'date': DateTime.now().toIso8601String(),
        'synced': false,
      };
      
      pendingList.add(jsonEncode(sessionData));
      await prefs.setStringList('pending_training_data', pendingList);
      
      _log('Dados de treino adicionados à fila: $trainingType');
      
      // Tentar sincronizar imediatamente se estiver online
      if (_isOnline) {
        _scheduleSync();
      }
    } catch (e) {
      _log('ERRO ao adicionar dados pendentes: $e');
    }
  }

  /// Obter dados de treino pendentes
  static Future<List<Map<String, dynamic>>> _getPendingTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingList = prefs.getStringList('pending_training_data') ?? [];
      
      return pendingList.map((jsonString) {
        return Map<String, dynamic>.from(jsonDecode(jsonString));
      }).toList();
    } catch (e) {
      _log('ERRO ao obter dados pendentes: $e');
      return [];
    }
  }

  /// Limpar dados pendentes após sincronização
  static Future<void> _clearPendingTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_training_data');
      _log('Dados pendentes limpos');
    } catch (e) {
      _log('ERRO ao limpar dados pendentes: $e');
    }
  }

  // 📱 STATUS E CONTROLE

  /// Atualizar status da sincronização
  static void _updateStatus(SyncStatus status, [String? error]) {
    _status = status;
    _lastError = error;
    _statusController.add(status);
    
    _log('Status atualizado: $status ${error != null ? "- $error" : ""}');
  }

  // 📡 GETTERS E STREAMS

  /// Status atual da conectividade
  static bool get isOnline => _isOnline;
  
  /// Status atual da sincronização
  static SyncStatus get status => _status;
  
  /// Último erro ocorrido
  static String? get lastError => _lastError;
  
  /// Última vez que sincronizou
  static DateTime? get lastSyncTime => _lastSyncTime;
  
  /// Stream de mudanças de status
  static Stream<SyncStatus> get statusStream => _statusController.stream;
  
  /// Stream de mudanças de conectividade
  static Stream<bool> get connectivityStream => _connectivityController.stream;

  // 🛠️ UTILITÁRIOS

  /// Forçar verificação de conectividade
  static Future<void> checkConnectivity() async {
    await _checkConnectivity();
    _connectivityController.add(_isOnline);
  }

  /// Obter informações de debug
  static Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'isOnline': _isOnline,
      'status': _status.toString(),
      'lastError': _lastError,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
    };
  }

  // 🧹 CLEANUP

  /// Limpar recursos
  static void dispose() {
    _log('Finalizando SyncService');
    
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _statusController.close();
    _connectivityController.close();
    
    _isInitialized = false;
  }
}