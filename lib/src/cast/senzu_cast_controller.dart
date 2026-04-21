import 'dart:async';
import 'package:get/get.dart';
import 'senzu_cast_service.dart';
import 'senzu_cast_media_builder.dart';
import 'dart:developer';

enum SenzuCastPanel { caption, quality, episode, audio, cast, none }

class SenzuCastController extends GetxController {
  final String appId;
  SenzuCastController({this.appId = kDefaultApplicationId});
  static const String kDefaultApplicationId = 'CC1AD845';

  // ── Rx State ──────────────────────────────────────────────────────────────
  final castState = SenzuCastState.notConnected.obs;
  final remoteState = const SenzuCastRemoteState().obs;
  final availableDevices = RxList<SenzuCastDeviceInfo>([]);
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final activeSource = RxnString();
  final activePanel = SenzuCastPanel.none.obs;

  final isDiscovering = false.obs;
  final connectingDeviceId = RxnString();

  // Track state
  final activeSubtitleTrackId = RxnInt();
  final activeAudioTrackId = RxnInt();

  final subtitleTracks = RxList<CastSubtitleTrack>([]);
  final audioTracks = RxList<CastAudioTrack>([]);
  final qualityOptions = RxList<CastQualityOption>([]);
  final activeQuality = RxnString();

  // ── Private ───────────────────────────────────────────────────────────────
  StreamSubscription<SenzuCastState>? _castStateSub;
  StreamSubscription<SenzuCastRemoteState>? _remoteStateSub;
  StreamSubscription<List<SenzuCastDeviceInfo>>? _devicesSub;

  SenzuCastMedia? _currentMedia;
  String? get currentPosterUrl => _currentMedia?.posterUrl;

  bool get isCasting => castState.value == SenzuCastState.connected;
  bool get isConnecting => castState.value == SenzuCastState.connecting;

  String? get connectedDeviceName =>
      availableDevices.firstWhereOrNull((_) => isCasting)?.deviceName;

  Duration get resumePosition =>
      Duration(milliseconds: remoteState.value.positionMs);

  int _attachCount = 0;

  @override
  void onInit() {
    super.onInit();
    _initAndAttach();
  }

  Future<void> _initAndAttach() async {
    await SenzuCastService.initCast(appId: appId);
    _attach();
  }

  @override
  void onClose() {
    _detach();
    super.onClose();
  }

  // ── Lifecycle helpers called by SenzuCoreController ───────────────────────

  void attach() {
    _attach();
  }

  void detach() {
    _detach();
  }

  void _attach() {
    _attachCount++;
    if (_attachCount == 1) {
      // First consumer — start the native event channel.
      SenzuCastService.startListening();
    }
    // Always re-subscribe streams in case they were cancelled.
    _subscribeStreams();
    _syncInitialState();
  }

  void _detach() {
    if (_attachCount <= 0) return;
    _attachCount--;

    if (_attachCount == 0) {
      _cancelSubscriptions();
      if (!isCasting) {
        SenzuCastService.stopListening();
      }
    }
  }

  void _subscribeStreams() {
    _cancelSubscriptions();

    _castStateSub = SenzuCastService.castStateStream.listen((state) {
      castState.value = state;

      if (state == SenzuCastState.notConnected) {
        remoteState.value = const SenzuCastRemoteState();
        _currentMedia = null;
        _resetTrackState();
        activeQuality.value = null;

        // Now it is safe to stop the service if no consumers remain.
        if (_attachCount == 0) {
          SenzuCastService.stopListening();
        }
      }
    });

    _remoteStateSub = SenzuCastService.remoteStateStream.listen((state) {
      remoteState.value = state;

      if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
        errorMessage.value = state.errorMessage;
      }

      _syncTrackStateFromNative(state.activeTrackIds);
    });

    _devicesSub = SenzuCastService.devicesStream.listen((devices) {
      availableDevices.value = devices;
    });
  }

  void _cancelSubscriptions() {
    _castStateSub?.cancel();
    _castStateSub = null;
    _remoteStateSub?.cancel();
    _remoteStateSub = null;
    _devicesSub?.cancel();
    _devicesSub = null;
  }

  void _syncTrackStateFromNative(List<int> activeIds) {
    if (activeIds.isEmpty) return;

    for (final track in subtitleTracks) {
      if (activeIds.contains(track.id)) {
        if (activeSubtitleTrackId.value != track.id) {
          activeSubtitleTrackId.value = track.id;
        }
        break;
      }
    }

    for (final track in audioTracks) {
      if (activeIds.contains(track.id)) {
        if (activeAudioTrackId.value != track.id) {
          activeAudioTrackId.value = track.id;
        }
        break;
      }
    }
  }

  void _resetTrackState() {
    activeSubtitleTrackId.value = null;
    activeAudioTrackId.value = null;
  }

  Future<void> _syncInitialState() async {
    try {
      // fore init
      await SenzuCastService.initCast(appId: appId);
      final state = await SenzuCastService.getCastState();
      castState.value = state;
    } catch (e) {
      log('SenzuCast: initial state sync failed: $e');
    }
  }

  void toggleCastPanel(SenzuCastPanel panel) {
    activePanel.value = activePanel.value == panel
        ? SenzuCastPanel.none
        : panel;
  }

  // ── Device Discovery & Connection ─────────────────────────────────────────
  Future<void> discoverDevices() async {
    isDiscovering.value = true;

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      final found = await SenzuCastService.discoverDevices();

      if (found.isNotEmpty) {
        availableDevices.value = found;
      }
    } catch (e) {
      errorMessage.value = 'Хайлт амжилтгүй: $e';
    } finally {
      isDiscovering.value = false;
    }
  }

  Future<void> connectToDevice(SenzuCastDeviceInfo device) async {
    connectingDeviceId.value = device.deviceId;
    try {
      await SenzuCastService.connectToDevice(device.deviceId);
    } catch (e) {
      errorMessage.value = 'Холбогдоход алдаа гарлаа: $e';
    } finally {
      connectingDeviceId.value = null;
    }
  }

  Future<void> showDevicePicker() async {
    errorMessage.value = null;
    try {
      await SenzuCastService.showDevicePicker();
    } catch (e) {
      errorMessage.value = 'Төхөөрөмж олдсонгүй: $e';
    }
  }

  // ── castMedia ──────────────────────────────────────────────────────────────
  Future<bool> castMedia(SenzuCastMedia media) async {
    if (!isCasting) {
      errorMessage.value = 'Cast холбогдоогүй байна';
      return false;
    }

    subtitleTracks.value = media.availableSubtitles;
    audioTracks.value = media.availableAudioTracks;
    qualityOptions.value = media.availableQualities;

    _resetTrackState();

    activeSubtitleTrackId.value = media.selectedSubtitleId;
    activeAudioTrackId.value = media.selectedAudioId;

    if (media.availableQualities.isNotEmpty) {
      final matchedQuality = media.availableQualities.firstWhereOrNull(
        (q) => q.url == media.url,
      );

      activeQuality.value =
          matchedQuality?.label ?? media.availableQualities.first.label;
    } else {
      activeQuality.value = null;
    }

    isLoading.value = true;
    errorMessage.value = null;
    _currentMedia = media;

    try {
      final ok = await SenzuCastService.loadMedia(media);
      if (!ok) {
        errorMessage.value = 'Media load амжилтгүй боллоо';
        isLoading.value = false;
        return false;
      }

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'Cast error: $e';
      isLoading.value = false;
      return false;
    }
  }

  Future<void> switchToCast({
    required SenzuCastMedia media,
    Duration? currentPosition,
  }) async {
    final merged = SenzuCastMedia(
      url: media.url,
      title: media.title,
      description: media.description,
      posterUrl: media.posterUrl,
      subtitleUrl: media.subtitleUrl,
      subtitleLanguage: media.subtitleLanguage,
      mimeType: media.mimeType,
      positionMs: currentPosition?.inMilliseconds ?? media.positionMs,
      durationMs: media.durationMs,
      isLive: media.isLive,
      releaseDate: media.releaseDate,
      studio: media.studio,
      httpHeaders: media.httpHeaders,
      subtitleHeaders: media.subtitleHeaders,
      availableSubtitles: media.availableSubtitles,
      availableAudioTracks: media.availableAudioTracks,
      availableQualities: media.availableQualities,
      selectedSubtitleId: media.selectedSubtitleId,
      selectedAudioId: media.selectedAudioId,
    );

    await castMedia(merged);
  }

  Future<void> play() => SenzuCastService.play();
  Future<void> pause() => SenzuCastService.pause();
  Future<void> seekTo(Duration position) =>
      SenzuCastService.seekTo(position.inMilliseconds);

  Future<void> stop() async {
    await SenzuCastService.stop();
    _currentMedia = null;
  }

  Future<void> disconnect() async {
    await SenzuCastService.disconnect();
    _currentMedia = null;
  }

  // ── Subtitle ───────────────────────────────────────────────────────────────
  Future<void> setSubtitle(int trackId) async {
    activeSubtitleTrackId.value = trackId;

    final ids = <int>[
      trackId,
      if (activeAudioTrackId.value != null) activeAudioTrackId.value!,
    ];

    await SenzuCastService.setActiveTracks(ids);
  }

  Future<void> disableSubtitles() async {
    activeSubtitleTrackId.value = null;

    final ids = <int>[
      if (activeAudioTrackId.value != null) activeAudioTrackId.value!,
    ];

    await SenzuCastService.setActiveTracks(ids);
  }

  // ── Audio ──────────────────────────────────────────────────────────────────
  Future<void> setAudioTrack(int trackId) async {
    activeAudioTrackId.value = trackId;

    final ids = <int>[
      trackId,
      if (activeSubtitleTrackId.value != null) activeSubtitleTrackId.value!,
    ];

    await SenzuCastService.setActiveTracks(ids);
  }

  Future<void> setCastVolume(double volume) =>
      SenzuCastService.setVolume(volume);

  // ── Quality ────────────────────────────────────────────────────────────────
  Future<void> switchQuality(String label) async {
    final q = qualityOptions.firstWhereOrNull((o) => o.label == label);
    if (q == null) return;

    final previousQuality = activeQuality.value;
    activeQuality.value = label;

    final pos = remoteState.value.positionMs;
    final dur = remoteState.value.durationMs;
    final isLive = dur == 0;

    try {
      final ok = await SenzuCastService.loadQuality(
        q.url,
        headers: q.headers,
        positionMs: pos,
        durationMs: dur,
        isLive: isLive,
      );

      if (!ok) {
        activeQuality.value = previousQuality;
        errorMessage.value = 'Чанар солих амжилтгүй';
        return;
      }

      log('SenzuCast: switchQuality → $label, pos=${pos}ms');
    } catch (e) {
      activeQuality.value = previousQuality;
      errorMessage.value = 'Чанар солих үед алдаа гарлаа: $e';
    }
  }
}
