import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';


class FeatureThumbnailSpritePage extends StatelessWidget {
  const FeatureThumbnailSpritePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('11. Thumbnail Sprite'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBox(
              'Drag the seek bar to see thumbnail preview from a sprite sheet.\n'
              'Replace sprite URL with your own WebVTT sprite or direct image.',
            ),
            const SizedBox(height: 16),

            _label('Seek thumbnail preview (10-column × 10-row sprite)'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                  thumbnailSprite: const SenzuThumbnailSprite(
                    url:         'https://www.iandevlin.com/html5test/webvtt/upc-tobymanifest-thumbnails.jpg',
                    columns:     10,
                    rows:        10,
                    intervalSec: 10,
                  ),
                ),
              },
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'Thumbnail Sprite',
                description: 'Seek to see frame preview',
              ),
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
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.6)),
      );
}
