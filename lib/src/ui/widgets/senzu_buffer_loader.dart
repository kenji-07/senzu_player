import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuBufferLoader
//
// iQIYI-style loading screen:
//   • Logo / title centered top-half
//   • Green progress bar (indeterminate while measuring, fills as buffer grows)
//   • "Starting soon... X.XX MB/s" — speed calculated from buffer delta
//   • Spinner bottom-center
//
// Logic:
//   • Shown only on initial load (isChangingSource && pos==0) OR not initialized
//   • MB/s = Δbuffered_bytes / Δtime  (approximated from Δbuffered_ms * bitrate)
//     Since we don't have raw bytes, we approximate via buffered-duration delta:
//     bitrate ≈ (Δbuffered_ms * avgBitrate) — but we don't have avgBitrate either.
//     So instead we track Δbuffered_ms/Δtime_ms → "buffer speed ratio" then
//     convert with a heuristic: 1 sec buffered/sec ≈ current_bandwidth_use.
//     For a real MB/s we measure how much `maxBuffering` Duration increases per
//     real-time second, then multiply by an assumed average segment bitrate.
//     This is an approximation — for exact MB/s, native bandwidth reporting is needed.
//
//   • If the consumer wants exact MB/s, they can pass `downloadSpeedBytesPerSec`
//     from a native speed observer. Otherwise the widget auto-estimates.
// ─────────────────────────────────────────────────────────────────────────────

class SenzuBufferLoader extends StatefulWidget {
  const SenzuBufferLoader({
    super.key,
    required this.bundle,
    required this.style,
    this.backgroundColor = const Color(0xFF0A0A0A),
    /// Optional: pass actual download speed from native (bytes/sec).
    /// If null, widget estimates from buffer progress delta.
    this.downloadSpeedBytesPerSec,
    /// Your app logo/brand widget shown at top. Defaults to player title text.
    this.logoWidget,
    /// Brand color for progress bar & spinner. Defaults to green (iQIYI style).
    this.brandColor = const Color(0xFF00CA13),
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final Color backgroundColor;
  final Stream<double>? downloadSpeedBytesPerSec;
  final Widget? logoWidget;
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
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut);

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
        final bytesPerSec = (contentSecsDelta * avgBytesPerContentSec) / realSecsDelta;
        final mbps = bytesPerSec / (1024 * 1024);

        _speedSamples.add(mbps);
        if (_speedSamples.length > 4) _speedSamples.removeAt(0);

        final avg = _speedSamples.reduce((a, b) => a + b) / _speedSamples.length;

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
      final isInitialized = widget.bundle.core.rxNativeState.value.isInitialized;

      final isInitialLoad = isChangingSource && !isPlaying && pos == Duration.zero;
      final notYetReady = !isInitialized && !widget.bundle.core.hasError.value;

      if (!isInitialLoad && !notYetReady) return const SizedBox.shrink();

      final dur = widget.bundle.playback.duration.value;
      final buf = widget.bundle.playback.maxBuffering.value;
      final bufRatio = dur.inMilliseconds > 0
          ? (buf.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

      return Positioned.fill(
        child: _IQIYILoadingOverlay(
          bufRatio: bufRatio,
          speedMbps: _speedMbps,
          shimmerAnim: _shimmerAnim,
          backgroundColor: widget.backgroundColor,
          brandColor: widget.brandColor,
          logoWidget: widget.logoWidget,
          style: widget.style,
          bundle: widget.bundle,
        ),
      );
    });
  }
}

// ── iQIYI-style overlay ────────────────────────────────────────────────────────

class _IQIYILoadingOverlay extends StatelessWidget {
  const _IQIYILoadingOverlay({
    required this.bufRatio,
    required this.speedMbps,
    required this.shimmerAnim,
    required this.backgroundColor,
    required this.brandColor,
    required this.logoWidget,
    required this.style,
    required this.bundle,
  });

  final double bufRatio;
  final double speedMbps;
  final Animation<double> shimmerAnim;
  final Color backgroundColor;
  final Color brandColor;
  final Widget? logoWidget;
  final SenzuPlayerStyle style;
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // ── Top half: Logo + progress ──────────────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                logoWidget ??
                    Text(
                      bundle.core.rxNativeState.value.isInitialized
                          ? ''
                          : 'Loading',
                      style: TextStyle(
                        color: brandColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),

                const SizedBox(height: 20),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _GreenProgressBar(
                    ratio: bufRatio,
                    brandColor: brandColor,
                    shimmerAnim: shimmerAnim,
                  ),
                ),

                const SizedBox(height: 14),

                // "Starting soon... X.XX MB/s"
                _SpeedLabel(
                  speedMbps: speedMbps,
                  brandColor: brandColor,
                  style: style,
                ),
              ],
            ),
          ),

          // ── Bottom half: Spinner ───────────────────────────────────────
          Expanded(
            child: Center(
              child: _GreenSpinner(brandColor: brandColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Green progress bar with shimmer ───────────────────────────────────────────

class _GreenProgressBar extends StatelessWidget {
  const _GreenProgressBar({
    required this.ratio,
    required this.brandColor,
    required this.shimmerAnim,
  });

  final double ratio;
  final Color brandColor;
  final Animation<double> shimmerAnim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            // Background track
            Container(
              color: brandColor.withValues(alpha: 0.18),
            ),

            // Filled portion
            if (ratio > 0)
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(color: brandColor),
              ),

            // Indeterminate shimmer when ratio == 0
            if (ratio == 0)
              AnimatedBuilder(
                animation: shimmerAnim,
                builder: (_, __) {
                  return FractionallySizedBox(
                    widthFactor: 0.35,
                    alignment: Alignment(
                      (shimmerAnim.value * 2 - 1) * 1.6,
                      0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            brandColor,
                            brandColor,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Shimmer at leading edge when loading
            if (ratio > 0 && ratio < 1.0)
              AnimatedBuilder(
                animation: shimmerAnim,
                builder: (_, __) => FractionallySizedBox(
                  widthFactor: ratio.clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.15,
                      child: Opacity(
                        opacity: shimmerAnim.value * 0.8,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.white],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

// ── Green spinner (iQIYI style — open circle) ─────────────────────────────────

class _GreenSpinner extends StatelessWidget {
  const _GreenSpinner({required this.brandColor});
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CircularProgressIndicator(
        strokeWidth: 3.0,
        valueColor: AlwaysStoppedAnimation<Color>(brandColor),
        backgroundColor: brandColor.withValues(alpha: 0.15),
        strokeCap: StrokeCap.round,
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
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }
    return const CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white);
  }
}