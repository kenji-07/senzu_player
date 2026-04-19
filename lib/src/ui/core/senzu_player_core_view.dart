import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:senzu_player/src/ui/widgets/senzu_video_surface.dart';
import 'package:senzu_player/src/ui/core/senzu_player_core_view_patches.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/ui/overlay/senzu_overlay_bottom.dart';
import 'package:senzu_player/src/ui/overlay/senzu_overlay_top.dart';
import 'package:senzu_player/src/ui/settings/senzu_panels.dart';
import 'package:senzu_player/src/ui/widgets/senzu_cellular_warning.dart';
import 'package:senzu_player/src/ui/widgets/senzu_buffer_loader.dart';
import 'package:senzu_player/src/ui/widgets/senzu_watermark_overlay.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/data/models/subtitle_model.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';
import 'package:senzu_player/src/cast/senzu_cast_service.dart';

class SenzuPlayerCoreView extends StatefulWidget {
  const SenzuPlayerCoreView({
    super.key,
    required this.bundle,
    required this.style,
    required this.meta,
    required this.enableCaption,
    required this.enableQuality,
    required this.enableAudio,
    required this.enableSpeed,
    required this.enableAspect,
    required this.enableFullscreen,
    required this.enablePip,
    required this.enableLock,
    required this.enableEpisode,
    required this.defaultAspectRatio,
    required this.enableSleep,
    this.chapters = const [],
    this.castController,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle? style;
  final SenzuMetaData? meta;
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
  State<SenzuPlayerCoreView> createState() => _SenzuPlayerCoreViewState();
}

class _SenzuPlayerCoreViewState extends State<SenzuPlayerCoreView> {
  SenzuPlayerBundle get bundle => widget.bundle;
  SenzuPlayerStyle get style => widget.style ?? SenzuPlayerStyle();
  SenzuMetaData get meta => widget.meta ?? const SenzuMetaData();

  // ── Double-tap seek ────────────────────────────────────────────────────────
  int _rewindCount = 0, _forwardCount = 0;
  bool _showRewind = false, _showForward = false;
  Timer? _rewindTimer, _forwardTimer;

  // ── Volume/brightness drag ─────────────────────────────────────────────────
  bool _dragLeft = false;
  final _dragVol = Rxn<double>();
  final _dragBri = Rxn<double>();

  // ── Long-press 2× speed ───────────────────────────────────────────────────
  bool _longPress = false;
  double _savedSpeed = 1.0;

  final _transformCtrl = TransformationController();
  double _scale = 1.0;

  @override
  void dispose() {
    _rewindTimer?.cancel();
    _forwardTimer?.cancel();
    _transformCtrl.dispose();
    super.dispose();
  }

  // ── Double-tap ─────────────────────────────────────────────────────────────
  void _doubleTap({required bool rewind}) {
    final offset = Duration(seconds: rewind ? -10 : 10);
    final isBuffering = bundle.core.rxNativeState.value.isBuffering;
    bundle.core.queueSeek(offset, isBuffering: isBuffering);

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

  // ── Drag volume / brightness ───────────────────────────────────────────────
  void _onDragStart(DragStartDetails d) {
    _dragLeft = d.localPosition.dx < (context.size?.width ?? 400) / 2;
    if (_dragLeft) {
      _dragBri.value = bundle.device.brightness.value;
    } else {
      _dragVol.value = bundle.device.volume.value;
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = -(d.primaryDelta! / (context.size?.height ?? 400));
    if (_dragLeft && _dragBri.value != null) {
      _dragBri.value = (_dragBri.value! + delta).clamp(0.0, 1.0);
      bundle.device.setBrightness(_dragBri.value!);
    } else if (!_dragLeft && _dragVol.value != null) {
      _dragVol.value = (_dragVol.value! + delta).clamp(0.0, 1.0);
      bundle.device.setVolume(_dragVol.value!);
    }
  }

  void _onDragEnd(DragEndDetails _) {
    _dragVol.value = null;
    _dragBri.value = null;
  }

  // ── Long press ─────────────────────────────────────────────────────────────
  void _onLongPress() {
    if (!bundle.playback.isPlaying.value) return;
    HapticFeedback.lightImpact();
    _savedSpeed = bundle.core.playbackSpeed;
    setState(() => _longPress = true);
    bundle.core.setPlaybackSpeed(2.0);
  }

  void _onLongPressUp() {
    bundle.core.setPlaybackSpeed(_savedSpeed);
    setState(() => _longPress = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (bundle.core.hasError.value) return _buildError();
      return _MainPlayerStack(
        bundle: bundle,
        style: style,
        meta: meta,
        widget: widget,
        dragVol: _dragVol,
        dragBri: _dragBri,
        longPress: _longPress,
        showRewind: _showRewind,
        showForward: _showForward,
        rewindCount: _rewindCount,
        forwardCount: _forwardCount,
        onDoubleTapLeft: () => _doubleTap(rewind: true),
        onDoubleTapRight: () => _doubleTap(rewind: false),
        onDragStart: _onDragStart,
        onDragUpdate: _onDragUpdate,
        onDragEnd: _onDragEnd,
        onLongPress: _onLongPress,
        onLongPressUp: _onLongPressUp,
        transformCtrl: _transformCtrl,
        onScaleUpdate: (s) => setState(() => _scale = s),
        scale: _scale,
        chapters: widget.chapters,
        castController: widget.castController,
      );
    });
  }

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() {
    final err = bundle.core.errorState.value;
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white60, size: 48),
          const SizedBox(height: 12),
          Text(
            style.senzuLanguage.failedToLoad,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          if (err != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                err.message,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
            ),
            onPressed: bundle.core.retrySource,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(style.senzuLanguage.retry),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MainPlayerStack
// ─────────────────────────────────────────────────────────────────────────────

class _MainPlayerStack extends StatelessWidget {
  const _MainPlayerStack({
    required this.bundle,
    required this.style,
    required this.meta,
    required this.widget,
    required this.dragVol,
    required this.dragBri,
    required this.longPress,
    required this.showRewind,
    required this.showForward,
    required this.rewindCount,
    required this.forwardCount,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onLongPress,
    required this.onLongPressUp,
    required this.transformCtrl,
    required this.onScaleUpdate,
    required this.scale,
    required this.chapters,
    required this.castController,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuMetaData meta;
  final SenzuPlayerCoreView widget;
  final Rxn<double> dragVol;
  final Rxn<double> dragBri;
  final bool longPress;
  final bool showRewind, showForward;
  final int rewindCount, forwardCount;
  final VoidCallback onDoubleTapLeft, onDoubleTapRight;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onLongPress, onLongPressUp;
  final TransformationController transformCtrl;
  final void Function(double) onScaleUpdate;
  final double scale;
  final List<SenzuChapter> chapters;
  final SenzuCastController? castController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final panelOpen = bundle.ui.activePanel.value != SenzuPanel.none;
      final adContainer = bundle.ad.adDisplayContainer.value;
      final adVisible =
          bundle.ad.isAdInitializing.value || bundle.ad.isAdLoaded.value;

      return Stack(
        children: [
          // ── AdDisplayContainer ─────────────────────────────────────────────
          if (adContainer != null)
            Positioned.fill(
              child: Opacity(
                opacity: adVisible ? 1.0 : 0.0,
                child: IgnorePointer(ignoring: !adVisible, child: adContainer),
              ),
            ),

          // ── Content video ──────────────────────────────────────────────────
          if (!bundle.ad.isAdLoaded.value &&
                  !bundle.ad.isAdInitializing.value ||
              bundle.ad.shouldShowContentVideo.value)
            _buildContentPlayer(panelOpen),

          // ── Ad loading spinner ─────────────────────────────────────────────
          if (bundle.ad.isAdInitializing.value)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: style.centerButtonStyle.circleSize,
                        height: style.centerButtonStyle.circleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: style.centerButtonStyle.circleColor,
                        ),
                        child: style.loading,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        style.senzuLanguage.adLoading,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildContentPlayer(bool panelOpen) {
    return GestureDetector(
      onLongPress: panelOpen ? null : onLongPress,
      onLongPressUp: panelOpen ? null : onLongPressUp,
      onVerticalDragStart: (panelOpen || !bundle.core.isFullScreen.value)
          ? null
          : onDragStart,
      onVerticalDragUpdate: (panelOpen || !bundle.core.isFullScreen.value)
          ? null
          : onDragUpdate,
      onVerticalDragEnd: (panelOpen || !bundle.core.isFullScreen.value)
          ? null
          : onDragEnd,
      child: Stack(
        children: [
          // 1. Video frame
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: transformCtrl,
              minScale: 1.0,
              maxScale: 3.0,
              panEnabled: scale > 1.05,
              onInteractionUpdate: (d) {
                if (d.pointerCount >= 2) {
                  onScaleUpdate(transformCtrl.value.getMaxScaleOnAxis());
                }
              },
              onInteractionEnd: (details) {
                final s = transformCtrl.value.getMaxScaleOnAxis();
                if (s <= 1.01) HapticFeedback.lightImpact();
              },
              child: _VideoFrame(
                bundle: bundle,
                aspectRatio: widget.defaultAspectRatio,
              ),
            ),
          ),

          // 2. Subtitle
          _SubtitleText(bundle: bundle, style: style.subtitleStyle),

          // 3. Overlay dim
          Obx(
            () => IgnorePointer(
              child: AnimatedOpacity(
                duration: style.transitions,
                opacity: bundle.ui.isShowingOverlay.value && !panelOpen
                    ? 1.0
                    : 0.0,
                child: Container(color: const Color(0x99000000)),
              ),
            ),
          ),

          // 3.2. Annotations
          Obx(() {
            return IgnorePointer(
              child: AnimatedOpacity(
                duration: style.transitions,
                opacity: bundle.ui.isShowingOverlay.value ? 0.0 : 1.0,
                child: Stack(
                  children: bundle.annotation.activeAnnotations
                      .map(
                        (a) => Align(
                          alignment: a.alignment,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: GestureDetector(
                              onTap: a.onTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  a.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            );
          }),

          // 4. Tap & double-tap zones
          Positioned.fill(
            child: IgnorePointer(
              ignoring: panelOpen,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => bundle.ui.showAndHideOverlay(),
                      onDoubleTap: onDoubleTapLeft,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(Get.context!).size.width / 3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => bundle.ui.showAndHideOverlay(),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => bundle.ui.showAndHideOverlay(),
                      onDoubleTap: onDoubleTapRight,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Center button
          if (!bundle.ui.isLocked.value)
            Obx(() {
              final loaderActive =
                  bundle.ui.isShowingThumbnail.value ||
                  (bundle.core.isChangingSource.value &&
                      bundle.playback.position.value == Duration.zero);
              final visible =
                  !panelOpen &&
                  !loaderActive &&
                  (bundle.ui.isShowingOverlay.value ||
                      bundle.core.isChangingSource.value ||
                      showRewind ||
                      showForward);
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
                    child: SenzuCenterControls(
                      bundle: bundle,
                      style: style.centerButtonStyle,
                      loading: style.loading,
                      buffering: Center(
                        child: RuntimeBufferingIndicator(
                          bufPercent: bufPercent,
                          style: style,
                        ),
                      ),
                      showRewind: showRewind,
                      showForward: showForward,
                      rewindCount: rewindCount,
                      forwardCount: forwardCount,
                      onPrev: style.onPrevEpisode,
                      onNext: style.onNextEpisode,
                    ),
                  ),
                ),
              );
            }),

          // 6. Skip OP / ED
          if (!bundle.ui.isLocked.value)
            SkipChapterButtons(
              bundle: bundle,
              style: style,
              panelOpen: panelOpen,
            ),

          // 6.1. Sleep timer badge
          Obx(() {
            if (!bundle.sleepTimer.isActive.value) {
              return const SizedBox.shrink();
            }
            final rem = bundle.sleepTimer.remainingTime.value;
            if (rem == null) return const SizedBox.shrink();
            return Positioned(
              top: bundle.core.isFullScreen.value ? 25 : 16,
              right: bundle.core.isFullScreen.value ? 25 : 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: panelOpen || bundle.ui.isShowingOverlay.value
                    ? 0.0
                    : 1.0,
                child: IgnorePointer(
                  ignoring: panelOpen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bedtime,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${rem.inMinutes}:${(rem.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // 7. Top overlay
          if (!bundle.ui.isLocked.value)
            Obx(() {
              final isDragging = bundle.playback.isDragging.value;
              return AnimatedOpacity(
                duration: style.transitions,
                opacity:
                    (bundle.ui.isShowingOverlay.value &&
                        !panelOpen &&
                        !isDragging)
                    ? 1.0
                    : 0.0,
                child: IgnorePointer(
                  ignoring:
                      !bundle.ui.isShowingOverlay.value ||
                      panelOpen ||
                      isDragging,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SenzuOverlayTop(
                      bundle: bundle,
                      style: style,
                      meta: meta,
                      enableCaption: widget.enableCaption,
                      enableQuality: widget.enableQuality,
                      enableSpeed: widget.enableSpeed,
                      enableAspect: widget.enableAspect,
                      castController: widget.castController,
                    ),
                  ),
                ),
              );
            }),

          // 7.1 SeekThumbnail + tooltip
          SeekDragTooltipWithChapter(
            bundle: bundle,
            style: style,
            chapters: chapters,
          ),

          // 8. Bottom overlay
          if (!bundle.ui.isLocked.value)
            Obx(
              () => AnimatedOpacity(
                duration: style.transitions,
                opacity: (bundle.ui.isShowingOverlay.value && !panelOpen)
                    ? 1.0
                    : 0.0,
                child: IgnorePointer(
                  ignoring: !bundle.ui.isShowingOverlay.value || panelOpen,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SenzuOverlayBottom(
                      bundle: bundle,
                      style: style,
                      enableFullscreen: widget.enableFullscreen,
                      enableEpisode: widget.enableEpisode,
                      enablePip: widget.enablePip,
                      chapters: chapters,
                    ),
                  ),
                ),
              ),
            ),

          // 9. Lock button
          if (widget.enableLock)
            Obx(() {
              final isLocked = bundle.ui.isLocked.value;
              final showOverlay = bundle.ui.isShowingOverlay.value;
              final isFs = bundle.core.isFullScreen.value;
              final isDragging = bundle.playback.isDragging.value;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showOverlay && !isDragging && !panelOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !showOverlay || isDragging || !panelOpen,
                  child: AnimatedAlign(
                    key: ValueKey(isLocked),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    alignment: isLocked
                        ? Alignment.bottomCenter
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: isLocked
                          ? EdgeInsets.only(bottom: isFs ? 40 : 12)
                          : EdgeInsets.only(left: isFs ? 28 : 12),
                      child: _LockButton(bundle: bundle),
                    ),
                  ),
                ),
              );
            }),

          // 10. Status bar
          Obx(
            () => bundle.core.isFullScreen.value
                ? Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _StatusBar(bundle: bundle),
                  )
                : const SizedBox.shrink(),
          ),

          // 11. Watermark
          if (bundle.core.watermark != null)
            Positioned.fill(
              child: SenzuWatermarkOverlay(watermark: bundle.core.watermark!),
            ),

          // 12. Panel close overlay
          if (panelOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => bundle.ui.activePanel.value = SenzuPanel.none,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

          // ── Panels ─────────────────────────────────────────────────────────
          if (widget.enableQuality)
            SenzuQualityPanel(bundle: bundle, style: style),
          if (widget.enableSpeed) SenzuSpeedPanel(bundle: bundle, style: style),
          if (widget.enableCaption)
            SenzuCaptionPanel(bundle: bundle, style: style),
          if (widget.enableAspect)
            SenzuAspectPanel(bundle: bundle, style: style),
          if (widget.enableAudio) SenzuAudioPanel(bundle: bundle, style: style),
          if (widget.enableEpisode && style.episodeWidget != null)
            SenzuEpisodePanel(bundle: bundle, style: style),
          if (widget.enableSleep) SenzuSleepPanel(bundle: bundle, style: style),

          // ── Cast panel ─────────────────────────────────────────────────────
          if (castController != null)
            SenzuCastPanel(
              bundle: bundle,
              style: style,
              castController: castController!,
            ),

          // 13. Volume/brightness toast
          Obx(
            () => IgnorePointer(
              child: _VBToast(dragVol: dragVol.value, dragBri: dragBri.value),
            ),
          ),

          // 14. 2× speed toast
          if (longPress)
            const IgnorePointer(
              child: Align(alignment: Alignment(0, -0.7), child: _SpeedToast()),
            ),

          // 15. Buffer loader
          Obx(() {
            if (bundle.ad.activeAd.value != null) {
              return const SizedBox.shrink();
            }
            return SenzuBufferLoader(bundle: bundle, style: style);
          }),

          // 16. Thumbnail
          Obx(
            () =>
                bundle.ui.isShowingThumbnail.value &&
                    !bundle.core.isChangingSource.value
                ? _Thumbnail(bundle: bundle, style: style)
                : const SizedBox.shrink(),
          ),

          // 17. Ad viewer
          _AdViewer(bundle: bundle, style: style),

          // 18. Cellular warning
          SenzuCellularWarning(bundle: bundle, style: style),

          // 19. Sleep overlay
          Obx(() {
            if (!bundle.sleepTimer.isSleeping.value) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: GestureDetector(
                onTap: () => bundle.sleepTimer.cancel(),
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bedtime,
                          color: Colors.white38,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          style.senzuLanguage.sleepModeActivated,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.touch_app,
                                color: Colors.white60,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                style.senzuLanguage.continueWatching,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({required this.bundle, required this.aspectRatio});
  final SenzuPlayerBundle bundle;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => Obx(() {
    final state = bundle.core.rxNativeState.value;
    final isChanging = bundle.core.isChangingSource.value;

    if (!state.isInitialized || isChanging) {
      return const ColoredBox(color: Colors.black);
    }

    final fit = bundle.ui.currentAspect.value;
    return SenzuVideoSurfaceWithFit(videoAspectRatio: aspectRatio, fit: fit);
  });
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText({required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuSubtitleStyle style;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubtitleData?>(
      valueListenable: bundle.subtitle.currentSubtitle,
      builder: (_, sub, __) {
        if (sub == null || sub.text.isEmpty) return const SizedBox.shrink();
        return Obx(() {
          final size =
              bundle.subtitle.subtitleSize.value.toDouble() *
              (bundle.core.isFullScreen.value ? 1.0 : 0.7);
          return Align(
            alignment: style.alignment,
            child: Padding(
              padding: style.padding,
              child: Text(
                sub.text,
                textAlign: style.textAlign,
                style: style.textStyle.copyWith(fontSize: size),
              ),
            ),
          );
        });
      },
    );
  }
}

class SenzuCenterControls extends StatelessWidget {
  const SenzuCenterControls({
    super.key,
    required this.bundle,
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

  final SenzuPlayerBundle bundle;
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
      if (showRewind) return _circle(_seekText('-${rewindCount * 10}s'));
      if (showForward) return _circle(_seekText('+${forwardCount * 10}s'));
      if (bundle.core.isChangingSource.value) return _circle(loading);
      if (bundle.playback.isBuffering.value) return _circle(buffering);

      final playing = bundle.playback.isPlaying.value;
      final ended =
          !bundle.core.isLiveRx.value &&
          bundle.playback.position.value >= bundle.playback.duration.value &&
          bundle.playback.duration.value > Duration.zero;

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
                ? () => bundle.core.seekTo(Duration.zero)
                : bundle.core.playOrPause,
            child: _circle(
              ended ? style.replay : (playing ? style.pause : style.play),
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
  Widget build(BuildContext context) {
    return GestureDetector(
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
}

class _LockButton extends StatelessWidget {
  const _LockButton({required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: bundle.ui.toggleLock,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
      ),
      child: Obx(
        () => Icon(
          bundle.ui.isLocked.value ? Icons.lock : Icons.lock_open,
          color: Colors.white,
          size: 20,
        ),
      ),
    ),
  );
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: style.transitions,
    opacity: bundle.ui.isShowingThumbnail.value ? 1.0 : 0.0,
    child: Stack(
      children: [
        if (style.thumbnail != null) Positioned.fill(child: style.thumbnail!),
        Center(
          child: GestureDetector(
            onTap: () async {
              await bundle.core.play();
              bundle.ui.showAndHideOverlay();
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              child: style.loading,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AdViewer extends StatelessWidget {
  const _AdViewer({required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => Obx(() {
    final ad = bundle.ad.activeAd.value;
    if (ad == null) return const SizedBox.shrink();

    final watched = bundle.ad.adTimeWatched.value ?? Duration.zero;
    final remaining = (ad.durationToSkip - watched).inSeconds.clamp(0, 999);
    final canSkip = watched >= ad.durationToSkip;
    final total = bundle.ad.totalAds.value;
    final current = bundle.ad.currentAdIndex;

    return Stack(
      children: [
        Positioned.fill(child: ad.child),
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Ad $current of $total',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: canSkip ? bundle.ad.skipAd : null,
            child:
                style.skipAdBuilder?.call(watched) ??
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    canSkip ? style.senzuLanguage.skipAd : '$remaining s',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.parse(ad.deepLink);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: Text(
              style.senzuLanguage.learnMore,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  });
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Spacer(),
          Text(
            '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Obx(
            () => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${bundle.device.batteryLevel.value}%',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                const SizedBox(width: 2),
                Icon(
                  _batIcon(
                    bundle.device.batteryLevel.value,
                    bundle.device.batteryState.value,
                  ),
                  color: bundle.device.batteryState.value == 'charging'
                      ? Colors.green
                      : Colors.white,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _batIcon(int l, String s) {
    if (s == 'charging') return Icons.battery_charging_full;
    if (l <= 14) return Icons.battery_0_bar;
    if (l <= 34) return Icons.battery_2_bar;
    if (l <= 54) return Icons.battery_3_bar;
    if (l <= 79) return Icons.battery_4_bar;
    return Icons.battery_full;
  }
}

class _VBToast extends StatelessWidget {
  const _VBToast({this.dragVol, this.dragBri});
  final double? dragVol, dragBri;

  @override
  Widget build(BuildContext context) {
    final v = dragVol ?? dragBri;
    if (v == null) return const SizedBox.shrink();
    final isVol = dragVol != null;
    return Align(
      alignment: const Alignment(0, -0.65),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVol
                  ? (v <= 0
                        ? Icons.volume_off
                        : v < 0.5
                        ? Icons.volume_down
                        : Icons.volume_up)
                  : (v <= 0
                        ? Icons.brightness_low
                        : v < 0.5
                        ? Icons.brightness_medium
                        : Icons.brightness_high),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: v,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedToast extends StatelessWidget {
  const _SpeedToast();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 20),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      '2× speed',
      style: TextStyle(color: Colors.white, fontSize: 13),
    ),
  );
}
