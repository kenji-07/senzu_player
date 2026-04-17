import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:senzu_player/senzu_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlayerMode — жишээ бүрийн горим
// ─────────────────────────────────────────────────────────────────────────────
enum PlayerMode {
  vod, // Энгийн VOD + Chapter + Ad + Subtitle
  live, // Live stream
  dvr, // DVR live (seekable)
  multiAudio, // Олон audio track
  seekThumbnail, // Sprite sheet thumbnail
  programmatic, // Гадаас bundle дамжуулан удирдах
  drm, // FairPlay / Widevine DRM
  pip, // Picture-in-Picture
  feed, // TikTok / Instagram хэв маяг
  watermark, // Watermark overlay
  annotation, // Annotation (popup cards)
  sleepTimer, // Sleep timer demo
  range, // Range-limited playback (clip)
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared test URLs
// ─────────────────────────────────────────────────────────────────────────────
class _Urls {
  static const hlsBipbop =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';
  static const hlsMux = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  static const hlsLive = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  static const hlsDvr =
      'https://demo.unified-streaming.com/k8s/live/scte35.isml/.m3u8';
  static const mp4Big =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/CastVideos/mp4/TearsOfSteel.mp4';
  static const subtitleEn =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/CastVideos/tracks/DesigningForGoogleCast-en.vtt';
  static const sprite =
      'https://image.tmdb.org/t/p/original/aWM8eYmhqBgH4YC5WLLPTJxlc2t.jpg';
}

// ─────────────────────────────────────────────────────────────────────────────
// ExamplePlayerPage
// ─────────────────────────────────────────────────────────────────────────────
class ExamplePlayerPage extends StatefulWidget {
  const ExamplePlayerPage({Key? key, required this.title, required this.mode})
      : super(key: key);
  final String title;
  final PlayerMode mode;

  @override
  State<ExamplePlayerPage> createState() => _ExamplePlayerPageState();
}

class _ExamplePlayerPageState extends State<ExamplePlayerPage> {
  SenzuPlayerBundle? _externalBundle;
  int currentIndex = 1;
  int total = 10;

  @override
  void initState() {
    super.initState();
    // Programmatic / sleep / annotation mode-д гадаас bundle үүсгэнэ
    if (widget.mode == PlayerMode.programmatic ||
        widget.mode == PlayerMode.sleepTimer ||
        widget.mode == PlayerMode.annotation) {
      _externalBundle = SenzuPlayerBundle.create(
        adaptiveBitrate: true,
        onQualityChanged: (q) => debugPrint('[ABR] Quality → $q'),
      );
    }
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

  // ── Sources ─────────────────────────────────────────────────────────────────
  Map<String, VideoSource> get _sources {
    switch (widget.mode) {
      // ── Live ──────────────────────────────────────────────────────────────
      case PlayerMode.live:
        return VideoSource.fromNetworkVideoSources({
          'Live HD': _Urls.hlsLive,
        });

      // ── DVR ───────────────────────────────────────────────────────────────
      case PlayerMode.dvr:
        return VideoSource.fromNetworkVideoSources({
          'DVR Stream': _Urls.hlsDvr,
        });

      // ── Multi Audio ───────────────────────────────────────────────────────
      case PlayerMode.multiAudio:
        return VideoSource.fromNetworkVideoSources({
          'Auto': _Urls.hlsBipbop,
          '720p': _Urls.hlsMux,
        });

      // ── Seek Thumbnail ────────────────────────────────────────────────────
      case PlayerMode.seekThumbnail:
        return VideoSource.fromNetworkVideoSources(
          {'1080p': _Urls.hlsMux, '720p': _Urls.hlsMux},
          thumbnailSprite: const SenzuThumbnailSprite(
            url: _Urls.sprite,
            columns: 5,
            rows: 5,
            thumbWidth: 160,
            thumbHeight: 90,
            intervalSec: 10,
          ),
        );

      // ── DRM (FairPlay iOS / Widevine Android) ─────────────────────────────
      case PlayerMode.drm:
        return {
          'FairPlay HLS (EZDRM)': VideoSource.fromUrl(
            'https://fps.ezdrm.com/demo/hls/BigBuckBunny_320x180.m3u8',
            drm: const SenzuDrmConfig.fairPlay(
              certificateUrl: 'https://fps.ezdrm.com/demo/fairplay.cer',
              licenseUrl: 'https://fps.ezdrm.com/api/licenses/',
            ),
          ),
          // Widevine (Android)
          'Widevine DASH': VideoSource.fromDashUrl(
            'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
            drm: const SenzuDrmConfig.widevine(
                licenseUrl:
                    'https://drm-widevine-licensing.axprod.net/AcquireLicense',
                headers: {
                  "X-AxDRM-Message":
                      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXJzaW9uIjogMSwiY29tX2tleV9pZCI6ICI3YjVkYmIwNC0xYzY3LTRlNjQtYWIyZS1hZTIyMDBkZmY5NzAiLCJtZXNzYWdlIjogeyAgInR5cGUiOiAiZW50aXRsZW1lbnRfbWVzc2FnZSIsICAidmVyc2lvbiI6IDIsICAiY29udGVudF9rZXlzX3NvdXJjZSI6IHsgICAgImlubGluZSI6IFsgICAgICB7ICAgICAgICAiaWQiOiAiOWViNDA1MGQtZTQ0Yi00ODAyLTkzMmUtMjdkNzUwODNlMjY2IiwgICAgICAgICJlbmNyeXB0ZWRfa2V5IjogInZzRTdGakNWZE83T2VpQ21xNFhKUmc9PSIgICAgICB9ICAgIF0gIH19fQ.WOa2ZjpbMASDEyDfER3y0A5K1JzV0bcRo6qig7Zfb7I"
                }),
          ),
        };

      // ── PiP ───────────────────────────────────────────────────────────────
      case PlayerMode.pip:
        return VideoSource.fromNetworkVideoSources({
          '1080p': _Urls.hlsMux,
          '720p': _Urls.hlsMux,
        });

      // ── Watermark ─────────────────────────────────────────────────────────
      case PlayerMode.watermark:
        return VideoSource.fromNetworkVideoSources({
          '720p': _Urls.mp4Big,
        });

      // ── Annotation ────────────────────────────────────────────────────────
      case PlayerMode.annotation:
        return VideoSource.fromNetworkVideoSources({
          'HD': _Urls.hlsMux,
        });

      // ── Sleep Timer ───────────────────────────────────────────────────────
      case PlayerMode.sleepTimer:
        return VideoSource.fromNetworkVideoSources({
          'HD': _Urls.hlsMux,
          'SD': _Urls.hlsMux,
        });

      // ── Range (clip) ──────────────────────────────────────────────────────
      case PlayerMode.range:
        return {
          'Clip 0:30–2:00': VideoSource(
            dataSource: _Urls.mp4Big,
            range: Tween(
              begin: const Duration(seconds: 30),
              end: const Duration(minutes: 2),
            ),
          ),
        };

      // ── VOD (default) — chapters + ads + subtitle ─────────────────────────
      case PlayerMode.vod:
      case PlayerMode.programmatic:
      default:
        return VideoSource.fromNetworkVideoSources(
          {
            '1080p': _Urls.hlsMux,
            '720p': _Urls.hlsMux,
            '480p': _Urls.hlsMux,
          },
          subtitle: {
            'English': SenzuPlayerSubtitle.network(
              _Urls.subtitleEn,
              type: SubtitleType.webvtt,
            ),
          },
          initialSubtitle: 'English',
          thumbnailSprite: const SenzuThumbnailSprite(
            url: _Urls.sprite,
            columns: 5,
            rows: 5,
            thumbWidth: 160,
            thumbHeight: 90,
            intervalSec: 10,
          ),
          ads: [
            SenzuPlayerAd(
              deepLink: 'https://example.com/ad1',
              durationToSkip: const Duration(seconds: 5),
              durationToEnd: const Duration(seconds: 25),
              durationToStart: const Duration(seconds: 8),
              child: const _AdWidget(label: 'Pre-roll Ad (5s skip)'),
            ),
            SenzuPlayerAd(
              deepLink: 'https://example.com/ad2',
              durationToSkip: const Duration(seconds: 10),
              durationToEnd: const Duration(seconds: 70),
              durationToStart: const Duration(seconds: 60),
              child: const _AdWidget(label: 'Mid-roll Ad (10s skip)'),
            ),
          ],
        );
    }
  }

  // ── Chapters (VOD / programmatic / annotation) ──────────────────────────────
  List<SenzuChapter> get _chapters {
    switch (widget.mode) {
      case PlayerMode.vod:
      case PlayerMode.programmatic:
      case PlayerMode.seekThumbnail:
        return const [
          SenzuChapter(
            startMs: 0,
            title: 'Intro',
            showOnProgressBar: false,
          ),
          SenzuChapter(
            startMs: 5000,
            title: 'OP',
            showOnProgressBar: true,
            isSkippable: true,
            skipToMs: 90000,
          ),
          SenzuChapter(
            startMs: 90000,
            title: '',
            showOnProgressBar: false,
          ),
          SenzuChapter(
            startMs: 92000,
            title: 'Episode',
            showOnProgressBar: true,
          ),
          SenzuChapter(
            startMs: 1180000,
            title: 'ED',
            showOnProgressBar: true,
            isSkippable: true,
            skipToMs: 1320000,
          ),
          SenzuChapter(
            startMs: 1320000,
            title: '',
            showOnProgressBar: false,
          ),
        ];
      default:
        return const [];
    }
  }

  // ── Style ──────────────────────────────────────────────────────────────────
  SenzuPlayerStyle get _style => SenzuPlayerStyle(
        onPrevEpisode: widget.mode == PlayerMode.vod
            ? () => _showSnack('← Prev episode')
            : null,
        onNextEpisode: widget.mode == PlayerMode.vod
            ? () => _showSnack('Next episode →')
            : null,
        hasPrevEpisode: currentIndex > 0,
        hasNextEpisode: currentIndex < total - 1,
        progressBarStyle: const SenzuProgressBarStyle(
          color: Color(0xFFFF4444),
          bufferedColor: Color(0x4DFFFFFF),
          backgroundColor: Color(0x26FFFFFF),
          height: 4,
          dotSize: 6,
          dotColor: Colors.white,
        ),
        episodeWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'EP 1 – Pilot',
            style: TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
        // Custom skip ad builder
        // skipAdBuilder: (watched) => Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        //   decoration: BoxDecoration(
        //     color: Colors.black87,
        //     borderRadius: BorderRadius.circular(6),
        //     border: Border.all(color: Colors.white24),
        //   ),
        //   child: Row(
        //     mainAxisSize: MainAxisSize.min,
        //     children: [
        //       const Icon(Icons.skip_next, color: Colors.white, size: 16),
        //       const SizedBox(width: 6),
        //       Text(
        //         'Skip Ad · ${watched.inSeconds}s',
        //         style: const TextStyle(color: Colors.white, fontSize: 12),
        //       ),
        //     ],
        //   ),
        // ),
      );

  // ── Meta ───────────────────────────────────────────────────────────────────
  SenzuMetaData get _meta => SenzuMetaData(
        title: widget.title,
        description: _modeSubtitle,
        icon: Icons.arrow_back_ios_new,
        iconColor: Colors.white,
        iconSize: 18,
      );

  String get _modeSubtitle {
    switch (widget.mode) {
      case PlayerMode.live:
        return 'Live Stream';
      case PlayerMode.dvr:
        return 'DVR – Seekable Live';
      case PlayerMode.drm:
        return 'FairPlay / Widevine';
      case PlayerMode.pip:
        return 'Picture-in-Picture';
      case PlayerMode.watermark:
        return 'Watermark Overlay';
      case PlayerMode.annotation:
        return 'Annotation Cards';
      case PlayerMode.sleepTimer:
        return 'Sleep Timer';
      case PlayerMode.range:
        return 'Clipped Playback';
      default:
        return 'Episode 1 – Pilot';
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Feed mode-г тусдаа render хийнэ
    if (widget.mode == PlayerMode.feed) {
      return const _FeedDemoPage();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Player ──────────────────────────────────────────────────────
            SenzuPlayer(
              source: _sources,
              autoPlay: true,
              seekTo: Duration.zero,
              isLive: _isLive,
              looping: widget.mode == PlayerMode.range,
              secureMode: false,
              enableLockScreen: true,

              // ABR
              adaptiveBitrate: true,
              minBufferThreshold: 0,
              maxBufferThreshold: 2500,
              onQualityChanged: (q) => _showSnack('Quality: $q'),

              // UI features
              enableFullscreen: true,
              enableCaption: widget.mode != PlayerMode.live,
              enableQuality: true,
              enableSpeed: widget.mode != PlayerMode.live,
              enableLock: true,
              enableAspect: true,
              enableEpisode: widget.mode == PlayerMode.vod,
              enableAudio: widget.mode == PlayerMode.multiAudio,
              enablePip: widget.mode == PlayerMode.pip,

              // Chapters
              chapters: _chapters,

              // External bundle (programmatic / sleep / annotation)
              bundle: _externalBundle,

              // Header meta
              meta: _meta,

              // Style
              style: _style,

              // Aspect ratio
              defaultAspectRatio: 16 / 9,

              // Data policy
              dataPolicy: const SenzuDataPolicy(
                warnOnCellular: true,
                dataSaverOnCellular: false,
                dataSaverQualityKey: '480p',
              ),

              // Watermark
              watermark: widget.mode == PlayerMode.watermark ||
                      widget.mode == PlayerMode.vod
                  ? const SenzuWatermark(
                      userId: 'user_42',
                      opacity: 0.14,
                      position: WatermarkPosition.random,
                      moveDuration: Duration(seconds: 20),
                      showTimestamp: true,
                    )
                  : null,

              // Token refresh
              tokenConfig: SenzuTokenConfig(
                refreshBeforeExpirySec: 120,
                onRefresh: (sourceName, headers) async {
                  return {
                    'url': _Urls.hlsMux,
                    'Authorization': 'Bearer refreshed_token',
                  };
                },
              ),

              // Annotations
              annotations: widget.mode == PlayerMode.annotation ||
                      widget.mode == PlayerMode.vod
                  ? [
                      SenzuAnnotation(
                        id: 'subscribe',
                        text: '👍 Subscribe хийгээрэй!',
                        appearAt: const Duration(seconds: 10),
                        disappearAt: const Duration(seconds: 16),
                        alignment: Alignment.topRight,
                        onTap: () => _showSnack('Subscribe tapped'),
                      ),
                      SenzuAnnotation(
                        id: 'promo',
                        text: '🎁 Онцгой урамшуулал →',
                        appearAt: const Duration(seconds: 30),
                        disappearAt: const Duration(seconds: 38),
                        alignment: Alignment.bottomLeft,
                        onTap: () => _showSnack('Promo tapped'),
                      ),
                      const SenzuAnnotation(
                        id: 'chapter_hint',
                        text: '📖 Chapter 1 эхэллээ',
                        appearAt: Duration(seconds: 92),
                        disappearAt: Duration(seconds: 97),
                        alignment: Alignment.topLeft,
                      ),
                    ]
                  : const [],
            ),

            // ── Mode-specific bottom panel ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildModeContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool? get _isLive {
    if (widget.mode == PlayerMode.live) return true;
    if (widget.mode == PlayerMode.dvr) return true;
    return null;
  }

  Widget _buildModeContent() {
    switch (widget.mode) {
      case PlayerMode.programmatic:
        return _externalBundle != null
            ? _ProgrammaticPanel(bundle: _externalBundle!)
            : const SizedBox.shrink();

      case PlayerMode.sleepTimer:
        return _externalBundle != null
            ? _SleepTimerPanel(bundle: _externalBundle!)
            : const SizedBox.shrink();

      case PlayerMode.multiAudio:
        return _externalBundle != null
            ? _AudioTrackPanel(bundle: _externalBundle!)
            : const SizedBox.shrink();

      case PlayerMode.drm:
        return const _DrmInfoPanel();

      case PlayerMode.live:
      case PlayerMode.dvr:
        return const _LiveInfoPanel();

      case PlayerMode.range:
        return const _RangeInfoPanel();

      case PlayerMode.pip:
        return const _PipInfoPanel();

      case PlayerMode.watermark:
        return const _WatermarkInfoPanel();

      case PlayerMode.annotation:
        return _externalBundle != null
            ? _AnnotationPanel(bundle: _externalBundle!)
            : const _AnnotationInfoPanel();

      case PlayerMode.seekThumbnail:
        return const _ThumbnailInfoPanel();

      case PlayerMode.vod:
      default:
        return const _VodInfoPanel();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feed Demo Page — TikTok + Instagram хэв маяг
// ─────────────────────────────────────────────────────────────────────────────

class _FeedDemoPage extends StatefulWidget {
  const _FeedDemoPage();

  @override
  State<_FeedDemoPage> createState() => _FeedDemoPageState();
}

class _FeedDemoPageState extends State<_FeedDemoPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // TikTok-style vertical feed sources
  static final _tikTokSources = [
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsMux}),
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsBipbop}),
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsMux}),
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsMux}),
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsBipbop}),
  ];

  // Instagram-style scroll feed sources
  static final _igSources = [
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsMux}),
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsBipbop}),
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsMux}),
    VideoSource.fromNetworkVideoSources({'auto': _Urls.hlsMux}),
  ];

  static const _users = [
    '@senzuplayer',
    '@flutter_dev',
    '@mongolia_vibes',
    '@tech_tips',
    '@senzu_demo',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Feed Demo'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '🎵 TikTok'),
            Tab(text: '📷 Instagram'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // TikTok — SenzuFeedList (vertical PageView)
          SenzuFeedList(
            sources: _tikTokSources,
            aspectRatio: 9 / 16,
            looping: true,
            onPageChanged: (i) => debugPrint('Feed page: $i'),
            footerBuilder: (ctx, i) => _TikTokFooter(
              username: _users[i % _users.length],
              likes: (1200 + i * 340).toString(),
            ),
            headerBuilder: (ctx, i) => _TikTokHeader(
              username: _users[i % _users.length],
            ),
          ),

          // Instagram — SenzuScrollFeed (ListView)
          SenzuScrollFeed(
            sources: _igSources,
            aspectRatio: 4 / 5,
            looping: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            headerBuilder: (ctx, i) => _IgHeader(
              username: _users[i % _users.length],
            ),
            footerBuilder: (ctx, i) => _IgFooter(
              likes: (980 + i * 120).toString(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TikTokHeader extends StatelessWidget {
  const _TikTokHeader({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(
                username[1].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              username,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      );
}

class _TikTokFooter extends StatelessWidget {
  const _TikTokFooter({required this.username, required this.likes});
  final String username, likes;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  const Text('SenzuPlayer demo video #flutter',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Column(
              children: [
                _FeedAction(icon: Icons.favorite_border, label: likes),
                const SizedBox(height: 12),
                const _FeedAction(icon: Icons.comment_outlined, label: '42'),
                const SizedBox(height: 12),
                const _FeedAction(icon: Icons.share_outlined, label: 'Share'),
              ],
            ),
          ],
        ),
      );
}

class _FeedAction extends StatelessWidget {
  const _FeedAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      );
}

class _IgHeader extends StatelessWidget {
  const _IgHeader({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.pink.shade300,
          child: Text(
            username[1].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        title: Text(username,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        trailing: const Icon(Icons.more_horiz, color: Colors.white70),
      );
}

class _IgFooter extends StatelessWidget {
  const _IgFooter({required this.likes});
  final String likes;

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.favorite_border, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Icon(Icons.comment_outlined, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Icon(Icons.send_outlined, color: Colors.white, size: 22),
            Spacer(),
            Icon(Icons.bookmark_border, color: Colors.white, size: 22),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Programmatic Panel
// ─────────────────────────────────────────────────────────────────────────────

class _ProgrammaticPanel extends StatelessWidget {
  const _ProgrammaticPanel({required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('🎮 Programmatic Control'),
          const SizedBox(height: 10),
          Obx(() => Wrap(spacing: 8, runSpacing: 8, children: [
                _Btn(
                  bundle.playback.isPlaying.value ? 'Pause' : 'Play',
                  bundle.playback.isPlaying.value
                      ? bundle.core.pause
                      : bundle.core.play,
                ),
                _Btn('−10s', () => bundle.core.seekBySeconds(-10)),
                _Btn('+10s', () => bundle.core.seekBySeconds(10)),
                _Btn(
                  bundle.device.isMuted.value ? 'Unmute 🔇' : 'Mute 🔊',
                  bundle.device.toggleMute,
                ),
                _Btn('Skip OP', bundle.ui.skipOp),
                _Btn('Skip ED', bundle.ui.skipEd),
                _Btn('0.5×', () => bundle.core.setPlaybackSpeed(0.5)),
                _Btn('1.0×', () => bundle.core.setPlaybackSpeed(1.0)),
                _Btn('1.5×', () => bundle.core.setPlaybackSpeed(1.5)),
                _Btn('2.0×', () => bundle.core.setPlaybackSpeed(2.0)),
              ])),
          const SizedBox(height: 16),
          const _SectionTitle('Volume'),
          Obx(() => _Slider(
                value: bundle.device.volume.value,
                label: '${(bundle.device.volume.value * 100).round()}%',
                onChanged: bundle.device.setVolume,
              )),
          const _SectionTitle('Brightness'),
          Obx(() => _Slider(
                value: bundle.device.brightness.value,
                label: '${(bundle.device.brightness.value * 100).round()}%',
                onChanged: bundle.device.setBrightness,
              )),
          const SizedBox(height: 12),
          const _SectionTitle('ℹ️ Info'),
          Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row('Position', _fmt(bundle.playback.position.value)),
                  _Row('Duration', _fmt(bundle.playback.duration.value)),
                  _Row('Quality', bundle.core.rxActiveSource.value ?? '—'),
                  _Row('Buffer',
                      '${(bundle.playback.bufferHealthRatio.value * 100).round()}%'),
                  _Row('Speed', '${bundle.core.playbackSpeed}×'),
                  _Row('Network', bundle.core.networkType.value),
                  _Row('HDR', bundle.core.isHdrEnabled.value.toString()),
                  _Row('Battery',
                      '${bundle.device.batteryLevel.value}% (${bundle.device.batteryState.value})'),
                  _Row('Locked', bundle.ui.isLocked.value.toString()),
                  _Row('Live', bundle.core.isLiveRx.value.toString()),
                ],
              )),
        ],
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sleep Timer Panel
// ─────────────────────────────────────────────────────────────────────────────

class _SleepTimerPanel extends StatelessWidget {
  const _SleepTimerPanel({required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('😴 Sleep Timer'),
          const SizedBox(height: 8),
          const Text(
            'Timer тохируулвал тоглуулалт автоматаар зогсоно.\n'
            'Дуусахад дэлгэц болон дуу нь аажмаар унтарна.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final isActive = bundle.sleepTimer.isActive.value;
            final rem = bundle.sleepTimer.remainingTime.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive && rem != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bedtime,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Remaining: ${rem.inMinutes}:${(rem.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: bundle.sleepTimer.stop,
                          child: const Icon(Icons.close,
                              color: Colors.white54, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final min in [1, 5, 10, 15, 30, 60])
                    _Btn(
                      '$min min',
                      () => bundle.sleepTimer.start(Duration(minutes: min)),
                    ),
                  if (isActive)
                    _Btn('Cancel', bundle.sleepTimer.stop,
                        color: Colors.red.shade900),
                ]),
              ],
            );
          }),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Track Panel
// ─────────────────────────────────────────────────────────────────────────────

class _AudioTrackPanel extends StatelessWidget {
  const _AudioTrackPanel({required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('🎵 Audio Tracks'),
          const SizedBox(height: 8),
          Obx(() {
            if (bundle.core.audioTracks.isEmpty) {
              return const Text(
                'Audio track олдсонгүй.\nHLS stream нь олон audio track агуулаагүй байна.',
                style:
                    TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
              );
            }
            return Column(
              children: bundle.core.audioTracks.map((track) {
                final isActive = bundle.core.activeAudioTrack.value == track.id;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isActive
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isActive ? const Color(0xFFFF4444) : Colors.white38,
                    size: 20,
                  ),
                  title: Text(
                    track.name,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'lang: ${track.language}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  onTap: () => bundle.core.setAudioTrack(track),
                );
              }).toList(),
            );
          }),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Annotation Panel (гадаас bundle байвал)
// ─────────────────────────────────────────────────────────────────────────────

class _AnnotationPanel extends StatelessWidget {
  const _AnnotationPanel({required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('💬 Active Annotations'),
          const SizedBox(height: 8),
          Obx(() {
            final active = bundle.annotation.activeAnnotations;
            if (active.isEmpty) {
              return const Text(
                'Одоогоор идэвхтэй annotation байхгүй.\n'
                '10s, 30s, 92s дээр popup гарна.',
                style:
                    TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
              );
            }
            return Column(
              children: active
                  .map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.label,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(a.text,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ))
                  .toList(),
            );
          }),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Info panels (static)
// ─────────────────────────────────────────────────────────────────────────────

class _DrmInfoPanel extends StatelessWidget {
  const _DrmInfoPanel();
  @override
  Widget build(BuildContext context) => const _InfoBox(
        title: '🔐 DRM – FairPlay / Widevine',
        items: [
          'iOS: FairPlay Streaming (HLS + .m3u8)',
          'Android: Widevine (DASH + .mpd)',
          'licenseUrl – лиценз сервер рүү хүсэлт',
          'certificateUrl – FairPlay cert татах URL',
          'headers – Authorization токен дамжуулах',
          'secureMode: true – screenshot хаах',
          '⚠️ Test URL-уудыг өөрийн DRM URL-ээр солино уу',
        ],
      );
}

class _LiveInfoPanel extends StatelessWidget {
  const _LiveInfoPanel();
  @override
  Widget build(BuildContext context) => const _InfoBox(
        title: '📡 Live / DVR Stream',
        items: [
          'DVR горимд progress bar харагдана',
          '"LIVE" badge дарж live edge рүү буцна',
          'Stream тасарвал автоматаар reconnect (5×)',
          'LL-HLS: 1–3 секундын delay',
          'isLive: true гэж тодорхой зааж өгнө',
          'DVR: hasDvr=true бол seek боломжтой',
        ],
      );
}

class _RangeInfoPanel extends StatelessWidget {
  const _RangeInfoPanel();
  @override
  Widget build(BuildContext context) => const _InfoBox(
        title: '✂️ Range – Clipped Playback',
        items: [
          'VideoSource дотор range: Tween<Duration>',
          'begin: эхлэх цаг, end: дуусах цаг',
          'Progress bar зөвхөн тухайн range харуулна',
          'looping: true бол range дотор давтана',
          'Trailer, clip, highlight үзүүлэхэд тохиромжтой',
        ],
      );
}

class _PipInfoPanel extends StatelessWidget {
  const _PipInfoPanel();
  @override
  Widget build(BuildContext context) => const _InfoBox(
        title: '🖼️ Picture-in-Picture',
        items: [
          'enablePip: true – PiP товч харагдана',
          'iOS 14+ / Android 8+ дэмжинэ',
          'App-аас гарсан ч видео үргэлжилнэ',
          'SenzuNativeChannel.enterPip() – программаар орох',
          'SenzuPipOverlay – root-д нэмбэл тохиромжтой',
        ],
      );
}

class _WatermarkInfoPanel extends StatelessWidget {
  const _WatermarkInfoPanel();
  @override
  Widget build(BuildContext context) => const _InfoBox(
        title: '💧 Watermark Overlay',
        items: [
          'userId – хэрэглэгч таних тэмдэг',
          'customText – дурын текст',
          'opacity – ил тод байдал (0.1–0.3 зөвлөнө)',
          'position: WatermarkPosition.random – хөдөлдөг',
          'moveDuration – хэр олон хэлбэлзэх',
          'showTimestamp – огноо/цаг харуулах',
        ],
      );
}

class _AnnotationInfoPanel extends StatelessWidget {
  const _AnnotationInfoPanel();
  @override
  Widget build(BuildContext context) => const _InfoBox(
        title: '💬 Annotations',
        items: [
          '10s дээр "Subscribe" annotation гарна',
          '30s дээр "Promo" annotation гарна',
          '92s дээр "Chapter hint" annotation гарна',
          'alignment – байрлал тохируулна',
          'onTap – дарах үйлдэл',
          'appearAt / disappearAt – цаг тохируулна',
        ],
      );
}

class _ThumbnailInfoPanel extends StatelessWidget {
  const _ThumbnailInfoPanel();
  @override
  Widget build(BuildContext context) => const _InfoBox(
        title: '🖼️ Seek Thumbnail Sprite',
        items: [
          'Progress bar drag хийхэд preview харагдана',
          'url – sprite sheet зургийн URL',
          'columns × rows – хэдэн thumbnail байгаа',
          'intervalSec – хэр олон секунд тутамд',
          'thumbWidth / thumbHeight – нэг thumbnail хэмжээ',
        ],
      );
}

class _VodInfoPanel extends StatelessWidget {
  const _VodInfoPanel();
  @override
  Widget build(BuildContext context) => const _InfoBox(
        title: '▶️ VOD Features',
        items: [
          'Chapters: OP/ED skip товч харагдана',
          'Progress bar drag → chapter haptic feedback',
          'Pre-roll Ad @ 8s, Mid-roll Ad @ 60s',
          'Subtitle: English VTT track',
          'Seek thumbnail sprite preview',
          'Watermark: user_42 (random position)',
          'Annotations: 3 popup cards',
          'ABR: 1080p / 720p / 480p auto-switch',
          'Token refresh callback тохируулсан',
          'Data saver: cellular-д анхааруулга',
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Ad widget
// ─────────────────────────────────────────────────────────────────────────────

class _AdWidget extends StatelessWidget {
  const _AdWidget({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1A237E),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap "Learn more" for details',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.value,
    required this.label,
    required this.onChanged,
  });
  final double value;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF4444),
            inactiveColor: Colors.white24,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.right),
        ),
      ]);
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.onTap, {this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.white12,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(label),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      );
}
