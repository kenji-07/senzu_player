import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:senzu_player/src/data/models/video_source_model.dart';
import 'package:senzu_player/src/data/models/senzu_player_config.dart';
import 'package:senzu_player/src/data/models/senzu_token_provider.dart';
import 'package:senzu_player/src/data/models/senzu_watermark.dart';
import 'package:senzu_player/src/data/models/senzu_audio_track.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';
import 'package:senzu_player/src/platform/senzu_native_video_controller.dart';
import 'package:senzu_player/src/platform/senzu_native_video_state.dart';
import 'package:senzu_player/src/platform/senzu_token_manager.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';
import 'package:senzu_player/src/cast/senzu_cast_media_builder.dart';
import 'package:senzu_player/src/cast/senzu_cast_service.dart';

class SenzuPlayerErrorState {
  const SenzuPlayerErrorState({
    required this.message,
    required this.sourceName,
  });
  final String message;
  final String sourceName;
}

class SenzuCoreController extends GetxController with WidgetsBindingObserver {
  SenzuCoreController({
    this.looping = false,
    this.secureMode = false,
    this.notification = true,
    this.watermark,
    this.onQualityChanged,
    SenzuDataPolicy dataPolicy = const SenzuDataPolicy(),
    SenzuTokenConfig? tokenConfig,
  }) {
    _dataPolicy = dataPolicy;
    if (tokenConfig != null) {
      _tokenManager = SenzuTokenManager(config: tokenConfig);
    }
  }

  // ── Config ─────────────────────────────────────────────────────────────────
  bool looping;
  bool secureMode;
  bool notification;
  SenzuWatermark? watermark;
  void Function(String quality)? onQualityChanged;

  SenzuDataPolicy _dataPolicy = const SenzuDataPolicy();
  SenzuTokenManager? _tokenManager;
  bool _pendingDataSaver = false;

  bool _disposed = false;
  int _sourceGeneration = 0;

  // ── Core Rx ────────────────────────────────────────────────────────────────
  final rxNativeState = Rx<SenzuNativeVideoState>(
    const SenzuNativeVideoState(),
  );
  final rxSources = Rxn<Map<String, VideoSource>>();
  final rxActiveSource = RxnString();
  final isChangingSource = false.obs;
  final hasError = false.obs;
  final errorState = Rxn<SenzuPlayerErrorState>();
  final audioTracks = RxList<SenzuAudioTrack>([]);
  final activeAudioTrack = RxnString();
  final isHdrEnabled = false.obs;
  final networkType = 'unknown'.obs;
  final showCellularWarning = false.obs;
  final isLiveRx = false.obs;
  final pendingSeek = Duration.zero.obs;
  final isFullScreen = false.obs;

  // ── Private ────────────────────────────────────────────────────────────────
  SenzuNativeVideoController? _native;
  StreamSubscription<SenzuNativeVideoState>? _stateSub;

  // ── Cast integration ───────────────────────────────────────────────────────
  SenzuCastController? _castController;

  bool? _explicitIsLive;
  bool _wasPlaying = false;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;

  double _currentSpeed = 1.0;

  StreamSubscription<double>? _volSub;
  StreamSubscription<Map<String, dynamic>>? _batSub;

  // ── External callbacks ─────────────────────────────────────────────────────
  bool Function()? isAdActiveCallback;
  void Function(dynamic, String)? onSubtitleChangeRequested;
  void Function(List<dynamic>)? onPendingAdsChanged;
  void Function(String)? onSourceChanged;

  // ── Getters ────────────────────────────────────────────────────────────────
  SenzuNativeVideoState get nativeState => rxNativeState.value;
  Map<String, VideoSource>? get sources => rxSources.value;
  String? get activeSourceName => rxActiveSource.value;
  VideoSource? get activeSource => rxSources.value?[rxActiveSource.value];
  double get playbackSpeed => _currentSpeed;

  bool get isLive {
    if (_explicitIsLive != null) return _explicitIsLive!;
    final d = rxNativeState.value.duration;
    return d == Duration.zero || d.inHours >= 24;
  }

  Duration get beginRange {
    final r = activeSource?.range;
    final b = r?.begin ?? Duration.zero;
    final dur = rxNativeState.value.duration;
    return (dur > Duration.zero && b >= dur) ? Duration.zero : b;
  }

  Duration get endRange {
    final dur = rxNativeState.value.duration;
    final r = activeSource?.range;
    final e = r?.end ?? dur;
    return e >= dur ? dur : e;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    SenzuNativeChannel.startListening();
    _volSub = SenzuNativeChannel.volumeStream.listen((_) {});
    _batSub = SenzuNativeChannel.batteryStream.listen((_) {});
    ever(isFullScreen, _onFullscreenChanged);
  }

  void _onFullscreenChanged(bool fs) {
    if (fs) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      Future.delayed(const Duration(milliseconds: 50), () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  void onClose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _volSub?.cancel();
    _batSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SenzuNativeChannel.stopListening();
    _releaseNative();
    if (secureMode) SenzuNativeChannel.disableSecureMode();
    _tokenManager?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        _wasPlaying = rxNativeState.value.isPlaying;
        if (_wasPlaying) pause();
      case AppLifecycleState.resumed:
        if (_wasPlaying) play();
      default:
        break;
    }
  }

  // ── Initialize ─────────────────────────────────────────────────────────────
  Future<void> initialize(
    Map<String, VideoSource> sourcesMap, {
    bool autoPlay = true,
    Duration seekTo = Duration.zero,
    bool? isLive,
  }) async {
    if (_disposed) return;

    await _checkNetwork();

    rxSources.value = sourcesMap;
    _explicitIsLive = isLive;
    isLiveRx.value = isLive ?? false;

    if (secureMode) await SenzuNativeChannel.enableSecureMode();

    final first = sourcesMap.entries.first;
    await changeSource(
      name: first.key,
      source: first.value,
      autoPlay: autoPlay,
    );

    if (_disposed) return;

    if (seekTo != Duration.zero && isLive != true) {
      await this.seekTo(seekTo + beginRange);
    }

    if (_pendingDataSaver) {
      _pendingDataSaver = false;
      _applyDataSaver();
    }
  }

  // ── Source change ──────────────────────────────────────────────────────────
  Future<void> changeSource({
    required String name,
    required VideoSource source,
    bool inheritPosition = true,
    bool autoPlay = true,
  }) async {
    if (_disposed) return;
    if (isAdActiveCallback?.call() == true) return;

    final myGen = ++_sourceGeneration;
    bool stale() => _disposed || _sourceGeneration != myGen;

    if (source.forceCodec == 'hevc') {
      final ok = await SenzuNativeChannel.checkCodecSupport('hevc');
      if (stale()) return;
      if (!ok) {
        errorState.value = SenzuPlayerErrorState(
          message: 'HEVC (H.265) is not supported on this device',
          sourceName: name,
        );
        hasError.value = true;
        return;
      }
    }

    _reconnectAttempts = 0;
    if (isLive) _startReconnectWatcher();

    if (source.isLowLatency) {
      await SenzuNativeChannel.setLowLatencyMode(
        targetMs: source.targetLatencyMs ?? 3000,
      );
      if (stale()) return;
    }

    if (rxActiveSource.value == name && rxNativeState.value.isInitialized) {
      return;
    }

    errorState.value = null;
    hasError.value = false;
    isChangingSource.value = true;

    final lastPos = rxNativeState.value.position;
    final lastSpeed = _currentSpeed;

    if (source.subtitle != null) {
      final sub = source.subtitle![source.initialSubtitle];
      if (sub != null) {
        onSubtitleChangeRequested?.call(sub, source.initialSubtitle);
      }
    }
    onPendingAdsChanged?.call(source.ads?.toList() ?? []);

    await _releaseNative();
    if (stale()) return;

    final ctrl = SenzuNativeVideoController();
    _native = ctrl;
    ctrl.startListening();

    SenzuNativeVideoState initState;
    try {
      initState = await ctrl.initialize(
        url: source.dataSource,
        headers: source.httpHeaders ?? {},
        drm: source.drm?.toMap() ?? {},
      );
    } catch (e) {
      if (stale()) {
        await ctrl.dispose();
        _native = null;
        return;
      }
      isChangingSource.value = false;
      errorState.value = SenzuPlayerErrorState(
        message: e.toString(),
        sourceName: name,
      );
      hasError.value = true;
      _native = null;
      return;
    }

    if (stale()) {
      await ctrl.dispose();
      _native = null;
      return;
    }

    final hdrOk = await SenzuNativeChannel.isHdrSupported();
    if (stale()) {
      await ctrl.dispose();
      _native = null;
      return;
    }
    if (hdrOk) {
      await SenzuNativeChannel.enableHdrIfSupported();
      isHdrEnabled.value = true;
    }

    if (_tokenManager != null) {
      _tokenManager!.scheduleRefresh(
        sourceName: name,
        currentUrl: source.dataSource,
        currentHeaders: source.httpHeaders ?? {},
        onRefreshed: (newUrl, newHeaders) {
          if (_disposed) return;
          final srcs = rxSources.value;
          if (srcs == null || !srcs.containsKey(name)) return;
          final cur = srcs[name]!;
          final newSrc = VideoSource(
            dataSource: newUrl,
            ads: cur.ads,
            subtitle: cur.subtitle,
            initialSubtitle: cur.initialSubtitle,
            range: cur.range,
            httpHeaders: newHeaders,
            thumbnailSprite: cur.thumbnailSprite,
            isLowLatency: cur.isLowLatency,
            targetLatencyMs: cur.targetLatencyMs,
            forceCodec: cur.forceCodec,
            protocol: cur.protocol,
          );
          rxSources.value = {...srcs, name: newSrc};
          changeSource(name: name, source: newSrc, inheritPosition: true);
        },
      );
    }

    _stateSub = ctrl.stream.listen(_onNativeState);

    await _loadAudioTracks();
    if (stale()) {
      await _releaseNative();
      return;
    }

    rxActiveSource.value = name;
    if (_explicitIsLive == null) isLiveRx.value = isLive;

    await ctrl.setPlaybackSpeed(lastSpeed);
    await ctrl.setLooping(looping);

    if (inheritPosition &&
        lastPos > Duration.zero &&
        lastPos < initState.duration) {
      await ctrl.seekTo(lastPos);
    } else if (source.range != null) {
      await ctrl.seekTo(beginRange);
    }

    if (stale()) {
      await _releaseNative();
      return;
    }

    rxNativeState.value = initState;
    isChangingSource.value = false;
    onSourceChanged?.call(name);

    if (autoPlay) await play();
  }

  // ── Native state ───────────────────────────────────────────────────────────
  void _onNativeState(SenzuNativeVideoState state) {
    if (_disposed) return;
    rxNativeState.value = state;

    if (state.errorDescription != null && state.errorDescription!.isNotEmpty) {
      errorState.value = SenzuPlayerErrorState(
        message: state.errorDescription!,
        sourceName: rxActiveSource.value ?? '',
      );
      hasError.value = true;
    }

    if (!state.isBuffering && pendingSeek.value != Duration.zero) {
      _applySeek();
    }

    if (activeSource?.range != null && !isLive && state.position >= endRange) {
      if (looping) {
        _native?.seekTo(beginRange);
        _native?.play();
      } else {
        _native?.pause();
      }
    }
  }

  // ── Cast state ───────────────────────────────────────────────────────────
  void setCastController(SenzuCastController ctrl) {
    _castController = ctrl;
    // Cast state өөрчлөгдөхөд local player зогсоох / эхлүүлэх
    ever(ctrl.castState, _onCastStateChanged);
  }

  void _onCastStateChanged(SenzuCastState state) {
    switch (state) {
      case SenzuCastState.connected:
        // Cast холбогдсон үед local player-г pause хийнэ
        pause();
      case SenzuCastState.notConnected:
        // Cast тасарсан үед local player-г cast position-оос үргэлжлүүлнэ
        final resumePos = _castController?.resumePosition ?? Duration.zero;
        if (resumePos > Duration.zero) {
          seekTo(resumePos).then((_) => play());
        } else {
          play();
        }
      default:
        break;
    }
  }

  /// Одоогийн source-г cast руу илгээх
  Future<void> castCurrentSource() async {
    final ctrl = _castController;
    if (ctrl == null) return;
    if (!ctrl.isCasting) {
      await ctrl.showDevicePicker();
      return;
    }

    final source = activeSource;
    final sourceName = activeSourceName ?? '';
    if (source == null) return;

    final media = SenzuCastMedia(
      url: source.dataSource,
      title: sourceName,
      description: '',
      positionMs: rxNativeState.value.position.inMilliseconds,
      isLive: isLive,
      mimeType: source.protocol == VideoProtocol.dash
          ? 'application/dash+xml'
          : null,
    );

    await ctrl.switchToCast(
      media: media,
      currentPosition: rxNativeState.value.position,
    );
  }

  // ── Playback ───────────────────────────────────────────────────────────────
  Future<void> play() async {
    if (_disposed || isChangingSource.value) return;
    if (isAdActiveCallback?.call() == true) return;
    if (looping && !isLive) {
      final pos = rxNativeState.value.position;
      if (pos >= endRange) await _native?.seekTo(beginRange);
    }
    await _native?.play();
  }

  Future<void> pause() async {
    if (_disposed || isChangingSource.value) return;
    await _native?.pause();
  }

  Future<void> playOrPause() async {
    if (rxNativeState.value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekTo(Duration pos) async {
    if (_disposed || isChangingSource.value) return;
    final target = isLive ? pos : _clamp(pos, beginRange, endRange);
    await _native?.seekTo(target);
  }

  Future<void> seekBySeconds(int seconds) async {
    if (isLive) return;
    final cur = rxNativeState.value.position.inSeconds;
    await seekTo(Duration(seconds: cur + seconds));
    if (!rxNativeState.value.isPlaying) await play();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _currentSpeed = speed;
    await _native?.setPlaybackSpeed(speed);
  }

  Future<void> retrySource() async {
    if (_disposed) return;
    final name = errorState.value?.sourceName ?? rxActiveSource.value;
    if (name == null || rxSources.value == null) return;
    final src = rxSources.value![name];
    if (src == null) return;
    await changeSource(name: name, source: src, inheritPosition: false);
  }

  Future<void> goToLiveEdge() async {
    if (!isLive) return;
    await seekTo(rxNativeState.value.duration);
    await play();
  }

  // ── Seek queue ─────────────────────────────────────────────────────────────
  void queueSeek(Duration offset, {required bool isBuffering}) {
    if (isLive) return;
    pendingSeek.value += offset;
    if (!isBuffering) _applySeek();
  }

  Future<void> _applySeek() async {
    if (pendingSeek.value == Duration.zero) return;
    final cur = rxNativeState.value.position;
    final target = cur + pendingSeek.value;
    pendingSeek.value = Duration.zero;
    await seekTo(target);
  }

  // ── Audio ──────────────────────────────────────────────────────────────────
  Future<void> _loadAudioTracks() async {
    final raw = await SenzuNativeChannel.getAudioTracks();
    audioTracks.value = raw
        .map(
          (m) => SenzuAudioTrack(
            id: m['id']?.toString() ?? '',
            name: (m['label'] as String?) ?? (m['name'] as String?) ?? 'Track',
            language: m['language'] as String? ?? 'und',
            isDefault: m['selected'] as bool? ?? false,
          ),
        )
        .toList();
    if (audioTracks.isNotEmpty) {
      activeAudioTrack.value = audioTracks
          .firstWhere((t) => t.isDefault, orElse: () => audioTracks.first)
          .id;
    }
  }

  Future<void> setAudioTrack(SenzuAudioTrack track) async {
    await SenzuNativeChannel.setAudioTrack(track.id);
    activeAudioTrack.value = track.id;
  }

  // ── Fullscreen ─────────────────────────────────────────────────────────────
  Future<void> openOrCloseFullscreen() async {
    await HapticFeedback.lightImpact();
    isFullScreen.value = !isFullScreen.value;
    update();
  }

  Future<void> closeFullscreen() async {
    if (isFullScreen.value) {
      isFullScreen.value = false;
    } else {
      if (Get.context != null && Navigator.canPop(Get.context!)) {
        Navigator.of(Get.context!).pop();
      }
    }
  }

  // ── Network ────────────────────────────────────────────────────────────────
  Future<void> _checkNetwork() async {
    final type = await SenzuNativeChannel.getNetworkType();
    networkType.value = type;
    if (type == 'cellular' && _dataPolicy.warnOnCellular) {
      showCellularWarning.value = true;
    }
    if (type == 'cellular' && _dataPolicy.dataSaverOnCellular) {
      _pendingDataSaver = true;
    }
  }

  void dismissCellularWarning({bool dataSaver = false}) {
    showCellularWarning.value = false;
    if (dataSaver) _applyDataSaver();
  }

  void _applyDataSaver() {
    final srcs = rxSources.value;
    if (srcs == null || srcs.isEmpty) return;
    final key = _dataPolicy.dataSaverQualityKey ?? srcs.keys.last;
    final src = srcs[key];
    if (src != null && rxActiveSource.value != key) {
      changeSource(name: key, source: src, inheritPosition: true);
    }
  }

  // ── Reconnect ──────────────────────────────────────────────────────────────
  void _startReconnectWatcher() {
    _reconnectTimer?.cancel();
    if (!isLive) return;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_disposed) {
        _reconnectTimer?.cancel();
        return;
      }
      final s = rxNativeState.value;
      if (!s.isPlaying &&
          !s.isBuffering &&
          !hasError.value &&
          _reconnectAttempts < _maxReconnectAttempts) {
        _reconnectAttempts++;
        await retrySource();
      }
      if (s.isPlaying) _reconnectAttempts = 0;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Future<void> _releaseNative() async {
    await _stateSub?.cancel();
    _stateSub = null;
    await _native?.dispose();
    _native = null;
  }

  Duration _clamp(Duration v, Duration lo, Duration hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }
}
