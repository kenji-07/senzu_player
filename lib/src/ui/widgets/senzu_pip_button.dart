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

  @override
  void initState() {
    super.initState();
    _checkSupport();
    SenzuNativeChannel.pipStream.listen((event) {
      if (!mounted) return;
      setState(() => _active = event['isActive'] as bool? ?? false);
    });
  }

  Future<void> _checkSupport() async {
    final ok = await SenzuNativeChannel.isPipSupported();
    if (mounted) setState(() => _supported = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    return InkWell(
      onTap: _active ? SenzuNativeChannel.exitPip : SenzuNativeChannel.enterPip,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          _active ? widget.style.enterPipIcon : widget.style.enterPipIcon,
          color: widget.style.pipIconColor,
          size: widget.style.pipIconSize,
        ),
      ),
    );
  }
}
