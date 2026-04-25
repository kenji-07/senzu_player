import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:senzu_player/senzu_player.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({Key? key}) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  SenzuPlayerBundle? _externalBundle;
  late final SenzuCastController _castController;
  int currentIndex = 1;
  int total = 10;
  String lastTap = '';
  int _refreshCount = 0;
  final _logs = <String>[];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _externalBundle = SenzuPlayerBundle.create(
      // ABR
      adaptiveBitrate: true,
      minBufferSec: 0,
      maxBufferSec: 30,

      looping: true,
      secureMode: true,
      notification: true,
      onQualityChanged: (q) => _showSnack('Quality: $q'),

      // Data policy
      dataPolicy: const SenzuDataPolicy(
        warnOnCellular: true,
        dataSaverOnCellular: false,
        dataSaverQualityKey: '480p',
      ),

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

      // Token refresh
      tokenConfig: SenzuTokenConfig(
        refreshBeforeExpirySec: 60,
        onRefresh: _onRefresh,
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
          onTap: () => setState(() => lastTap = 'Chapter 2 annotation tapped'),
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
    );
    _castController =
        SenzuCastController(appId: SenzuCastController.kDefaultApplicationId);
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

  void _addLog(String msg) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() => _logs.insert(0, '[$ts] $msg'));
    if (_logs.length > 20) _logs.removeLast();
  }

  Future<Map<String, String>> _onRefresh(
      String sourceName, Map<String, String> currentHeaders) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _refreshCount++;
    final fakeExpiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 30;
    final newUrl =
        'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8?exp=$fakeExpiry&sig=fake_sig_$_refreshCount';
    _addLog('Refreshed! count=$_refreshCount exp=$fakeExpiry');
    return {
      'url': newUrl,
      'Authorization': 'Bearer refreshed_token_$_refreshCount',
    };
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
              source: VideoSource.fromNetworkVideoSources(
                {
                  '1080p': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
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
                },
                ads: [
                  SenzuPlayerAd(
                    deepLink: 'https://example.com/ad1',
                    durationToSkip: const Duration(seconds: 5),
                    durationToEnd: const Duration(seconds: 25),
                    durationToStart: const Duration(seconds: 8),
                    child: Container(
                      color: const Color(0xFF1A237E),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Pre-roll Ad (5s skip)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap "Learn more" for details',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                thumbnailSprite: const SenzuThumbnailSprite(
                  url:
                      'https://image.tmdb.org/t/p/original/aWM8eYmhqBgH4YC5WLLPTJxlc2t.jpg',
                  columns: 5,
                  rows: 5,
                  thumbWidth: 160,
                  thumbHeight: 90,
                  intervalSec: 10,
                ),
              ),

              bundle: _externalBundle!,
              defaultAspectRatio: 16 / 9,

              autoPlay: true,
              seekTo: Duration.zero,
              isLive: false,

              castController: _castController,

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
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Obx(() {
                      final connected = _castController.castState.value ==
                          SenzuCastState.connected;

                      if (!connected) {
                        return _ProgrammaticPanel(bundle: _externalBundle!);
                      }

                      return const SizedBox.shrink();
                    }),
                    _label('Remote State'),
                    Obx(() {
                      final remote = _castController.remoteState.value;
                      final cast = _castController.castState.value;
                      if (cast != SenzuCastState.connected) {
                        return const Text(
                          'Not connected',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow('State', remote.sessionState.name),
                            _infoRow(
                                'Position', '${remote.positionMs ~/ 1000}s'),
                            _infoRow(
                                'Duration', '${remote.durationMs ~/ 1000}s'),
                            _infoRow('Playing', '${remote.isPlaying}'),
                            _infoRow(
                                'Volume', remote.volume.toStringAsFixed(2)),
                            _infoRow('Active tracks',
                                remote.activeTrackIds.toString()),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // ── Manual cast controls ───────────────────────────────────────
                    _label('Manual Cast Controls'),
                    Obx(() {
                      final connected = _castController.castState.value ==
                          SenzuCastState.connected;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _btn('Discover',
                              () => _castController.discoverDevices()),
                          _btn('Show Picker',
                              () => _castController.showDevicePicker()),
                          if (connected) ...[
                            _btn('Play', () => _castController.play()),
                            _btn('Pause', () => _castController.pause()),
                            _btn('Seek +30s', () {
                              final pos =
                                  _castController.remoteState.value.positionMs +
                                      30000;
                              _castController
                                  .seekTo(Duration(milliseconds: pos));
                            }),
                            _btn('Disconnect',
                                () => _castController.disconnect(),
                                color: Colors.red),
                          ],
                        ],
                      );
                    }),

                    const SizedBox(height: 24),

                    // ── Available devices ──────────────────────────────────────────
                    _label('Available Devices'),
                    Obx(() {
                      final devices = _castController.availableDevices;
                      if (devices.isEmpty) {
                        return const Text(
                          'No devices found. Tap "Discover" to search.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        );
                      }
                      return Column(
                        children: devices
                            .map((d) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.cast,
                                      color: Colors.white54, size: 20),
                                  title: Text(d.deviceName,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13)),
                                  subtitle: Text(d.modelName,
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 11)),
                                  onTap: () =>
                                      _castController.connectToDevice(d),
                                ))
                            .toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
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

  Widget _infoRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(k,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            Text(v,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );

  Widget _btn(String label, VoidCallback onTap,
          {Color color = const Color(0xFF00CA13)}) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: onTap,
        child: Text(label),
      );
}

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
