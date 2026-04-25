import 'package:flutter/material.dart';
import 'package:senzu_player/src/data/language/language.dart';

// ── Progress bar ──────────────────────────────────────────────────────────────
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

// ── Cellular warning ──────────────────────────────────────────────────────────
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

// ── Settings panel ────────────────────────────────────────────────────────────
class SenzuSettingsPanelStyle {
  const SenzuSettingsPanelStyle({
    this.panelDecoration = const BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.all(Radius.circular(0)),
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

// ── HDR badge ─────────────────────────────────────────────────────────────────
class SenzuHdrBadgeStyle {
  const SenzuHdrBadgeStyle({
    this.decoration = const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    ),
  });

  final BoxDecoration decoration;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
}

// ── Live badge ────────────────────────────────────────────────────────────────
class SenzuLiveBadgeStyle {
  const SenzuLiveBadgeStyle({
    this.liveColor = Colors.red,
    this.dvrOffColor = const Color(0xFF9E9E9E),
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    ),
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  final Color liveColor;
  final Color dvrOffColor;
  final TextStyle textStyle;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
}

// ── Sleep timer badge ─────────────────────────────────────────────────────────
class SenzuSleepBadgeStyle {
  const SenzuSleepBadgeStyle({
    this.decoration = const BoxDecoration(
      color: Color(0x8A000000),
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    this.icon = const Icon(Icons.bedtime, color: Colors.white70, size: 14),
    this.textStyle = const TextStyle(color: Colors.white, fontSize: 12),
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  final BoxDecoration decoration;
  final Icon icon;
  final TextStyle textStyle;
  final EdgeInsetsGeometry padding;
}

// ── PIP button ────────────────────────────────────────────────────────────────
class SenzuPipButtonStyle {
  const SenzuPipButtonStyle({
    this.enterIcon = Icons.picture_in_picture_alt_rounded,
    this.exitIcon = Icons.picture_in_picture_alt_outlined,
    this.iconColor = Colors.white,
    this.iconSize = 20.0,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  final IconData enterIcon;
  final IconData exitIcon;
  final Color iconColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
}

// ── Error overlay ─────────────────────────────────────────────────────────────
class SenzuErrorStyle {
  const SenzuErrorStyle({
    this.icon = const Icon(
      Icons.error_outline,
      color: Colors.white60,
      size: 48,
    ),
    this.titleStyle = const TextStyle(color: Colors.white, fontSize: 14),
    this.messageStyle = const TextStyle(color: Colors.white54, fontSize: 11),
    this.buttonStyle,
    this.backroundColor = Colors.black,
    this.refreshIcon = const Icon(Icons.refresh, size: 18),
  });

  final Icon icon;
  final Icon refreshIcon;
  final TextStyle titleStyle;
  final TextStyle messageStyle;
  final Color backroundColor;

  /// Null → uses a default white24 ElevatedButton style.
  final ButtonStyle? buttonStyle;
}

// ── Error overlay ─────────────────────────────────────────────────────────────
class SenzuAnnotationStyle {
  const SenzuAnnotationStyle({
    this.padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.decoration = const BoxDecoration(
      color: Color(0xB3000000), // 0.7 alpha black
      borderRadius: BorderRadius.all(Radius.circular(8)),
      border: Border.fromBorderSide(BorderSide(color: Colors.white24)),
    ),
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
    ),
  });

  final EdgeInsetsGeometry padding;
  final BoxDecoration decoration;
  final TextStyle textStyle;
}

// ── Speed toast ───────────────────────────────────────────────────────────────
class SenzuSpeedToastStyle {
  const SenzuSpeedToastStyle({
    this.backgroundColor = const Color(0x59000000),
    this.textStyle = const TextStyle(color: Colors.white, fontSize: 13),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.topAlignment = -0.7,
  });

  final Color backgroundColor;
  final TextStyle textStyle;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double topAlignment;
}

// ── Volume / brightness toast ─────────────────────────────────────────────────
class SenzuVBToastStyle {
  const SenzuVBToastStyle({
    this.iconColor = Colors.white,
    this.iconSize = 20.0,
    this.barWidth = 80.0,
    this.barHeight = 4.0,
    this.barBackgroundColor = Colors.white30,
    this.barForegroundColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.topAlignment = -0.65,
    this.decoration = const BoxDecoration(
      color: Color(0x73000000),
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    this.volume0 = Icons.volume_off,
    this.volume50 = Icons.volume_down,
    this.volume100 = Icons.volume_up,
    this.brightness0 = Icons.brightness_low,
    this.brightness50 = Icons.brightness_medium,
    this.brightness100 = Icons.brightness_high,
  });

  final BoxDecoration decoration;
  final Color iconColor;
  final double iconSize;
  final double barWidth;
  final double barHeight;
  final Color barBackgroundColor;
  final Color barForegroundColor;
  final EdgeInsetsGeometry padding;
  final double topAlignment;
  final IconData volume0;
  final IconData volume50;
  final IconData volume100;
  final IconData brightness0;
  final IconData brightness50;
  final IconData brightness100;
}

// ── Buffer loader ─────────────────────────────────────────────────────────────
class SenzuBufferLoaderStyle {
  const SenzuBufferLoaderStyle({
    this.backgroundColor = const Color(0xFF0A0A0A),
    this.brandColor = const Color(0xFF00CA13),
    this.textStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
    ),
  });

  final Color backgroundColor;
  final Color brandColor;
  final TextStyle textStyle;
}

// ── Overlay Icons ─────────────────────────────────────────────────────────────
class SenzuOverlayIconsStyle {
  const SenzuOverlayIconsStyle({
    this.sleep =
        const Icon(Icons.bedtime_outlined, size: 20, color: Colors.white),
    this.aspect = const Icon(Icons.aspect_ratio, size: 20, color: Colors.white),
    this.speed = const Icon(Icons.speed, size: 20, color: Colors.white),
    this.caption =
        const Icon(Icons.closed_caption, size: 20, color: Colors.white),
    this.quality = const Icon(Icons.hd, size: 20, color: Colors.white),
    this.audio = const Icon(Icons.audiotrack, size: 20, color: Colors.white),
    this.episode = const Icon(Icons.view_list, size: 20, color: Colors.white),
    this.fullscreenExit = const Icon(Icons.fullscreen_exit, size: 20, color: Colors.white),
    this.fullscreen = const Icon(Icons.fullscreen, size: 20, color: Colors.white),
    this.castConnected = const Icon(Icons.cast_connected, size: 20, color: Colors.green),
    this.cast = const Icon(Icons.cast, size: 20, color: Colors.white),
    this.castNoDevicesAvailable = const Icon(Icons.cast, size: 20, color: Colors.white38),
  });

  final Icon sleep;
  final Icon aspect;
  final Icon speed;
  final Icon caption;
  final Icon quality;
  final Icon audio;
  final Icon episode;
  final Icon fullscreenExit;
  final Icon fullscreen;
  final Icon castConnected;
  final Icon cast;
  final Icon castNoDevicesAvailable;
}

// ── Status bar ─────────────────────────────────────────────────────────────
class SenzuStatusBarStyle {
  const SenzuStatusBarStyle({
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.timeStyle = const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
    this.batteryLevelStyle = const TextStyle(color: Colors.white, fontSize: 10),
    this.chargingIcon14 = Icons.battery_0_bar,
    this.chargingIcon34 = Icons.battery_2_bar,
    this.chargingIcon54 = Icons.battery_3_bar,
    this.chargingIcon79 = Icons.battery_4_bar,
    this.chargingIcon100 = Icons.battery_full,
    this.chargingIcon = Icons.battery_charging_full,
    this.iconSize = 14,
    this.chargingIconColor = Colors.green,
    this.notChargingIconColor = Colors.white,
  });

  final EdgeInsetsGeometry padding;
  final TextStyle timeStyle;
  final TextStyle batteryLevelStyle;
  final double iconSize;
  final IconData chargingIcon14;
  final IconData chargingIcon34;
  final IconData chargingIcon54;
  final IconData chargingIcon79;
  final IconData chargingIcon100;
  final IconData chargingIcon;
  final Color chargingIconColor;
  final Color notChargingIconColor;
}

// ── Cast panel item ───────────────────────────────────────────────────────────
class SenzuCastPanelStyle {
  const SenzuCastPanelStyle({
    this.selectedColor = Colors.lightBlueAccent,
    this.unselectedColor = Colors.white,
    this.selectedCheckIcon = const Icon(
      Icons.check,
      size: 14,
      color: Colors.lightBlueAccent,
    ),
    this.textSize = 12.0,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.searchingTextStyle = const TextStyle(
      color: Colors.white38,
      fontSize: 11,
    ),
    this.noDevicesTextStyle = const TextStyle(
      color: Colors.white38,
      fontSize: 11,
    ),
    this.deviceNameTextStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
    ),
    this.deviceModelTextStyle = const TextStyle(
      color: Colors.white38,
      fontSize: 10,
    ),
    this.connectingTextStyle = const TextStyle(
      color: Colors.orangeAccent,
      fontSize: 10,
    ),
  });

  final Color selectedColor;
  final Color unselectedColor;
  final Icon selectedCheckIcon;
  final double textSize;
  final EdgeInsetsGeometry itemPadding;
  final TextStyle searchingTextStyle;
  final TextStyle noDevicesTextStyle;
  final TextStyle deviceNameTextStyle;
  final TextStyle deviceModelTextStyle;
  final TextStyle connectingTextStyle;
}

// ── Skip chapter button ───────────────────────────────────────────────────────
class SenzuSkipButtonStyle {
  const SenzuSkipButtonStyle({
    this.backgroundColor = const Color(0xFF00CA13),
    this.textColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(7)),
    this.paddingFullscreen = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 10,
    ),
    this.paddingNormal = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 5,
    ),
    this.fontSizeFullscreen = 16.0,
    this.fontSizeNormal = 11.0,
    this.fontWeight = FontWeight.w600,
  });

  final Color backgroundColor;
  final Color textColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry paddingFullscreen;
  final EdgeInsetsGeometry paddingNormal;
  final double fontSizeFullscreen;
  final double fontSizeNormal;
  final FontWeight fontWeight;
}

// ── Subtitle ──────────────────────────────────────────────────────────────────
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

// ── Center button ─────────────────────────────────────────────────────────────
class SenzuCenterButtonStyle {
  SenzuCenterButtonStyle({
    this.circleSize = 60.0,
    this.circleColor = const Color(0x4D000000),
    Icon? play,
    Icon? pause,
    Icon? replay,
    Icon? rewind,
    Icon? forward,
  })  : play =
            play ?? const Icon(Icons.play_arrow, color: Colors.white, size: 32),
        pause = pause ?? const Icon(Icons.pause, color: Colors.white, size: 32),
        replay =
            replay ?? const Icon(Icons.replay, color: Colors.white, size: 28),
        rewind = rewind ??
            const Icon(Icons.fast_rewind, color: Colors.white, size: 12),
        forward = forward ??
            const Icon(Icons.fast_forward, color: Colors.white, size: 12);

  final double circleSize;
  final Color circleColor;
  final Icon play, pause, replay, rewind, forward;
}

// ── Main player style ─────────────────────────────────────────────────────────
class SenzuPlayerStyle {
  SenzuPlayerStyle({
    SenzuProgressBarStyle? progressBarStyle,
    SenzuSubtitleStyle? subtitleStyle,
    SenzuCenterButtonStyle? centerButtonStyle,
    SenzuCellularWarningStyle? cellularWarningStyle,
    SenzuSettingsPanelStyle? settingsPanelStyle,
    SenzuHdrBadgeStyle? hdrBadgeStyle,
    SenzuLiveBadgeStyle? liveBadgeStyle,
    SenzuSleepBadgeStyle? sleepBadgeStyle,
    SenzuPipButtonStyle? pipButtonStyle,
    SenzuErrorStyle? errorStyle,
    SenzuSpeedToastStyle? speedToastStyle,
    SenzuVBToastStyle? vbToastStyle,
    SenzuBufferLoaderStyle? bufferLoaderStyle,
    SenzuCastPanelStyle? castPanelStyle,
    SenzuSkipButtonStyle? skipButtonStyle,
    SenzuAnnotationStyle? annotationStyle,
    SenzuStatusBarStyle? statusBarStyle,
    SenzuOverlayIconsStyle? overlayIconsStyle,
    SenzuLanguage? senzuLanguage,
    this.thumbnail,
    this.bottomExtra,
    this.episodeWidget,
    this.skipAdBuilder,
    this.onPrevEpisode,
    this.onNextEpisode,
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
    Widget? sleepOverlay,
  })  : progressBarStyle = progressBarStyle ?? const SenzuProgressBarStyle(),
        senzuLanguage = senzuLanguage ?? const SenzuLanguage(),
        settingsPanelStyle =
            settingsPanelStyle ?? const SenzuSettingsPanelStyle(),
        subtitleStyle = subtitleStyle ?? const SenzuSubtitleStyle(),
        hdrBadgeStyle = hdrBadgeStyle ?? const SenzuHdrBadgeStyle(),
        liveBadgeStyle = liveBadgeStyle ?? const SenzuLiveBadgeStyle(),
        sleepBadgeStyle = sleepBadgeStyle ?? const SenzuSleepBadgeStyle(),
        errorStyle = errorStyle ?? const SenzuErrorStyle(),
        speedToastStyle = speedToastStyle ?? const SenzuSpeedToastStyle(),
        vbToastStyle = vbToastStyle ?? const SenzuVBToastStyle(),
        bufferLoaderStyle = bufferLoaderStyle ?? const SenzuBufferLoaderStyle(),
        castPanelStyle = castPanelStyle ?? const SenzuCastPanelStyle(),
        skipButtonStyle = skipButtonStyle ?? const SenzuSkipButtonStyle(),
        cellularWarningStyle =
            cellularWarningStyle ?? const SenzuCellularWarningStyle(),
        centerButtonStyle = centerButtonStyle ?? SenzuCenterButtonStyle(),
        pipButtonStyle = pipButtonStyle ?? const SenzuPipButtonStyle(),
        annotationStyle = annotationStyle ?? const SenzuAnnotationStyle(),
        statusBarStyle = statusBarStyle ?? const SenzuStatusBarStyle(),
        overlayIconsStyle = overlayIconsStyle ?? const SenzuOverlayIconsStyle(),
        loading = loading ??
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: Colors.white,
              ),
            ),
        buffering = buffering ??
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: Colors.white,
              ),
            ),
        sleepOverlay = sleepOverlay ??
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bedtime,
                      color: Colors.white38,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      senzuLanguage!.sleepModeActivated,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            color: Colors.white60,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            senzuLanguage.continueWatching,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );

  final SenzuProgressBarStyle progressBarStyle;
  final SenzuLanguage senzuLanguage;
  final SenzuSettingsPanelStyle settingsPanelStyle;
  final SenzuSubtitleStyle subtitleStyle;
  final SenzuHdrBadgeStyle hdrBadgeStyle;
  final SenzuLiveBadgeStyle liveBadgeStyle;
  final SenzuSleepBadgeStyle sleepBadgeStyle;
  final SenzuCellularWarningStyle cellularWarningStyle;
  final SenzuCenterButtonStyle centerButtonStyle;
  final SenzuPipButtonStyle pipButtonStyle;
  final SenzuErrorStyle errorStyle;
  final SenzuSpeedToastStyle speedToastStyle;
  final SenzuVBToastStyle vbToastStyle;
  final SenzuBufferLoaderStyle bufferLoaderStyle;
  final SenzuCastPanelStyle castPanelStyle;
  final SenzuAnnotationStyle annotationStyle;
  final SenzuSkipButtonStyle skipButtonStyle;
  final SenzuStatusBarStyle statusBarStyle;
  final SenzuOverlayIconsStyle overlayIconsStyle;

  final Widget? thumbnail;
  final Widget? bottomExtra;
  final Widget? episodeWidget;
  final Widget Function(Duration)? skipAdBuilder;
  final AlignmentGeometry skipAdAlignment;
  final Duration transitions;
  final TextStyle textStyle;
  final Widget loading;
  final Widget buffering;
  final Widget sleepOverlay;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final bool? hasPrevEpisode;
  final bool? hasNextEpisode;
}
