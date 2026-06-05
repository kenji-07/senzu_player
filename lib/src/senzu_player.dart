import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:senzu_player/src/data/models/video_source_model.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/ui/core/senzu_player_core_view.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/ui/widgets/senzu_error_view.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';
import 'package:senzu_player/src/ui/tv/senzu_tv_core_view.dart';

// ── Barrel exports ────────────────────────────────────────────────────────────
export 'package:senzu_player/src/data/models/ad_model.dart';
export 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
export 'package:senzu_player/src/data/models/senzu_drm_config.dart';
export 'package:senzu_player/src/data/models/senzu_annotation_model.dart';
export 'package:senzu_player/src/data/models/subtitle_model.dart';
export 'package:senzu_player/src/data/models/video_source_model.dart';
export 'package:senzu_player/src/ui/widgets/senzu_style.dart';
export 'package:senzu_player/src/ui/core/senzu_player_core_view.dart';
export 'package:senzu_player/src/data/models/senzu_watermark.dart';
export 'package:senzu_player/src/data/models/senzu_token_provider.dart';
export 'package:senzu_player/src/data/models/senzu_player_config.dart';
export 'package:senzu_player/src/data/models/senzu_thumbnail_sprite.dart';
export 'package:senzu_player/src/data/language/language.dart';
export 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
export 'package:senzu_player/src/controllers/senzu_downloader.dart';
export 'package:senzu_player/src/data/database/download_database.dart'
    show DownloadTask;
export 'package:senzu_player/src/cast/senzu_cast_controller.dart';
export 'package:senzu_player/src/cast/senzu_cast_service.dart';
export 'package:senzu_player/src/data/models/senzu_metadata.dart';
export 'package:senzu_player/src/cast/senzu_cast_media_builder.dart';
export 'package:senzu_player/src/controllers/senzu_ui_controller.dart'
    show SenzuPanel;

class SenzuPlayer extends StatefulWidget {
  const SenzuPlayer({
    super.key,
    required this.source,
    required this.bundle,
    this.seekTo = Duration.zero,
    this.autoPlay = false,
    this.isTv = false,
    this.isLive = false,
    this.style,
    this.meta,
    this.chapters = const [],
    this.defaultAspectRatio = 16 / 9,
    this.enableFullscreen = true,
    this.enableCaption = true,
    this.enableSleep = true,
    this.enableQuality = true,
    this.enableAudio = false,
    this.enableSpeed = true,
    this.enableAspect = true,
    this.enableLock = true,
    this.enableEpisode = true,
    this.enablePip = true,
    this.imaAdTagUrl,
    this.castController,
  });

  final Map<String, VideoSource> source;
  final Duration seekTo;
  final bool autoPlay;
  final bool? isLive;
  final bool isTv;

  final SenzuPlayerStyle? style;
  final SenzuMetaData? meta;
  final double defaultAspectRatio;

  final List<SenzuChapter> chapters;

  final bool enableFullscreen,
      enableCaption,
      enableQuality,
      enableAudio,
      enableSpeed,
      enableAspect,
      enableLock,
      enablePip,
      enableSleep,
      enableEpisode;

  final String? imaAdTagUrl;

  final SenzuPlayerBundle bundle;
  final SenzuCastController? castController;

  @override
  State<SenzuPlayer> createState() => _SenzuPlayerState();
}

class _SenzuPlayerState extends State<SenzuPlayer> {
  late final SenzuPlayerBundle _bundle;
  late final SenzuPlayerStyle _style;
  late final SenzuMetaData _meta;

  bool _initialized = false;
  String? _initError;

  // Fullscreen overlay
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _style = widget.style ?? SenzuPlayerStyle();
    _meta = widget.meta ?? const SenzuMetaData();

    _bundle = widget.bundle;

    ever(_bundle.core.isFullScreen, _onFullscreenChanged);

    _init();
  }

  void _onFullscreenChanged(bool isFs) {
    if (isFs) {
      _insertFullscreenOverlay();
    } else {
      _removeFullscreenOverlay();
    }
  }

  void _insertFullscreenOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black,
        child: widget.isTv
            ? SenzuTvCoreView(
                bundle: _bundle,
                style: _style,
                meta: _meta,
                chapters: widget.chapters,
              )
            : SenzuPlayerCoreView(
                bundle: _bundle,
                style: _style,
                meta: _meta,
                enableCaption: widget.enableCaption,
                enableQuality: widget.enableQuality,
                enableAudio: widget.enableAudio,
                enableSpeed: widget.enableSpeed,
                enableAspect: widget.enableAspect,
                enableFullscreen: widget.enableFullscreen,
                enablePip: widget.enablePip,
                enableLock: widget.enableLock,
                enableEpisode: widget.enableEpisode,
                defaultAspectRatio: widget.defaultAspectRatio,
                chapters: widget.chapters,
                enableSleep: widget.enableSleep,
                castController: widget.castController,
              ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    if (widget.isTv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _overlayEntry == null) return;
        FocusManager.instance.rootScope.unfocus();
      });
    }
  }

  void _removeFullscreenOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    // _bundle.dispose();
    if (widget.enablePip) SenzuNativeChannel.disablePip();

    super.dispose();
  }

  Future<void> _init() async {
    try {
      _bundle.ui.isShowingThumbnail.value = _style.thumbnail != null;

      if (widget.castController != null) {
        _bundle.core.setCastController(widget.castController!);
      }

      _bundle.core.setCastMeta(_meta);

      final bool hasAdTagUrl =
          widget.imaAdTagUrl != null && widget.imaAdTagUrl!.isNotEmpty;

      if (hasAdTagUrl) {
        _bundle.ad.setImaAdTagUrl(widget.imaAdTagUrl!);
        _bundle.ad.setupAdDisplayContainer();
      } else {
        _bundle.ad.isAdLoaded.value = false;
        _bundle.ad.isAdInitializing.value = false;
      }

      await _bundle.core.initialize(
        widget.source,
        autoPlay: widget.autoPlay,
        seekTo: widget.seekTo,
        isLive: widget.isLive,
      );

      _bundle.ui.setChapters(widget.chapters);

      if (widget.isTv) {
        _bundle.core.isFullScreen.value = true;
      }

      if (widget.enablePip) await SenzuNativeChannel.enablePip();

      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _initError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = false;
        _initError = e.toString();
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _initError = null;
      _initialized = false;
    });
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) return _errorWidget();

    return Obx(() {
      final isFs = _bundle.core.isFullScreen.value;
      return AspectRatio(
        aspectRatio: widget.defaultAspectRatio,
        child: isFs
            ? const ColoredBox(color: Colors.black)
            : _initialized
                ? widget.isTv
                    ? SenzuTvCoreView(
                        bundle: _bundle,
                        style: _style,
                        meta: _meta,
                        chapters: widget.chapters,
                      )
                    : SenzuPlayerCoreView(
                        bundle: _bundle,
                        style: _style,
                        meta: _meta,
                        enableCaption: widget.enableCaption,
                        enableQuality: widget.enableQuality,
                        enableAudio: widget.enableAudio,
                        enableSpeed: widget.enableSpeed,
                        enableAspect: widget.enableAspect,
                        enableFullscreen: widget.enableFullscreen,
                        enablePip: widget.enablePip,
                        enableLock: widget.enableLock,
                        enableEpisode: widget.enableEpisode,
                        defaultAspectRatio: widget.defaultAspectRatio,
                        chapters: widget.chapters,
                        enableSleep: widget.enableSleep,
                        castController: widget.castController,
                      )
                : _loadingWidget(),
      );
    });
  }

  Widget _loadingWidget() => Stack(
        children: [
          if (_style.thumbnail != null)
            Positioned.fill(child: _style.thumbnail!),
          const Positioned(top: 16, left: 16, child: SenzuBackButton()),
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _style.centerButtonStyle.circleColor,
              ),
              child: _style.loading,
            ),
          ),
        ],
      );

  Widget _errorWidget() => SenzuErrorView(
        errorStyle: _style.errorStyle,
        title: _style.senzuLanguage.failedToLoad,
        retryLabel: _style.senzuLanguage.retry,
        onRetry: _retry,
        message: _initError,
        aspectRatio: widget.defaultAspectRatio,
        showBackButton: true,
      );
}
