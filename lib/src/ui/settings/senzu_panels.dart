import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';
import 'package:senzu_player/src/cast/senzu_cast_service.dart';

// ── Generic panel shell ────────────────────────────────────────────────────────
class SenzuSidePanel extends StatelessWidget {
  const SenzuSidePanel({
    super.key,
    required this.bundle,
    required this.style,
    required this.panel,
    required this.child,
    this.width = 200,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPanel panel;
  final Widget child;
  final double width;
  final SenzuPlayerStyle style;

  String get title {
    switch (panel) {
      case SenzuPanel.aspect:
        return style.senzuLanguage.aspectRatio;
      case SenzuPanel.audio:
        return style.senzuLanguage.audio;
      case SenzuPanel.caption:
        return style.senzuLanguage.subtitles;
      case SenzuPanel.episode:
        return style.senzuLanguage.episodes;
      case SenzuPanel.none:
        return '';
      case SenzuPanel.quality:
        return style.senzuLanguage.quality;
      case SenzuPanel.settings:
        return style.senzuLanguage.settings;
      case SenzuPanel.speed:
        return style.senzuLanguage.playbackSpeed;
      case SenzuPanel.sleep:
        return style.senzuLanguage.sleepTimer;
      case SenzuPanel.cast:
        return style.senzuLanguage.cast;
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final visible = bundle.ui.activePanel.value == panel;
    return Align(
      alignment: Alignment.centerRight,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        offset: visible ? Offset.zero : const Offset(1.0, 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: visible ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !visible,
            child: Container(
              width: width,
              margin: const EdgeInsets.only(right: 0),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      top: 10,
                      bottom: 10,
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  });
}

// ── Sleep Timer ───────────────────────────────────────────────────────────────────
class SenzuSleepPanel extends StatelessWidget {
  const SenzuSleepPanel({super.key, required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => SenzuSidePanel(
    bundle: bundle,
    panel: SenzuPanel.sleep,
    style: style,
    child: Obx(() {
      final position = bundle.playback.position.value;
      final duration = bundle.playback.duration.value;
      final remaining = duration - position;
      final remainingMin = remaining.inMinutes;
      final base = [1, 5, 10, 15, 30, 60];

      final isActive = bundle.sleepTimer.isActive.value;
      final activeRemaining = bundle.sleepTimer.remainingTime.value;

      int? activeMinutes;
      if (isActive && activeRemaining != null) {
        activeMinutes = ((activeRemaining.inSeconds + 30) ~/ 60);
      }

      bool isSelected(int minutes) => isActive && activeMinutes == minutes;

      final items = [
        if (remainingMin > 0)
          _PanelItem(
            label:
                '${style.senzuLanguage.untilVideoEnds}($remainingMin ${style.senzuLanguage.minutesShort})',
            selected: isSelected(remainingMin),
            onTap: () =>
                bundle.sleepTimer.start(Duration(minutes: remainingMin)),
          ),
        ...base.map(
          (k) => _PanelItem(
            label: '$k ${style.senzuLanguage.minutes}',
            selected: isSelected(k),
            onTap: () => bundle.sleepTimer.start(Duration(minutes: k)),
          ),
        ),

        _PanelItem(
          label: style.senzuLanguage.cancel,
          selected: !isActive,
          onTap: () => bundle.sleepTimer.stop(),
        ),
      ];

      return _PanelList(items: items);
    }),
  );
}

// ── Quality ───────────────────────────────────────────────────────────────────

class SenzuQualityPanel extends StatelessWidget {
  const SenzuQualityPanel({
    super.key,
    required this.bundle,
    required this.style,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => SenzuSidePanel(
    bundle: bundle,
    style: style,
    panel: SenzuPanel.quality,
    child: Obx(() {
      final sources = bundle.core.rxSources.value ?? {};
      final active = bundle.core.rxActiveSource.value;
      return _PanelList(
        items: sources.keys
            .map(
              (k) => _PanelItem(
                label: k,
                selected: k == active,
                onTap: k == active
                    ? null
                    : () {
                        final src = sources[k];
                        if (src != null) {
                          bundle.core.changeSource(name: k, source: src);
                        }
                      },
              ),
            )
            .toList(),
      );
    }),
  );
}

// ── Speed ─────────────────────────────────────────────────────────────
class SenzuSpeedPanel extends StatelessWidget {
  const SenzuSpeedPanel({super.key, required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => SenzuSidePanel(
    bundle: bundle,
    panel: SenzuPanel.speed,
    style: style,
    child: _SpeedContent(bundle: bundle, style: style),
  );
}

class _SpeedContent extends StatefulWidget {
  const _SpeedContent({required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  State<_SpeedContent> createState() => _SpeedContentState();
}

class _SpeedContentState extends State<_SpeedContent> {
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  final _currentSpeed = 1.0.obs;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _currentSpeed.value = widget.bundle.core.playbackSpeed;
    _sub = widget.bundle.core.rxNativeState.listen((_) {
      _currentSpeed.value = widget.bundle.core.playbackSpeed;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final cur = _currentSpeed.value;
    return _PanelList(
      items: _speeds
          .map(
            (s) => _PanelItem(
              label: s == 1.0
                  ? '1× (${widget.style.senzuLanguage.normal})'
                  : '$s×',
              selected: (cur - s).abs() < 0.01,
              onTap: () async {
                await widget.bundle.core.setPlaybackSpeed(s);
                _currentSpeed.value = s;
              },
            ),
          )
          .toList(),
    );
  });
}

// ── Caption ───────────────────────────────────────────────────────────────────
class SenzuCaptionPanel extends StatelessWidget {
  const SenzuCaptionPanel({
    super.key,
    required this.bundle,
    required this.style,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => SenzuSidePanel(
    bundle: bundle,
    panel: SenzuPanel.caption,
    width: 220,
    style: style,
    child: Obx(() {
      final active = bundle.subtitle.activeCaption.value;
      final srcName = bundle.core.rxActiveSource.value;
      final subs = bundle.core.rxSources.value?[srcName]?.subtitle ?? {};

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelList(
            items: [
              _PanelItem(
                label: style.senzuLanguage.none,
                selected: active == style.senzuLanguage.none,
                onTap: () => bundle.subtitle.changeSubtitle(
                  subtitle: null,
                  name: style.senzuLanguage.none,
                ),
              ),
              ...subs.entries.map(
                (e) => _PanelItem(
                  label: e.key,
                  selected: active == e.key,
                  onTap: () => bundle.subtitle.changeSubtitle(
                    subtitle: e.value,
                    name: e.key,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Obx(
              () => Column(
                children: [
                  Text(
                    '${style.senzuLanguage.subtitleSize}: ${bundle.subtitle.subtitleSize.value}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.red,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.red,
                      overlayShape: SliderComponentShape.noOverlay,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: bundle.subtitle.subtitleSize.value.toDouble(),
                      min: 10,
                      max: 50,
                      divisions: 40,
                      onChanged: (v) =>
                          bundle.subtitle.setSubtitleSize(v.toInt()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }),
  );
}

class SenzuAudioPanel extends StatelessWidget {
  const SenzuAudioPanel({super.key, required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => SenzuSidePanel(
    bundle: bundle,
    style: style,
    panel: SenzuPanel.audio,
    child: Obx(
      () => _PanelList(
        items: bundle.core.audioTracks
            .map(
              (t) => _PanelItem(
                label: '${t.name} (${t.language})',
                selected: bundle.core.activeAudioTrack.value == t.id,
                onTap: () => bundle.core.setAudioTrack(t),
              ),
            )
            .toList(),
      ),
    ),
  );
}

// ── Aspect ────────────────────────────────────────────────────────────────────
class SenzuAspectPanel extends StatelessWidget {
  const SenzuAspectPanel({
    super.key,
    required this.bundle,
    required this.style,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    final aspects = <BoxFit, String>{
      BoxFit.cover: style.senzuLanguage.normal,
      BoxFit.contain: style.senzuLanguage.contain,
      BoxFit.fill: style.senzuLanguage.fill,
      BoxFit.fitWidth: style.senzuLanguage.fitWidth,
      BoxFit.fitHeight: style.senzuLanguage.fitHeight,
    };

    return SenzuSidePanel(
      bundle: bundle,
      style: style,
      panel: SenzuPanel.aspect,
      child: Obx(
        () => _PanelList(
          items: aspects.entries
              .map(
                (e) => _PanelItem(
                  label: e.value,
                  selected: bundle.ui.currentAspect.value == e.key,
                  onTap: () => bundle.ui.setAspect(e.key),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ── Episode ───────────────────────────────────────────────────────────────────
class SenzuEpisodePanel extends StatelessWidget {
  const SenzuEpisodePanel({
    super.key,
    required this.bundle,
    required this.style,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  @override
  Widget build(BuildContext context) => SenzuSidePanel(
    bundle: bundle,
    panel: SenzuPanel.episode,
    width: 240,
    style: style,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: style.episodeWidget!,
    ),
  );
}

// ── Cast Panel ────────────────────────────────────────────────────────────────
class SenzuCastPanel extends StatelessWidget {
  const SenzuCastPanel({
    super.key,
    required this.bundle,
    required this.style,
    required this.castController,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuCastController castController;

  @override
  Widget build(BuildContext context) => SenzuSidePanel(
    bundle: bundle,
    panel: SenzuPanel.cast,
    width: 260,
    style: style,
    child: _CastPanelContent(
      bundle: bundle,
      style: style,
      castController: castController,
    ),
  );
}

class _CastPanelContent extends StatefulWidget {
  const _CastPanelContent({
    required this.bundle,
    required this.style,
    required this.castController,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuCastController castController;

  @override
  State<_CastPanelContent> createState() => _CastPanelContentState();
}

class _CastPanelContentState extends State<_CastPanelContent> {
  List<SenzuCastDeviceInfo> _devices = [];
  bool _discovering = false;
  String? _connectingId;
  StreamSubscription? _deviceSub;

  SenzuCastController get cc => widget.castController;

  @override
  void initState() {
    super.initState();
    SenzuCastService.startListening();
    _deviceSub = SenzuCastService.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    _discover();
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    super.dispose();
  }

  Future<void> _discover() async {
    if (!mounted) return;
    setState(() => _discovering = true);
    final found = await SenzuCastService.discoverDevices();
    if (mounted) {
      setState(() {
        if (found.isNotEmpty) _devices = found;
        _discovering = false;
      });
    }
  }

  Future<void> _connect(SenzuCastDeviceInfo device) async {
    setState(() => _connectingId = device.deviceId);
    await SenzuCastService.connectToDevice(device.deviceId);
    if (mounted) setState(() => _connectingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = cc.castState.value;
      final isCasting = state == SenzuCastState.connected;

      if (isCasting) {
        return _ConnectedView(
          bundle: widget.bundle,
          style: widget.style,
          castController: cc,
        );
      }

      return _DeviceListView(
        devices: _devices,
        discovering: _discovering,
        connectingId: _connectingId,
        onDiscover: _discover,
        onConnect: _connect,
      );
    });
  }
}

// ── Device list (not connected) ───────────────────────────────────────────────
class _DeviceListView extends StatelessWidget {
  const _DeviceListView({
    required this.devices,
    required this.discovering,
    required this.connectingId,
    required this.onDiscover,
    required this.onConnect,
  });
  final List<SenzuCastDeviceInfo> devices;
  final bool discovering;
  final String? connectingId;
  final VoidCallback onDiscover;
  final void Function(SenzuCastDeviceInfo) onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Refresh button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: onDiscover,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: discovering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          color: Colors.white54,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),
        ),

        if (discovering && devices.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Colors.white38,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Хайж байна...',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          )
        else if (devices.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cast, color: Colors.white12, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'Төхөөрөмж олдсонгүй',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: devices.length,
              itemBuilder: (_, i) {
                final d = devices[i];
                final isConnecting = connectingId == d.deviceId;
                return InkWell(
                  onTap: isConnecting ? null : () => onConnect(d),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cast, color: Colors.white54, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.deviceName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              if (d.modelName.isNotEmpty)
                                Text(
                                  d.modelName,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isConnecting)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.lightBlueAccent,
                            ),
                          )
                        else
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white24,
                            size: 16,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Connected view ────────────────────────────────────────────────────────────
class _ConnectedView extends StatelessWidget {
  const _ConnectedView({
    required this.bundle,
    required this.style,
    required this.castController,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuCastController castController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final remote = castController.remoteState.value;
      final device = castController.availableDevices.firstOrNull;

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.cast_connected,
                    color: Colors.lightBlueAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      device?.deviceName ?? 'Cast',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 12),

            // Progress
            if (remote.durationMs > 0) ...[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.red,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.red,
                  trackHeight: 2,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                ),
                child: Slider(
                  value: (remote.positionMs / remote.durationMs).clamp(
                    0.0,
                    1.0,
                  ),
                  onChanged: (v) {
                    final posMs = (v * remote.durationMs).toInt();
                    castController.seekTo(Duration(milliseconds: posMs));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(Duration(milliseconds: remote.positionMs)),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      _fmt(Duration(milliseconds: remote.durationMs)),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CastCtrlBtn(
                  icon: Icons.replay_10,
                  size: 20,
                  onTap: () => castController.seekTo(
                    Duration(milliseconds: remote.positionMs - 10000),
                  ),
                ),
                const SizedBox(width: 12),
                _CastCtrlBtn(
                  icon: remote.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 34,
                  onTap: remote.isPlaying
                      ? castController.pause
                      : castController.play,
                ),
                const SizedBox(width: 12),
                _CastCtrlBtn(
                  icon: Icons.forward_10,
                  size: 20,
                  onTap: () => castController.seekTo(
                    Duration(milliseconds: remote.positionMs + 10000),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Volume
            Row(
              children: [
                const Icon(Icons.volume_up, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white70,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      trackHeight: 2,
                      overlayShape: SliderComponentShape.noOverlay,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                      ),
                    ),
                    child: Slider(
                      value: remote.volume.clamp(0.0, 1.0),
                      onChanged: castController.setCastVolume,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(color: Colors.white12, height: 12),

            // Subtitle tracks
            if (castController.subtitleTracks.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Subtitle',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
              const SizedBox(height: 4),
              Obx(
                () => Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _TrackChip(
                      label: 'Off',
                      selected:
                          castController.activeSubtitleTrackId.value == null,
                      onTap: castController.disableSubtitles,
                    ),
                    ...castController.subtitleTracks.map(
                      (t) => _TrackChip(
                        label: t.name,
                        selected:
                            castController.activeSubtitleTrackId.value == t.id,
                        onTap: () => castController.setSubtitle(t.id),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Quality options
            if (castController.qualityOptions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Quality',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
              const SizedBox(height: 4),
              Obx(
                () => Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: castController.qualityOptions
                      .map(
                        (q) => _TrackChip(
                          label: q.label,
                          selected:
                              castController.activeQuality.value == q.label,
                          onTap: () => castController.switchQuality(q.label),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            const Divider(color: Colors.white12, height: 12),

            // Disconnect
            InkWell(
              onTap: castController.disconnect,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.cast, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Disconnect',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

class _CastCtrlBtn extends StatelessWidget {
  const _CastCtrlBtn({required this.icon, required this.onTap, this.size = 24});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Icon(icon, color: Colors.white, size: size),
  );
}

class _TrackChip extends StatelessWidget {
  const _TrackChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? Colors.red : Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 10,
        ),
      ),
    ),
  );
}

// ── Shared ────────────────────────────────────────────────────────────────────
class _PanelList extends StatelessWidget {
  const _PanelList({required this.items});
  final List<_PanelItem> items;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    ),
  );
}

class _PanelItem extends StatelessWidget {
  const _PanelItem({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.red : Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.multitrack_audio, size: 16, color: Colors.red),
        ],
      ),
    ),
  );
}
