import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import '../data/database/download_database.dart';
import '../data/language/language.dart';

class SenzuDownloader {
  SenzuDownloader._() {
    _initListener();
  }
  static final SenzuDownloader instance = SenzuDownloader._();

  static const _method = MethodChannel('senzu_player/downloader');
  static const _event = EventChannel('senzu_player/downloader_events');

  final _statusController = StreamController<DownloadTask>.broadcast();
  Stream<DownloadTask> get onProgressChanged => _statusController.stream;

  StreamSubscription? _eventSubscription;

  final Map<String, int> _lastBytes = {};
  final Map<String, DateTime> _lastTime = {};

  void _initListener() {
    _eventSubscription = _event.receiveBroadcastStream().listen((data) async {
      final map = Map<String, dynamic>.from(data as Map);
      final id = map['id'] as String;
      final progress = (map['progress'] as num).toDouble();
      final status = map['status'] as String;
      final localPath = map['localPath'] as String?;
      final bytesDownloaded = map['bytesDownloaded'] as int?;
      final totalBytes = map['totalBytes'] as int?;

      // Calculate speed
      double? speed;
      if (bytesDownloaded != null) {
        final now = DateTime.now();
        final lastBytes = _lastBytes[id];
        final lastTime = _lastTime[id];
        if (lastBytes != null && lastTime != null) {
          final diffBytes = bytesDownloaded - lastBytes;
          final diffTimeMs = now.difference(lastTime).inMilliseconds;
          if (diffTimeMs > 0 && diffBytes >= 0) {
            speed = (diffBytes * 1000) / diffTimeMs;
          }
        }
        _lastBytes[id] = bytesDownloaded;
        _lastTime[id] = now;
      }

      if (status == 'completed' ||
          status == 'failed' ||
          status == 'paused' ||
          status == 'cancelled' ||
          status == 'deleted') {
        _lastBytes.remove(id);
        _lastTime.remove(id);
      }

      final db = DownloadDatabase.instance;
      final task = await db.getTask(id);
      if (task != null) {
        final updated = task.copyWith(
          progress: progress,
          status: status,
          localPath: localPath ?? task.localPath,
          bytesDownloaded: bytesDownloaded ?? task.bytesDownloaded,
          totalBytes: totalBytes ?? task.totalBytes,
          speed: speed,
        );
        await db.updateTask(updated);
        _statusController.add(updated);
      }
    }, onError: (err) {
      debugPrint('SenzuDownloader event error: $err');
    });
  }

  Future<void> startDownload({
    required String id,
    required String url,
    required String title,
    String? description,
    String? posterUrl,
    Map<String, String>? headers,
    Map<String, dynamic>? drmConfig,
    String? subtitleUrl,
    String? subtitleKey,
    String? subtitleIv,
    String? expiredAt, // ISO8601 string of expiry date
    SenzuLanguage language = const SenzuLanguage(),
  }) async {
    // 0. Set locales
    await setNotificationLocales(
      downloadCompleteTitle: language.downloadCompleteTitle,
      downloadCompleteBody: language.downloadCompleteBody,
      downloadFailedTitle: language.downloadFailedTitle,
      downloadFailedBody: language.downloadFailedBody,
      licenseExpiredTitle: language.licenseExpiredTitle,
      licenseExpiredBody: language.licenseExpiredBody,
    );

    // 1. Prepare SQLite task entry
    final task = DownloadTask(
      id: id,
      title: title,
      description: description,
      posterUrl: posterUrl,
      videoUrl: url,
      status: 'queued',
      progress: 0.0,
      subtitleKey: subtitleKey,
      subtitleIv: subtitleIv,
      expiredAt: expiredAt,
    );
    await DownloadDatabase.instance.insertTask(task);
    _statusController.add(task);

    // 2. Download subtitles if provided
    String? localSubtitlePath;
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      try {
        localSubtitlePath = await _downloadSubtitle(id, subtitleUrl, headers);
      } catch (e) {
        debugPrint('Error downloading subtitle: $e');
      }
    }

    // Update DB with subtitle path
    final taskWithSubtitle = task.copyWith(
      subtitlePath: localSubtitlePath,
    );
    await DownloadDatabase.instance.insertTask(taskWithSubtitle);

    // 3. Trigger native downloader
    try {
      await _method.invokeMethod('startDownload', {
        'id': id,
        'url': url,
        'headers': headers ?? {},
        'drmConfig': drmConfig ?? {},
        'title': title,
        'posterUrl': posterUrl ?? '',
        'description': description ?? '',
      });
    } catch (e) {
      final failedTask = taskWithSubtitle.copyWith(status: 'failed');
      await DownloadDatabase.instance.insertTask(failedTask);
      _statusController.add(failedTask);
      rethrow;
    }
  }

  Future<void> pauseDownload(String id) async {
    await _method.invokeMethod('pauseDownload', {'id': id});
    final db = DownloadDatabase.instance;
    final task = await db.getTask(id);
    if (task != null) {
      final updated = task.copyWith(status: 'paused');
      await db.updateTask(updated);
      _statusController.add(updated);
    }
  }

  Future<void> resumeDownload(String id) async {
    await _method.invokeMethod('resumeDownload', {'id': id});
    final db = DownloadDatabase.instance;
    final task = await db.getTask(id);
    if (task != null) {
      final updated = task.copyWith(status: 'downloading');
      await db.updateTask(updated);
      _statusController.add(updated);
    }
  }

  Future<void> cancelDownload(String id) async {
    await _method.invokeMethod('cancelDownload', {'id': id});
    await _deleteLocalFiles(id);
    final db = DownloadDatabase.instance;
    await db.deleteTask(id);
    _statusController.add(DownloadTask(
      id: id,
      title: '',
      videoUrl: '',
      status: 'cancelled',
      progress: 0.0,
    ));
  }

  Future<void> deleteDownload(String id) async {
    await _method.invokeMethod('deleteDownload', {'id': id});
    await _deleteLocalFiles(id);
    final db = DownloadDatabase.instance;
    await db.deleteTask(id);
    _statusController.add(DownloadTask(
      id: id,
      title: '',
      videoUrl: '',
      status: 'deleted',
      progress: 0.0,
    ));
  }

  Future<List<DownloadTask>> getAllTasks() async {
    return await DownloadDatabase.instance.getAllTasks();
  }

  // ── Bookmark / path utilities ─────────────────────────────────────────────

  /// iOS only: resolves a "bookmark:<base64>" string to the real absolute file
  /// path on the current device. Returns null if the bookmark is stale or if
  /// this is not iOS.
  Future<String?> resolveBookmark(String bookmarkString) async {
    if (!Platform.isIOS) return null;
    if (!bookmarkString.startsWith('bookmark:')) return null;
    try {
      final path = await _method.invokeMethod<String>(
        'resolveBookmark',
        {'bookmark': bookmarkString},
      );
      return path;
    } catch (e) {
      debugPrint('resolveBookmark error: $e');
      return null;
    }
  }

  /// iOS only: checks whether a file exists at [path].
  Future<bool> checkFileExists(String path) async {
    if (!Platform.isIOS) return File(path).existsSync();
    try {
      final exists = await _method.invokeMethod<bool>(
        'checkFileExists',
        {'path': path},
      );
      return exists ?? false;
    } catch (e) {
      debugPrint('checkFileExists error: $e');
      return false;
    }
  }

  // ── License expiry ────────────────────────────────────────────────────────

  Future<void> checkLicenses() async {
    final tasks = await getAllTasks();
    final now = DateTime.now();
    for (final task in tasks) {
      if (task.expiredAt != null && task.status == 'completed') {
        try {
          final expiry = DateTime.parse(task.expiredAt!);
          if (now.isAfter(expiry)) {
            await _method.invokeMethod('notifyLicenseExpired', {
              'id': task.id,
              'title': task.title,
            });
            final updated = task.copyWith(status: 'expired');
            await DownloadDatabase.instance.updateTask(updated);
            _statusController.add(updated);
          }
        } catch (e) {
          debugPrint('License date parse error: $e');
        }
      }
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      await _method.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  Future<void> setNotificationLocales({
    required String downloadCompleteTitle,
    required String downloadCompleteBody,
    required String downloadFailedTitle,
    required String downloadFailedBody,
    required String licenseExpiredTitle,
    required String licenseExpiredBody,
  }) async {
    try {
      await _method.invokeMethod('setNotificationLocales', {
        'downloadCompleteTitle': downloadCompleteTitle,
        'downloadCompleteBody': downloadCompleteBody,
        'downloadFailedTitle': downloadFailedTitle,
        'downloadFailedBody': downloadFailedBody,
        'licenseExpiredTitle': licenseExpiredTitle,
        'licenseExpiredBody': licenseExpiredBody,
      });
    } catch (e) {
      debugPrint('Error setting notification locales: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Downloads a subtitle file locally preserving raw bytes (keeps AES
  /// encryption intact if the server served encrypted content).
  Future<String> _downloadSubtitle(
      String taskId, String url, Map<String, String>? headers) async {
    final dir = await getApplicationDocumentsDirectory();
    final subDir = Directory(p.join(dir.path, 'senzu_downloads', taskId));
    if (!subDir.existsSync()) {
      await subDir.create(recursive: true);
    }

    final ext = p.extension(url).split('?').first;
    final fileName = 'subtitle${ext.isEmpty ? ".vtt" : ext}';
    final file = File(p.join(subDir.path, fileName));

    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } else {
      throw Exception(
          'Failed to download subtitle. Status code: ${response.statusCode}');
    }
  }

  Future<void> _deleteLocalFiles(String taskId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final subDir = Directory(p.join(dir.path, 'senzu_downloads', taskId));
      if (subDir.existsSync()) {
        await subDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting local subtitle files: $e');
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _statusController.close();
  }
}
