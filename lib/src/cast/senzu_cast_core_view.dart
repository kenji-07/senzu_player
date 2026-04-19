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

  @override
  void dispose() {
    _rewindTimer?.cancel();
    _forwardTimer?.cancel();
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
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuMetaData meta;
  final SenzuCastController castController;
  final List<SenzuChapter> chapters;
  final bool showRewind, showForward;
  final int rewindCount, forwardCount;
  final VoidCallback onDoubleTapLeft, onDoubleTapRight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Poster / background ─────────────────────────────────────────────
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: castController.currentPosterUrl!,
            fit: BoxFit.contain,
            placeholder: (_, __) => const ColoredBox(color: Colors.black),
            errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),
        ),

        // ── Tap + double-tap zones ──────────────────────────────────────────
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

        // ── Overlay (top + bottom) ──────────────────────────────────────────
        Align(
          alignment: Alignment.topCenter,
          child: _CastTopBar(
            bundle: bundle,
            style: style,
            meta: meta,
            castController: castController,
          ),
        ),
        // Bottom
        Align(
          alignment: Alignment.bottomCenter,
          child: _CastBottomBar(
            bundle: bundle,
            castController: castController,
            style: style,
            chapters: chapters,
          ),
        ),

        // ── Center controls (항상 표시 — overlay 상태와 무관) ─────────────────
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

        // ── Panels ──────────────────────────────────────────────────────────
        _CastQualityPanel(style: style, castController: castController),
        _CastCaptionPanel(style: style, castController: castController),
        _CastAudioPanel(style: style, castController: castController),

        // ── Panel close overlay ─────────────────────────────────────────────
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
      ],
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
                onTap: () => bundle.core.closeFullscreen(),
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
                Icons.closed_caption,
                () => castController.toggleCastPanel(SenzuCastPanel.caption),
              ),
              _IconBtn(
                Icons.hd,
                () => castController.toggleCastPanel(SenzuCastPanel.quality),
              ),
              _IconBtn(
                Icons.audiotrack,
                () => castController.toggleCastPanel(SenzuCastPanel.audio),
              ),
              SenzuCastButton(castController: castController, bundle: bundle),
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
        final isLive = remote.durationMs == 0 || bundle.core.isLiveRx.value;

        final ratio = remote.durationMs > 0
            ? (remote.positionMs / remote.durationMs).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  // Cast device badge
                  Obx(() {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cast_connected,
                          color: Colors.lightBlueAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          castController.connectedDeviceName ?? 'Cast',
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(width: 8),
                  if (!isLive)
                    Text('${_fmt(pos)} / ${_fmt(dur)}', style: style.textStyle),
                  const Spacer(),
                  InkWell(
                    onTap: () => bundle.core.openOrCloseFullscreen(),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        isFS ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    decoration: BoxDecoration(shape: BoxShape.circle, color: style.circleColor),
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
            final posMs =
                (_dragRatio *
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
                // Background
                Container(
                  height: s.height,
                  decoration: BoxDecoration(
                    color: s.backgroundColor,
                    borderRadius: s.borderRadius,
                  ),
                ),
                // Played
                AnimatedContainer(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 80),
                  width: (_totalW * displayRatio).clamp(0.0, _totalW),
                  height: s.height,
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent,
                    borderRadius: s.borderRadius,
                  ),
                ),
                // Chapter markers
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
                // Dot
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
                        color: Colors.lightBlueAccent,
                        shape: BoxShape.circle,
                        boxShadow: _dragging
                            ? [
                                BoxShadow(
                                  color: Colors.lightBlueAccent.withValues(
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
                label: q.label,
                selected: q.label == activeQ,
                onTap: q.label == activeQ
                    ? null
                    : () => castController.switchQuality(q.label),
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
            label: style.senzuLanguage.none,
            selected: activeId == null,
            onTap: castController.disableSubtitles,
          ),
          ...tracks.map(
            (t) => _PanelItem(
              label: t.name,
              selected: activeId == t.id,
              onTap: () => castController.setSubtitle(t.id),
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
                label: '${t.name} (${t.language})',
                selected: activeId == t.id,
                onTap: () => castController.setAudioTrack(t.id),
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: const BoxDecoration(color: Colors.black),
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
                color: selected ? Colors.lightBlueAccent : Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check, size: 14, color: Colors.lightBlueAccent),
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
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}
