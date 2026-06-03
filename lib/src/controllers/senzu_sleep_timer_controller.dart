import 'dart:async';
import 'package:get/get.dart';

import 'package:senzu_player/src/controllers/senzu_core_controller.dart';
import 'package:senzu_player/src/controllers/senzu_device_controller.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';

class SenzuSleepTimerController extends GetxController {
  SenzuSleepTimerController({required this.core, required this.device});
  final SenzuCoreController core;
  final SenzuDeviceController device;

  final remainingTime = Rxn<Duration>();
  final isActive = false.obs;
  final isSleeping = false.obs;

  Timer? _timer;
  Timer? _fadeTimer;

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

    _fadeTimer?.cancel();
    int elapsedMs = 0;
    const durationMs = 3000;
    const intervalMs = 50;

    _fadeTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) async {
      elapsedMs += intervalMs;
      if (elapsedMs >= durationMs) {
        timer.cancel();
        _fadeTimer = null;
        device.volume.value = 0.0;
        device.brightness.value = 0.0;
        await SenzuNativeChannel.setVolume(0.0);
        await SenzuNativeChannel.setBrightness(0.0);
        isSleeping.value = true;
        return;
      }

      final t = elapsedMs / durationMs;
      final tCurved = t * t; // ease-in curve approximation
      final vol = (_savedVolume * (1 - tCurved)).clamp(0.0, 1.0);
      final bri = (_savedBrightness * (1 - tCurved)).clamp(0.0, 1.0);

      device.volume.value = vol;
      device.brightness.value = bri;
      await SenzuNativeChannel.setVolume(vol);
      await SenzuNativeChannel.setBrightness(bri);
    });

    // force pause
    await core.pause();
  }

  Future<void> cancel() async {
    _fadeTimer?.cancel();
    _fadeTimer = null;

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
    _fadeTimer?.cancel();
    super.onClose();
  }
}
