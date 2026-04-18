import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
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
          onTap: () => _onTap(context, state),
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

  void _onTap(BuildContext context, SenzuCastState state) {
    if (state == SenzuCastState.connected) {
      _showConnectedSheet(context);
    } else {
      _showDevicePickerSheet(context);
    }
  }

  // ── Device Picker Sheet ───────────────────────────────────────────────────
  void _showDevicePickerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DevicePickerSheet(castController: castController),
    );
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

// ── Device Picker Sheet ───────────────────────────────────────────────────────
class _DevicePickerSheet extends StatefulWidget {
  const _DevicePickerSheet({required this.castController});
  final SenzuCastController castController;

  @override
  State<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<_DevicePickerSheet> {
  List<SenzuCastDeviceInfo> _devices = [];
  bool _loading = true;
  String? _connectingId;
  StreamSubscription? _deviceSub;

  @override
  void initState() {
    super.initState();

    // ← Энэ заавал байх ёстой
    SenzuCastService.startListening();

    _deviceSub = SenzuCastService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
          _loading = false;
        });
      }
    });

    _discover();
  }

  Future<void> _discover() async {
    setState(() => _loading = true);

    // Хэдийнэ олдсон device-уудыг шууд авах
    final existing = await SenzuCastService.discoverDevices();
    if (mounted && existing.isNotEmpty) {
      setState(() {
        _devices = existing;
        _loading = false;
      });
      return;
    }

    // Шинэ device хайх — 5 секунд хүлээнэ
    await Future.delayed(const Duration(seconds: 5));

    final devices = await SenzuCastService.discoverDevices();
    if (mounted) {
      setState(() {
        _devices = devices;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    super.dispose();
  }

  Future<void> _connect(SenzuCastDeviceInfo device) async {
    setState(() => _connectingId = device.deviceId);
    await SenzuCastService.connectToDevice(device.deviceId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title + refresh
          Row(
            children: [
              const Icon(Icons.cast, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Cast хийх төхөөрөмж',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _discover,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Content
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Төхөөрөмж хайж байна...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.cast, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Төхөөрөмж олдсонгүй',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Chromecast нэг WiFi дотор байгаа эсэхийг шалгана уу',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _devices.length,
              itemBuilder: (_, i) {
                final device = _devices[i];
                final isConnecting = _connectingId == device.deviceId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cast,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    device.deviceName,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: device.modelName.isNotEmpty
                      ? Text(
                          device.modelName,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        )
                      : null,
                  trailing: isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.lightBlueAccent,
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Colors.white38,
                          size: 20,
                        ),
                  onTap: isConnecting ? null : () => _connect(device),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Connected Sheet (өмнөх кодоос хэвээр) ────────────────────────────────────
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Device info
            Row(
              children: [
                const Icon(
                  Icons.cast_connected,
                  color: Colors.lightBlueAccent,
                  size: 24,
                ),
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
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Subtitle selector
            if (castController.subtitleTracks.isNotEmpty) ...[
              const Divider(color: Colors.white12),
              const Text(
                'Subtitle',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Obx(
                () => Wrap(
                  spacing: 6,
                  children: [
                    _TrackChip(
                      label: 'Off',
                      selected:
                          castController.activeSubtitleTrackId.value == null,
                      onTap: castController.disableSubtitles,
                    ),
                    ...castController.subtitleTracks.map(
                      (t) => _TrackChip(
                        label: t.name,
                        selected:
                            castController.activeSubtitleTrackId.value == t.id,
                        onTap: () => castController.setSubtitle(t.id),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Quality selector
            if (castController.qualityOptions.isNotEmpty) ...[
              const Divider(color: Colors.white12),
              const Text(
                'Quality',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Obx(
                () => Wrap(
                  spacing: 6,
                  children: castController.qualityOptions
                      .map(
                        (q) => _TrackChip(
                          label: q.label,
                          selected:
                              castController.activeQuality.value == q.label,
                          onTap: () => castController.switchQuality(q.label),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],

            // Volume slider
            Obx(
              () => Row(
                children: [
                  const Icon(Icons.volume_up, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: castController.remoteState.value.volume,
                      onChanged: castController.setCastVolume,
                      activeColor: Colors.red,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Progress bar
            if (remote.durationMs > 0) ...[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.red,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.red,
                  trackHeight: 3,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: (remote.positionMs / remote.durationMs).clamp(
                    0.0,
                    1.0,
                  ),
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
                    Text(
                      _fmt(Duration(milliseconds: remote.positionMs)),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _fmt(Duration(milliseconds: remote.durationMs)),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
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
                  icon: remote.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
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

class _TrackChip extends StatelessWidget {
  const _TrackChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? Colors.red : Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 11,
        ),
      ),
    ),
  );
}
