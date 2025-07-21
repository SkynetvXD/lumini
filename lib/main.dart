import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/learner_service.dart';
import 'app.dart';
import 'screens/home/home_screen.dart';

void main() async {
  // Garante que os widgets Flutter estejam inicializados
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Erro ao inicializar Firebase: $e');
  }
  
  // Verifica se já há aprendizes cadastrados
  final hasLearners = await LearnerService.hasLearners();
  
  // Se houver aprendizes, atualiza o último acesso do aprendiz atual
  if (hasLearners) {
    await LearnerService.updateCurrentLearnerLastAccess();
  }
  
  // Inicia o app sempre com a tela inicial
  runApp(const MyAppWrapper());
}

class MyAppWrapper extends StatelessWidget {
  const MyAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
      builder: (context, child) {
        // Garante que diálogos e telas não ultrapassem o tamanho da tela
        return LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 600, // Limite opcional para tablets
                minWidth: 320, // Limite mínimo para celulares pequenos
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}