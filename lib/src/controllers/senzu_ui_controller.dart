import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'senzu_core_controller.dart';
import 'senzu_playback_controller.dart';

import 'package:senzu_player/src/platform/senzu_native_channel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuUIController
//
// Single responsibility:
//   • Overlay show/hide + auto-hide timer
//   • Lock screen toggle
//   • Panel toggle (quality / speed / caption …)
//   • Skip OP / ED button visibility
//   • Aspect ratio cycling
//   • isShowingThumbnail
//   • Notification on/off toggle
// ─────────────────────────────────────────────────────────────────────────────

enum SenzuPanel {
  caption,
  quality,
  speed,
  episode,
  aspect,
  audio,
  settings,
  sleep,
  none,
}

class SenzuUIController extends GetxController {
  SenzuUIController({required this.core, required this.playback});

  final SenzuCoreController core;
  final SenzuPlaybackController playback;

  // ── Rx ────────────────────────────────────────────────────────────────────
  final isShowingOverlay = true.obs;
  final isLocked = false.obs;

  /// True until the first frame is played after initialize.
  /// Hidden by watching isPlaying transition false→true.
  final isShowingThumbnail = true.obs;
  final activePanel = SenzuPanel.none.obs;
  final currentAspect = BoxFit.cover.obs;
  final showSkipOp = false.obs;
  final showSkipEd = false.obs;

  // ── Private ────────────────────────────────────────────────────────────────
  static const _overlayMs = 2800;
  Timer? _overlayTimer;
  bool _thumbnailDismissed = false;

  // Throttle: skip button update-ийг 500ms-д нэг удаа хязгаарлана

  Duration _lastSkipPos = Duration.zero;

  @override
  void onInit() {
    super.onInit();

    ever(playback.isPlaying, _onPlayingChanged);
    ever(playback.isDragging, _onDragging);
    ever(core.rxActiveSource, _onSourceChanged);

    // Throttled skip button update — 500ms interval
    // ever() биш interval worker ашиглана
    _startSkipWorker();

    setNotificationEnabled(core.notification);
  }

  void _startSkipWorker() {
    // Position reactive-г сонсох биш polling timer ашиглана
    // Учир нь: ever(position) = 200ms тутам, timer = 500ms тутам
    Timer.periodic(const Duration(milliseconds: 500), (t) {
      final pos = playback.position.value;
      // dirty check — position 500ms дотор өөрчлөгдөөгүй бол skip
      if (pos == _lastSkipPos) return;
      _lastSkipPos = pos;
      _updateSkipButtons(pos);
    });
  }

  // ── Skip OP / ED ───────────────────────────────────────────────────────────

  void _updateSkipButtons(Duration pos) {
    // Бүх comparison нэг pass-д хийнэ — branch prediction friendly
    final opShow =
        core.opEnd > Duration.zero &&
        pos.inMilliseconds >= core.opStart.inMilliseconds &&
        pos.inMilliseconds < core.opEnd.inMilliseconds;

    final edShow =
        core.edEnd > Duration.zero &&
        pos.inMilliseconds >= core.edStart.inMilliseconds &&
        pos.inMilliseconds < core.edEnd.inMilliseconds;

    // Rx update нь зөвхөн state өөрчлөгдсөн үед
    if (showSkipOp.value != opShow) showSkipOp.value = opShow;
    if (showSkipEd.value != edShow) showSkipEd.value = edShow;
  }

  void _onDragging(bool dragging) {
    if (dragging) {
      isShowingOverlay.value = true;
      _cancelOverlay();
    } else {
      if (playback.isPlaying.value) _scheduleOverlay();
    }
  }

  void _onSourceChanged(_) {
    _thumbnailDismissed = false;
    isShowingThumbnail.value = true;
    _lastSkipPos = Duration.zero;
  }

  // ── Thumbnail logic ────────────────────────────────────────────────────────
  // Dismissed once when isPlaying first becomes true (first real frame rendered)
  void _onPlayingChanged(bool playing) {
    if (playing) {
      if (!_thumbnailDismissed) {
        _thumbnailDismissed = true;
        isShowingThumbnail.value = false;
      }
      if (isShowingOverlay.value && _overlayTimer == null) {
        _scheduleOverlay();
      }
    } else {
      if (!playback.isDragging.value) _cancelOverlay();
    }
  }

  // ── Overlay ────────────────────────────────────────────────────────────────
  void showAndHideOverlay([bool? show]) {
    if (activePanel.value != SenzuPanel.none) {
      activePanel.value = SenzuPanel.none;
      return;
    }
    isShowingOverlay.value = show ?? !isShowingOverlay.value;
    if (isShowingOverlay.value) {
      _cancelOverlay();
      if (playback.isPlaying.value) _scheduleOverlay();
    }
  }

  void _scheduleOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: _overlayMs), () {
      if (playback.isPlaying.value) isShowingOverlay.value = false;
      _overlayTimer = null;
    });
  }

  void _cancelOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
  }

  // ── Panel ──────────────────────────────────────────────────────────────────
  void togglePanel(SenzuPanel panel) {
    activePanel.value = activePanel.value == panel ? SenzuPanel.none : panel;
  }

  // ── Lock ───────────────────────────────────────────────────────────────────
  Future<void> toggleLock() async {
    isLocked.value = !isLocked.value;
    HapticFeedback.lightImpact();
    if (isLocked.value) {
      await SenzuNativeChannel.enableWakelock();
    } else {
      await SenzuNativeChannel.disableWakelock();
    }
  }

  // ── Aspect ─────────────────────────────────────────────────────────────────
  void setAspect(BoxFit fit) => currentAspect.value = fit;

  // ── Notification on/off ────────────────────────────────────────────────────
  Future<void> setNotificationEnabled(bool enabled) async {
    if (enabled) {
      await SenzuNativeChannel.setNowPlayingEnabled(true);
    } else {
      await SenzuNativeChannel.setNowPlayingEnabled(false);
    }
  }

  void skipOp() {
    core.seekTo(core.opEnd);
    showSkipOp.value = false;
  }

  void skipEd() {
    core.seekTo(core.edEnd);
    showSkipEd.value = false;
  }

  @override
  void onClose() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    super.onClose();
  }
}
