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
            padding: style.hdrBadgeStyle.padding,
            decoration: style.hdrBadgeStyle.decoration,
            child: Text(
              style.senzuLanguage.hdr,
              style: style.hdrBadgeStyle.textStyle,
            ),
          ),
        );
      });
}
