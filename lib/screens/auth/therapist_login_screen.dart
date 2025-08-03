// lib/screens/auth/therapist_login_screen.dart
import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/native_auth_service.dart';
import '../common_widgets/gradient_background.dart';
import '../home/therapist_screen.dart';
import '../home/home_screen.dart';

class TherapistLoginScreen extends StatefulWidget {
  const TherapistLoginScreen({super.key});

  @override
  State<TherapistLoginScreen> createState() => _TherapistLoginScreenState();
}

class _TherapistLoginScreenState extends State<TherapistLoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  
  // Controladores para login nativo
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isNativeLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Verificar se já existe um login ativo
  Future<void> _checkExistingLogin() async {
    try {
      // Verificar login Google
      final isGoogleLoggedIn = await AuthService.isTherapistLoggedIn();
      if (isGoogleLoggedIn && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TherapistScreen()),
        );
        return;
      }
      
      // Verificar login nativo
      final isNativeLoggedIn = await NativeAuthService.isTherapistLoggedInNative();
      if (isNativeLoggedIn && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TherapistScreen()),
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
      final therapistData = await AuthService.signInWithGoogle();

      if (therapistData != null && mounted) {
        // Login bem-sucedido, navegar para a tela do terapeuta
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TherapistScreen()),
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

  // Fazer login nativo
  Future<void> _signInWithNative() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isNativeLoading = true;
      _errorMessage = null;
    });

    try {
      final therapistData = await NativeAuthService.signInTherapistWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (therapistData != null && mounted) {
        // Login bem-sucedido, navegar para a tela do terapeuta
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TherapistScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isNativeLoading = false;
          _errorMessage = _getNativeErrorMessage(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNativeLoading = false;
        });
      }
    }
  }

  // Converter mensagens de erro do Google para algo mais amigável
  String _getErrorMessage(String error) {
    if (error.contains('Email não autorizado')) {
      return 'Este email não está autorizado para acesso de terapeuta.\nEntre em contato com o administrador.';
    } else if (error.contains('network')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    } else if (error.contains('cancelled')) {
      return 'Login cancelado.';
    } else {
      return 'Erro no login. Tente novamente.';
    }
  }

  // Converter mensagens de erro nativo
  String _getNativeErrorMessage(String error) {
    if (error.contains('Email não encontrado')) {
      return 'Email não cadastrado no sistema';
    } else if (error.contains('não está autorizado')) {
      return 'Este email não tem permissão de terapeuta';
    } else if (error.contains('Senha incorreta')) {
      return 'Senha incorreta';
    } else {
      return 'Erro no login nativo. Tente novamente';
    }
  }

  // Voltar para a tela inicial
  void _goBack() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  // Mostrar informações de cadastro
  void _showRegistrationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Como me cadastrar?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para obter acesso ao sistema Lumimi como terapeuta:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
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
                      Icon(Icons.email, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Entre em contato:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(
                    'cogluna.contact@gmail.com',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Solicite seu cadastro como terapeuta e aguarde as instruções de acesso.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        colors: [
          Colors.green.shade400,
          Colors.green.shade700,
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Botão voltar
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                ),

                const SizedBox(height: 20),

                // Ícone
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.green,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 32),

                // Título
                const Text(
                  'Acesso do Terapeuta',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                // Subtítulo
                Text(
                  'Escolha sua forma de acesso ao sistema',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withAlpha(220),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

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
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // LOGIN NATIVO
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Login com Email e Senha',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Campo Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'Digite seu email',
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Digite seu email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Email inválido';
                                  }
                                  return null;
                                },
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Campo Senha
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  hintText: 'Digite sua senha',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Digite sua senha';
                                  }
                                  return null;
                                },
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Botão Login Nativo
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isNativeLoading ? null : _signInWithNative,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isNativeLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Entrar',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OU',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // LOGIN GOOGLE
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
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'G',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
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

                      const SizedBox(height: 20),

                      // Botão de Cadastro
                      TextButton(
                        onPressed: _showRegistrationInfo,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade600,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Não tem cadastro? Clique aqui',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Informações adicionais
                      Text(
                        'Ao fazer login, você concorda com os termos de uso e política de privacidade.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.4,
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
                          'Login seguro e criptografado.\nSeus dados estão protegidos.',
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 14,
                          ),
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