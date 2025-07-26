// lib/services/patient_auth_service_hybrid.dart
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/learner.dart';
import 'firestore_service.dart';
import 'sync_service.dart';

class PatientAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  static const String _patientDataKey = 'patient_data';
  static const String _isPatientLoggedInKey = 'is_patient_logged_in';
  static const bool _debugMode = kDebugMode;

  static void _log(String message) {
    if (_debugMode) {
      print('👨‍⚕️ PatientAuthService: $message');
    }
  }

  // 💾 GERENCIAMENTO LOCAL DE DADOS

  /// Salvar dados do paciente logado localmente
  static Future<void> _savePatientData(Learner patient) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_patientDataKey, patient.toJson());
      await prefs.setBool(_isPatientLoggedInKey, true);
      _log('Dados do paciente salvos localmente: ${patient.email}');
    } catch (e) {
      _log('ERRO ao salvar dados do paciente: $e');
    }
  }

  /// Obter dados do paciente logado
  static Future<Learner?> getPatientData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_patientDataKey);
      
      if (dataString != null) {
        final patient = Learner.fromJson(dataString);
        _log('Dados do paciente carregados: ${patient.email}');
        return patient;
      }
      
      _log('Nenhum dado de paciente encontrado');
      return null;
    } catch (e) {
      _log('ERRO ao carregar dados do paciente: $e');
      return null;
    }
  }

  /// Verificar se paciente está logado
  static Future<bool> isPatientLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isPatientLoggedInKey) ?? false;
      
      // Verificar também se o usuário do Firebase ainda está logado
      final user = _auth.currentUser;
      
      if (isLoggedIn && user != null) {
        // Verificar se o paciente ainda está autorizado
        final patient = await getPatientData();
        if (patient != null && patient.isActive) {
          // Se estiver online, verificar se ainda existe na base do terapeuta
          if (SyncService.isOnline) {
            try {
              final existingPatient = await FirestoreService.getPatientByEmail(user.email ?? '');
              if (existingPatient != null && existingPatient.isActive) {
                _log('Paciente validado no Firestore: ${user.email}');
                return true;
              } else {
                _log('Paciente não mais autorizado no Firestore, fazendo logout');
                await signOut();
                return false;
              }
            } catch (e) {
              _log('ERRO na validação Firestore (modo offline): $e');
              // Se não conseguir validar no Firestore, continuar baseado nos dados locais
              return true;
            }
          } else {
            // Modo offline - usar dados locais
            _log('Modo offline - usando validação local');
            return true;
          }
        }
        
        _log('Paciente local inválido, fazendo logout');
        await signOut();
      }
      
      return false;
    } catch (e) {
      _log('ERRO na verificação de login: $e');
      return false;
    }
  }

  // 🔐 LOGIN E LOGOUT

  /// Login com Google para paciente - VERSÃO HÍBRIDA
  static Future<Learner?> signInWithGoogle() async {
    try {
      _log('Iniciando login de paciente...');
      
      // Deslogar primeiro para forçar seleção de conta
      await _googleSignIn.signOut();
      
      // Iniciar processo de login
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _log('Login cancelado pelo usuário');
        return null;
      }

      _log('Usuário selecionado: ${googleUser.email}');

      // Obter tokens de autenticação
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Criar credencial para Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Fazer login no Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final email = user.email!;
        _log('Login Firebase bem-sucedido: $email');
        
        // 🔒 VERIFICAÇÃO RIGOROSA: Buscar paciente no Firestore
        Learner? patient;
        
        if (SyncService.isOnline) {
          try {
            patient = await FirestoreService.getPatientByEmail(email);
            
            if (patient == null) {
              _log('ACESSO NEGADO: Email não cadastrado como paciente no Firestore');
              await signOut();
              throw Exception('🚫 ACESSO NEGADO\n\nEmail: $email\n\nEste email não está registrado como paciente.\n\nPara ter acesso:\n1. Entre em contato com seu terapeuta\n2. Solicite o cadastro do seu email\n3. Tente fazer login novamente');
            }

            if (!patient.isActive) {
              _log('ACESSO NEGADO: Paciente inativo no Firestore');
              await signOut();
              throw Exception('🚫 CONTA INATIVA\n\nSua conta de paciente está inativa.\n\nEntre em contato com seu terapeuta para reativar o acesso.');
            }

            _log('Paciente autorizado encontrado no Firestore: ${patient.name}');

            // Atualizar último acesso no Firestore
            if (patient.therapistId != null) {
              try {
                await FirestoreService.updatePatientLastAccess(
                  patient.therapistId!,
                  patient.id,
                );
                _log('Último acesso atualizado no Firestore');
              } catch (e) {
                _log('ERRO ao atualizar último acesso: $e');
              }
            }

            // Atualizar dados locais com dados do Firestore
            final updatedPatient = patient.updateLastAccess();
            await _savePatientData(updatedPatient);
            
            // Iniciar sincronização em background
            _startBackgroundSync();
            
            _log('Login de paciente concluído com sucesso');
            return updatedPatient;
          } catch (e) {
            if (e.toString().contains('ACESSO NEGADO') || e.toString().contains('CONTA INATIVA')) {
              rethrow;
            }
            
            _log('ERRO na verificação Firestore: $e');
            
            // Fallback: verificar dados locais se Firestore falhar
            final localPatient = await _validateLocalPatient(email);
            if (localPatient != null) {
              _log('Usando dados locais como fallback');
              await _savePatientData(localPatient.updateLastAccess());
              return localPatient;
            }
            
            await signOut();
            throw Exception('🚫 ERRO DE CONEXÃO\n\nNão foi possível validar seu acesso.\n\nVerifique sua conexão e tente novamente.');
          }
        } else {
          // Modo offline: usar apenas dados locais
          _log('Modo offline - verificando dados locais');
          final localPatient = await _validateLocalPatient(email);
          if (localPatient != null) {
            _log('Paciente validado localmente');
            await _savePatientData(localPatient.updateLastAccess());
            return localPatient;
          } else {
            await signOut();
            throw Exception('🚫 SEM CONEXÃO\n\nEste é seu primeiro login?\n\nVocê precisa estar conectado à internet na primeira vez.\n\nTente novamente quando tiver conexão.');
          }
        }
      }

      _log('ERRO: Usuário Firebase é null');
      return null;
    } catch (e) {
      _log('ERRO no login do paciente: $e');
      rethrow;
    }
  }

  /// Validar paciente com dados locais
  static Future<Learner?> _validateLocalPatient(String email) async {
    try {
      // Verificar se existe dados locais válidos para este email
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_patientDataKey);
      
      if (dataString != null) {
        final patient = Learner.fromJson(dataString);
        if (patient.email?.toLowerCase() == email.toLowerCase() && patient.isActive) {
          _log('Paciente local válido encontrado: ${patient.name}');
          return patient;
        }
      }
      
      _log('Nenhum paciente local válido para: $email');
      return null;
    } catch (e) {
      _log('ERRO na validação local: $e');
      return null;
    }
  }

  /// Iniciar sincronização em background
  static void _startBackgroundSync() {
    if (SyncService.isOnline) {
      _log('Iniciando sincronização em background');
      // Agendar sync sem aguardar
      Future.microtask(() => SyncService.syncNow());
    }
  }

  /// Logout do paciente
  static Future<void> signOut() async {
    try {
      _log('Fazendo logout do paciente...');
      
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_patientDataKey);
      await prefs.setBool(_isPatientLoggedInKey, false);
      
      _log('Logout do paciente concluído');
    } catch (e) {
      _log('ERRO no logout do paciente: $e');
      rethrow;
    }
  }

  // 🔧 UTILITÁRIOS

  /// Obter usuário atual do Firebase
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Stream para mudanças no estado de autenticação
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Atualizar dados do paciente
  static Future<bool> updatePatientData(Learner patient) async {
    try {
      _log('Atualizando dados do paciente: ${patient.email}');
      
      // Sempre salvar localmente
      await _savePatientData(patient);
      
      // Tentar atualizar no Firestore se online
      if (SyncService.isOnline && patient.therapistId != null) {
        try {
          await FirestoreService.updatePatientLastAccess(
            patient.therapistId!,
            patient.id,
          );
          _log('Dados do paciente atualizados no Firestore');
        } catch (e) {
          _log('ERRO ao atualizar no Firestore: $e');
          // Não falha se o Firestore der erro
        }
      }
      
      return true;
    } catch (e) {
      _log('ERRO ao atualizar dados do paciente: $e');
      return false;
    }
  }

  /// Obter ID único do paciente para dados isolados
  static Future<String?> getPatientUniqueId() async {
    final patient = await getPatientData();
    return patient?.id;
  }

  /// Verificar se o paciente atual pertence a um terapeuta específico
  static Future<bool> belongsToTherapist(String therapistId) async {
    final patient = await getPatientData();
    final belongs = patient?.therapistId == therapistId;
    _log('Paciente pertence ao terapeuta $therapistId: $belongs');
    return belongs;
  }

  /// Obter terapeuta responsável pelo paciente atual
  static Future<String?> getTherapistId() async {
    final patient = await getPatientData();
    return patient?.therapistId;
  }

  // 🔒 VALIDAÇÃO ADICIONAL DE SEGURANÇA

  /// Validar sessão atual
  static Future<bool> validateCurrentSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _log('Validação falhou: Usuário Firebase não encontrado');
        return false;
      }
      
      final email = user.email ?? '';
      
      // Se online, verificar no Firestore
      if (SyncService.isOnline) {
        try {
          final patient = await FirestoreService.getPatientByEmail(email);
          if (patient == null || !patient.isActive) {
            _log('Validação falhou: Paciente não autorizado ou inativo no Firestore');
            await signOut();
            return false;
          }
        } catch (e) {
          _log('ERRO na validação Firestore: $e');
          // Continuar com validação local se Firestore falhar
        }
      }
      
      // Validação local
      final localPatient = await _validateLocalPatient(email);
      if (localPatient == null) {
        _log('Validação falhou: Paciente não encontrado localmente');
        await signOut();
        return false;
      }
      
      _log('Sessão validada com sucesso para: $email');
      return true;
    } catch (e) {
      _log('ERRO na validação de sessão: $e');
      return false;
    }
  }

  /// Obter informações do terapeuta responsável
  static Future<Map<String, dynamic>?> getTherapistInfo() async {
    try {
      final patient = await getPatientData();
      if (patient?.therapistId == null) return null;
      
      Map<String, dynamic> info = {
        'therapistId': patient!.therapistId,
        'patientSince': patient.createdAt.toIso8601String(),
        'lastUpdate': patient.lastAccess?.toIso8601String(),
      };
      
      // Tentar obter dados do terapeuta do Firestore se online
      if (SyncService.isOnline) {
        try {
          final therapistData = await FirestoreService.getTherapistData(patient.therapistId!);
          if (therapistData != null) {
            info['therapistName'] = therapistData['name'];
            info['therapistEmail'] = therapistData['email'];
          }
        } catch (e) {
          _log('ERRO ao obter dados do terapeuta: $e');
        }
      }
      
      return info;
    } catch (e) {
      _log('ERRO ao obter info do terapeuta: $e');
      return null;
    }
  }

  /// Verificar se o paciente pode acessar uma funcionalidade específica
  static Future<bool> canAccessFeature(String feature) async {
    try {
      final patient = await getPatientData();
      if (patient == null || !patient.isActive) {
        return false;
      }
      
      // Implementar lógica específica de permissões se necessário
      // Por exemplo, baseado no diagnóstico, idade, etc.
      
      return true; // Por padrão, permitir acesso
    } catch (e) {
      _log('ERRO na verificação de permissão: $e');
      return false;
    }
  }

  // 🔧 MÉTODOS DE DEBUG

  /// Verificar status do paciente atual
  static Future<Map<String, dynamic>> getPatientStatus() async {
    try {
      final patient = await getPatientData();
      final user = _auth.currentUser;
      
      return {
        'hasPatientData': patient != null,
        'patientEmail': patient?.email,
        'patientActive': patient?.isActive ?? false,
        'hasFirebaseUser': user != null,
        'firebaseEmail': user?.email,
        'therapistId': patient?.therapistId,
        'lastAccess': patient?.lastAccess?.toIso8601String(),
        'isOnline': SyncService.isOnline,
        'syncStatus': SyncService.status.toString(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Forçar revalidação completa do paciente
  static Future<bool> forceRevalidation() async {
    try {
      _log('Iniciando revalidação forçada...');
      
      final user = _auth.currentUser;
      if (user == null) {
        _log('Revalidação falhou: Sem usuário Firebase');
        return false;
      }
      
      final email = user.email ?? '';
      
      // Se online, buscar dados atualizados do Firestore
      if (SyncService.isOnline) {
        try {
          final patient = await FirestoreService.getPatientByEmail(email);
          
          if (patient == null || !patient.isActive) {
            _log('Revalidação falhou: Paciente não encontrado ou inativo no Firestore');
            await signOut();
            return false;
          }
          
          // Atualizar dados locais com dados mais recentes do Firestore
          await _savePatientData(patient);
          _log('Revalidação bem-sucedida com dados do Firestore');
          return true;
        } catch (e) {
          _log('ERRO na revalidação Firestore: $e');
        }
      }
      
      // Fallback: validar com dados locais
      final localPatient = await _validateLocalPatient(email);
      if (localPatient != null) {
        _log('Revalidação bem-sucedida com dados locais');
        return true;
      }
      
      _log('Revalidação falhou completamente');
      await signOut();
      return false;
    } catch (e) {
      _log('ERRO na revalidação: $e');
      return false;
    }
  }

  // 🔄 SINCRONIZAÇÃO

  /// Sincronizar dados do paciente manualmente
  static Future<bool> syncPatientData() async {
    if (!SyncService.isOnline) {
      _log('Sem conexão para sincronização');
      return false;
    }
    
    try {
      final patient = await getPatientData();
      if (patient != null && patient.therapistId != null) {
        // Buscar dados atualizados do Firestore
        final updatedPatient = await FirestoreService.getPatientByEmail(patient.email!);
        
        if (updatedPatient != null) {
          await _savePatientData(updatedPatient);
          _log('Dados do paciente sincronizados com sucesso');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      _log('ERRO na sincronização: $e');
      return false;
    }
  }

  /// Verificar se há atualizações disponíveis no servidor
  static Future<bool> hasUpdatesAvailable() async {
    if (!SyncService.isOnline) return false;
    
    try {
      final localPatient = await getPatientData();
      if (localPatient == null) return false;
      
      final serverPatient = await FirestoreService.getPatientByEmail(localPatient.email!);
      if (serverPatient == null) return false;
      
      // Comparar timestamps de última atualização
      final localLastUpdate = localPatient.lastAccess ?? localPatient.createdAt;
      final serverLastUpdate = serverPatient.lastAccess ?? serverPatient.createdAt;
      
      return serverLastUpdate.isAfter(localLastUpdate);
    } catch (e) {
      _log('ERRO ao verificar atualizações: $e');
      return false;
    }
  }

  // 📱 CONECTIVIDADE

  /// Lidar com mudanças de conectividade
  static void handleConnectivityChange(bool isOnline) {
    if (isOnline) {
      _log('Conexão restaurada - iniciando sincronização');
      _startBackgroundSync();
    } else {
      _log('Conexão perdida - modo offline ativado');
    }
  }

  // 🧹 LIMPEZA

  /// Limpar cache e dados temporários
  static Future<void> clearCache() async {
    try {
      // Manter dados essenciais do paciente, mas limpar cache temporário
      final prefs = await SharedPreferences.getInstance();
      
      // Remover dados de cache (não os dados principais do paciente)
      final keys = prefs.getKeys().where((key) => 
        key.startsWith('cache_') || 
        key.startsWith('temp_') ||
        key.startsWith('pending_')
      );
      
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      _log('Cache limpo com sucesso');
    } catch (e) {
      _log('ERRO ao limpar cache: $e');
    }
  }
}