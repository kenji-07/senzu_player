import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';


class FeatureWatermarkPage extends StatelessWidget {
  const FeatureWatermarkPage({Key? key}) : super(key: key);

  static const _url =
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('7. Watermark'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Random moving watermark (userId + timestamp)'),
            SenzuPlayer(
              source: {'Auto': VideoSource.fromUrl(_url)},
              watermark: const SenzuWatermark(
                userId: 'user_88492',
                showTimestamp: true,
                opacity: 0.22,
                fontSize: 13,
                color: Colors.white,
                position: WatermarkPosition.random,
                moveDuration: Duration(seconds: 20),
              ),
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Random Watermark'),
            ),
            const SizedBox(height: 24),

            _label('Fixed position — bottom right'),
            SenzuPlayer(
              source: {'Auto': VideoSource.fromUrl(_url)},
              watermark: const SenzuWatermark(
                customText: '© MyPlatform',
                showUserId: false,
                showTimestamp: false,
                opacity: 0.3,
                fontSize: 12,
                color: Colors.white70,
                position: WatermarkPosition.bottomRight,
              ),
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Fixed Watermark'),
            ),
            const SizedBox(height: 24),

            _label('Center watermark — all fields'),
            SenzuPlayer(
              source: {'Auto': VideoSource.fromUrl(_url)},
              watermark: const SenzuWatermark(
                userId: 'premium_user',
                customText: 'CONFIDENTIAL',
                showTimestamp: true,
                opacity: 0.15,
                fontSize: 14,
                color: Colors.redAccent,
                position: WatermarkPosition.center,
              ),
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Center Watermark'),
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
}
