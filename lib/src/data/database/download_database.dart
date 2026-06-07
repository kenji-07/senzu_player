import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DownloadTask {
  final String id;
  final String title;
  final String? description;
  final String? posterUrl;
  final String videoUrl;
  final String? localPath;
  final String status; // 'queued', 'downloading', 'paused', 'completed', 'failed'
  final double progress; // 0.0 to 100.0
  final String? subtitlePath;
  final String? subtitleKey;
  final String? subtitleIv;
  final String? drmLicenseKey;
  final String? expiredAt; // ISO8601 string or expiry timestamp
  final int? bytesDownloaded;
  final int? totalBytes;
  final double? speed; // Transient download speed in bytes/sec
  final int episodeNumber; // 0 = none / movie
  final String videoType;  // e.g. 'movie', 'episode', 'trailer'

  const DownloadTask({
    required this.id,
    required this.title,
    this.description,
    this.posterUrl,
    required this.videoUrl,
    this.localPath,
    required this.status,
    required this.progress,
    this.subtitlePath,
    this.subtitleKey,
    this.subtitleIv,
    this.drmLicenseKey,
    this.expiredAt,
    this.bytesDownloaded,
    this.totalBytes,
    this.speed,
    this.episodeNumber = 0,
    this.videoType = '',
  });

  String get progressSizeText {
    if (bytesDownloaded == null || bytesDownloaded == 0) return '';
    final downloadedMb = bytesDownloaded! / (1024 * 1024);
    if (totalBytes != null && totalBytes! > 0) {
      final totalMb = totalBytes! / (1024 * 1024);
      return '${downloadedMb.toStringAsFixed(1)} MB / ${totalMb.toStringAsFixed(1)} MB';
    }
    return '${downloadedMb.toStringAsFixed(1)} MB';
  }

  String get completedSizeText {
    if (totalBytes != null && totalBytes! > 0) {
      final totalMb = totalBytes! / (1024 * 1024);
      return '${totalMb.toStringAsFixed(1)} MB';
    }
    if (bytesDownloaded != null && bytesDownloaded! > 0) {
      final downloadedMb = bytesDownloaded! / (1024 * 1024);
      return '${downloadedMb.toStringAsFixed(1)} MB';
    }
    return '';
  }

  String get speedText {
    if (speed == null || speed! <= 0) return '';
    final kb = speed! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB/s';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB/s';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'poster_url': posterUrl,
      'video_url': videoUrl,
      'local_path': localPath,
      'status': status,
      'progress': progress,
      'subtitle_path': subtitlePath,
      'subtitle_key': null, // Do not store subtitle decryption key in DB
      'subtitle_iv': null,  // Do not store subtitle decryption IV in DB
      'drm_license_key': drmLicenseKey,
      'expired_at': expiredAt,
      'bytes_downloaded': bytesDownloaded,
      'total_bytes': totalBytes,
      'episode_number': episodeNumber,
      'video_type': videoType,
    };
  }

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      posterUrl: map['poster_url'] as String?,
      videoUrl: map['video_url'] as String,
      localPath: map['local_path'] as String?,
      status: map['status'] as String,
      progress: (map['progress'] as num).toDouble(),
      subtitlePath: map['subtitle_path'] as String?,
      subtitleKey: null, // Do not read from DB
      subtitleIv: null,  // Do not read from DB
      drmLicenseKey: map['drm_license_key'] as String?,
      expiredAt: map['expired_at'] as String?,
      bytesDownloaded: map['bytes_downloaded'] as int?,
      totalBytes: map['total_bytes'] as int?,
      episodeNumber: (map['episode_number'] as int?) ?? 0,
      videoType: (map['video_type'] as String?) ?? '',
    );
  }

  DownloadTask copyWith({
    String? id,
    String? title,
    String? description,
    String? posterUrl,
    String? videoUrl,
    String? localPath,
    String? status,
    double? progress,
    String? subtitlePath,
    String? subtitleKey,
    String? subtitleIv,
    String? drmLicenseKey,
    String? expiredAt,
    int? bytesDownloaded,
    int? totalBytes,
    double? speed,
    int? episodeNumber,
    String? videoType,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      subtitlePath: subtitlePath ?? this.subtitlePath,
      subtitleKey: subtitleKey ?? this.subtitleKey,
      subtitleIv: subtitleIv ?? this.subtitleIv,
      drmLicenseKey: drmLicenseKey ?? this.drmLicenseKey,
      expiredAt: expiredAt ?? this.expiredAt,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      speed: speed ?? this.speed,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      videoType: videoType ?? this.videoType,
    );
  }

  Future<DownloadTask> resolvePaths() async {
    if (!Platform.isIOS) return this;
    final resolvedLocal = localPath != null ? await _resolveSandbox(localPath!) : null;
    final resolvedSub = subtitlePath != null ? await _resolveSandbox(subtitlePath!) : null;
    return copyWith(
      localPath: resolvedLocal,
      subtitlePath: resolvedSub,
    );
  }

  static Future<String> _resolveSandbox(String path) async {
    const token = 'Containers/Data/Application/';
    if (!path.contains(token)) return path;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final activeHomeRoot = docDir.path;

      final homeParts = activeHomeRoot.split(token);
      if (homeParts.length < 2) return path;
      final activeSubPath = homeParts[1];
      final activeSlashIdx = activeSubPath.indexOf('/');
      final activeUUID = activeSlashIdx == -1 ? activeSubPath : activeSubPath.substring(0, activeSlashIdx);
      final resolvedHome = '${homeParts[0]}$token$activeUUID';

      final pathParts = path.split(token);
      if (pathParts.length < 2) return path;
      final subPath = pathParts[1];
      final firstSlashIdx = subPath.indexOf('/');
      if (firstSlashIdx == -1) return path;
      final relativePath = subPath.substring(firstSlashIdx);

      return '$resolvedHome$relativePath';
    } catch (e) {
      return path;
    }
  }
}

class DownloadDatabase {
  DownloadDatabase._();
  static final DownloadDatabase instance = DownloadDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'senzu_downloads.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE download_tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            poster_url TEXT,
            video_url TEXT NOT NULL,
            local_path TEXT,
            status TEXT NOT NULL,
            progress REAL NOT NULL DEFAULT 0.0,
            subtitle_path TEXT,
            subtitle_key TEXT,
            subtitle_iv TEXT,
            drm_license_key TEXT,
            expired_at TEXT,
            bytes_downloaded INTEGER NOT NULL DEFAULT 0,
            total_bytes INTEGER NOT NULL DEFAULT 0,
            episode_number INTEGER NOT NULL DEFAULT 0,
            video_type TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE image_cache (
            id TEXT PRIMARY KEY,
            image_data BLOB NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE download_tasks ADD COLUMN bytes_downloaded INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE download_tasks ADD COLUMN total_bytes INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE download_tasks ADD COLUMN episode_number INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE download_tasks ADD COLUMN video_type TEXT NOT NULL DEFAULT \'\'');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS image_cache (
              id TEXT PRIMARY KEY,
              image_data BLOB NOT NULL,
              cached_at INTEGER NOT NULL
            )
          ''');
          await _createIndexes(db);
        }
      },
    );
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_download_tasks_status ON download_tasks(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_download_tasks_video_type ON download_tasks(video_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_download_tasks_expired_at ON download_tasks(expired_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_image_cache_cached_at ON image_cache(cached_at)');
  }

  Future<int> insertTask(DownloadTask task) async {
    final db = await database;
    return await db.insert(
      'download_tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTask(DownloadTask task) async {
    final db = await database;
    return await db.update(
      'download_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> updateProgress(String id, double progress, String status, {String? localPath}) async {
    final db = await database;
    final Map<String, dynamic> values = {
      'progress': progress,
      'status': status,
    };
    if (localPath != null) {
      values['local_path'] = localPath;
    }
    return await db.update(
      'download_tasks',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete(
      'download_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<DownloadTask?> getTask(String id) async {
    final db = await database;
    final maps = await db.query(
      'download_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return DownloadTask.fromMap(maps.first);
  }

  Future<List<DownloadTask>> getAllTasks() async {
    final db = await database;
    final maps = await db.query('download_tasks');
    return maps.map((m) => DownloadTask.fromMap(m)).toList();
  }
}

/// Persistent BLOB cache for poster / thumbnail images that belong to a
/// downloaded media item. Image data lives in the same SQLite file as the
/// download tasks so it is cleaned up together with the app.
class DownloadImageCache {
  DownloadImageCache._();

  /// Downloads [imageUrl] and stores the bytes under [id].
  /// Returns `true` on success.
  static Future<bool> downloadAndCache({
    required String imageUrl,
    required String id,
  }) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return false;
      final db = await DownloadDatabase.instance.database;
      await db.insert(
        'image_cache',
        {
          'id': id,
          'image_data': response.bodyBytes,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      developer.log('Image download error: $e', name: 'DownloadImageCache');
      return false;
    }
  }

  /// Returns the cached image bytes for [id] or `null` if missing.
  static Future<Uint8List?> getCached(String id) async {
    try {
      final db = await DownloadDatabase.instance.database;
      final maps = await db.query(
        'image_cache',
        columns: ['image_data'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return maps.first['image_data'] as Uint8List?;
    } catch (e) {
      developer.log('Get cached image error: $e', name: 'DownloadImageCache');
      return null;
    }
  }

  /// Removes the cached image for [id].
  static Future<void> delete(String id) async {
    final db = await DownloadDatabase.instance.database;
    await db.delete(
      'image_cache',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes every cached image.
  static Future<void> clearAll() async {
    final db = await DownloadDatabase.instance.database;
    await db.delete('image_cache');
  }

  /// Returns the total cache size in megabytes.
  static Future<double> sizeInMb() async {
    try {
      final db = await DownloadDatabase.instance.database;
      final result = await db.rawQuery(
        'SELECT SUM(LENGTH(image_data)) AS total FROM image_cache',
      );
      if (result.isEmpty || result.first['total'] == null) return 0.0;
      final bytes = (result.first['total'] as num).toInt();
      return bytes / (1024 * 1024);
    } catch (e) {
      developer.log('Get cache size error: $e', name: 'DownloadImageCache');
      return 0.0;
    }
  }
}
