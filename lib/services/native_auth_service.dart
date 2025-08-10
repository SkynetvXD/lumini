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
      'password': 'test@123',  // ← SENHA ALTERADA
      'type': 'therapist',
      'name': 'Dr. Terapeuta CoGLuna',  // ← NOME MELHORADO
      'uid': 'therapist_cogluna_001',
      'email': 'terapeutacogluna@gmail.com',
      'authorized': true,
    },
    
    // PACIENTE
    'pacientecogluna@gmail.com': {
      'password': 'test@123',  // ← SENHA ALTERADA
      'type': 'patient',
      'name': 'Paciente CoGLuna',  // ← NOME MELHORADO
      'uid': 'patient_cogluna_001',
      'email': 'pacientecogluna@gmail.com',
      'birthDate': null, // Será definida como hoje na validação
      'therapistId': 'therapist_cogluna_001',  // ← JÁ VINCULADO AO TERAPEUTA
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
    
    // 🆕 AUTO-VINCULAR PACIENTES NATIVOS
    await autoLinkNativePatientsToTherapist(userData['uid']);
    
    print('✅ Login de terapeuta concluído com pacientes nativos vinculados');
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

  // ==================== INTEGRAÇÃO COM SISTEMA DE PACIENTES ====================

  /// Obter todos os pacientes nativos vinculados a um terapeuta
  static List<Map<String, dynamic>> getNativePatientsForTherapist(String therapistId) {
  final patients = <Map<String, dynamic>>[];
  
  for (final entry in _predefinedUsers.entries) {
    final userData = entry.value;
    
    // Verificar se é paciente e está vinculado ao terapeuta
    if (userData['type'] == 'patient' && 
        userData['therapistId'] == therapistId &&
        userData['isActive'] == true) {
      
      // Criar dados do paciente no formato Learner
      final patientData = {
        'id': userData['uid'],
        'name': userData['name'],
        'email': userData['email'],
        'birthDate': DateTime.now().toIso8601String(), // Data de nascimento hoje
        'diagnosis': 'Paciente de Teste',
        'createdAt': DateTime.now().toIso8601String(),
        'lastAccess': DateTime.now().toIso8601String(),
        'therapistId': userData['therapistId'],
        'isActive': userData['isActive'],
        'isAuthenticated': true,
        'authMethod': 'native',
      };
      
      patients.add(patientData);
    }
  }
  
  print('✅ ${patients.length} pacientes nativos encontrados para terapeuta: $therapistId');
  return patients;
}

/// Verificar se um email é um paciente nativo
static bool isNativePatient(String email) {
  final emailLower = email.toLowerCase().trim();
  final userData = _predefinedUsers[emailLower];
  return userData != null && userData['type'] == 'patient';
}

/// Obter dados de um paciente nativo por email
static Map<String, dynamic>? getNativePatientByEmail(String email) {
  final emailLower = email.toLowerCase().trim();
  final userData = _predefinedUsers[emailLower];
  
  if (userData != null && userData['type'] == 'patient') {
    return {
      'id': userData['uid'],
      'name': userData['name'],
      'email': userData['email'],
      'birthDate': DateTime.now().toIso8601String(),
      'diagnosis': 'Paciente de Teste',
      'createdAt': DateTime.now().toIso8601String(),
      'lastAccess': DateTime.now().toIso8601String(),
      'therapistId': userData['therapistId'],
      'isActive': userData['isActive'],
      'isAuthenticated': true,
      'authMethod': 'native',
    };
  }
  
  return null;
}

/// Adicionar automaticamente pacientes nativos ao terapeuta quando ele faz login
static Future<void> autoLinkNativePatientsToTherapist(String therapistId) async {
  try {
    print('🔗 Vinculando pacientes nativos ao terapeuta: $therapistId');
    
    // Importar o serviço aqui para evitar dependência circular
    final patients = getNativePatientsForTherapist(therapistId);
    
    if (patients.isNotEmpty) {
      // Usar TherapistPatientService para adicionar os pacientes nativos
      for (final patientData in patients) {
        await _addNativePatientToTherapist(therapistId, patientData);
      }
      
      print('✅ ${patients.length} pacientes nativos vinculados com sucesso');
    } else {
      print('ℹ️ Nenhum paciente nativo encontrado para este terapeuta');
    }
  } catch (e) {
    print('❌ Erro ao vincular pacientes nativos: $e');
  }
}

/// Adicionar paciente nativo à lista local do terapeuta
static Future<void> _addNativePatientToTherapist(String therapistId, Map<String, dynamic> patientData) async {
  try {
    // Importação local para evitar dependência circular
    const patientsKey = 'therapist_patients';
    final patientsKeyForTherapist = '${patientsKey}_$therapistId';
    
    final prefs = await SharedPreferences.getInstance();
    final existingPatients = prefs.getStringList(patientsKeyForTherapist) ?? [];
    
    // Verificar se o paciente já existe
    bool alreadyExists = false;
    for (String patientJson in existingPatients) {
      try {
        final existingPatient = jsonDecode(patientJson);
        if (existingPatient['id'] == patientData['id'] || 
            existingPatient['email'] == patientData['email']) {
          alreadyExists = true;
          break;
        }
      } catch (e) {
        continue;
      }
    }
    
    // Adicionar apenas se não existir
    if (!alreadyExists) {
      existingPatients.add(jsonEncode(patientData));
      await prefs.setStringList(patientsKeyForTherapist, existingPatients);
      print('✅ Paciente nativo adicionado: ${patientData['name']}');
    } else {
      print('ℹ️ Paciente nativo já existe: ${patientData['name']}');
    }
  } catch (e) {
    print('❌ Erro ao adicionar paciente nativo: $e');
  }
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