import 'dart:async';
import 'package:flutter/services.dart';
import 'senzu_native_video_state.dart';
import 'senzu_native_channel.dart';

class SenzuNativeVideoController {
  static const _methodChannel = MethodChannel('senzu_player/native');

  final _stateCtrl = StreamController<SenzuNativeVideoState>.broadcast();
  StreamSubscription<SenzuNativeVideoState>? _eventSub;

  SenzuNativeVideoState _value = const SenzuNativeVideoState();
  bool _disposed = false;

  SenzuNativeVideoState get value => _value;
  Stream<SenzuNativeVideoState> get stream => _stateCtrl.stream;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void startListening() {
    _eventSub?.cancel();
    _eventSub = SenzuNativeChannel.playbackStream.listen(
      (state) {
        if (_disposed) return;
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
    assert(!_disposed, 'initialize() called after dispose()');

    final args = <String, dynamic>{
      'url':     url,
      'headers': headers,
      'title':   title,
      'artist':  artist,
      'artwork': artwork ?? '',
      'isLive':  isLive,
    };
    if (drm.isNotEmpty) {
      args['drm'] = drm;
    }

    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'initialize',
      args,
    );
    final durationMs = result?['durationMs'] as int? ?? 0;
    _value = SenzuNativeVideoState(
      duration:      Duration(milliseconds: durationMs),
      isInitialized: true,
    );
    _emit(_value);
    return _value;
  }

  Future<void> play() async {
    if (_disposed) return;
    return _methodChannel.invokeMethod('play');
  }

  Future<void> pause() async {
    if (_disposed) return;
    return _methodChannel.invokeMethod('pause');
  }

  Future<void> seekTo(Duration pos) async {
    if (_disposed) return;
    return _methodChannel.invokeMethod(
      'seekTo',
      {'positionMs': pos.inMilliseconds.toDouble()},
    );
  }

  Future<void> setPlaybackSpeed(double s) async {
    if (_disposed) return;
    return _methodChannel.invokeMethod('setPlaybackSpeed', {'speed': s});
  }

  Future<void> setLooping(bool v) async {
    if (_disposed) return;
    return _methodChannel.invokeMethod('setLooping', {'looping': v});
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _eventSub?.cancel();
    _eventSub = null;

    try {
      await _methodChannel.invokeMethod('dispose');
    } catch (_) {
      // Native player may already be gone on hot-restart / force-close
    }

    if (!_stateCtrl.isClosed) {
      await _stateCtrl.close();
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _onError(Object err) {
    if (_disposed) return;
    final msg = err is PlatformException ? (err.message ?? '$err') : '$err';
    final s = _value.copyWith(errorDescription: msg, isPlaying: false);
    _value = s;
    _emit(s);
  }

  void _emit(SenzuNativeVideoState s) {
    // Double-check: disposed flag OR isClosed guard
    if (_disposed || _stateCtrl.isClosed) return;
    _stateCtrl.add(s);
  }
}