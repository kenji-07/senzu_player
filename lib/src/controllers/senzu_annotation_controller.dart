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

  @override
  void onInit() {
    super.onInit();
    ever(playback.position, _updateAnnotations);
  }

  void _updateAnnotations(Duration pos) {
    final active = annotations.where((a) =>
      pos >= a.appearAt && pos < a.disappearAt,
    ).toList();
    // Өөрчлөгдсөн үед л update хийнэ
    if (active.length != activeAnnotations.length ||
        !active.every(activeAnnotations.contains)) {
      activeAnnotations.value = active;
    }
  }
}