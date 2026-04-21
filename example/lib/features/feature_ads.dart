import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureAdsPage extends StatelessWidget {
  const FeatureAdsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar:
          AppBar(title: const Text('13. Ads'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _label('Mid-roll ad at 50% + custom skip button'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                    ads: [
                      SenzuPlayerAd(
                        fractionToStart: 0.5,
                        durationToEnd: const Duration(seconds: 10),
                        durationToSkip: const Duration(seconds: 3),
                        deepLink: 'https://example.com/ad2',
                        child: Container(
                          color: Colors.purple.shade900,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.movie,
                                    color: Colors.white, size: 40),
                                SizedBox(height: 8),
                                Text('Mid-roll Ad (50%)',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    subtitle: {
                      'English': SenzuPlayerSubtitle.network(
                        'https://vjs.zencdn.net/v/oceans.vtt',
                        type: SubtitleType.webvtt,
                      ),
                      'Mongolia': SenzuPlayerSubtitle.network(
                        'https://raw.githubusercontent.com/videojs/video.js/main/docs/examples/shared/example-captions.vtt',
                        type: SubtitleType.webvtt,
                      ),
                      'Test': SenzuPlayerSubtitle.network(
                        'https://raw.githubusercontent.com/shaka-project/shaka-player/main/test/test/assets/text-clip.vtt',
                        type: SubtitleType.webvtt,
                      ),
                    },
                    initialSubtitle: 'English'),
              },
              defaultAspectRatio: 16 / 9,
              autoPlay: false,
              style: SenzuPlayerStyle(
                skipAdBuilder: (watched) {
                  final canSkip = watched >= const Duration(seconds: 3);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: canSkip ? const Color(0xFF00CA13) : Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      canSkip
                          ? 'Skip Ad ▶'
                          : 'Skip in ${3 - watched.inSeconds}s',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
              meta: const SenzuMetaData(title: 'Mid-roll Ad'),
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
