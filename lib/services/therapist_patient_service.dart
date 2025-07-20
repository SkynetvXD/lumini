import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/learner.dart';

class TherapistPatientService {
  static const String _patientsKey = 'therapist_patients';
  static const int maxPatientsPerTherapist = 10;

  // Obter todos os pacientes Gmail de um terapeuta
  static Future<List<Learner>> getPatientsByTherapist(String therapistId) async {
    final prefs = await SharedPreferences.getInstance();
    final patientsKey = '${_patientsKey}_$therapistId';
    final patientsList = prefs.getStringList(patientsKey) ?? [];
    
    return patientsList
        .map((patientJson) => Learner.fromJson(patientJson))
        .where((patient) => patient.isActive && patient.isAuthenticated)
        .toList();
  }

  // Adicionar um novo paciente Gmail para um terapeuta
  static Future<bool> addPatient(Learner patient) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_${patient.therapistId}';
      final patients = await getPatientsByTherapist(patient.therapistId!);
      
      // Verificar se atingiu o limite de pacientes
      if (patients.length >= maxPatientsPerTherapist) {
        throw Exception('Limite de $maxPatientsPerTherapist pacientes atingido');
      }
      
      // Verificar se o email já está cadastrado para este terapeuta
      if (patients.any((p) => p.email?.toLowerCase() == patient.email?.toLowerCase())) {
        throw Exception('Este email já está cadastrado como paciente');
      }
      
      // Adicionar o novo paciente
      patients.add(patient);
      
      // Salvar a lista atualizada
      final patientsJsonList = patients.map((p) => p.toJson()).toList();
      return await prefs.setStringList(patientsKey, patientsJsonList);
    } catch (e) {
      print('Erro ao adicionar paciente: $e');
      rethrow;
    }
  }

  // Atualizar um paciente existente
  static Future<bool> updatePatient(Learner patient) async {
    try {
      if (!patient.isAuthenticated || patient.therapistId == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_${patient.therapistId}';
      final patients = await getPatientsByTherapist(patient.therapistId!);
      
      // Encontrar o índice do paciente a ser atualizado
      final index = patients.indexWhere((p) => p.id == patient.id);
      if (index == -1) {
        throw Exception('Paciente não encontrado');
      }
      
      // Atualizar o paciente
      patients[index] = patient;
      
      // Salvar a lista atualizada
      final patientsJsonList = patients.map((p) => p.toJson()).toList();
      return await prefs.setStringList(patientsKey, patientsJsonList);
    } catch (e) {
      print('Erro ao atualizar paciente: $e');
      return false;
    }
  }

  // Remover um paciente (desativar)
  static Future<bool> removePatient(String patientId) async {
    try {
      // Primeiro, encontrar o paciente em todos os terapeutas
      final patient = await getPatientById(patientId);
      if (patient == null || !patient.isAuthenticated) {
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_${patient.therapistId}';
      final patients = await getPatientsByTherapist(patient.therapistId!);
      
      // Marcar como inativo em vez de remover completamente
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        patients[index] = patients[index].copyWith(isActive: false);
        
        // Salvar a lista atualizada
        final patientsJsonList = patients.map((p) => p.toJson()).toList();
        return await prefs.setStringList(patientsKey, patientsJsonList);
      }
      
      return false;
    } catch (e) {
      print('Erro ao remover paciente: $e');
      return false;
    }
  }

  // Obter paciente por email
  static Future<Learner?> getPatientByEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Buscar em todas as listas de pacientes de todos os terapeutas
      for (String key in keys) {
        if (key.startsWith(_patientsKey)) {
          final patientsList = prefs.getStringList(key) ?? [];
          
          for (String patientJson in patientsList) {
            final patient = Learner.fromJson(patientJson);
            if (patient.isAuthenticated && 
                patient.email?.toLowerCase() == email.toLowerCase() && 
                patient.isActive) {
              return patient;
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Erro ao buscar paciente por email: $e');
      return null;
    }
  }

  // Obter paciente por ID
  static Future<Learner?> getPatientById(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Buscar em todas as listas de pacientes de todos os terapeutas
      for (String key in keys) {
        if (key.startsWith(_patientsKey)) {
          final patientsList = prefs.getStringList(key) ?? [];
          
          for (String patientJson in patientsList) {
            final patient = Learner.fromJson(patientJson);
            if (patient.id == patientId && patient.isAuthenticated) {
              return patient;
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Erro ao buscar paciente por ID: $e');
      return null;
    }
  }

  // Gerar um ID único para um novo paciente
  static String generateUniqueId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return '${timestamp}_$randomPart';
  }

  // Contar pacientes ativos de um terapeuta
  static Future<int> getActivePatientCount(String therapistId) async {
    final patients = await getPatientsByTherapist(therapistId);
    return patients.where((p) => p.isActive).length;
  }

  // Verificar se um terapeuta pode adicionar mais pacientes
  static Future<bool> canAddMorePatients(String therapistId) async {
    final count = await getActivePatientCount(therapistId);
    return count < maxPatientsPerTherapist;
  }

  // Convidar paciente (enviar informações para o paciente fazer login)
  static Future<Map<String, String>> invitePatient({
    required String email,
    required String name,
    required String therapistId,
    DateTime? birthDate,
    String? diagnosis,
  }) async {
    try {
      // Verificar se o terapeuta pode adicionar mais pacientes
      if (!await canAddMorePatients(therapistId)) {
        throw Exception('Limite de pacientes atingido');
      }
      
      // Criar novo paciente Gmail usando factory do Learner
      final patient = Learner.createGmailPatient(
        email: email,
        name: name,
        therapistId: therapistId,
        birthDate: birthDate,
        diagnosis: diagnosis,
      );
      
      // Adicionar paciente
      final success = await addPatient(patient);
      
      if (success) {
        return {
          'patientId': patient.id,
          'email': patient.email!,
          'inviteMessage': 'Paciente $name foi registrado com sucesso!\n\n'
              'Instruções para o paciente:\n'
              '1. Fazer login no app Lumimi\n'
              '2. Escolher "Paciente"\n'
              '3. Entrar com a conta: ${patient.email}\n'
              '4. Começar os treinos!\n\n'
              'O acesso estará ativo a partir de agora.',
        };
      } else {
        throw Exception('Erro ao registrar paciente');
      }
    } catch (e) {
      print('Erro ao convidar paciente: $e');
      rethrow;
    }
  }

  // Obter estatísticas do terapeuta
  static Future<Map<String, dynamic>> getTherapistStats(String therapistId) async {
    final patients = await getPatientsByTherapist(therapistId);
    
    int activePatients = patients.where((p) => p.isActive).length;
    int totalPatients = patients.length;
    int recentlyActive = patients.where((p) {
      if (p.lastAccess == null) return false;
      final daysSinceLastAccess = DateTime.now().difference(p.lastAccess!).inDays;
      return daysSinceLastAccess <= 7; // Ativo nos últimos 7 dias
    }).length;
    
    return {
      'activePatients': activePatients,
      'totalPatients': totalPatients,
      'recentlyActive': recentlyActive,
      'availableSlots': maxPatientsPerTherapist - activePatients,
    };
  }

  // Limpar todos os dados de pacientes de um terapeuta
  static Future<bool> clearAllPatients(String therapistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_$therapistId';
      return await prefs.remove(patientsKey);
    } catch (e) {
      print('Erro ao limpar pacientes: $e');
      return false;
    }
  }
}