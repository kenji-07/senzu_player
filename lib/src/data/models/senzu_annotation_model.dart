import 'package:flutter/material.dart';

class SenzuAnnotation {
  const SenzuAnnotation({
    required this.id,
    required this.text,
    required this.appearAt,
    required this.disappearAt,
    this.alignment = Alignment.topRight,
    this.onTap,
  });
  final String id;
  final String text;
  final Duration appearAt;
  final Duration disappearAt;
  final AlignmentGeometry alignment;
  final VoidCallback? onTap;
}
