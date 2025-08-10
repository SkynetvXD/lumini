// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home/home_screen.dart';
import 'screens/menu/menu_trainings_page.dart';
import 'services/patient_auth_service.dart';
import 'services/auth_service.dart';
import 'services/unified_auth_service.dart';
import 'services/sync_service.dart';

void main() async {
  // Garantir que o Flutter está inicializado
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // ✅ INICIALIZAR FIREBASE COM OPÇÕES CORRETAS
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // ← IMPORTANTE!
    );
    print('🔥 Firebase inicializado com sucesso');
    
    // Verificar se Firebase está realmente funcionando
    final FirebaseAuth auth = FirebaseAuth.instance;
    print('🔐 Firebase Auth inicializado: ${auth.app.name}');
    
    // Inicializar serviços
    await SyncService.initialize();
    print('🔄 SyncService inicializado');
    
  } catch (e) {
    print('❌ ERRO CRÍTICO na inicialização do Firebase: $e');
    // Em caso de erro crítico, mostrar tela de erro
    runApp(ErrorApp(error: e.toString()));
    return;
  }
  
  runApp(const LumimiApp());
}

/// App de erro para quando Firebase falha completamente
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Erro de Inicialização',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'O app não pôde ser inicializado corretamente.\n\nErro: $error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    _checkInitialAuth();
  }

  /// Verificar estado de autenticação inicial
  Future<void> _checkInitialAuth() async {
    try {
      // ✅ VERIFICAR SE FIREBASE ESTÁ INICIALIZADO
      if (Firebase.apps.isEmpty) {
        print('❌ Firebase não está inicializado');
        setState(() {
          _initialScreen = const HomeScreen();
          _isLoading = false;
        });
        return;
      }

      print('🔍 Verificando autenticação inicial...');
      
      // Verificar se algum usuário está logado (usando UnifiedAuthService)
      final isTherapistLoggedIn = await UnifiedAuthService.isTherapistLoggedIn();
      final isPatientLoggedIn = await UnifiedAuthService.isPatientLoggedIn();
      
      if (isTherapistLoggedIn) {
        print('✅ Terapeuta logado - redirecionando para TherapistScreen');
        // Importar e usar TherapistScreen
        setState(() {
          _initialScreen = const HomeScreen(); // Ou TherapistScreen
          _isLoading = false;
        });
      } else if (isPatientLoggedIn) {
        print('✅ Paciente logado - redirecionando para MenuTrainingsPage');
        setState(() {
          _initialScreen = const MenuTrainingsPage();
          _isLoading = false;
        });
      } else {
        print('ℹ️ Nenhum usuário logado - mostrando HomeScreen');
        setState(() {
          _initialScreen = const HomeScreen();
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print('❌ Erro na verificação de autenticação: $e');
      setState(() {
        _initialScreen = const HomeScreen();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Inicializando Lumimi...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    return _initialScreen;
  }
}