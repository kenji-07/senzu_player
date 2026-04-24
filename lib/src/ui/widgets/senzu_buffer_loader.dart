import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

class SenzuBufferLoader extends StatefulWidget {
  const SenzuBufferLoader({
    super.key,
    required this.bundle,
    required this.style,
    @Deprecated('Use style.bufferLoaderStyle.backgroundColor instead')
    Color? backgroundColor,
    @Deprecated('Use style.bufferLoaderStyle.brandColor instead')
    Color? brandColor,
    this.downloadSpeedBytesPerSec,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  /// Optional external download-speed stream (bytes/sec).
  final Stream<double>? downloadSpeedBytesPerSec;

  @override
  State<SenzuBufferLoader> createState() => _SenzuBufferLoaderState();
}

class _SenzuBufferLoaderState extends State<SenzuBufferLoader>
    with SingleTickerProviderStateMixin {
  double _speedMbps = 0.0;
  Duration _lastBuffered = Duration.zero;
  DateTime _lastTime = DateTime.now();
  Timer? _speedTimer;

  final List<double> _speedSamples = [];

  late final AnimationController _shimmerCtrl;
  late final Animation<double> shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    shimmerAnim = CurvedAnimation(
      parent: _shimmerCtrl,
      curve: Curves.easeInOut,
    );
    _startSpeedTimer();
  }

  void _startSpeedTimer() {
    _lastBuffered = widget.bundle.playback.maxBuffering.value;
    _lastTime = DateTime.now();

    _speedTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final currentBuffered = widget.bundle.playback.maxBuffering.value;
      final dtMs = now.difference(_lastTime).inMilliseconds;
      if (dtMs <= 0) return;

      final deltaMs = (currentBuffered - _lastBuffered).inMilliseconds;
      if (deltaMs > 0) {
        const avgBytesPerContentSec = 600000.0;
        final contentSecsDelta = deltaMs / 1000.0;
        final realSecsDelta = dtMs / 1000.0;
        final bytesPerSec =
            (contentSecsDelta * avgBytesPerContentSec) / realSecsDelta;
        final mbps = bytesPerSec / (1024 * 1024);

        _speedSamples.add(mbps);
        if (_speedSamples.length > 4) _speedSamples.removeAt(0);

        final avg =
            _speedSamples.reduce((a, b) => a + b) / _speedSamples.length;

        setState(() => _speedMbps = avg.clamp(0.0, 999.0));
      }

      _lastBuffered = currentBuffered;
      _lastTime = now;
    });
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isChangingSource = widget.bundle.core.isChangingSource.value;
      final isPlaying = widget.bundle.playback.isPlaying.value;
      final pos = widget.bundle.playback.position.value;
      final isInitialized =
          widget.bundle.core.rxNativeState.value.isInitialized;

      final isInitialLoad =
          isChangingSource && !isPlaying && pos == Duration.zero;
      final notYetReady =
          !isInitialized && !widget.bundle.core.hasError.value;

      if (!isInitialLoad && !notYetReady) return const SizedBox.shrink();

      return Positioned.fill(
        child: _LoadingOverlay(
          speedMbps: _speedMbps,
          style: widget.style,
        ),
      );
    });
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({
    required this.speedMbps,
    required this.style,
  });

  final double speedMbps;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: style.bufferLoaderStyle.backgroundColor,
      child: Center(
        child: _SpeedLabel(speedMbps: speedMbps, style: style),
      ),
    );
  }
}

class _SpeedLabel extends StatelessWidget {
  const _SpeedLabel({required this.speedMbps, required this.style});

  final double speedMbps;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    final hasSpeed = speedMbps > 0.01;
    final speedStr = speedMbps >= 1.0
        ? '${speedMbps.toStringAsFixed(2)} MB/s'
        : '${(speedMbps * 1024).toStringAsFixed(0)} KB/s';

    final prefix = style.senzuLanguage.preparingPrefix;
    final label = hasSpeed ? '$prefix... $speedStr' : style.senzuLanguage.preparing;

    return Text(label, style: style.bufferLoaderStyle.textStyle);
  }
}

/// Shown during runtime buffering (spinner or percent).
class RuntimeBufferingIndicator extends StatelessWidget {
  const RuntimeBufferingIndicator({
    super.key,
    required this.bufPercent,
    required this.style,
  });

  final int bufPercent;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    if (bufPercent > 0) {
      return Text(
        '$bufPercent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return const CircularProgressIndicator(
      strokeWidth: 1.6,
      color: Colors.white,
    );
  }
}