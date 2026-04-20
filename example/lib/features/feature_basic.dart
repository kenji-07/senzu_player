import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureBasicPage extends StatelessWidget {
  const FeatureBasicPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('1. Basic Playback'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Basic HLS ──────────────────────────────────────────────────
            const _SectionLabel('Basic HLS'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'Tears of Steel',
                description: 'Basic HLS demo',
              ),
            ),
            const SizedBox(height: 24),

            // ── MP4 ────────────────────────────────────────────────────────
            const _SectionLabel('MP4 File'),
            SenzuPlayer(
              source: {
                'HD': VideoSource.fromFile(
                  '/sdcard/Download/sample.mp4',
                ),
              },
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Local MP4'),
            ),
            const SizedBox(height: 24),

            // ── Looping ────────────────────────────────────────────────────
            const _SectionLabel('Looping'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              looping: true,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Looping Video'),
            ),
            const SizedBox(height: 24),

            // ── Start at position ──────────────────────────────────────────
            const _SectionLabel('Start at 1 minute'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              seekTo: const Duration(minutes: 1),
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Seeked to 1:00'),
            ),
            const SizedBox(height: 24),

            // ── Custom aspect ratio ────────────────────────────────────────
            const _SectionLabel('4:3 Aspect Ratio'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              defaultAspectRatio: 4 / 3,
              meta: const SenzuMetaData(title: '4:3 Ratio'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
}
