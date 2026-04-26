import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

class SenzuCellularWarning extends StatelessWidget {
  const SenzuCellularWarning({
    super.key,
    required this.bundle,
    required this.style,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => Obx(() {
        if (!bundle.core.showCellularWarning.value) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: style.cellularWarningStyle.decoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                style.cellularWarningStyle.icon,
                const SizedBox(height: 12),
                Text(
                  style.senzuLanguage.cellularWarningTitle,
                  style: style.cellularWarningStyle.titleStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  style.senzuLanguage.cellularWarningBody,
                  style: style.cellularWarningStyle.bodyStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () =>
                            bundle.core.dismissCellularWarning(dataSaver: true),
                        child: Text(style.senzuLanguage.dataSaver),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => bundle.core.dismissCellularWarning(),
                        child: Text(style.senzuLanguage.cellularContinue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      });
}
