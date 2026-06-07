import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

/// Renders a poster image straight from the SQLite cache populated by
/// [DownloadImageCache]. No network request is made — if the bytes are
/// missing a placeholder is shown.
class CachedOfflinePoster extends StatelessWidget {
  final String mediaId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedOfflinePoster({
    super.key,
    required this.mediaId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: DownloadImageCache.getCached(mediaId),
      builder: (context, snapshot) {
        Widget child;
        if (snapshot.connectionState == ConnectionState.waiting) {
          child = _loading();
        } else if (snapshot.hasData && snapshot.data != null) {
          child = Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        } else {
          child = _placeholder();
        }
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          child: SizedBox(width: width, height: height, child: child),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        color: Colors.white10,
        child: const Icon(Icons.video_library, color: Colors.white30),
      );

  Widget _loading() => Container(
        color: Colors.white10,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white30),
            ),
          ),
        ),
      );
}
