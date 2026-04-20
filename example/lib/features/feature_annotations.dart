import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';


class FeatureAnnotationsPage extends StatefulWidget {
  const FeatureAnnotationsPage({Key? key}) : super(key: key);
  @override
  State<FeatureAnnotationsPage> createState() => _Feature8AnnotationsPageState();
}

class _Feature8AnnotationsPageState extends State<FeatureAnnotationsPage> {
  String _lastTap = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('8. Annotations'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Tappable overlays at specific timestamps'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                ),
              },
              annotations: [
                SenzuAnnotation(
                  id: 'promo_1',
                  text: '🎁 Special offer — Tap to claim!',
                  appearAt: const Duration(seconds: 5),
                  disappearAt: const Duration(seconds: 15),
                  alignment: Alignment.topRight,
                  onTap: () => setState(() => _lastTap = 'Promo tapped at 0:05'),
                ),
                SenzuAnnotation(
                  id: 'chapter_2',
                  text: '📖 Chapter 2 starts',
                  appearAt: const Duration(seconds: 20),
                  disappearAt: const Duration(seconds: 28),
                  alignment: Alignment.topLeft,
                  onTap: () => setState(() => _lastTap = 'Chapter 2 annotation tapped'),
                ),
                SenzuAnnotation(
                  id: 'subscribe',
                  text: '🔔 Subscribe now',
                  appearAt: const Duration(seconds: 40),
                  disappearAt: const Duration(seconds: 55),
                  alignment: Alignment.bottomRight,
                  onTap: () => setState(() => _lastTap = 'Subscribe tapped'),
                ),
                SenzuAnnotation(
                  id: 'poll',
                  text: '📊 Vote: Did you like this?',
                  appearAt: const Duration(minutes: 1),
                  disappearAt: const Duration(minutes: 1, seconds: 15),
                  alignment: Alignment.center,
                  onTap: () => setState(() => _lastTap = 'Poll tapped'),
                ),
              ],
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Annotations Demo'),
            ),
            if (_lastTap.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00CA13).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00CA13).withValues(alpha: 0.3)),
                ),
                child: Text(_lastTap,
                    style: const TextStyle(color: Color(0xFF00CA13), fontSize: 12)),
              ),
            ],
            const SizedBox(height: 16),
            _infoBox(
              '• Annotations appear/disappear based on playback position\n'
              '• Scan runs every 250ms with set-based diff\n'
              '• Each annotation is tappable with a custom callback\n'
              '• Hidden when overlay controls are visible',
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

  Widget _infoBox(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.7)),
      );
}
