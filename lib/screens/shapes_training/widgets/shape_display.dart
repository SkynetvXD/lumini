import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'shape_painter.dart';

class ShapeDisplay extends StatelessWidget {
  final int currentShape;
  final Color color;
  
  const ShapeDisplay({
    super.key,
    required this.currentShape,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 🆕 Obter dimensões da tela para responsividade
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 🆕 Calcular tamanhos baseados na tela
    final containerSize = math.min(screenWidth * 0.4, screenHeight * 0.2).clamp(120.0, 180.0);
    final paintSize = containerSize * 0.8;
    
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(paintSize, paintSize),
          painter: ShapePainter(
            shapeType: currentShape,
            color: color,
          ),
        ),
      ),
    );
  }
}