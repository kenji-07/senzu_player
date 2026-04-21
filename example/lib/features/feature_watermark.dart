import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';


class FeatureWatermarkPage extends StatelessWidget {
  const FeatureWatermarkPage({Key? key}) : super(key: key);

  static const _url =
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

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
