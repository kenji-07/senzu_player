import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureBundlePage extends StatefulWidget {
  const FeatureBundlePage({Key? key}) : super(key: key);
  @override
  State<FeatureBundlePage> createState() => _FeatureBundlePageState();
}

class _FeatureBundlePageState extends State<FeatureBundlePage> {
  late final SenzuPlayerBundle _bundle;

  @override
  void initState() {
    super.initState();
    _bundle = SenzuPlayerBundle.create(looping: false, adaptiveBitrate: true);
  }

  @override
  void dispose() {
    _bundle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('16. External Bundle'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Player controlled from outside'),
            SenzuPlayer(
              source: {
                '1080p': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
                '720p': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              bundle: _bundle,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'External Bundle Control',
                description: 'Controlled programmatically',
              ),
            ),
            const SizedBox(height: 20),

            // ── Playback controls ──────────────────────────────────────────
            _label('Playback'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('▶ Play',  () => _bundle.core.play()),
                _btn('⏸ Pause', () => _bundle.core.pause()),
                _btn('⏮ Seek 0', () => _bundle.core.seekTo(Duration.zero)),
                _btn('⏭ Seek 1min',
                    () => _bundle.core.seekTo(const Duration(minutes: 1))),
                _btn('+10s', () => _bundle.core.seekBySeconds(10)),
                _btn('-10s', () => _bundle.core.seekBySeconds(-10)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Speed ──────────────────────────────────────────────────────
            _label('Playback Speed'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0.5, 1.0, 1.25, 1.5, 2.0]
                  .map((s) => _btn(
                        '$s×',
                        () => _bundle.core.setPlaybackSpeed(s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // ── Volume ─────────────────────────────────────────────────────
            _label('Volume'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0.0, 0.25, 0.5, 0.75, 1.0]
                  .map((v) => _btn(
                        '${(v * 100).toInt()}%',
                        () => _bundle.device.setVolume(v),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // ── Brightness ─────────────────────────────────────────────────
            _label('Brightness'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0.1, 0.3, 0.5, 0.7, 1.0]
                  .map((b) => _btn(
                        '${(b * 100).toInt()}%',
                        () => _bundle.device.setBrightness(b),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // ── Sleep timer ────────────────────────────────────────────────
            _label('Sleep Timer'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('1 min', () => _bundle.sleepTimer.start(const Duration(minutes: 1))),
                _btn('5 min', () => _bundle.sleepTimer.start(const Duration(minutes: 5))),
                _btn('Stop', () => _bundle.sleepTimer.stop(), color: Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            // ── Live state monitor ─────────────────────────────────────────
            _label('Live State'),
            StreamBuilder(
              stream: Stream.periodic(const Duration(milliseconds: 300)),
              builder: (_, __) {
                final s = _bundle.core.rxNativeState.value;
                final pb = _bundle.playback;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Initialized', '${s.isInitialized}'),
                      _row('Playing',     '${pb.isPlaying.value}'),
                      _row('Buffering',   '${pb.isBuffering.value}'),
                      _row('Position',    '${pb.position.value.inSeconds}s'),
                      _row('Duration',    '${pb.duration.value.inSeconds}s'),
                      _row('Speed',       '${_bundle.core.playbackSpeed}×'),
                      _row('Volume',      _bundle.device.volume.value.toStringAsFixed(2)),
                      _row('Battery',     '${_bundle.device.batteryLevel.value}% — ${_bundle.device.batteryState.value}'),
                      _row('Active src',  _bundle.core.rxActiveSource.value ?? '—'),
                      _row('Error',       s.errorDescription ?? 'none'),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(k, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
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