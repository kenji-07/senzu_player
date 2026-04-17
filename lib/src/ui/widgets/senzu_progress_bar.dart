import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/data/models/senzu_thumbnail_sprite.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

class SenzuProgressBar extends StatefulWidget {
  const SenzuProgressBar({
    super.key,
    required this.style,
    required this.bundle,
    this.thumbnailSprite,
    this.chapters = const [],
  });
  final SenzuProgressBarStyle style;
  final SenzuPlayerBundle bundle;
  final SenzuThumbnailSprite? thumbnailSprite;
  final List<SenzuChapter> chapters;

  @override
  State<SenzuProgressBar> createState() => _SenzuProgressBarState();
}

class _SenzuProgressBarState extends State<SenzuProgressBar> {
  double _totalW = 1.0;

  int _lastHapticSecond = -1;

  SenzuPlayerBundle get bundle => widget.bundle;
  SenzuProgressBarStyle get s => widget.style;

  void _onDragStart(double dx, double w) {
    _totalW = w > 0 ? w : 1.0;
    bundle.playback.dragRatio.value = (dx / _totalW).clamp(0.0, 1.0);
    _lastHapticSecond = -1;
    bundle.playback.setDragging(true);
    bundle.ui.showAndHideOverlay(
      true,
    ); // ← overlay харуулж, timer-г cancel хийнэ
    bundle.core.pause();
    setState(() {});
  }

  void _onDragUpdate(double dx) {
    if (_totalW <= 0) return;

    bundle.playback.dragRatio.value = (dx / _totalW).clamp(0.0, 1.0);

    final dur = bundle.playback.duration.value;
    if (dur.inMilliseconds == 0) return;

    final currentSec = (dur.inSeconds * bundle.playback.dragRatio.value)
        .floor();

    if (currentSec != _lastHapticSecond) {
      _lastHapticSecond = currentSec;
      HapticFeedback.selectionClick();
    }

    setState(() {});
  }

  Future<void> _onDragEnd() async {
    if (!bundle.playback.isDragging.value) return;
    final target =
        bundle.playback.duration.value * bundle.playback.dragRatio.value;
    bundle.playback.setDragging(false);
    _lastHapticSecond = -1;
    await bundle.core.seekTo(bundle.core.beginRange + target);
    if (bundle.ad.activeAd.value == null) await bundle.core.play();
    // play() дуусмагц timer дахин эхэлнэ — автоматаар
  }

  void _onDragCancel() {
    if (!bundle.playback.isDragging.value) return;
    // Frame lock үед шууд setState дуудахгүйн тулд next frame хүлээнэ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Widget аль хэдийн unmount болсон ч GetX Rx-д бичиж болно
      // (widget биш controller-д бичиж байгаа тул mounted шаардлагагүй)
      bundle.playback.setDragging(false);
      _lastHapticSecond = -1;
      if (bundle.ad.activeAd.value == null) bundle.core.play();
    });
  }

  void _stopHapticTimer() {
    _lastHapticSecond = -1;
  }

  @override
  void dispose() {
    _stopHapticTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        _totalW = box.maxWidth > 0 ? box.maxWidth : 1.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(d.globalPosition);
            _onDragStart(local.dx, box.size.width);
          },
          onHorizontalDragUpdate: (d) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(d.globalPosition);
            _onDragUpdate(local.dx);
          },
          onHorizontalDragEnd: (_) => _onDragEnd(),
          onHorizontalDragCancel: _onDragCancel,
          onTapDown: (d) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(d.globalPosition);

            final ratio = (local.dx / box.size.width).clamp(0.0, 1.0);
            final dur = bundle.playback.duration.value;

            if (dur.inMilliseconds == 0) return;

            final target = dur * ratio;

            bundle.core.seekTo(bundle.core.beginRange + target);
          },
          onTapUp: (_) => _onDragEnd(),
          onTapCancel: _onDragCancel,
          child: Obx(() {
            final dur = bundle.playback.duration.value;

            // Drag хийж байвал bundle.playback.dragRatio.value, үгүй бол position-ийн ratio
            final posR = bundle.playback.isDragging.value
                ? bundle.playback.dragRatio.value
                : (dur.inMilliseconds > 0
                      ? (bundle.playback.position.value.inMilliseconds /
                                dur.inMilliseconds)
                            .clamp(0.0, 1.0)
                      : 0.0);

            final bufR = dur.inMilliseconds > 0
                ? (bundle.playback.maxBuffering.value.inMilliseconds /
                          dur.inMilliseconds)
                      .clamp(0.0, 1.0)
                : 0.0;

            return SizedBox(
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
                  ),
                  _Bar(
                    w: _totalW,
                    ratio: bufR,
                    color: s.bufferedColor,
                    style: s,
                  ),
                  _Bar(w: _totalW, ratio: posR, color: s.color, style: s),
                  _Dot(
                    posRatio: posR,
                    totalW: _totalW,
                    style: s,
                    isDragging: bundle.playback.isDragging.value,
                  ),
                  // ── Chapter markers ────────────────────────────────────────
                  if (widget.chapters.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: SenzuChapterPainter(
                            chapters: widget.chapters,
                            duration: dur, // Obx дотор аль хэдийн унших байгаа
                            currentPosition: bundle.playback.isDragging.value
                                ? dur * bundle.playback.dragRatio.value
                                : bundle.playback.position.value,
                            markerHeight: s.height * 1.0,
                            markerWidth: 2.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class SenzuChapterPainter extends CustomPainter {
  SenzuChapterPainter({
    required this.chapters,
    required this.duration,
    this.markerColor = Colors.white,
    this.markerWidth = 2.0,
    this.markerHeight = 10.0,
    this.activeChapterColor = const Color(0xFFFFD700),
    this.currentPosition,
  }) : _cache = _ChapterPainterCache(chapters, duration);

  final List<SenzuChapter> chapters;
  final Duration duration;
  final Duration? currentPosition;
  final Color markerColor;
  final Color activeChapterColor;
  final double markerWidth;
  final double markerHeight;

  // Immutable cache — duration/chapters өөрчлөгдөхөд л шинэчлэгдэнэ
  final _ChapterPainterCache _cache;

  // Paint объектуудыг дахин үүсгэхгүйн тулд lazy init
  final _normalPaint = Paint()..strokeCap = StrokeCap.round;
  final _activePaint = Paint()..strokeCap = StrokeCap.round;
  final _glowPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final fractions = _cache.fractions;
    if (fractions.isEmpty) return;

    final activeIdx = currentPosition != null
        ? _cache.activeChapterIndex(currentPosition!.inMilliseconds)
        : -1;

    for (int i = 0; i < fractions.length; i++) {
      // showOnProgressBar=false chapter-уудыг skip — OP/ED separator-ууд
      if (!chapters[i].showOnProgressBar) continue;

      final x = fractions[i] * size.width;

      // Edge-д байгаа marker-уудыг skip (visual clipping)
      if (x < markerWidth || x > size.width - markerWidth) continue;

      final isActive = i == activeIdx;
      final top = (size.height - markerHeight) / 2;

      if (isActive) {
        _activePaint
          ..color = activeChapterColor
          ..strokeWidth = markerWidth + 0.5;
        canvas.drawLine(
          Offset(x, top),
          Offset(x, top + markerHeight),
          _activePaint,
        );

        // Glow effect — active chapter-т
        _glowPaint.color = activeChapterColor.withValues(alpha: 0.28);
        canvas.drawCircle(
          Offset(x, size.height / 2),
          markerWidth * 2.5,
          _glowPaint,
        );
      } else {
        _normalPaint
          ..color = markerColor
          ..strokeWidth = markerWidth;
        canvas.drawLine(
          Offset(x, top),
          Offset(x, top + markerHeight),
          _normalPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SenzuChapterPainter old) {
    // Position өөрчлөгдөхөд л repaint
    if (old.currentPosition != currentPosition) return true;
    // Duration өөрчлөгдсөн бол cache invalid → repaint
    if (old.duration != duration) return true;
    // Chapter тоо өөрчлөгдсөн бол repaint
    if (old.chapters.length != chapters.length) return true;
    return false;
  }

  @override
  bool shouldRebuildSemantics(SenzuChapterPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChapterPainterCache  —  fraction list-ийг duration-аар cache хийнэ
// ─────────────────────────────────────────────────────────────────────────────

class _ChapterPainterCache {
  _ChapterPainterCache(List<SenzuChapter> chapters, Duration duration)
    : fractions = _compute(chapters, duration);

  final List<double> fractions;

  static List<double> _compute(List<SenzuChapter> chapters, Duration duration) {
    if (duration.inMilliseconds == 0 || chapters.isEmpty) return const [];
    final ms = duration.inMilliseconds.toDouble();
    // showOnProgressBar=false байсан ч fraction-г хадгална —
    // index alignment-г хадгалахад хэрэгтэй (paint дотор skip хийнэ)
    return List.generate(
      chapters.length,
      (i) => chapters[i].startMs / ms,
      growable: false,
    );
  }

  /// O(log n) binary search: posMs-д хамааралтай chapter index
  int activeChapterIndex(int posMs) {
    if (fractions.isEmpty) return -1;
    int lo = 0, hi = fractions.length - 1, result = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      // Chapter-ийн startMs <= posMs бол candidate
      // (fractions[mid] * duration_ms ≈ startMs)
      if ((fractions[mid] * 1e9).round() <= posMs * 1e3.round()) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }
}

// ── _Bar ──────────────────────────────────────────────────────────────────────
class _Bar extends StatelessWidget {
  const _Bar({
    required this.w,
    required this.ratio,
    required this.color,
    required this.style,
  });
  final double w, ratio;
  final Color color;
  final SenzuProgressBarStyle style;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 80),
    width: (w * ratio).clamp(0.0, w),
    height: style.height,
    decoration: BoxDecoration(color: color, borderRadius: style.borderRadius),
  );
}

// ── _Dot ──────────────────────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  const _Dot({
    required this.posRatio,
    required this.totalW,
    required this.style,
    required this.isDragging,
  });
  final double posRatio, totalW;
  final SenzuProgressBarStyle style;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final sz = style.dotSize * (isDragging ? 1.8 : 1.0);
    final left = (totalW * posRatio - sz).clamp(0.0, totalW - sz * 2);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      margin: EdgeInsets.only(left: left),
      width: sz * 2,
      height: sz * 2,
      decoration: BoxDecoration(
        color: style.dotColor,
        shape: BoxShape.circle,
        // Drag хийж байвал shadow нэм
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

// ── _SeekThumbnail ────────────────────────────────────────────────────────────
class SeekThumbnail extends StatelessWidget {
  const SeekThumbnail({
    required this.position,
    required this.sprite,
    required this.style,
  });
  final Duration position;
  final SenzuThumbnailSprite sprite;
  final SenzuProgressBarStyle style;

  @override
  Widget build(BuildContext context) {
    final offset = sprite.fractionalOffsetAt(position);

    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: sprite.url,
          fit: BoxFit.none,
          width: Get.width,
          height: Get.height,
          alignment: offset,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => Container(
            color: Colors.black45,
            child: const Icon(
              Icons.image_not_supported,
              color: Colors.white38,
              size: 24,
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: style.tooltipBgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _fmt(position),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── _Tooltip ──────────────────────────────────────────────────────────────────
class Tooltips extends StatelessWidget {
  const Tooltips({required this.position, required this.style});
  final Duration position;
  final SenzuProgressBarStyle style;

  @override
  Widget build(BuildContext context) {
    final text = _fmt(position);

    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: style.tooltipBgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
