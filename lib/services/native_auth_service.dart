// lib/services/native_auth_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NativeAuthService {
  static const String _therapistDataKey = 'therapist_data_native';
  static const String _patientDataKey = 'patient_data_native';
  static const String _isTherapistLoggedInKey = 'is_therapist_logged_in_native';
  static const String _isPatientLoggedInKey = 'is_patient_logged_in_native';

  // 🔒 USUÁRIOS PRÉ-CADASTRADOS DO SISTEMA
  static const Map<String, Map<String, dynamic>> _predefinedUsers = {
    // TERAPEUTA
    'terapeutacogluna@gmail.com': {
      'password': 'coglun@123',
      'type': 'therapist',
      'name': 'Terapeuta T',
      'uid': 'therapist_cogluna_001',
      'email': 'terapeutacogluna@gmail.com',
      'authorized': true,
    },
    
    // PACIENTE
    'pacientecogluna@gmail.com': {
      'password': 'coglun@123',
      'type': 'patient',
      'name': 'Paciente T',
      'uid': 'patient_cogluna_001',
      'email': 'pacientecogluna@gmail.com',
      'birthDate': null, // Será definida como hoje na validação
      'therapistId': 'therapist_cogluna_001',
      'isActive': true,
    },
  };

  // ==================== AUTENTICAÇÃO TERAPEUTA ====================

  /// Login de terapeuta com email/senha
  static Future<Map<String, dynamic>?> signInTherapistWithEmail(String email, String password) async {
    try {
      final emailLower = email.toLowerCase().trim();
      
      // Verificar se o usuário existe
      if (!_predefinedUsers.containsKey(emailLower)) {
        throw Exception('Email não encontrado no sistema.');
      }

      final userData = _predefinedUsers[emailLower]!;
      
      // Verificar se é terapeuta
      if (userData['type'] != 'therapist') {
        throw Exception('Este email não está autorizado para acesso de terapeuta.');
      }

      // Verificar senha
      if (userData['password'] != password) {
        throw Exception('Senha incorreta.');
      }

      // Criar dados do terapeuta
      final therapistData = {
        'uid': userData['uid'],
        'name': userData['name'],
        'email': userData['email'],
        'photoUrl': '',
        'loginTime': DateTime.now().toIso8601String(),
        'authorized': userData['authorized'],
        'authMethod': 'native',
      };

      await _saveTherapistData(therapistData);
      return therapistData;

    } catch (e) {
      print('Erro no login de terapeuta: $e');
      rethrow;
    }
  }

  /// Verificar se terapeuta está logado (nativo)
  static Future<bool> isTherapistLoggedInNative() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isTherapistLoggedInKey) ?? false;
  }

  /// Obter dados do terapeuta logado (nativo)
  static Future<Map<String, dynamic>?> getTherapistDataNative() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_therapistDataKey);
    
    if (dataString != null) {
      return Map<String, dynamic>.from(jsonDecode(dataString));
    }
    return null;
  }

  // ==================== AUTENTICAÇÃO PACIENTE ====================

  /// Login de paciente com email/senha
  static Future<Map<String, dynamic>?> signInPatientWithEmail(String email, String password) async {
    try {
      final emailLower = email.toLowerCase().trim();
      
      // Verificar se o usuário existe
      if (!_predefinedUsers.containsKey(emailLower)) {
        throw Exception('🚫 ACESSO NEGADO\n\nEmail: $email\n\nEste email não está registrado como paciente.\n\nPara ter acesso:\n1. Entre em contato com seu terapeuta\n2. Solicite o cadastro do seu email\n3. Tente fazer login novamente');
      }

      final userData = _predefinedUsers[emailLower]!;
      
      // Verificar se é paciente
      if (userData['type'] != 'patient') {
        throw Exception('Este email não está autorizado para acesso de paciente.');
      }

      // Verificar se está ativo
      if (userData['isActive'] != true) {
        throw Exception('🚫 CONTA INATIVA\n\nSua conta de paciente está inativa.\n\nEntre em contato com seu terapeuta para reativar o acesso.');
      }

      // Verificar senha
      if (userData['password'] != password) {
        throw Exception('Senha incorreta.');
      }

      // Criar dados do paciente com data de nascimento de hoje
      final today = DateTime.now();
      final patientData = {
        'id': userData['uid'],
        'name': userData['name'],
        'email': userData['email'],
        'birthDate': today.toIso8601String(),
        'therapistId': userData['therapistId'],
        'isActive': userData['isActive'],
        'loginTime': DateTime.now().toIso8601String(),
        'lastAccess': DateTime.now().toIso8601String(),
        'authMethod': 'native',
      };

      await _savePatientData(patientData);
      return patientData;

    } catch (e) {
      print('Erro no login de paciente: $e');
      rethrow;
    }
  }

  /// Verificar se paciente está logado (nativo)
  static Future<bool> isPatientLoggedInNative() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isPatientLoggedInKey) ?? false;
  }

  /// Obter dados do paciente logado (nativo)
  static Future<Map<String, dynamic>?> getPatientDataNative() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_patientDataKey);
    
    if (dataString != null) {
      return Map<String, dynamic>.from(jsonDecode(dataString));
    }
    return null;
  }

  // ==================== FUNÇÕES AUXILIARES ====================

  /// Salvar dados do terapeuta
  static Future<void> _saveTherapistData(Map<String, dynamic> therapistData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_therapistDataKey, jsonEncode(therapistData));
    await prefs.setBool(_isTherapistLoggedInKey, true);
  }

  /// Salvar dados do paciente
  static Future<void> _savePatientData(Map<String, dynamic> patientData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_patientDataKey, jsonEncode(patientData));
    await prefs.setBool(_isPatientLoggedInKey, true);
  }

  /// Logout terapeuta nativo
  static Future<void> signOutTherapist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_therapistDataKey);
      await prefs.setBool(_isTherapistLoggedInKey, false);
    } catch (e) {
      print('Erro no logout de terapeuta: $e');
      rethrow;
    }
  }

  /// Logout paciente nativo
  static Future<void> signOutPatient() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_patientDataKey);
      await prefs.setBool(_isPatientLoggedInKey, false);
    } catch (e) {
      print('Erro no logout de paciente: $e');
      rethrow;
    }
  }

  /// Verificar se o sistema tem usuários pré-cadastrados
  static bool hasUsers() {
    return _predefinedUsers.isNotEmpty;
  }
}