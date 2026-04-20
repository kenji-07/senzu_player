import 'package:flutter/material.dart';
import 'feature_basic.dart';
import 'feature_quality.dart';
import 'feature_drm.dart';
import 'feature_chapters.dart';
import 'feature_cast.dart';
import 'feature_watermark.dart';
import 'feature_annotations.dart';
import 'feature_sleep_timer.dart';
import 'feature_token_refresh.dart';
import 'feature_thumbnail_sprite.dart';
import 'feature_data_policy.dart';
import 'feature_ads.dart';
import 'feature_live.dart';
import 'feature_pip.dart';
import 'feature_download_bundle.dart';

class FeatureListPage extends StatelessWidget {
  const FeatureListPage({Key? key}) : super(key: key);

  static final _items = <_FeatureItem>[
    const _FeatureItem(
      icon: Icons.play_circle_fill,
      title: '1. Basic Playback',
      subtitle: 'HLS / MP4, autoplay, loop, aspect ratio',
      color: Color(0xFF00CA13),
      page: FeatureBasicPage(),
    ),
    const _FeatureItem(
      icon: Icons.hd,
      title: '2. Multi-Quality',
      subtitle: 'M3U8 playlist parse, ABR, quality panel',
      color: Color(0xFF2196F3),
      page: FeatureQualityPage(),
    ),
    const _FeatureItem(
      icon: Icons.lock,
      title: '4. DRM',
      subtitle: 'FairPlay (iOS) & Widevine (Android)',
      color: Color(0xFFF44336),
      page: FeatureDrmPage(),
    ),
    const _FeatureItem(
      icon: Icons.skip_next,
      title: '5. Chapters & Skip OP/ED',
      subtitle: 'Chapter markers, skip buttons, tooltips',
      color: Color(0xFFFF9800),
      page: FeatureChaptersPage(),
    ),
    const _FeatureItem(
      icon: Icons.cast,
      title: '6. Google Cast',
      subtitle: 'Chromecast, quality/subtitle/audio on receiver',
      color: Color(0xFF00BCD4),
      page: FeatureCastPage(),
    ),
    const _FeatureItem(
      icon: Icons.water_drop,
      title: '7. Watermark',
      subtitle: 'Floating watermark, userId, timestamp, random',
      color: Color(0xFF607D8B),
      page: FeatureWatermarkPage(),
    ),
    const _FeatureItem(
      icon: Icons.layers,
      title: '8. Annotations',
      subtitle: 'Tappable overlays at specific timestamps',
      color: Color(0xFFE91E63),
      page: FeatureAnnotationsPage(),
    ),
    const _FeatureItem(
      icon: Icons.bedtime,
      title: '9. Sleep Timer',
      subtitle: 'Countdown, fade out, wakelock',
      color: Color(0xFF3F51B5),
      page: FeatureSleepTimerPage(),
    ),
    const _FeatureItem(
      icon: Icons.vpn_key,
      title: '10. Token / Signed URL Refresh',
      subtitle: 'Auto refresh before expiry',
      color: Color(0xFF795548),
      page: FeatureTokenRefreshPage(),
    ),
    const _FeatureItem(
      icon: Icons.grid_view,
      title: '11. Thumbnail Sprite',
      subtitle: 'Seek preview from sprite sheet',
      color: Color(0xFF009688),
      page: FeatureThumbnailSpritePage(),
    ),
    const _FeatureItem(
      icon: Icons.signal_cellular_alt,
      title: '12. Data Policy',
      subtitle: 'Cellular warning, data saver mode',
      color: Color(0xFFFF5722),
      page: FeatureDataPolicyPage(),
    ),
    const _FeatureItem(
      icon: Icons.ads_click,
      title: '13. Ads (IMA / Custom)',
      subtitle: 'VAST pre-roll, mid-roll, skip countdown',
      color: Color(0xFFFFEB3B),
      page: FeatureAdsPage(),
    ),
    const _FeatureItem(
      icon: Icons.live_tv,
      title: '14. Live Stream',
      subtitle: 'DVR, live badge, low-latency, go-to-live',
      color: Color(0xFFF44336),
      page: FeatureLivePage(),
    ),
    const _FeatureItem(
      icon: Icons.picture_in_picture_alt,
      title: '15. Picture-in-Picture',
      subtitle: 'PiP button, auto-enter, overlay',
      color: Color(0xFF4CAF50),
      page: FeaturePipPage(),
    ),
    const _FeatureItem(
      icon: Icons.tune,
      title: '16. External Bundle Control',
      subtitle: 'Control player from outside the widget',
      color: Color(0xFF9E9E9E),
      page: FeatureBundlePage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SenzuPlayer Demo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, i) {
          final item = _items[i];
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            title: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              item.subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.white24,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => item.page),
            ),
          );
        },
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.page,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget page;
}
