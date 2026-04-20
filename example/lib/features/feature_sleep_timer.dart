import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';


class FeatureSleepTimerPage extends StatefulWidget {
  const FeatureSleepTimerPage({Key? key}) : super(key: key);
  @override
  State<FeatureSleepTimerPage> createState() => _FeatureSleepTimerPageState();
}

class _FeatureSleepTimerPageState extends State<FeatureSleepTimerPage> {
  late final SenzuPlayerBundle _bundle;

  @override
  void initState() {
    super.initState();
    _bundle = SenzuPlayerBundle.create();
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
      appBar: AppBar(title: const Text('9. Sleep Timer'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Sleep timer panel — tap bedtime icon in top controls'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              bundle: _bundle,
              enableSleep: true,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Sleep Timer Demo'),
            ),
            const SizedBox(height: 20),

            _label('Manual timer controls'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('Start 1 min', () => _bundle.sleepTimer.start(const Duration(minutes: 1))),
                _btn('Start 5 min', () => _bundle.sleepTimer.start(const Duration(minutes: 5))),
                _btn('Start 30s (demo)', () => _bundle.sleepTimer.start(const Duration(seconds: 30))),
                _btn('Stop', () => _bundle.sleepTimer.stop(), color: Colors.red),
                _btn('Cancel fade', () => _bundle.sleepTimer.cancel(), color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),

            // ── Live remaining time ────────────────────────────────────────
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (_, __) {
                final rem = _bundle.sleepTimer.remainingTime.value;
                final active = _bundle.sleepTimer.isActive.value;
                final sleeping = _bundle.sleepTimer.isSleeping.value;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Active', '$active'),
                      _row('Sleeping', '$sleeping'),
                      _row('Remaining',
                          rem != null ? '${rem.inMinutes}:${(rem.inSeconds % 60).toString().padLeft(2, '0')}' : '—'),
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
              width: 80,
              child: Text(k, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            Text(v, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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