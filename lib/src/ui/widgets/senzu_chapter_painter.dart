import 'package:flutter/material.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';

/// Chapter marker-уудыг canvas дээр шууд зурна.
/// RepaintBoundary-тай хамт ашиглавал progress bar-ын rebuild-ыг
/// chapter layer-аас бүрэн тусгаарлана.
class SenzuChapterPainter extends CustomPainter {
  SenzuChapterPainter({
    required this.chapters,
    required this.duration,
    this.markerColor = Colors.white,
    this.markerWidth = 2.0,
    this.markerHeight = 10.0,
    this.activeChapterColor = const Color(0xFFFFD700),
    this.currentPosition,
  });

  final List<SenzuChapter> chapters;
  final Duration duration;
  final Duration? currentPosition;
  final Color markerColor;
  final Color activeChapterColor;
  final double markerWidth;
  final double markerHeight;

  // Cache: fraction-ыг duration өөрчлөгдөхөд л дахин тооцоолно
  late final List<double> _fractions = _computeFractions();

  List<double> _computeFractions() {
    if (duration.inMilliseconds == 0) return [];
    return chapters
        .map((c) => c.startMs / duration.inMilliseconds)
        .toList(growable: false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_fractions.isEmpty) return;

    // Active chapter index — O(log n) binary search
    final activeIdx = currentPosition != null
        ? _activeChapterIndex(currentPosition!)
        : -1;

    for (int i = 0; i < _fractions.length; i++) {
      final x = _fractions[i] * size.width;

      // Skip edges
      if (x < markerWidth || x > size.width - markerWidth) continue;

      final isActive = i == activeIdx;
      final paint = Paint()
        ..color = isActive ? activeChapterColor : markerColor
        ..strokeWidth = markerWidth
        ..strokeCap = StrokeCap.round;

      final top = (size.height - markerHeight) / 2;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + markerHeight),
        paint,
      );

      // Active chapter: glow effect (нэмэлт circle)
      if (isActive) {
        canvas.drawCircle(
          Offset(x, size.height / 2),
          markerWidth * 2,
          Paint()
            ..color = activeChapterColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  int _activeChapterIndex(Duration pos) {
    final posMs = pos.inMilliseconds;
    if (chapters.isEmpty) return -1;

    // Binary search — O(log n)
    int lo = 0, hi = chapters.length - 1, result = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (chapters[mid].startMs <= posMs) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(SenzuChapterPainter old) {
    // Position өөрчлөгдөхөд л repaint — duration/chapters өөрчлөгдөхгүй бол skip
    return old.currentPosition != currentPosition ||
        old.chapters.length != chapters.length ||
        old.duration != duration;
  }

  @override
  bool shouldRebuildSemantics(SenzuChapterPainter old) => false;
}

/// Progress bar + chapter markers нэгтгэсэн widget
class SenzuProgressBarWithChapters extends StatelessWidget {
  const SenzuProgressBarWithChapters({
    super.key,
    required this.progressBar,
    required this.chapters,
    required this.duration,
    required this.currentPosition,
    this.barHeight = 4.0,
  });

  final Widget progressBar;
  final List<SenzuChapter> chapters;
  final Duration duration;
  final Duration currentPosition;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) return progressBar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        progressBar,
        // RepaintBoundary: chapter layer нь progress rebuild-д нөлөөлөхгүй
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: SenzuChapterPainter(
                chapters: chapters,
                duration: duration,
                currentPosition: currentPosition,
                markerHeight: barHeight * 2.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}