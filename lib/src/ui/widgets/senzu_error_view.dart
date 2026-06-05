import 'package:flutter/material.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';

/// Shared error overlay used by both [SenzuPlayer] and [SenzuPlayerCoreView].
///
/// Parameters:
/// - [errorStyle]    — visual style (icon, colors, button style …)
/// - [title]         — primary "failed to load" text
/// - [message]       — optional detail error message (raw string)
/// - [retryLabel]    — label shown on the retry button
/// - [onRetry]       — callback when user taps retry
/// - [aspectRatio]   — when non-null the widget is wrapped in an [AspectRatio]
/// - [showBackButton]— whether to show a top-left back chevron
class SenzuErrorView extends StatelessWidget {
  const SenzuErrorView({
    super.key,
    required this.errorStyle,
    required this.title,
    required this.retryLabel,
    required this.onRetry,
    this.message,
    this.aspectRatio,
    this.showBackButton = false,
  });

  final SenzuErrorStyle errorStyle;
  final String title;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? message;

  /// If provided, the content is wrapped in an [AspectRatio] widget.
  final double? aspectRatio;

  /// Whether to show a back-chevron button at top-left.
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: errorStyle.backroundColor,
      child: Stack(
        children: [
          // ── Main error body ─────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                errorStyle.icon,
                const SizedBox(height: 12),
                Text(title, style: errorStyle.titleStyle),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      message!,
                      style: errorStyle.messageStyle,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: errorStyle.buttonStyle ??
                      ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                      ),
                  onPressed: onRetry,
                  icon: errorStyle.refreshIcon,
                  label: Text(retryLabel),
                ),
              ],
            ),
          ),

          // ── Optional back button ────────────────────────────────────────────
          if (showBackButton)
            const Positioned(
              top: 16,
              left: 16,
              child: SenzuBackButton(),
            ),
        ],
      ),
    );

    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio!, child: content);
    }
    return content;
  }
}

// ── Back button ───────────────────────────────────────────────────────────────
/// A reusable back-chevron button that pops the current route.
class SenzuBackButton extends StatelessWidget {
  const SenzuBackButton({super.key});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
      );
}
