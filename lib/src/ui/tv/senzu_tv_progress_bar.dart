import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/data/models/senzu_thumbnail_sprite.dart';
import 'package:senzu_player/src/ui/widgets/senzu_progress_bar.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';

class SenzuProgressBarTV extends StatefulWidget {
  const SenzuProgressBarTV({
    super.key,
    required this.style,
    required this.bundle,
    this.focusNode,
    this.autofocus = false,
    this.arrowSeekEnabled = true,
    this.thumbnailSprite,
    this.chapters = const [],
    this.onMoveBack,
    this.onSeekBackward,
    this.onSeekForward,
    this.onBack,
  });

  final SenzuProgressBarStyle style;
  final SenzuPlayerBundle bundle;

  final FocusNode? focusNode;
  final bool autofocus;
  final bool arrowSeekEnabled;

  final SenzuThumbnailSprite? thumbnailSprite;
  final List<SenzuChapter> chapters;

  final VoidCallback? onMoveBack;
  final VoidCallback? onSeekBackward;
  final VoidCallback? onSeekForward;
  final VoidCallback? onBack;

  @override
  State<SenzuProgressBarTV> createState() => SenzuProgressBarTVState();
}

class SenzuProgressBarTVState extends State<SenzuProgressBarTV> {
  double _totalW = 1.0;
  bool _focused = false;

  Duration? _optimisticPos;
  Timer? _optimisticResetTimer;
  Worker? _posWorker;

  SenzuPlayerBundle get bundle => widget.bundle;
  SenzuProgressBarStyle get s => widget.style;

  @override
  void initState() {
    super.initState();

    _posWorker = ever(bundle.playback.position, (Duration native) {
      final target = _optimisticPos;
      if (target == null || !mounted) return;

      final diff = (native - target).abs();
      if (diff.inMilliseconds <= 3000) {
        _optimisticResetTimer?.cancel();
        setState(() => _optimisticPos = null);
      }
    });
  }

  Duration? applyOptimisticSeek(int offsetSeconds) {
    final dur = bundle.playback.duration.value;
    if (dur.inMilliseconds == 0) return null;

    final current = _optimisticPos ?? bundle.playback.position.value;
    final raw = current + Duration(seconds: offsetSeconds);

    final next = raw < Duration.zero
        ? Duration.zero
        : raw > dur
            ? dur
            : raw;

    setState(() => _optimisticPos = next);

    _optimisticResetTimer?.cancel();
    _optimisticResetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _optimisticPos = null);
    });

    return next;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (!widget.arrowSeekEnabled) return KeyEventResult.ignored;

    if (e is KeyDownEvent &&
        (e.logicalKey == LogicalKeyboardKey.escape ||
            e.logicalKey == LogicalKeyboardKey.goBack ||
            e.logicalKey == LogicalKeyboardKey.browserBack)) {
      widget.onBack?.call();
      bundle.ui.isShowingOverlay.value = false;
      return KeyEventResult.handled;
    }

    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        final target = applyOptimisticSeek(-10);

        if (target != null) {
          bundle.core.seekTo(bundle.core.beginRange + target);
        }

        return KeyEventResult.handled;
      }

      if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        final target = applyOptimisticSeek(10);

        if (target != null) {
          bundle.core.seekTo(bundle.core.beginRange + target);
        }

        return KeyEventResult.handled;
      }

      if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.onMoveBack?.call();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _optimisticResetTimer?.cancel();
    _posWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: _onKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (_, box) {
            _totalW = box.maxWidth > 0 ? box.maxWidth : 1.0;
            final optimistic = _optimisticPos;

            return Obx(() {
              final dur = bundle.playback.duration.value;
              final isDragging = bundle.playback.isDragging.value;

              final displayPos = isDragging
                  ? dur * bundle.playback.dragRatio.value
                  : optimistic ?? bundle.playback.position.value;

              final posR = dur.inMilliseconds > 0
                  ? (displayPos.inMilliseconds / dur.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0;

              final bufR = dur.inMilliseconds > 0
                  ? (bundle.playback.maxBuffering.value.inMilliseconds /
                          dur.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: 28,
                    child: Stack(
                      alignment: AlignmentDirectional.centerStart,
                      clipBehavior: Clip.none,
                      children: [
                        _Bar(
                          w: _totalW,
                          ratio: 1.0,
                          color: s.backgroundColor,
                          style: s,
                          focus: _focused,
                        ),
                        _Bar(
                          w: _totalW,
                          ratio: bufR,
                          color: s.bufferedColor,
                          style: s,
                          focus: _focused,
                        ),
                        _Bar(
                          w: _totalW,
                          ratio: posR,
                          color: _focused ? s.color : s.dotColor,
                          style: s,
                          focus: _focused,
                        ),
                        _focused
                            ? _Dot(
                                posRatio: posR,
                                totalW: _totalW,
                                style: s,
                                isDragging: isDragging || optimistic != null,
                              )
                            : const SizedBox.shrink(),
                        if (widget.chapters.isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: SenzuChapterPainter(
                                  chapters: widget.chapters,
                                  duration: dur,
                                  currentPosition: displayPos,
                                  markerHeight: s.height,
                                  markerWidth: 2.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isDragging || optimistic != null)
                    Positioned(
                      bottom: 36,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: widget.thumbnailSprite != null
                            ? _TvSeekThumbnail(
                                position: displayPos,
                                sprite: widget.thumbnailSprite!,
                                style: s,
                                ratio: posR,
                                totalW: _totalW,
                              )
                            : _TvSeekTooltip(
                                position: displayPos,
                                style: s,
                                ratio: posR,
                                totalW: _totalW,
                              ),
                      ),
                    ),
                  if ((isDragging || optimistic != null) &&
                      widget.chapters.isNotEmpty)
                    Positioned(
                      bottom: widget.thumbnailSprite != null ? 160 : 64,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: _TvChapterTooltip(
                          position: displayPos,
                          chapters: widget.chapters,
                          style: s,
                        ),
                      ),
                    ),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}

class _TvSeekTooltip extends StatelessWidget {
  const _TvSeekTooltip({
    required this.position,
    required this.style,
    required this.ratio,
    required this.totalW,
  });

  final Duration position;
  final SenzuProgressBarStyle style;
  final double ratio;
  final double totalW;

  @override
  Widget build(BuildContext context) {
    const tooltipW = 72.0;
    final dotX = (totalW * ratio).clamp(tooltipW / 2, totalW - tooltipW / 2);

    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(dotX - tooltipW / 2, 0),
        child: Container(
          width: tooltipW,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: style.tooltipBgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _fmt(position),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: style.positionColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _TvSeekThumbnail extends StatelessWidget {
  const _TvSeekThumbnail({
    required this.position,
    required this.sprite,
    required this.style,
    required this.ratio,
    required this.totalW,
  });

  final Duration position;
  final SenzuThumbnailSprite sprite;
  final SenzuProgressBarStyle style;
  final double ratio;
  final double totalW;

  @override
  Widget build(BuildContext context) {
    const thumbW = 160.0;
    const thumbH = 90.0;
    final dotX = (totalW * ratio).clamp(thumbW / 2, totalW - thumbW / 2);
    final offset = sprite.fractionalOffsetAt(position);

    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(dotX - thumbW / 2, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: thumbW,
                height: thumbH,
                child: CachedNetworkImage(
                  imageUrl: sprite.url,
                  fit: BoxFit.none,
                  alignment: offset,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Colors.black45),
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: style.tooltipBgColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _fmt(position),
                style: TextStyle(
                  color: style.positionColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _TvChapterTooltip extends StatelessWidget {
  const _TvChapterTooltip({
    required this.position,
    required this.chapters,
    required this.style,
  });

  final Duration position;
  final List<SenzuChapter> chapters;
  final SenzuProgressBarStyle style;

  @override
  Widget build(BuildContext context) {
    final chapter = _findChapter(position);
    if (chapter == null || chapter.label == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: style.tooltipBgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          chapter.label!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  SenzuChapter? _findChapter(Duration pos) {
    if (chapters.isEmpty) return null;

    final posMs = pos.inMilliseconds;
    SenzuChapter? result;

    for (final c in chapters) {
      if (c.startMs <= posMs) {
        result = c;
      } else {
        break;
      }
    }

    return result;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.w,
    required this.ratio,
    required this.color,
    required this.style,
    required this.focus,
  });

  final double w;
  final bool focus;
  final double ratio;
  final Color color;
  final SenzuProgressBarStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: (w * ratio).clamp(0.0, w),
      height: style.height + (focus ? 3 : 0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: style.borderRadius,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.posRatio,
    required this.totalW,
    required this.style,
    required this.isDragging,
  });

  final double posRatio;
  final double totalW;
  final SenzuProgressBarStyle style;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final sz = style.dotSize * (isDragging ? 1.8 : 1.3);
    final left = (totalW * posRatio - sz).clamp(0.0, totalW - sz * 2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      margin: EdgeInsets.only(left: left),
      width: sz * 2,
      height: sz * 2,
      decoration: BoxDecoration(
        color: style.dotColor,
        shape: BoxShape.circle,
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: style.dotColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}
