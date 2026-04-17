import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:senzu_player/senzu_player.dart';

// // TikTok хэв маяг
// SenzuFeedList(
//   sources: [
//     {'auto': VideoSource.fromUrl('https://example.com/video1.m3u8')},
//     {'auto': VideoSource.fromUrl('https://example.com/video2.m3u8')},
//   ],
//   footerBuilder: (ctx, i) => Padding(
//     padding: const EdgeInsets.all(16),
//     child: Row(children: [
//       IconButton(icon: Icon(Icons.favorite_border, color: Colors.white), onPressed: () {}),
//       IconButton(icon: Icon(Icons.comment, color: Colors.white), onPressed: () {}),
//       IconButton(icon: Icon(Icons.share, color: Colors.white), onPressed: () {}),
//     ]),
//   ),
// )

// // Instagram хэв маяг
// SenzuScrollFeed(
//   sources: [...],
//   aspectRatio: 16 / 9,
//   headerBuilder: (ctx, i) => ListTile(
//     leading: CircleAvatar(child: Text('U$i')),
//     title: Text('User $i'),
//   ),
// )

enum PlayerMode { vod, live, dvr, multiAudio, seekThumbnail, programmatic }

class ExamplePlayerPage extends StatefulWidget {
  const ExamplePlayerPage({Key? key, required this.title, required this.mode})
      : super(key: key);
  final String title;
  final PlayerMode mode;

  @override
  State<ExamplePlayerPage> createState() => _ExamplePlayerPageState();
}

class _ExamplePlayerPageState extends State<ExamplePlayerPage> {
  // Programmatic mode-д гадааас bundle үүсгэнэ
  SenzuPlayerBundle? _externalBundle;

  @override
  void initState() {
    super.initState();
    if (widget.mode == PlayerMode.programmatic) {
      _externalBundle = SenzuPlayerBundle.create(
        adaptiveBitrate: true,
        onQualityChanged: (q) => debugPrint('Quality → $q'),
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
    // Гадааас үүсгэсэн bundle-г dispose хийнэ
    _externalBundle?.dispose();
    super.dispose();
  }

  // Widget _buildM3U8Player() {
  //   return FutureBuilder<Map<String, VideoSource>>(
  //     future: VideoSource.fromM3u8PlaylistUrl(
  //       'https://cdn2.playmax.mn//volume1/2026/movies/asian/ultimate_mission/480p.m3u8',
  //       httpHeaders: customHeaders,
  //       autoSubtitle: true,
  //       formatter: (quality) =>
  //           quality == 'Auto' ? 'Automatic' : '${quality.split('x').last}p',
  //     ),
  //     builder: (context, snapshot) {
  //       if (snapshot.hasData) {
  //         return SenzuPlayer(
  //           source: snapshot.data!,
  //           autoPlay: true,
  //           seekTo: Duration.zero,
  //           isLive: false,

  //           // imaAdTagUrl:
  //           //     'https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/vmap_ad_samples&sz=640x480&cust_params=sample_ar%3Dpremidpost&ciu_szs=300x250&gdfp_req=1&ad_rule=1&output=vmap&unviewed_position_start=1&env=vp&impl=s&cmsid=496&vid=short_onecue&correlator=',

  //           // ── Playback ──────────────────────────────────────────────────
  //           looping: false,
  //           secureMode: false,

  //           // ── Lock screen / Now Playing ─────────────────────────────────
  //           enableLockScreen: true,

  //           // ── ABR ───────────────────────────────────────────────────────
  //           adaptiveBitrate: true,
  //           minBufferThreshold: 8,
  //           maxBufferThreshold: 25,
  //           onQualityChanged: (q) {
  //             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //                 content: Text('Quality: $q'),
  //                 duration: const Duration(seconds: 1)));
  //           },

  //           // ── UI toggles ────────────────────────────────────────────────
  //           enableFullscreen: true,
  //           enableCaption: true,
  //           enableQuality: true,
  //           enableSpeed: true,
  //           enableLock: true,
  //           enableAspect: true,
  //           enableEpisode: true,
  //           enableAudio: true,
  //           enablePip: true,

  //           // ── Skip OP/ED ────────────────────────────────────────────────
  //           chapters: const [
  //             SenzuChapter(
  //               startMs: 5000,
  //               title: 'Opening',
  //               showOnProgressBar: true, // progress bar дээр marker зурна
  //               isSkippable: true, // overlay дээр "Skip Opening" товч харуулна
  //               skipToMs: 90000, // skip хийх target цаг
  //             ),
  //             SenzuChapter(
  //               startMs: 90000,
  //               title: 'Episode',
  //               showOnProgressBar: false, // separator, marker зурахгүй
  //             ),
  //             SenzuChapter(
  //               startMs: 1200000,
  //               title: 'Ending',
  //               isSkippable: true,
  //               skipToMs: 1320000,
  //             ),
  //           ],

  //           // ── Гадаас bundle дамжуулах (programmatic mode) ───────────────
  //           bundle: _externalBundle,

  //           // ── Header ────────────────────────────────────────────────────
  //           meta: _externalBundle != null
  //               ? SenzuMetaData(
  //                   title: widget.title,
  //                   description: 'Episode 1',
  //                   icon: Icons.arrow_back,
  //                   iconColor: Colors.red,
  //                   iconSize: 20)
  //               : SenzuMetaData(
  //                   title: widget.title,
  //                   description: 'Episode 1',
  //                   icon: Icons.arrow_back,
  //                   iconColor: Colors.red,
  //                   iconSize: 20),

  //           // ── Data policy ───────────────────────────────────────────────
  //           dataPolicy: const SenzuDataPolicy(
  //             warnOnCellular: true,
  //             dataSaverOnCellular: false,
  //             dataSaverQualityKey: '480p',
  //           ),

  //           // ── Watermark ─────────────────────────────────────────────────
  //           watermark: const SenzuWatermark(
  //             userId: 'user_12345',
  //             opacity: 0.15,
  //             position: WatermarkPosition.random,
  //             moveDuration: Duration(seconds: 20),
  //             showTimestamp: true,
  //           ),

  //           // ── Token refresh ─────────────────────────────────────────────
  //           tokenConfig: SenzuTokenConfig(
  //             refreshBeforeExpirySec: 120,
  //             onRefresh: (sourceName, headers) async {
  //               return {
  //                 'url': 'https://your-cdn.com/refreshed-url.m3u8',
  //                 'Authorization': 'Bearer refreshed_token',
  //               };
  //             },
  //           ),
  //           defaultAspectRatio: 16 / 9,
  //           // ── Annotations ─────────────────────────────────────────────
  //           annotations: [
  //             SenzuAnnotation(
  //               id: 'subscribe',
  //               text: '👍 Subscribe хийгээрэй!',
  //               appearAt: const Duration(seconds: 10),
  //               disappearAt: const Duration(seconds: 15),
  //               alignment: Alignment.topRight,
  //               onTap: () => debugPrint('Тapped!'),
  //             ),
  //             SenzuAnnotation(
  //               id: 'link',
  //               text: '🔗 Дэлгэрэнгүй мэдээлэл',
  //               appearAt: const Duration(seconds: 30),
  //               disappearAt: const Duration(seconds: 40),
  //               alignment: Alignment.bottomLeft,
  //               onTap: () => debugPrint('Тapped!'),
  //             ),
  //           ],

  //           // ── Style ─────────────────────────────────────────────────────
  //           style: SenzuPlayerStyle(
  //               onPrevEpisode: () {},
  //               onNextEpisode: () {},
  //               progressBarStyle: const SenzuProgressBarStyle(
  //                 color: Color(0xFFFF4444),
  //                 bufferedColor: Color(0x4DFFFFFF),
  //                 backgroundColor: Color(0x33FFFFFF),
  //                 height: 4,
  //                 dotSize: 6,
  //                 dotColor: Colors.white,
  //               ),
  //               episodeWidget: Container(
  //                 padding:
  //                     const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                 decoration: BoxDecoration(
  //                   color: Colors.white12,
  //                   borderRadius: BorderRadius.circular(4),
  //                 ),
  //                 child: const Text(
  //                   'episode.title',
  //                   style: TextStyle(color: Colors.white, fontSize: 11),
  //                 ),
  //               )),
  //         );
  //       }
  //       return const Center(child: CircularProgressIndicator());
  //     },
  //   );
  // }

  final Map<String, String> customHeaders = {
    'Referer': 'https://playmax.mn/',
    'Origin': 'https://playmax.mn',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
  };

  // ── Sources ─────────────────────────────────────────────────────────────────

  Map<String, VideoSource> get _sources {
    switch (widget.mode) {
      case PlayerMode.live:
        return VideoSource.fromNetworkVideoSources({
          'Live': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        });

      case PlayerMode.dvr:
        return VideoSource.fromNetworkVideoSources({
          'DVR':
              'https://demo.unified-streaming.com/k8s/live/scte35.isml/.m3u8',
        });

      case PlayerMode.multiAudio:
        return VideoSource.fromNetworkVideoSources(
          {
            '1080p':
                'https://cdn2.playmax.mn//volume1/2026/movies/asian/ultimate_mission/480p.m3u8',
          },
          httpHeaders: customHeaders,
          // thumbnailSprite: const SenzuThumbnailSprite(
          //   url:
          //       'https://image.tmdb.org/t/p/original/aWM8eYmhqBgH4YC5WLLPTJxlc2t.jpg',
          //   columns: 500,
          //   rows: 500,
          //   thumbWidth: 120,
          //   thumbHeight: 68,
          //   intervalSec: 10,
          // ),
        );

      case PlayerMode.seekThumbnail:
        return VideoSource.fromNetworkVideoSources(
          {
            '1080p': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
          },
          thumbnailSprite: const SenzuThumbnailSprite(
            url:
                'https://image.tmdb.org/t/p/original/aWM8eYmhqBgH4YC5WLLPTJxlc2t.jpg',
            columns: 5,
            rows: 5,
            thumbWidth: 120,
            thumbHeight: 68,
            intervalSec: 10,
          ),
        );

      case PlayerMode.vod:
      case PlayerMode.programmatic:
      default:
        return VideoSource.fromNetworkVideoSources(
          {
            '1080p': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
            '720p': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
            '480p': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
          },
          thumbnailSprite: const SenzuThumbnailSprite(
            url:
                'https://image.tmdb.org/t/p/original/aWM8eYmhqBgH4YC5WLLPTJxlc2t.jpg',
            columns: 5,
            rows: 5,
            thumbWidth: 120,
            thumbHeight: 68,
            intervalSec: 10,
          ),
          ads: [
            SenzuPlayerAd(
              deepLink: 'https://playmax.mn/movie/12345?utm_source=player_ad',
              durationToSkip: const Duration(seconds: 5),
              durationToEnd: const Duration(seconds: 25),
              durationToStart: const Duration(seconds: 10),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'Ad: 5 seconds',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            SenzuPlayerAd(
              deepLink: 'https://playmax.mn/movie/12345?utm_source=player_ad',
              durationToSkip: const Duration(seconds: 10),
              durationToEnd: const Duration(seconds: 70),
              durationToStart: const Duration(seconds: 60),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'Ad: 10 seconds',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        );
    }
  }

  bool? get _isLive {
    if (widget.mode == PlayerMode.live) return true;
    if (widget.mode == PlayerMode.dvr) return true;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Player ────────────────────────────────────────────────────────
            SenzuPlayer(
              source: _sources,
              autoPlay: true,
              seekTo: Duration.zero,
              isLive: false,

              // imaAdTagUrl:
              //     'https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/vmap_ad_samples&sz=640x480&cust_params=sample_ar%3Dpremidpost&ciu_szs=300x250&gdfp_req=1&ad_rule=1&output=vmap&unviewed_position_start=1&env=vp&impl=s&cmsid=496&vid=short_onecue&correlator=',

              // ── Playback ──────────────────────────────────────────────────
              looping: false,
              secureMode: false,

              // ── Lock screen / Now Playing ─────────────────────────────────
              enableLockScreen: true,

              // ── ABR ───────────────────────────────────────────────────────
              adaptiveBitrate: true,
              minBufferThreshold: 8,
              maxBufferThreshold: 25,
              onQualityChanged: (q) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Quality: $q'),
                    duration: const Duration(seconds: 1)));
              },

              // ── UI toggles ────────────────────────────────────────────────
              enableFullscreen: true,
              enableCaption: true,
              enableQuality: true,
              enableSpeed: true,
              enableLock: true,
              enableAspect: true,
              enableEpisode: true,
              enableAudio: true,
              enablePip: true,

              // ── Skip OP/ED ────────────────────────────────────────────────
              chapters: const [
                SenzuChapter(
                  startMs: 5000,
                  title: 'Opening',
                  showOnProgressBar: true, // progress bar дээр marker зурна
                  isSkippable:
                      true, // overlay дээр "Skip Opening" товч харуулна
                  skipToMs: 90000, // skip хийх target цаг
                ),
                SenzuChapter(
                  startMs: 90000,
                  title: 'Episode',
                  showOnProgressBar: true, // progress bar дээр marker зурна
                  isSkippable:
                      true, // overlay дээр "Skip Opening" товч харуулна
                ),
                SenzuChapter(
                  startMs: 1200000,
                  title: 'Ending',
                  showOnProgressBar: true, // progress bar дээр marker зурна
                  isSkippable:
                      true, // overlay дээр "Skip Opening" товч харуулна
                  skipToMs: 1320000,
                ),
              ],

              // ── Гадаас bundle дамжуулах (programmatic mode) ───────────────
              bundle: _externalBundle,

              // ── Header ────────────────────────────────────────────────────
              meta: _externalBundle != null
                  ? SenzuMetaData(
                      title: widget.title,
                      description: 'Episode 1',
                      icon: Icons.arrow_back,
                      iconColor: Colors.red,
                      iconSize: 20)
                  : SenzuMetaData(
                      title: widget.title,
                      description: 'Episode 1',
                      icon: Icons.arrow_back,
                      iconColor: Colors.red,
                      iconSize: 20),

              // ── Data policy ───────────────────────────────────────────────
              dataPolicy: const SenzuDataPolicy(
                warnOnCellular: true,
                dataSaverOnCellular: false,
                dataSaverQualityKey: '480p',
              ),

              // ── Watermark ─────────────────────────────────────────────────
              watermark: const SenzuWatermark(
                userId: 'user_12345',
                opacity: 0.15,
                position: WatermarkPosition.random,
                moveDuration: Duration(seconds: 20),
                showTimestamp: true,
              ),

              // ── Token refresh ─────────────────────────────────────────────
              tokenConfig: SenzuTokenConfig(
                refreshBeforeExpirySec: 120,
                onRefresh: (sourceName, headers) async {
                  return {
                    'url': 'https://your-cdn.com/refreshed-url.m3u8',
                    'Authorization': 'Bearer refreshed_token',
                  };
                },
              ),
              defaultAspectRatio: 16 / 9,
              // ── Annotations ─────────────────────────────────────────────
              annotations: [
                SenzuAnnotation(
                  id: 'subscribe',
                  text: '👍 Subscribe хийгээрэй!',
                  appearAt: const Duration(seconds: 10),
                  disappearAt: const Duration(seconds: 15),
                  alignment: Alignment.topRight,
                  onTap: () => debugPrint('Тapped!'),
                ),
                SenzuAnnotation(
                  id: 'link',
                  text: '🔗 Дэлгэрэнгүй мэдээлэл',
                  appearAt: const Duration(seconds: 30),
                  disappearAt: const Duration(seconds: 40),
                  alignment: Alignment.bottomLeft,
                  onTap: () => debugPrint('Тapped!'),
                ),
              ],

              // ── Style ─────────────────────────────────────────────────────
              style: SenzuPlayerStyle(
                  onPrevEpisode: () {},
                  onNextEpisode: () {},
                  progressBarStyle: const SenzuProgressBarStyle(
                    color: Color(0xFFFF4444),
                    bufferedColor: Color(0x4DFFFFFF),
                    backgroundColor: Color(0x33FFFFFF),
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
                      'episode.title',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  )),
            ),
            // ── Mode-specific content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: _buildModeContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeContent() {
    switch (widget.mode) {
      case PlayerMode.programmatic:
        return _externalBundle != null
            ? _ProgrammaticControls(bundle: _externalBundle!)
            : const SizedBox.shrink();

      case PlayerMode.multiAudio:
        return _externalBundle != null
            ? _AudioTrackControls(bundle: _externalBundle!)
            : const SizedBox.shrink();

      case PlayerMode.live:
      case PlayerMode.dvr:
        return const _LiveInfo();

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Programmatic Controls ──────────────────────────────────────────────────────

class _ProgrammaticControls extends StatelessWidget {
  const _ProgrammaticControls({required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Programmatic Control'),
            const SizedBox(height: 8),

            // ── Playback buttons ────────────────────────────────────────────
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
                    bundle.device.isMuted.value ? 'Unmute' : 'Mute',
                    bundle.device.toggleMute,
                  ),
                  _Btn('Skip OP', bundle.ui.skipOp),
                  _Btn('Skip ED', bundle.ui.skipEd),
                ])),
            const SizedBox(height: 12),

            // ── Volume ──────────────────────────────────────────────────────
            Obx(() => _SliderRow(
                  label: 'Vol',
                  value: bundle.device.volume.value,
                  display: '${(bundle.device.volume.value * 100).round()}%',
                  onChanged: bundle.device.setVolume,
                )),

            // ── Brightness ──────────────────────────────────────────────────
            Obx(() => _SliderRow(
                  label: 'Bri',
                  value: bundle.device.brightness.value,
                  display: '${(bundle.device.brightness.value * 100).round()}%',
                  onChanged: bundle.device.setBrightness,
                )),

            const SizedBox(height: 8),

            // ── Info ────────────────────────────────────────────────────────
            Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Info('Position', _fmt(bundle.playback.position.value)),
                    _Info('Duration', _fmt(bundle.playback.duration.value)),
                    _Info('Quality', bundle.core.rxActiveSource.value ?? '—'),
                    _Info(
                      'Buffer',
                      '${(bundle.playback.bufferHealthRatio.value * 100).round()}%',
                    ),
                    _Info('Network', bundle.core.networkType.value),
                    _Info(
                      'Battery',
                      '${bundle.device.batteryLevel.value}% (${bundle.device.batteryState.value})',
                    ),
                    // _Info('Skip OP', bundle.ui.showSkipOp.value.toString()),
                    // _Info('Skip ED', bundle.ui.showSkipEd.value.toString()),
                    _Info('HDR', bundle.core.isHdrEnabled.value.toString()),
                    _Info('Locked', bundle.ui.isLocked.value.toString()),
                  ],
                )),
          ],
        ),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

// ── Audio Track Controls ───────────────────────────────────────────────────────

class _AudioTrackControls extends StatelessWidget {
  const _AudioTrackControls({required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Audio Tracks'),
            const SizedBox(height: 8),
            Obx(() {
              if (bundle.core.audioTracks.isEmpty) {
                return const Text(
                  'Audio track олдсонгүй.\n'
                  'HLS stream нь олон audio track агуулаагүй байна.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                );
              }
              return Column(
                children: bundle.core.audioTracks.map((track) {
                  final isActive =
                      bundle.core.activeAudioTrack.value == track.id;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color:
                          isActive ? const Color(0xFFFF4444) : Colors.white54,
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
                      track.language,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    onTap: () => bundle.core.setAudioTrack(track),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      );
}

// ── Live Info ──────────────────────────────────────────────────────────────────

class _LiveInfo extends StatelessWidget {
  const _LiveInfo();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Live Stream Info'),
            SizedBox(height: 8),
            Text(
              '• DVR горимд progress bar харагдана\n'
              '• "LIVE" badge-г дарж live edge рүү буцаж болно\n'
              '• Stream тасарвал автоматаар reconnect хийнэ (5 удаа)\n'
              '• LL-HLS: 1–3 секундын delay',
              style:
                  TextStyle(color: Colors.white60, fontSize: 12, height: 1.6),
            ),
          ],
        ),
      );
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.display,
    required this.onChanged,
  });
  final String label;
  final double value;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 28,
            child: Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 11))),
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
            width: 36,
            child: Text(display,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
                textAlign: TextAlign.right)),
      ]);
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white12,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(label),
      );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          SizedBox(
              width: 80,
              child: Text('$label:',
                  style: const TextStyle(color: Colors.white54, fontSize: 11))),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      );
}
