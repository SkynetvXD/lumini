// lib/services/progress_service_hybrid.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/training_stats.dart';
import 'firestore_service.dart';
import 'sync_service.dart';
import 'patient_auth_service.dart';
import 'learner_service.dart';
import 'auth_service.dart';

class ProgressService {
  static const String _colorTrainingKey = 'color_training_stats';
  static const String _shapeTrainingKey = 'shape_training_stats';
  static const String _quantityTrainingKey = 'quantity_training_stats';
  static const String _overallProgressKey = 'overall_progress';
  
  static const bool _debugMode = kDebugMode;

  static void _log(String message) {
    if (_debugMode) {
      print('📊 ProgressService: $message');
    }
  }

  // 🔄 ESTRATÉGIA HÍBRIDA

  /// Determinar se deve usar Firestore ou dados locais
  static Future<bool> _shouldUseFirestore() async {
    if (!SyncService.isOnline) return false;
    
    try {
      final patient = await PatientAuthService.getPatientData();
      return patient != null && patient.isAuthenticated && patient.therapistId != null;
    } catch (e) {
      return false;
    }
  }

  /// Obter chave única baseada no tipo de usuário
  static Future<String> _getUniqueKey(String baseKey) async {
    try {
      // Verificar se é paciente Gmail autenticado
      final isPatientLoggedIn = await PatientAuthService.isPatientLoggedIn();
      if (isPatientLoggedIn) {
        final patientId = await PatientAuthService.getPatientUniqueId();
        if (patientId != null) {
          return '${baseKey}_patient_$patientId';
        }
      }
      
      // Verificar se é learner local
      final currentLearner = await LearnerService.getCurrentLearner();
      if (currentLearner != null && !currentLearner.isAuthenticated) {
        return '${baseKey}_learner_${currentLearner.id}';
      }
    } catch (e) {
      _log('ERRO ao obter chave única: $e');
    }
    
    // Fallback para sistema antigo
    return baseKey;
  }

  // 💾 SALVAR ESTATÍSTICAS (HÍBRIDO)

  /// Salvar estatísticas de treinamento de cores
  static Future<bool> saveColorTrainingStats(TrainingStats stats) async {
    _log('Salvando estatísticas de cores: ${stats.successPercentage.toStringAsFixed(1)}%');
    
    bool firestoreSuccess = false;
    bool localSuccess = false;

    // 1. Tentar salvar no Firestore primeiro
    if (await _shouldUseFirestore()) {
      try {
        final patient = await PatientAuthService.getPatientData();
        if (patient != null && patient.therapistId != null) {
          await FirestoreService.saveTrainingSession(
            therapistId: patient.therapistId!,
            patientId: patient.id,
            trainingType: 'colors',
            stats: stats,
          );
          firestoreSuccess = true;
          _log('Dados salvos no Firestore com sucesso');
        }
      } catch (e) {
        _log('ERRO no Firestore, usando fallback local: $e');
        // Adicionar à fila de sincronização para tentar depois
        await SyncService.addPendingTrainingData(
          trainingType: 'colors',
          stats: stats,
        );
      }
    }

    // 2. SEMPRE salvar localmente também (backup/cache)
    try {
      localSuccess = await _saveColorTrainingStatsLocal(stats);
      if (localSuccess) {
        _log('Dados salvos localmente como backup');
      }
    } catch (e) {
      _log('ERRO ao salvar localmente: $e');
    }

    return firestoreSuccess || localSuccess;
  }

  /// Salvar estatísticas de treinamento de formas
  static Future<bool> saveShapeTrainingStats(TrainingStats stats) async {
    _log('Salvando estatísticas de formas: ${stats.successPercentage.toStringAsFixed(1)}%');
    
    bool firestoreSuccess = false;
    bool localSuccess = false;

    // Firestore
    if (await _shouldUseFirestore()) {
      try {
        final patient = await PatientAuthService.getPatientData();
        if (patient != null && patient.therapistId != null) {
          await FirestoreService.saveTrainingSession(
            therapistId: patient.therapistId!,
            patientId: patient.id,
            trainingType: 'shapes',
            stats: stats,
          );
          firestoreSuccess = true;
          _log('Dados salvos no Firestore com sucesso');
        }
      } catch (e) {
        _log('ERRO no Firestore: $e');
        await SyncService.addPendingTrainingData(
          trainingType: 'shapes',
          stats: stats,
        );
      }
    }

    // Local backup
    try {
      localSuccess = await _saveShapeTrainingStatsLocal(stats);
    } catch (e) {
      _log('ERRO ao salvar localmente: $e');
    }

    return firestoreSuccess || localSuccess;
  }

  /// Salvar estatísticas de treinamento de quantidades
  static Future<bool> saveQuantityTrainingStats(TrainingStats stats) async {
    _log('Salvando estatísticas de quantidades: ${stats.successPercentage.toStringAsFixed(1)}%');
    
    bool firestoreSuccess = false;
    bool localSuccess = false;

    // Firestore
    if (await _shouldUseFirestore()) {
      try {
        final patient = await PatientAuthService.getPatientData();
        if (patient != null && patient.therapistId != null) {
          await FirestoreService.saveTrainingSession(
            therapistId: patient.therapistId!,
            patientId: patient.id,
            trainingType: 'quantities',
            stats: stats,
          );
          firestoreSuccess = true;
          _log('Dados salvos no Firestore com sucesso');
        }
      } catch (e) {
        _log('ERRO no Firestore: $e');
        await SyncService.addPendingTrainingData(
          trainingType: 'quantities',
          stats: stats,
        );
      }
    }

    // Local backup
    try {
      localSuccess = await _saveQuantityTrainingStatsLocal(stats);
    } catch (e) {
      _log('ERRO ao salvar localmente: $e');
    }

    return firestoreSuccess || localSuccess;
  }

  // 📊 OBTER ESTATÍSTICAS (HÍBRIDO)

  /// Obter progresso geral (Firestore primeiro, depois local)
  static Future<Map<String, dynamic>> getOverallProgress() async {
    _log('Obtendo progresso geral');

    // 1. Tentar obter do Firestore primeiro
    if (await _shouldUseFirestore()) {
      try {
        final patient = await PatientAuthService.getPatientData();
        if (patient != null && patient.therapistId != null) {
          final progress = await FirestoreService.getPatientProgress(
            patient.therapistId!,
            patient.id,
          );
          
          if (progress.isNotEmpty) {
            final formattedProgress = _formatFirestoreProgress(progress);
            _log('Progresso obtido do Firestore');
            return formattedProgress;
          }
        }
      } catch (e) {
        _log('ERRO ao obter do Firestore: $e');
      }
    }

    // 2. Fallback para dados locais
    try {
      final localProgress = await _getOverallProgressLocal();
      _log('Progresso obtido localmente');
      return localProgress;
    } catch (e) {
      _log('ERRO ao obter dados locais: $e');
      return _getDefaultProgress();
    }
  }

  /// Obter estatísticas de cores (Firestore primeiro, depois local)
  static Future<List<Map<String, dynamic>>> getColorTrainingStats() async {
    _log('Obtendo estatísticas de cores');

    // Firestore
    if (await _shouldUseFirestore()) {
      try {
        final patient = await PatientAuthService.getPatientData();
        if (patient != null && patient.therapistId != null) {
          final sessions = await FirestoreService.getTrainingSessions(
            patient.therapistId!,
            patient.id,
            trainingType: 'colors',
          );
          
          if (sessions.isNotEmpty) {
            _log('${sessions.length} sessões de cores obtidas do Firestore');
            return sessions;
          }
        }
      } catch (e) {
        _log('ERRO ao obter do Firestore: $e');
      }
    }

    // Local fallback
    return await _getColorTrainingStatsLocal();
  }

  /// Obter estatísticas de formas
  static Future<List<Map<String, dynamic>>> getShapeTrainingStats() async {
    if (await _shouldUseFirestore()) {
      try {
        final patient = await PatientAuthService.getPatientData();
        if (patient != null && patient.therapistId != null) {
          final sessions = await FirestoreService.getTrainingSessions(
            patient.therapistId!,
            patient.id,
            trainingType: 'shapes',
          );
          
          if (sessions.isNotEmpty) {
            return sessions;
          }
        }
      } catch (e) {
        _log('ERRO ao obter formas do Firestore: $e');
      }
    }

    return await _getShapeTrainingStatsLocal();
  }

  /// Obter estatísticas de quantidades
  static Future<List<Map<String, dynamic>>> getQuantityTrainingStats() async {
    if (await _shouldUseFirestore()) {
      try {
        final patient = await PatientAuthService.getPatientData();
        if (patient != null && patient.therapistId != null) {
          final sessions = await FirestoreService.getTrainingSessions(
            patient.therapistId!,
            patient.id,
            trainingType: 'quantities',
          );
          
          if (sessions.isNotEmpty) {
            return sessions;
          }
        }
      } catch (e) {
        _log('ERRO ao obter quantidades do Firestore: $e');
      }
    }

    return await _getQuantityTrainingStatsLocal();
  }

  // 🏆 CONCLUSÃO DE TREINOS

  /// Marcar treino de cores como concluído
  static Future<bool> markColorTrainingCompleted() async {
    _log('Marcando treino de cores como concluído');
    
    // Sempre atualizar dados locais
    final localSuccess = await _markColorTrainingCompletedLocal();
    
    // Tentar atualizar no Firestore também
    if (await _shouldUseFirestore()) {
      try {
        // O Firestore atualiza automaticamente quando salvamos sessões
        // Então só precisamos garantir que os dados locais estejam corretos
        _log('Conclusão de cores será sincronizada automaticamente');
      } catch (e) {
        _log('ERRO ao marcar conclusão no Firestore: $e');
      }
    }
    
    return localSuccess;
  }

  /// Marcar treino de formas como concluído
  static Future<bool> markShapeTrainingCompleted() async {
    _log('Marcando treino de formas como concluído');
    return await _markShapeTrainingCompletedLocal();
  }

  /// Marcar treino de quantidades como concluído
  static Future<bool> markQuantityTrainingCompleted() async {
    _log('Marcando treino de quantidades como concluído');
    return await _markQuantityTrainingCompletedLocal();
  }

  // 🗑️ LIMPEZA

  /// Limpar todos os dados de progresso
  static Future<bool> clearAllProgress() async {
    _log('Limpando todos os dados de progresso');
    
    // Sempre limpar dados locais
    bool localCleared = false;
    try {
      localCleared = await _clearAllProgressLocal();
    } catch (e) {
      _log('ERRO ao limpar dados locais: $e');
    }
    
    // Limpar dados pendentes de sync
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_training_data');
    } catch (e) {
      _log('ERRO ao limpar dados pendentes: $e');
    }
    
    return localCleared;
  }

  // 🔧 MÉTODOS AUXILIARES

  /// Formatar dados do Firestore para o formato esperado
  static Map<String, dynamic> _formatFirestoreProgress(Map<String, dynamic> firestoreData) {
    return {
      'completedTrainings': firestoreData['completedTrainings'] ?? 0,
      'totalStars': firestoreData['totalStars'] ?? 0,
      'colorTrainingCompleted': firestoreData['colorsCompleted'] ?? false,
      'shapeTrainingCompleted': firestoreData['shapesCompleted'] ?? false,
      'quantityTrainingCompleted': firestoreData['quantitiesCompleted'] ?? false,
    };
  }

  /// Obter progresso padrão
  static Map<String, dynamic> _getDefaultProgress() {
    return {
      'completedTrainings': 0,
      'totalStars': 0,
      'colorTrainingCompleted': false,
      'shapeTrainingCompleted': false,
      'quantityTrainingCompleted': false,
    };
  }

  // 💾 MÉTODOS LOCAIS (CÓDIGO ORIGINAL ADAPTADO)

  /// Salvar estatísticas de cores localmente
  static Future<bool> _saveColorTrainingStatsLocal(TrainingStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_colorTrainingKey);
    
    final statsMap = {
      'successes': stats.successes,
      'errors': stats.errors,
      'totalAttempts': stats.totalAttempts,
      'date': DateTime.now().toIso8601String(),
    };
    
    List<String> statsList = prefs.getStringList(key) ?? [];
    statsList.add(jsonEncode(statsMap));
    
    return await prefs.setStringList(key, statsList);
  }

  /// Salvar estatísticas de formas localmente
  static Future<bool> _saveShapeTrainingStatsLocal(TrainingStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_shapeTrainingKey);
    
    final statsMap = {
      'successes': stats.successes,
      'errors': stats.errors,
      'totalAttempts': stats.totalAttempts,
      'date': DateTime.now().toIso8601String(),
    };
    
    List<String> statsList = prefs.getStringList(key) ?? [];
    statsList.add(jsonEncode(statsMap));
    
    return await prefs.setStringList(key, statsList);
  }

  /// Salvar estatísticas de quantidades localmente
  static Future<bool> _saveQuantityTrainingStatsLocal(TrainingStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_quantityTrainingKey);
    
    final statsMap = {
      'successes': stats.successes,
      'errors': stats.errors,
      'totalAttempts': stats.totalAttempts,
      'date': DateTime.now().toIso8601String(),
    };
    
    List<String> statsList = prefs.getStringList(key) ?? [];
    statsList.add(jsonEncode(statsMap));
    
    return await prefs.setStringList(key, statsList);
  }

  /// Obter progresso geral local
  static Future<Map<String, dynamic>> _getOverallProgressLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_overallProgressKey);
    
    String? progressJson = prefs.getString(key);
    
    if (progressJson == null) {
      return _getDefaultProgress();
    }
    
    final Map<String, dynamic> progressMap = Map<String, dynamic>.from(jsonDecode(progressJson));
    
    // Garantir que todos os campos existam
    progressMap['colorTrainingCompleted'] ??= false;
    progressMap['shapeTrainingCompleted'] ??= false;
    progressMap['quantityTrainingCompleted'] ??= false;
    
    return progressMap;
  }

  /// Obter estatísticas de cores locais
  static Future<List<Map<String, dynamic>>> _getColorTrainingStatsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_colorTrainingKey);
    
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  /// Obter estatísticas de formas locais
  static Future<List<Map<String, dynamic>>> _getShapeTrainingStatsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_shapeTrainingKey);
    
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  /// Obter estatísticas de quantidades locais
  static Future<List<Map<String, dynamic>>> _getQuantityTrainingStatsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_quantityTrainingKey);
    
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  /// Marcar treino de cores como concluído localmente
  static Future<bool> _markColorTrainingCompletedLocal() async {
    final progress = await _getOverallProgressLocal();
    
    if (progress['colorTrainingCompleted'] == true) {
      return true;
    }
    
    progress['colorTrainingCompleted'] = true;
    progress['completedTrainings'] = (progress['completedTrainings'] as int) + 1;
    
    final avgStats = await getLastColorTrainingStats();
    if (avgStats != null) {
      int stars = 0;
      double successRate = avgStats.successPercentage;
      
      if (successRate >= 90) stars = 3;
      else if (successRate >= 70) stars = 2;
      else stars = 1;
      
      progress['totalStars'] = (progress['totalStars'] as int) + stars;
    }
    
    return await _updateOverallProgressLocal(progress);
  }

  /// Marcar treino de formas como concluído localmente
  static Future<bool> _markShapeTrainingCompletedLocal() async {
    final progress = await _getOverallProgressLocal();
    
    if (progress['shapeTrainingCompleted'] == true) {
      return true;
    }
    
    progress['shapeTrainingCompleted'] = true;
    progress['completedTrainings'] = (progress['completedTrainings'] as int) + 1;
    
    final avgStats = await getLastShapeTrainingStats();
    if (avgStats != null) {
      int stars = 0;
      double successRate = avgStats.successPercentage;
      
      if (successRate >= 90) stars = 3;
      else if (successRate >= 70) stars = 2;
      else stars = 1;
      
      progress['totalStars'] = (progress['totalStars'] as int) + stars;
    }
    
    return await _updateOverallProgressLocal(progress);
  }

  /// Marcar treino de quantidades como concluído localmente
  static Future<bool> _markQuantityTrainingCompletedLocal() async {
    final progress = await _getOverallProgressLocal();
    
    if (progress['quantityTrainingCompleted'] == true) {
      return true;
    }
    
    progress['quantityTrainingCompleted'] = true;
    progress['completedTrainings'] = (progress['completedTrainings'] as int) + 1;
    
    final avgStats = await getLastQuantityTrainingStats();
    if (avgStats != null) {
      int stars = 0;
      double successRate = avgStats.successPercentage;
      
      if (successRate >= 90) stars = 3;
      else if (successRate >= 70) stars = 2;
      else stars = 1;
      
      progress['totalStars'] = (progress['totalStars'] as int) + stars;
    }
    
    return await _updateOverallProgressLocal(progress);
  }

  /// Atualizar progresso geral local
  static Future<bool> _updateOverallProgressLocal(Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_overallProgressKey);
    return await prefs.setString(key, jsonEncode(progress));
  }

  /// Limpar todos os dados locais
  static Future<bool> _clearAllProgressLocal() async {
    final prefs = await SharedPreferences.getInstance();
    
    final colorKey = await _getUniqueKey(_colorTrainingKey);
    final shapeKey = await _getUniqueKey(_shapeTrainingKey);
    final quantityKey = await _getUniqueKey(_quantityTrainingKey);
    final overallKey = await _getUniqueKey(_overallProgressKey);
    
    await prefs.remove(colorKey);
    await prefs.remove(shapeKey);
    await prefs.remove(quantityKey);
    await prefs.remove(overallKey);
    
    return true;
  }

  // 📈 MÉTODOS DE COMPATIBILIDADE

  /// Obter última estatística de cores (compatibilidade)
  static Future<TrainingStats?> getLastColorTrainingStats() async {
    final statsList = await getColorTrainingStats();
    
    if (statsList.isEmpty) {
      return null;
    }
    
    final lastStatsMap = statsList.last;
    return TrainingStats(
      successes: lastStatsMap['successes'],
      errors: lastStatsMap['errors'],
      totalAttempts: lastStatsMap['totalAttempts'],
    );
  }

  /// Obter última estatística de formas (compatibilidade)
  static Future<TrainingStats?> getLastShapeTrainingStats() async {
    final statsList = await getShapeTrainingStats();
    
    if (statsList.isEmpty) {
      return null;
    }
    
    final lastStatsMap = statsList.last;
    return TrainingStats(
      successes: lastStatsMap['successes'],
      errors: lastStatsMap['errors'],
      totalAttempts: lastStatsMap['totalAttempts'],
    );
  }

  /// Obter última estatística de quantidades (compatibilidade)
  static Future<TrainingStats?> getLastQuantityTrainingStats() async {
    final statsList = await getQuantityTrainingStats();
    
    if (statsList.isEmpty) {
      return null;
    }
    
    final lastStatsMap = statsList.last;
    return TrainingStats(
      successes: lastStatsMap['successes'],
      errors: lastStatsMap['errors'],
      totalAttempts: lastStatsMap['totalAttempts'],
    );
  }

  /// Obter estatísticas médias de cores (compatibilidade)
  static Future<TrainingStats?> getAverageColorTrainingStats() async {
    final statsList = await getColorTrainingStats();
    
    if (statsList.isEmpty) {
      return null;
    }
    
    int totalSuccesses = 0;
    int totalErrors = 0;
    int totalAttempts = 0;
    
    for (var stats in statsList) {
      totalSuccesses += stats['successes'] as int;
      totalErrors += stats['errors'] as int;
      totalAttempts += stats['totalAttempts'] as int;
    }
    
    return TrainingStats(
      successes: totalSuccesses ~/ statsList.length,
      errors: totalErrors ~/ statsList.length,
      totalAttempts: totalAttempts ~/ statsList.length,
    );
  }

  // 🔄 MIGRAÇÃO (MANTIDO PARA COMPATIBILIDADE)

  /// Migrar dados antigos para novo sistema
  static Future<void> migrateOldDataToNewSystem() async {
    try {
      _log('Verificando necessidade de migração...');
      // A migração real acontece no SyncService
      // Este método é mantido para compatibilidade
    } catch (e) {
      _log('ERRO na migração: $e');
    }
  }

  /// Função para gerar mensagem personalizada de acordo com o desempenho
  static String getPerformanceMessage(double successPercentage) {
    if (successPercentage >= 90) {
      return "Incrível! Você é um verdadeiro expert! 🌟";
    } else if (successPercentage >= 70) {
      return "Muito bom! Você tem um ótimo conhecimento! 😃";
    } else if (successPercentage >= 50) {
      return "Bom trabalho! Continue praticando para melhorar! 👍";
    } else {
      return "Vamos praticar mais! A cada tentativa você vai melhorar! 💪";
    }
  }

  // 🆕 MÉTODOS ESPECÍFICOS PARA PACIENTES (PARA TERAPEUTAS)

  /// Obter estatísticas de cores de um paciente específico (para terapeutas)
  static Future<List<Map<String, dynamic>>> getPatientColorTrainingStats(String patientId) async {
    try {
      // Buscar dados do terapeuta atual
      final therapistData = await AuthService.getTherapistData();
      if (therapistData != null) {
        return await FirestoreService.getTrainingSessions(
          therapistData['uid'],
          patientId,
          trainingType: 'colors',
        );
      }
    } catch (e) {
      _log('ERRO ao obter stats de cores do paciente: $e');
    }
    
    return [];
  }

  /// Obter estatísticas de formas de um paciente específico (para terapeutas)
  static Future<List<Map<String, dynamic>>> getPatientShapeTrainingStats(String patientId) async {
    try {
      final therapistData = await AuthService.getTherapistData();
      if (therapistData != null) {
        return await FirestoreService.getTrainingSessions(
          therapistData['uid'],
          patientId,
          trainingType: 'shapes',
        );
      }
    } catch (e) {
      _log('ERRO ao obter stats de formas do paciente: $e');
    }
    
    return [];
  }

  /// Obter estatísticas de quantidades de um paciente específico (para terapeutas)
  static Future<List<Map<String, dynamic>>> getPatientQuantityTrainingStats(String patientId) async {
    try {
      final therapistData = await AuthService.getTherapistData();
      if (therapistData != null) {
        return await FirestoreService.getTrainingSessions(
          therapistData['uid'],
          patientId,
          trainingType: 'quantities',
        );
      }
    } catch (e) {
      _log('ERRO ao obter stats de quantidades do paciente: $e');
    }
    
    return [];
  }

  /// Obter progresso geral de um paciente específico (para terapeutas)
  static Future<Map<String, dynamic>> getPatientOverallProgress(String patientId) async {
    try {
      final therapistData = await AuthService.getTherapistData();
      if (therapistData != null) {
        final progress = await FirestoreService.getPatientProgress(
          therapistData['uid'],
          patientId,
        );
        return _formatFirestoreProgress(progress);
      }
    } catch (e) {
      _log('ERRO ao obter progresso do paciente: $e');
    }
    
    return _getDefaultProgress();
  }

  /// Obter estatísticas resumidas de um paciente (para terapeutas)
  static Future<Map<String, dynamic>> getPatientSummaryStats(String patientId) async {
    try {
      final colorStats = await getPatientColorTrainingStats(patientId);
      final shapeStats = await getPatientShapeTrainingStats(patientId);
      final quantityStats = await getPatientQuantityTrainingStats(patientId);
      final overallProgress = await getPatientOverallProgress(patientId);

      // Calcular estatísticas resumidas
      Map<String, dynamic> colorSummary = _calculateTrainingSummary(colorStats);
      Map<String, dynamic> shapeSummary = _calculateTrainingSummary(shapeStats);
      Map<String, dynamic> quantitySummary = _calculateTrainingSummary(quantityStats);

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
        'overallProgress': overallProgress,
        'colorTraining': colorSummary,
        'shapeTraining': shapeSummary,
        'quantityTraining': quantitySummary,
        'lastActivity': lastActivity?.toIso8601String(),
        'totalSessions': colorStats.length + shapeStats.length + quantityStats.length,
      };
    } catch (e) {
      _log('ERRO ao obter resumo do paciente: $e');
      return {
        'patientId': patientId,
        'totalSessions': 0,
        'overallProgress': _getDefaultProgress(),
      };
    }
  }

  /// Calcular resumo de um tipo de treino
  static Map<String, dynamic> _calculateTrainingSummary(List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) {
      return {
        'totalSessions': 0,
        'totalSuccesses': 0,
        'totalErrors': 0,
        'totalAttempts': 0,
        'averageSuccessRate': 0.0,
        'lastSession': null,
        'bestPerformance': 0.0,
        'trend': 'stable',
      };
    }

    int totalSessions = stats.length;
    int totalSuccesses = 0;
    int totalErrors = 0;
    int totalAttempts = 0;
    double bestPerformance = 0.0;
    
    List<double> successRates = [];

    for (var stat in stats) {
      int successes = stat['successes'] as int;
      int errors = stat['errors'] as int;
      int attempts = stat['totalAttempts'] as int;
      
      totalSuccesses += successes;
      totalErrors += errors;
      totalAttempts += attempts;
      
      double successRate = attempts > 0 ? (successes / attempts) * 100 : 0.0;
      successRates.add(successRate);
      
      if (successRate > bestPerformance) {
        bestPerformance = successRate;
      }
    }

    double averageSuccessRate = totalAttempts > 0 ? (totalSuccesses / totalAttempts) * 100 : 0.0;
    
    // Calcular tendência
    String trend = 'stable';
    if (successRates.length >= 6) {
      final recent = successRates.skip(successRates.length - 3).toList();
      final previous = successRates.skip(successRates.length - 6).take(3).toList();
      
      double recentAvg = recent.reduce((a, b) => a + b) / recent.length;
      double previousAvg = previous.reduce((a, b) => a + b) / previous.length;
      
      if (recentAvg > previousAvg + 5) {
        trend = 'improving';
      } else if (recentAvg < previousAvg - 5) {
        trend = 'declining';
      }
    }

    return {
      'totalSessions': totalSessions,
      'totalSuccesses': totalSuccesses,
      'totalErrors': totalErrors,
      'totalAttempts': totalAttempts,
      'averageSuccessRate': averageSuccessRate,
      'lastSession': stats.isNotEmpty ? stats.last['date'] : null,
      'bestPerformance': bestPerformance,
      'trend': trend,
    };
  }
}