import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:senzu_player/senzu_player.dart';

class OfflinePlayerPage extends StatefulWidget {
  final DownloadTask task;
  const OfflinePlayerPage({super.key, required this.task});

  @override
  State<OfflinePlayerPage> createState() => _OfflinePlayerPageState();
}

class _OfflinePlayerPageState extends State<OfflinePlayerPage> {
  SenzuPlayerBundle? _bundle;
  bool _isLoading = true;
  String? _fileError; // non-null → show error UI instead of player
  late DownloadTask _resolvedTask;

  @override
  void initState() {
    super.initState();
    _resolvedTask = widget.task;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _initPlayer();
  }

  void _initPlayer() async {
    _bundle = SenzuPlayerBundle.create(
      looping: false,
      secureMode: true,
      notification: true,
    );

    // Resolve any sandbox-UUID stale paths (Android/iOS Containers paths)
    final resolved = await widget.task.resolvePaths();

    // On iOS: verify the bookmark / file still exists before opening the player.
    // This catches stale bookmarks after app reinstall / device restore.
    if (resolved.localPath != null && resolved.localPath!.isNotEmpty) {
      final path = resolved.localPath!;
      if (path.startsWith('bookmark:')) {
        final realPath = await SenzuDownloader.instance.resolveBookmark(path);
        if (realPath == null) {
          if (mounted) {
            setState(() {
              _resolvedTask = resolved;
              _fileError =
                  'Offline file not found (bookmark stale).\nPlease download again.';
              _isLoading = false;
            });
          }
          return;
        }
        final exists = await SenzuDownloader.instance.checkFileExists(realPath);
        if (!exists) {
          if (mounted) {
            setState(() {
              _resolvedTask = resolved;
              _fileError =
                  'The offline file has been deleted.\nPlease download it again.';
              _isLoading = false;
            });
          }
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        _resolvedTask = resolved;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _bundle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // File inaccessible (stale bookmark / deleted media)
    if (_fileError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                Text(
                  _fileError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Determine offline source URL.
    //
    // Priority:
    //  - Android Media3 cache:  'offline_media://<id>' → fall back to original HTTP URL
    //  - iOS bookmark:          'bookmark:<base64>'    → pass as-is; iOS native resolves it
    //  - Raw path / file URL:   add file:// prefix if missing
    //  - No local path at all:  use original HTTP URL (stream)
    final String? storedPath = _resolvedTask.localPath;
    String sourceUrl;
    bool isBookmark = false;

    if (storedPath == null || storedPath.isEmpty) {
      sourceUrl = _resolvedTask.videoUrl;
    } else if (storedPath.startsWith('offline_media://')) {
      // Android Media3 — play from original URL via SimpleCache
      sourceUrl = _resolvedTask.videoUrl;
    } else if (storedPath.startsWith('bookmark:')) {
      // iOS bookmark — pass opaque string directly to native; native resolves it
      sourceUrl = storedPath;
      isBookmark = true;
    } else if (storedPath.startsWith('file://') ||
        storedPath.startsWith('http://') ||
        storedPath.startsWith('https://')) {
      sourceUrl = storedPath;
    } else {
      // Raw absolute path — add file:// prefix
      sourceUrl = 'file://$storedPath';
    }

    // Protocol: infer HLS from stored path OR from original URL when using bookmark
    final String urlForProtocolCheck =
        isBookmark ? _resolvedTask.videoUrl : sourceUrl;
    final bool isHls = urlForProtocolCheck.contains('.m3u8') ||
        urlForProtocolCheck.contains('.m3u8?') ||
        sourceUrl.contains('.movpkg');

    // Set up offline subtitle decrypt/local parser
    final Map<String, SenzuPlayerSubtitle> offlineSubtitles = {};
    if (_resolvedTask.subtitlePath != null &&
        _resolvedTask.subtitlePath!.isNotEmpty) {
      final isDecrypted = _resolvedTask.subtitleKey != null &&
          _resolvedTask.subtitleKey!.isNotEmpty &&
          _resolvedTask.subtitleIv != null &&
          _resolvedTask.subtitleIv!.isNotEmpty;
      if (isDecrypted) {
        offlineSubtitles['Offline (Decrypted)'] = SenzuPlayerSubtitle.decrypt(
          _resolvedTask.subtitlePath!,
          keyHex: _resolvedTask.subtitleKey,
          ivHex: _resolvedTask.subtitleIv,
          type: SubtitleType.webvtt,
        );
      } else {
        offlineSubtitles['Offline'] = SenzuPlayerSubtitle.network(
          _resolvedTask.subtitlePath!,
          type: SubtitleType.webvtt,
        );
      }
    }

    final videoSource = VideoSource(
      dataSource: sourceUrl,
      initialSubtitle:
          offlineSubtitles.isNotEmpty ? offlineSubtitles.keys.first : '',
      subtitle: offlineSubtitles.isNotEmpty ? offlineSubtitles : null,
      protocol: isHls ? VideoProtocol.hls : VideoProtocol.mp4,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Close header button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resolvedTask.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.wifi_off, color: Colors.white30, size: 18),
                ],
              ),
            ),
            // Player
            Expanded(
              child: Center(
                child: SenzuPlayer(
                  source: {'Default': videoSource},
                  bundle: _bundle!,
                  autoPlay: true,
                  enableFullscreen: true,
                  enableCaption: offlineSubtitles.isNotEmpty,
                  enableQuality:
                      false, // Local file doesn't need ABR quality selection
                  enableSpeed: true,
                  enableLock: true,
                  enablePip: true,
                  isLive: false,
                  meta: SenzuMetaData(
                    title: _resolvedTask.title,
                    description:
                        _resolvedTask.description ?? 'Offline playback',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
