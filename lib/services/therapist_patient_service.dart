// lib/services/therapist_patient_service_hybrid.dart
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/learner.dart';
import 'firestore_service.dart';
import 'sync_service.dart';
import 'auth_service.dart';
import 'native_auth_service.dart';

class TherapistPatientService {
  static const String _patientsKey = 'therapist_patients';
  static const String _backupKey = 'therapist_patients_backup';
  static const int maxPatientsPerTherapist = 10;
  static const bool _debugMode = kDebugMode;

  static void _log(String message) {
    if (_debugMode) {
      print('🏥 TherapistPatientService: $message');
    }
  }

  // 🔄 ESTRATÉGIA HÍBRIDA

  /// Determinar se deve usar Firestore ou dados locais
  static Future<bool> _shouldUseFirestore() async {
    if (!SyncService.isOnline) return false;
    
    try {
      final therapistData = await AuthService.getTherapistData();
      final isLoggedIn = await AuthService.isTherapistLoggedIn();
      return therapistData != null && isLoggedIn;
    } catch (e) {
      return false;
    }
  }

  /// Obter ID do terapeuta atual
  static Future<String?> _getCurrentTherapistId() async {
  try {
    // 1. Tentar dados nativos primeiro
    final nativeData = await NativeAuthService.getTherapistDataNative();
    if (nativeData != null) {
      _log('TherapistId obtido via dados nativos: ${nativeData['uid']}');
      return nativeData['uid'];
    }
    
    // 2. Fallback para dados Google
    final googleData = await AuthService.getTherapistData();
    if (googleData != null) {
      _log('TherapistId obtido via dados Google: ${googleData['uid']}');
      return googleData['uid'];
    }
    
    _log('ERRO: Nenhum therapistId encontrado');
    return null;
  } catch (e) {
    _log('ERRO ao obter therapistId: $e');
    return null;
  }
}

  // 👥 GESTÃO DE PACIENTES (HÍBRIDO)

  /// Obter todos os pacientes Gmail de um terapeuta
static Future<List<Learner>> getPatientsByTherapist(String therapistId) async {
  _log('Obtendo pacientes para terapeuta: $therapistId');

  List<Learner> allPatients = [];

  // 1. Tentar obter do Firestore primeiro
  if (await _shouldUseFirestore()) {
    try {
      final firestorePatients = await FirestoreService.getTherapistPatients(therapistId);
      allPatients.addAll(firestorePatients);
      _log('${firestorePatients.length} pacientes do Firestore encontrados');
    } catch (e) {
      _log('ERRO ao obter pacientes do Firestore: $e');
    }
  }

  // 2. Obter pacientes locais
  try {
    final localPatients = await _getLocalPatients(therapistId);
    for (final localPatient in localPatients) {
      // Verificar duplicatas por email
      bool isDuplicate = allPatients.any((existing) =>
          existing.email?.toLowerCase() == localPatient.email?.toLowerCase());
      if (!isDuplicate) {
        allPatients.add(localPatient);
        _log('Paciente local adicionado: ${localPatient.name}');
      } else {
        _log('Paciente local já existe: ${localPatient.name}');
      }
    }
  } catch (e) {
    _log('ERRO ao obter pacientes locais: $e');
  }

  // 3. 🆕 INCLUIR PACIENTES NATIVOS
  try {
    final nativePatientsData = NativeAuthService.getNativePatientsForTherapist(therapistId);
    _log('${nativePatientsData.length} pacientes nativos encontrados');

    for (final nativePatientData in nativePatientsData) {
      // Converter dados nativos para Learner
      final nativePatient = Learner.fromMap(nativePatientData);

      // Verificar duplicatas por email
      bool isDuplicate = allPatients.any((existing) =>
          existing.email?.toLowerCase() == nativePatient.email?.toLowerCase());

      if (!isDuplicate) {
        allPatients.add(nativePatient);
        _log('Paciente nativo adicionado: ${nativePatient.name}');
      } else {
        _log('Paciente nativo já existe: ${nativePatient.name}');
      }
    }
  } catch (e) {
    _log('ERRO ao obter pacientes nativos: $e');
  }

  _log('TOTAL: ${allPatients.length} pacientes (Firestore + Local + Nativos)');
  return allPatients;
}

  /// Adicionar um novo paciente Gmail
  static Future<bool> addPatient(Learner patient) async {
    _log('Adicionando paciente: ${patient.email}');

    if (!patient.isAuthenticated || patient.therapistId == null) {
      _log('ERRO: Paciente inválido - não autenticado ou sem therapistId');
      return false;
    }

    final therapistId = patient.therapistId!;
    bool firestoreSuccess = false;
    bool localSuccess = false;

    // 1. Tentar adicionar no Firestore primeiro
    if (await _shouldUseFirestore()) {
      try {
        final patientId = await FirestoreService.addGmailPatient(
          therapistId: therapistId,
          email: patient.email!,
          name: patient.name,
          birthDate: patient.birthDate,
          diagnosis: patient.diagnosis,
        );
        
        // Atualizar o ID do paciente se necessário
        if (patientId != patient.id) {
          patient = patient.copyWith(id: patientId);
        }
        
        firestoreSuccess = true;
        _log('Paciente adicionado no Firestore com sucesso');
      } catch (e) {
        _log('ERRO no Firestore: $e');
        if (e.toString().contains('Limite de')) {
          rethrow; // Repassar erro de limite
        }
        if (e.toString().contains('já cadastrado')) {
          rethrow; // Repassar erro de duplicação
        }
      }
    }

    // 2. SEMPRE salvar localmente também (backup)
    try {
      localSuccess = await _addLocalPatient(therapistId, patient);
      if (localSuccess) {
        _log('Paciente salvo localmente como backup');
      }
    } catch (e) {
      _log('ERRO ao salvar localmente: $e');
    }

    return firestoreSuccess || localSuccess;
  }

  /// Atualizar um paciente existente
  static Future<bool> updatePatient(Learner patient) async {
    _log('Atualizando paciente: ${patient.id}');

    if (!patient.isAuthenticated || patient.therapistId == null) {
      _log('ERRO: Paciente inválido para atualização');
      return false;
    }

    final therapistId = patient.therapistId!;
    bool firestoreSuccess = false;
    bool localSuccess = false;

    // 1. Tentar atualizar no Firestore
    if (await _shouldUseFirestore()) {
      try {
        await FirestoreService.updatePatientLastAccess(therapistId, patient.id);
        firestoreSuccess = true;
        _log('Paciente atualizado no Firestore');
      } catch (e) {
        _log('ERRO ao atualizar no Firestore: $e');
      }
    }

    // 2. Sempre atualizar localmente
    try {
      localSuccess = await _updateLocalPatient(therapistId, patient);
    } catch (e) {
      _log('ERRO ao atualizar localmente: $e');
    }

    return firestoreSuccess || localSuccess;
  }

  /// Remover um paciente (desativar)
  static Future<bool> removePatient(String patientId) async {
    _log('Removendo paciente: $patientId');

    // Buscar o paciente primeiro
    final patient = await getPatientById(patientId);
    if (patient == null) {
      _log('ERRO: Paciente não encontrado: $patientId');
      return false;
    }

    final therapistId = patient.therapistId!;
    bool firestoreSuccess = false;
    bool localSuccess = false;

    // 1. Tentar remover do Firestore
    if (await _shouldUseFirestore()) {
      try {
        await FirestoreService.removePatient(therapistId, patientId);
        firestoreSuccess = true;
        _log('Paciente removido do Firestore');
      } catch (e) {
        _log('ERRO ao remover do Firestore: $e');
      }
    }

    // 2. Sempre remover localmente
    try {
      localSuccess = await _removeLocalPatient(therapistId, patientId);
    } catch (e) {
      _log('ERRO ao remover localmente: $e');
    }

    return firestoreSuccess || localSuccess;
  }

  /// Obter paciente por email
  static Future<Learner?> getPatientByEmail(String email) async {
    _log('Buscando paciente por email: $email');

    // 1. Tentar buscar no Firestore primeiro
    if (await _shouldUseFirestore()) {
      try {
        final firestorePatient = await FirestoreService.getPatientByEmail(email);
        if (firestorePatient != null) {
          _log('Paciente encontrado no Firestore');
          return firestorePatient;
        }
      } catch (e) {
        _log('ERRO ao buscar no Firestore: $e');
      }
    }

    // 2. Buscar nos dados locais
    try {
      return await _getLocalPatientByEmail(email);
    } catch (e) {
      _log('ERRO ao buscar localmente: $e');
      return null;
    }
  }

  /// Obter paciente por ID
  static Future<Learner?> getPatientById(String patientId) async {
    _log('Buscando paciente por ID: $patientId');

    // 1. Tentar buscar no Firestore
    if (await _shouldUseFirestore()) {
      try {
        final therapistId = await _getCurrentTherapistId();
        if (therapistId != null) {
          final patients = await FirestoreService.getTherapistPatients(therapistId);
          final patient = patients.firstWhere(
            (p) => p.id == patientId,
            orElse: () => throw Exception('Patient not found'),
          );
          _log('Paciente encontrado no Firestore por ID');
          return patient;
        }
      } catch (e) {
        _log('ERRO ao buscar no Firestore por ID: $e');
      }
    }

    // 2. Buscar nos dados locais
    return await _getLocalPatientById(patientId);
  }

  /// Convidar paciente (versão híbrida)
  static Future<Map<String, String>> invitePatient({
    required String email,
    required String name,
    required String therapistId,
    DateTime? birthDate,
    String? diagnosis,
  }) async {
    _log('Convidando paciente: $email para terapeuta: $therapistId');

    // 1. Tentar usar Firestore primeiro
    if (await _shouldUseFirestore()) {
      try {
        final patientId = await FirestoreService.addGmailPatient(
          therapistId: therapistId,
          email: email,
          name: name,
          birthDate: birthDate,
          diagnosis: diagnosis,
        );

        return {
          'patientId': patientId,
          'email': email,
          'inviteMessage': 'Paciente $name foi registrado com sucesso no sistema!\n\n'
              'Instruções para o paciente:\n'
              '1. Fazer login no app Lumimi\n'
              '2. Escolher "Paciente"\n'
              '3. Entrar com a conta: $email\n'
              '4. Começar os treinos!\n\n'
              'Os dados ficam sincronizados automaticamente na nuvem.',
        };
      } catch (e) {
        _log('ERRO no convite via Firestore: $e');
        if (e.toString().contains('Limite de') || e.toString().contains('já cadastrado')) {
          rethrow;
        }
      }
    }

    // 2. Fallback para método local
    return await _inviteLocalPatient(email, name, therapistId, birthDate, diagnosis);
  }

  // 📊 ESTATÍSTICAS E RELATÓRIOS

  /// Obter estatísticas do terapeuta
  static Future<Map<String, dynamic>> getTherapistStats(String therapistId) async {
    _log('Obtendo estatísticas do terapeuta: $therapistId');

    // Tentar obter do Firestore primeiro
    if (await _shouldUseFirestore()) {
      try {
        final firestoreStats = await FirestoreService.getTherapistStats(therapistId);
        if (firestoreStats.isNotEmpty) {
          _log('Estatísticas obtidas do Firestore');
          return firestoreStats;
        }
      } catch (e) {
        _log('ERRO ao obter stats do Firestore: $e');
      }
    }

    // Fallback para estatísticas locais
    return await _getLocalTherapistStats(therapistId);
  }

  /// Obter resumo de estatísticas de um paciente
  static Future<Map<String, dynamic>> getPatientSummaryStats(String patientId) async {
    _log('Obtendo resumo do paciente: $patientId');

    // Tentar obter do Firestore primeiro
    if (await _shouldUseFirestore()) {
      try {
        final therapistId = await _getCurrentTherapistId();
        if (therapistId != null) {
          // Obter sessões do Firestore
          final colorStats = await FirestoreService.getTrainingSessions(
            therapistId,
            patientId,
            trainingType: 'colors',
          );
          final shapeStats = await FirestoreService.getTrainingSessions(
            therapistId,
            patientId,
            trainingType: 'shapes',
          );
          final quantityStats = await FirestoreService.getTrainingSessions(
            therapistId,
            patientId,
            trainingType: 'quantities',
          );

          final overallProgress = await FirestoreService.getPatientProgress(
            therapistId,
            patientId,
          );

          return _calculateSummaryFromFirestore(
            patientId,
            colorStats,
            shapeStats,
            quantityStats,
            overallProgress,
          );
        }
      } catch (e) {
        _log('ERRO ao obter resumo do Firestore: $e');
      }
    }

    // Fallback para dados locais
    return await _getLocalPatientSummary(patientId);
  }

  // 🔧 UTILITÁRIOS

  /// Verificar se terapeuta pode adicionar mais pacientes
  static Future<bool> canAddMorePatients(String therapistId) async {
    if (await _shouldUseFirestore()) {
      try {
        return await FirestoreService.canAddPatient(therapistId);
      } catch (e) {
        _log('ERRO ao verificar limite no Firestore: $e');
      }
    }

    // Verificação local
    final patients = await _getLocalPatients(therapistId);
    final activeCount = patients.where((p) => p.isActive).length;
    return activeCount < maxPatientsPerTherapist;
  }

  /// Obter contagem de pacientes ativos
  static Future<int> getActivePatientCount(String therapistId) async {
    final patients = await getPatientsByTherapist(therapistId);
    return patients.where((p) => p.isActive).length;
  }

  /// Gerar um ID único para um novo paciente
  static String generateUniqueId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return 'patient_${timestamp}_$randomPart';
  }

  /// Limpar todos os dados de pacientes de um terapeuta
  static Future<bool> clearAllPatients(String therapistId) async {
    _log('Limpando todos os pacientes do terapeuta: $therapistId');

    try {
      // Limpar dados locais
      await _clearLocalPatients(therapistId);
      
      // Se online, limpar dados do Firestore seria perigoso
      // Por enquanto, apenas marcar como inativo
      if (await _shouldUseFirestore()) {
        _log('Dados do Firestore não são limpos automaticamente por segurança');
      }

      return true;
    } catch (e) {
      _log('ERRO ao limpar pacientes: $e');
      return false;
    }
  }

  // 💾 MÉTODOS LOCAIS (IMPLEMENTAÇÃO COMPLETA)

  /// Salvar backup local dos dados Firestore
  static Future<void> _saveLocalBackup(String therapistId, List<Learner> patients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_$therapistId';
      final backupKey = '${_backupKey}_$therapistId';
      
      final patientsJsonList = patients.map((p) => p.toJson()).toList();
      
      // Salvar dados principais
      await prefs.setStringList(patientsKey, patientsJsonList);
      
      // Criar backup com timestamp
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'therapistId': therapistId,
        'patientsCount': patients.length,
        'patients': patientsJsonList,
      };
      
      await prefs.setString(backupKey, jsonEncode(backupData));
      _log('Backup local criado: ${patients.length} pacientes');
    } catch (e) {
      _log('ERRO ao criar backup local: $e');
    }
  }

  /// Obter pacientes dos dados locais
  static Future<List<Learner>> _getLocalPatients(String therapistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_$therapistId';
      final patientsList = prefs.getStringList(patientsKey) ?? [];
      
      final patients = patientsList
          .map((patientJson) => Learner.fromJson(patientJson))
          .where((patient) => patient.isActive && patient.isAuthenticated)
          .toList();
      
      return patients;
    } catch (e) {
      _log('ERRO ao obter pacientes locais: $e');
      return [];
    }
  }

  /// Adicionar paciente aos dados locais
  static Future<bool> _addLocalPatient(String therapistId, Learner patient) async {
    try {
      final patients = await _getLocalPatients(therapistId);
      
      // Verificar limite
      if (patients.length >= maxPatientsPerTherapist) {
        throw Exception('Limite de $maxPatientsPerTherapist pacientes atingido');
      }
      
      // Verificar duplicação
      if (patients.any((p) => p.email?.toLowerCase() == patient.email?.toLowerCase())) {
        throw Exception('Este email já está cadastrado como paciente');
      }
      
      patients.add(patient);
      await _saveLocalBackup(therapistId, patients);
      return true;
    } catch (e) {
      _log('ERRO ao adicionar paciente local: $e');
      rethrow;
    }
  }

  /// Atualizar paciente nos dados locais
  static Future<bool> _updateLocalPatient(String therapistId, Learner patient) async {
    try {
      final patients = await _getLocalPatients(therapistId);
      final index = patients.indexWhere((p) => p.id == patient.id);
      
      if (index == -1) {
        _log('Paciente não encontrado para atualização local: ${patient.id}');
        return false;
      }
      
      patients[index] = patient;
      await _saveLocalBackup(therapistId, patients);
      return true;
    } catch (e) {
      _log('ERRO ao atualizar paciente local: $e');
      return false;
    }
  }

  /// Remover paciente dos dados locais
  static Future<bool> _removeLocalPatient(String therapistId, String patientId) async {
    try {
      final patients = await _getLocalPatients(therapistId);
      final index = patients.indexWhere((p) => p.id == patientId);
      
      if (index == -1) {
        _log('Paciente não encontrado para remoção local: $patientId');
        return false;
      }
      
      // Marcar como inativo em vez de remover
      patients[index] = patients[index].copyWith(isActive: false);
      await _saveLocalBackup(therapistId, patients);
      return true;
    } catch (e) {
      _log('ERRO ao remover paciente local: $e');
      return false;
    }
  }

  /// Buscar paciente por email nos dados locais
  static Future<Learner?> _getLocalPatientByEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (String key in keys) {
        if (key.startsWith(_patientsKey)) {
          final patientsList = prefs.getStringList(key) ?? [];
          
          for (String patientJson in patientsList) {
            try {
              final patient = Learner.fromJson(patientJson);
              if (patient.isAuthenticated && 
                  patient.email?.toLowerCase() == email.toLowerCase() && 
                  patient.isActive) {
                return patient;
              }
            } catch (e) {
              continue; // Ignorar entradas corrompidas
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      _log('ERRO ao buscar paciente local por email: $e');
      return null;
    }
  }

  /// Buscar paciente por ID nos dados locais
  static Future<Learner?> _getLocalPatientById(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (String key in keys) {
        if (key.startsWith(_patientsKey)) {
          final patientsList = prefs.getStringList(key) ?? [];
          
          for (String patientJson in patientsList) {
            try {
              final patient = Learner.fromJson(patientJson);
              if (patient.id == patientId && patient.isAuthenticated) {
                return patient;
              }
            } catch (e) {
              continue;
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      _log('ERRO ao buscar paciente local por ID: $e');
      return null;
    }
  }

  /// Convidar paciente usando dados locais
  static Future<Map<String, String>> _inviteLocalPatient(
    String email,
    String name,
    String therapistId,
    DateTime? birthDate,
    String? diagnosis,
  ) async {
    try {
      final patient = Learner.createGmailPatient(
        email: email,
        name: name,
        therapistId: therapistId,
        birthDate: birthDate,
        diagnosis: diagnosis,
      );
      
      final success = await _addLocalPatient(therapistId, patient);
      
      if (success) {
        return {
          'patientId': patient.id,
          'email': patient.email!,
          'inviteMessage': 'Paciente $name foi registrado localmente!\n\n'
              'IMPORTANTE: Os dados estão salvos apenas no dispositivo.\n'
              'Para sincronização na nuvem, é necessário conexão com internet.\n\n'
              'Instruções para o paciente:\n'
              '1. Fazer login no app Lumimi\n'
              '2. Escolher "Paciente"\n'
              '3. Entrar com a conta: ${patient.email}\n'
              '4. Começar os treinos!',
        };
      } else {
        throw Exception('Erro ao registrar paciente localmente');
      }
    } catch (e) {
      _log('ERRO no convite local: $e');
      rethrow;
    }
  }

  /// Obter estatísticas locais do terapeuta
  static Future<Map<String, dynamic>> _getLocalTherapistStats(String therapistId) async {
    try {
      final patients = await _getLocalPatients(therapistId);
      
      return {
        'totalPatients': patients.length,
        'activePatients': patients.where((p) => p.isActive).length,
        'totalSessions': 0, // Seria necessário implementar contagem local
        'lastActivity': patients.isNotEmpty 
            ? patients.map((p) => p.lastAccess).where((d) => d != null).fold<DateTime?>(
                null, (latest, date) => latest == null || date!.isAfter(latest) ? date : latest
              )?.toIso8601String()
            : null,
        'averageSessionsPerPatient': 0.0,
        'dataSource': 'local',
      };
    } catch (e) {
      _log('ERRO ao obter stats locais: $e');
      return {};
    }
  }

  /// Obter resumo local do paciente
  static Future<Map<String, dynamic>> _getLocalPatientSummary(String patientId) async {
    try {
      // Implementação básica - seria necessário expandir para incluir dados de progresso
      return {
        'patientId': patientId,
        'totalSessions': 0,
        'overallProgress': {
          'completedTrainings': 0,
          'totalStars': 0,
          'colorTrainingCompleted': false,
          'shapeTrainingCompleted': false,
          'quantityTrainingCompleted': false,
        },
        'lastActivity': null,
        'dataSource': 'local',
      };
    } catch (e) {
      _log('ERRO ao obter resumo local: $e');
      return {};
    }
  }

  /// Calcular resumo baseado nos dados do Firestore
  static Map<String, dynamic> _calculateSummaryFromFirestore(
    String patientId,
    List<Map<String, dynamic>> colorStats,
    List<Map<String, dynamic>> shapeStats,
    List<Map<String, dynamic>> quantityStats,
    Map<String, dynamic> overallProgress,
  ) {
    // Última atividade
    DateTime? lastActivity;
    final allStats = [...colorStats, ...shapeStats, ...quantityStats];
    if (allStats.isNotEmpty) {
      final dates = allStats.map((stat) => DateTime.parse(stat['date'])).toList();
      dates.sort((a, b) => b.compareTo(a));
      lastActivity = dates.first;
    }

    return {
      'patientId': patientId,
      'overallProgress': {
        'completedTrainings': overallProgress['completedTrainings'] ?? 0,
        'totalStars': overallProgress['totalStars'] ?? 0,
        'colorTrainingCompleted': overallProgress['colorsCompleted'] ?? false,
        'shapeTrainingCompleted': overallProgress['shapesCompleted'] ?? false,
        'quantityTrainingCompleted': overallProgress['quantitiesCompleted'] ?? false,
      },
      'colorTraining': _calculateTrainingSummary(colorStats),
      'shapeTraining': _calculateTrainingSummary(shapeStats),
      'quantityTraining': _calculateTrainingSummary(quantityStats),
      'lastActivity': lastActivity?.toIso8601String(),
      'totalSessions': colorStats.length + shapeStats.length + quantityStats.length,
      'dataSource': 'firestore',
    };
  }

  /// Calcular resumo de um tipo de treino
  static Map<String, dynamic> _calculateTrainingSummary(List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) {
      return {
        'totalSessions': 0,
        'averageSuccessRate': 0.0,
        'lastSession': null,
        'trend': 'stable',
      };
    }

    double totalSuccessRate = 0.0;
    for (var stat in stats) {
      totalSuccessRate += stat['successPercentage'] as double;
    }

    return {
      'totalSessions': stats.length,
      'averageSuccessRate': totalSuccessRate / stats.length,
      'lastSession': stats.last['date'],
      'trend': 'stable', // Simplificado
    };
  }

  /// Limpar dados locais de um terapeuta
  static Future<void> _clearLocalPatients(String therapistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_$therapistId';
      final backupKey = '${_backupKey}_$therapistId';
      
      await prefs.remove(patientsKey);
      await prefs.remove(backupKey);
      
      _log('Dados locais limpos para terapeuta: $therapistId');
    } catch (e) {
      _log('ERRO ao limpar dados locais: $e');
    }
  }

  // 🔧 MÉTODOS DE DEBUG E VERIFICAÇÃO

  /// Verificar integridade dos dados
  static Future<Map<String, dynamic>> verifyDataIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int totalPatients = 0;
      int corruptedEntries = 0;
      Map<String, int> therapistCounts = {};
      
      for (String key in keys) {
        if (key.startsWith(_patientsKey)) {
          final therapistId = key.replaceFirst('${_patientsKey}_', '');
          final patientsList = prefs.getStringList(key) ?? [];
          
          int validPatients = 0;
          
          for (String patientJson in patientsList) {
            try {
              final patient = Learner.fromJson(patientJson);
              if (patient.isAuthenticated && patient.isActive) {
                validPatients++;
                totalPatients++;
              }
            } catch (e) {
              corruptedEntries++;
            }
          }
          
          therapistCounts[therapistId] = validPatients;
        }
      }
      
      return {
        'totalPatients': totalPatients,
        'corruptedEntries': corruptedEntries,
        'therapistCounts': therapistCounts,
        'dataIntegrityOk': corruptedEntries == 0,
        'firestoreAvailable': await _shouldUseFirestore(),
        'syncStatus': SyncService.status.toString(),
      };
    } catch (e) {
      _log('ERRO na verificação de integridade: $e');
      return {'error': e.toString()};
    }
  }

  /// Reparar dados corrompidos
  static Future<bool> repairCorruptedData() async {
    try {
      _log('Iniciando reparo de dados corrompidos...');
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (String key in keys) {
        if (key.startsWith(_patientsKey)) {
          final patientsList = prefs.getStringList(key) ?? [];
          final validPatients = <String>[];
          
          for (String patientJson in patientsList) {
            try {
              final patient = Learner.fromJson(patientJson);
              if (patient.isAuthenticated && patient.isActive) {
                validPatients.add(patientJson);
              }
            } catch (e) {
              _log('Removendo entrada corrompida: $e');
            }
          }
          
          if (validPatients.length != patientsList.length) {
            await prefs.setStringList(key, validPatients);
            _log('Chave reparada: $key (${patientsList.length} -> ${validPatients.length})');
          }
        }
      }
      
      return true;
    } catch (e) {
      _log('ERRO no reparo: $e');
      return false;
    }
  }
}