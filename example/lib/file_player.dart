import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:senzu_player/senzu_player.dart';

class FilePage extends StatefulWidget {
  const FilePage({Key? key}) : super(key: key);

  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> {
  SenzuPlayerBundle? _externalBundle;
  int currentIndex = 1;
  int total = 10;
  String lastTap = '';

  @override
  void initState() {
    super.initState();

    _externalBundle = SenzuPlayerBundle.create();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
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
      body: SafeArea(
        child: Column(
          children: [
            // ── Player ──────────────────────────────────────────────────────
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromFile(
                  '/images/testvideo.mp4',
                  initialSubtitle: 'English',
                  subtitle: {
                    'English': SenzuPlayerSubtitle.content(
                      '/images/bumble_bee_captions.srt',
                      '',
                      type: SubtitleType.srt,
                    ),
                  },
                )
              },

              bundle: _externalBundle,
              defaultAspectRatio: 16 / 9,

              autoPlay: true,
              seekTo: Duration.zero,
              isLive: false,
              looping: true,
              secureMode: true,
              enableLockScreen: true,

              // ABR
              adaptiveBitrate: false,
              minBufferThreshold: 0,
              maxBufferThreshold: 10000,
              onQualityChanged: (q) => _showSnack('Quality: $q'),

              // UI features
              enableFullscreen: true,
              enableCaption: true,
              enableQuality: true,
              enableSpeed: true,
              enableLock: true,
              enableAspect: true,
              enableEpisode: true,
              enableAudio: true,
              enablePip: true,

              // Chapters
              chapters: const [
                SenzuChapter(
                    startMs: 0, title: 'Cold Open', showOnProgressBar: true),
                SenzuChapter(
                    startMs: 5000,
                    title: 'OP',
                    showOnProgressBar: true,
                    isSkippable: true,
                    skipToMs: 30000),
                SenzuChapter(
                    startMs: 30000, title: '', showOnProgressBar: false),
                SenzuChapter(
                    startMs: 35000, title: 'Act I', showOnProgressBar: true),
                SenzuChapter(
                    startMs: 70000, title: 'Act II', showOnProgressBar: true),
                SenzuChapter(
                    startMs: 90000,
                    title: 'ED',
                    showOnProgressBar: true,
                    isSkippable: true,
                    skipToMs: 120000),
                SenzuChapter(
                    startMs: 120000, title: '', showOnProgressBar: false),
                SenzuChapter(
                    startMs: 125000,
                    title: 'Post-credits',
                    showOnProgressBar: true),
              ],

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
                onPrevEpisode: () => _showSnack('← Prev episode'),
                onNextEpisode: () => _showSnack('Next episode →'),
                hasPrevEpisode: currentIndex > 0,
                hasNextEpisode: currentIndex < total - 1,
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

              // Watermark
              watermark: const SenzuWatermark(
                userId: 'user_42',
                opacity: 0.14,
                position: WatermarkPosition.random,
                moveDuration: Duration(seconds: 20),
                showTimestamp: true,
                fontSize: 13,
                color: Colors.white,
              ),

              // Annotations
              annotations: [
                SenzuAnnotation(
                  id: 'promo_1',
                  text: '🎁 Special offer — Tap to claim!',
                  appearAt: const Duration(seconds: 5),
                  disappearAt: const Duration(seconds: 15),
                  alignment: Alignment.topRight,
                  onTap: () => setState(() => lastTap = 'Promo tapped at 0:05'),
                ),
                SenzuAnnotation(
                  id: 'chapter_2',
                  text: '📖 Chapter 2 starts',
                  appearAt: const Duration(seconds: 20),
                  disappearAt: const Duration(seconds: 28),
                  alignment: Alignment.topLeft,
                  onTap: () =>
                      setState(() => lastTap = 'Chapter 2 annotation tapped'),
                ),
                SenzuAnnotation(
                  id: 'subscribe',
                  text: '🔔 Subscribe now',
                  appearAt: const Duration(seconds: 40),
                  disappearAt: const Duration(seconds: 55),
                  alignment: Alignment.bottomRight,
                  onTap: () => setState(() => lastTap = 'Subscribe tapped'),
                ),
                SenzuAnnotation(
                  id: 'poll',
                  text: '📊 Vote: Did you like this?',
                  appearAt: const Duration(minutes: 1),
                  disappearAt: const Duration(minutes: 1, seconds: 15),
                  alignment: Alignment.center,
                  onTap: () => setState(() => lastTap = 'Poll tapped'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
