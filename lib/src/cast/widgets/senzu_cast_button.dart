import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../senzu_cast_controller.dart';
import '../senzu_cast_service.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';

class SenzuCastButton extends StatelessWidget {
  const SenzuCastButton({
    super.key,
    required this.castController,
    required this.bundle,
    required this.style,
  });

  final SenzuCastController castController;
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle? style;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = castController.castState.value;

      return InkWell(
          onTap: () {
            if (state == SenzuCastState.connected) {
              castController.disconnect();
            } else if (state == SenzuCastState.connecting) {
              bundle.ui.togglePanel(SenzuPanel.cast);
            } else if (state == SenzuCastState.noDevicesAvailable) {
              bundle.ui.togglePanel(SenzuPanel.cast);
            } else if (state == SenzuCastState.notConnected) {
              bundle.ui.togglePanel(SenzuPanel.cast);
            } else {
              bundle.ui.togglePanel(SenzuPanel.cast);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: state == SenzuCastState.connecting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Colors.white,
                    ),
                  )
                : switch (state) {
                    SenzuCastState.connected =>
                      style!.overlayIconsStyle.castConnected,
                    SenzuCastState.noDevicesAvailable =>
                      style!.overlayIconsStyle.castNoDevicesAvailable,
                    _ => style!.overlayIconsStyle.cast,
                  },
          ));
    });
  }
}
