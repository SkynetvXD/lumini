// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home/home_screen.dart';
import 'screens/menu/menu_trainings_page.dart';
import 'services/patient_auth_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';

void main() async {
  // Garantir que o Flutter está inicializado
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicializar Firebase
    await Firebase.initializeApp();
    print('🔥 Firebase inicializado com sucesso');
    
    // Inicializar serviços
    await SyncService.initialize();
    print('🔄 SyncService inicializado');
    
  } catch (e) {
    print('❌ ERRO na inicialização do Firebase: $e');
    // App pode continuar em modo local se Firebase falhar
  }
  
  runApp(const LumimiApp());
}

class LumimiApp extends StatelessWidget {
  const LumimiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumimi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthStateWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Widget que gerencia o estado de autenticação inicial
class AuthStateWrapper extends StatefulWidget {
  const AuthStateWrapper({super.key});

  @override
  State<AuthStateWrapper> createState() => _AuthStateWrapperState();
}

class _AuthStateWrapperState extends State<AuthStateWrapper> {
  bool _isLoading = true;
  Widget _initialScreen = const HomeScreen();

  @override
  void initState() {
    super.initState();
    _checkInitialAuthState();
  }

  Future<void> _checkInitialAuthState() async {
    try {
      // Verificar se há um paciente logado
      final isPatientLoggedIn = await PatientAuthService.isPatientLoggedIn();
      if (isPatientLoggedIn) {
        print('👨‍⚕️ Paciente já logado, redirecionando para menu');
        setState(() {
          _initialScreen = const MenuTrainingsPage();
          _isLoading = false;
        });
        return;
      }

      // Verificar se há um terapeuta logado
      final isTherapistLoggedIn = await AuthService.isTherapistLoggedIn();
      if (isTherapistLoggedIn) {
        print('👩‍⚕️ Terapeuta já logado, redirecionando para tela do terapeuta');
        // Importar e usar TherapistScreen se existir
        // setState(() {
        //   _initialScreen = const TherapistScreen();
        //   _isLoading = false;
        // });
        // return;
      }

      // Se ninguém está logado, ir para home
      print('🏠 Nenhum usuário logado, indo para HomeScreen');
      setState(() {
        _initialScreen = const HomeScreen();
        _isLoading = false;
      });

    } catch (e) {
      print('❌ ERRO ao verificar estado de autenticação: $e');
      // Em caso de erro, ir para home
      setState(() {
        _initialScreen = const HomeScreen();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: LoadingScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    return _initialScreen;
  }
}

/// Tela de loading inicial
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xFF2196F3),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo ou ícone do app
              Icon(
                Icons.school,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 24),

              // Nome do app
              Text(
                'Lumimi',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),

              // Subtítulo
              Text(
                'Aprendizado Inclusivo',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 48),

              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),

              Text(
                'Inicializando...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}