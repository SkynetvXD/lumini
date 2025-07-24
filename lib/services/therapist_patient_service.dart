import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/learner.dart';

class TherapistPatientService {
  static const String _patientsKey = 'therapist_patients';
  static const String _backupKey = 'therapist_patients_backup';
  static const int maxPatientsPerTherapist = 10;

  // 🔧 DEBUG: Ligar/desligar logs detalhados
  static const bool _debugMode = kDebugMode;

  static void _log(String message) {
    if (_debugMode) {
      print('🏥 TherapistPatientService: $message');
    }
  }

  // 🔒 OBTER THERAPIST ID ATUAL DE FORMA SEGURA
  static Future<String?> _getCurrentTherapistId() async {
    try {
      // Importar AuthService para obter dados atuais
      final prefs = await SharedPreferences.getInstance();
      final therapistDataString = prefs.getString('therapist_data');
      
      if (therapistDataString != null) {
        final therapistData = jsonDecode(therapistDataString);
        final therapistId = therapistData['uid'] as String?;
        _log('TherapistId encontrado: $therapistId');
        return therapistId;
      }
      
      _log('ERRO: Nenhum terapeuta logado encontrado');
      return null;
    } catch (e) {
      _log('ERRO ao obter therapistId: $e');
      return null;
    }
  }

  // 💾 BACKUP AUTOMÁTICO DOS DADOS
  static Future<void> _createBackup(String therapistId, List<Learner> patients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupKey = '${_backupKey}_$therapistId';
      final patientsJsonList = patients.map((p) => p.toJson()).toList();
      
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'therapistId': therapistId,
        'patientsCount': patients.length,
        'patients': patientsJsonList,
      };
      
      await prefs.setString(backupKey, jsonEncode(backupData));
      _log('Backup criado: ${patients.length} pacientes');
    } catch (e) {
      _log('ERRO ao criar backup: $e');
    }
  }

  // 🔄 RECOVERY DOS DADOS DE BACKUP
  static Future<List<Learner>> _recoverFromBackup(String therapistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupKey = '${_backupKey}_$therapistId';
      final backupString = prefs.getString(backupKey);
      
      if (backupString != null) {
        final backupData = jsonDecode(backupString);
        final patientsList = backupData['patients'] as List;
        final patients = patientsList
            .map((patientJson) => Learner.fromJson(patientJson))
            .where((patient) => patient.isAuthenticated && patient.isActive)
            .toList();
        
        _log('Recovery do backup: ${patients.length} pacientes recuperados');
        return patients;
      }
    } catch (e) {
      _log('ERRO no recovery: $e');
    }
    
    return [];
  }

  // Obter todos os pacientes Gmail de um terapeuta - VERSÃO ROBUSTA
  static Future<List<Learner>> getPatientsByTherapist(String therapistId) async {
    try {
      _log('Obtendo pacientes para therapistId: $therapistId');
      
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_$therapistId';
      final patientsList = prefs.getStringList(patientsKey) ?? [];
      
      _log('Pacientes encontrados no storage: ${patientsList.length}');
      
      List<Learner> patients = [];
      
      // Tentar carregar dados principais
      try {
        patients = patientsList
            .map((patientJson) => Learner.fromJson(patientJson))
            .where((patient) => patient.isActive && patient.isAuthenticated)
            .toList();
        
        _log('Pacientes válidos carregados: ${patients.length}');
      } catch (e) {
        _log('ERRO ao carregar dados principais: $e');
        
        // Tentar recovery do backup
        patients = await _recoverFromBackup(therapistId);
        
        if (patients.isNotEmpty) {
          _log('Dados recuperados do backup, salvando...');
          await _savePatientsList(therapistId, patients);
        }
      }
      
      return patients;
    } catch (e) {
      _log('ERRO CRÍTICO em getPatientsByTherapist: $e');
      return [];
    }
  }

  // 💾 SALVAR LISTA DE PACIENTES DE FORMA ROBUSTA
  static Future<bool> _savePatientsList(String therapistId, List<Learner> patients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_$therapistId';
      
      // Filtrar apenas pacientes válidos
      final validPatients = patients.where((p) => 
        p.isAuthenticated && 
        p.therapistId == therapistId
      ).toList();
      
      // Converter para JSON
      final patientsJsonList = validPatients.map((p) => p.toJson()).toList();
      
      // Salvar dados principais
      final success = await prefs.setStringList(patientsKey, patientsJsonList);
      
      if (success) {
        _log('Lista salva com sucesso: ${validPatients.length} pacientes');
        
        // Criar backup automático
        await _createBackup(therapistId, validPatients);
        
        return true;
      }
      
      return false;
    } catch (e) {
      _log('ERRO ao salvar lista: $e');
      return false;
    }
  }

  // Adicionar um novo paciente Gmail para um terapeuta - VERSÃO ROBUSTA
  static Future<bool> addPatient(Learner patient) async {
    try {
      if (!patient.isAuthenticated || patient.therapistId == null) {
        _log('ERRO: Paciente inválido - não autenticado ou sem therapistId');
        return false;
      }
      
      final therapistId = patient.therapistId!;
      _log('Adicionando paciente para therapistId: $therapistId');
      
      final patients = await getPatientsByTherapist(therapistId);
      
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
      final success = await _savePatientsList(therapistId, patients);
      
      if (success) {
        _log('Paciente adicionado com sucesso: ${patient.email}');
      }
      
      return success;
    } catch (e) {
      _log('ERRO ao adicionar paciente: $e');
      rethrow;
    }
  }

  // Atualizar um paciente existente - VERSÃO ROBUSTA
  static Future<bool> updatePatient(Learner patient) async {
    try {
      if (!patient.isAuthenticated || patient.therapistId == null) {
        _log('ERRO: Paciente inválido para atualização');
        return false;
      }

      final therapistId = patient.therapistId!;
      final patients = await getPatientsByTherapist(therapistId);
      
      // Encontrar o índice do paciente a ser atualizado
      final index = patients.indexWhere((p) => p.id == patient.id);
      if (index == -1) {
        _log('ERRO: Paciente não encontrado para atualização: ${patient.id}');
        return false;
      }
      
      // Atualizar o paciente
      patients[index] = patient;
      
      // Salvar a lista atualizada
      final success = await _savePatientsList(therapistId, patients);
      
      if (success) {
        _log('Paciente atualizado com sucesso: ${patient.email}');
      }
      
      return success;
    } catch (e) {
      _log('ERRO ao atualizar paciente: $e');
      return false;
    }
  }

  // Remover um paciente (desativar) - VERSÃO ROBUSTA
  static Future<bool> removePatient(String patientId) async {
    try {
      _log('Removendo paciente: $patientId');
      
      // Buscar o paciente em todos os terapeutas
      final patient = await getPatientById(patientId);
      if (patient == null || !patient.isAuthenticated) {
        _log('ERRO: Paciente não encontrado: $patientId');
        return false;
      }
      
      final therapistId = patient.therapistId!;
      final patients = await getPatientsByTherapist(therapistId);
      
      // Marcar como inativo em vez de remover completamente
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        patients[index] = patients[index].copyWith(isActive: false);
        
        // Salvar a lista atualizada
        final success = await _savePatientsList(therapistId, patients);
        
        if (success) {
          _log('Paciente removido com sucesso: $patientId');
        }
        
        return success;
      }
      
      return false;
    } catch (e) {
      _log('ERRO ao remover paciente: $e');
      return false;
    }
  }

  // Obter paciente por email - VERSÃO OTIMIZADA
  static Future<Learner?> getPatientByEmail(String email) async {
    try {
      _log('Buscando paciente por email: $email');
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Buscar em todas as listas de pacientes de todos os terapeutas
      for (String key in keys) {
        if (key.startsWith(_patientsKey)) {
          final patientsList = prefs.getStringList(key) ?? [];
          
          for (String patientJson in patientsList) {
            try {
              final patient = Learner.fromJson(patientJson);
              if (patient.isAuthenticated && 
                  patient.email?.toLowerCase() == email.toLowerCase() && 
                  patient.isActive) {
                _log('Paciente encontrado: ${patient.id}');
                return patient;
              }
            } catch (e) {
              _log('ERRO ao parsear paciente: $e');
              continue;
            }
          }
        }
      }
      
      _log('Paciente não encontrado para email: $email');
      return null;
    } catch (e) {
      _log('ERRO ao buscar paciente por email: $e');
      return null;
    }
  }

  // Obter paciente por ID - VERSÃO OTIMIZADA
  static Future<Learner?> getPatientById(String patientId) async {
    try {
      _log('Buscando paciente por ID: $patientId');
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Buscar em todas as listas de pacientes de todos os terapeutas
      for (String key in keys) {
        if (key.startsWith(_patientsKey)) {
          final patientsList = prefs.getStringList(key) ?? [];
          
          for (String patientJson in patientsList) {
            try {
              final patient = Learner.fromJson(patientJson);
              if (patient.id == patientId && patient.isAuthenticated) {
                _log('Paciente encontrado por ID: ${patient.email}');
                return patient;
              }
            } catch (e) {
              _log('ERRO ao parsear paciente: $e');
              continue;
            }
          }
        }
      }
      
      _log('Paciente não encontrado para ID: $patientId');
      return null;
    } catch (e) {
      _log('ERRO ao buscar paciente por ID: $e');
      return null;
    }
  }

  // Gerar um ID único para um novo paciente
  static String generateUniqueId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return 'patient_${timestamp}_$randomPart';
  }

  // Contar pacientes ativos de um terapeuta
  static Future<int> getActivePatientCount(String therapistId) async {
    final patients = await getPatientsByTherapist(therapistId);
    final count = patients.where((p) => p.isActive).length;
    _log('Contagem de pacientes ativos para $therapistId: $count');
    return count;
  }

  // Verificar se um terapeuta pode adicionar mais pacientes
  static Future<bool> canAddMorePatients(String therapistId) async {
    final count = await getActivePatientCount(therapistId);
    final canAdd = count < maxPatientsPerTherapist;
    _log('Pode adicionar mais pacientes: $canAdd ($count/$maxPatientsPerTherapist)');
    return canAdd;
  }

  // Convidar paciente (enviar informações para o paciente fazer login) - VERSÃO MELHORADA
  static Future<Map<String, String>> invitePatient({
    required String email,
    required String name,
    required String therapistId,
    DateTime? birthDate,
    String? diagnosis,
  }) async {
    try {
      _log('Convidando paciente: $email para terapeuta: $therapistId');
      
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
        _log('Paciente convidado com sucesso: ${patient.email}');
        
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
      _log('ERRO ao convidar paciente: $e');
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
    
    _log('Estatísticas do terapeuta: $activePatients ativos de $totalPatients total');
    
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
      _log('Limpando todos os pacientes do terapeuta: $therapistId');
      
      final prefs = await SharedPreferences.getInstance();
      final patientsKey = '${_patientsKey}_$therapistId';
      final backupKey = '${_backupKey}_$therapistId';
      
      await prefs.remove(patientsKey);
      await prefs.remove(backupKey);
      
      _log('Dados limpos com sucesso');
      return true;
    } catch (e) {
      _log('ERRO ao limpar pacientes: $e');
      return false;
    }
  }

  // 🔧 MÉTODOS DE DEBUG E MANUTENÇÃO

  // Verificar integridade dos dados
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
      };
    } catch (e) {
      _log('ERRO na verificação de integridade: $e');
      return {'error': e.toString()};
    }
  }

  // Reparar dados corrompidos
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