import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/data/models/video_source_model.dart';
import 'package:senzu_player/src/ui/core/senzu_player_core_view.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuFeedPlayer  —  нэг feed item
// ─────────────────────────────────────────────────────────────────────────────

class SenzuFeedPlayer extends StatefulWidget {
  const SenzuFeedPlayer({
    super.key,
    required this.source,
    this.aspectRatio = 9 / 16,
    this.autoPlayThreshold = 0.5,
    this.looping = true,
    this.style,
    this.header,
    this.footer,
  });

  final Map<String, VideoSource> source;
  final double aspectRatio;
  final double autoPlayThreshold;
  final bool looping;
  final SenzuPlayerStyle? style;
  final Widget? header;
  final Widget? footer;

  @override
  State<SenzuFeedPlayer> createState() => _SenzuFeedPlayerState();
}

class _SenzuFeedPlayerState extends State<SenzuFeedPlayer> {
  SenzuPlayerBundle? _bundle;
  bool _initialized = false;
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _bundle?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    final bundle = SenzuPlayerBundle.create(
      looping: widget.looping,
      adaptiveBitrate: true,
      notification: false, // Feed-д lock screen notification хэрэггүй
    );

    if (mounted) setState(() => _bundle = bundle);

    try {
      await bundle.core.initialize(widget.source, autoPlay: false);
      if (mounted && _visible) await bundle.core.play();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onVisibility(VisibilityInfo info) {
    final shouldPlay = info.visibleFraction >= widget.autoPlayThreshold;

    if (shouldPlay && !_visible) {
      _visible = true;
      if (!_initialized) {
        _init();
      } else {
        _bundle?.core.play();
      }
    } else if (!shouldPlay && _visible) {
      _visible = false;
      _bundle?.core.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.key ?? ValueKey(widget.source.values.first.dataSource),
      onVisibilityChanged: _onVisibility,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      );
    }

    final bundle = _bundle;
    if (bundle == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white38,
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    final style = widget.style ?? SenzuPlayerStyle();

    return Stack(
      children: [
        SenzuPlayerCoreView(
          bundle: bundle,
          style: style,
          meta: SenzuMetaData(show: false),
          enableCaption: false,
          enableQuality: false,
          enableAudio: false,
          enableSpeed: false,
          enableAspect: false,
          enableFullscreen: false,
          enablePip: false,
          enableLock: false,
          enableEpisode: false,
          defaultAspectRatio: widget.aspectRatio,
        ),
        // Header (хэрэглэгчийн нэр, дүрс гэх мэт)
        if (widget.header != null)
          Positioned(top: 0, left: 0, right: 0, child: widget.header!),
        // Footer (like, comment, share)
        if (widget.footer != null)
          Positioned(bottom: 0, left: 0, right: 0, child: widget.footer!),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SenzuFeedList  —  TikTok/Reels хэв маяг (PageView)
// ─────────────────────────────────────────────────────────────────────────────

class SenzuFeedList extends StatefulWidget {
  const SenzuFeedList({
    super.key,
    required this.sources,
    this.aspectRatio = 9 / 16,
    this.looping = true,
    this.style,
    this.onPageChanged,
    this.headerBuilder,
    this.footerBuilder,
  });

  final List<Map<String, VideoSource>> sources;
  final double aspectRatio;
  final bool looping;
  final SenzuPlayerStyle? style;
  final void Function(int)? onPageChanged;

  /// Хуудас бүрийн дээд хэсэг (хэрэглэгчийн мэдээлэл)
  final Widget? Function(BuildContext, int)? headerBuilder;

  /// Хуудас бүрийн доод хэсэг (like, share гэх мэт)
  final Widget? Function(BuildContext, int)? footerBuilder;

  @override
  State<SenzuFeedList> createState() => _SenzuFeedListState();
}

class _SenzuFeedListState extends State<SenzuFeedList> {
  final _ctrl = PageController();

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _ctrl,
      scrollDirection: Axis.vertical,
      itemCount: widget.sources.length,
      onPageChanged: widget.onPageChanged,
      // addAutomaticKeepAlives: false — dispose хурдан болно
      // addRepaintBoundaries: true — default, page isolation хийнэ
      itemBuilder: (ctx, i) {
        return RepaintBoundary(
          // GPU layer isolation
          child: SenzuFeedPlayer(
            key: PageStorageKey('feed_$i'), // ValueKey биш PageStorageKey
            source: widget.sources[i],
            aspectRatio: widget.aspectRatio,
            looping: widget.looping,
            style: widget.style,
            header: widget.headerBuilder?.call(ctx, i),
            footer: widget.footerBuilder?.call(ctx, i),
          ),
        );
      },
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// SenzuScrollFeed  —  Instagram/Twitter хэв маяг (ListView)
// ─────────────────────────────────────────────────────────────────────────────

class SenzuScrollFeed extends StatelessWidget {
  const SenzuScrollFeed({
    super.key,
    required this.sources,
    this.aspectRatio = 16 / 9,
    this.looping = true,
    this.style,
    this.headerBuilder,
    this.footerBuilder,
    this.padding,
    this.physics,
    this.controller,
  });

  final List<Map<String, VideoSource>> sources;
  final double aspectRatio;
  final bool looping;
  final SenzuPlayerStyle? style;
  final Widget? Function(BuildContext, int)? headerBuilder;
  final Widget? Function(BuildContext, int)? footerBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding ?? EdgeInsets.zero,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      controller: controller,
      itemCount: sources.length,
      // CacheExtent: screen height-ийн 0.5x — memory vs smoothness balance
      cacheExtent: MediaQuery.of(context).size.height * 0.5,
      addRepaintBoundaries: true,
      itemBuilder: (ctx, i) => RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // Column height minimize
          children: [
            if (headerBuilder != null)
              headerBuilder!(ctx, i) ?? const SizedBox.shrink(),
            SenzuFeedPlayer(
              key: PageStorageKey('scroll_$i'),
              source: sources[i],
              aspectRatio: aspectRatio,
              looping: looping,
              style: style,
            ),
            if (footerBuilder != null)
              footerBuilder!(ctx, i) ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
