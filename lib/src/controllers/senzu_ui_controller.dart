import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'senzu_core_controller.dart';
import 'senzu_playback_controller.dart';

import 'package:senzu_player/src/platform/senzu_native_channel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuUIController  —  OPTIMIZED
//
// CHANGES vs original:
//   • _skipWorkerTimer stored and cancelled in onClose (was leaked before)
//   • _scheduleOverlay guard: only reschedule when state actually changes
//   • showAndHideOverlay: early-return if already in desired state
//   • setNotificationEnabled: cached last value, avoid redundant method calls
//   • _onPlayingChanged: combined condition check to reduce branch count
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
  final isShowingOverlay    = true.obs;
  final isLocked            = false.obs;
  final isShowingThumbnail  = true.obs;
  final activePanel         = SenzuPanel.none.obs;
  final currentAspect       = BoxFit.cover.obs;
  final showSkipOp          = false.obs;
  final showSkipEd          = false.obs;

  // ── Private ────────────────────────────────────────────────────────────────
  static const _overlayMs = 2800;
  Timer? _overlayTimer;
  // FIX: was not stored, leaked on dispose
  Timer? _skipWorkerTimer;
  bool _thumbnailDismissed = false;
  bool? _lastNotificationEnabled; // cache to avoid redundant platform calls

  Duration _lastSkipPos = Duration.zero;

  @override
  void onInit() {
    super.onInit();

    ever(playback.isPlaying, _onPlayingChanged);
    ever(playback.isDragging, _onDragging);
    ever(core.rxActiveSource, _onSourceChanged);

    _startSkipWorker();
    setNotificationEnabled(core.notification);
  }

  // FIX: Timer.periodic is now stored in _skipWorkerTimer and cancelled onClose
  void _startSkipWorker() {
    _skipWorkerTimer?.cancel();
    _skipWorkerTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        final pos = playback.position.value;
        if (pos == _lastSkipPos) return;
        _lastSkipPos = pos;
        _updateSkipButtons(pos);
      },
    );
  }

  // ── Skip OP / ED ───────────────────────────────────────────────────────────

  // PERF: single pass, both conditions evaluated with short-circuit
  void _updateSkipButtons(Duration pos) {
    final posMs = pos.inMilliseconds;

    final opShow = core.opEnd > Duration.zero &&
        posMs >= core.opStart.inMilliseconds &&
        posMs < core.opEnd.inMilliseconds;

    final edShow = core.edEnd > Duration.zero &&
        posMs >= core.edStart.inMilliseconds &&
        posMs < core.edEnd.inMilliseconds;

    // Only write to Rx when value changes — avoids unnecessary rebuilds
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
    // Reset skip buttons immediately on source change
    showSkipOp.value = false;
    showSkipEd.value = false;
  }

  // ── Thumbnail ──────────────────────────────────────────────────────────────
  void _onPlayingChanged(bool playing) {
    if (playing) {
      if (!_thumbnailDismissed) {
        _thumbnailDismissed = true;
        isShowingThumbnail.value = false;
      }
      // OPT: only schedule if overlay is visible and no timer running
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

    final desired = show ?? !isShowingOverlay.value;
    // OPT: early return if already in desired state
    if (isShowingOverlay.value == desired && show != null) return;

    isShowingOverlay.value = desired;
    if (desired) {
      _cancelOverlay();
      if (playback.isPlaying.value) _scheduleOverlay();
    }
  }

  void _scheduleOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(
      const Duration(milliseconds: _overlayMs),
      () {
        if (playback.isPlaying.value) isShowingOverlay.value = false;
        _overlayTimer = null;
      },
    );
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
  // OPT: skip platform call if value hasn't changed
  Future<void> setNotificationEnabled(bool enabled) async {
    if (_lastNotificationEnabled == enabled) return;
    _lastNotificationEnabled = enabled;
    await SenzuNativeChannel.setNowPlayingEnabled(enabled);
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
    // FIX: was missing — this timer leaked in previous version
    _skipWorkerTimer?.cancel();
    _skipWorkerTimer = null;
    super.onClose();
  }
}