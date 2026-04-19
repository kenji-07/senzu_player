import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'senzu_cast_service.dart';
import 'senzu_cast_media_builder.dart';

enum SenzuCastPanel { caption, quality, episode, audio, cast, none }

class SenzuCastController extends GetxController {
  // ── Rx State ──────────────────────────────────────────────────────────────
  final castState = SenzuCastState.notConnected.obs;
  final remoteState = const SenzuCastRemoteState().obs;
  final availableDevices = RxList<SenzuCastDeviceInfo>([]);
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final activeSource = RxnString();
  final activePanel = SenzuCastPanel.none.obs;

  // ── Device panel state ────────────────────────────────────────────────────
  final isDiscovering = false.obs;
  final connectingDeviceId = RxnString();

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

  // ── Computed ──────────────────────────────────────────────────────────────
  bool get isCasting => castState.value == SenzuCastState.connected;
  bool get isConnecting => castState.value == SenzuCastState.connecting;

  String? get connectedDeviceName =>
      availableDevices.firstWhereOrNull((_) => isCasting)?.deviceName;

  @override
  void onInit() {
    super.onInit();
    SenzuCastService.startListening();
    _subscribeStreams();
    _syncInitialState();
  }

  void _subscribeStreams() {
    _castStateSub = SenzuCastService.castStateStream.listen((state) {
      castState.value = state;
      // Cast холбогдоход одоогийн медиаг дахин load хийхгүй —
      // SenzuCoreController._onCastStateChanged castCurrentSource() дуудна.
      if (state == SenzuCastState.notConnected) {
        remoteState.value = const SenzuCastRemoteState();
        _currentMedia = null;
      }
    });

    _remoteStateSub = SenzuCastService.remoteStateStream.listen((state) {
      remoteState.value = state;
      if (state.errorMessage != null) {
        errorMessage.value = state.errorMessage;
      }
    });

    _devicesSub = SenzuCastService.devicesStream.listen((devices) {
      availableDevices.value = devices;
    });
  }

  Future<void> _syncInitialState() async {
    try {
      castState.value = await SenzuCastService.getCastState();
    } catch (e) {
      debugPrint('SenzuCast: initial state sync failed: $e');
    }
  }

  // ── Panel ──────────────────────────────────────────────────────────────────
  void toggleCastPanel(SenzuCastPanel panel) {
    activePanel.value = activePanel.value == panel
        ? SenzuCastPanel.none
        : panel;
  }

  // ── Device Discovery & Connection ─────────────────────────────────────────
  Future<void> discoverDevices() async {
    isDiscovering.value = true;
    try {
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

  // ── Public API ─────────────────────────────────────────────────────────────
  Future<void> showDevicePicker() async {
    errorMessage.value = null;
    try {
      await SenzuCastService.showDevicePicker();
    } catch (e) {
      errorMessage.value = 'Төхөөрөмж олдсонгүй: $e';
    }
  }

  /// Cast руу медиа илгээх — track мэдээллийг хадгална, дахин load хийнэ
  Future<bool> castMedia(SenzuCastMedia media) async {
    if (!isCasting) {
      errorMessage.value = 'Cast холбогдоогүй байна';
      return false;
    }

    subtitleTracks.value = media.availableSubtitles;
    audioTracks.value = media.availableAudioTracks;
    qualityOptions.value = media.availableQualities;

    // ✅ Шинэ медиа load хийхэд active state-г reset хийнэ
    activeSubtitleTrackId.value = null;
    activeAudioTrackId.value = null;

    if (media.availableQualities.isNotEmpty) {
      activeQuality.value = media.availableQualities.first.label;
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

  /// Subtitle track солих — шинэ loadMedia биш, setActiveTrackIDs ашиглана
  Future<void> setSubtitle(int trackId) async {
    // ✅ Эхлээд state шинэчилнэ (UI шууд харагдана)
    activeSubtitleTrackId.value = trackId;

    final activeIds = <int>[trackId];
    if (activeAudioTrackId.value != null) {
      activeIds.add(activeAudioTrackId.value!);
    }
    await SenzuCastService.setActiveTracks(activeIds);
  }

  Future<void> disableSubtitles() async {
    // ✅ State-г эхлээд reset хийнэ
    activeSubtitleTrackId.value = null;

    if (activeAudioTrackId.value != null) {
      await SenzuCastService.setActiveTracks([activeAudioTrackId.value!]);
    } else {
      await SenzuCastService.setActiveTracks([]);
    }
  }

  /// Audio track солих — setActiveTrackIDs ашиглана
  Future<void> setAudioTrack(int trackId) async {
    // ✅ State-г эхлээд шинэчилнэ
    activeAudioTrackId.value = trackId;

    final activeIds = <int>[trackId];
    if (activeSubtitleTrackId.value != null) {
      activeIds.add(activeSubtitleTrackId.value!);
    }
    await SenzuCastService.setActiveTracks(activeIds);
  }

  Future<void> setCastVolume(double volume) =>
      SenzuCastService.setVolume(volume);

  /// Чанар солих — loadQuality дуудна (position хадгалж)
  Future<void> switchQuality(String label) async {
    final q = qualityOptions.firstWhereOrNull((o) => o.label == label);
    if (q == null) return;

    // ✅ Эхлээд UI шинэчилнэ
    activeQuality.value = label;

    final pos = remoteState.value.positionMs;
    final ok = await SenzuCastService.loadQuality(
      q.url,
      headers: q.headers,
      positionMs: pos,
    );
    // Load амжилтгүй бол rollback хийнэ
    if (!ok) activeQuality.value = null;
  }

  Future<void> switchToCast({
    required SenzuCastMedia media,
    required Duration currentPosition,
  }) async {
    final mediaWithPos = SenzuCastMedia(
      url: media.url,
      title: media.title,
      description: media.description,
      posterUrl: media.posterUrl,
      subtitleUrl: media.subtitleUrl,
      mimeType: media.mimeType,
      positionMs: currentPosition.inMilliseconds,
      isLive: media.isLive,
      httpHeaders: media.httpHeaders,
      subtitleHeaders: media.subtitleHeaders,
      availableSubtitles: media.availableSubtitles,
      availableAudioTracks: media.availableAudioTracks,
      availableQualities: media.availableQualities,
      releaseDate: media.releaseDate,
      studio: media.studio,
    );
    await castMedia(mediaWithPos);
  }

  Duration get resumePosition =>
      Duration(milliseconds: remoteState.value.positionMs);

  @override
  void onClose() {
    _castStateSub?.cancel();
    _remoteStateSub?.cancel();
    _devicesSub?.cancel();
    SenzuCastService.stopListening();
    super.onClose();
  }
}
