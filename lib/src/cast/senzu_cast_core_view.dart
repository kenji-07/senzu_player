import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/cast/widgets/senzu_cast_button.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';
import 'package:senzu_player/src/cast/senzu_cast_service.dart';
import 'package:senzu_player/src/ui/widgets/senzu_progress_bar.dart';
import 'dart:developer';

class SenzuCastCoreView extends StatefulWidget {
  const SenzuCastCoreView({
    super.key,
    required this.bundle,
    required this.style,
    required this.meta,
    this.chapters = const [],
    this.castController,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle? style;
  final SenzuMetaData? meta;
  final List<SenzuChapter> chapters;
  final SenzuCastController? castController;

  @override
  State<SenzuCastCoreView> createState() => _SenzuCastCoreViewState();
}

class _SenzuCastCoreViewState extends State<SenzuCastCoreView> {
  SenzuPlayerBundle get bundle => widget.bundle;
  SenzuPlayerStyle get style => widget.style ?? SenzuPlayerStyle();
  SenzuMetaData get meta => widget.meta ?? const SenzuMetaData();

  // ── Double-tap seek ────────────────────────────────────────────────────────
  int _rewindCount = 0, _forwardCount = 0;
  bool _showRewind = false, _showForward = false;
  Timer? _rewindTimer, _forwardTimer;

  // ── Volume ────────────────────────────────────────────────────────
  bool _dragLeft = false;
  double? _dragVol;
  Timer? _dragVolTimer;

  @override
  void dispose() {
    _rewindTimer?.cancel();
    _forwardTimer?.cancel();
    _dragVolTimer?.cancel();
    super.dispose();
  }

  void _doubleTap({required bool rewind}) {
    final cc = widget.castController;
    if (cc == null) return;
    final posMs = cc.remoteState.value.positionMs;
    final offsetMs = rewind ? -10000 : 10000;
    cc.seekTo(
      Duration(
        milliseconds: (posMs + offsetMs).clamp(
          0,
          cc.remoteState.value.durationMs,
        ),
      ),
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

  void _onDragStart(DragStartDetails d) {
    final w = context.size?.width ?? 400;
    _dragLeft = d.localPosition.dx < w / 2;

    if (!_dragLeft) {
      _dragVol = widget.castController?.remoteState.value.volume ?? 1.0;
      if (mounted) setState(() {});
    }
  }

  Future<void> _onDragUpdate(DragUpdateDetails d) async {
    final cc = widget.castController;
    if (cc == null) return;
    if (_dragLeft) return;

    final h = context.size?.height ?? 400;
    final delta = -(d.primaryDelta! / h);

    final current = _dragVol ?? cc.remoteState.value.volume;
    final next = (current + delta).clamp(0.0, 1.0);

    _dragVol = next;
    await cc.setCastVolume(next);

    _dragVolTimer?.cancel();
    _dragVolTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() => _dragVol = null);
    });

    if (mounted) setState(() {});
  }

  void _onDragEnd(DragEndDetails _) {
    _dragVolTimer?.cancel();
    _dragVolTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      setState(() => _dragVol = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.castController == null) return const SizedBox.shrink();
    return _CastActiveView(
      bundle: bundle,
      style: style,
      meta: meta,
      castController: widget.castController!,
      chapters: widget.chapters,
      showRewind: _showRewind,
      showForward: _showForward,
      rewindCount: _rewindCount,
      forwardCount: _forwardCount,
      onDoubleTapLeft: () => _doubleTap(rewind: true),
      onDoubleTapRight: () => _doubleTap(rewind: false),
      onDragStart: _onDragStart,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      dragVolume: _dragVol,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CastActiveView
// ─────────────────────────────────────────────────────────────────────────────
class _CastActiveView extends StatelessWidget {
  const _CastActiveView({
    required this.bundle,
    required this.style,
    required this.meta,
    required this.castController,
    required this.chapters,
    required this.showRewind,
    required this.showForward,
    required this.rewindCount,
    required this.forwardCount,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.dragVolume,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuMetaData meta;
  final SenzuCastController castController;
  final List<SenzuChapter> chapters;
  final bool showRewind, showForward;
  final int rewindCount, forwardCount;
  final VoidCallback onDoubleTapLeft, onDoubleTapRight;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final double? dragVolume;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: meta.posterUrl ?? '',
              fit: BoxFit.contain,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: Obx(() {
              final panelOpen =
                  castController.activePanel.value != SenzuCastPanel.none;
              return IgnorePointer(
                ignoring: panelOpen,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: onDoubleTapLeft,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 3,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: onDoubleTapRight,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _CastTopBar(
              bundle: bundle,
              style: style,
              meta: meta,
              castController: castController,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _CastBottomBar(
              bundle: bundle,
              castController: castController,
              style: style,
              chapters: chapters,
            ),
          ),
          Center(
            child: _CastCenterControls(
              castController: castController,
              style: style.centerButtonStyle,
              loading: style.loading,
              buffering: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: Colors.white,
                ),
              ),
              showRewind: showRewind,
              showForward: showForward,
              rewindCount: rewindCount,
              forwardCount: forwardCount,
              onPrev: style.onPrevEpisode,
              onNext: style.onNextEpisode,
              hasPrev: style.hasPrevEpisode,
              hasNext: style.hasNextEpisode,
            ),
          ),
          Obx(() {
            final panelOpen =
                castController.activePanel.value != SenzuCastPanel.none;
            if (!panelOpen) return const SizedBox.shrink();

            return Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    castController.activePanel.value = SenzuCastPanel.none,
                child: const ColoredBox(color: Colors.transparent),
              ),
            );
          }),
          _CastQualityPanel(style: style, castController: castController),
          _CastCaptionPanel(style: style, castController: castController),
          _CastAudioPanel(style: style, castController: castController),
          if (dragVolume != null)
            IgnorePointer(
              child: Align(
                alignment: Alignment(0, style.vbToastStyle.topAlignment),
                child: Container(
                  padding: style.vbToastStyle.padding,
                  decoration: style.vbToastStyle.decoration,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dragVolume! <= 0
                            ? style.vbToastStyle.volume0
                            : dragVolume! < 0.5
                                ? style.vbToastStyle.volume50
                                : style.vbToastStyle.volume100,
                        color: style.vbToastStyle.iconColor,
                        size: style.vbToastStyle.iconSize,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: style.vbToastStyle.barWidth,
                        height: style.vbToastStyle.barHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: dragVolume!,
                            backgroundColor:
                                style.vbToastStyle.barBackgroundColor,
                            valueColor: AlwaysStoppedAnimation(
                              style.vbToastStyle.barForegroundColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class _CastTopBar extends StatelessWidget {
  const _CastTopBar({
    required this.bundle,
    required this.style,
    required this.meta,
    required this.castController,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuMetaData meta;
  final SenzuCastController castController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.only(top: 8, left: 12, right: 8, bottom: 12),
      child: Row(
        children: [
          if (meta.show ?? true)
            Expanded(
              child: GestureDetector(
                onTap: () => bundle.core.closeFullscreen(context),
                child: Row(
                  children: [
                    Icon(meta.icon, color: meta.iconColor, size: meta.iconSize),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (meta.title != null)
                              Text(
                                meta.title!,
                                style: meta.titleStyle,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            if (meta.description != null)
                              Text(
                                meta.description!,
                                style: meta.descriptionStyle,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBtn(
                style.overlayIconsStyle.caption,
                () => castController.toggleCastPanel(SenzuCastPanel.caption),
              ),
              _IconBtn(
                style.overlayIconsStyle.quality,
                () => castController.toggleCastPanel(SenzuCastPanel.quality),
              ),
              _IconBtn(
                style.overlayIconsStyle.audio,
                () => castController.toggleCastPanel(SenzuCastPanel.audio),
              ),
              SenzuCastButton(
                  castController: castController, bundle: bundle, style: style),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────
class _CastBottomBar extends StatelessWidget {
  const _CastBottomBar({
    required this.bundle,
    required this.castController,
    required this.style,
    required this.chapters,
  });

  final SenzuPlayerBundle bundle;
  final SenzuCastController castController;
  final SenzuPlayerStyle style;
  final List<SenzuChapter> chapters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: Obx(() {
        final remote = castController.remoteState.value;
        final isFS = bundle.core.isFullScreen.value;
        final hPad = isFS ? 28.0 : 14.0;
        final dur = Duration(milliseconds: remote.durationMs);
        final pos = Duration(milliseconds: remote.positionMs);

        final isLive = bundle.core.isLiveRx.value;

        final ratio = remote.durationMs > 0 && !isLive
            ? (remote.positionMs / remote.durationMs).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  // Cast device name
                  Obx(() {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cast_connected,
                          color: style.progressBarStyle.color,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          castController.connectedDeviceName ?? 'Cast',
                          style: TextStyle(
                            color: style.progressBarStyle.color,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(width: 8),

                  // Time label — show LIVE badge for live, time for VOD
                  if (isLive)
                    _CastLiveBadge(style: style)
                  else
                    Text('${_fmt(pos)} / ${_fmt(dur)}', style: style.textStyle),

                  const Spacer(),
                  InkWell(
                    onTap: () => bundle.core.openOrCloseFullscreen(),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: isFS
                          ? style.overlayIconsStyle.fullscreenExit
                          : style.overlayIconsStyle.fullscreen,
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar — hidden for live
            if (!isLive)
              Padding(
                padding: EdgeInsets.only(
                  left: hPad,
                  right: hPad,
                  bottom: isFS ? 16 : 8,
                ),
                child: _CastProgressBar(
                  ratio: ratio,
                  castController: castController,
                  style: style.progressBarStyle,
                  chapters: chapters,
                  duration: dur,
                  position: pos,
                ),
              )
            else
              SizedBox(height: isFS ? 16 : 8),
          ],
        );
      }),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── Live badge for cast ───────────────────────────────────────────────────────
class _CastLiveBadge extends StatelessWidget {
  const _CastLiveBadge({required this.style});
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.liveBadgeStyle.liveColor,
        borderRadius: style.liveBadgeStyle.borderRadius,
      ),
      child: Text(
        style.senzuLanguage.live,
        style: style.liveBadgeStyle.textStyle,
      ),
    );
  }
}

// ── Center controls ───────────────────────────────────────────────────────────
class _CastCenterControls extends StatelessWidget {
  const _CastCenterControls({
    required this.castController,
    required this.style,
    required this.loading,
    required this.buffering,
    required this.showRewind,
    required this.showForward,
    required this.rewindCount,
    required this.forwardCount,
    this.onPrev,
    this.onNext,
    this.hasPrev,
    this.hasNext,
  });

  final SenzuCastController castController;
  final SenzuCenterButtonStyle style;
  final Widget loading, buffering;
  final bool showRewind, showForward;
  final int rewindCount, forwardCount;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool? hasPrev;
  final bool? hasNext;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final remote = castController.remoteState.value;
      final isPlaying = remote.isPlaying;
      final isLoadingMedia =
          remote.sessionState == SenzuCastSessionState.loading ||
              castController.isLoading.value;
      final isBuffering =
          remote.sessionState == SenzuCastSessionState.buffering;
      final ended =
          remote.durationMs > 0 && remote.positionMs >= remote.durationMs;

      if (showRewind) return _circle(_seekText('-${rewindCount * 10}s'));
      if (showForward) return _circle(_seekText('+${forwardCount * 10}s'));
      if (isLoadingMedia) return _circle(loading);
      if (isBuffering) return _circle(buffering);

      final showPrev = hasPrev != null || onPrev != null;
      final showNext = hasNext != null || onNext != null;
      final prevEnabled = hasPrev ?? (onPrev != null);
      final nextEnabled = hasNext ?? (onNext != null);

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showPrev)
            _SideButton(
              icon: Icons.skip_previous,
              onTap: prevEnabled && onPrev != null ? onPrev! : null,
              size: style.circleSize * 0.55,
              isDisabled: !prevEnabled,
            )
          else
            SizedBox(width: style.circleSize * 0.55 + 8),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: ended
                ? () => castController.seekTo(Duration.zero)
                : (isPlaying ? castController.pause : castController.play),
            child: _circle(
              ended ? style.replay : (isPlaying ? style.pause : style.play),
            ),
          ),
          const SizedBox(width: 16),
          if (showNext)
            _SideButton(
              icon: Icons.skip_next,
              onTap: nextEnabled && onNext != null ? onNext! : null,
              size: style.circleSize * 0.55,
              isDisabled: !nextEnabled,
            )
          else
            SizedBox(width: style.circleSize * 0.55 + 8),
        ],
      );
    });
  }

  Widget _circle(Widget child) => Container(
        width: style.circleSize,
        height: style.circleSize,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: style.circleColor),
        child: child,
      );

  Widget _seekText(String text) => _circle(
        Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

// ── Progress bar ──────────────────────────────────────────────────────────────
class _CastProgressBar extends StatefulWidget {
  const _CastProgressBar({
    required this.ratio,
    required this.castController,
    required this.style,
    required this.chapters,
    required this.duration,
    required this.position,
  });

  final double ratio;
  final SenzuCastController castController;
  final SenzuProgressBarStyle style;
  final List<SenzuChapter> chapters;
  final Duration duration;
  final Duration position;

  @override
  State<_CastProgressBar> createState() => _CastProgressBarState();
}

class _CastProgressBarState extends State<_CastProgressBar> {
  bool _dragging = false;
  double _dragRatio = 0.0;
  double _totalW = 1.0;

  @override
  Widget build(BuildContext context) {
    final displayRatio = _dragging ? _dragRatio : widget.ratio;
    final s = widget.style;

    return LayoutBuilder(
      builder: (_, box) {
        _totalW = box.maxWidth > 0 ? box.maxWidth : 1.0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(d.globalPosition);
            setState(() {
              _dragging = true;
              _dragRatio = (local.dx / _totalW).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragUpdate: (d) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(d.globalPosition);
            setState(() {
              _dragRatio = (local.dx / _totalW).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (_) {
            final posMs = (_dragRatio *
                    widget.castController.remoteState.value.durationMs)
                .toInt();
            widget.castController.seekTo(Duration(milliseconds: posMs));
            setState(() => _dragging = false);
          },
          onTapDown: (d) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(d.globalPosition);
            final ratio = (local.dx / _totalW).clamp(0.0, 1.0);
            final posMs =
                (ratio * widget.castController.remoteState.value.durationMs)
                    .toInt();
            widget.castController.seekTo(Duration(milliseconds: posMs));
          },
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                Container(
                  height: s.height,
                  decoration: BoxDecoration(
                    color: s.backgroundColor,
                    borderRadius: s.borderRadius,
                  ),
                ),
                AnimatedContainer(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 80),
                  width: (_totalW * displayRatio).clamp(0.0, _totalW),
                  height: s.height,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: s.borderRadius,
                  ),
                ),
                if (widget.chapters.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: SenzuChapterPainter(
                          chapters: widget.chapters,
                          duration: widget.duration,
                          currentPosition: _dragging
                              ? widget.duration * _dragRatio
                              : widget.position,
                          markerHeight: s.height * 1.0,
                          markerWidth: 2.0,
                        ),
                      ),
                    ),
                  ),
                Builder(
                  builder: (_) {
                    final sz = s.dotSize * (_dragging ? 1.8 : 1.0);
                    final left = (_totalW * displayRatio - sz).clamp(
                      0.0,
                      _totalW - sz * 2,
                    );
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      margin: EdgeInsets.only(left: left),
                      width: sz * 2,
                      height: sz * 2,
                      decoration: BoxDecoration(
                        color: s.dotColor,
                        shape: BoxShape.circle,
                        boxShadow: _dragging
                            ? [
                                BoxShadow(
                                  color: s.backgroundColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Cast-aware side panels ────────────────────────────────────────────────────
class _CastQualityPanel extends StatelessWidget {
  const _CastQualityPanel({required this.style, required this.castController});
  final SenzuPlayerStyle style;
  final SenzuCastController castController;

  @override
  Widget build(BuildContext context) => _CastSidePanel(
        castController: castController,
        style: style,
        panel: SenzuCastPanel.quality,
        child: Obx(() {
          final qualities = castController.qualityOptions;
          final activeQ = castController.activeQuality.value;
          return _PanelList(
            items: qualities
                .map(
                  (q) => _PanelItem(
                    style: style,
                    label: q.label,
                    selected: q.label == activeQ,
                    onTap: q.label == activeQ
                        ? null
                        : () {
                            castController.switchQuality(q.label);
                            log('Select Quality: ${q.label}');
                          },
                  ),
                )
                .toList(),
          );
        }),
      );
}

class _CastCaptionPanel extends StatelessWidget {
  const _CastCaptionPanel({required this.style, required this.castController});
  final SenzuPlayerStyle style;
  final SenzuCastController castController;

  @override
  Widget build(BuildContext context) => _CastSidePanel(
        castController: castController,
        style: style,
        panel: SenzuCastPanel.caption,
        width: 220,
        child: Obx(() {
          final tracks = castController.subtitleTracks;
          final activeId = castController.activeSubtitleTrackId.value;
          return _PanelList(
            items: [
              _PanelItem(
                style: style,
                label: style.senzuLanguage.none,
                selected: activeId == null,
                onTap:
                    activeId == null ? null : castController.disableSubtitles,
              ),
              ...tracks.map(
                (t) => _PanelItem(
                  style: style,
                  label: t.name,
                  selected: activeId == t.id,
                  onTap: activeId == t.id
                      ? null
                      : () {
                          castController.setSubtitle(t.id);
                          log('Select Subtitle: ${t.id}');
                        },
                ),
              ),
            ],
          );
        }),
      );
}

class _CastAudioPanel extends StatelessWidget {
  const _CastAudioPanel({required this.style, required this.castController});
  final SenzuPlayerStyle style;
  final SenzuCastController castController;

  @override
  Widget build(BuildContext context) => _CastSidePanel(
        castController: castController,
        style: style,
        panel: SenzuCastPanel.audio,
        child: Obx(() {
          final tracks = castController.audioTracks;
          final activeId = castController.activeAudioTrackId.value;
          return _PanelList(
            items: tracks
                .map(
                  (t) => _PanelItem(
                    style: style,
                    label: '${t.name} (${t.language})',
                    selected: activeId == t.id,
                    onTap: () {
                      castController.setAudioTrack(t.id);
                      log('Select Audio: ${t.id}');
                    },
                  ),
                )
                .toList(),
          );
        }),
      );
}

// ── Side panel shell ──────────────────────────────────────────────────────────
class _CastSidePanel extends StatelessWidget {
  const _CastSidePanel({
    required this.castController,
    required this.style,
    required this.panel,
    required this.child,
    this.width = 200,
  });

  final SenzuCastController castController;
  final SenzuCastPanel panel;
  final Widget child;
  final double width;
  final SenzuPlayerStyle style;

  String get title {
    switch (panel) {
      case SenzuCastPanel.audio:
        return style.senzuLanguage.audio;
      case SenzuCastPanel.caption:
        return style.senzuLanguage.subtitles;
      case SenzuCastPanel.episode:
        return style.senzuLanguage.episodes;
      case SenzuCastPanel.quality:
        return style.senzuLanguage.quality;
      case SenzuCastPanel.cast:
        return style.senzuLanguage.cast;
      case SenzuCastPanel.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final visible = castController.activePanel.value == panel;
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
                  padding: style.settingsPanelStyle.panelPadding,
                  decoration: style.settingsPanelStyle.panelDecoration,
                  child: Column(
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
                          style: style.settingsPanelStyle.titleStyle,
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

// ── Shared helpers ────────────────────────────────────────────────────────────
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
  const _PanelItem(
      {required this.label,
      required this.selected,
      this.onTap,
      required this.style});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final SenzuPlayerStyle style;

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
                    color: selected
                        ? style.settingsPanelStyle.selectedTextColor
                        : style.settingsPanelStyle.unselectedTextColor,
                    fontSize: style.settingsPanelStyle.selectedTextSize,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (selected) style.settingsPanelStyle.selectedIcon,
            ],
          ),
        ),
      );
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.onTap,
    required this.size,
    this.isDisabled = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.35 : 1.0,
          child: Container(
            width: size + 16,
            height: size + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: isDisabled ? 0.15 : 0.35),
            ),
            child: Icon(icon, color: Colors.white, size: size),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(this.icon, this.onTap);
  final Icon icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: icon,
        ),
      );
}
