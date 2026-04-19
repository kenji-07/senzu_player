import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'senzu_core_controller.dart';
import 'senzu_playback_controller.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';

enum SenzuPanel {
  caption,
  quality,
  speed,
  episode,
  aspect,
  audio,
  settings,
  sleep,
  cast,
  none,
}

class SenzuUIController extends GetxController {
  SenzuUIController({required this.core, required this.playback});

  final SenzuCoreController core;
  final SenzuPlaybackController playback;

  // ── Rx ────────────────────────────────────────────────────────────────────
  final isShowingOverlay = true.obs;
  final isLocked = false.obs;
  final isShowingThumbnail = true.obs;
  final activePanel = SenzuPanel.none.obs;
  final currentAspect = BoxFit.contain.obs;

  final activeSkipChapters = RxList<SenzuChapter>([]);

  // ── Private ────────────────────────────────────────────────────────────────
  static const _overlayMs = 2800;
  Timer? _overlayTimer;
  Timer? _skipWorkerTimer;
  bool _thumbnailDismissed = false;
  bool? _lastNotificationEnabled;
  Duration _lastSkipPos = Duration.zero;

  List<SenzuChapter> _chapters = const [];
  List<SenzuChapter> _skippableChapters = const [];

  // ─────────────────────────────────────────────────────────────────────────
  void setChapters(List<SenzuChapter> chapters) {
    _chapters = chapters;
    _skippableChapters = chapters.where((c) => c.isSkippable).toList();
    activeSkipChapters.clear();
    _lastSkipPos = Duration.zero;

    if (_skippableChapters.isNotEmpty) {
      _startSkipWorker();
    } else {
      _skipWorkerTimer?.cancel();
      _skipWorkerTimer = null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(playback.isPlaying, _onPlayingChanged);
    ever(playback.isDragging, _onDragging);
    ever(core.rxActiveSource, _onSourceChanged);
    setNotificationEnabled(core.notification);
  }

  void _startSkipWorker() {
    _skipWorkerTimer?.cancel();
    _skipWorkerTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final pos = playback.position.value;
      if (pos == _lastSkipPos) return;
      _lastSkipPos = pos;
      _updateSkipButtons(pos);
    });
  }

  // ── Skip chapters ──────────────────────────────────────────────────────────

  void _updateSkipButtons(Duration pos) {
    if (_skippableChapters.isEmpty) return;
    final posMs = pos.inMilliseconds;

    final active = <SenzuChapter>[];
    for (final chapter in _skippableChapters) {
      final startMs = chapter.startMs;
      final endMs = chapter.skipToMs ?? _nextChapterStartMs(chapter);
      if (endMs == null) continue;
      if (posMs >= startMs && posMs < endMs) {
        active.add(chapter);
      }
    }

    final changed =
        active.length != activeSkipChapters.length ||
        active.any((c) => !activeSkipChapters.contains(c));
    if (changed) activeSkipChapters.value = active;
  }

  int? _nextChapterStartMs(SenzuChapter chapter) {
    final idx = _chapters.indexOf(chapter);
    if (idx < 0 || idx + 1 >= _chapters.length) return null;
    return _chapters[idx + 1].startMs;
  }

  void skipChapter(SenzuChapter chapter) {
    final targetMs = chapter.skipToMs ?? _nextChapterStartMs(chapter);
    if (targetMs == null) return;
    core.seekTo(Duration(milliseconds: targetMs));
    activeSkipChapters.remove(chapter);
  }

  void skipOp() {
    final op = activeSkipChapters.firstWhereOrNull((c) => c.title == 'OP');
    if (op != null) skipChapter(op);
  }

  void skipEd() {
    final ed = activeSkipChapters.firstWhereOrNull((c) => c.title == 'ED');
    if (ed != null) skipChapter(ed);
  }

  List<SenzuChapter> get chapters => _chapters;

  // ── Source change ──────────────────────────────────────────────────────────
  void _onSourceChanged(_) {
    _thumbnailDismissed = false;
    isShowingThumbnail.value = true;
    _lastSkipPos = Duration.zero;
    activeSkipChapters.clear();
  }

  // ── Dragging ───────────────────────────────────────────────────────────────
  void _onDragging(bool dragging) {
    if (dragging) {
      isShowingOverlay.value = true;
      _cancelOverlay();
    } else {
      if (playback.isPlaying.value) _scheduleOverlay();
    }
  }

  // ── Thumbnail ──────────────────────────────────────────────────────────────
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
    final desired = show ?? !isShowingOverlay.value;
    if (isShowingOverlay.value == desired && show != null) return;
    isShowingOverlay.value = desired;
    if (desired) {
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
    await HapticFeedback.lightImpact();
    if (isLocked.value) {
      await SenzuNativeChannel.enableWakelock();
    } else {
      await SenzuNativeChannel.disableWakelock();
    }
  }

  // ── Aspect ─────────────────────────────────────────────────────────────────
  void setAspect(BoxFit fit) => currentAspect.value = fit;

  // ── Notification ──────────────────────────────────────────────────────────
  Future<void> setNotificationEnabled(bool enabled) async {
    if (_lastNotificationEnabled == enabled) return;
    _lastNotificationEnabled = enabled;
    await SenzuNativeChannel.setNowPlayingEnabled(enabled);
  }

  @override
  void onClose() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    _skipWorkerTimer?.cancel();
    _skipWorkerTimer = null;
    super.onClose();
  }
}