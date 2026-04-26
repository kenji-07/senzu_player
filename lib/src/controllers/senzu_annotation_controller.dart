import 'dart:async';
import 'package:get/get.dart';
import 'package:senzu_player/src/controllers/senzu_playback_controller.dart';
import 'package:senzu_player/src/data/models/senzu_annotation_model.dart';

class SenzuAnnotationController extends GetxController {
  SenzuAnnotationController({
    required this.playback,
    this.annotations = const [],
  });

  final SenzuPlaybackController playback;
  final List<SenzuAnnotation> annotations;

  final activeAnnotations = RxList<SenzuAnnotation>([]);

  late final List<_AnnotationEntry> _sorted;

  // Throttle: annotation-г 250ms-д нэг удаа шалгана
  Timer? _scanTimer;

  final Set<String> _activeIds = {};

  @override
  void onInit() {
    super.onInit();

    _sorted = annotations
        .map((a) => _AnnotationEntry(
              annotation: a,
              appearMs: a.appearAt.inMilliseconds,
              disappearMs: a.disappearAt.inMilliseconds,
            ))
        .toList()
      ..sort((a, b) => a.appearMs.compareTo(b.appearMs));

    // Annotation байхгүй бол timer эхлүүлэхгүй — CPU хэмнэнэ
    if (_sorted.isNotEmpty) {
      _startScanTimer();
    }
  }

  void _startScanTimer() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!playback.isPlaying.value) return;
      _scan(playback.position.value);
    });
  }

  void _scan(Duration pos) {
    final posMs = pos.inMilliseconds;

    final startIdx = _lowerBound(posMs);
    if (startIdx < 0) {
      _updateActive(const []);
      return;
    }

    final active = <SenzuAnnotation>[];
    for (int i = startIdx; i < _sorted.length; i++) {
      final e = _sorted[i];
      if (e.appearMs > posMs) break;
      if (e.disappearMs > posMs) {
        active.add(e.annotation);
      }
    }

    for (int i = startIdx - 1; i >= 0; i--) {
      final e = _sorted[i];
      if (e.disappearMs <= posMs) break;
      if (e.appearMs <= posMs) {
        active.add(e.annotation);
      }
    }

    _updateActive(active);
  }

  void _updateActive(List<SenzuAnnotation> newActive) {
    final newIds = newActive.map((a) => a.id).toSet();
    if (newIds.length == _activeIds.length &&
        newIds.every(_activeIds.contains)) {
      return;
    }
    _activeIds
      ..clear()
      ..addAll(newIds);
    activeAnnotations.value = newActive;
  }

  int _lowerBound(int posMs) {
    if (_sorted.isEmpty) return -1;
    int lo = 0, hi = _sorted.length - 1, result = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (_sorted[mid].appearMs <= posMs) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }

  @override
  void onClose() {
    _scanTimer?.cancel();
    super.onClose();
  }
}

class _AnnotationEntry {
  const _AnnotationEntry({
    required this.annotation,
    required this.appearMs,
    required this.disappearMs,
  });
  final SenzuAnnotation annotation;
  final int appearMs;
  final int disappearMs;
}
