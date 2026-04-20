import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureDrmPage extends StatelessWidget {
  const FeatureDrmPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('4. DRM'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replace license/certificate URLs with your own DRM server endpoints.',
                      style: TextStyle(
                          color: Colors.orange.shade200, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── FairPlay (iOS only) ────────────────────────────────────────
            if (defaultTargetPlatform == TargetPlatform.iOS) ...[
              _label('FairPlay Streaming (iOS)'),
              SenzuPlayer(
                source: {
                  'FPS': VideoSource.fromUrl(
                    'https://your-fps-stream.example.com/stream.m3u8',
                    drm: const SenzuDrmConfig.fairPlay(
                      licenseUrl:
                          'https://your-license-server.example.com/fps/license',
                      certificateUrl:
                          'https://your-license-server.example.com/fps/cert',
                      headers: {
                        'Authorization': 'Bearer YOUR_TOKEN',
                        'X-Custom-Header': 'value',
                      },
                    ),
                  ),
                },
                defaultAspectRatio: 16 / 9,
                secureMode: true,
                meta: const SenzuMetaData(
                  title: 'FairPlay DRM',
                  description: 'iOS FPS protected content',
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Widevine (Android only) ────────────────────────────────────
            if (defaultTargetPlatform == TargetPlatform.android) ...[
              _label('Widevine DRM (Android)'),
              SenzuPlayer(
                source: {
                  'Widevine': VideoSource.fromDashUrl(
                    'https://your-widevine-stream.example.com/stream.mpd',
                    drm: const SenzuDrmConfig.widevine(
                      licenseUrl:
                          'https://your-license-server.example.com/widevine',
                      headers: {
                        'Authorization': 'Bearer YOUR_TOKEN',
                      },
                    ),
                  ),
                },
                defaultAspectRatio: 16 / 9,
                secureMode: true,
                meta: const SenzuMetaData(
                  title: 'Widevine DRM',
                  description: 'Android Widevine protected content',
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Secure mode (screenshot block) ────────────────────────────
            _label('Secure Mode — Screenshot Blocked'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                ),
              },
              defaultAspectRatio: 16 / 9,
              secureMode: true,
              meta: const SenzuMetaData(
                title: 'Secure Mode',
                description: 'Screenshots and screen recording blocked',
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
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );
}
