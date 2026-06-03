import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 2,
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
            progress REAL DEFAULT 0.0,
            subtitle_path TEXT,
            subtitle_key TEXT,
            subtitle_iv TEXT,
            drm_license_key TEXT,
            expired_at TEXT,
            bytes_downloaded INTEGER DEFAULT 0,
            total_bytes INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE download_tasks ADD COLUMN bytes_downloaded INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE download_tasks ADD COLUMN total_bytes INTEGER DEFAULT 0');
        }
      },
    );
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
