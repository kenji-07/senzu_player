import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class _NativeSurface extends StatelessWidget {
  const _NativeSurface({required this.fit});

  static const _viewType = 'senzu_player/surface';
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _buildAndroid();
      case TargetPlatform.iOS:
        return _buildIOS();
      default:
        return const SizedBox.expand(
          child: ColoredBox(color: Color(0xFF111111)),
        );
    }
  }

  Widget _buildAndroid() {
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: const <String, dynamic>{},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }

  Widget _buildIOS() {
    return const UiKitView(
      viewType: _viewType,
      layoutDirection: TextDirection.ltr,
      creationParams:  <String, dynamic>{},
      creationParamsCodec:  StandardMessageCodec(),
      gestureRecognizers:  <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}

class SenzuVideoSurfaceWithFit extends StatelessWidget {
  const SenzuVideoSurfaceWithFit({
    super.key,
    required this.videoAspectRatio,
    this.fit = BoxFit.contain,
    this.color = const Color(0xFF000000),
  });

  final double videoAspectRatio;
  final BoxFit fit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;

        double width, height;

        switch (fit) {
          case BoxFit.cover:
            final scaleToFitWidth = boxW / videoAspectRatio;
            final scaleToFitHeight = boxH * videoAspectRatio;
            if (scaleToFitWidth >= boxH) {
              width = boxW;
              height = scaleToFitWidth;
            } else {
              width = scaleToFitHeight;
              height = boxH;
            }
            break;

          case BoxFit.fill:
            width = boxW;
            height = boxH;
            break;

          case BoxFit.fitWidth:
            width = boxW;
            height = boxW / videoAspectRatio;
            break;

          case BoxFit.fitHeight:
            height = boxH;
            width = boxH * videoAspectRatio;
            break;

          case BoxFit.none:
            width = videoAspectRatio * 360;
            height = 360;
            break;

          case BoxFit.contain:
          case BoxFit.scaleDown:
            final byWidth = boxW / videoAspectRatio;
            final byHeight = boxH * videoAspectRatio;
            if (byWidth <= boxH) {
              width = boxW;
              height = byWidth;
            } else {
              width = byHeight;
              height = boxH;
            }
            break;
        }

        return ColoredBox(
          color: color,
          child: Center(
            child: SizedBox(
              width: width.clamp(0.0, double.infinity),
              height: height.clamp(0.0, double.infinity),
              child: const _NativeSurface(fit: BoxFit.fill),
            ),
          ),
        );
      },
    );
  }
}