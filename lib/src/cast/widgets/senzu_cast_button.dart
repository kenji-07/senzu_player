import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../senzu_cast_controller.dart';
import '../senzu_cast_service.dart';

class SenzuCastButton extends StatelessWidget {
  const SenzuCastButton({
    super.key,
    required this.castController,
    this.iconColor = Colors.white,
    this.iconSize = 22.0,
  });

  final SenzuCastController castController;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = castController.castState.value;

      final (icon, color, tooltip) = switch (state) {
        SenzuCastState.connected =>
          (Icons.cast_connected, Colors.lightBlueAccent, 'Cast холбогдсон'),
        SenzuCastState.connecting =>
          (Icons.cast,           Colors.orangeAccent,    'Холбогдож байна...'),
        SenzuCastState.noDevicesAvailable =>
          (Icons.cast,           Colors.white38,         'Төхөөрөмж олдсонгүй'),
        _ =>
          (Icons.cast,           iconColor,              'Cast хийх'),
      };

      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => _onTap(context, state),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: state == SenzuCastState.connecting
                ? SizedBox(
                    width:  iconSize,
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

  void _onTap(BuildContext context, SenzuCastState state) {
    if (state == SenzuCastState.connected) {
      _showConnectedSheet(context);
    } else {
      castController.showDevicePicker();
    }
  }

  void _showConnectedSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CastConnectedSheet(castController: castController),
    );
  }
}

class _CastConnectedSheet extends StatelessWidget {
  const _CastConnectedSheet({required this.castController});
  final SenzuCastController castController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final device = castController.availableDevices.firstOrNull;
      final remote = castController.remoteState.value;

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Device info
            Row(
              children: [
                const Icon(Icons.cast_connected,
                    color: Colors.lightBlueAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device?.deviceName ?? 'Cast Device',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (device?.modelName.isNotEmpty == true)
                        Text(
                          device!.modelName,
                          style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Progress bar
            if (remote.durationMs > 0) ...[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor:   Colors.red,
                  inactiveTrackColor: Colors.white24,
                  thumbColor:         Colors.red,
                  trackHeight:        3,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: (remote.positionMs / remote.durationMs).clamp(0.0, 1.0),
                  onChanged: (v) {
                    final posMs = (v * remote.durationMs).toInt();
                    castController.seekTo(Duration(milliseconds: posMs));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(Duration(milliseconds: remote.positionMs)),
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(_fmt(Duration(milliseconds: remote.durationMs)),
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlBtn(
                  icon: Icons.replay_10,
                  onTap: () => castController.seekTo(
                    Duration(milliseconds: remote.positionMs - 10000),
                  ),
                ),
                const SizedBox(width: 16),
                _ControlBtn(
                  icon: remote.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 48,
                  onTap: remote.isPlaying
                      ? castController.pause
                      : castController.play,
                ),
                const SizedBox(width: 16),
                _ControlBtn(
                  icon: Icons.forward_10,
                  onTap: () => castController.seekTo(
                    Duration(milliseconds: remote.positionMs + 10000),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Disconnect button
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                castController.disconnect();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.cast, size: 18),
              label: const Text('Disconnect'),
            ),
          ],
        ),
      );
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.onTap,
    this.size = 32.0,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Icon(icon, color: Colors.white, size: size),
  );
}