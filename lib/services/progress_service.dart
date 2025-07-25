import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_stats.dart';
import 'patient_auth_service.dart';
import 'learner_service.dart';

class ProgressService {
  static const String _colorTrainingKey = 'color_training_stats';
  static const String _shapeTrainingKey = 'shape_training_stats';
  static const String _sequenceTrainingKey = 'sequence_training_stats';
  static const String _imageAssociationKey = 'image_association_stats';
  static const String _quantityTrainingKey = 'quantity_training_stats';
  static const String _puzzleTrainingKey = 'puzzle_training_stats';
  static const String _overallProgressKey = 'overall_progress';

  // Obter chave única baseada no tipo de usuário (Gmail ou Local)
  static Future<String> _getUniqueKey(String baseKey) async {
    // Verificar se é paciente autenticado por Gmail
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
    
    // Fallback para sistema antigo (compatibilidade)
    return baseKey;
  }

  // 🆕 MÉTODOS ESPECÍFICOS PARA PACIENTES (PARA USO DO TERAPEUTA)

  // Obter chave específica de um paciente Gmail
  static String _getPatientSpecificKey(String baseKey, String patientId) {
    return '${baseKey}_patient_$patientId';
  }

  // Obter estatísticas de cores de um paciente específico
  static Future<List<Map<String, dynamic>>> getPatientColorTrainingStats(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPatientSpecificKey(_colorTrainingKey, patientId);
    
    final statsList = prefs.getStringList(key) ?? [];
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  // Obter estatísticas de formas de um paciente específico
  static Future<List<Map<String, dynamic>>> getPatientShapeTrainingStats(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPatientSpecificKey(_shapeTrainingKey, patientId);
    
    final statsList = prefs.getStringList(key) ?? [];
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  // Obter estatísticas de quantidades de um paciente específico
  static Future<List<Map<String, dynamic>>> getPatientQuantityTrainingStats(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPatientSpecificKey(_quantityTrainingKey, patientId);
    
    final statsList = prefs.getStringList(key) ?? [];
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  // Obter progresso geral de um paciente específico
  static Future<Map<String, dynamic>> getPatientOverallProgress(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPatientSpecificKey(_overallProgressKey, patientId);
    
    final progressJson = prefs.getString(key);
    
    if (progressJson == null) {
      return {
        'completedTrainings': 0,
        'totalStars': 0,
        'colorTrainingCompleted': false,
        'shapeTrainingCompleted': false,
        'sequenceTrainingCompleted': false,
        'imageAssociationCompleted': false,
        'quantityTrainingCompleted': false,
        'puzzleTrainingCompleted': false,
      };
    }
    
    final Map<String, dynamic> progressMap = Map<String, dynamic>.from(jsonDecode(progressJson));
    
    // Garantir que todos os campos existam
    if (!progressMap.containsKey('colorTrainingCompleted')) {
      progressMap['colorTrainingCompleted'] = false;
    }
    if (!progressMap.containsKey('shapeTrainingCompleted')) {
      progressMap['shapeTrainingCompleted'] = false;
    }
    if (!progressMap.containsKey('sequenceTrainingCompleted')) {
      progressMap['sequenceTrainingCompleted'] = false;
    }
    if (!progressMap.containsKey('imageAssociationCompleted')) {
      progressMap['imageAssociationCompleted'] = false;
    }
    if (!progressMap.containsKey('quantityTrainingCompleted')) {
      progressMap['quantityTrainingCompleted'] = false;
    }
    if (!progressMap.containsKey('puzzleTrainingCompleted')) {
      progressMap['puzzleTrainingCompleted'] = false;
    }
    
    return progressMap;
  }

  // Obter estatísticas resumidas de um paciente específico
  static Future<Map<String, dynamic>> getPatientSummaryStats(String patientId) async {
    final colorStats = await getPatientColorTrainingStats(patientId);
    final shapeStats = await getPatientShapeTrainingStats(patientId);
    final quantityStats = await getPatientQuantityTrainingStats(patientId);
    final overallProgress = await getPatientOverallProgress(patientId);

    // Calcular estatísticas de cada tipo de treino
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
  }

  // Calcular resumo de um tipo de treino
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
        'trend': 'stable', // stable, improving, declining
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
    
    // Calcular tendência (baseado nas últimas 3 sessões vs 3 anteriores)
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

  // 🔄 MÉTODOS ORIGINAIS (MANTIDOS PARA COMPATIBILIDADE)

  // Salvar estatísticas de treinamento de cores
  static Future<bool> saveColorTrainingStats(TrainingStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_colorTrainingKey);
    
    // Converter para mapa e depois para JSON
    final statsMap = {
      'successes': stats.successes,
      'errors': stats.errors,
      'totalAttempts': stats.totalAttempts,
      'date': DateTime.now().toIso8601String(),
    };
    
    // Obter a lista atual se existir
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    // Adicionar nova entrada
    statsList.add(jsonEncode(statsMap));
    
    // Salvar lista atualizada
    return await prefs.setStringList(key, statsList);
  }

  // Obter todas as estatísticas de treinamento de cores
  static Future<List<Map<String, dynamic>>> getColorTrainingStats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_colorTrainingKey);
    
    // Obter a lista de JSON
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    // Converter para lista de mapas
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  // Obter a última estatística de treinamento de cores
  static Future<TrainingStats?> getLastColorTrainingStats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_colorTrainingKey);
    
    // Obter a lista de JSON
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    if (statsList.isEmpty) {
      return null;
    }
    
    // Pegar o último item e converter para TrainingStats
    final lastStatsMap = jsonDecode(statsList.last);
    return TrainingStats(
      successes: lastStatsMap['successes'],
      errors: lastStatsMap['errors'],
      totalAttempts: lastStatsMap['totalAttempts'],
    );
  }

  // Calcular estatísticas médias para treinamento de cores
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

  // Salvar estatísticas de treinamento de formas
  static Future<bool> saveShapeTrainingStats(TrainingStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_shapeTrainingKey);
    
    // Converter para mapa e depois para JSON
    final statsMap = {
      'successes': stats.successes,
      'errors': stats.errors,
      'totalAttempts': stats.totalAttempts,
      'date': DateTime.now().toIso8601String(),
    };
    
    // Obter a lista atual se existir
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    // Adicionar nova entrada
    statsList.add(jsonEncode(statsMap));
    
    // Salvar lista atualizada
    return await prefs.setStringList(key, statsList);
  }

  // Obter todas as estatísticas de treinamento de formas
  static Future<List<Map<String, dynamic>>> getShapeTrainingStats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_shapeTrainingKey);
    
    // Obter a lista de JSON
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    // Converter para lista de mapas
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  // Obter a última estatística de treinamento de formas
  static Future<TrainingStats?> getLastShapeTrainingStats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_shapeTrainingKey);
    
    // Obter a lista de JSON
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    if (statsList.isEmpty) {
      return null;
    }
    
    // Pegar o último item e converter para TrainingStats
    final lastStatsMap = jsonDecode(statsList.last);
    return TrainingStats(
      successes: lastStatsMap['successes'],
      errors: lastStatsMap['errors'],
      totalAttempts: lastStatsMap['totalAttempts'],
    );
  }
  
  // Salvar estatísticas de treinamento de quantidades
  static Future<bool> saveQuantityTrainingStats(TrainingStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_quantityTrainingKey);
    
    // Converter para mapa e depois para JSON
    final statsMap = {
      'successes': stats.successes,
      'errors': stats.errors,
      'totalAttempts': stats.totalAttempts,
      'date': DateTime.now().toIso8601String(),
    };
    
    // Obter a lista atual se existir
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    // Adicionar nova entrada
    statsList.add(jsonEncode(statsMap));
    
    // Salvar lista atualizada
    return await prefs.setStringList(key, statsList);
  }

  // Obter todas as estatísticas de treinamento de quantidades
  static Future<List<Map<String, dynamic>>> getQuantityTrainingStats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_quantityTrainingKey);
    
    // Obter a lista de JSON
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    // Converter para lista de mapas
    return statsList.map((statsJson) => 
      Map<String, dynamic>.from(jsonDecode(statsJson))).toList();
  }

  // Obter a última estatística de treinamento de quantidades
  static Future<TrainingStats?> getLastQuantityTrainingStats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_quantityTrainingKey);
    
    // Obter a lista de JSON
    List<String> statsList = prefs.getStringList(key) ?? [];
    
    if (statsList.isEmpty) {
      return null;
    }
    
    // Pegar o último item e converter para TrainingStats
    final lastStatsMap = jsonDecode(statsList.last);
    return TrainingStats(
      successes: lastStatsMap['successes'],
      errors: lastStatsMap['errors'],
      totalAttempts: lastStatsMap['totalAttempts'],
    );
  }

  // Obter progresso geral (todos os treinamentos combinados)
  static Future<Map<String, dynamic>> getOverallProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_overallProgressKey);
    
    // Obter o progresso geral se existir
    String? progressJson = prefs.getString(key);
    
    if (progressJson == null) {
      return {
        'completedTrainings': 0,
        'totalStars': 0,
        'colorTrainingCompleted': false,
        'shapeTrainingCompleted': false,
        'sequenceTrainingCompleted': false,
        'imageAssociationCompleted': false,
        'quantityTrainingCompleted': false,
        'puzzleTrainingCompleted': false,
      };
    }
    
    // Ensure all fields exist in the returned map
    final Map<String, dynamic> progressMap = Map<String, dynamic>.from(jsonDecode(progressJson));
    
    // Add missing fields with defaults if necessary
    if (!progressMap.containsKey('colorTrainingCompleted')) {
      progressMap['colorTrainingCompleted'] = false;
    }
    if (!progressMap.containsKey('shapeTrainingCompleted')) {
      progressMap['shapeTrainingCompleted'] = false;
    }
    if (!progressMap.containsKey('sequenceTrainingCompleted')) {
      progressMap['sequenceTrainingCompleted'] = false;
    }
    if (!progressMap.containsKey('imageAssociationCompleted')) {
      progressMap['imageAssociationCompleted'] = false;
    }
    if (!progressMap.containsKey('quantityTrainingCompleted')) {
      progressMap['quantityTrainingCompleted'] = false;
    }
    if (!progressMap.containsKey('puzzleTrainingCompleted')) {
      progressMap['puzzleTrainingCompleted'] = false;
    }
    
    return progressMap;
  }

  // Atualizar progresso geral
  static Future<bool> updateOverallProgress(Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getUniqueKey(_overallProgressKey);
    return await prefs.setString(key, jsonEncode(progress));
  }

  // Atualizar status de conclusão para o treinamento de cores
  static Future<bool> markColorTrainingCompleted() async {
    final progress = await getOverallProgress();
    
    // Se já estiver marcado como concluído, não faz nada
    if (progress['colorTrainingCompleted'] == true) {
      return true;
    }
    
    // Atualizar valores
    progress['colorTrainingCompleted'] = true;
    progress['completedTrainings'] = (progress['completedTrainings'] as int) + 1;
    
    // Adicionar estrelas com base na média de desempenho
    final avgStats = await getAverageColorTrainingStats();
    if (avgStats != null) {
      int stars = 0;
      double successRate = avgStats.successPercentage;
      
      if (successRate >= 90) {
        stars = 3;
      } else if (successRate >= 70) stars = 2;
      else stars = 1;
      
      progress['totalStars'] = (progress['totalStars'] as int) + stars;
    }
    
    return await updateOverallProgress(progress);
  }

  // Atualizar status de conclusão para o treinamento de formas
  static Future<bool> markShapeTrainingCompleted() async {
    final progress = await getOverallProgress();
    
    // Se já estiver marcado como concluído, não faz nada
    if (progress['shapeTrainingCompleted'] == true) {
      return true;
    }
    
    // Atualizar valores
    progress['shapeTrainingCompleted'] = true;
    progress['completedTrainings'] = (progress['completedTrainings'] as int) + 1;
    
    // Adicionar estrelas com base na média de desempenho
    final avgStats = await getLastShapeTrainingStats();
    if (avgStats != null) {
      int stars = 0;
      double successRate = avgStats.successPercentage;
      
      if (successRate >= 90) {
        stars = 3;
      } else if (successRate >= 70) stars = 2;
      else stars = 1;
      
      progress['totalStars'] = (progress['totalStars'] as int) + stars;
    }
    
    return await updateOverallProgress(progress);
  }
  
  // Atualizar status de conclusão para o treinamento de quantidades
  static Future<bool> markQuantityTrainingCompleted() async {
    final progress = await getOverallProgress();
    
    // Se já estiver marcado como concluído, não faz nada
    if (progress['quantityTrainingCompleted'] == true) {
      return true;
    }
    
    // Atualizar valores
    progress['quantityTrainingCompleted'] = true;
    progress['completedTrainings'] = (progress['completedTrainings'] as int) + 1;
    
    // Adicionar estrelas com base na média de desempenho
    final avgStats = await getLastQuantityTrainingStats();
    if (avgStats != null) {
      int stars = 0;
      double successRate = avgStats.successPercentage;
      
      if (successRate >= 90) {
        stars = 3;
      } else if (successRate >= 70) stars = 2;
      else stars = 1;
      
      progress['totalStars'] = (progress['totalStars'] as int) + stars;
    }
    
    return await updateOverallProgress(progress);
  }

  // Limpar todos os dados de progresso do usuário atual
  static Future<bool> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    final colorKey = await _getUniqueKey(_colorTrainingKey);
    final shapeKey = await _getUniqueKey(_shapeTrainingKey);
    final sequenceKey = await _getUniqueKey(_sequenceTrainingKey);
    final imageKey = await _getUniqueKey(_imageAssociationKey);
    final quantityKey = await _getUniqueKey(_quantityTrainingKey);
    final puzzleKey = await _getUniqueKey(_puzzleTrainingKey);
    final overallKey = await _getUniqueKey(_overallProgressKey);
    
    await prefs.remove(colorKey);
    await prefs.remove(shapeKey);
    await prefs.remove(sequenceKey);
    await prefs.remove(imageKey);
    await prefs.remove(quantityKey);
    await prefs.remove(puzzleKey);
    await prefs.remove(overallKey);
    
    return true;
  }

  // Obter dados de progresso para relatório (específico do usuário)
  static Future<Map<String, dynamic>> getPatientProgressForReport(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Construir chaves específicas do usuário
    final colorKey = '${_colorTrainingKey}_patient_$userId';
    final shapeKey = '${_shapeTrainingKey}_patient_$userId';
    final quantityKey = '${_quantityTrainingKey}_patient_$userId';
    final overallKey = '${_overallProgressKey}_patient_$userId';
    
    // Obter dados
    final colorStats = prefs.getStringList(colorKey) ?? [];
    final shapeStats = prefs.getStringList(shapeKey) ?? [];
    final quantityStats = prefs.getStringList(quantityKey) ?? [];
    final overallJson = prefs.getString(overallKey);
    
    Map<String, dynamic> overall = {};
    if (overallJson != null) {
      overall = jsonDecode(overallJson);
    }
    
    return {
      'colorStats': colorStats.map((s) => jsonDecode(s)).toList(),
      'shapeStats': shapeStats.map((s) => jsonDecode(s)).toList(),
      'quantityStats': quantityStats.map((s) => jsonDecode(s)).toList(),
      'overallProgress': overall,
    };
  }

  // Migrar dados antigos para novo sistema (se necessário)
  static Future<void> migrateOldDataToNewSystem() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obter IDs únicos baseados no tipo de usuário
      String? uniqueId;
      bool isPatient = false;
      
      // Verificar se é paciente Gmail
      if (await PatientAuthService.isPatientLoggedIn()) {
        uniqueId = await PatientAuthService.getPatientUniqueId();
        isPatient = true;
      } else {
        // Verificar se é learner local
        final currentLearner = await LearnerService.getCurrentLearner();
        if (currentLearner != null && !currentLearner.isAuthenticated) {
          uniqueId = currentLearner.id;
          isPatient = false;
        }
      }
      
      if (uniqueId == null) return;
      
      // Verificar se há dados antigos e migrar
      final oldKeys = [
        _colorTrainingKey,
        _shapeTrainingKey,
        _quantityTrainingKey,
        _overallProgressKey,
      ];
      
      for (String oldKey in oldKeys) {
        final newKey = isPatient 
            ? '${oldKey}_patient_$uniqueId'
            : '${oldKey}_learner_$uniqueId';
        
        // Migrar dados se existirem e se as novas chaves não existirem
        if (prefs.containsKey(oldKey) && !prefs.containsKey(newKey)) {
          if (oldKey == _overallProgressKey) {
            final oldData = prefs.getString(oldKey);
            if (oldData != null) {
              await prefs.setString(newKey, oldData);
            }
          } else {
            final oldData = prefs.getStringList(oldKey);
            if (oldData != null) {
              await prefs.setStringList(newKey, oldData);
            }
          }
        }
      }
    } catch (e) {
      print('Erro na migração de dados: $e');
    }
  }
  
  // Função para gerar mensagem personalizada de acordo com o desempenho
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
}