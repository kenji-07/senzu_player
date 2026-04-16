import 'package:flutter/material.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/platform/senzu_native_channel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SenzuPipButton
//
// Floating PiP button — shown in overlay top bar when PiP is supported.
// Tapping enters Picture-in-Picture mode.
// ─────────────────────────────────────────────────────────────────────────────

class SenzuPipButton extends StatefulWidget {
  const SenzuPipButton({super.key, required this.bundle});
  final SenzuPlayerBundle bundle;

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
          _active
              ? Icons
                    .picture_as_pdf // or any "exit PiP" icon
              : Icons.pin_drop,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// SenzuPipOverlay
//
// Shown when PiP is active — a minimal "back to player" button.
// Embed at the root of your app above the Navigator if needed.
// ─────────────────────────────────────────────────────────────────────────────

class SenzuPipOverlay extends StatelessWidget {
  const SenzuPipOverlay({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: SenzuNativeChannel.pipStream,
      builder: (context, snap) {
        final isActive = snap.data?['isActive'] as bool? ?? false;
        if (!isActive) return const SizedBox.shrink();
        return Positioned(
          bottom: 16,
          right: 16,
          child: GestureDetector(
            onTap: () {
              SenzuNativeChannel.exitPip();
              onTap?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.picture_in_picture_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Back to player',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
