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

/// Android TV bottom overlay.
///
/// Layout (D-pad traversal order):
///   [SeekBar(←→)]  [Episode]  [Fullscreen]
///
/// ↑/↓ дарахад SenzuTvCoreView-ийн key handler
/// overlay-г харуулж, top/bottom-д focus шилжүүлнэ.
class SenzuTvOverlayBottom extends StatelessWidget {
  const SenzuTvOverlayBottom({
    super.key,
    required this.bundle,
    required this.style,
    this.enableFullscreen = true,
    this.enablePip = false,
    this.enableEpisode = false,
    this.chapters = const [],
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final bool enableFullscreen;
  final bool enablePip;
  final bool enableEpisode;
  final List<SenzuChapter> chapters;

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
          final isFS = bundle.core.isFullScreen.value;
          final isLive = bundle.core.isLiveRx.value;
          final hasDvr =
              isLive && bundle.stream.liveEdge.value > Duration.zero;
          final hPad = isFS ? 48.0 : 24.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Time + right buttons ─────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: [
                    // Time / Live badge
                    if (isLive)
                      _TvLiveBadge(
                          bundle: bundle, hasDvr: hasDvr, style: style)
                    else
                      Obx(() {
                        final pos = bundle.playback.position.value;
                        final dur = bundle.playback.duration.value;
                        return Text(
                          '${_fmt(pos)} / ${_fmt(dur)}',
                          style: style.textStyle.copyWith(fontSize: 14),
                        );
                      }),

                    const Spacer(),

                    if (enableEpisode && style.episodeWidget != null)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(10),
                        child: SenzuTvButton(
                          icon: style.overlayIconsStyle.episode,
                          tooltip: style.senzuLanguage.episodes,
                          onTap: () =>
                              bundle.ui.togglePanel(SenzuPanel.episode),
                        ),
                      ),
                    if (enableFullscreen)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(11),
                        child: SenzuTvButton(
                          icon: isFS
                              ? style.overlayIconsStyle.fullscreenExit
                              : style.overlayIconsStyle.fullscreen,
                          onTap: () => bundle.core.openOrCloseFullscreen(),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Seek bar ─────────────────────────────────────────────────
              if (!isLive || hasDvr)
                Padding(
                  padding: EdgeInsets.only(
                    left: hPad,
                    right: hPad,
                    bottom: isFS ? 24 : 12,
                  ),
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: _TvSeekBar(
                      bundle: bundle,
                      style: style,
                      chapters: chapters,
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
  });
  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final List<SenzuChapter> chapters;

  @override
  State<_TvSeekBar> createState() => _TvSeekBarState();
}

class _TvSeekBarState extends State<_TvSeekBar> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
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
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_focused)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_left,
                        color: Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '← −10s   +10s →',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_right,
                        color: Colors.white54, size: 14),
                  ],
                ),
              ),
            SenzuProgressBar(
              style: widget.style.progressBarStyle,
              bundle: widget.bundle,
              thumbnailSprite:
                  widget.bundle.core.activeSource?.thumbnailSprite,
              chapters: widget.chapters,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live badge ─────────────────────────────────────────────────────────────────
class _TvLiveBadge extends StatelessWidget {
  const _TvLiveBadge(
      {required this.bundle,
      required this.hasDvr,
      required this.style});
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
            child: Text(style.senzuLanguage.live,
                style: liveStyle.textStyle),
          ),
        );
      });
}