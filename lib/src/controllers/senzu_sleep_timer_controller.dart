import 'dart:async';
import 'package:flutter/animation.dart';
import 'package:get/get.dart';

import 'package:senzu_player/src/controllers/senzu_core_controller.dart';
import 'package:senzu_player/src/controllers/senzu_device_controller.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';

class SenzuSleepTimerController extends GetxController
    with GetSingleTickerProviderStateMixin {
  SenzuSleepTimerController({required this.core, required this.device});
  final SenzuCoreController core;
  final SenzuDeviceController device;

  final remainingTime = Rxn<Duration>();
  final isActive = false.obs;
  final isSleeping = false.obs;

  Timer? _timer;
  AnimationController? _fadeCtrl;
  Animation<double>? _fadeAnim;

  double _savedVolume = 1.0;
  double _savedBrightness = 1.0;

  void start(Duration duration) {
    _timer?.cancel();
    remainingTime.value = duration;
    isActive.value = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final rem = remainingTime.value;
      if (rem == null || rem.inSeconds <= 0) {
        await _onFinished();
        return;
      }
      remainingTime.value = rem - const Duration(seconds: 1);
    });
  }

  Future<void> _onFinished() async {
    stop();

    _savedVolume = device.volume.value;
    _savedBrightness = device.brightness.value;

    await core.pause();
    await SenzuNativeChannel.disableWakelock();

    _fadeCtrl?.dispose();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl!, curve: Curves.easeIn);

    _fadeCtrl!.addListener(() {
      final t = _fadeAnim!.value;
      final vol = (_savedVolume * (1 - t)).clamp(0.0, 1.0);
      final bri = (_savedBrightness * (1 - t)).clamp(0.0, 1.0);
      device.volume.value = vol;
      device.brightness.value = bri;
      SenzuNativeChannel.setVolume(vol);
      SenzuNativeChannel.setBrightness(bri);
    });

    _fadeCtrl!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        isSleeping.value = true;
      }
    });

    // force pause
    await core.pause();

    await _fadeCtrl!.forward();
  }

  Future<void> cancel() async {
    _fadeCtrl?.stop();
    _fadeCtrl?.dispose();
    _fadeCtrl = null;

    isSleeping.value = false;

    await device.setVolume(_savedVolume);
    await device.setBrightness(_savedBrightness);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    isActive.value = false;
    remainingTime.value = null;
  }

  @override
  void onClose() {
    _timer?.cancel();
    _fadeCtrl?.dispose();
    super.onClose();
  }
}
