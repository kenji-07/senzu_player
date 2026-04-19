import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../senzu_cast_controller.dart';
import '../senzu_cast_service.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

/// Cast button — panel-г нээж/хаадаг. showModalBottomSheet байхгүй.
class SenzuCastButton extends StatelessWidget {
  const SenzuCastButton({
    super.key,
    required this.castController,
    required this.bundle,
    this.iconColor = Colors.white,
    this.iconSize = 22.0,
  });

  final SenzuCastController castController;
  final SenzuPlayerBundle bundle;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = castController.castState.value;

      final (icon, color, tooltip) = switch (state) {
        SenzuCastState.connected => (
          Icons.cast_connected,
          Colors.lightBlueAccent,
          'Cast холбогдсон',
        ),
        SenzuCastState.connecting => (
          Icons.cast,
          Colors.orangeAccent,
          'Холбогдож байна...',
        ),
        SenzuCastState.noDevicesAvailable => (
          Icons.cast,
          Colors.white38,
          'Төхөөрөмж олдсонгүй',
        ),
        _ => (Icons.cast, iconColor, 'Cast хийх'),
      };

      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => bundle.ui.togglePanel(SenzuPanel.cast),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: state == SenzuCastState.connecting
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: color,
                    ),
                  )
                : Icon(icon, color: color, size: iconSize),
          ),
        ),
      );
    });
  }
}