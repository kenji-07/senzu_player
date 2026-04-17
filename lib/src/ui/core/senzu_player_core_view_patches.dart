import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/ui/widgets/senzu_progress_bar.dart';

class SkipChapterButtons extends StatelessWidget {
  const SkipChapterButtons({
    super.key,
    required this.bundle,
    required this.style,
    required this.panelOpen,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final bool panelOpen;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isFs       = bundle.core.isFullScreen.value;
      final isDragging = bundle.playback.isDragging.value;
      final chapters   = bundle.ui.activeSkipChapters;

      if (chapters.isEmpty) return const SizedBox.shrink();

      return Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: panelOpen || isDragging ? 0.0 : 1.0,
          child: IgnorePointer(
            ignoring: panelOpen || isDragging,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isFs ? 28.0 : 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: OP (эсвэл эхний chapter)
                  _buildButton(chapters.first, isFs),
                  // Right side: ED (хоёр дахь chapter байвал)
                  if (chapters.length > 1)
                    _buildButton(chapters[1], isFs)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildButton(SenzuChapter chapter, bool isFullscreen) {
    // label() null бол fallback
    final label = chapter.label ?? 'Skip';
    return _SkipButton(
      label: 'Skip $label',
      isFullscreen: isFullscreen,
      onTap: () => bundle.ui.skipChapter(chapter),
    );
  }
}


class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.label,
    required this.isFullscreen,
    required this.onTap,
  });
  final String label;
  final bool isFullscreen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isFullscreen ? 16 : 10,
            vertical: isFullscreen ? 10 : 5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF00CA13),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isFullscreen ? 16 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}


class SeekDragTooltipWithChapter extends StatelessWidget {
  const SeekDragTooltipWithChapter({
    super.key,
    required this.bundle,
    required this.style,
    required this.chapters,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final List<SenzuChapter> chapters;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDragging = bundle.playback.isDragging.value;
      if (!isDragging) return const SizedBox.shrink();

      final dur        = bundle.playback.duration.value;
      final posR       = bundle.playback.dragRatio.value;
      final displayPos = dur * posR;

      return Positioned.fill(
        child: IgnorePointer(
          child: Stack(
            children: [
              // Existing thumbnail / time tooltip
              bundle.core.activeSource?.thumbnailSprite != null
                  ? SeekThumbnail(
                      position: displayPos,
                      sprite: bundle.core.activeSource!.thumbnailSprite!,
                      style: style.progressBarStyle,
                    )
                  : Tooltips(
                      position: displayPos,
                      style: style.progressBarStyle,
                    ),

              // Chapter name overlay (chapters байвал)
              if (chapters.isNotEmpty)
                SenzuChapterTooltip(
                  position: displayPos,
                  chapters: chapters,
                  style: style.progressBarStyle,
                ),
            ],
          ),
        ),
      );
    });
  }
}

class SenzuChapterTooltip extends StatelessWidget {
  const SenzuChapterTooltip({
    super.key,
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
    if (chapter == null || chapter.label == null) return const SizedBox.shrink();

    return Align(
      alignment: const Alignment(0, -0.85),
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
            fontSize: 11,
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