import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_progress_bar.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';

import 'senzu_tv_button.dart';
import 'senzu_tv_focus_wrapper.dart';

class SenzuTvOverlayBottom extends StatefulWidget {
  const SenzuTvOverlayBottom({
    super.key,
    required this.bundle,
    required this.style,
    this.enableEpisode = false,
    this.chapters = const [],
    this.firstFocusNode,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final bool enableEpisode;
  final List<SenzuChapter> chapters;
  final FocusNode? firstFocusNode;

  @override
  State<SenzuTvOverlayBottom> createState() => _SenzuTvOverlayBottomState();
}

class _SenzuTvOverlayBottomState extends State<SenzuTvOverlayBottom> {
  final FocusNode _seekNode = FocusNode(debugLabel: 'tv-bottom-seek');

  @override
  void dispose() {
    _seekNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        child: Obx(() {
          final isFS = widget.bundle.core.isFullScreen.value;
          final isLive = widget.bundle.core.isLiveRx.value;
          final hasDvr =
              isLive && widget.bundle.stream.liveEdge.value > Duration.zero;
          final hPad = isFS ? 48.0 : 24.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: [
                    if (isLive)
                      _TvLiveBadge(
                        bundle: widget.bundle,
                        hasDvr: hasDvr,
                        style: widget.style,
                      )
                    else
                      Obx(() {
                        final pos = widget.bundle.playback.position.value;
                        final dur = widget.bundle.playback.duration.value;
                        return Text(
                          '${_fmt(pos)} / ${_fmt(dur)}',
                          style: widget.style.textStyle.copyWith(fontSize: 14),
                        );
                      }),

                    const Spacer(),

                    if (widget.enableEpisode &&
                        widget.style.episodeWidget != null)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(10),
                        child: SenzuTvButton(
                          focusNode: widget.firstFocusNode,
                          icon: widget.style.overlayIconsStyle.episode,
                          tooltip: widget.style.senzuLanguage.episodes,
                          onKeyEvent: (_, e) {
    if (e is KeyDownEvent &&
        (e.logicalKey == LogicalKeyboardKey.arrowDown ||
            e.logicalKey == LogicalKeyboardKey.arrowRight)) {
      _seekNode.requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  },
                          onTap: () => widget.bundle.ui
                              .togglePanel(SenzuPanel.episode),
                        ),
                      ),
                  ],
                ),
              ),

              if (!isLive || hasDvr)
                Padding(
                  padding: EdgeInsets.only(
                    left: hPad,
                    right: hPad,
                    bottom: isFS ? 24 : 12,
                  ),
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(11),
                    child: _TvSeekBar(
                      focusNode: _seekNode,
                      bundle: widget.bundle,
                      style: widget.style,
                      chapters: widget.chapters,
                      arrowSeekEnabled: true,
                      onMoveBack: () {
    widget.firstFocusNode?.requestFocus();
  },
                    ),
                  ),
                )
              else
                SizedBox(height: isFS ? 24 : 12),
            ],
          );
        }),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
// ── D-pad seek progress bar ───────────────────────────────────────────────────
class _TvSeekBar extends StatefulWidget {
  const _TvSeekBar({
    required this.bundle,
    required this.style,
    required this.chapters,
    required this.focusNode,
    this.arrowSeekEnabled = false,
    this.onMoveBack,
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final List<SenzuChapter> chapters;
  final FocusNode? focusNode;
  final bool arrowSeekEnabled;
  final VoidCallback? onMoveBack;

  @override
  State<_TvSeekBar> createState() => _TvSeekBarState();
}

class _TvSeekBarState extends State<_TvSeekBar> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (!widget.arrowSeekEnabled) {
      return KeyEventResult.ignored;
    }

    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        widget.bundle.core.seekBySeconds(-10);
        HapticFeedback.selectionClick();
        return KeyEventResult.handled;
      }

      if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        widget.bundle.core.seekBySeconds(10);
        HapticFeedback.selectionClick();
        return KeyEventResult.handled;
      }
    }
    if (e is KeyDownEvent &&
    (e.logicalKey == LogicalKeyboardKey.arrowUp ||
        e.logicalKey == LogicalKeyboardKey.arrowLeft)) {
  widget.onMoveBack?.call();
  return KeyEventResult.handled;
}

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: _onKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: _focused
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white54, width: 1.5),
                color: Colors.white.withOpacity(0.06),
              )
            : const BoxDecoration(),
        child: SenzuProgressBar(
          style: widget.style.progressBarStyle,
          bundle: widget.bundle,
          thumbnailSprite: widget.bundle.core.activeSource?.thumbnailSprite,
          chapters: widget.chapters,
        ),
      ),
    );
  }
}

// ── Live badge ─────────────────────────────────────────────────────────────────
class _TvLiveBadge extends StatelessWidget {
  const _TvLiveBadge(
      {required this.bundle, required this.hasDvr, required this.style});
  final SenzuPlayerBundle bundle;
  final bool hasDvr;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => Obx(() {
        final atEdge = bundle.stream.isAtLiveEdge.value;
        final liveStyle = style.liveBadgeStyle;
        return SenzuTvFocusWrapper(
          onTap: (!hasDvr || atEdge) ? null : bundle.core.goToLiveEdge,
          enabled: hasDvr && !atEdge,
          child: Container(
            padding: liveStyle.padding,
            decoration: BoxDecoration(
              color: atEdge ? liveStyle.liveColor : liveStyle.dvrOffColor,
              borderRadius: liveStyle.borderRadius,
            ),
            child: Text(style.senzuLanguage.live, style: liveStyle.textStyle),
          ),
        );
      });
}
