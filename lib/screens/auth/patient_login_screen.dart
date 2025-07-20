import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../services/patient_auth_service.dart';
import '../common_widgets/gradient_background.dart';
import '../menu/menu_trainings_page.dart';
import '../home/home_screen.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  // Verificar se já existe um login ativo
  Future<void> _checkExistingLogin() async {
    try {
      final isLoggedIn = await PatientAuthService.isPatientLoggedIn();
      if (isLoggedIn && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuTrainingsPage()),
        );
      }
    } catch (e) {
      // Se houver erro, continuar na tela de login
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao verificar login existente';
        });
      }
    }
  }

  // Fazer login com Google
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final patient = await PatientAuthService.signInWithGoogle();

      if (patient != null && mounted) {
        // Login bem-sucedido, navegar para o menu de treinos
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuTrainingsPage()),
        );
      } else if (mounted) {
        // Login cancelado pelo usuário
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _getErrorMessage(e.toString());
        });
      }
    }
  }

  // Converter mensagens de erro para algo mais amigável
  String _getErrorMessage(String error) {
    if (error.contains('não está registrado como paciente')) {
      return 'Este email não está registrado.\nEntre em contato com seu terapeuta para ser cadastrado.';
    } else if (error.contains('conta está inativa')) {
      return 'Sua conta está inativa.\nEntre em contato com seu terapeuta.';
    } else if (error.contains('network')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    } else if (error.contains('cancelled')) {
      return 'Login cancelado.';
    } else {
      return 'Erro no login. Entre em contato com seu terapeuta se o problema persistir.';
    }
  }

  // Voltar para a tela inicial
  void _goBack() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  // Mostrar informações sobre como se cadastrar
  void _showRegistrationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Como me cadastrar?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para usar o Lumimi como paciente, você precisa ser cadastrado por um terapeuta.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('📋 Passos para o cadastro:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildInfoStep('1', 'Seu terapeuta deve ter uma conta no Lumimi'),
            _buildInfoStep('2', 'Seu terapeuta irá cadastrar seu email no sistema'),
            _buildInfoStep('3', 'Você receberá as instruções de acesso'),
            _buildInfoStep('4', 'Faça login aqui com sua conta Google'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.contact_support, color: Colors.orange.shade700, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Precisa de ajuda?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Entre em contato com seu terapeuta ou com a equipe responsável pelo seu acompanhamento.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ENTENDI'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        colors: [Colors.blue.shade100, Colors.blue.shade400],
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Botão de voltar
                Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    // Botão de ajuda
                    IconButton(
                      onPressed: _showRegistrationInfo,
                      icon: const Icon(
                        Icons.help_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: 'Como me cadastrar?',
                    ),
                  ],
                ),

                // Conteúdo principal centralizado
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ícone e título
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.blue,
                          size: 60,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Título
                      const Text(
                        'Login do Paciente',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Subtítulo
                      Text(
                        'Entre com sua conta do Google para\nacessar seus treinos personalizados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withAlpha(220),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Card de login
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Mensagem de erro
                            if (_errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Botão de login com Google
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signInWithGoogle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: _isLoading
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Entrando...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Ícone do Google
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'G',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Entrar com Google',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Botão de ajuda
                            TextButton.icon(
                              onPressed: _showRegistrationInfo,
                              icon: Icon(Icons.help_outline, size: 16, color: Colors.grey.shade600),
                              label: Text(
                                'Não tenho cadastro',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Informação sobre segurança
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withAlpha(128),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.security,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Seus dados de treinos são privados\ne seguros. Apenas você e seu terapeuta\npodem acessá-los.',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(220),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}