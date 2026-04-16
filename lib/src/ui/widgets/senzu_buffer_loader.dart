import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuBufferLoader
//
// Shows ONLY during initial load (before first play) and source change.
// Runtime buffering is shown inline in _CenterButton.
// ─────────────────────────────────────────────────────────────────────────────

class SenzuBufferLoader extends StatelessWidget {
  const SenzuBufferLoader({
    super.key,
    required this.bundle,
    required this.style,
    this.backgroundColor = const Color.fromARGB(204, 0, 0, 0),
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => Obx(() {
        // Show only while:
        //  1. Source is being loaded/changed AND playback hasn't started yet.
        //  2. NOT while dragging.
        //  3. NOT when playing.
        final isChangingSource = bundle.core.isChangingSource.value;
        final isPlaying        = bundle.playback.isPlaying.value;
        final pos              = bundle.playback.position.value;
        final isInitialized    = bundle.core.rxNativeState.value.isInitialized;

        // "Initial load" = changing source AND not yet playing AND at position 0
        final isInitialLoad = isChangingSource &&
            !isPlaying &&
            pos == Duration.zero;

        // Also show if not yet initialized at all (very first load)
        final notYetReady = !isInitialized && !bundle.core.hasError.value;

        if (!isInitialLoad && !notYetReady) return const SizedBox.shrink();

        final dur      = bundle.playback.duration.value;
        final buf      = bundle.playback.maxBuffering.value;
        final bufRatio = dur.inMilliseconds > 0
            ? (buf.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        final bufPercent = (bufRatio * 100).toInt();

        return Positioned.fill(
          child: Container(
            color: backgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: _InitialLoadIndicator(
                  bufRatio:   bufRatio,
                  bufPercent: bufPercent,
                  buf:        buf,
                  dur:        dur,
                  style:      style,
                ),
              ),
            ),
          ),
        );
      });
}

// ── Initial load indicator ────────────────────────────────────────────────────

class _InitialLoadIndicator extends StatelessWidget {
  const _InitialLoadIndicator({
    required this.bufRatio,
    required this.bufPercent,
    required this.buf,
    required this.dur,
    required this.style,
  });

  final double bufRatio;
  final int bufPercent;
  final Duration buf;
  final Duration dur;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                style.senzuLanguage.preparing,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '$bufPercent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(color: Colors.white12),
                FractionallySizedBox(
                  widthFactor: bufRatio,
                  child: Container(color: Colors.white),
                ),
                _BufferShimmer(ratio: bufRatio),
              ]),
            ),
          ),
          if (dur > Duration.zero) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_fmt(buf)} ${style.senzuLanguage.buffered}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ],
      );

  String _fmt(Duration d) {
    if (d <= Duration.zero) return '0s';
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }
}

// ── Runtime buffering indicator — used inside _CenterButton ───────────────────

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

// ── Shimmer animation ─────────────────────────────────────────────────────────

class _BufferShimmer extends StatefulWidget {
  const _BufferShimmer({required this.ratio});
  final double ratio;

  @override
  State<_BufferShimmer> createState() => _BufferShimmerState();
}

class _BufferShimmerState extends State<_BufferShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => FractionallySizedBox(
          widthFactor: widget.ratio,
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.12,
            alignment: Alignment.centerRight,
            child: Opacity(
              opacity: _anim.value * 0.6,
              child: Container(color: Colors.white),
            ),
          ),
        ),
      );
}