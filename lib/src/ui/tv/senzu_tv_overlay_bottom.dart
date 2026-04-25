import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';

import 'senzu_tv_button.dart';
import 'senzu_tv_focus_wrapper.dart';
import 'senzu_tv_progress_bar.dart';

class SenzuTvOverlayBottom extends StatefulWidget {
  const SenzuTvOverlayBottom({
    super.key,
    required this.bundle,
    required this.style,
    this.enableEpisode = false,
    this.chapters = const [],
    this.firstFocusNode,
    this.onSeekBackward,
    this.onSeekForward,
    this.onBack,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final bool enableEpisode;
  final List<SenzuChapter> chapters;
  final FocusNode? firstFocusNode;

  final VoidCallback? onSeekBackward;
  final VoidCallback? onSeekForward;
  final VoidCallback? onBack;

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
          final isLive = widget.bundle.core.isLiveRx.value;
          final hasDvr =
              isLive && widget.bundle.stream.liveEdge.value > Duration.zero;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
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
                                    e.logicalKey ==
                                        LogicalKeyboardKey.arrowRight)) {
                              _seekNode.requestFocus();
                              return KeyEventResult.handled;
                            }

                            return KeyEventResult.ignored;
                          },
                          onTap: () => widget.bundle.ui.togglePanel(
                            SenzuPanel.episode,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLive || hasDvr)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 48,
                    right: 48,
                    bottom: 24,
                  ),
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(11),
                    child: SenzuProgressBarTV(
                      focusNode: _seekNode,
                      arrowSeekEnabled: true,
                      style: widget.style.progressBarStyle,
                      bundle: widget.bundle,
                      thumbnailSprite:
                          widget.bundle.core.activeSource?.thumbnailSprite,
                      chapters: widget.chapters,
                      onMoveBack: () => widget.firstFocusNode?.requestFocus(),
                      onSeekBackward: widget.onSeekBackward,
                      onSeekForward: widget.onSeekForward,
                      onBack: widget.onBack,
                    ),
                  ),
                )
              else
                const SizedBox(height: 24),
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

class _TvLiveBadge extends StatelessWidget {
  const _TvLiveBadge({
    required this.bundle,
    required this.hasDvr,
    required this.style,
  });

  final SenzuPlayerBundle bundle;
  final bool hasDvr;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
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
          child: Text(
            style.senzuLanguage.live,
            style: liveStyle.textStyle,
          ),
        ),
      );
    });
  }
}
