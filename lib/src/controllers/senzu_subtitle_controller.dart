import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/data/models/subtitle_model.dart';
import 'senzu_core_controller.dart';
import 'senzu_playback_controller.dart';

class SenzuSubtitleController extends GetxController {
  SenzuSubtitleController({
    required this.core,
    required this.playback,
  });

  final SenzuCoreController core;
  final SenzuPlaybackController playback;

  // ── Rx ────────────────────────────────────────────────────────────────────
  final subtitleSize = 23.obs;
  final activeCaption = RxnString();

  // ── ValueNotifier — widget rebuilds on subtitle change ──────────────────
  final currentSubtitle = ValueNotifier<SubtitleData?>(null);

  // ── Private ────────────────────────────────────────────────────────────────
  final Map<String, List<SubtitleData>> _cache = {};
  List<SubtitleData> _activeSubs = [];
  SubtitleData? _lastFound;

  @override
  void onInit() {
    super.onInit();

    ever(playback.position, _onPosition);

    ever(core.rxActiveSource, (_) {
      _lastFound = null;
      currentSubtitle.value = null;
    });

    core.onSubtitleChangeRequested = (subtitle, name) {
      changeSubtitle(subtitle: subtitle as SenzuPlayerSubtitle?, name: name);
    };
  }

  // ── Position → subtitle lookup ─────────────────────────────────────────────
  void _onPosition(Duration pos) {
    if (_activeSubs.isEmpty) return;
    final found = _binarySearch(_activeSubs, pos);
    if (found != _lastFound) {
      _lastFound = found;
      currentSubtitle.value = found;
    }
  }

  // ── O(log n) binary search ────────────────────────────────────────────────
  SubtitleData? _binarySearch(List<SubtitleData> subs, Duration pos) {
    int lo = 0, hi = subs.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final s = subs[mid];
      if (pos < s.start) {
        hi = mid - 1;
      } else if (pos > s.end) {
        lo = mid + 1;
      } else {
        return s;
      }
    }
    return null;
  }

  // ── Subtitle change ────────────────────────────────────────────────────────
  Future<void> changeSubtitle({
    required SenzuPlayerSubtitle? subtitle,
    required String name,
  }) async {
    activeCaption.value = name;
    _lastFound = null;
    currentSubtitle.value = null;

    if (subtitle == null) {
      _activeSubs = [];
      return;
    }

    // Use cache if available
    if (_cache.containsKey(name)) {
      _activeSubs = _cache[name]!;
      return;
    }

    await subtitle.initialize();

    // Sort for binary search correctness
    final sorted = List<SubtitleData>.from(subtitle.subtitles)
      ..sort((a, b) => a.start.compareTo(b.start));

    _cache[name] = sorted;
    _activeSubs = sorted;
  }

  void setSubtitleSize(int size) => subtitleSize.value = size;

  void clearCache() => _cache.clear();

  @override
  void onClose() {
    _activeSubs = [];
    currentSubtitle.dispose();
    core.onSubtitleChangeRequested = null;
    super.onClose();
  }
}
