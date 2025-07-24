import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/learner.dart';
import 'therapist_patient_service.dart';

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

  // 🔧 DEBUG: Ligar/desligar logs detalhados
  static const bool _debugMode = kDebugMode;

  static void _log(String message) {
    if (_debugMode) {
      print('👨‍⚕️ PatientAuthService: $message');
    }
  }

  // Salvar dados do paciente logado
  static Future<void> _savePatientData(Learner patient) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_patientDataKey, patient.toJson());
    await prefs.setBool(_isPatientLoggedInKey, true);
    _log('Dados do paciente salvos: ${patient.email}');
  }

  // Obter dados do paciente logado
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

  // Verificar se paciente está logado
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
          // Verificar se ainda existe na base do terapeuta
          final existingPatient = await TherapistPatientService.getPatientByEmail(user.email ?? '');
          if (existingPatient != null && existingPatient.isActive) {
            _log('Paciente validado: ${user.email}');
            return true;
          }
        }
        
        _log('Paciente não mais autorizado, fazendo logout');
        await signOut();
      }
      
      return false;
    } catch (e) {
      _log('ERRO na verificação de login: $e');
      return false;
    }
  }

  // Login com Google para paciente - VERSÃO SEGURA
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
        
        // 🔒 VERIFICAÇÃO RIGOROSA: O EMAIL ESTÁ CADASTRADO COMO PACIENTE?
        final patient = await TherapistPatientService.getPatientByEmail(email);
        
        if (patient == null) {
          _log('ACESSO NEGADO: Email não cadastrado como paciente');
          await signOut();
          throw Exception('🚫 ACESSO NEGADO\n\nEmail: $email\n\nEste email não está registrado como paciente.\n\nPara ter acesso:\n1. Entre em contato com seu terapeuta\n2. Solicite o cadastro do seu email\n3. Tente fazer login novamente');
        }

        if (!patient.isActive) {
          _log('ACESSO NEGADO: Paciente inativo');
          await signOut();
          throw Exception('🚫 CONTA INATIVA\n\nSua conta de paciente está inativa.\n\nEntre em contato com seu terapeuta para reativar o acesso.');
        }

        _log('Paciente autorizado encontrado: ${patient.name}');

        // Atualizar último acesso do paciente
        final updatedPatient = patient.updateLastAccess();
        await TherapistPatientService.updatePatient(updatedPatient);

        // Salvar dados do paciente logado
        await _savePatientData(updatedPatient);
        
        _log('Login de paciente concluído com sucesso');
        return updatedPatient;
      }

      _log('ERRO: Usuário Firebase é null');
      return null;
    } catch (e) {
      _log('ERRO no login do paciente: $e');
      rethrow;
    }
  }

  // Logout do paciente
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

  // Obter usuário atual do Firebase
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream para mudanças no estado de autenticação
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Atualizar dados do paciente
  static Future<bool> updatePatientData(Learner patient) async {
    try {
      _log('Atualizando dados do paciente: ${patient.email}');
      
      final success = await TherapistPatientService.updatePatient(patient);
      if (success) {
        await _savePatientData(patient);
        _log('Dados do paciente atualizados com sucesso');
      }
      return success;
    } catch (e) {
      _log('ERRO ao atualizar dados do paciente: $e');
      return false;
    }
  }

  // Obter ID único do paciente para dados isolados
  static Future<String?> getPatientUniqueId() async {
    final patient = await getPatientData();
    return patient?.id;
  }

  // Verificar se o paciente atual pertence a um terapeuta específico
  static Future<bool> belongsToTherapist(String therapistId) async {
    final patient = await getPatientData();
    final belongs = patient?.therapistId == therapistId;
    _log('Paciente pertence ao terapeuta $therapistId: $belongs');
    return belongs;
  }

  // Obter terapeuta responsável pelo paciente atual
  static Future<String?> getTherapistId() async {
    final patient = await getPatientData();
    return patient?.therapistId;
  }

  // 🔒 VALIDAÇÃO ADICIONAL DE SEGURANÇA
  static Future<bool> validateCurrentSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _log('Validação falhou: Usuário Firebase não encontrado');
        return false;
      }
      
      final email = user.email ?? '';
      
      // Verificar se ainda está cadastrado como paciente ativo
      final patient = await TherapistPatientService.getPatientByEmail(email);
      if (patient == null || !patient.isActive) {
        _log('Validação falhou: Paciente não autorizado ou inativo');
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

  // Obter informações do terapeuta responsável
  static Future<Map<String, dynamic>?> getTherapistInfo() async {
    try {
      final patient = await getPatientData();
      if (patient?.therapistId == null) return null;
      
      // Buscar dados do terapeuta (você pode expandir isso se necessário)
      return {
        'therapistId': patient!.therapistId,
        'patientSince': patient.createdAt.toIso8601String(),
        'lastUpdate': patient.lastAccess?.toIso8601String(),
      };
    } catch (e) {
      _log('ERRO ao obter info do terapeuta: $e');
      return null;
    }
  }

  // Verificar se o paciente pode acessar uma funcionalidade específica
  static Future<bool> canAccessFeature(String feature) async {
    try {
      final patient = await getPatientData();
      if (patient == null || !patient.isActive) {
        return false;
      }
      
      // Aqui você pode implementar lógica específica de permissões
      // Por exemplo, baseado no diagnóstico, idade, etc.
      
      return true; // Por padrão, permitir acesso
    } catch (e) {
      _log('ERRO na verificação de permissão: $e');
      return false;
    }
  }

  // 🔧 MÉTODOS DE DEBUG

  // Verificar status do paciente atual
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
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Forçar revalidação completa do paciente
  static Future<bool> forceRevalidation() async {
    try {
      _log('Iniciando revalidação forçada...');
      
      final user = _auth.currentUser;
      if (user == null) {
        _log('Revalidação falhou: Sem usuário Firebase');
        return false;
      }
      
      final email = user.email ?? '';
      final patient = await TherapistPatientService.getPatientByEmail(email);
      
      if (patient == null || !patient.isActive) {
        _log('Revalidação falhou: Paciente não encontrado ou inativo');
        await signOut();
        return false;
      }
      
      // Atualizar dados locais com dados mais recentes
      await _savePatientData(patient);
      
      _log('Revalidação bem-sucedida');
      return true;
    } catch (e) {
      _log('ERRO na revalidação: $e');
      return false;
    }
  }
}