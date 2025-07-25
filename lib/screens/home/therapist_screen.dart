import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/learner.dart';
import '../../services/progress_service.dart';
import '../../services/pdf_report_service.dart';
import '../../services/auth_service.dart';
import '../../services/therapist_patient_service.dart';
import '../../utils/pdf_helper.dart';
import '../common_widgets/gradient_background.dart';
import '../therapist/add_patient_by_email_dialog.dart';
import 'home_screen.dart';

class TherapistScreen extends StatefulWidget {
  const TherapistScreen({super.key});

  @override
  State<TherapistScreen> createState() => _TherapistScreenState();
}

class _TherapistScreenState extends State<TherapistScreen> with WidgetsBindingObserver {
  List<Learner> _gmailPatients = [];
  bool _isLoading = true;
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat timeFormat = DateFormat('HH:mm');
  final TextEditingController _therapistNameController = TextEditingController();
  
  // Dados do terapeuta logado
  Map<String, dynamic>? _therapistData;
  String _therapistName = 'Dr(a). Nome do Terapeuta';

  // 🆕 Cache para dados de progresso dos pacientes
  final Map<String, Map<String, dynamic>> _patientProgressCache = {};
  
  // 🆕 Timer para auto-refresh
  static const Duration _autoRefreshInterval = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 🔧 Carregamento sequencial para evitar problemas
    _initializeData();
    
    // 🆕 Auto-refresh periódico
    _startAutoRefresh();
  }

  // 🆕 Inicialização sequencial dos dados
  Future<void> _initializeData() async {
    try {
      // 1. Primeiro carregar dados do terapeuta
      await _loadTherapistData();
      
      // 2. Só depois carregar os pacientes (depende dos dados do terapeuta)
      if (_therapistData != null) {
        await _loadGmailPatientsWithProgress();
      }
    } catch (e) {
      print('Erro na inicialização: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _therapistNameController.dispose();
    super.dispose();
  }

  // 🆕 Detectar quando o app volta ao foco
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App voltou ao foco, recarregar dados
      _refreshAllData();
    }
  }

  // 🆕 Auto-refresh periódico
  void _startAutoRefresh() {
    Future.delayed(_autoRefreshInterval, () {
      if (mounted) {
        _refreshPatientProgress();
        _startAutoRefresh(); // Reagendar próximo refresh
      }
    });
  }

  // 🆕 Refresh completo de todos os dados
  Future<void> _refreshAllData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Carregamento sequencial
      await _loadTherapistData();
      if (_therapistData != null) {
        await _loadGmailPatientsWithProgress();
      }
    } catch (e) {
      print('Erro no refresh: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 🆕 Refresh apenas do progresso dos pacientes (mais leve)
  Future<void> _refreshPatientProgress() async {
    if (_gmailPatients.isEmpty) return;
    
    for (final patient in _gmailPatients) {
      await _loadPatientProgressData(patient.id);
    }
    
    if (mounted) {
      setState(() {
        // Trigger rebuild para mostrar dados atualizados
      });
    }
  }

  // Carregar dados do terapeuta logado
  Future<void> _loadTherapistData() async {
    try {
      final therapistData = await AuthService.getTherapistData();
      final isLoggedIn = await AuthService.isTherapistLoggedIn();
      
      if (!isLoggedIn || therapistData == null) {
        print('❌ Terapeuta não logado ou dados inválidos');
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
        return;
      }
      
      print('✅ Dados do terapeuta carregados: ${therapistData['name']}');
      
      // Atualizar dados do terapeuta (sem setState ainda)
      _therapistData = therapistData;
      _therapistName = therapistData['name'] ?? 'Terapeuta';
      _therapistNameController.text = _therapistName;
      
    } catch (e) {
      print('❌ Erro ao carregar dados do terapeuta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do terapeuta'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🆕 Carregar pacientes Gmail COM dados de progresso
  Future<void> _loadGmailPatientsWithProgress() async {
    if (_therapistData == null) {
      print('❌ Dados do terapeuta não disponíveis, não é possível carregar pacientes');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    print('🔄 Carregando pacientes para terapeuta: ${_therapistData!['uid']}');

    try {
      // Carregar lista de pacientes
      final gmailPatients = await TherapistPatientService.getPatientsByTherapist(_therapistData!['uid']);
      print('📋 ${gmailPatients.length} pacientes encontrados');
      
      // 🆕 Carregar dados de progresso para cada paciente
      for (final patient in gmailPatients) {
        print('📊 Carregando progresso para: ${patient.name}');
        await _loadPatientProgressData(patient.id);
      }
      
      print('✅ Todos os dados carregados com sucesso');
      
      // Atualizar UI apenas no final
      if (mounted) {
        setState(() {
          _gmailPatients = gmailPatients;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar pacientes: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar pacientes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🆕 Carregar dados de progresso específicos de um paciente
  Future<void> _loadPatientProgressData(String patientId) async {
    try {
      print('📈 Carregando progresso para paciente: $patientId');
      final progressData = await ProgressService.getPatientSummaryStats(patientId);
      _patientProgressCache[patientId] = progressData;
      print('✅ Progresso carregado: ${progressData['totalSessions']} sessões');
    } catch (e) {
      print('⚠️ Erro ao carregar progresso do paciente $patientId: $e');
      // Manter dados em cache se houver erro, mas criar entrada vazia
      _patientProgressCache[patientId] = {
        'totalSessions': 0,
        'overallProgress': {'totalStars': 0, 'completedTrainings': 0},
        'lastActivity': null,
      };
    }
  }

  // 🆕 Obter dados de progresso do cache
  Map<String, dynamic>? _getPatientProgress(String patientId) {
    return _patientProgressCache[patientId];
  }

  // Adicionar paciente Gmail
  Future<void> _addGmailPatient() async {
    if (_therapistData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados do terapeuta não encontrados'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final canAdd = await TherapistPatientService.canAddMorePatients(_therapistData!['uid']);
    if (!canAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limite de 10 pacientes Gmail atingido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => const AddPatientByEmailDialog(),
    );

    if (added == true) {
      await _loadGmailPatientsWithProgress();
    }
  }

  // Remover paciente Gmail
  Future<void> _removePatient(Learner patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover paciente'),
        content: Text('Tem certeza que deseja remover ${patient.name}? Esta ação não pode ser desfeita.'),
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
      final success = await TherapistPatientService.removePatient(patient.id);
      
      if (success) {
        // 🆕 Remover do cache também
        _patientProgressCache.remove(patient.id);
        
        await _loadGmailPatientsWithProgress();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${patient.name} foi removido com sucesso'),
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
        SnackBar(
          content: Text('Erro ao remover paciente: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Gerar relatório
  Future<void> _generateWeeklyReport(Learner patient) async {
    final dateRange = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => _WeeklyReportDialog(learner: patient),
    );

    if (dateRange == null) return;

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
      final reportFile = await PdfReportService.generateWeeklyReport(
        learner: patient,
        startDate: dateRange['startDate']!,
        endDate: dateRange['endDate']!,
        therapistName: _therapistNameController.text,
      );

      if (!mounted) return;
      
      Navigator.of(context).pop();

      final pdfInfo = await PdfHelper.getPdfInfo(reportFile);

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
                'Relatório semanal de ${patient.name} foi gerado com sucesso!',
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
              // Opções disponíveis
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'O que você pode fazer:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Visualizar o PDF na tela', style: TextStyle(fontSize: 12)),
                    const Text('• Compartilhar via WhatsApp, email, etc.', style: TextStyle(fontSize: 12)),
                    const Text('• Salvar no dispositivo', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('FECHAR'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await PdfHelper.sharePdf(reportFile, context: context);
              },
              icon: const Icon(Icons.share, size: 16),
              label: const Text('COMPARTILHAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
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
      
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar relatório: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'TENTAR NOVAMENTE',
            onPressed: () => _generateWeeklyReport(patient),
          ),
        ),
      );
    }
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
                              await PdfHelper.sharePdf(file, context: context);
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
                await PdfHelper.cleanOldPdfs(maxAgeInDays: 30, context: context);
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

  // Helper to build info row for PDF info
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Mostrar progresso do paciente com dados do cache
  Future<void> _showPatientProgress(Learner patient) async {
    try {
      // 🆕 Usar dados do cache primeiro, depois recarregar
      Map<String, dynamic>? cachedProgress = _getPatientProgress(patient.id);
      
      // Mostrar dados do cache imediatamente se disponível
      if (cachedProgress != null) {
        _displayPatientProgressDialog(patient, cachedProgress);
      } else {
        // Mostrar loading se não houver cache
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Carregando progresso...'),
              ],
            ),
          ),
        );
      }
      
      // 🆕 Recarregar dados frescos em background
      await _loadPatientProgressData(patient.id);
      final freshProgress = _getPatientProgress(patient.id);
      
      if (!mounted) return;
      
      // Fechar loading se estava aberto
      if (cachedProgress == null) {
        Navigator.of(context).pop();
      }
      
      if (freshProgress != null) {
        // Se já estava mostrando o diálogo, fechar e mostrar com dados atualizados
        if (cachedProgress != null) {
          Navigator.of(context).pop();
        }
        _displayPatientProgressDialog(patient, freshProgress);
      }

    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar loading se aberto
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar progresso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🆕 Exibir diálogo de progresso do paciente
  void _displayPatientProgressDialog(Learner patient, Map<String, dynamic> progressData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade500,
              radius: 20,
              child: Text(
                patient.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progresso de ${patient.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  // 🆕 Mostrar última atividade
                  if (progressData['lastActivity'] != null)
                    Text(
                      'Última atividade: ${DateFormat('dd/MM HH:mm').format(DateTime.parse(progressData['lastActivity']))}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge para indicar tipo de paciente Gmail
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Paciente Gmail',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 🆕 Resumo geral
              _buildGeneralSummarySection(progressData),
              const SizedBox(height: 16),
              
              // 🆕 Treinos individuais
              _buildTrainingProgressSection('Treino de Cores', progressData['colorTraining'], Colors.red),
              const SizedBox(height: 12),
              _buildTrainingProgressSection('Treino de Formas', progressData['shapeTraining'], Colors.green),
              const SizedBox(height: 12),
              _buildTrainingProgressSection('Treino de Quantidades', progressData['quantityTraining'], Colors.blue),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('FECHAR'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _generateWeeklyReport(patient);
            },
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('GERAR PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Seção de resumo geral
  Widget _buildGeneralSummarySection(Map<String, dynamic> progressData) {
    final overallProgress = progressData['overallProgress'] as Map<String, dynamic>;
    final totalSessions = progressData['totalSessions'] as int;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo Geral',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total de sessões:'),
              Text(
                '$totalSessions',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Treinamentos completos:'),
              Text(
                '${overallProgress['completedTrainings']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estrelas conquistadas:'),
              Row(
                children: [
                  Text(
                    '${overallProgress['totalStars']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🆕 Seção de progresso de treino específico
  Widget _buildTrainingProgressSection(String title, Map<String, dynamic>? trainingData, Color color) {
    if (trainingData == null || trainingData['totalSessions'] == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(76)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Nenhum treino realizado ainda',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final totalSessions = trainingData['totalSessions'] as int;
    final averageSuccessRate = trainingData['averageSuccessRate'] as double;
    final trend = trainingData['trend'] as String;
    final lastSession = trainingData['lastSession'] as String?;

    // Ícone e cor da tendência
    IconData trendIcon;
    Color trendColor;
    switch (trend) {
      case 'improving':
        trendIcon = Icons.trending_up;
        trendColor = Colors.green;
        break;
      case 'declining':
        trendIcon = Icons.trending_down;
        trendColor = Colors.red;
        break;
      default:
        trendIcon = Icons.trending_flat;
        trendColor = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.8),
                ),
              ),
              Row(
                children: [
                  Icon(trendIcon, size: 16, color: trendColor),
                  const SizedBox(width: 4),
                  Text(
                    '${averageSuccessRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: trendColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sessões: $totalSessions',
                style: const TextStyle(fontSize: 12),
              ),
              if (lastSession != null)
                Text(
                  'Última: ${DateFormat('dd/MM').format(DateTime.parse(lastSession))}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: averageSuccessRate / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do Painel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_therapistData != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: _therapistData!['photoUrl'] != null && _therapistData!['photoUrl'].isNotEmpty
                        ? NetworkImage(_therapistData!['photoUrl'])
                        : null,
                    backgroundColor: Colors.green,
                    child: _therapistData!['photoUrl'] == null || _therapistData!['photoUrl'].isEmpty
                        ? Text(
                            _therapistData!['name']?.substring(0, 1).toUpperCase() ?? 'T',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _therapistData!['name'] ?? 'Terapeuta',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _therapistData!['email'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const Text('Deseja sair do painel do terapeuta?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Saindo...'),
                    ],
                  ),
                ),
              );
              
              try {
                await AuthService.signOut();
                if (!mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao fazer logout: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Painel do Terapeuta',
              style: TextStyle(fontSize: 18),
            ),
            if (_therapistData != null)
              Text(
                _therapistData!['name'] ?? 'Terapeuta',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(),
          tooltip: 'Sair do painel',
        ),
        actions: [
          // 🆕 Botão de refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              print('🔄 Refresh manual iniciado');
              await _refreshAllData();
            },
            tooltip: 'Atualizar dados',
          ),
          if (_therapistData != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: _therapistData!['photoUrl'] != null && _therapistData!['photoUrl'].isNotEmpty
                    ? NetworkImage(_therapistData!['photoUrl'])
                    : null,
                backgroundColor: Colors.white,
                child: _therapistData!['photoUrl'] == null || _therapistData!['photoUrl'].isEmpty
                    ? Text(
                        _therapistData!['name']?.substring(0, 1).toUpperCase() ?? 'T',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () => _showPdfManagement(),
            tooltip: 'Relatórios salvos',
          ),
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
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Carregando pacientes...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : _buildGmailPatientsContent(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        onPressed: _addGmailPatient,
        icon: const Icon(Icons.cloud),
        label: const Text('Adicionar Paciente Gmail'),
      ),
    );
  }

  // Conteúdo principal - apenas pacientes Gmail
  Widget _buildGmailPatientsContent() {
    if (_gmailPatients.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPatientsList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 80,
            color: Colors.white.withAlpha(150),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum paciente Gmail cadastrado',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no botão abaixo para\nadicionar um novo paciente',
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

  Widget _buildPatientsList() {
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
              const Row(
                children: [
                  Icon(
                    Icons.cloud,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Meus Pacientes Gmail',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${_gmailPatients.length} de ${TherapistPatientService.maxPatientsPerTherapist} pacientes',
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
            itemCount: _gmailPatients.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final patient = _gmailPatients[index];
              final progressData = _getPatientProgress(patient.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.blue.shade200,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade500,
                        radius: 25,
                        child: Text(
                          patient.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Badge Gmail
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.cloud,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      patient.name,
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
                      
                      // Email
                      if (patient.email != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.email, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                patient.email!,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      
                      // Data de nascimento
                      Row(
                        children: [
                          const Icon(Icons.cake, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${dateFormat.format(patient.birthDate)} (${patient.age} anos)',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // 🆕 Resumo de progresso
                      if (progressData != null && progressData['totalSessions'] > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.analytics, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${progressData['totalSessions']} sessões • ${progressData['overallProgress']['totalStars']} ⭐',
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ] else if (progressData != null && progressData['totalSessions'] == 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.info, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'Nenhuma atividade registrada',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      // Diagnóstico
                      if (patient.diagnosis != null && patient.diagnosis!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.medical_information, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                patient.diagnosis!,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      // Último acesso
                      if (patient.lastAccess != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Último acesso: ${dateFormat.format(patient.lastAccess!)} às ${timeFormat.format(patient.lastAccess!)}',
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
                          onPressed: () => _generateWeeklyReport(patient),
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
                          onPressed: () => _showPatientProgress(patient),
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
                          onPressed: () => _removePatient(patient),
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