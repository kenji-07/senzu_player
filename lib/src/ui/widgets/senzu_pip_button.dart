import 'dart:async';
import 'package:flutter/material.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';

class SenzuPipButton extends StatefulWidget {
  const SenzuPipButton({super.key, required this.bundle, required this.style});
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  State<SenzuPipButton> createState() => _SenzuPipButtonState();
}

class _SenzuPipButtonState extends State<SenzuPipButton> {
  bool _supported = false;
  bool _active = false;
  StreamSubscription<Map<String, dynamic>>? _pipSub;

  SenzuPipButtonStyle get _pipStyle => widget.style.pipButtonStyle;

  @override
  void initState() {
    super.initState();
    _checkSupport();
    _pipSub = SenzuNativeChannel.pipStream.listen((event) {
      if (!mounted) return;
      setState(() => _active = event['isActive'] as bool? ?? false);
    });
  }

  Future<void> _checkSupport() async {
    final ok = await SenzuNativeChannel.isPipSupported();
    if (mounted) setState(() => _supported = ok);
  }

  @override
  void dispose() {
    _pipSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    return InkWell(
      onTap: _active ? SenzuNativeChannel.exitPip : SenzuNativeChannel.enterPip,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: _pipStyle.padding,
        child: Icon(
          _active ? _pipStyle.exitIcon : _pipStyle.enterIcon,
          color: _pipStyle.iconColor,
          size: _pipStyle.iconSize,
        ),
      ),
    );
  }
}