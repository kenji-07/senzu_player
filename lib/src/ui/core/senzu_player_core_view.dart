import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:senzu_player/src/ui/widgets/senzu_video_surface.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/ui/overlay/senzu_overlay_bottom.dart';
import 'package:senzu_player/src/ui/overlay/senzu_overlay_top.dart';
import 'package:senzu_player/src/ui/settings/senzu_panels.dart';
import 'package:senzu_player/src/ui/widgets/senzu_cellular_warning.dart';
import 'package:senzu_player/src/ui/widgets/senzu_buffer_loader.dart';
import 'package:senzu_player/src/ui/widgets/senzu_watermark_overlay.dart';
import 'package:senzu_player/src/ui/widgets/senzu_progress_bar.dart';
// import 'package:senzu_player/src/ui/widgets/transitions.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/data/models/subtitle_model.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuPlayerCoreView
// ─────────────────────────────────────────────────────────────────────────────

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
      enableEpisode;

  @override
  State<SenzuPlayerCoreView> createState() => _SenzuPlayerCoreViewState();
}

class _SenzuPlayerCoreViewState extends State<SenzuPlayerCoreView> {
  SenzuPlayerBundle get bundle => widget.bundle;
  SenzuPlayerStyle get style => widget.style ?? SenzuPlayerStyle();
  SenzuMetaData get meta => widget.meta ?? SenzuMetaData();

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

  // ── Scale ──────────────────────────────────────────────────────────────────
  double _scale = 1.0;

  final _transformCtrl = TransformationController();

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

      return Stack(
        children: [
          // ── AdDisplayContainer ALWAYS in tree (IMA-д шаардлагатай) ──
          Obx(() {
            final container = bundle.ad.adDisplayContainer.value;
            final adVisible =
                bundle.ad.isAdInitializing.value || bundle.ad.isAdLoaded.value;
            if (container == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: Opacity(
                opacity: adVisible ? 1.0 : 0.0,
                child: IgnorePointer(ignoring: !adVisible, child: container),
              ),
            );
          }),

          // ── Content video (ad дуусмагц эсвэл ad байхгүй үед) ──
          if (!bundle.ad.isAdLoaded.value &&
                  !bundle.ad.isAdInitializing.value ||
              bundle.ad.shouldShowContentVideo.value)
            _buildMainPlayer(),

          // ── Ad loading spinner (container дэлгэц дээр байхад) ──
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
                        style: TextStyle(color: Colors.white54, fontSize: 11),
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

  // ── Main player ────────────────────────────────────────────────────────────

  Widget _buildMainPlayer() {
    return Obx(() {
      final panelOpen = bundle.ui.activePanel.value != SenzuPanel.none;

      return GestureDetector(
        onLongPress: panelOpen ? null : _onLongPress,
        onLongPressUp: panelOpen ? null : _onLongPressUp,
        onVerticalDragStart: (panelOpen || !bundle.core.isFullScreen.value)
            ? null
            : _onDragStart,
        onVerticalDragUpdate: (panelOpen || !bundle.core.isFullScreen.value)
            ? null
            : _onDragUpdate,
        onVerticalDragEnd: (panelOpen || !bundle.core.isFullScreen.value)
            ? null
            : _onDragEnd,
        child: Stack(
          children: [
            // 1. Video frame
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 1.0,
                maxScale: 3.0,
                panEnabled: _scale > 1.05,
                onInteractionUpdate: (d) {
                  if (d.pointerCount >= 2) {
                    setState(() {
                      _scale = _transformCtrl.value.getMaxScaleOnAxis();
                    });
                  }
                },
                onInteractionEnd: (details) {
                  final scale = _transformCtrl.value.getMaxScaleOnAxis();

                  if (scale <= 1.01) {
                    HapticFeedback.lightImpact();
                  }
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
                  opacity: bundle.ui.isShowingOverlay.value ? 1.0 : 0.0,
                  child: Container(color: const Color(0x99000000)),
                ),
              ),
            ),

            // 3.2. Annotations
            Obx(
              () => Stack(
                children: bundle.annotation.activeAnnotations
                    .map(
                      (a) => Align(
                        alignment: a.alignment,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: GestureDetector(
                            onTap: a.onTap,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: 1.0,
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
                      ),
                    )
                    .toList(),
              ),
            ),

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
                        onDoubleTap: () => _doubleTap(rewind: true),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 3,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => bundle.ui.showAndHideOverlay(),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => bundle.ui.showAndHideOverlay(),
                        onDoubleTap: () => _doubleTap(rewind: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Panel-sensitive UI: AnimatedOpacity + IgnorePointer ──
            // if(!panelOpen) хасаж, animation-тай болгосон

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
                        showRewind: _showRewind,
                        showForward: _showForward,
                        rewindCount: _rewindCount,
                        forwardCount: _forwardCount,
                        onPrev: style.onPrevEpisode,
                        onNext: style.onNextEpisode,
                      ),
                    ),
                  ),
                );
              }),

            // 6. Skip OP / ED
            if (!bundle.ui.isLocked.value)
              Obx(() {
                final isFs = bundle.core.isFullScreen.value;
                final isDragging = bundle.playback.isDragging.value;
                return Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: panelOpen || isDragging ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: panelOpen,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isFs ? 28.0 : 12.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Obx(
                              () => AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: bundle.ui.showSkipOp.value ? 1.0 : 0.0,
                                child: IgnorePointer(
                                  ignoring: !bundle.ui.showSkipOp.value,
                                  child: _SkipButton(
                                    label: style.senzuLanguage.skipOp,
                                    isFullscreen: isFs,
                                    onTap: bundle.ui.skipOp,
                                  ),
                                ),
                              ),
                            ),
                            Obx(
                              () => AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: bundle.ui.showSkipEd.value ? 1.0 : 0.0,
                                child: IgnorePointer(
                                  ignoring: !bundle.ui.showSkipEd.value,
                                  child: _SkipButton(
                                    label: style.senzuLanguage.skipEd,
                                    isFullscreen: isFs,
                                    onTap: bundle.ui.skipEd,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

            // 6.1. Sleep timer badge
            Obx(() {
              if (!bundle.sleepTimer.isActive.value)
                return const SizedBox.shrink();
              final rem = bundle.sleepTimer.remainingTime.value;
              if (rem == null) return const SizedBox.shrink();
              return Positioned(
                top: 16,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: panelOpen ? 0.0 : 1.0,
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
                      ),
                    ),
                  ),
                );
              }),

            // 7.1 SeekThumbnail + tooltip
            Obx(() {
              final isDragging = bundle
                  .playback
                  .isDragging
                  .value; // ← энэ Obx-г subscribe хийнэ
              if (!isDragging) return const SizedBox.shrink();

              final dur = bundle.playback.duration.value;
              final posR = bundle.playback.dragRatio.value;
              final displayPos = dur * posR;

              return Positioned.fill(
                child: IgnorePointer(
                  child: bundle.core.activeSource?.thumbnailSprite != null
                      ? SeekThumbnail(
                          position: displayPos,
                          sprite: bundle.core.activeSource!.thumbnailSprite!,
                          style: style.progressBarStyle,
                        )
                      : Tooltips(
                          position: displayPos,
                          style: style.progressBarStyle,
                        ),
                ),
              );
            }),

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
                  opacity: showOverlay && !isDragging ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !showOverlay || isDragging,
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

            // 10. Side panels (panel-ийн гадна дарахад хаах invisible overlay)
            if (panelOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => bundle.ui.activePanel.value = SenzuPanel.none,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),

            if (widget.enableQuality) SenzuQualityPanel(bundle: bundle),
            if (widget.enableSpeed)
              SenzuSpeedPanel(bundle: bundle, style: style),
            if (widget.enableCaption)
              SenzuCaptionPanel(bundle: bundle, style: style),
            if (widget.enableAspect)
              SenzuAspectPanel(bundle: bundle, style: style),
            if (widget.enableAudio) SenzuAudioPanel(bundle: bundle),
            if (widget.enableEpisode && style.episodeWidget != null)
              SenzuEpisodePanel(bundle: bundle, child: style.episodeWidget!),
            SenzuSleepPanel(bundle: bundle),

            // 11. Volume/brightness toast
            Obx(
              () => IgnorePointer(
                child: _VBToast(
                  dragVol: _dragVol.value,
                  dragBri: _dragBri.value,
                ),
              ),
            ),

            // 12. 2× speed toast
            if (_longPress)
              const IgnorePointer(
                child: Align(
                  alignment: Alignment(0, -0.7),
                  child: _SpeedToast(),
                ),
              ),

            // 13. Buffer loader
            Obx(() {
              if (bundle.ad.activeAd.value != null)
                return const SizedBox.shrink();
              return SenzuBufferLoader(bundle: bundle, style: style);
            }),

            // Thumbnail
            Obx(
              () =>
                  bundle.ui.isShowingThumbnail.value &&
                      !bundle.core.isChangingSource.value
                  ? _Thumbnail(bundle: bundle, style: style)
                  : const SizedBox.shrink(),
            ),

            // 13.1. Watermark
            if (bundle.core.watermark != null)
              Positioned.fill(
                child: SenzuWatermarkOverlay(watermark: bundle.core.watermark!),
              ),

            // 14. Ad viewer
            _AdViewer(bundle: bundle, style: style),

            // 15. Status bar
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

            // 16. Cellular warning
            SenzuCellularWarning(bundle: bundle, style: style),

            // 17. Sleep overlay
            Obx(() {
              if (!bundle.sleepTimer.isSleeping.value)
                return const SizedBox.shrink();
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
                          const Text(
                            'Sleep mode activated',
                            style: TextStyle(
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  color: Colors.white60,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Continue watching',
                                  style: TextStyle(
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
            style: TextStyle(color: Colors.white, fontSize: 14),
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({required this.bundle, required this.aspectRatio});
  final SenzuPlayerBundle bundle;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => Obx(() {
    final state = bundle.core.rxNativeState.value;
    if (!state.isInitialized) return const ColoredBox(color: Colors.black);
    return SenzuVideoSurfaceWithFit(
      videoAspectRatio: aspectRatio,
      fit: bundle.ui.currentAspect.value,
    );
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
    // Өмнөх/дараагийн callback — null бол товч харуулахгүй
    this.onPrev,
    this.onNext,
  });

  final SenzuPlayerBundle bundle;
  final SenzuCenterButtonStyle style;
  final Widget loading, buffering;
  final bool showRewind, showForward;
  final int rewindCount, forwardCount;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Double-tap feedback
      if (showRewind) return _circle(_seekText('-${rewindCount * 10}s'));
      if (showForward) return _circle(_seekText('+${forwardCount * 10}s'));

      // Loading / buffering
      if (bundle.core.isChangingSource.value) return _circle(loading);
      if (bundle.playback.isBuffering.value) return _circle(buffering);

      final playing = bundle.playback.isPlaying.value;
      final ended =
          !bundle.core.isLiveRx.value &&
          bundle.playback.position.value >= bundle.playback.duration.value &&
          bundle.playback.duration.value > Duration.zero;

      // ── 3 товч: Өмнөх | Play/Pause/Replay | Дараагийн ──────────────────
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─ Өмнөх ─
          if (onPrev != null)
            _SideButton(
              icon: PhosphorIcons.skipBack(),
              onTap: onPrev!,
              size: style.circleSize * 0.55,
            )
          else
            SizedBox(width: style.circleSize * 0.55 + 8),

          const SizedBox(width: 16),

          // ─ Center ─
          GestureDetector(
            onTap: ended
                ? () => bundle.core.seekTo(Duration.zero)
                : bundle.core.playOrPause,
            child: _circle(
              ended ? style.replay : (playing ? style.pause : style.play),
            ),
          ),

          const SizedBox(width: 16),

          // ─ Дараагийн ─
          if (onNext != null)
            _SideButton(
              icon: PhosphorIcons.skipForward(),
              onTap: onNext!,
              size: style.circleSize * 0.55,
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

// ── Side button (жижиг дугуй товч) ───────────────────────────────────────────

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
      ),
      child: Icon(icon, color: Colors.white, size: size),
    ),
  );
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
          bundle.ui.isLocked.value
              ? PhosphorIcons.lock()
              : PhosphorIcons.lockOpen(),
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
    final remaining = (ad.durationToSkip - watched).inSeconds;
    final canSkip = watched >= ad.durationToSkip;
    final total = bundle.ad.totalAds.value;
    final current = bundle.ad.currentAdIndex;
    return ColoredBox(
      color: Colors.amber,
      child: Stack(
        children: [
          Positioned.fill(child: ad.child),
          Positioned(
            left: 0,
            bottom: 0,
            child:
                style.skipAdBuilder?.call(watched) ??
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
              child: Text(
                style.senzuLanguage.learnMore,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
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
