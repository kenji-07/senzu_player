import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:senzu_player/src/data/models/senzu_watermark.dart';

class SenzuWatermarkOverlay extends StatefulWidget {
  const SenzuWatermarkOverlay({super.key, required this.watermark});
  final SenzuWatermark watermark;

  @override
  State<SenzuWatermarkOverlay> createState() => _SenzuWatermarkOverlayState();
}

class _SenzuWatermarkOverlayState extends State<SenzuWatermarkOverlay> {
  Alignment _alignment = Alignment.topLeft;
  Timer? _timer;
  final _rng = Random();

  static const _positions = [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.bottomLeft,
    Alignment.bottomRight,
    Alignment.center,
    Alignment(-0.5, 0.0),
    Alignment(0.5, 0.0),
  ];

  @override
  void initState() {
    super.initState();
    _setInitialPosition();
    if (widget.watermark.position == WatermarkPosition.random) {
      _timer = Timer.periodic(widget.watermark.moveDuration, (_) {
        if (mounted) setState(() => _alignment = _randomPosition());
      });
    }
  }

  void _setInitialPosition() {
    _alignment = widget.watermark.position == WatermarkPosition.random
        ? _randomPosition()
        : _toAlignment(widget.watermark.position);
  }

  Alignment _randomPosition() => _positions[_rng.nextInt(_positions.length)];

  Alignment _toAlignment(WatermarkPosition p) => switch (p) {
        WatermarkPosition.topLeft => Alignment.topLeft,
        WatermarkPosition.topRight => Alignment.topRight,
        WatermarkPosition.bottomLeft => Alignment.bottomLeft,
        WatermarkPosition.bottomRight => Alignment.bottomRight,
        WatermarkPosition.center => Alignment.center,
        WatermarkPosition.random => Alignment.topLeft,
      };

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedAlign(
          duration: const Duration(seconds: 3),
          curve: Curves.easeInOut,
          alignment: _alignment,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Opacity(
              opacity: widget.watermark.opacity,
              child: Text(
                widget.watermark.buildText(),
                style: TextStyle(
                  color: widget.watermark.color,
                  fontSize: widget.watermark.fontSize,
                  fontWeight: FontWeight.w500,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4),
                    Shadow(color: Colors.black, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
