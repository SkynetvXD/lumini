// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/learner.dart';
import '../models/training_stats.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔧 CONFIGURAÇÕES
  static const int maxTherapists = 10;
  static const int maxPatientsPerTherapist = 10;
  static const bool _debugMode = kDebugMode;

  static void _log(String message) {
    if (_debugMode) {
      print('🔥 FirestoreService: $message');
    }
  }

  // 📊 VERIFICAÇÕES E VALIDAÇÕES

  /// Verificar se terapeuta pode ser criado (limite de 10)
  static Future<bool> canCreateTherapist() async {
    try {
      final snapshot = await _db.collection('therapists').get();
      final canCreate = snapshot.size < maxTherapists;
      _log('Pode criar terapeuta: $canCreate (${snapshot.size}/$maxTherapists)');
      return canCreate;
    } catch (e) {
      _log('ERRO ao verificar limite de terapeutas: $e');
      return false;
    }
  }

  /// Verificar se terapeuta pode adicionar mais pacientes
  static Future<bool> canAddPatient(String therapistId) async {
    try {
      final snapshot = await _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .where('isActive', isEqualTo: true)
          .get();
      
      final canAdd = snapshot.size < maxPatientsPerTherapist;
      _log('Pode adicionar paciente: $canAdd (${snapshot.size}/$maxPatientsPerTherapist)');
      return canAdd;
    } catch (e) {
      _log('ERRO ao verificar limite de pacientes: $e');
      return false;
    }
  }

  // 👨‍⚕️ GESTÃO DE TERAPEUTAS

  /// Criar ou atualizar perfil do terapeuta
  static Future<void> createOrUpdateTherapistProfile(Map<String, dynamic> therapistData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      _log('Criando/atualizando perfil do terapeuta: ${user.uid}');

      await _db.collection('therapists').doc(user.uid).set({
        'uid': user.uid,
        'name': therapistData['name'],
        'email': therapistData['email'],
        'photoUrl': therapistData['photoUrl'],
        'createdAt': FieldValue.serverTimestamp(),
        'lastAccess': FieldValue.serverTimestamp(),
        'maxPatients': maxPatientsPerTherapist,
        'activePatients': 0,
        'isActive': true,
      }, SetOptions(merge: true));

      _log('Perfil do terapeuta criado/atualizado com sucesso');
    } catch (e) {
      _log('ERRO ao criar perfil do terapeuta: $e');
      rethrow;
    }
  }

  /// Obter dados do terapeuta
  static Future<Map<String, dynamic>?> getTherapistData(String therapistId) async {
    try {
      _log('Obtendo dados do terapeuta: $therapistId');
      final doc = await _db.collection('therapists').doc(therapistId).get();
      
      if (doc.exists) {
        _log('Dados do terapeuta encontrados');
        return doc.data();
      } else {
        _log('Terapeuta não encontrado');
        return null;
      }
    } catch (e) {
      _log('ERRO ao obter dados do terapeuta: $e');
      return null;
    }
  }

  /// Atualizar último acesso do terapeuta
  static Future<void> updateTherapistLastAccess(String therapistId) async {
    try {
      await _db.collection('therapists').doc(therapistId).update({
        'lastAccess': FieldValue.serverTimestamp(),
      });
      _log('Último acesso do terapeuta atualizado');
    } catch (e) {
      _log('ERRO ao atualizar último acesso: $e');
    }
  }

  // 👥 GESTÃO DE PACIENTES

  /// Adicionar paciente Gmail
  static Future<String> addGmailPatient({
    required String therapistId,
    required String email,
    required String name,
    DateTime? birthDate,
    String? diagnosis,
  }) async {
    try {
      _log('Adicionando paciente Gmail: $email para terapeuta: $therapistId');

      // Verificar limite de pacientes
      if (!await canAddPatient(therapistId)) {
        throw Exception('Limite de $maxPatientsPerTherapist pacientes atingido');
      }

      // Verificar se email já existe
      final existingPatient = await _db
          .collectionGroup('patients')
          .where('email', isEqualTo: email.toLowerCase())
          .where('isActive', isEqualTo: true)
          .get();
      
      if (existingPatient.docs.isNotEmpty) {
        throw Exception('Email já cadastrado como paciente');
      }

      // Criar referência do paciente
      final patientRef = _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .doc();

      final patientData = {
        'id': patientRef.id,
        'email': email.toLowerCase(),
        'name': name,
        'birthDate': birthDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'diagnosis': diagnosis,
        'therapistId': therapistId,
        'isActive': true,
        'isAuthenticated': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastAccess': FieldValue.serverTimestamp(),
      };

      // Usar transação para garantir atomicidade
      await _db.runTransaction((transaction) async {
        // Adicionar paciente
        transaction.set(patientRef, patientData);
        
        // Incrementar contador de pacientes ativos
        transaction.update(
          _db.collection('therapists').doc(therapistId),
          {'activePatients': FieldValue.increment(1)},
        );
      });

      _log('Paciente Gmail adicionado com sucesso: ${patientRef.id}');
      return patientRef.id;
    } catch (e) {
      _log('ERRO ao adicionar paciente Gmail: $e');
      rethrow;
    }
  }

  /// Obter pacientes do terapeuta
  static Future<List<Learner>> getTherapistPatients(String therapistId) async {
    try {
      _log('Obtendo pacientes do terapeuta: $therapistId');
      
      final snapshot = await _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      final patients = snapshot.docs.map((doc) {
        final data = doc.data();
        return Learner(
          id: data['id'],
          name: data['name'],
          birthDate: DateTime.parse(data['birthDate']),
          diagnosis: data['diagnosis'],
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastAccess: (data['lastAccess'] as Timestamp?)?.toDate(),
          email: data['email'],
          therapistId: data['therapistId'],
          isActive: data['isActive'] ?? true,
          isAuthenticated: data['isAuthenticated'] ?? true,
        );
      }).toList();

      _log('${patients.length} pacientes encontrados');
      return patients;
    } catch (e) {
      _log('ERRO ao obter pacientes: $e');
      return [];
    }
  }

  /// Obter paciente por email
  static Future<Learner?> getPatientByEmail(String email) async {
    try {
      _log('Buscando paciente por email: $email');
      
      final snapshot = await _db
          .collectionGroup('patients')
          .where('email', isEqualTo: email.toLowerCase())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _log('Paciente não encontrado para email: $email');
        return null;
      }

      final data = snapshot.docs.first.data();
      final patient = Learner(
        id: data['id'],
        name: data['name'],
        birthDate: DateTime.parse(data['birthDate']),
        diagnosis: data['diagnosis'],
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastAccess: (data['lastAccess'] as Timestamp?)?.toDate(),
        email: data['email'],
        therapistId: data['therapistId'],
        isActive: data['isActive'] ?? true,
        isAuthenticated: data['isAuthenticated'] ?? true,
      );

      _log('Paciente encontrado: ${patient.name}');
      return patient;
    } catch (e) {
      _log('ERRO ao buscar paciente por email: $e');
      return null;
    }
  }

  /// Atualizar último acesso do paciente
  static Future<void> updatePatientLastAccess(String therapistId, String patientId) async {
    try {
      await _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .doc(patientId)
          .update({'lastAccess': FieldValue.serverTimestamp()});
      
      _log('Último acesso do paciente atualizado: $patientId');
    } catch (e) {
      _log('ERRO ao atualizar último acesso do paciente: $e');
    }
  }

  /// Remover paciente (marcar como inativo)
  static Future<void> removePatient(String therapistId, String patientId) async {
    try {
      _log('Removendo paciente: $patientId');

      await _db.runTransaction((transaction) async {
        // Marcar paciente como inativo
        transaction.update(
          _db.collection('therapists').doc(therapistId).collection('patients').doc(patientId),
          {'isActive': false, 'removedAt': FieldValue.serverTimestamp()},
        );
        
        // Decrementar contador de pacientes ativos
        transaction.update(
          _db.collection('therapists').doc(therapistId),
          {'activePatients': FieldValue.increment(-1)},
        );
      });

      _log('Paciente removido com sucesso');
    } catch (e) {
      _log('ERRO ao remover paciente: $e');
      rethrow;
    }
  }

  // 📈 PROGRESSO DOS TREINOS

  /// Salvar sessão de treino
  static Future<void> saveTrainingSession({
    required String therapistId,
    required String patientId,
    required String trainingType, // 'colors', 'shapes', 'quantities'
    required TrainingStats stats,
  }) async {
    try {
      _log('Salvando sessão de treino: $trainingType para paciente: $patientId');

      final sessionData = {
        'successes': stats.successes,
        'errors': stats.errors,
        'totalAttempts': stats.totalAttempts,
        'successPercentage': stats.successPercentage,
        'date': FieldValue.serverTimestamp(),
        'trainingType': trainingType,
        'deviceInfo': await _getDeviceInfo(),
      };

      // Salvar sessão individual
      await _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .doc(patientId)
          .collection('training_sessions')
          .add(sessionData);

      // Atualizar estatísticas gerais
      await _updateOverallProgress(therapistId, patientId, trainingType, stats);

      _log('Sessão de treino salva com sucesso');
    } catch (e) {
      _log('ERRO ao salvar sessão de treino: $e');
      rethrow;
    }
  }

  /// Atualizar progresso geral do paciente
  static Future<void> _updateOverallProgress(
    String therapistId,
    String patientId,
    String trainingType,
    TrainingStats stats,
  ) async {
    try {
      final progressRef = _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .doc(patientId)
          .collection('progress')
          .doc('overall');

      await _db.runTransaction((transaction) async {
        final doc = await transaction.get(progressRef);
        final data = doc.exists ? Map<String, dynamic>.from(doc.data()!) : <String, dynamic>{};

        // Atualizar estatísticas específicas do treino
        final sessionsKey = '${trainingType}SessionsCompleted';
        final successesKey = '${trainingType}TotalSuccesses';
        final attemptsKey = '${trainingType}TotalAttempts';
        final completedKey = '${trainingType}Completed';
        final starsKey = '${trainingType}Stars';

        data[sessionsKey] = (data[sessionsKey] ?? 0) + 1;
        data[successesKey] = (data[successesKey] ?? 0) + stats.successes;
        data[attemptsKey] = (data[attemptsKey] ?? 0) + stats.totalAttempts;
        
        // Calcular se treino foi "completado" (>50% de acerto na média)
        final totalAttempts = data[attemptsKey] as int;
        final totalSuccesses = data[successesKey] as int;
        final averageSuccess = totalAttempts > 0 ? (totalSuccesses / totalAttempts) * 100 : 0.0;
        
        if (averageSuccess >= 50 && !(data[completedKey] ?? false)) {
          data[completedKey] = true;
          
          // Calcular estrelas baseado no desempenho
          int stars = 1;
          if (averageSuccess >= 90) stars = 3;
          else if (averageSuccess >= 70) stars = 2;
          
          data[starsKey] = stars;
        }

        // Atualizar contadores gerais
        final completedTrainings = [
          data['colorsCompleted'] ?? false,
          data['shapesCompleted'] ?? false,
          data['quantitiesCompleted'] ?? false,
        ].where((completed) => completed).length;

        final totalStars = (data['colorsStars'] ?? 0) + 
                          (data['shapesStars'] ?? 0) + 
                          (data['quantitiesStars'] ?? 0);

        data['completedTrainings'] = completedTrainings;
        data['totalStars'] = totalStars;
        data['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.set(progressRef, data, SetOptions(merge: true));
      });

      _log('Progresso geral atualizado');
    } catch (e) {
      _log('ERRO ao atualizar progresso geral: $e');
    }
  }

  /// Obter progresso do paciente
  static Future<Map<String, dynamic>> getPatientProgress(
    String therapistId,
    String patientId,
  ) async {
    try {
      _log('Obtendo progresso do paciente: $patientId');
      
      final progressDoc = await _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .doc(patientId)
          .collection('progress')
          .doc('overall')
          .get();

      if (progressDoc.exists) {
        final data = progressDoc.data()!;
        _log('Progresso encontrado');
        return data;
      } else {
        _log('Nenhum progresso encontrado');
        return {};
      }
    } catch (e) {
      _log('ERRO ao obter progresso: $e');
      return {};
    }
  }

  /// Obter sessões de treino por tipo
  static Future<List<Map<String, dynamic>>> getTrainingSessions(
    String therapistId,
    String patientId, {
    String? trainingType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      _log('Obtendo sessões de treino para paciente: $patientId');
      
      Query query = _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .doc(patientId)
          .collection('training_sessions')
          .orderBy('date', descending: true);

      if (trainingType != null) {
        query = query.where('trainingType', isEqualTo: trainingType);
      }
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final sessions = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
        return data;
      }).toList();

      _log('${sessions.length} sessões encontradas');
      return sessions;
    } catch (e) {
      _log('ERRO ao obter sessões de treino: $e');
      return [];
    }
  }

  // 🔄 UTILITÁRIOS

  /// Obter informações do dispositivo
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': 'flutter',
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    };
  }

  /// Verificar se Firestore está disponível
  static Future<bool> isAvailable() async {
    try {
      await _db.enableNetwork();
      return true;
    } catch (e) {
      _log('Firestore não disponível: $e');
      return false;
    }
  }

  /// Obter estatísticas do terapeuta
  static Future<Map<String, dynamic>> getTherapistStats(String therapistId) async {
    try {
      _log('Obtendo estatísticas do terapeuta: $therapistId');
      
      final patients = await getTherapistPatients(therapistId);
      
      int totalSessions = 0;
      int activePatients = patients.where((p) => p.isActive).length;
      DateTime? lastActivity;

      for (final patient in patients) {
        // Contar sessões do paciente
        final sessions = await getTrainingSessions(therapistId, patient.id, limit: 1000);
        totalSessions += sessions.length;
        
        // Verificar última atividade
        if (patient.lastAccess != null) {
          if (lastActivity == null || patient.lastAccess!.isAfter(lastActivity)) {
            lastActivity = patient.lastAccess;
          }
        }
      }

      final stats = {
        'totalPatients': patients.length,
        'activePatients': activePatients,
        'totalSessions': totalSessions,
        'lastActivity': lastActivity?.toIso8601String(),
        'averageSessionsPerPatient': patients.isNotEmpty ? totalSessions / patients.length : 0.0,
      };

      _log('Estatísticas calculadas: $totalSessions sessões, $activePatients pacientes ativos');
      return stats;
    } catch (e) {
      _log('ERRO ao obter estatísticas: $e');
      return {};
    }
  }

  // 🛡️ CLEANUP E MANUTENÇÃO

  /// Limpar dados antigos (sessões > 1 ano)
  static Future<void> cleanupOldData(String therapistId, String patientId) async {
    try {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      
      final oldSessions = await _db
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .doc(patientId)
          .collection('training_sessions')
          .where('date', isLessThan: Timestamp.fromDate(oneYearAgo))
          .get();

      final batch = _db.batch();
      for (final doc in oldSessions.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _log('${oldSessions.docs.length} sessões antigas removidas');
    } catch (e) {
      _log('ERRO na limpeza de dados antigos: $e');
    }
  }
}