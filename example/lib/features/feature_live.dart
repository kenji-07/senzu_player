import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureLivePage extends StatelessWidget {
  const FeatureLivePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('14. Live Stream'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Basic live ─────────────────────────────────────────────────
            _label('Live stream (LIVE badge, no seek bar)'),
            SenzuPlayer(
              source: {
                'Live': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/live/scte35.isml/.m3u8',
                ),
              },
              isLive: true,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Live Demo', description: 'Unified Streaming live'),
            ),
            const SizedBox(height: 24),

            // ── Low-latency ────────────────────────────────────────────────
            _label('Low-latency live (target 2s)'),
            SenzuPlayer(
              source: {
                'LL-HLS': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/live/scte35.isml/.m3u8',
                  isLowLatency: true,
                  targetLatencyMs: 2000,
                ),
              },
              isLive: true,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'Low-Latency Live',
                description: 'Target latency: 2000ms',
              ),
            ),
            const SizedBox(height: 24),

            // ── DVR live ───────────────────────────────────────────────────
            _label('DVR live stream (seek bar visible)'),
            SenzuPlayer(
              source: {
                'DVR': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/live/scte35.isml/.m3u8',
                ),
              },
              isLive: true,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'DVR Live',
                description: 'Seek backwards in live stream',
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
}
