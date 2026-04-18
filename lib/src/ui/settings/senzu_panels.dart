import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';

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
    // rxVideo солигдоход speed-г дахин уншина
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
