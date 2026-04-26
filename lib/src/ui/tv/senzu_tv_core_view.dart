import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:senzu_player/src/ui/widgets/senzu_video_surface.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/ui/tv/panel.dart';
import 'package:senzu_player/src/ui/widgets/senzu_buffer_loader.dart';
import 'package:senzu_player/src/ui/widgets/senzu_watermark_overlay.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/ui/core/senzu_player_core_view_patches.dart';
import 'package:senzu_player/src/data/models/subtitle_model.dart';

import 'senzu_tv_overlay_top.dart';
import 'senzu_tv_overlay_bottom.dart';
import 'senzu_tv_focus_wrapper.dart';

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
    this.enableEpisode = true,
    this.defaultAspectRatio = 16 / 9,
    this.chapters = const [],
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
      enableEpisode;
  final List<SenzuChapter> chapters;

  @override
  State<SenzuTvCoreView> createState() => _SenzuTvCoreViewState();
}

class _SenzuTvCoreViewState extends State<SenzuTvCoreView> {
  SenzuPlayerBundle get bundle => widget.bundle;
  SenzuPlayerStyle get style => widget.style;

  _Zone _zone = _Zone.center;

  final _rootNode = FocusNode(debugLabel: 'tv-root');
  final _topFirstNode = FocusNode(debugLabel: 'tv-top-first');
  final _bottomFirstNode = FocusNode(debugLabel: 'tv-bottom-first');
  final _centerControlNode = FocusNode(debugLabel: 'tv-center-control');

  int _rewindCount = 0, _forwardCount = 0;
  bool _showRewind = false, _showForward = false;
  Timer? _rewindTimer, _forwardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      bundle.ui.toggleLock(true);
      _rootNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _rootNode.dispose();
    _topFirstNode.dispose();
    _bottomFirstNode.dispose();
    _centerControlNode.dispose();
    _rewindTimer?.cancel();
    _forwardTimer?.cancel();
    super.dispose();
  }

  void _triggerSeek({required bool rewind}) {
    final offset = Duration(seconds: rewind ? -10 : 10);
    bundle.core.queueSeek(
      offset,
      isBuffering: bundle.core.rxNativeState.value.isBuffering,
    );
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

  void _goZone(_Zone z) {
    if (!mounted) {
      return;
    }

    setState(() => _zone = z);

    bundle.ui.isShowingOverlay.value = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final node = switch (z) {
        _Zone.top => _topFirstNode,
        _Zone.bottom => _bottomFirstNode,
        _Zone.center => _centerControlNode,
      };

      FocusScope.of(context).requestFocus(node);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = e.logicalKey;

    final panelOpen = bundle.ui.activePanel.value != SenzuPanel.none;
    final overlayVisible = bundle.ui.isShowingOverlay.value;

    final isBackKey = key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack;

    if (isBackKey) {
      if (panelOpen) {
        bundle.ui.activePanel.value = SenzuPanel.none;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _goZone(_Zone.bottom);
        });

        return KeyEventResult.handled;
      }

      if (overlayVisible) {
        bundle.ui.isShowingOverlay.value = false;
        _rootNode.requestFocus();
        return KeyEventResult.handled;
      }

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pop();
      }

      return KeyEventResult.handled;
    }

    if (panelOpen) {
      return KeyEventResult.ignored;
    }

    if (!overlayVisible) {
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.mediaPlayPause) {
        bundle.core.playOrPause();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.mediaPlay) {
        bundle.core.play();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.mediaPause) {
        bundle.core.pause();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowLeft) {
        _triggerSeek(rewind: true);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowRight) {
        _triggerSeek(rewind: false);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        _goZone(_Zone.bottom);
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      switch (_zone) {
        case _Zone.bottom:
          _goZone(_Zone.center);
          return KeyEventResult.handled;
        case _Zone.center:
          _goZone(_Zone.top);
          return KeyEventResult.handled;
        case _Zone.top:
          return KeyEventResult.ignored;
      }
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      switch (_zone) {
        case _Zone.top:
          _goZone(_Zone.center);
          return KeyEventResult.handled;
        case _Zone.center:
          _goZone(_Zone.bottom);
          return KeyEventResult.handled;
        case _Zone.bottom:
          return KeyEventResult.ignored;
      }
    }

    if (_zone == _Zone.top) {
      if (e is KeyDownEvent) {
        if (key == LogicalKeyboardKey.arrowRight) {
          FocusManager.instance.primaryFocus?.nextFocus();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowLeft) {
          FocusManager.instance.primaryFocus?.previousFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    if (_zone == _Zone.bottom) {
      if (e is KeyDownEvent) {
        if (key == LogicalKeyboardKey.arrowRight) {
          FocusManager.instance.primaryFocus?.nextFocus();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowLeft) {
          FocusManager.instance.primaryFocus?.previousFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      bundle.core.playOrPause();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.mediaPlay) {
      bundle.core.play();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.mediaPause) {
      bundle.core.pause();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Obx(() {
        final panelOpen = bundle.ui.activePanel.value != SenzuPanel.none;
        final overlayVisible = bundle.ui.isShowingOverlay.value;
        final showOverlay = overlayVisible && !panelOpen;

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
                opacity: showOverlay ? 0.55 : 0.0,
                child: Container(color: Colors.black),
              ),
            ),

            // 4. Center controls
            Obx(() {
              final loaderActive = bundle.ui.isShowingThumbnail.value ||
                  (bundle.core.isChangingSource.value &&
                      bundle.playback.position.value == Duration.zero);
              final visible = !panelOpen &&
                  !loaderActive &&
                  (bundle.ui.isShowingOverlay.value ||
                      bundle.core.isChangingSource.value ||
                      _showRewind ||
                      _showForward);
              final dur = bundle.playback.duration.value;
              final buf = bundle.playback.maxBuffering.value;
              final pos = bundle.playback.position.value;
              final bufRatio = dur.inMilliseconds > 0
                  ? ((buf - pos).inMilliseconds / dur.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    )
                  : 0.0;
              final bufPercent = (bufRatio * 100).toInt();
              final isDragging = bundle.playback.isDragging.value;

              return IgnorePointer(
                ignoring: !visible || isDragging,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: visible && !isDragging ? 1.0 : 0.0,
                  child: Center(
                    child: _TvCenterControls(
                      bundle: bundle,
                      style: style,
                      loading: style.loading,
                      buffering: Center(
                        child: RuntimeBufferingIndicator(
                          bufPercent: bufPercent,
                          style: style,
                        ),
                      ),
                      showRewind: _showRewind,
                      showForward: _showForward,
                      rewindCount: _rewindCount,
                      forwardCount: _forwardCount,
                      focusNode: _centerControlNode,
                    ),
                  ),
                ),
              );
            }),
            // 5. TOP overlay
            Align(
              alignment: Alignment.topCenter,
              child: ExcludeFocus(
                excluding: !showOverlay,
                child: AnimatedOpacity(
                  duration: style.transitions,
                  opacity: showOverlay ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !showOverlay,
                    child: SenzuTvOverlayTop(
                      bundle: bundle,
                      style: style,
                      meta: widget.meta,
                      enableCaption: widget.enableCaption,
                      enableQuality: widget.enableQuality,
                      enableSpeed: widget.enableSpeed,
                      enableAspect: widget.enableAspect,
                      firstFocusNode: _topFirstNode,
                    ),
                  ),
                ),
              ),
            ),

            // 6. Seek drag tooltip
            SeekDragTooltipWithChapter(
              bundle: bundle,
              style: style,
              chapters: widget.chapters,
            ),

            // 7. BOTTOM overlay
            Align(
              alignment: Alignment.bottomCenter,
              child: ExcludeFocus(
                excluding: !showOverlay,
                child: AnimatedOpacity(
                  duration: style.transitions,
                  opacity: showOverlay ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !showOverlay,
                    child: SenzuTvOverlayBottom(
                      bundle: bundle,
                      style: style,
                      enableEpisode: widget.enableEpisode,
                      chapters: widget.chapters,
                      // Эхний товчны node дамжуулна
                      firstFocusNode: _bottomFirstNode,
                    ),
                  ),
                ),
              ),
            ),

            // 8. Watermark
            if (bundle.core.watermark != null)
              Positioned.fill(
                child: SenzuWatermarkOverlay(watermark: bundle.core.watermark!),
              ),

            // ── Panels ───────────────────────────────────────────────────────
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

            // 9. Buffer loader
            SenzuBufferLoader(bundle: bundle, style: style),
          ],
        );
      }),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TvVideoFrame extends StatelessWidget {
  const _TvVideoFrame({required this.bundle, required this.aspectRatio});
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
            padding: style.paddingTV,
            child: Text(
              sub.text,
              textAlign: style.textAlign,
              style: style.textStyleTV,
            ),
          ),
        );
      },
    );
  }
}

class _TvCenterControls extends StatelessWidget {
  const _TvCenterControls({
    required this.bundle,
    required this.style,
    required this.loading,
    required this.buffering,
    required this.showRewind,
    required this.showForward,
    required this.rewindCount,
    required this.forwardCount,
    required this.focusNode,
  });

  final SenzuPlayerBundle bundle;
  final Widget loading, buffering;
  final SenzuPlayerStyle style;
  final bool showRewind, showForward;
  final int rewindCount, forwardCount;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (showRewind) return _circle(_text('-${rewindCount * 10}s'));
      if (showForward) return _circle(_text('+${forwardCount * 10}s'));
      if (bundle.core.isChangingSource.value) return _circle(loading);
      if (bundle.playback.isBuffering.value) return _circle(buffering);

      final playing = bundle.playback.isPlaying.value;
      final ended = !bundle.core.isLiveRx.value &&
          bundle.playback.position.value >= bundle.playback.duration.value &&
          bundle.playback.duration.value > Duration.zero;

      return SenzuTvFocusWrapper(
        focusNode: focusNode,
        autofocus: false,
        onTap: ended
            ? () => bundle.core.seekTo(Duration.zero)
            : bundle.core.playOrPause,
        focusedDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: Colors.white.withValues(alpha: 0.08),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: _circle(
          ended
              ? style.centerButtonStyle.replay
              : playing
                  ? style.centerButtonStyle.pause
                  : style.centerButtonStyle.play,
        ),
      );
    });
  }

  Widget _circle(Widget child) => Container(
        width: style.centerButtonStyle.circleSize,
        height: style.centerButtonStyle.circleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: style.centerButtonStyle.circleColor,
        ),
        child: child,
      );

  Widget _text(String t) => Center(
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}
