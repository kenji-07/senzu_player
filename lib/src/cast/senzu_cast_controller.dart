import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'senzu_cast_service.dart';
import 'senzu_cast_media_builder.dart';

enum SenzuCastPanel {
  caption,
  quality,
  episode,
  audio,
  cast,
  none,
}

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

  // ── Computed ──────────────────────────────────────────────────────────────
  bool get isCasting => castState.value == SenzuCastState.connected;
  bool get isConnecting => castState.value == SenzuCastState.connecting;

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
      if (state == SenzuCastState.connected && _currentMedia != null) {
        _reloadCurrentMedia();
      }
      if (state == SenzuCastState.notConnected) {
        remoteState.value = const SenzuCastRemoteState();
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
    activePanel.value = activePanel.value == panel ? SenzuCastPanel.none : panel;
  }

  // ── Device Discovery & Connection ─────────────────────────────────────────

  /// Төхөөрөмж хайх (panel нээгдэхэд автоматаар дуудна)
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

  /// Тодорхой төхөөрөмжид холбогдох
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

  Future<bool> castMedia(SenzuCastMedia media) async {
    if (!isCasting) {
      errorMessage.value = 'Cast холбогдоогүй байна';
      return false;
    }

    subtitleTracks.value = media.availableSubtitles;
    audioTracks.value = media.availableAudioTracks;
    qualityOptions.value = media.availableQualities;
    activeQuality.value = media.availableQualities.isNotEmpty
        ? media.availableQualities.first.label
        : null;

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

  Future<void> _reloadCurrentMedia() async {
    final media = _currentMedia;
    if (media == null) return;
    final pos = remoteState.value.positionMs;
    await castMedia(
      SenzuCastMedia(
        url: media.url,
        title: media.title,
        description: media.description,
        posterUrl: media.posterUrl,
        subtitleUrl: media.subtitleUrl,
        positionMs: pos,
        isLive: media.isLive,
      ),
    );
  }

  Future<void> setSubtitle(int trackId) async {
    await SenzuCastService.setSubtitleTrack(trackId);
    activeSubtitleTrackId.value = trackId;
  }

  Future<void> disableSubtitles() async {
    await SenzuCastService.disableSubtitles();
    activeSubtitleTrackId.value = null;
  }

  Future<void> setAudioTrack(int trackId) async {
    await SenzuCastService.setAudioTrack(trackId);
    activeAudioTrackId.value = trackId;
  }

  Future<void> setCastVolume(double volume) =>
      SenzuCastService.setVolume(volume);

  Future<void> switchQuality(String label) async {
    final q = qualityOptions.firstWhereOrNull((o) => o.label == label);
    if (q == null) return;
    final pos = remoteState.value.positionMs;
    await SenzuCastService.loadQuality(
      q.url,
      headers: q.headers,
      positionMs: pos,
    );
    activeQuality.value = label;
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
      positionMs: currentPosition.inMilliseconds,
      isLive: media.isLive,
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