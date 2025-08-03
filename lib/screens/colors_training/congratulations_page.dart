// lib/screens/colors_training/congratulations_page.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../../constants/colors.dart';
import '../common_widgets/gradient_background.dart';
import '../colors_training/dashboard_page.dart'; // Para acessar o TrainingType

class CongratulationsPage extends StatelessWidget {
  final VoidCallback onContinue;
  final TrainingType trainingType; // 🆕 Novo parâmetro obrigatório
  
  const CongratulationsPage({
    super.key, 
    required this.onContinue,
    required this.trainingType, // 🆕 Obrigatório
  });
  
  // 🆕 Método para obter mensagem baseada no tipo de treino
  String _getSuccessMessage() {
    switch (trainingType) {
      case TrainingType.colors:
        return "Você acertou a cor! Vamos continuar jogando?";
      case TrainingType.shapes:
        return "Você acertou a forma! Vamos continuar jogando?";
      case TrainingType.quantities:
        return "Você acertou a quantidade! Vamos continuar jogando?";
    }
  }
  
  // 🆕 Método para obter texto do botão baseado no tipo de treino
  String _getButtonText() {
    switch (trainingType) {
      case TrainingType.colors:
        return "Próxima Cor";
      case TrainingType.shapes:
        return "Próxima Forma";
      case TrainingType.quantities:
        return "Próxima Quantidade";
    }
  }
  
  // 🆕 Método para obter ícone baseado no tipo de treino
  IconData _getButtonIcon() {
    switch (trainingType) {
      case TrainingType.colors:
        return Icons.palette;
      case TrainingType.shapes:
        return Icons.category;
      case TrainingType.quantities:
        return Icons.filter_9_plus;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        colors: AppColors.congratulationsGradient,
        child: Stack(
          children: [
            // Confettis animados (simulados com círculos estáticos)
            for (int i = 0; i < 30; i++)
              Positioned(
                left: Random().nextDouble() * MediaQuery.of(context).size.width,
                top: Random().nextDouble() * MediaQuery.of(context).size.height,
                child: Container(
                  width: Random().nextDouble() * 10 + 5,
                  height: Random().nextDouble() * 10 + 5,
                  decoration: BoxDecoration(
                    color: Color((Random().nextDouble() * 0xFFFFFF).toInt() << 0)
                        .withOpacity(1.0),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            
            // Conteúdo principal
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sentiment_very_satisfied,
                    color: Colors.green,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Parabéns!",
                  style: TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 30),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _getSuccessMessage(), // 🆕 Mensagem dinâmica
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onContinue();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getButtonIcon()), // 🆕 Ícone dinâmico
                      SizedBox(width: 10),
                      Text(
                        _getButtonText(), // 🆕 Texto do botão dinâmico
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}