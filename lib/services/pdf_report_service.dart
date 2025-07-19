import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/learner.dart';
import '../models/training_stats.dart';
import 'progress_service.dart';

class PdfReportService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Gerar relatório semanal em PDF
  static Future<File> generateWeeklyReport({
    required Learner learner,
    required DateTime startDate,
    required DateTime endDate,
    required String therapistName,
  }) async {
    // Carregar dados de progresso
    final colorStats = await ProgressService.getColorTrainingStats();
    final shapeStats = await ProgressService.getShapeTrainingStats();
    final quantityStats = await ProgressService.getQuantityTrainingStats();

    // Filtrar dados por período
    final weekColorStats = _filterStatsByWeek(colorStats, startDate, endDate);
    final weekShapeStats = _filterStatsByWeek(shapeStats, startDate, endDate);
    final weekQuantityStats = _filterStatsByWeek(quantityStats, startDate, endDate);

    // Calcular estatísticas da semana
    final weeklyAnalysis = _calculateWeeklyAnalysis(
      weekColorStats, 
      weekShapeStats, 
      weekQuantityStats
    );

    // Criar documento PDF
    final pdf = pw.Document();

    // Adicionar páginas ao PDF
    pdf.addPage(_buildFirstPage(learner, startDate, endDate, therapistName, weeklyAnalysis));
    
    if (weekColorStats.isNotEmpty || weekShapeStats.isNotEmpty || weekQuantityStats.isNotEmpty) {
      pdf.addPage(_buildDetailsPage(
        learner,
        weekColorStats,
        weekShapeStats,
        weekQuantityStats,
        weeklyAnalysis,
      ));
    }

    pdf.addPage(_buildConclusionPage(learner, weeklyAnalysis));

    // Salvar PDF
    final fileName = 'relatorio_${learner.name.replaceAll(' ', '_')}_${_dateFormat.format(DateTime.now()).replaceAll('/', '_')}.pdf';
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    
    try {
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      // Fallback para diretório temporário
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(await pdf.save());
      return tempFile;
    }
  }

  // Primeira página do relatório
  static pw.Page _buildFirstPage(
    Learner learner,
    DateTime startDate,
    DateTime endDate,
    String therapistName,
    Map<String, dynamic> analysis,
  ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            _buildHeader(),
            pw.SizedBox(height: 30),
            
            // Dados de identificação
            _buildIdentificationSection(learner, therapistName),
            pw.SizedBox(height: 30),
            
            // Período do relatório
            _buildPeriodSection(startDate, endDate),
            pw.SizedBox(height: 30),
            
            // Resumo geral
            _buildSummarySection(analysis),
            pw.SizedBox(height: 30),
            
            // Gráfico de desempenho (representação textual)
            _buildPerformanceChart(analysis),
          ],
        );
      },
    );
  }

  // Segunda página com detalhes
  static pw.Page _buildDetailsPage(
    Learner learner,
    List<Map<String, dynamic>> colorStats,
    List<Map<String, dynamic>> shapeStats,
    List<Map<String, dynamic>> quantityStats,
    Map<String, dynamic> analysis,
  ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Título da página
            pw.Text(
              'DETALHAMENTO DAS ATIVIDADES',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo700,
              ),
            ),
            pw.Divider(color: PdfColors.indigo700),
            pw.SizedBox(height: 20),
            
            // Detalhes por tipo de treino
            if (colorStats.isNotEmpty) ...[
              _buildTrainingSection('Treino de Cores', colorStats, PdfColors.red300),
              pw.SizedBox(height: 20),
            ],
            
            if (shapeStats.isNotEmpty) ...[
              _buildTrainingSection('Treino de Formas', shapeStats, PdfColors.green300),
              pw.SizedBox(height: 20),
            ],
            
            if (quantityStats.isNotEmpty) ...[
              _buildTrainingSection('Treino de Quantidades', quantityStats, PdfColors.blue300),
              pw.SizedBox(height: 20),
            ],
            
            // Tabela de sessões
            pw.SizedBox(height: 20),
            _buildSessionsTable(colorStats, shapeStats, quantityStats),
          ],
        );
      },
    );
  }

  // Terceira página com conclusões
  static pw.Page _buildConclusionPage(
    Learner learner,
    Map<String, dynamic> analysis,
  ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Título
            pw.Text(
              'CONCLUSÕES E RECOMENDAÇÕES',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo700,
              ),
            ),
            pw.Divider(color: PdfColors.indigo700),
            pw.SizedBox(height: 20),
            
            // Análise do desempenho
            _buildPerformanceAnalysis(learner, analysis),
            pw.SizedBox(height: 30),
            
            // Recomendações
            _buildRecommendations(analysis),
            pw.SizedBox(height: 30),
            
            // Observações adicionais
            _buildAdditionalObservations(),
            
            pw.Spacer(),
            
            // Rodapé
            _buildFooter(),
          ],
        );
      },
    );
  }

  // Cabeçalho do relatório
  static pw.Widget _buildHeader() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo700,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'LUMIMI',
            style: pw.TextStyle(
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Relatório Semanal de Progresso',
            style: pw.TextStyle(
              fontSize: 16,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Seção de identificação
  static pw.Widget _buildIdentificationSection(Learner learner, String therapistName) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DADOS DE IDENTIFICAÇÃO',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo700,
            ),
          ),
          pw.SizedBox(height: 15),
          _buildInfoRow('Nome:', learner.name),
          _buildInfoRow('Data de Nascimento:', _dateFormat.format(learner.birthDate)),
          _buildInfoRow('Idade:', '${learner.age} anos'),
          if (learner.diagnosis != null && learner.diagnosis!.isNotEmpty)
            _buildInfoRow('Diagnóstico:', learner.diagnosis!),
          _buildInfoRow('Equipe Responsável:', therapistName),
          _buildInfoRow('Data do Relatório:', _dateFormat.format(DateTime.now())),
        ],
      ),
    );
  }

  // Seção do período
  static pw.Widget _buildPeriodSection(DateTime startDate, DateTime endDate) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'PERÍODO ANALISADO: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${_dateFormat.format(startDate)} até ${_dateFormat.format(endDate)}',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
        ],
      ),
    );
  }

  // Seção de resumo
  static pw.Widget _buildSummarySection(Map<String, dynamic> analysis) {
    final totalSessions = analysis['totalSessions'] as int;
    final successRate = analysis['successRate'] as double;
    final averageDuration = analysis['averageDuration'] as double;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUMO GERAL',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryCard('Sessões Realizadas', totalSessions.toString(), PdfColors.blue),
              _buildSummaryCard('Taxa de Acerto', '${successRate.toStringAsFixed(1)}%', PdfColors.green),
              _buildSummaryCard('Duração Média', '${averageDuration.toStringAsFixed(1)} min', PdfColors.orange),
            ],
          ),
        ],
      ),
    );
  }

  // Card de resumo
  static pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Gráfico de desempenho (representação visual simples)
  static pw.Widget _buildPerformanceChart(Map<String, dynamic> analysis) {
    final successRate = analysis['successRate'] as double;
    final colorSessions = analysis['colorSessions'] as int;
    final shapeSessions = analysis['shapeSessions'] as int;
    final quantitySessions = analysis['quantitySessions'] as int;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DISTRIBUIÇÃO DAS ATIVIDADES',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 15),
          
          // Barra de cores
          if (colorSessions > 0)
            _buildActivityBar('Treino de Cores', colorSessions, PdfColors.red300),
          
          // Barra de formas
          if (shapeSessions > 0)
            _buildActivityBar('Treino de Formas', shapeSessions, PdfColors.green300),
          
          // Barra de quantidades
          if (quantitySessions > 0)
            _buildActivityBar('Treino de Quantidades', quantitySessions, PdfColors.blue300),
        ],
      ),
    );
  }

  // Barra de atividade
  static pw.Widget _buildActivityBar(String name, int sessions, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(name, style: pw.TextStyle(fontSize: 12)),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 20,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Center(
                child: pw.Text(
                  '$sessions sessões',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Seção de treino específico
  static pw.Widget _buildTrainingSection(
    String title,
    List<Map<String, dynamic>> stats,
    PdfColor color,
  ) {
    int totalSuccesses = 0;
    int totalErrors = 0;
    int totalAttempts = 0;

    for (var stat in stats) {
      totalSuccesses += stat['successes'] as int;
      totalErrors += stat['errors'] as int;
      totalAttempts += stat['totalAttempts'] as int;
    }

    final successRate = totalAttempts > 0 ? (totalSuccesses / totalAttempts) * 100 : 0.0;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color.shade(0.8),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sessões: ${stats.length}'),
              pw.Text('Acertos: $totalSuccesses'),
              pw.Text('Erros: $totalErrors'),
              pw.Text('Taxa: ${successRate.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  // Tabela de sessões
  static pw.Widget _buildSessionsTable(
    List<Map<String, dynamic>> colorStats,
    List<Map<String, dynamic>> shapeStats,
    List<Map<String, dynamic>> quantityStats,
  ) {
    // Combinar todos os stats
    final allStats = <Map<String, dynamic>>[];
    
    for (var stat in colorStats) {
      allStats.add({...stat, 'type': 'Cores'});
    }
    for (var stat in shapeStats) {
      allStats.add({...stat, 'type': 'Formas'});
    }
    for (var stat in quantityStats) {
      allStats.add({...stat, 'type': 'Quantidades'});
    }
    
    allStats.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    if (allStats.isEmpty) {
      return pw.Text('Nenhuma sessão registrada no período.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'HISTÓRICO DE SESSÕES',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Cabeçalho
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Data', isHeader: true),
                _buildTableCell('Tipo', isHeader: true),
                _buildTableCell('Acertos', isHeader: true),
                _buildTableCell('Total', isHeader: true),
                _buildTableCell('Taxa (%)', isHeader: true),
              ],
            ),
            // Dados (máximo 8 sessões)
            ...allStats.take(8).map((stat) {
              final date = DateTime.parse(stat['date']);
              final successes = stat['successes'] as int;
              final totalAttempts = stat['totalAttempts'] as int;
              final successRate = totalAttempts > 0 ? (successes / totalAttempts) * 100 : 0.0;
              
              return pw.TableRow(
                children: [
                  _buildTableCell(DateFormat('dd/MM').format(date)),
                  _buildTableCell(stat['type']),
                  _buildTableCell(successes.toString()),
                  _buildTableCell(totalAttempts.toString()),
                  _buildTableCell(successRate.toStringAsFixed(1)),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  // Célula da tabela
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // Análise de desempenho
  static pw.Widget _buildPerformanceAnalysis(Learner learner, Map<String, dynamic> analysis) {
    final successRate = analysis['successRate'] as double;
    final totalSessions = analysis['totalSessions'] as int;
    
    String performanceText;
    if (successRate >= 80) {
      performanceText = 'excelente progresso';
    } else if (successRate >= 60) {
      performanceText = 'bom progresso';
    } else if (successRate >= 40) {
      performanceText = 'progresso moderado';
    } else {
      performanceText = 'necessidade de ajustes na metodologia';
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ANÁLISE DO DESEMPENHO',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Nesta semana, o aprendiz ${learner.name} apresentou $performanceText, '
            'realizando $totalSessions sessões com uma taxa média de acerto de '
            '${successRate.toStringAsFixed(1)}%. Baseando-se nos dados obtidos, '
            'observa-se desenvolvimento nas habilidades de discriminação, atenção '
            'e seguimento de instruções.',
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Recomendações
  static pw.Widget _buildRecommendations(Map<String, dynamic> analysis) {
    final successRate = analysis['successRate'] as double;
    
    String recommendations;
    if (successRate >= 80) {
      recommendations = 'Recomendamos continuar com os treinos atuais e considerar aumentar '
                       'gradualmente a dificuldade. O aprendiz demonstra estar pronto para '
                       'desafios mais complexos e aplicação das habilidades em diferentes contextos.';
    } else if (successRate >= 60) {
      recommendations = 'Recomendamos manter a frequência atual dos treinos e focar nos '
                       'tipos de atividades onde há maior dificuldade. Aplicar estratégias '
                       'de reforço positivo para consolidar as habilidades adquiridas.';
    } else if (successRate >= 40) {
      recommendations = 'Recomendamos revisar as estratégias de ensino e considerar '
                       'simplificar as atividades temporariamente. Aumentar a frequência '
                       'dos treinos e utilizar mais dicas visuais e verbais.';
    } else {
      recommendations = 'Recomendamos uma revisão completa da abordagem terapêutica. '
                       'Considerar avaliação adicional das habilidades pré-requisito '
                       'e implementar estratégias mais individualizadas.';
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RECOMENDAÇÕES',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            recommendations,
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Observações adicionais
  static pw.Widget _buildAdditionalObservations() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'OBSERVAÇÕES ADICIONAIS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• Aplicar os treinos em ambiente controlado para melhor concentração'),
              pw.Text('• Considerar a generalização das habilidades para ambiente natural'),
              pw.Text('• Manter registro contínuo do progresso para ajustes futuros'),
              pw.Text('• Envolver família/cuidadores no processo de aprendizagem'),
            ].map((text) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: text,
            )).toList(),
          ),
        ],
      ),
    );
  }

  // Rodapé
  static pw.Widget _buildFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Relatório gerado automaticamente pelo Lumimi',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Data de geração: ${_dateTimeFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  // Linha de informação
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares (mantidos do código original)
  static List<Map<String, dynamic>> _filterStatsByWeek(
    List<Map<String, dynamic>> stats,
    DateTime startDate,
    DateTime endDate,
  ) {
    return stats.where((stat) {
      final statDate = DateTime.parse(stat['date']);
      return statDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             statDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  static Map<String, dynamic> _calculateWeeklyAnalysis(
    List<Map<String, dynamic>> colorStats,
    List<Map<String, dynamic>> shapeStats,
    List<Map<String, dynamic>> quantityStats,
  ) {
    final totalSessions = colorStats.length + shapeStats.length + quantityStats.length;
    
    int totalSuccesses = 0;
    int totalErrors = 0;
    int totalAttempts = 0;
    double totalDuration = 0;

    for (var stat in [...colorStats, ...shapeStats, ...quantityStats]) {
      totalSuccesses += stat['successes'] as int;
      totalErrors += stat['errors'] as int;
      totalAttempts += stat['totalAttempts'] as int;
      totalDuration += (stat['totalAttempts'] as int) * 1.5;
    }

    final successRate = totalAttempts > 0 ? (totalSuccesses / totalAttempts) * 100 : 0.0;
    final averageDuration = totalSessions > 0 ? totalDuration / totalSessions : 0.0;

    return {
      'totalSessions': totalSessions,
      'totalSuccesses': totalSuccesses,
      'totalErrors': totalErrors,
      'totalAttempts': totalAttempts,
      'successRate': successRate,
      'averageDuration': averageDuration,
      'colorSessions': colorStats.length,
      'shapeSessions': shapeStats.length,
      'quantitySessions': quantityStats.length,
    };
  }
}