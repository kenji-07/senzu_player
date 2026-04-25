import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';

import 'senzu_tv_button.dart';

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
    this.castController,
    this.firstFocusNode,
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
  final FocusNode? firstFocusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            children: [
              if (meta.show ?? true)
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (meta.title != null)
                          Text(
                            meta.title!,
                            style: meta.titleStyle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        if (meta.description != null)
                          Text(
                            meta.description!,
                            style: meta.descriptionStyle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),
              Obx(() {
                final isLive = bundle.core.isLiveRx.value;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (enableAspect)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: SenzuTvButton(
                          icon: style.overlayIconsStyle.aspect,
                          tooltip: style.senzuLanguage.aspectRatio,
                          focusNode: firstFocusNode,
                          onTap: () => bundle.ui.togglePanel(SenzuPanel.aspect),
                        ),
                      ),
                    if (enableSpeed && !isLive)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: SenzuTvButton(
                          icon: style.overlayIconsStyle.speed,
                          tooltip: style.senzuLanguage.playbackSpeed,
                          onTap: () => bundle.ui.togglePanel(SenzuPanel.speed),
                        ),
                      ),
                    if (enableCaption)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(3),
                        child: SenzuTvButton(
                          icon: style.overlayIconsStyle.caption,
                          tooltip: style.senzuLanguage.subtitles,
                          onTap: () =>
                              bundle.ui.togglePanel(SenzuPanel.caption),
                        ),
                      ),
                    if (enableQuality)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(4),
                        child: SenzuTvButton(
                          icon: style.overlayIconsStyle.quality,
                          tooltip: style.senzuLanguage.quality,
                          onTap: () =>
                              bundle.ui.togglePanel(SenzuPanel.quality),
                        ),
                      ),
                    if (enableAudio)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(5),
                        child: SenzuTvButton(
                          icon: style.overlayIconsStyle.audio,
                          tooltip: style.senzuLanguage.audio,
                          onTap: () => bundle.ui.togglePanel(SenzuPanel.audio),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ));
  }
}
