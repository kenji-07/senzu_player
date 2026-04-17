import 'package:get/get.dart';
import 'package:senzu_player/src/platform/senzu_native_video_state.dart';
import 'senzu_core_controller.dart';

class SenzuPlaybackController extends GetxController {
  SenzuPlaybackController({required this.core});

  final SenzuCoreController core;

  // ── Rx observables ─────────────────────────────────────────────────────────
  final position          = Duration.zero.obs;
  final duration          = Duration.zero.obs;
  final maxBuffering      = Duration.zero.obs;
  final isPlaying         = false.obs;
  final isBuffering       = false.obs;
  final isDragging        = false.obs;
  final dragRatio         = 0.0.obs;
  final bufferHealthRatio = 1.0.obs;

  @override
  void onInit() {
    super.onInit();
    ever(core.rxNativeState, _onState);

    // Apply current state if already initialized
    final current = core.rxNativeState.value;
    if (current.isInitialized) _onState(current);
  }

  // ── State handler ──────────────────────────────────────────────────────────
  void _onState(SenzuNativeVideoState state) {
    // Position (range-adjusted, relative to beginRange)
    final begin  = core.beginRange;
    final rel    = state.position - begin;
    final newPos = rel < Duration.zero ? Duration.zero : rel;
    if (position.value != newPos) position.value = newPos;

    // Duration (range-adjusted)
    final end        = core.endRange;
    final rawDur     = end - begin;
    final clampedDur = rawDur < Duration.zero ? Duration.zero : rawDur;
    if (duration.value != clampedDur) duration.value = clampedDur;

    // isPlaying
    if (isPlaying.value != state.isPlaying) isPlaying.value = state.isPlaying;

    // isBuffering — not updated while dragging
    if (!isDragging.value && isBuffering.value != state.isBuffering) {
      isBuffering.value = state.isBuffering;
    }

    // maxBuffering — largest buffered end position
    Duration newMax = Duration.zero;
    for (final r in state.buffered) {
      if (r.end > newMax) newMax = r.end;
    }
    if (maxBuffering.value != newMax) maxBuffering.value = newMax;
  }

  // ── ABR buffer health ──────────────────────────────────────────────────────
  void updateBufferHealth(double ratio) {
    bufferHealthRatio.value = ratio.clamp(0.0, 1.0);
  }

  // ── Drag ──────────────────────────────────────────────────────────────────
  void setDragging(bool v) => isDragging.value = v;

  @override
  void onClose() {
    super.onClose();
  }
}