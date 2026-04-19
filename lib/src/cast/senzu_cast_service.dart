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
  });

  final SenzuCastSessionState sessionState;
  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final double volume;
  final bool isMuted;
  final String? errorMessage;

  factory SenzuCastRemoteState.fromMap(Map<dynamic, dynamic> m) =>
      SenzuCastRemoteState(
        sessionState: _parseSessionState(m['sessionState'] as String?),
        positionMs: (m['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        isPlaying: (m['isPlaying'] as bool?) ?? false,
        volume: (m['volume'] as num?)?.toDouble() ?? 1.0,
        isMuted: (m['isMuted'] as bool?) ?? false,
        errorMessage: m['errorMessage'] as String?,
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

  static const _method = MethodChannel('senzu_player/cast');
  static const _event = EventChannel('senzu_player/cast_events');

  static StreamSubscription<dynamic>? _eventSub;

  // ── Stream controllers ────────────────────────────────────────────────────
  static final _castStateCtrl = StreamController<SenzuCastState>.broadcast();
  static final _remoteStateCtrl =
      StreamController<SenzuCastRemoteState>.broadcast();
  static final _devicesCtrl =
      StreamController<List<SenzuCastDeviceInfo>>.broadcast();

  static Stream<SenzuCastState> get castStateStream => _castStateCtrl.stream;
  static Stream<SenzuCastRemoteState> get remoteStateStream =>
      _remoteStateCtrl.stream;
  static Stream<List<SenzuCastDeviceInfo>> get devicesStream =>
      _devicesCtrl.stream;

  static Future<List<SenzuCastDeviceInfo>> discoverDevices() async {
    try {
      final result = await _method.invokeMethod<List>('discoverDevices');
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
      await _method.invokeMethod('connectToDevice', {'deviceId': deviceId});
    } on PlatformException catch (e) {
      debugPrint('SenzuCast connectToDevice error: ${e.message}');
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  static void startListening() {
    _eventSub ??= _event.receiveBroadcastStream().listen((event) {
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

  // ── Commands ──────────────────────────────────────────────────────────────
  static Future<void> showDevicePicker() =>
      _method.invokeMethod('showDevicePicker');

  static Future<bool> loadMedia(SenzuCastMedia media) async {
    try {
      final result = await _method.invokeMethod<bool>(
        'loadMedia',
        media.toMap(),
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('SenzuCast loadMedia error: ${e.message}');
      return false;
    }
  }

  static Future<void> play() => _method.invokeMethod('play');

  static Future<void> pause() => _method.invokeMethod('pause');

  static Future<void> seekTo(int positionMs) =>
      _method.invokeMethod('seekTo', {'positionMs': positionMs});

  static Future<void> stop() => _method.invokeMethod('stop');

  static Future<void> setVolume(double volume) =>
      _method.invokeMethod('setVolume', {'volume': volume});

  static Future<void> disconnect() => _method.invokeMethod('disconnect');

  static Future<SenzuCastState> getCastState() async {
    final s = await _method.invokeMethod<String>('getCastState');
    return _parseCastState(s);
  }

  /// Subtitle track идэвхжүүлэх (setActiveTrackIDs дуудна)
  static Future<void> setSubtitleTrack(int trackId) =>
      _method.invokeMethod('setSubtitleTrack', {'trackId': trackId});

  static Future<void> disableSubtitles() =>
      _method.invokeMethod('disableSubtitles');

  /// Audio track идэвхжүүлэх (setActiveTrackIDs дуудна)
  static Future<void> setAudioTrack(int trackId) =>
      _method.invokeMethod('setAudioTrack', {'trackId': trackId});

  /// Subtitle + audio хоёуланг нэг дор тохируулах — [trackIds] хоосон бол бүгдийг унтраана
  static Future<void> setActiveTracks(List<int> trackIds) =>
      _method.invokeMethod('setActiveTracks', {'trackIds': trackIds});

  static Future<bool> loadQuality(
    String url, {
    Map<String, String> headers = const {},
    int positionMs = 0,
    int durationMs = 0, // ← НЭМЭХ
    bool isLive = false, // ← НЭМЭХ
  }) async {
    try {
      final result = await _method.invokeMethod<bool>('loadQuality', {
        'url': url,
        'headers': headers,
        'positionMs': positionMs,
        'durationMs': durationMs, // ← НЭМЭХ
        'isLive': isLive,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('SenzuCast loadQuality error: ${e.message}');
      return false;
    }
  }
}
