import 'package:flutter/material.dart';

enum WatermarkPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
  random
}

class SenzuWatermark {
  const SenzuWatermark({
    this.userId,
    this.customText,
    this.opacity = 0.18,
    this.fontSize = 13.0,
    this.color = Colors.white,
    this.position = WatermarkPosition.random,
    this.moveDuration = const Duration(seconds: 30),
    this.showTimestamp = true,
    this.showUserId = true,
  });

  final String? userId;
  final String? customText;
  final double opacity;
  final double fontSize;
  final Color color;
  final WatermarkPosition position;
  final Duration moveDuration;
  final bool showTimestamp;
  final bool showUserId;

  String buildText() {
    final parts = <String>[];
    if (showUserId && userId != null) parts.add(userId!);
    if (customText != null) parts.add(customText!);
    if (showTimestamp) {
      final now = DateTime.now();
      parts.add('${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}');
    }
    return parts.join('  ·  ');
  }
}
