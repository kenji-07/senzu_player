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
    this.positionColor = Colors.white,
  });
  final double height;
  final double dotSize;
  final Color color;
  final Color bufferedColor;
  final Color backgroundColor;
  final Color dotColor;
  final BorderRadius borderRadius;
  final Color tooltipBgColor;
  final Color positionColor;
}

class SenzuCellularWarningStyle {
  const SenzuCellularWarningStyle({
    this.decoration = const BoxDecoration(
      color: Color(0xFF1A1A1A),
      borderRadius: BorderRadius.all(Radius.circular(16)),
      border: Border.fromBorderSide(BorderSide(color: Colors.white12)),
    ),
    this.icon = const Icon(
      Icons.signal_cellular_alt,
      color: Colors.orangeAccent,
      size: 36,
    ),
    this.titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    this.bodyStyle = const TextStyle(
      color: Colors.white60,
      fontSize: 13,
      height: 1.5,
    ),
  });

  final BoxDecoration decoration;
  final Icon icon;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
}

class SenzuSettingsPanelStyle {
  const SenzuSettingsPanelStyle({
    this.panelDecoration = const BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    this.panelPadding = const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    this.titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.normal,
    ),
    this.selectedTextColor = Colors.red,
    this.unselectedTextColor = Colors.white,
    this.selectedTextSize = 12,
    this.selectedIcon = const Icon(
      Icons.multitrack_audio,
      size: 16,
      color: Colors.red,
    ),
  });

  final BoxDecoration panelDecoration;
  final EdgeInsetsGeometry panelPadding;
  final TextStyle titleStyle;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final double selectedTextSize;
  final Icon selectedIcon;
}

class SenzuHdrBadgeStyle {
  const SenzuHdrBadgeStyle({
    this.decoration = const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    this.textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    ),
  });

  final BoxDecoration decoration;
  final TextStyle textStyle;
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
    SenzuCellularWarningStyle? cellularWarningStyle,
    SenzuSettingsPanelStyle? settingsPanelStyle,
    SenzuHdrBadgeStyle? hdrBadgeStyle,
    SenzuLanguage? senzuLanguage,
    this.exitPipIcon = Icons.picture_in_picture_alt_outlined,
    this.enterPipIcon = Icons.picture_in_picture_alt_rounded,
    this.pipIconColor = Colors.white,
    this.pipIconSize = 20,
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
       settingsPanelStyle =
           settingsPanelStyle ?? const SenzuSettingsPanelStyle(),
       subtitleStyle = subtitleStyle ?? const SenzuSubtitleStyle(),
       hdrBadgeStyle = hdrBadgeStyle ?? const SenzuHdrBadgeStyle(),
       cellularWarningStyle =
           cellularWarningStyle ?? const SenzuCellularWarningStyle(),
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
  final SenzuSettingsPanelStyle settingsPanelStyle;
  final SenzuSubtitleStyle subtitleStyle;
  final SenzuHdrBadgeStyle hdrBadgeStyle;
  final SenzuCellularWarningStyle cellularWarningStyle;
  final SenzuCenterButtonStyle centerButtonStyle;
  final Widget? thumbnail;
  final Widget? bottomExtra;
  final Widget? episodeWidget;
  final Widget Function(Duration)? skipAdBuilder;
  final AlignmentGeometry skipAdAlignment;
  final IconData exitPipIcon;
  final IconData enterPipIcon;
  final Color pipIconColor;
  final double pipIconSize;
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
