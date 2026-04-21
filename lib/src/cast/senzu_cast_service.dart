import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'senzu_cast_media_builder.dart';

enum SenzuCastState { notConnected, connecting, connected, noDevicesAvailable }

enum SenzuCastSessionState { idle, loading, playing, paused, buffering, error }

class SenzuCastDeviceInfo {
  const SenzuCastDeviceInfo({
    required this.deviceId,
    required this.deviceName,
    this.modelName = '',
  });
  final String deviceId;
  final String deviceName;
  final String modelName;

  factory SenzuCastDeviceInfo.fromMap(Map<dynamic, dynamic> m) =>
      SenzuCastDeviceInfo(
        deviceId: m['deviceId'] as String? ?? '',
        deviceName: m['deviceName'] as String? ?? 'Unknown',
        modelName: m['modelName'] as String? ?? '',
      );
}

class SenzuCastRemoteState {
  const SenzuCastRemoteState({
    this.sessionState = SenzuCastSessionState.idle,
    this.positionMs = 0,
    this.durationMs = 0,
    this.isPlaying = false,
    this.volume = 1.0,
    this.isMuted = false,
    this.errorMessage,
    this.activeTrackIds = const [],
  });

  final SenzuCastSessionState sessionState;
  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final double volume;
  final bool isMuted;
  final String? errorMessage;
  final List<int> activeTrackIds;

  factory SenzuCastRemoteState.fromMap(Map<dynamic, dynamic> m) =>
      SenzuCastRemoteState(
        sessionState: _parseSessionState(m['sessionState'] as String?),
        positionMs: (m['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        isPlaying: (m['isPlaying'] as bool?) ?? false,
        volume: (m['volume'] as num?)?.toDouble() ?? 1.0,
        isMuted: (m['isMuted'] as bool?) ?? false,
        errorMessage: m['errorMessage'] as String?,
        activeTrackIds: (m['activeTrackIds'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [],
      );

  static SenzuCastSessionState _parseSessionState(String? s) {
    switch (s) {
      case 'loading':
        return SenzuCastSessionState.loading;
      case 'playing':
        return SenzuCastSessionState.playing;
      case 'paused':
        return SenzuCastSessionState.paused;
      case 'buffering':
        return SenzuCastSessionState.buffering;
      case 'error':
        return SenzuCastSessionState.error;
      default:
        return SenzuCastSessionState.idle;
    }
  }
}

class SenzuCastService {
  SenzuCastService._();

  // Cast channel — senzu_player/cast
  static const _castMethod = MethodChannel('senzu_player/cast');
  static const _castEvent  = EventChannel('senzu_player/cast_events');

  // Native channel — senzu_player/native
  static const _nativeMethod = MethodChannel('senzu_player/native');

  static StreamSubscription<dynamic>? _eventSub;

  static final _castStateCtrl =
      StreamController<SenzuCastState>.broadcast();
  static final _remoteStateCtrl =
      StreamController<SenzuCastRemoteState>.broadcast();
  static final _devicesCtrl =
      StreamController<List<SenzuCastDeviceInfo>>.broadcast();

  static Stream<SenzuCastState> get castStateStream => _castStateCtrl.stream;
  static Stream<SenzuCastRemoteState> get remoteStateStream =>
      _remoteStateCtrl.stream;
  static Stream<List<SenzuCastDeviceInfo>> get devicesStream =>
      _devicesCtrl.stream;

  // ── Cast SDK Initialize ──────────────────────────────────────────────────
  static Future<void> initCast({required String appId}) async {
    try {
      await _nativeMethod.invokeMethod('initCast', {
        'appId': appId,
      });
    } on PlatformException catch (e) {
      debugPrint('SenzuCast initCast error: ${e.message}');
    }
  }

  // ── Event stream ─────────────────────────────────────────────────────────

  static Future<List<SenzuCastDeviceInfo>> discoverDevices() async {
    try {
      final result = await _castMethod.invokeMethod<List>('discoverDevices');
      return result
              ?.map((e) => SenzuCastDeviceInfo.fromMap(e as Map))
              .toList() ??
          [];
    } on PlatformException catch (e) {
      debugPrint('SenzuCast discoverDevices error: ${e.message}');
      return [];
    }
  }

  static Future<void> connectToDevice(String deviceId) async {
    try {
      await _castMethod.invokeMethod('connectToDevice', {'deviceId': deviceId});
    } on PlatformException catch (e) {
      debugPrint('SenzuCast connectToDevice error: ${e.message}');
    }
  }

  static void startListening() {
    _eventSub ??= _castEvent.receiveBroadcastStream().listen((event) {
      final m = Map<dynamic, dynamic>.from(event as Map);
      switch (m['type'] as String?) {
        case 'castState':
          _castStateCtrl.add(_parseCastState(m['state'] as String?));
        case 'remoteState':
          _remoteStateCtrl.add(SenzuCastRemoteState.fromMap(m));
        case 'devices':
          final raw = m['devices'] as List? ?? [];
          _devicesCtrl.add(
            raw.map((d) => SenzuCastDeviceInfo.fromMap(d as Map)).toList(),
          );
        default:
          break;
      }
    }, onError: (e) => debugPrint('SenzuCastService error: $e'));
  }

  static void stopListening() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  static SenzuCastState _parseCastState(String? s) {
    switch (s) {
      case 'connecting':
        return SenzuCastState.connecting;
      case 'connected':
        return SenzuCastState.connected;
      case 'noDevicesAvailable':
        return SenzuCastState.noDevicesAvailable;
      default:
        return SenzuCastState.notConnected;
    }
  }

  static Future<void> showDevicePicker() =>
      _castMethod.invokeMethod('showDevicePicker');

  static Future<bool> loadMedia(SenzuCastMedia media) async {
    try {
      final result =
          await _castMethod.invokeMethod<bool>('loadMedia', media.toMap());
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('SenzuCast loadMedia error: ${e.message}');
      return false;
    }
  }

  static Future<void> play()  => _castMethod.invokeMethod('play');
  static Future<void> pause() => _castMethod.invokeMethod('pause');
  static Future<void> seekTo(int positionMs) =>
      _castMethod.invokeMethod('seekTo', {'positionMs': positionMs});
  static Future<void> stop()  => _castMethod.invokeMethod('stop');
  static Future<void> setVolume(double volume) =>
      _castMethod.invokeMethod('setVolume', {'volume': volume});
  static Future<void> disconnect() => _castMethod.invokeMethod('disconnect');

  static Future<SenzuCastState> getCastState() async {
    final s = await _castMethod.invokeMethod<String>('getCastState');
    return _parseCastState(s);
  }

  static Future<void> setSubtitleTrack(int trackId) =>
      _castMethod.invokeMethod('setSubtitleTrack', {'trackId': trackId});

  static Future<void> disableSubtitles() =>
      _castMethod.invokeMethod('disableSubtitles');

  static Future<void> setAudioTrack(int trackId) =>
      _castMethod.invokeMethod('setAudioTrack', {'trackId': trackId});

  static Future<void> setActiveTracks(List<int> trackIds) =>
      _castMethod.invokeMethod('setActiveTracks', {'trackIds': trackIds});

  static Future<bool> loadQuality(
    String url, {
    Map<String, String> headers = const {},
    int positionMs = 0,
    int durationMs = 0,
    bool isLive = false,
  }) async {
    try {
      final result = await _castMethod.invokeMethod<bool>('loadQuality', {
        'url': url,
        'headers': headers,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'isLive': isLive,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('SenzuCast loadQuality error: ${e.message}');
      return false;
    }
  }
}