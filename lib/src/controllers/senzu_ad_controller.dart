import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';
import 'package:senzu_player/src/data/models/ad_model.dart';
import 'package:senzu_player/src/platform/senzu_native_video_state.dart';
import 'senzu_core_controller.dart';
import 'senzu_playback_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuAdController  —  Ad overlay + IMA SDK
// ─────────────────────────────────────────────────────────────────────────────

class SenzuAdController extends GetxController {
  SenzuAdController({required this.core, required this.playback});

  final SenzuCoreController core;
  final SenzuPlaybackController playback;

  // ── Rx ────────────────────────────────────────────────────────────────────
  final activeAd = Rxn<SenzuPlayerAd>();
  final isAdActive = false.obs;
  final adTimeWatched = Rxn<Duration>();
  final shouldShowAd = false.obs;
  final isAdLoaded = false.obs;
  final isAdInitializing = false.obs;
  // FIX: default false — video is hidden until explicitly shown
  final shouldShowContentVideo = false.obs;
  final adDisplayContainer = Rxn<AdDisplayContainer>();
  final totalAds = 0.obs;

  // ── Private ────────────────────────────────────────────────────────────────
  List<SenzuPlayerAd> _pendingAds = [];
  final List<SenzuPlayerAd> adsSeen = [];

  String? _imaAdTagUrl;
  AdsLoader? _adsLoader;
  AdsManager? _adsManager;
  Timer? _adTimer;
  Timer? _adCheckTimer;
  Timer? _contentProgressTimer;
  final _contentProgressProvider = ContentProgressProvider();
  bool _isProcessingAd = false;
  Duration _lastCheckedPos = Duration.zero;
  final _queuedAds = <SenzuPlayerAd>[];
  StreamSubscription<SenzuNativeVideoState>? _adStreamSub;
  Duration _lastAdCheckPos = Duration.zero;

  int get currentAdIndex => adsSeen.length;

  @override
  void onInit() {
    super.onInit();
    shouldShowContentVideo.value = true;

    core.onPendingAdsChanged = (ads) {
      final filtered = ads.whereType<SenzuPlayerAd>().toList();
      totalAds.value = filtered.length;
      _pendingAds = filtered.where((a) => !adsSeen.any((s) => s == a)).toList();
      // Timer биш: pending ads байвал stream listener нэмнэ
      _attachAdStreamListener();
    };

    core.onSourceChanged = (name) {
      _lastCheckedPos = Duration.zero;
      _pendingAds.clear();
      adsSeen.clear();
      _queuedAds.clear();
      _detachAdStreamListener();
      if (isAdActive.value) _forceEndAd();
      shouldShowContentVideo.value = true;
    };
  }

  void _attachAdStreamListener() {
    if (_adStreamSub != null) return; // Already listening

    _adStreamSub = core.rxNativeState.listen((state) {
      if (_pendingAds.isEmpty || isAdActive.value) {
        _detachAdStreamListener();
        return;
      }
      // Playback stream-ийн interval = 200ms
      // Жижиг optimization: 200ms-д position change мэдэгдэхүйц байхгүй бол skip
      final pos = state.position;
      if ((pos - _lastAdCheckPos).abs().inMilliseconds < 150) return;
      _lastAdCheckPos = pos;
      _findAd();
    });
  }

  void _detachAdStreamListener() {
    _adStreamSub?.cancel();
    _adStreamSub = null;
  }

  void _forceEndAd() {
    _adTimer?.cancel();
    _isProcessingAd = false;
    isAdActive.value = false;
    activeAd.value = null;
    adTimeWatched.value = null;
    shouldShowContentVideo.value = true;
  }

  void _findAd() {
    if (_isProcessingAd || isAdActive.value) return;
    if (playback.isDragging.value) return;

    final pos = playback.position.value;
    final dur = playback.duration.value;
    if (dur == Duration.zero) return;

    final from = _lastCheckedPos;
    final to = pos;
    _lastCheckedPos = pos;

    if (to < from) return;

    final triggered = <SenzuPlayerAd>[];
    for (final ad in List<SenzuPlayerAd>.from(_pendingAds)) {
      final start = ad.durationToStart ?? (dur * ad.fractionToStart!);
      if (start >= from && start <= to) {
        triggered.add(ad);
        _pendingAds.remove(ad);
        adsSeen.add(ad);
      }
    }

    if (triggered.isEmpty) return;

    triggered.sort((a, b) {
      final aStart = a.durationToStart ?? (dur * a.fractionToStart!);
      final bStart = b.durationToStart ?? (dur * b.fractionToStart!);
      return bStart.compareTo(aStart);
    });

    _queuedAds.clear();
    _queuedAds.addAll(triggered.sublist(1));
    _triggerAd(triggered.first);
  }

  void _triggerAd(SenzuPlayerAd ad) {
    _isProcessingAd = true;

    // FIX: Эхлээд video нуу, ДАРАА нь pause хий
    shouldShowContentVideo.value = false;
    isAdActive.value = true;
    activeAd.value = ad;

    Future.microtask(() async {
      // pause нь async тул video нуусны дараа дуудна
      await core.pause();
      _isProcessingAd = false;
    });

    _startAdTimer();

    if (_pendingAds.isEmpty && _queuedAds.isEmpty) {
      _adCheckTimer?.cancel();
      _adCheckTimer = null;
    }
  }

  void _startAdTimer() {
    const tick = Duration(milliseconds: 500);
    _adTimer?.cancel();
    adTimeWatched.value = Duration.zero;
    _adTimer = Timer.periodic(tick, (t) {
      adTimeWatched.value = (adTimeWatched.value ?? Duration.zero) + tick;
      if (activeAd.value != null &&
          adTimeWatched.value! >= activeAd.value!.durationToSkip) {
        t.cancel();
      }
    });
  }

  Future<void> skipAd() async {
    if (!isAdActive.value) return;
    _adTimer?.cancel();
    _isProcessingAd = false;
    isAdActive.value = false;
    activeAd.value = null;
    adTimeWatched.value = null;

    if (_queuedAds.isNotEmpty) {
      final next = _queuedAds.removeLast();
      _triggerAd(next);
      return;
    }

    shouldShowContentVideo.value = true;
    _lastCheckedPos = playback.position.value;
    await core.play();
  }

  // ── IMA ────────────────────────────────────────────────────────────────────

  void setImaAdTagUrl(String url) => _imaAdTagUrl = url;

  void setupAdDisplayContainer() {
    isAdInitializing.value = true;
    // IMA үед content видео харуулахгүй
    shouldShowContentVideo.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      adDisplayContainer.value = AdDisplayContainer(
        onContainerAdded: _onContainerAdded,
      );
    });
  }

  void _onContainerAdded(AdDisplayContainer container) {
    if (_imaAdTagUrl == null || _imaAdTagUrl!.isEmpty) {
      isAdInitializing.value = false;
      shouldShowContentVideo.value = true;
      return;
    }
    core.pause();
    _adsLoader = AdsLoader(
      container: container,
      onAdsLoaded: (OnAdsLoadedData data) {
        isAdInitializing.value = false;
        _adsManager = data.manager;
        _adsManager!.setAdsManagerDelegate(
          AdsManagerDelegate(onAdEvent: _onAdEvent, onAdErrorEvent: _onAdError),
        );
        _adsManager!.init(settings: AdsRenderingSettings());
      },
      onAdsLoadError: (AdsLoadErrorData data) {
        debugPrint('IMA load error: ${data.error.message}');
        isAdInitializing.value = false;
        isAdLoaded.value = false;
        shouldShowContentVideo.value = true;
      },
    );
    _requestAds(container);
  }

  void _onAdEvent(AdEvent event) async {
    switch (event.type) {
      case AdEventType.loaded:
        isAdLoaded.value = true;
      case AdEventType.contentPauseRequested:
        await _pauseContent();
        _adsManager?.start();
      case AdEventType.contentResumeRequested:
        isAdLoaded.value = false;
        await _resumeContent();
      case AdEventType.allAdsCompleted:
        _adsLoader?.contentComplete();
        _adsManager?.destroy();
        _adsManager = null;
        isAdLoaded.value = false;
        shouldShowContentVideo.value = true;
      default:
        break;
    }
  }

  void _onAdError(AdErrorEvent event) {
    debugPrint('IMA Ad error: ${event.error.message}');
    isAdInitializing.value = false;
    isAdLoaded.value = false;
    _resumeContent();
  }

  Future<void> _requestAds(AdDisplayContainer container) async {
    if (_imaAdTagUrl == null) return;
    await _adsLoader?.requestAds(
      AdsRequest(
        adTagUrl: _imaAdTagUrl!,
        contentProgressProvider: _contentProgressProvider,
      ),
    );
  }

  Future<void> _pauseContent() async {
    shouldShowContentVideo.value = false;
    shouldShowAd.value = true;
    _contentProgressTimer?.cancel();
    _contentProgressTimer = null;
    core.pause();
    await Future.microtask(() {});
  }

  Future<void> _resumeContent() async {
    shouldShowAd.value = false;
    if (_adsManager != null) {
      _contentProgressTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) async {
          final v = core.rxNativeState;
          if (!v.value.isInitialized) return;
          await _contentProgressProvider.setProgress(
            progress: v.value.position,
            duration: v.value.duration,
          );
        },
      );
    }
    shouldShowContentVideo.value = true;
    await core.play();
  }

  @override
  void onClose() {
    _detachAdStreamListener();

    _adCheckTimer?.cancel();
    _adCheckTimer = null;
    _adTimer?.cancel();
    _contentProgressTimer?.cancel();
    core.onPendingAdsChanged = null;
    _adsManager?.destroy();
    _adsManager = null;
    _queuedAds.clear();
    try {
      _adsLoader?.contentComplete();
    } catch (_) {}
    _adsLoader = null;
    super.onClose();
  }
}
