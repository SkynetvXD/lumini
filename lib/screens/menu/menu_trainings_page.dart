import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/learner.dart';
import '../../services/learner_service.dart';
import '../../services/progress_service.dart';
import '../../utils/message_helper.dart';
import '../colors_training/colors_training_page.dart';
import '../common_widgets/gradient_background.dart';
import '../progress/progress_history_page.dart';
import '../quantity_training/quantity_training_page.dart';
import '../shapes_training/shapes_training_page.dart';
import '/screens/home/home_screen.dart';
import 'widgets/training_card.dart';
import '../../services/patient_auth_service.dart';

class MenuTrainingsPage extends StatefulWidget {
  const MenuTrainingsPage({super.key});

  @override
  State<MenuTrainingsPage> createState() => _MenuTrainingsPageState();
}

class _MenuTrainingsPageState extends State<MenuTrainingsPage> {
  int _totalStars = 0;
  Learner? _currentLearner;  // Para ambos os sistemas
  bool _isLoading = true;
  bool _isAuthenticatedPatient = false;
  
  // Chaves globais para cada botão de treinamento
  final GlobalKey _sequenceKey = GlobalKey();
  final GlobalKey _imageAssociationKey = GlobalKey();
  final GlobalKey _puzzleKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _loadProgressAndLearner();
  }
  
  Future<void> _loadProgressAndLearner() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // Só permite paciente autenticado Google
    final isPatientLoggedIn = await PatientAuthService.isPatientLoggedIn();

    if (isPatientLoggedIn) {
      final patient = await PatientAuthService.getPatientData();
      if (patient != null) {
        await ProgressService.migrateOldDataToNewSystem();
        final progress = await ProgressService.getOverallProgress();
        setState(() {
          _currentLearner = patient;
          _isAuthenticatedPatient = true;
          _totalStars = progress['totalStars'] as int;
          _isLoading = false;
        });
        return;
      }
    }

    // Se não estiver autenticado, volta para HomeScreen
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  
  // Função para mostrar mensagem personalizada acima de um botão
  void _showComingSoonMessage(GlobalKey buttonKey, String trainingName) {
    // Obtém a posição do botão
    final RenderBox renderBox = buttonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    
    // Calculamos o centro da tela para posicionar a mensagem
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Mostra um popup acima do botão, centralizado na tela
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // Centralizamos a mensagem na tela
        left: screenWidth / 2 - 100, // Largura estimada de 200px, centralizada
        top: position.dy - 50, // 50px acima do botão
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 200, // Largura fixa para a mensagem
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              "Treino de $trainingName em breve!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
    
    // Adiciona e remove depois de 2 segundos
    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  // Função para mostrar diálogo de logout
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do App'),
        content: const Text('Deseja sair e voltar à tela inicial?'),
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : GradientBackground(
              colors: AppColors.menuGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              child: SafeArea(
                child: Column(
                  children: [
                    // Cabeçalho
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        children: [
                          // Botão de sair
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _showLogoutDialog,
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Sair',
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Logo e nome do app (centralizado)
                          Column(
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Lumimi",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Informações do aprendiz atual
                              if (_currentLearner != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(76),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.white,
                                        radius: 12,
                                        child: Text(
                                          _currentLearner!.name.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _currentLearner!.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          
                          const Spacer(),
                          
                          // Menu de opções e estrelas
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              
                              // Contador de estrelas
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(76),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$_totalStars",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Subtítulo
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Escolha um treino para começar a brincar e aprender!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Botão de progresso
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => const ProgressHistoryPage(),
                          ),
                        ).then((_) => _loadProgressAndLearner());
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withAlpha(128),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bar_chart,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Ver Meu Progresso",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Grid de opções de treino
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: GridView.count(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          children: [
                            // Treino de Cores (implementado)
                            TrainingCard(
                              title: "Treino de Cores",
                              icon: Icons.palette,
                              color: AppColors.redCard,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ColorsTrainingPage()),
                              ).then((_) => _loadProgressAndLearner()),
                            ),
                            
                            // Treino de Formas (implementado)
                            TrainingCard(
                              title: "Treino de Formas",
                              icon: Icons.category,
                              color: AppColors.greenCard,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ShapesTrainingPage()),
                              ).then((_) => _loadProgressAndLearner()),
                            ),
                            
                            // Treino de Quantidades (implementado)
                            TrainingCard(
                              title: "Treino de Quantidades",
                              icon: Icons.filter_9_plus,
                              color: AppColors.blueCard,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const QuantityTrainingPage()),
                              ).then((_) => _loadProgressAndLearner()),
                            ),
                            
                            // Sequência e Padrões (em breve)
                            TrainingCard(
                              key: _sequenceKey,
                              title: "Sequência e Padrões",
                              icon: Icons.repeat,
                              color: AppColors.amberCard,
                              onTap: () => _showComingSoonMessage(_sequenceKey, "Sequência e Padrões"),
                            ),
                            
                            // Associação de Imagens (em breve)
                            TrainingCard(
                              key: _imageAssociationKey,
                              title: "Associação de Imagens",
                              icon: Icons.image,
                              color: AppColors.purpleCard,
                              onTap: () => _showComingSoonMessage(_imageAssociationKey, "Associação de Imagens"),
                            ),
                            
                            // Quebra-cabeça Simples (em breve)
                            TrainingCard(
                              key: _puzzleKey,
                              title: "Quebra-cabeça Simples",
                              icon: Icons.extension,
                              color: AppColors.tealCard,
                              onTap: () => _showComingSoonMessage(_puzzleKey, "Quebra-cabeça"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}