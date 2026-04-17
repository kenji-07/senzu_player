import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'example_player_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SenzuPlayer – v2.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF4444),
          secondary: Color(0xFFFF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SenzuPlayer'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white10),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          const _Header(),
          const SizedBox(height: 24),

          // ── Playback ────────────────────────────────────────────────────────
          const _GroupLabel('Playback'),
          _Card(
            icon: Icons.play_circle_outline,
            color: const Color(0xFFE53935),
            title: 'VOD Player',
            subtitle:
                'HLS · Chapters · Skip OP/ED · Ads · Subtitle · ABR · Watermark · Annotations',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'VOD Player',
                  mode: PlayerMode.vod,
                )),
          ),
          _Card(
            icon: Icons.sensors,
            color: const Color(0xFFE91E63),
            title: 'Live Stream',
            subtitle: 'Энгийн live · Auto-reconnect (5×) · isLive: true',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Live Stream',
                  mode: PlayerMode.live,
                )),
          ),
          _Card(
            icon: Icons.history,
            color: const Color(0xFF8E24AA),
            title: 'DVR Live',
            subtitle: 'Live + seek bar · Live edge badge · DVR window',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'DVR Live',
                  mode: PlayerMode.dvr,
                )),
          ),
          _Card(
            icon: Icons.cut,
            color: const Color(0xFF5E35B1),
            title: 'Range / Clip',
            subtitle: 'Tween<Duration> · begin/end clip · looping дотор',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Range Clip',
                  mode: PlayerMode.range,
                )),
          ),

          const SizedBox(height: 8),
          // ── Features ────────────────────────────────────────────────────────
          const _GroupLabel('Features'),
          _Card(
            icon: Icons.image_search,
            color: const Color(0xFF1E88E5),
            title: 'Seek Thumbnail',
            subtitle:
                'Sprite sheet preview · Progress bar drag · Chapter markers',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Seek Thumbnail',
                  mode: PlayerMode.seekThumbnail,
                )),
          ),
          _Card(
            icon: Icons.picture_in_picture_alt,
            color: const Color(0xFF00ACC1),
            title: 'Picture-in-Picture',
            subtitle: 'iOS 14+ / Android 8+ · App background-д үргэлжлэнэ',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'PiP Player',
                  mode: PlayerMode.pip,
                )),
          ),
          _Card(
            icon: Icons.queue_music,
            color: const Color(0xFF00897B),
            title: 'Multi Audio Track',
            subtitle: 'HLS audio tracks · Хэл солих',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Multi Audio',
                  mode: PlayerMode.multiAudio,
                )),
          ),
          _Card(
            icon: Icons.code,
            color: const Color(0xFF43A047),
            title: 'Programmatic Control',
            subtitle:
                'External bundle · Play/Pause/Seek · Volume · Brightness · Speed',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Programmatic',
                  mode: PlayerMode.programmatic,
                )),
          ),

          const SizedBox(height: 8),
          // ── Overlays ────────────────────────────────────────────────────────
          const _GroupLabel('Overlays & Protection'),
          _Card(
            icon: Icons.water_drop_outlined,
            color: const Color(0xFFF57F17),
            title: 'Watermark',
            subtitle: 'UserID · Timestamp · Random position · Fade animation',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Watermark',
                  mode: PlayerMode.watermark,
                )),
          ),
          _Card(
            icon: Icons.comment_outlined,
            color: const Color(0xFFEF6C00),
            title: 'Annotations',
            subtitle: 'Time-based popup cards · onTap callback · 3 demo cards',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Annotations',
                  mode: PlayerMode.annotation,
                )),
          ),
          _Card(
            icon: Icons.lock_outline,
            color: const Color(0xFF6D4C41),
            title: 'DRM – FairPlay / Widevine',
            subtitle:
                'FairPlay (iOS HLS) · Widevine (Android DASH) · Secure mode',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'DRM Player',
                  mode: PlayerMode.drm,
                )),
          ),

          const SizedBox(height: 8),
          // ── UX ──────────────────────────────────────────────────────────────
          const _GroupLabel('UX Utilities'),
          _Card(
            icon: Icons.bedtime_outlined,
            color: const Color(0xFF37474F),
            title: 'Sleep Timer',
            subtitle: 'Countdown timer · Volume/brightness fade · Cancel',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Sleep Timer',
                  mode: PlayerMode.sleepTimer,
                )),
          ),

          const SizedBox(height: 8),
          // ── Feed ────────────────────────────────────────────────────────────
          const _GroupLabel('Feed (Social)'),
          _Card(
            icon: Icons.video_library_outlined,
            color: const Color(0xFF212121),
            title: 'Feed Player',
            subtitle: 'TikTok (PageView) · Instagram (ListView) · Auto-play',
            badge: 'TikTok + IG',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Feed',
                  mode: PlayerMode.feed,
                )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFFF4444).withValues(alpha: 0.4)),
              ),
              child: const Icon(
                Icons.play_circle_fill,
                color: Color(0xFFFF4444),
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SenzuPlayer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Flutter native video player · v2.0',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  const Wrap(
                    spacing: 6,
                    children: [
                      _Chip('HLS'),
                      _Chip('DRM'),
                      _Chip('PiP'),
                      _Chip('Feed'),
                      _Chip('ABR'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 9)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Group label
// ─────────────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(color: color, fontSize: 9),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.2), size: 20),
            ],
          ),
        ),
      );
}
