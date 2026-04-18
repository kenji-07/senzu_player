import 'package:flutter/material.dart';
import 'package:senzu_player/src/data/language/language.dart';

class SenzuProgressBarStyle {
  const SenzuProgressBarStyle({
    this.height = 4.0,
    this.dotSize = 6.0,
    this.color = Colors.red,
    this.bufferedColor = const Color(0x4DFFFFFF),
    this.backgroundColor = const Color(0x33FFFFFF),
    this.dotColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.tooltipBgColor = Colors.black87,
  });
  final double height;
  final double dotSize;
  final Color color;
  final Color bufferedColor;
  final Color backgroundColor;
  final Color dotColor;
  final BorderRadius borderRadius;
  final Color tooltipBgColor;
}

class SenzuSubtitleStyle {
  const SenzuSubtitleStyle({
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      backgroundColor: Colors.black54,
      height: 1.3,
    ),
    this.alignment = Alignment.bottomCenter,
    this.textAlign = TextAlign.center,
    this.padding = const EdgeInsets.only(bottom: 8),
  });
  final TextStyle textStyle;
  final AlignmentGeometry alignment;
  final TextAlign textAlign;
  final EdgeInsetsGeometry padding;
}

class SenzuCenterButtonStyle {
  SenzuCenterButtonStyle({
    this.circleSize = 60.0,
    this.circleColor = const Color(0x4D000000),
    Widget? play,
    Widget? pause,
    Widget? replay,
    Widget? rewind,
    Widget? forward,
  }) : play =
           play ?? const Icon(Icons.play_arrow, color: Colors.white, size: 32),
       pause = pause ?? const Icon(Icons.pause, color: Colors.white, size: 32),
       replay =
           replay ?? const Icon(Icons.replay, color: Colors.white, size: 28),
       rewind =
           rewind ??
           const Icon(Icons.fast_rewind, color: Colors.white, size: 12),
       forward =
           forward ??
           const Icon(Icons.fast_forward, color: Colors.white, size: 12);

  final double circleSize;
  final Color circleColor;
  final Widget play, pause, replay, rewind, forward;
}

class SenzuPlayerStyle {
  SenzuPlayerStyle({
    SenzuProgressBarStyle? progressBarStyle,
    SenzuSubtitleStyle? subtitleStyle,
    SenzuCenterButtonStyle? centerButtonStyle,
    SenzuLanguage? senzuLanguage,
    this.thumbnail,
    this.bottomExtra,
    this.episodeWidget,
    this.skipAdBuilder,
    this.onPrevEpisode,
    this.onNextEpisode,
    // ── Episode navigation state ──────────────────────────────────────────
    // null = always enabled (backward compat)
    // false = disabled (dimmed, not tappable)
    // true = enabled
    this.hasPrevEpisode,
    this.hasNextEpisode,
    this.skipAdAlignment = Alignment.bottomRight,
    this.transitions = const Duration(milliseconds: 400),
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
    Widget? loading,
    Widget? buffering,
  }) : progressBarStyle = progressBarStyle ?? const SenzuProgressBarStyle(),
       senzuLanguage = senzuLanguage ?? const SenzuLanguage(),
       subtitleStyle = subtitleStyle ?? const SenzuSubtitleStyle(),
       centerButtonStyle = centerButtonStyle ?? SenzuCenterButtonStyle(),
       loading =
           loading ??
           const Center(
             child: CircularProgressIndicator(
               strokeWidth: 1.6,
               color: Colors.white,
             ),
           ),
       buffering =
           buffering ??
           const Center(
             child: CircularProgressIndicator(
               strokeWidth: 1.6,
               color: Colors.white,
             ),
           );

  final SenzuProgressBarStyle progressBarStyle;
  final SenzuLanguage senzuLanguage;
  final SenzuSubtitleStyle subtitleStyle;
  final SenzuCenterButtonStyle centerButtonStyle;
  final Widget? thumbnail;
  final Widget? bottomExtra;
  final Widget? episodeWidget;
  final Widget Function(Duration)? skipAdBuilder;
  final AlignmentGeometry skipAdAlignment;
  final Duration transitions;
  final TextStyle textStyle;
  final Widget loading;
  final Widget buffering;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;

  /// If null → button visibility follows whether callback is non-null (old behavior).
  /// If false → button is shown but greyed out / disabled.
  /// If true → button is shown and active.
  ///
  /// Use case:
  ///   hasPrevEpisode: currentIndex > 0
  ///   hasNextEpisode: currentIndex < totalEpisodes - 1
  final bool? hasPrevEpisode;
  final bool? hasNextEpisode;
}
