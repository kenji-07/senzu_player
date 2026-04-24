import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/cast/widgets/senzu_cast_button.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';

import 'senzu_tv_button.dart';

/// Android TV top overlay.
///
/// FocusTraversalGroup(OrderedTraversalPolicy) ашиглаж
/// D-pad left/right-аар товчнуудын хооронд шилжинэ.
class SenzuTvOverlayTop extends StatelessWidget {
  const SenzuTvOverlayTop({
    super.key,
    required this.bundle,
    required this.style,
    required this.meta,
    this.enableCaption = true,
    this.enableQuality = true,
    this.enableAudio = false,
    this.enableSpeed = true,
    this.enableAspect = true,
    this.enableSleep = true,
    this.castController,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuCastController? castController;
  final SenzuMetaData meta;
  final bool enableCaption;
  final bool enableQuality;
  final bool enableAudio;
  final bool enableSpeed;
  final bool enableAspect;
  final bool enableSleep;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      // OrderedTraversalPolicy → FocusOrder-оор зэрэглэнэ
      policy: OrderedTraversalPolicy(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding:
            const EdgeInsets.only(top: 8, left: 16, right: 8, bottom: 16),
        child: Row(
          children: [
            // ── Back button ────────────────────────────────────────────────
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: SenzuTvButton(
                icon: Icon(meta.icon ?? Icons.arrow_back),
                iconColor: meta.iconColor ?? Colors.white,
                iconSize: (meta.iconSize ?? 24),
                onTap: () => bundle.core.closeFullscreen(context),
              ),
            ),

            const Spacer(),

            // ── Right-side action buttons ──────────────────────────────────
            Obx(() {
              final isLive = bundle.core.isLiveRx.value;
              int order = 1;

              Widget btn(
                Widget button,
                int o,
              ) =>
                  FocusTraversalOrder(
                    order: NumericFocusOrder(o.toDouble()),
                    child: button,
                  );

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (enableSleep)
                    btn(
                      SenzuTvButton(
                        icon: style.overlayIconsStyle.sleep,
                        tooltip: style.senzuLanguage.sleepTimer,
                        onTap: () =>
                            bundle.ui.togglePanel(SenzuPanel.sleep),
                      ),
                      order++,
                    ),
                  if (enableAspect)
                    btn(
                      SenzuTvButton(
                        icon: style.overlayIconsStyle.aspect,
                        tooltip: style.senzuLanguage.aspectRatio,
                        onTap: () =>
                            bundle.ui.togglePanel(SenzuPanel.aspect),
                      ),
                      order++,
                    ),
                  if (enableSpeed && !isLive)
                    btn(
                      SenzuTvButton(
                        icon: style.overlayIconsStyle.speed,
                        tooltip: style.senzuLanguage.playbackSpeed,
                        onTap: () =>
                            bundle.ui.togglePanel(SenzuPanel.speed),
                      ),
                      order++,
                    ),
                  if (enableCaption)
                    btn(
                      SenzuTvButton(
                        icon: style.overlayIconsStyle.caption,
                        tooltip: style.senzuLanguage.subtitles,
                        onTap: () =>
                            bundle.ui.togglePanel(SenzuPanel.caption),
                      ),
                      order++,
                    ),
                  if (enableQuality)
                    btn(
                      SenzuTvButton(
                        icon: style.overlayIconsStyle.quality,
                        tooltip: style.senzuLanguage.quality,
                        onTap: () =>
                            bundle.ui.togglePanel(SenzuPanel.quality),
                      ),
                      order++,
                    ),
                  if (enableAudio)
                    btn(
                      SenzuTvButton(
                        icon: style.overlayIconsStyle.audio,
                        tooltip: style.senzuLanguage.audio,
                        onTap: () =>
                            bundle.ui.togglePanel(SenzuPanel.audio),
                      ),
                      order++,
                    ),
                  if (castController != null)
                    FocusTraversalOrder(
                      order: NumericFocusOrder(order.toDouble()),
                      child: SenzuCastButton(
                        castController: castController!,
                        bundle: bundle,
                        style: style,
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}