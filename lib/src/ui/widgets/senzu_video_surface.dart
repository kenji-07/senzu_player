// lib/src/widgets/senzu_video_surface.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Renders the native video surface inside the Flutter widget tree.
///
/// On Android this uses an [AndroidView] backed by ExoPlayer's SurfaceView.
/// On iOS this uses a [UiKitView] backed by AVPlayerLayer.
///
/// Replaces the previous `VideoPlayer(controller)` widget in the UI layer.
///
/// Usage:
/// ```dart
/// SenzuVideoSurface(
///   fit: BoxFit.contain,
///   aspectRatio: 16 / 9,
/// )
/// ```
class SenzuVideoSurface extends StatelessWidget {
  const SenzuVideoSurface({
    super.key,
    this.fit         = BoxFit.contain,
    this.aspectRatio = 16 / 9,
    this.color       = const Color(0xFF000000),
  });

  /// How the video frame should be inscribed into the available space.
  ///
  /// Mirrors the [BoxFit] semantics used by the old [VideoPlayer] widget.
  final BoxFit fit;

  /// The native aspect ratio of the video.  The widget will size itself to
  /// maintain this ratio when [fit] is [BoxFit.contain] or [BoxFit.cover].
  final double aspectRatio;

  /// Background colour visible while the player is initialising.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ColoredBox(
        color: color,
        child: _NativeSurface(fit: fit),
      ),
    );
  }
}

// ── Private platform-dispatching widget ──────────────────────────────────────

class _NativeSurface extends StatelessWidget {
  const _NativeSurface({required this.fit});

  static const _viewType = 'senzu_player/surface';

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // The creation params map is intentionally empty for now.
    // It is forwarded to the native factory and reserved for
    // future multi-player / textureId disambiguation.
    const Map<String, dynamic> creationParams = {};

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _buildAndroid(creationParams);
      case TargetPlatform.iOS:
        return _buildIOS(creationParams);
      default:
        // Fallback for desktop / web (should not reach production)
        return const SizedBox.expand(
          child: ColoredBox(color: Color(0xFF111111)),
        );
    }
  }

  Widget _buildAndroid(Map<String, dynamic> params) {
    return AndroidView(
      viewType           : _viewType,
      layoutDirection    : TextDirection.ltr,
      creationParams     : params,
      creationParamsCodec: const StandardMessageCodec(),
      // Use hybrid composition for DRM / FLAG_SECURE surfaces.
      // PlatformViewSurface handles the SurfaceView Z-order correctly.
      gestureRecognizers : const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }

  Widget _buildIOS(Map<String, dynamic> params) {
    return UiKitView(
      viewType           : _viewType,
      layoutDirection    : TextDirection.ltr,
      creationParams     : params,
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers : const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}
// width: Get.width, height: Get.height
// ── SenzuVideoSurfaceWithFit ──────────────────────────────────────────────────
//
// Optional helper widget that mirrors [BoxFit.cover] / [BoxFit.fill]
// behaviour using a [FittedBox] over the platform view.
//
// Note: PlatformViews cannot be clipped by Flutter compositing; for
// [BoxFit.cover] the native layer will fill the available space and the
// Flutter clip will only affect widgets drawn above it.

class SenzuVideoSurfaceWithFit extends StatelessWidget {
  const SenzuVideoSurfaceWithFit({
    super.key,
    required this.videoAspectRatio,
    this.fit   = BoxFit.contain,
    this.color = const Color(0xFF000000),
  });

  final double videoAspectRatio;
  final BoxFit fit;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth  = constraints.maxWidth;
        final boxHeight = constraints.maxHeight;

        double width, height;

        switch (fit) {
          case BoxFit.cover:
            // Scale so the video fills the box, cropping if necessary
            final scaleW = boxWidth  / videoAspectRatio;
            final scaleH = boxHeight;
            if (scaleW > scaleH) {
              width  = boxWidth;
              height = boxWidth / videoAspectRatio;
            } else {
              height = boxHeight;
              width  = boxHeight * videoAspectRatio;
            }
          case BoxFit.fill:
            width  = boxWidth;
            height = boxHeight;
          case BoxFit.fitWidth:
            width  = boxWidth;
            height = boxWidth / videoAspectRatio;
          case BoxFit.fitHeight:
            height = boxHeight;
            width  = boxHeight * videoAspectRatio;
          case BoxFit.contain:
          default:
            final scaleByWidth  = boxWidth  / videoAspectRatio;
            final scaleByHeight = boxHeight;
            if (scaleByWidth < scaleByHeight) {
              width  = boxWidth;
              height = boxWidth / videoAspectRatio;
            } else {
              height = boxHeight;
              width  = boxHeight * videoAspectRatio;
            }
        }

        return ColoredBox(
          color: color,
          child: Center(
            child: SizedBox(
              width : width,
              height: height,
              child : const _NativeSurface(fit: BoxFit.fill),
            ),
          ),
        );
      },
    );
  }
}