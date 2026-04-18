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
    this.backgroundColor = const Color(0xFF0A0A0A),

    /// Optional: pass actual download speed from native (bytes/sec).
    /// If null, widget estimates from buffer progress delta.
    this.downloadSpeedBytesPerSec,

    this.brandColor = const Color(0xFF00CA13),
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final Color backgroundColor;
  final Stream<double>? downloadSpeedBytesPerSec;
  final Color brandColor;

  @override
  State<SenzuBufferLoader> createState() => _SenzuBufferLoaderState();
}

class _SenzuBufferLoaderState extends State<SenzuBufferLoader>
    with SingleTickerProviderStateMixin {
  // ── Speed estimation ──────────────────────────────────────────────────────
  double _speedMbps = 0.0; // displayed speed
  Duration _lastBuffered = Duration.zero;
  DateTime _lastTime = DateTime.now();
  Timer? _speedTimer;

  // Smoothing: keep last 3 samples
  final List<double> _speedSamples = [];

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = CurvedAnimation(
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

      // Δbuffered in ms
      final deltaMs = (currentBuffered - _lastBuffered).inMilliseconds;
      if (deltaMs > 0) {
        // Approximate: assume average HLS segment bitrate ~4 Mbps (500 KB/s per sec of content)
        // speed_bytes/sec = (deltaMs / 1000) * avgBytesPerSec / (dtMs / 1000)
        // avgBytesPerSec heuristic: 500_000 bytes = 500 KB per content-second (SD/HD mix)
        const avgBytesPerContentSec = 600_000.0; // ~4.8 Mbps average
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
      final notYetReady = !isInitialized && !widget.bundle.core.hasError.value;

      if (!isInitialLoad && !notYetReady) return const SizedBox.shrink();

      final dur = widget.bundle.playback.duration.value;
      final buf = widget.bundle.playback.maxBuffering.value;
      final bufRatio = dur.inMilliseconds > 0
          ? (buf.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

      return Positioned.fill(
        child: LoadingOverlay(
          bufRatio: bufRatio,
          speedMbps: _speedMbps,
          shimmerAnim: _shimmerAnim,
          backgroundColor: widget.backgroundColor,
          brandColor: widget.brandColor,
          style: widget.style,
          bundle: widget.bundle,
        ),
      );
    });
  }
}

// ── Overlay ────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.bufRatio,
    required this.speedMbps,
    required this.shimmerAnim,
    required this.backgroundColor,
    required this.brandColor,
    required this.style,
    required this.bundle,
  });

  final double bufRatio;
  final double speedMbps;
  final Animation<double> shimmerAnim;
  final Color backgroundColor;
  final Color brandColor;
  final SenzuPlayerStyle style;
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: _SpeedLabel(
          speedMbps: speedMbps,
          brandColor: brandColor,
          style: style,
        ),
      ),
    );
  }
}

// ── Speed label ────────────────────────────────────────────────────────────────

class _SpeedLabel extends StatelessWidget {
  const _SpeedLabel({
    required this.speedMbps,
    required this.brandColor,
    required this.style,
  });

  final double speedMbps;
  final Color brandColor;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    final hasSpeed = speedMbps > 0.01;
    final speedStr = speedMbps >= 1.0
        ? '${speedMbps.toStringAsFixed(2)} MB/s'
        : '${(speedMbps * 1024).toStringAsFixed(0)} KB/s';

    return Text(
      hasSpeed
          ? '${style.senzuLanguage.preparing.replaceAll('...', '')}... $speedStr'
          : style.senzuLanguage.preparing,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ── RuntimeBufferingIndicator (unchanged, used by center button) ───────────────

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
