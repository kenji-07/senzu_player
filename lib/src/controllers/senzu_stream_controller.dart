import 'dart:async';
import 'package:get/get.dart';
import 'package:senzu_player/src/platform/senzu_native_video_state.dart';
import 'senzu_core_controller.dart';
import 'senzu_playback_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuStreamController
//
// Single responsibility:
//   • Adaptive Bitrate (ABR) monitor — native state-с buffer ahead уншина
//   • DVR window + live edge tracking
// ─────────────────────────────────────────────────────────────────────────────

class SenzuStreamController extends GetxController {
  SenzuStreamController({
    required this.core,
    required this.playback,
    bool adaptiveBitrate = true,
    int minBufferSec = 10,
    int maxBufferSec = 30,
  }) {
    _abEnabled    = adaptiveBitrate;
    _minBufferSec = minBufferSec;
    _maxBufferSec = maxBufferSec;
  }

  final SenzuCoreController  core;
  final SenzuPlaybackController playback;

  // ── Rx ────────────────────────────────────────────────────────────────────
  final dvrWindowStart = Rxn<Duration>();
  final isAtLiveEdge   = true.obs;
  final liveEdge       = Duration.zero.obs;

  // ── ABR config ─────────────────────────────────────────────────────────────
  bool _abEnabled    = true;
  int  _minBufferSec = 10;
  int  _maxBufferSec = 30;

  static const _hysteresis = Duration(seconds: 5);
  DateTime? _lastQualitySwitch;

  Timer? _abTimer;

  @override
  void onInit() {
    super.onInit();
    // rxNativeState өөрчлөгдөхөд live edge шинэчилнэ
    ever(core.rxNativeState, _onState);
    // Source солигдоход ABR monitor дахин эхэлнэ
    core.onSourceChanged = (_) => _startAbMonitor();
    _startAbMonitor();
  }

  // ── Native state handler ───────────────────────────────────────────────────
  void _onState(SenzuNativeVideoState state) {
    if (!core.isLive) return;
    if (state.duration == Duration.zero) return;

    liveEdge.value = state.duration;
    final distFromEdge = liveEdge.value - state.position;
    isAtLiveEdge.value = distFromEdge.inSeconds < 10;
  }

  // ── ABR ────────────────────────────────────────────────────────────────────
  void _startAbMonitor() {
    _abTimer?.cancel();
    if (!_abEnabled) return;

    final srcs = core.rxSources.value;
    if (srcs == null || srcs.length <= 1) return;

    // Live stream-д ABR хийхгүй
    if (core.isLive) return;

    _abTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkBuffer(),
    );
  }

  void _checkBuffer() {
    final srcs = core.rxSources.value;
    if (srcs == null || srcs.length <= 1) return;

    final now = DateTime.now();
    if (_lastQualitySwitch != null &&
        now.difference(_lastQualitySwitch!) < _hysteresis) return;

    final state = core.rxNativeState.value;
    if (!state.isInitialized) return;

    final buf = _bufferedAhead(state);
    playback.updateBufferHealth((buf / _maxBufferSec).clamp(0.0, 1.0));

    if (buf < _minBufferSec && playback.isPlaying.value) {
      if (_switchQuality(-1)) {
        _lastQualitySwitch = now;
        core.onQualityChanged?.call(core.rxActiveSource.value ?? '');
      }
    } else if (buf > _maxBufferSec) {
      if (_switchQuality(1)) {
        _lastQualitySwitch = now;
        core.onQualityChanged?.call(core.rxActiveSource.value ?? '');
      }
    }
  }

  double _bufferedAhead(SenzuNativeVideoState state) {
    final pos = state.position;
    for (final r in state.buffered) {
      if (r.start <= pos && pos <= r.end) {
        return (r.end - pos).inSeconds.toDouble();
      }
    }
    return 0;
  }

  bool _switchQuality(int dir) {
    final srcs = core.rxSources.value!;
    final keys = srcs.keys.toList();
    final idx  = keys.indexOf(core.rxActiveSource.value ?? '');
    final next = idx - dir;
    if (next < 0 || next >= keys.length) return false;
    final src = srcs[keys[next]];
    if (src == null) return false;
    core.changeSource(name: keys[next], source: src, inheritPosition: true);
    return true;
  }

  @override
  void onClose() {
    _abTimer?.cancel();
    core.onSourceChanged = null;
    super.onClose();
  }
}