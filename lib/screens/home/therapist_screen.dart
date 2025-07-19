import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../models/learner.dart';
import '../../services/learner_service.dart';
import '../../services/progress_service.dart';
import '../../services/pdf_report_service.dart';
import '../../utils/pdf_helper.dart';
import '../common_widgets/gradient_background.dart';
import '../learner/add_learner_dialog.dart';
import 'home_screen.dart';

class TherapistScreen extends StatefulWidget {
  const TherapistScreen({super.key});

  @override
  State<TherapistScreen> createState() => _TherapistScreenState();
}

class _TherapistScreenState extends State<TherapistScreen> {
  List<Learner> _learners = [];
  bool _isLoading = true;
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat timeFormat = DateFormat('HH:mm');
  final TextEditingController _therapistNameController = TextEditingController(text: 'Dr(a). Nome do Terapeuta');

  @override
  void initState() {
    super.initState();
    _loadLearners();
  }

  @override
  void dispose() {
    _therapistNameController.dispose();
    super.dispose();
  }

  Future<void> _loadLearners() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final learners = await LearnerService.getAllLearners();
      setState(() {
        _learners = learners;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao carregar pacientes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addNewLearner() async {
    if (_learners.length >= LearnerService.maxLearners) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limite de 10 pacientes atingido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => const AddLearnerDialog(),
    );

    if (added == true) {
      await _loadLearners();
    }
  }

  Future<void> _removeLearner(Learner learner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover paciente'),
        content: Text('Tem certeza que deseja remover ${learner.name}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('REMOVER', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await LearnerService.removeLearner(learner.id);
      if (success) {
        await _loadLearners();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${learner.name} foi removido com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao remover paciente'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover paciente'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateWeeklyReport(Learner learner) async {
    // Mostrar diálogo para seleção de período
    final dateRange = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => _WeeklyReportDialog(learner: learner),
    );

    if (dateRange == null) return;

    // Mostrar diálogo de progresso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Gerando relatório PDF...'),
          ],
        ),
      ),
    );

    try {
      // Definir o aprendiz atual para carregar seus dados
      await LearnerService.setCurrentLearnerId(learner.id);
      
      // Gerar o relatório PDF
      final reportFile = await PdfReportService.generateWeeklyReport(
        learner: learner,
        startDate: dateRange['startDate']!,
        endDate: dateRange['endDate']!,
        therapistName: _therapistNameController.text,
      );

      if (!mounted) return;
      
      // Fechar diálogo de progresso
      Navigator.of(context).pop();

      // Obter informações do PDF
      final pdfInfo = await PdfHelper.getPdfInfo(reportFile);

      // Mostrar diálogo de sucesso com opções
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Relatório PDF Gerado'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Relatório semanal de ${learner.name} foi gerado com sucesso!',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Informações do arquivo:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Nome:', pdfInfo['name']),
                    _buildInfoRow('Tamanho:', pdfInfo['sizeString']),
                    _buildInfoRow('Criado em:', DateFormat('dd/MM/yyyy HH:mm').format(pdfInfo['modified'])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Use os botões abaixo para visualizar, compartilhar ou imprimir o relatório.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Botão Fechar
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('FECHAR'),
            ),
            
            // Botão Compartilhar
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await PdfHelper.sharePdf(reportFile);
              },
              icon: const Icon(Icons.share, size: 16),
              label: const Text('COMPARTILHAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            
            // Botão Visualizar
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await PdfHelper.showPdfPreview(context, reportFile);
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('VISUALIZAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Fechar diálogo de progresso se ainda estiver aberto
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar relatório: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'TENTAR NOVAMENTE',
            onPressed: () => _generateWeeklyReport(learner),
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLearnerProgress(Learner learner) async {
    // Carregar dados de progresso do paciente
    await LearnerService.setCurrentLearnerId(learner.id);
    
    final colorStats = await ProgressService.getColorTrainingStats();
    final shapeStats = await ProgressService.getShapeTrainingStats();
    final quantityStats = await ProgressService.getQuantityTrainingStats();
    final overallProgress = await ProgressService.getOverallProgress();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Progresso de ${learner.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressSection('Treino de Cores', colorStats),
              const SizedBox(height: 16),
              _buildProgressSection('Treino de Formas', shapeStats),
              const SizedBox(height: 16),
              _buildProgressSection('Treino de Quantidades', quantityStats),
              const SizedBox(height: 16),
              _buildOverallProgressSection(overallProgress),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('FECHAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(String title, List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text('Nenhum treino realizado ainda'),
        ],
      );
    }

    final lastSession = stats.last;
    final successes = lastSession['successes'] as int;
    final totalAttempts = lastSession['totalAttempts'] as int;
    final successRate = (successes / totalAttempts) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text('Sessões realizadas: ${stats.length}'),
        Text('Última taxa de acerto: ${successRate.toStringAsFixed(1)}%'),
        Text('Último treino: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(lastSession['date']))}'),
      ],
    );
  }

  Widget _buildOverallProgressSection(Map<String, dynamic> progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progresso Geral',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text('Treinamentos completos: ${progress['completedTrainings']}'),
        Text('Estrelas conquistadas: ${progress['totalStars']}'),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do Painel'),
        content: const Text('Deseja sair do painel do terapeuta e voltar à tela inicial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('SAIR'),
          ),
        ],
      ),
    );
  }

  void _showTherapistNameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome do Terapeuta'),
        content: TextField(
          controller: _therapistNameController,
          decoration: const InputDecoration(
            labelText: 'Nome completo',
            hintText: 'Dr(a). Nome do Terapeuta',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nome do terapeuta atualizado'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
  }

  void _showPdfManagement() async {
    final savedPdfs = await PdfHelper.getAllSavedPdfs();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Relatórios Salvos'),
        content: savedPdfs.isEmpty
            ? const Text('Nenhum relatório salvo encontrado.')
            : SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: savedPdfs.length,
                  itemBuilder: (context, index) {
                    final file = savedPdfs[index];
                    final stat = file.statSync();
                    
                    return ListTile(
                      leading: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
                      title: Text(
                        file.path.split('/').last,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        'Criado em: ${DateFormat('dd/MM/yyyy HH:mm').format(stat.modified)}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 16),
                                SizedBox(width: 8),
                                Text('Visualizar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 16),
                                SizedBox(width: 8),
                                Text('Compartilhar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Excluir', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) async {
                          Navigator.of(context).pop();
                          
                          switch (value) {
                            case 'view':
                              await PdfHelper.showPdfPreview(context, file);
                              break;
                            case 'share':
                              await PdfHelper.sharePdf(file);
                              break;
                            case 'delete':
                              await file.delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Relatório excluído')),
                              );
                              break;
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
        actions: [
          if (savedPdfs.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await PdfHelper.cleanOldPdfs(maxAgeInDays: 30);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Relatórios antigos removidos')),
                );
              },
              child: const Text('LIMPAR ANTIGOS'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('FECHAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Terapeuta'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(),
          tooltip: 'Sair do painel',
        ),
        actions: [
          // Botão para gerenciar PDFs
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () => _showPdfManagement(),
            tooltip: 'Relatórios salvos',
          ),
          // Botão para configurar nome do terapeuta
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _showTherapistNameDialog(),
            tooltip: 'Configurar nome do terapeuta',
          ),
        ],
      ),
      body: GradientBackground(
        colors: [Colors.green.shade100, Colors.green.shade300],
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _learners.isEmpty
                ? _buildEmptyState()
                : _buildLearnersList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewLearner,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.white.withAlpha(150),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum paciente cadastrado',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no botão + para adicionar um novo paciente',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withAlpha(200),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLearnersList() {
    return Column(
      children: [
        // Cabeçalho
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(51),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Meus Pacientes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${_learners.length} de ${LearnerService.maxLearners} pacientes',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista de pacientes
        Expanded(
          child: ListView.builder(
            itemCount: _learners.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final learner = _learners[index];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade500,
                    radius: 25,
                    child: Text(
                      learner.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  title: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      learner.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.cake, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${dateFormat.format(learner.birthDate)} (${learner.age} anos)',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (learner.diagnosis != null && learner.diagnosis!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.medical_information, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                learner.diagnosis!,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (learner.lastAccess != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Último acesso: ${dateFormat.format(learner.lastAccess!)} às ${timeFormat.format(learner.lastAccess!)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      // Botão para gerar relatório PDF
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
                          onPressed: () => _generateWeeklyReport(learner),
                          tooltip: 'Gerar relatório PDF',
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                      
                      // Botão para ver progresso
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.analytics, color: Colors.blue.shade700),
                          onPressed: () => _showLearnerProgress(learner),
                          tooltip: 'Ver progresso',
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                      
                      // Botão de remover
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                          onPressed: () => _removeLearner(learner),
                          tooltip: 'Remover paciente',
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Diálogo para seleção do período do relatório
class _WeeklyReportDialog extends StatefulWidget {
  final Learner learner;

  const _WeeklyReportDialog({required this.learner});

  @override
  State<_WeeklyReportDialog> createState() => _WeeklyReportDialogState();
}

class _WeeklyReportDialogState extends State<_WeeklyReportDialog> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Relatório PDF de ${widget.learner.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Selecione o período para o relatório:'),
          const SizedBox(height: 16),
          
          // Data de início
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Data de Início'),
            subtitle: Text(_dateFormat.format(_startDate)),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _startDate = date;
                });
              }
            },
          ),
          
          // Data de fim
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Data de Fim'),
            subtitle: Text(_dateFormat.format(_endDate)),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _endDate,
                firstDate: _startDate,
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _endDate = date;
                });
              }
            },
          ),
          
          const SizedBox(height: 16),
          
          // Botões de período rápido
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _endDate = DateTime.now();
                    _startDate = _endDate.subtract(const Duration(days: 7));
                  });
                },
                child: const Text('Última Semana'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _endDate = DateTime.now();
                    _startDate = _endDate.subtract(const Duration(days: 30));
                  });
                },
                child: const Text('Último Mês'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop({
              'startDate': _startDate,
              'endDate': _endDate,
            });
          },
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('GERAR PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}