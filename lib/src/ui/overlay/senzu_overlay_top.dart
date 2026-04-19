import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';
import 'package:senzu_player/src/data/models/senzu_metadata.dart';
import 'package:senzu_player/src/cast/widgets/senzu_cast_button.dart';
import 'package:senzu_player/src/cast/senzu_cast_controller.dart';

class SenzuOverlayTop extends StatelessWidget {
  const SenzuOverlayTop({
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
      padding: const EdgeInsets.only(top: 8, left: 12, right: 8, bottom: 12),
      child: Row(
        children: [
          if (meta.show ?? true)
            Expanded(
              child: GestureDetector(
                onTap: () => bundle.core.closeFullscreen(),
                child: Row(
                  children: [
                    Icon(meta.icon, color: meta.iconColor, size: meta.iconSize),
                    const SizedBox(width: 8),
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
                    ),
                    const SizedBox(width: 8),
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
                // Sleep timer
                _Btn(
                  Icons.bedtime_outlined,
                  () => bundle.ui.togglePanel(SenzuPanel.sleep),
                ),

                // Aspect ratio
                if (enableAspect)
                  _Btn(
                    Icons.aspect_ratio,
                    () => bundle.ui.togglePanel(SenzuPanel.aspect),
                  ),

                // Speed (not available for live)
                if (enableSpeed && !isLive)
                  _Btn(
                    Icons.speed,
                    () => bundle.ui.togglePanel(SenzuPanel.speed),
                  ),

                // Captions
                if (enableCaption)
                  _Btn(
                    Icons.closed_caption,
                    () => bundle.ui.togglePanel(SenzuPanel.caption),
                  ),

                // Quality
                if (enableQuality)
                  _Btn(
                    Icons.hd,
                    () => bundle.ui.togglePanel(SenzuPanel.quality),
                  ),

                // Audio tracks
                if (enableAudio)
                  _Btn(
                    Icons.audiotrack,
                    () => bundle.ui.togglePanel(SenzuPanel.audio),
                  ),

                // Cast
                if (castController != null)
                  SenzuCastButton(
                    castController: castController!,
                    bundle: bundle,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}
