import 'package:flutter/material.dart';

class SenzuMetaData {
  const SenzuMetaData({
    this.show = true,
    this.title,
    this.description,
    this.posterUrl,
    this.icon = Icons.arrow_back,
    this.iconColor = Colors.white,
    this.iconSize = 20,
    this.titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    this.descriptionStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),
  });

  final bool? show;
  final String? title;
  final String? description;
  final String? posterUrl;
  final IconData? icon;
  final Color? iconColor;
  final double? iconSize;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
}
