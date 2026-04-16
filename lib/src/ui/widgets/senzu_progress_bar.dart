import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/data/models/senzu_thumbnail_sprite.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

class SenzuProgressBar extends StatefulWidget {
  const SenzuProgressBar({
    super.key,
    required this.style,
    required this.bundle,
    this.thumbnailSprite,
  });
  final SenzuProgressBarStyle style;
  final SenzuPlayerBundle bundle;
  final SenzuThumbnailSprite? thumbnailSprite;

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
                ],
              ),
            );
          }),
        );
      },
    );
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
