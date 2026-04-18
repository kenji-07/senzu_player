import 'senzu_core_controller.dart';
import 'dart:developer';
import 'senzu_playback_controller.dart';
import 'senzu_subtitle_controller.dart';
import 'senzu_ad_controller.dart';
import 'senzu_stream_controller.dart';
import 'senzu_ui_controller.dart';
import 'senzu_device_controller.dart';
import 'senzu_annotation_controller.dart';
import 'senzu_sleep_timer_controller.dart';
import 'package:senzu_player/src/data/models/senzu_player_config.dart';
import 'package:senzu_player/src/data/models/senzu_token_provider.dart';
import 'package:senzu_player/src/data/models/senzu_watermark.dart';
import 'package:senzu_player/src/data/models/senzu_annotation_model.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';

class SenzuPlayerBundle {
  SenzuPlayerBundle._({
    required this.core,
    required this.playback,
    required this.subtitle,
    required this.ad,
    required this.stream,
    required this.ui,
    required this.device,
    required this.sleepTimer,
    required this.annotation,
  });

  final SenzuCoreController core;
  final SenzuPlaybackController playback;
  final SenzuSubtitleController subtitle;
  final SenzuAdController ad;
  final SenzuStreamController stream;
  final SenzuUIController ui;
  final SenzuDeviceController device;
  final SenzuSleepTimerController sleepTimer;
  final SenzuAnnotationController annotation;

  factory SenzuPlayerBundle.create({
    bool looping = false,
    bool adaptiveBitrate = true,
    int minBufferSec = 10,
    int maxBufferSec = 30,
    bool secureMode = false,
    bool notification = true,
    SenzuWatermark? watermark,
    void Function(String)? onQualityChanged,
    SenzuDataPolicy dataPolicy = const SenzuDataPolicy(),
    SenzuTokenConfig? tokenConfig,
    List<SenzuAnnotation> annotations = const [],
    SenzuCastController? castController,
  }) {
    final core = SenzuCoreController(
      looping: looping,
      secureMode: secureMode,
      watermark: watermark,
      onQualityChanged: onQualityChanged,
      dataPolicy: dataPolicy,
      tokenConfig: tokenConfig,
      notification: notification,
    );

    final playback = SenzuPlaybackController(core: core);
    final subtitle = SenzuSubtitleController(core: core, playback: playback);
    final ad = SenzuAdController(core: core, playback: playback);
    final stream = SenzuStreamController(
      core: core,
      playback: playback,
      adaptiveBitrate: adaptiveBitrate,
      minBufferSec: minBufferSec,
      maxBufferSec: maxBufferSec,
    );
    final ui = SenzuUIController(core: core, playback: playback);
    final device = SenzuDeviceController();
    final sleepTimer = SenzuSleepTimerController(core: core, device: device);

    final annotation = SenzuAnnotationController(
      playback: playback,
      annotations: annotations,
    );

    if (castController != null) {
      core.setCastController(castController);
    }

    core.isAdActiveCallback = () => ad.isAdActive.value;

    core.onInit();
    playback.onInit();
    subtitle.onInit();
    ad.onInit();
    stream.onInit();
    ui.onInit();
    annotation.onInit();
    sleepTimer.onInit();
    device.onInit();
    log('SENZU PLAYER BUNDLE CREATE');

    return SenzuPlayerBundle._(
      core: core,
      playback: playback,
      subtitle: subtitle,
      ad: ad,
      stream: stream,
      ui: ui,
      device: device,
      sleepTimer: sleepTimer,
      annotation: annotation,
    );
  }

  void dispose() {
    log('SENZU PLAYER BUNDLE DESPOSE');
    device.onClose();
    ui.onClose();
    stream.onClose();
    ad.onClose();
    subtitle.onClose();
    playback.onClose();
    core.onClose();
    sleepTimer.onClose();
    annotation.onClose();
  }
}
