import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureCastPage extends StatefulWidget {
  const FeatureCastPage({Key? key}) : super(key: key);

  @override
  State<FeatureCastPage> createState() => _FeatureCastPageState();
}

class _FeatureCastPageState extends State<FeatureCastPage> {
  late final SenzuCastController _castController;

  @override
  void initState() {
    super.initState();
    _castController =
        SenzuCastController(appId: SenzuCastController.kDefaultApplicationId);
    _castController.onInit();
  }

  @override
  void dispose() {
    _castController.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('6. Google Cast'),
        backgroundColor: Colors.black,
        actions: [
          // ── Cast state indicator ─────────────────────────────────────────
          Obx(() {
            final state = _castController.castState.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                backgroundColor: _stateColor(state).withValues(alpha: 0.15),
                label: Text(
                  _stateLabel(state),
                  style: TextStyle(color: _stateColor(state), fontSize: 11),
                ),
                side: BorderSide(
                    color: _stateColor(state).withValues(alpha: 0.4)),
              ),
            );
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cast icon appears in the top-right controls.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Tap Cast icon → device picker panel\n'
                    '• Select device → connects and transfers playback\n'
                    '• Quality / Subtitle / Audio available on receiver\n'
                    '• Disconnect → resumes local at cast position',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 11, height: 1.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Player with cast ───────────────────────────────────────────
            _label('Player with Cast enabled'),
            SenzuPlayer(
              source: {
                '1080p': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                ),
                '720p': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                ),
                '480p': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                ),
              },
              castController: _castController,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'Tears of Steel',
                description: 'Cast demo — Unified Streaming',
              ),
              isLive: false,
              style: SenzuPlayerStyle(
                senzuLanguage: const SenzuLanguage(
                  cast: 'Cast',
                  quality: 'Quality',
                  subtitles: 'Subtitles',
                  audio: 'Audio',
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Cast remote state ──────────────────────────────────────────
            _label('Remote State'),
            Obx(() {
              final remote = _castController.remoteState.value;
              final cast = _castController.castState.value;
              if (cast != SenzuCastState.connected) {
                return const Text(
                  'Not connected',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                );
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('State', remote.sessionState.name),
                    _infoRow('Position', '${remote.positionMs ~/ 1000}s'),
                    _infoRow('Duration', '${remote.durationMs ~/ 1000}s'),
                    _infoRow('Playing', '${remote.isPlaying}'),
                    _infoRow('Volume', remote.volume.toStringAsFixed(2)),
                    _infoRow('Active tracks', remote.activeTrackIds.toString()),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // ── Manual cast controls ───────────────────────────────────────
            _label('Manual Cast Controls'),
            Obx(() {
              final connected =
                  _castController.castState.value == SenzuCastState.connected;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _btn('Discover', () => _castController.discoverDevices()),
                  _btn('Show Picker', () => _castController.showDevicePicker()),
                  if (connected) ...[
                    _btn('Play', () => _castController.play()),
                    _btn('Pause', () => _castController.pause()),
                    _btn('Seek +30s', () {
                      final pos =
                          _castController.remoteState.value.positionMs + 30000;
                      _castController.seekTo(Duration(milliseconds: pos));
                    }),
                    _btn('Disconnect', () => _castController.disconnect(),
                        color: Colors.red),
                  ],
                ],
              );
            }),

            const SizedBox(height: 24),

            // ── Available devices ──────────────────────────────────────────
            _label('Available Devices'),
            Obx(() {
              final devices = _castController.availableDevices;
              if (devices.isEmpty) {
                return const Text(
                  'No devices found. Tap "Discover" to search.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                );
              }
              return Column(
                children: devices
                    .map((d) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cast,
                              color: Colors.white54, size: 20),
                          title: Text(d.deviceName,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                          subtitle: Text(d.modelName,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          onTap: () => _castController.connectToDevice(d),
                        ))
                    .toList(),
              );
            }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _stateColor(SenzuCastState s) {
    switch (s) {
      case SenzuCastState.connected:
        return Colors.lightBlueAccent;
      case SenzuCastState.connecting:
        return Colors.orange;
      case SenzuCastState.noDevicesAvailable:
        return Colors.white38;
      default:
        return Colors.white24;
    }
  }

  String _stateLabel(SenzuCastState s) {
    switch (s) {
      case SenzuCastState.connected:
        return 'Connected';
      case SenzuCastState.connecting:
        return 'Connecting…';
      case SenzuCastState.noDevicesAvailable:
        return 'No devices';
      default:
        return 'Not connected';
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  Widget _infoRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(k,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            Text(v,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );

  Widget _btn(String label, VoidCallback onTap,
          {Color color = const Color(0xFF00CA13)}) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: onTap,
        child: Text(label),
      );
}
