import 'package:flutter/material.dart';

import 'package:senzu_player/src/data/models/video_source_model.dart';
import 'package:senzu_player/src/data/models/senzu_annotation_model.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/ui/core/senzu_player_core_view.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/data/models/senzu_watermark.dart';
import 'package:senzu_player/src/data/models/senzu_token_provider.dart';
import 'package:senzu_player/src/data/models/senzu_player_config.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';

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
export 'package:senzu_player/src/data/models/senzu_metadata.dart';
export 'package:senzu_player/src/controllers/senzu_ui_controller.dart'
    show SenzuPanel;

class SenzuPlayer extends StatefulWidget {
  const SenzuPlayer({
    super.key,
    required this.source,
    this.seekTo = Duration.zero,
    this.looping = false,
    this.autoPlay = true,
    this.isLive,
    this.style,
    this.meta,
    this.chapters = const [],
    
    this.defaultAspectRatio = 16 / 9,
    this.enableFullscreen = true,
    this.enableCaption = true,
    this.enableQuality = true,
    this.enableAudio = false,
    this.enableSpeed = true,
    this.enableAspect = true,
    this.enableLock = true,
    this.enableEpisode = true,
    this.enablePip = true,
    this.notification = true,
    this.secureMode = false,
    this.enableLockScreen = true,
    this.adaptiveBitrate = true,
    this.minBufferThreshold = 10,
    this.maxBufferThreshold = 30,
    this.onQualityChanged,
    this.dataPolicy = const SenzuDataPolicy(),
    this.watermark,
    this.tokenConfig,
    this.imaAdTagUrl,
    this.annotations = const [],
    this.bundle,
  });

  final SenzuWatermark? watermark;
  final SenzuDataPolicy dataPolicy;
  final SenzuTokenConfig? tokenConfig;

  final Map<String, VideoSource> source;
  final Duration seekTo;
  final bool looping;
  final bool autoPlay;
  final bool? isLive;

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
      enableEpisode;

  final bool notification;
  final bool secureMode;
  final bool enableLockScreen;

  final String? imaAdTagUrl;

  final bool adaptiveBitrate;
  final int minBufferThreshold;
  final int maxBufferThreshold;
  final void Function(String)? onQualityChanged;

  final List<SenzuAnnotation> annotations;
  final SenzuPlayerBundle? bundle;

  @override
  State<SenzuPlayer> createState() => _SenzuPlayerState();
}

class _SenzuPlayerState extends State<SenzuPlayer> {
  late final SenzuPlayerBundle _bundle;
  late final SenzuPlayerStyle _style;
  late final SenzuMetaData _meta;
  late final bool _ownsBundle;

  bool _initialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _style = widget.style ?? SenzuPlayerStyle();
    _meta = widget.meta ?? SenzuMetaData();

    if (widget.bundle != null) {
      _bundle = widget.bundle!;
      _ownsBundle = false;
    } else {
      _bundle = SenzuPlayerBundle.create(
        looping: widget.looping,
        adaptiveBitrate: widget.adaptiveBitrate,
        minBufferSec: widget.minBufferThreshold,
        maxBufferSec: widget.maxBufferThreshold,
        secureMode: widget.secureMode,
        onQualityChanged: widget.onQualityChanged,
        watermark: widget.watermark,
        dataPolicy: widget.dataPolicy,
        tokenConfig: widget.tokenConfig,
        annotations: widget.annotations,
        notification: widget.notification,
      );
      _ownsBundle = true;
    }

    _init();
  }

  @override
  void dispose() {
    if (_ownsBundle) {
      _bundle.dispose();
      if (widget.enablePip) SenzuNativeChannel.disablePip();
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _bundle.ui.isShowingThumbnail.value = _style.thumbnail != null;

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

      if (widget.enablePip) await SenzuNativeChannel.enablePip();

      if (!mounted) return;
      setState(() {
        _initialized = true;
        _initError = null;
      });
    } catch (e) {
      if (!mounted) return;
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

    return AspectRatio(
      aspectRatio: widget.defaultAspectRatio,
      child: _initialized
          ? SenzuPlayerCoreView(
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
            )
          : _loadingWidget(),
    );
  }

  Widget _loadingWidget() => Stack(
        children: [
          if (_style.thumbnail != null) Positioned.fill(child: _style.thumbnail!),
          Positioned(top: 16, left: 16, child: _BackBtn()),
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

  Widget _errorWidget() => AspectRatio(
        aspectRatio: widget.defaultAspectRatio,
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white60, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _style.senzuLanguage.failedToLoad,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _initError!,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(_style.senzuLanguage.retry),
                    ),
                  ],
                ),
              ),
              Positioned(top: 16, left: 16, child: _BackBtn()),
            ],
          ),
        ),
      );
}

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
      );
}