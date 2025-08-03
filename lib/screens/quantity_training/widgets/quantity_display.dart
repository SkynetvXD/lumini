import 'package:flutter/material.dart';
import 'dart:math';

class QuantityDisplay extends StatelessWidget {
  final int quantity;
  
  const QuantityDisplay({
    super.key,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    // 🆕 Obter dimensões da tela para responsividade
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 🆕 Calcular tamanhos baseados na tela
    final containerWidth = min(screenWidth * 0.8, 300.0);
    final containerHeight = min(screenHeight * 0.2, 150.0);
    
    return Container(
      width: containerWidth,
      height: containerHeight,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _buildItemsDisplay(quantity, containerWidth, containerHeight),
    );
  }
  
  // 🆕 Função atualizada com parâmetros de tamanho
  Widget _buildItemsDisplay(int quantity, double width, double height) {
    final random = Random();
    
    // Uma lista de possíveis ícones para usar
    final List<IconData> icons = [
      Icons.star,
      Icons.favorite,
      Icons.pets,
      Icons.emoji_emotions,
      Icons.cake,
      Icons.wb_sunny,
      Icons.local_florist,
    ];
    
    // Escolher um ícone aleatório para esta exibição
    final selectedIcon = icons[random.nextInt(icons.length)];
    
    // Escolher uma cor aleatória para esta exibição
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    final selectedColor = colors[random.nextInt(colors.length)];
    
    // 🆕 Calcular tamanho do ícone baseado no container
    final iconSize = min(width / 10, height / 5).clamp(25.0, 45.0);
    
    // Organizar os ícones em linhas e colunas (máximo 5 por linha)
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        quantity,
        (index) => Icon(
          selectedIcon,
          color: selectedColor,
          size: iconSize,
        ),
      ),
    );
  }
}