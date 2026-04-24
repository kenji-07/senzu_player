import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:senzu_player/src/ui/widgets/senzu_video_surface.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/ui/settings/senzu_panels.dart';
import 'package:senzu_player/src/ui/widgets/senzu_buffer_loader.dart';
import 'package:senzu_player/src/ui/widgets/senzu_watermark_overlay.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';
import 'package:senzu_player/src/ui/core/senzu_player_core_view_patches.dart';
import 'package:senzu_player/src/data/models/subtitle_model.dart';

import 'senzu_tv_overlay_top.dart';
import 'senzu_tv_overlay_bottom.dart';
import 'senzu_tv_focus_wrapper.dart';

/// Focus zone — overlay дотор 3 бүс байна:
/// [top] → [center] → [bottom]
/// ↑/↓ → бүс хоорондоо шилжинэ
/// ← / → → seek (center бүс байхад)
enum _Zone { center, top, bottom }

class SenzuTvCoreView extends StatefulWidget {
  const SenzuTvCoreView({
    super.key,
    required this.bundle,
    required this.style,
    required this.meta,
    this.enableCaption = true,
    this.enableQuality = true,
    this.enableAudio = false,
    this.enableSpeed = true,
    this.enableAspect = true,
    this.enableFullscreen = true,
    this.enablePip = false,
    this.enableLock = false,
    this.enableEpisode = true,
    this.enableSleep = true,
    this.defaultAspectRatio = 16 / 9,
    this.chapters = const [],
    this.castController,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuMetaData meta;
  final double defaultAspectRatio;
  final bool enableCaption,
      enableQuality,
      enableAudio,
      enableSpeed,
      enableAspect,
      enableFullscreen,
      enablePip,
      enableLock,
      enableSleep,
      enableEpisode;
  final List<SenzuChapter> chapters;
  final SenzuCastController? castController;

  @override
  State<SenzuTvCoreView> createState() => _SenzuTvCoreViewState();
}

class _SenzuTvCoreViewState extends State<SenzuTvCoreView> {
  SenzuPlayerBundle get bundle => widget.bundle;
  SenzuPlayerStyle get style => widget.style;

  // ── Focus scopes — top/bottom-д тус бүр FocusScopeNode байна ────────────
  final _topScope = FocusScopeNode(debugLabel: 'tv-top-scope');
  final _bottomScope = FocusScopeNode(debugLabel: 'tv-bottom-scope');
  final _centerNode = FocusNode(debugLabel: 'tv-center');

  _Zone _zone = _Zone.center;

  // ── Seek feedback ──────────────────────────────────────────────────────────
  int _rewindCount = 0, _forwardCount = 0;
  bool _showRewind = false, _showForward = false;
  Timer? _rewindTimer, _forwardTimer;

  @override
  void dispose() {
    _topScope.dispose();
    _bottomScope.dispose();
    _centerNode.dispose();
    _rewindTimer?.cancel();
    _forwardTimer?.cancel();
    super.dispose();
  }

  // ── Focus zone routing ─────────────────────────────────────────────────────
  void _goZone(_Zone z) {
    if (!mounted) return;
    setState(() => _zone = z);

    // overlay байхгүй бол нэг удаа харуулна
    if (!bundle.ui.isShowingOverlay.value) {
      bundle.ui.showAndHideOverlay(true);
    }

    switch (z) {
      case _Zone.top:
        _topScope.requestFocus();
      case _Zone.bottom:
        _bottomScope.requestFocus();
      case _Zone.center:
        _centerNode.requestFocus();
    }
  }

  // ── Seek feedback ──────────────────────────────────────────────────────────
  void _triggerSeek({required bool rewind}) {
    final offset = Duration(seconds: rewind ? -10 : 10);
    bundle.core.queueSeek(
        offset, isBuffering: bundle.core.rxNativeState.value.isBuffering);
    HapticFeedback.selectionClick();
    setState(() {
      if (rewind) {
        if (!_showRewind) _rewindCount = 0;
        _rewindCount++;
        _showRewind = true;
        _rewindTimer?.cancel();
        _rewindTimer = Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _showRewind = false);
        });
      } else {
        if (!_showForward) _forwardCount = 0;
        _forwardCount++;
        _showForward = true;
        _forwardTimer?.cancel();
        _forwardTimer = Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _showForward = false);
        });
      }
    });
  }

  // ── Root key handler ───────────────────────────────────────────────────────
  // Overlay харагдахгүй байх үед бүх key-г энд боловсруулна.
  // Overlay харагдах үед top/bottom scope өөрсдөө боловсруулна,
  // боловсруулаагүй key энд буцаж ирнэ.
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final panelOpen = bundle.ui.activePanel.value != SenzuPanel.none;
    final overlayVisible = bundle.ui.isShowingOverlay.value;

    // Panel хаах
    if (e.logicalKey == LogicalKeyboardKey.escape ||
        e.logicalKey == LogicalKeyboardKey.goBack) {
      if (panelOpen) {
        bundle.ui.activePanel.value = SenzuPanel.none;
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (panelOpen) return KeyEventResult.ignored;

    // ── Overlay гарч ирэх / бүс солих ─────────────────────────────────────
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!overlayVisible) {
        // Overlay нээгдэж, bottom бүс идэвхтэй болно
        _goZone(_Zone.bottom);
      } else if (_zone == _Zone.bottom) {
        _goZone(_Zone.center);
      } else if (_zone == _Zone.center) {
        _goZone(_Zone.top);
      }
      return KeyEventResult.handled;
    }

    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!overlayVisible) {
        _goZone(_Zone.bottom);
      } else if (_zone == _Zone.top) {
        _goZone(_Zone.center);
      } else if (_zone == _Zone.center) {
        _goZone(_Zone.bottom);
      }
      return KeyEventResult.handled;
    }

    // ── Center бүсэд байх үед ────────────────────────────────────────────────
    if (_zone == _Zone.center || !overlayVisible) {
      // Play/Pause
      if (e.logicalKey == LogicalKeyboardKey.select ||
          e.logicalKey == LogicalKeyboardKey.enter ||
          e.logicalKey == LogicalKeyboardKey.space ||
          e.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
        bundle.core.playOrPause();
        HapticFeedback.lightImpact();
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.mediaPlay) {
        bundle.core.play();
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.mediaPause) {
        bundle.core.pause();
        return KeyEventResult.handled;
      }

      // Seek ← →
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _triggerSeek(rewind: true);
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        _triggerSeek(rewind: false);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _centerNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Obx(() {
        final panelOpen = bundle.ui.activePanel.value != SenzuPanel.none;
        final overlayVisible = bundle.ui.isShowingOverlay.value;

        return Stack(
          children: [
            // 1. Video
            Positioned.fill(
              child: _TvVideoFrame(
                bundle: bundle,
                aspectRatio: widget.defaultAspectRatio,
              ),
            ),

            // 2. Subtitle
            _TvSubtitle(bundle: bundle, style: style.subtitleStyle),

            // 3. Dim
            IgnorePointer(
              child: AnimatedOpacity(
                duration: style.transitions,
                opacity: overlayVisible ? 0.55 : 0.0,
                child: Container(color: Colors.black),
              ),
            ),

            // 4. Center play/pause (overlay байх үед)
            if (overlayVisible && !panelOpen)
              Center(
                child: _TvCenterControls(
                  bundle: bundle,
                  style: style,
                  showRewind: _showRewind,
                  showForward: _showForward,
                  rewindCount: _rewindCount,
                  forwardCount: _forwardCount,
                  focusNode: _centerNode, // центр node-оос focus дамжуулна
                  onTap: bundle.core.playOrPause,
                ),
              ),

            // 4b. Seek feedback (overlay харагдахгүй байх үед ч гарна)
            if (_showRewind || _showForward)
              Center(
                child: _SeekFeedback(
                  rewind: _showRewind,
                  count: _showRewind ? _rewindCount : _forwardCount,
                ),
              ),

            // 5. Skip OP/ED
            SkipChapterButtons(
              bundle: bundle,
              style: style,
              panelOpen: panelOpen,
            ),

            // 6. TOP overlay — FocusScopeNode _topScope
            AnimatedPositioned(
              duration: style.transitions,
              top: overlayVisible && !panelOpen ? 0 : -120,
              left: 0,
              right: 0,
              child: FocusScope(
                node: _topScope,
                child: SenzuTvOverlayTop(
                  bundle: bundle,
                  style: style,
                  meta: widget.meta,
                  enableCaption: widget.enableCaption,
                  enableQuality: widget.enableQuality,
                  enableSpeed: widget.enableSpeed,
                  enableAspect: widget.enableAspect,
                  enableSleep: widget.enableSleep,
                  castController: widget.castController,
                ),
              ),
            ),

            // 7. Seek drag tooltip
            SeekDragTooltipWithChapter(
              bundle: bundle,
              style: style,
              chapters: widget.chapters,
            ),

            // 8. BOTTOM overlay — FocusScopeNode _bottomScope
            AnimatedPositioned(
              duration: style.transitions,
              bottom: overlayVisible && !panelOpen ? 0 : -120,
              left: 0,
              right: 0,
              child: FocusScope(
                node: _bottomScope,
                child: SenzuTvOverlayBottom(
                  bundle: bundle,
                  style: style,
                  enableFullscreen: widget.enableFullscreen,
                  enableEpisode: widget.enableEpisode,
                  chapters: widget.chapters,
                ),
              ),
            ),

            // 9. Watermark
            if (bundle.core.watermark != null)
              Positioned.fill(
                child:
                    SenzuWatermarkOverlay(watermark: bundle.core.watermark!),
              ),

            // 10. Panel backdrop
            if (panelOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      bundle.ui.activePanel.value = SenzuPanel.none,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),

            // ── Panels ────────────────────────────────────────────────────
            if (widget.enableQuality)
              SenzuQualityPanel(bundle: bundle, style: style),
            if (widget.enableSpeed)
              SenzuSpeedPanel(bundle: bundle, style: style),
            if (widget.enableCaption)
              SenzuCaptionPanel(bundle: bundle, style: style),
            if (widget.enableAspect)
              SenzuAspectPanel(bundle: bundle, style: style),
            if (widget.enableAudio)
              SenzuAudioPanel(bundle: bundle, style: style),
            if (widget.enableEpisode && style.episodeWidget != null)
              SenzuEpisodePanel(bundle: bundle, style: style),
            if (widget.enableSleep)
              SenzuSleepPanel(bundle: bundle, style: style),

            // 11. Buffer loader
            // SenzuBufferLoader(bundle: bundle, style: style),

            // 12. Zone indicator (debug — production-д устгана)
            if (overlayVisible)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _ZoneIndicator(zone: _zone),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _TvVideoFrame extends StatelessWidget {
  const _TvVideoFrame(
      {required this.bundle, required this.aspectRatio});
  final SenzuPlayerBundle bundle;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => Obx(() {
        final state = bundle.core.rxNativeState.value;
        final isChanging = bundle.core.isChangingSource.value;
        if (!state.isInitialized || isChanging) {
          return const ColoredBox(color: Colors.black);
        }
        return SenzuVideoSurfaceWithFit(
          videoAspectRatio: aspectRatio,
          fit: bundle.ui.currentAspect.value,
        );
      });
}

class _TvSubtitle extends StatelessWidget {
  const _TvSubtitle({required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuSubtitleStyle style;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubtitleData?>(
      valueListenable: bundle.subtitle.currentSubtitle,
      builder: (_, sub, __) {
        if (sub == null || sub.text.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: style.alignment,
          child: Padding(
            padding: style.padding,
            child: Text(
              sub.text,
              textAlign: style.textAlign,
              style: style.textStyle.copyWith(fontSize: 22),
            ),
          ),
        );
      },
    );
  }
}

/// Center play/pause товч — zone=center байх үед энд focus байна.
class _TvCenterControls extends StatelessWidget {
  const _TvCenterControls({
    required this.bundle,
    required this.style,
    required this.showRewind,
    required this.showForward,
    required this.rewindCount,
    required this.forwardCount,
    required this.focusNode,
    required this.onTap,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final bool showRewind, showForward;
  final int rewindCount, forwardCount;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (bundle.core.isChangingSource.value) {
        return _circle(style.centerButtonStyle, style.loading);
      }
      if (bundle.playback.isBuffering.value) {
        return _circle(style.centerButtonStyle, style.buffering);
      }

      final playing = bundle.playback.isPlaying.value;
      final ended = !bundle.core.isLiveRx.value &&
          bundle.playback.position.value >= bundle.playback.duration.value &&
          bundle.playback.duration.value > Duration.zero;

      return SenzuTvFocusWrapper(
        focusNode: focusNode,
        autofocus: false,
        onTap: onTap,
        focusedDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: Colors.white.withOpacity(0.1),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.25),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: _circle(
          style.centerButtonStyle,
          ended
              ? style.centerButtonStyle.replay
              : playing
                  ? style.centerButtonStyle.pause
                  : style.centerButtonStyle.play,
        ),
      );
    });
  }

  Widget _circle(SenzuCenterButtonStyle s, Widget child) => Container(
        width: s.circleSize,
        height: s.circleSize,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: s.circleColor),
        child: child,
      );
}

/// Seek ±10s feedback overlay
class _SeekFeedback extends StatelessWidget {
  const _SeekFeedback({required this.rewind, required this.count});
  final bool rewind;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        rewind ? '−${count * 10}s' : '+${count * 10}s',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Debug zone indicator — production-д энэ widget-ийг устга
class _ZoneIndicator extends StatelessWidget {
  const _ZoneIndicator({required this.zone});
  final _Zone zone;

  @override
  Widget build(BuildContext context) {
    final label = switch (zone) {
      _Zone.top => '▲ TOP',
      _Zone.center => '● CENTER',
      _Zone.bottom => '▼ BOTTOM',
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style:
            const TextStyle(color: Colors.white54, fontSize: 10),
      ),
    );
  }
}