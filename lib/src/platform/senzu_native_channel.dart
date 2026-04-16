import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'senzu_native_video_state.dart';

class SenzuNativeChannel {
  SenzuNativeChannel._();

  static const _method = MethodChannel('senzu_player/native');
  static const _event  = EventChannel('senzu_player/events');

  static StreamSubscription<dynamic>? _sub;

  static final _playbackCtrl = StreamController<SenzuNativeVideoState>.broadcast();
  static final _volumeCtrl   = StreamController<double>.broadcast();
  static final _batteryCtrl  = StreamController<Map<String, dynamic>>.broadcast();
  static final _remoteCtrl   = StreamController<Map<String, dynamic>>.broadcast();
  static final _pipCtrl      = StreamController<Map<String, dynamic>>.broadcast();

  static Stream<SenzuNativeVideoState> get playbackStream => _playbackCtrl.stream;
  static Stream<double>                get volumeStream   => _volumeCtrl.stream;
  static Stream<Map<String, dynamic>>  get batteryStream  => _batteryCtrl.stream;
  static Stream<Map<String, dynamic>>  get remoteStream   => _remoteCtrl.stream;
  static Stream<Map<String, dynamic>>  get pipStream      => _pipCtrl.stream;

  static void startListening() {
    _sub ??= _event.receiveBroadcastStream().listen((e) {
      final m = Map<String, dynamic>.from(e as Map);
      switch (m['type'] as String?) {
        case 'playback':
          try {
            _playbackCtrl.add(SenzuNativeVideoState.fromMap(m));
          } catch (err) {
            debugPrint('SenzuNativeChannel: playback parse error: $err');
          }
        case 'volume':
          _volumeCtrl.add((m['value'] as num).toDouble());
        case 'battery':
          _batteryCtrl.add(m);
        case 'remote':
          _remoteCtrl.add(m);
        case 'pip':
          _pipCtrl.add(m);
        default:
          break;
      }
    }, onError: (e) => debugPrint('SenzuNativeChannel error: $e'));
  }

  static void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  // ── Codec ─────────────────────────────────────────────────────────────────
  static Future<bool> checkCodecSupport(String codec) async =>
      (await _method.invokeMethod<bool>('checkCodecSupport', {'codec': codec})) ?? false;

  // ── Low Latency ───────────────────────────────────────────────────────────
  static Future<void> setLowLatencyMode({required int targetMs}) =>
      _method.invokeMethod('setLowLatencyMode', {'targetMs': targetMs});

  static Future<int> getLiveLatency() async =>
      (await _method.invokeMethod<int>('getLiveLatency')) ?? -1;

  // ── Audio Tracks ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAudioTracks() async {
    final result = await _method.invokeMethod<List>('getAudioTracks');
    return result?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  }

  static Future<void> setAudioTrack(String trackId) =>
      _method.invokeMethod('setAudioTrack', {'trackId': trackId});

  // ── Network ───────────────────────────────────────────────────────────────
  static Future<String> getNetworkType() async =>
      (await _method.invokeMethod<String>('getNetworkType')) ?? 'unknown';

  // ── HDR ───────────────────────────────────────────────────────────────────
  static Future<bool> isHdrSupported() async =>
      (await _method.invokeMethod<bool>('isHdrSupported')) ?? false;

  static Future<void> enableHdrIfSupported() =>
      _method.invokeMethod('enableHdrIfSupported');

  // ── Secure ────────────────────────────────────────────────────────────────
  static Future<void> enableSecureMode()  => _method.invokeMethod('enableSecureMode');
  static Future<void> disableSecureMode() => _method.invokeMethod('disableSecureMode');

  // ── Wakelock ──────────────────────────────────────────────────────────────
  static Future<void> enableWakelock()  => _method.invokeMethod('enableWakelock');
  static Future<void> disableWakelock() => _method.invokeMethod('disableWakelock');

  // ── Volume ────────────────────────────────────────────────────────────────
  static Future<double> getVolume() async =>
      (await _method.invokeMethod<double>('getVolume')) ?? 1.0;
  static Future<void> setVolume(double v) =>
      _method.invokeMethod('setVolume', {'volume': v});

  // ── Brightness ────────────────────────────────────────────────────────────
  static Future<double> getBrightness() async =>
      (await _method.invokeMethod<double>('getBrightness')) ?? 0.5;
  static Future<void> setBrightness(double b) =>
      _method.invokeMethod('setBrightness', {'brightness': b});

  // ── Battery ───────────────────────────────────────────────────────────────
  static Future<int> getBatteryLevel() async =>
      (await _method.invokeMethod<int>('getBatteryLevel')) ?? -1;
  static Future<String> getBatteryState() async =>
      (await _method.invokeMethod<String>('getBatteryState')) ?? 'unknown';

  // ── Now Playing / Notification ────────────────────────────────────────────
  static Future<void> setNowPlayingMetadata({
    String title  = '',
    String artist = '',
    String? artwork,
    bool isLive   = false,
  }) =>
      _method.invokeMethod('setNowPlayingMetadata', {
        'title':   title,
        'artist':  artist,
        'artwork': artwork ?? '',
        'isLive':  isLive,
      });

  static Future<void> setNowPlayingEnabled(bool enabled) =>
      _method.invokeMethod('setNowPlayingEnabled', {'enabled': enabled});

  // ── Picture-in-Picture ────────────────────────────────────────────────────
  static Future<bool> isPipSupported() async =>
      (await _method.invokeMethod<bool>('isPipSupported')) ?? false;

  static Future<void> enablePip()  => _method.invokeMethod('enablePip');
  static Future<void> disablePip() => _method.invokeMethod('disablePip');
  static Future<void> enterPip()   => _method.invokeMethod('enterPip');
  static Future<void> exitPip()    => _method.invokeMethod('exitPip');
}