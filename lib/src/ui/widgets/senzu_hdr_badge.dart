import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

class SenzuHdrBadge extends StatelessWidget {
  const SenzuHdrBadge({super.key, required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => Obx(() {
    if (!bundle.core.isHdrEnabled.value) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: style.hdrBadgeStyle.decoration,
        child: Text('HDR', style: style.hdrBadgeStyle.textStyle),
      ),
    );
  });
}
