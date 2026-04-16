import 'dart:async';
import 'package:flutter/services.dart';
import 'senzu_native_video_state.dart';
import 'senzu_native_channel.dart';

class SenzuNativeVideoController {
  static const _methodChannel = MethodChannel('senzu_player/native');

  final _stateCtrl = StreamController<SenzuNativeVideoState>.broadcast();
  StreamSubscription<SenzuNativeVideoState>? _eventSub;

  SenzuNativeVideoState _value = const SenzuNativeVideoState();
  SenzuNativeVideoState get value => _value;
  Stream<SenzuNativeVideoState> get stream => _stateCtrl.stream;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// EventChannel-д subscribe хийнэ.
  /// [SenzuNativeChannel.startListening] өмнө нь дуудагдсан байх ёстой.
  void startListening() {
    _eventSub?.cancel();
    _eventSub = SenzuNativeChannel.playbackStream.listen(
      (state) {
        _value = state;
        _emit(state);
      },
      onError: _onError,
    );
  }

  Future<SenzuNativeVideoState> initialize({
    required String url,
    Map<String, String> headers = const {},
    Map<String, dynamic> drm = const {},
    String title  = '',
    String artist = '',
    String? artwork,
    bool isLive   = false,
  }) async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'initialize',
      {
        'url':     url,
        'headers': headers,
        'title':   title,
        'artist':  artist,
        'artwork': artwork ?? '',
        'isLive':  isLive,
        'drm': drm,

      },
    );
    final durationMs = result?['durationMs'] as int? ?? 0;
    _value = SenzuNativeVideoState(
      duration:      Duration(milliseconds: durationMs),
      isInitialized: true,
    );
    _emit(_value);
    return _value;
  }

  Future<void> play()  => _methodChannel.invokeMethod('play');
  Future<void> pause() => _methodChannel.invokeMethod('pause');

  Future<void> seekTo(Duration pos) =>
      _methodChannel.invokeMethod('seekTo', {'positionMs': pos.inMilliseconds.toDouble()});

  Future<void> setPlaybackSpeed(double s) =>
      _methodChannel.invokeMethod('setPlaybackSpeed', {'speed': s});

  Future<void> setLooping(bool v) =>
      _methodChannel.invokeMethod('setLooping', {'looping': v});

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _methodChannel.invokeMethod('dispose');
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _onError(Object err) {
    final msg = err is PlatformException ? (err.message ?? '$err') : '$err';
    final s = _value.copyWith(errorDescription: msg, isPlaying: false);
    _value = s;
    _emit(s);
  }

  void _emit(SenzuNativeVideoState s) {
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }
}