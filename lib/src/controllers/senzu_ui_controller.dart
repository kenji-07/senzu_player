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

  @override
  void onInit() {
    super.onInit();

    // Hide thumbnail when playback actually starts
    ever(playback.isPlaying, _onPlayingChanged);

    // Skip OP/ED buttons driven by position
    ever(playback.position, _updateSkipButtons);

    // Drag: show overlay, cancel timer; stop drag: reschedule if playing
    ever(playback.isDragging, (dragging) {
      if (dragging) {
        isShowingOverlay.value = true;
        _cancelOverlay();
      } else {
        if (playback.isPlaying.value) _scheduleOverlay();
      }
    });

    // When source changes, reset thumbnail state
    ever(core.rxActiveSource, (_) {
      _thumbnailDismissed = false;
      isShowingThumbnail.value = true;
    });

    setNotificationEnabled(core.notification);
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

  // ── Skip OP / ED ───────────────────────────────────────────────────────────
  void _updateSkipButtons(Duration pos) {
    final opShow =
        core.opEnd > Duration.zero && pos >= core.opStart && pos < core.opEnd;
    final edShow =
        core.edEnd > Duration.zero && pos >= core.edStart && pos < core.edEnd;
    if (showSkipOp.value != opShow) showSkipOp.value = opShow;
    if (showSkipEd.value != edShow) showSkipEd.value = edShow;
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
