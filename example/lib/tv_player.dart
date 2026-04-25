import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:senzu_player/senzu_player.dart';

class TVPage extends StatefulWidget {
  const TVPage({super.key});

  @override
  State<TVPage> createState() => _TVPageState();
}

class _TVPageState extends State<TVPage> {
  SenzuPlayerBundle? _externalBundle;
  String lastTap = '';

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _externalBundle = SenzuPlayerBundle.create(
      // ABR
      adaptiveBitrate: false,

      looping: true,
      secureMode: true,
      notification: true,
      onQualityChanged: (q) => _showSnack('Quality: $q'),

      // Watermark
      watermark: const SenzuWatermark(
        userId: 'user_42',
        opacity: 0.14,
        position: WatermarkPosition.bottomRight,
        moveDuration: Duration(seconds: 20),
        showTimestamp: true,
        fontSize: 13,
        color: Colors.white,
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _externalBundle?.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: FocusScope(
          autofocus: true,
          child: SafeArea(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: SenzuPlayer(
                source: VideoSource.fromNetworkVideoSources(
                    {
                      '1080p':
                          'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                      '720p':
                          'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8'
                    },
                    initialSubtitle: 'English',
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
                    }),

                bundle: _externalBundle!,
                defaultAspectRatio: 16 / 9,

                autoPlay: true,
                seekTo: Duration.zero,
                isLive: false,
                isTv: true,

                // UI features
                enableFullscreen: false,
                enableCaption: true,
                enableQuality: true,
                enableSpeed: true,
                enableLock: false,
                enableAspect: true,
                enableEpisode: true,
                enableAudio: true,
                enablePip: false,
                enableSleep: false,

                // Header meta
                meta: const SenzuMetaData(
                  title: 'Player page',
                  description: "Test 1",
                  posterUrl:
                      'https://image.tmdb.org/t/p/original/aWM8eYmhqBgH4YC5WLLPTJxlc2t.jpg',
                  icon: Icons.arrow_back_ios_new,
                  iconColor: Colors.white,
                  iconSize: 18,
                ),

                // Style
                style: SenzuPlayerStyle(
                  senzuLanguage: const SenzuLanguage(
                    cast: 'Cast',
                    quality: 'Quality',
                    subtitles: 'Subtitles',
                    audio: 'Audio',
                    // etc
                  ),
                  progressBarStyle: const SenzuProgressBarStyle(
                    color: Color(0xFFFF4444),
                    bufferedColor: Color(0x4DFFFFFF),
                    backgroundColor: Color(0x26FFFFFF),
                    height: 4,
                    dotSize: 6,
                    dotColor: Colors.white,
                  ),
                  episodeWidget: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EP 1 – Pilot',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}
