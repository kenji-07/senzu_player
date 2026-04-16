import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'example_player_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title:                      'Project - v2.0+89',
      debugShowCheckedModeBanner: false,
      theme:                      ThemeData.dark(),
      home:                       const ExampleHome(),
    );
  }
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Project - v2.0+89',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            icon:     Icons.play_circle_outline,
            title:    'VOD Player',
            subtitle: 'HLS · Seek thumbnail · Skip OP/ED · ABR',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'VOD Player',
                  mode:  PlayerMode.vod,
                )),
          ),
          _Card(
            icon:     Icons.sensors,
            title:    'Live Stream',
            subtitle: 'Энгийн live · Auto reconnect',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Live Stream',
                  mode:  PlayerMode.live,
                )),
          ),
          _Card(
            icon:     Icons.history,
            title:    'DVR Live',
            subtitle: 'Live + seek bar · Live edge badge',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'DVR Live',
                  mode:  PlayerMode.dvr,
                )),
          ),
          _Card(
            icon:     Icons.queue_music,
            title:    'Multi Audio Track',
            subtitle: 'Дуу хэлний сонголт · HLS audio tracks',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Multi Audio',
                  mode:  PlayerMode.multiAudio,
                )),
          ),
          _Card(
            icon:     Icons.image_search,
            title:    'Seek Thumbnail',
            subtitle: 'Sprite sheet preview · Progress bar drag',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Seek Thumbnail',
                  mode:  PlayerMode.seekThumbnail,
                )),
          ),
          _Card(
            icon:     Icons.code,
            title:    'Programmatic Control',
            subtitle: 'External controller · Volume · Seek · Info',
            onTap: () => Get.to(() => const ExamplePlayerPage(
                  title: 'Programmatic',
                  mode:  PlayerMode.programmatic,
                )),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color:  const Color(0xFF1A1A1A),
        margin: const EdgeInsets.only(bottom: 12),
        shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width:  44,
            height: 44,
            decoration: BoxDecoration(
              color:        Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFFF4444), size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          trailing: const Icon(Icons.chevron_right,
              color: Colors.white24, size: 20),
          onTap: onTap,
        ),
      );
}