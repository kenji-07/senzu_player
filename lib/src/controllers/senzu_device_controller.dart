import 'dart:async';
import 'package:get/get.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';

class SenzuDeviceController extends GetxController {
  final volume       = 1.0.obs;
  final brightness   = 0.5.obs;
  final batteryLevel = 0.obs;
  final batteryState = 'unknown'.obs;
  final isMuted      = false.obs;
 
  double _volBeforeMute = 1.0;
  StreamSubscription<double>?               _volSub;
  StreamSubscription<Map<String, dynamic>>? _batSub;
 
  @override
  void onInit() {
    super.onInit();
    _volSub = SenzuNativeChannel.volumeStream.listen((v) {
      volume.value = v;
      if (isMuted.value && v > 0) isMuted.value = false;
    });
    _batSub = SenzuNativeChannel.batteryStream.listen((m) {
      batteryLevel.value = (m['level'] as num?)?.toInt() ?? batteryLevel.value;
      batteryState.value = (m['state'] as String?) ?? batteryState.value;
    });
    _initDevice();
  }
 
  Future<void> _initDevice() async {
    volume.value       = await SenzuNativeChannel.getVolume();
    brightness.value   = await SenzuNativeChannel.getBrightness();
    batteryLevel.value = await SenzuNativeChannel.getBatteryLevel();
    batteryState.value = await SenzuNativeChannel.getBatteryState();
  }
 
  Future<void> setVolume(double v) async {
    volume.value = v.clamp(0.0, 1.0);
    await SenzuNativeChannel.setVolume(volume.value);
    if (isMuted.value && v > 0) isMuted.value = false;
  }
 
  Future<void> toggleMute() async {
    if (isMuted.value) {
      isMuted.value = false;
      await setVolume(_volBeforeMute);
    } else {
      _volBeforeMute = volume.value;
      isMuted.value = true;
      await setVolume(0);
    }
  }
 
  Future<void> setBrightness(double b) async {
    brightness.value = b.clamp(0.0, 1.0);
    await SenzuNativeChannel.setBrightness(brightness.value);
  }
 
  @override
  void onClose() {
    _volSub?.cancel();
    _batSub?.cancel();
    super.onClose();
  }
}