import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_progress_bar.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/data/models/senzu_chapter_model.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/ui/widgets/senzu_pip_button.dart';

class SenzuOverlayBottom extends StatelessWidget {
  const SenzuOverlayBottom({
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

  Duration _clampDur(Duration v, Duration lo, Duration hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        final hasDvr = isLive && bundle.stream.liveEdge.value > Duration.zero;
        final hPad = isFS ? 28.0 : 14.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (style.bottomExtra != null) style.bottomExtra!,

            Obx(() {
              final isDragging = bundle.playback.isDragging.value;
              if (isDragging) return const SizedBox.shrink();

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: [
                    if (isLive)
                      _LiveBadge(
                        bundle: bundle,
                        hasDvr: hasDvr,
                        style: style,
                      ),

                    if (!isLive)
                      Obx(() {
                        final pos = bundle.playback.position.value;
                        final dur = bundle.playback.duration.value;
                        final pending = bundle.core.pendingSeek.value;
                        final displayPos = pending != Duration.zero
                            ? _clampDur(pos + pending, Duration.zero, dur)
                            : pos;
                        return Text(
                          '${_fmt(displayPos)} / ${_fmt(dur)}',
                          style: style.textStyle,
                        );
                      }),

                    const Spacer(),
                    if (enablePip) SenzuPipButton(bundle: bundle, style: style),
                    if (enableEpisode && style.episodeWidget != null)
                      _Btn(
                        icon: style.overlayIconsStyle.episode,
                        onTap: () =>
                            bundle.ui.togglePanel(SenzuPanel.episode),
                      ),
                    if (enableFullscreen)
                      _Btn(
                        icon: isFS
                            ? style.overlayIconsStyle.fullscreenExit
                            : style.overlayIconsStyle.fullscreen,
                        onTap: () => bundle.core.openOrCloseFullscreen(),
                      ),
                  ],
                ),
              );
            }),

            if (!isLive || hasDvr)
              Padding(
                padding: EdgeInsets.only(
                  left: hPad,
                  right: hPad,
                  bottom: isFS ? 16 : 8,
                ),
                child: SenzuProgressBar(
                  style: style.progressBarStyle,
                  bundle: bundle,
                  thumbnailSprite: bundle.core.activeSource?.thumbnailSprite,
                  chapters: chapters,
                ),
              )
            else
              SizedBox(height: isFS ? 16 : 8),
          ],
        );
      }),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── LIVE badge ─────────────────────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  const _LiveBadge({
    required this.bundle,
    required this.hasDvr,
    required this.style,
  });
  final SenzuPlayerBundle bundle;
  final bool hasDvr;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) => Obx(() {
        final atEdge = bundle.stream.isAtLiveEdge.value;
        final liveStyle = style.liveBadgeStyle;
        return GestureDetector(
          onTap: (!hasDvr || atEdge) ? null : bundle.core.goToLiveEdge,
          child: Container(
            padding: liveStyle.padding,
            decoration: BoxDecoration(
              color: atEdge ? liveStyle.liveColor : liveStyle.dvrOffColor,
              borderRadius: liveStyle.borderRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasDvr && !atEdge) ...[
                  const Icon(Icons.circle, color: Colors.white, size: 7),
                  const SizedBox(width: 4),
                ],
                Text(
                  style.senzuLanguage.live,
                  style: liveStyle.textStyle,
                ),
              ],
            ),
          ),
        );
      });
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.onTap});
  final Icon icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: const EdgeInsets.all(6), child: icon),
      );
}