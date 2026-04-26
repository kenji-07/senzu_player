import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:senzu_player/src/data/models/subtitle_model.dart';
import 'package:senzu_player/src/data/models/senzu_drm_config.dart';
import 'package:senzu_player/src/data/models/ad_model.dart';
import 'package:senzu_player/src/data/models/senzu_thumbnail_sprite.dart';

// ── VideoProtocol ─────────────────────────────────────────────────────────────
enum VideoProtocol { hls, dash, mp4 }

class VideoSource {
  VideoSource({
    required this.dataSource,
    this.ads,
    this.subtitle,
    this.initialSubtitle = '',
    this.range,
    this.httpHeaders,
    this.thumbnailSprite,
    this.isLowLatency = false,
    this.targetLatencyMs,
    this.forceCodec,
    this.drm,
    this.protocol = VideoProtocol.hls,
  });

  final String dataSource;
  final List<SenzuPlayerAd>? ads;
  final Map<String, SenzuPlayerSubtitle>? subtitle;
  final String initialSubtitle;
  final Tween<Duration>? range;
  final Map<String, String>? httpHeaders;
  final SenzuThumbnailSprite? thumbnailSprite;
  final bool isLowLatency;
  final int? targetLatencyMs;
  final String? forceCodec;
  final VideoProtocol protocol;
  final SenzuDrmConfig? drm;

  @Deprecated('Use initialSubtitle instead.')
  String get intialSubtitle => initialSubtitle;

  // ── fromUrl (үндсэн constructor) ────────────────────────────────────
  static VideoSource fromUrl(
    String url, {
    Map<String, String>? httpHeaders,
    List<SenzuPlayerAd>? ads,
    Map<String, SenzuPlayerSubtitle>? subtitle,
    String initialSubtitle = '',
    Tween<Duration>? range,
    SenzuThumbnailSprite? thumbnailSprite,
    bool isLowLatency = false,
    int? targetLatencyMs,
    String? forceCodec,
    VideoProtocol protocol = VideoProtocol.hls,
    final SenzuDrmConfig? drm,
  }) =>
      VideoSource(
        dataSource: url,
        httpHeaders: httpHeaders,
        ads: ads,
        subtitle: subtitle,
        initialSubtitle: initialSubtitle,
        range: range,
        thumbnailSprite: thumbnailSprite,
        isLowLatency: isLowLatency,
        targetLatencyMs: targetLatencyMs,
        forceCodec: forceCodec,
        protocol: protocol,
        drm: drm,
      );

  // ── fromDashUrl ───────────────────────────────────────────────────────────
  static VideoSource fromDashUrl(
    String url, {
    Map<String, String>? httpHeaders,
    List<SenzuPlayerAd>? ads,
    Map<String, SenzuPlayerSubtitle>? subtitle,
    String initialSubtitle = '',
    Tween<Duration>? range,
    final SenzuDrmConfig? drm,
  }) =>
      VideoSource(
        dataSource: url,
        protocol: VideoProtocol.dash,
        httpHeaders: httpHeaders,
        ads: ads,
        subtitle: subtitle,
        initialSubtitle: initialSubtitle,
        range: range,
        drm: drm,
      );

  // ── fromFile ───────────────────────────────────────────────────────────────
  static VideoSource fromFile(
    String filePath, {
    List<SenzuPlayerAd>? ads,
    Map<String, SenzuPlayerSubtitle>? subtitle,
    String initialSubtitle = '',
    Tween<Duration>? range,
    SenzuThumbnailSprite? thumbnailSprite,
  }) =>
      VideoSource(
        dataSource: filePath,
        protocol: VideoProtocol.mp4,
        ads: ads,
        subtitle: subtitle,
        initialSubtitle: initialSubtitle,
        range: range,
        thumbnailSprite: thumbnailSprite,
      );

  // ── fromAsset ──────────────────────────────────────────────────────────────
  // Asset playback native layer-д дэмжихгүй тул file path болгон хөрвүүлнэ.
  // Хэрэглэгч өөрөө asset-г file-д copy хийж path дамжуулах шаардлагатай.
  @Deprecated(
    'Asset playback is not supported by the native player. Use fromFile instead.',
  )
  static VideoSource fromAsset(
    String assetPath, {
    String package = '',
    List<SenzuPlayerAd>? ads,
    Map<String, SenzuPlayerSubtitle>? subtitle,
    String initialSubtitle = '',
    Tween<Duration>? range,
    SenzuThumbnailSprite? thumbnailSprite,
  }) =>
      VideoSource(
        dataSource: assetPath,
        protocol: VideoProtocol.mp4,
        ads: ads,
        subtitle: subtitle,
        initialSubtitle: initialSubtitle,
        range: range,
        thumbnailSprite: thumbnailSprite,
      );

  // ── fromNetworkVideoSources ───────────────────────────────────────────────
  static Map<String, VideoSource> fromNetworkVideoSources(
    Map<String, String> sources, {
    String initialSubtitle = '',
    Map<String, SenzuPlayerSubtitle>? subtitle,
    List<SenzuPlayerAd>? ads,
    Tween<Duration>? range,
    Map<String, String>? httpHeaders,
    SenzuThumbnailSprite? thumbnailSprite,
    final SenzuDrmConfig? drm,
  }) =>
      sources.map(
        (k, url) => MapEntry(
          k,
          VideoSource(
            dataSource: url,
            initialSubtitle: initialSubtitle,
            subtitle: subtitle,
            ads: ads,
            range: range,
            httpHeaders: httpHeaders,
            thumbnailSprite: thumbnailSprite,
            drm: drm,
          ),
        ),
      );

  // ── fromM3u8PlaylistUrl ───────────────────────────────────────────────────
  static Future<Map<String, VideoSource>> fromM3u8PlaylistUrl(
    String m3u8, {
    String initialSubtitle = '',
    Map<String, SenzuPlayerSubtitle>? subtitle,
    List<SenzuPlayerAd>? ads,
    Tween<Duration>? range,
    String Function(String)? formatter,
    bool descending = true,
    Map<String, String>? httpHeaders,
    bool autoSubtitle = true,
    String initialSubtitleLang = '',
    SenzuThumbnailSprite? thumbnailSprite,
    final SenzuDrmConfig? drm,
  }) async {
    final content = await _fetch(m3u8, httpHeaders);
    final sourceUrls = _parseVariants(content, m3u8);

    String resolvedInitial = initialSubtitle;
    Map<String, SenzuPlayerSubtitle>? resolvedSubs = subtitle;

    if (autoSubtitle && subtitle == null) {
      final r = await _parseSubs(
        content,
        m3u8,
        httpHeaders,
        initialSubtitleLang,
      );
      if (r.subtitles.isNotEmpty) {
        resolvedSubs = r.subtitles;
        resolvedInitial = r.initialName;
      }
    }

    VideoSource bb(String url) => VideoSource(
          dataSource: url,
          initialSubtitle: resolvedInitial,
          subtitle: resolvedSubs,
          ads: ads,
          range: range,
          httpHeaders: httpHeaders,
          thumbnailSprite: thumbnailSprite,
          drm: drm,
        );

    final sorted = sourceUrls.entries.toList()
      ..sort((a, b) {
        if (!descending) return 0;
        final ah = int.tryParse(a.key.split('x').last) ?? 0;
        final bh = int.tryParse(b.key.split('x').last) ?? 0;
        return bh.compareTo(ah);
      });

    final result = <String, VideoSource>{};
    if (descending) result['Auto'] = bb(m3u8);
    for (final e in sorted) {
      result[formatter?.call(e.key) ?? e.key] = bb(e.value);
    }
    if (!descending) result['Auto'] = bb(m3u8);
    return result;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Future<String> _fetch(String url, Map<String, String>? h) async {
    final r = await http.get(Uri.parse(url), headers: h ?? {});
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}: $url');
    return utf8.decode(r.bodyBytes);
  }

  static Map<String, String> _parseVariants(String content, String base) {
    final urlRx = RegExp(r'^https?://', caseSensitive: false);
    final bRx = RegExp(r'(.*)\r?/');
    final varRx = RegExp(
      r'#EXT-X-STREAM-INF:(?:.*,RESOLUTION=(\d+x\d+))?,?(.*)\r?\n(.*)',
      caseSensitive: false,
      multiLine: true,
    );
    final result = <String, String>{};
    for (final m in varRx.allMatches(content)) {
      final raw = m.group(3) ?? '', q = m.group(1) ?? '';
      if (raw.isEmpty || q.isEmpty) continue;
      result[q] = urlRx.hasMatch(raw)
          ? raw
          : '${bRx.firstMatch(base)?.group(0) ?? ''}$raw';
    }
    return result;
  }

  static Future<_SubRes> _parseSubs(
    String content,
    String baseUrl,
    Map<String, String>? h,
    String initLang,
  ) async {
    final trackRx = RegExp(
      r'#EXT-X-MEDIA:TYPE=SUBTITLES'
      r'(?:[^"\n]*,LANGUAGE="([^"]*)")?'
      r'(?:[^"\n]*,NAME="([^"]*)")?'
      r'(?:[^"\n]*,URI="([^"]*)")?',
      caseSensitive: false,
      multiLine: true,
    );
    final urlRx = RegExp(r'^https?://', caseSensitive: false);
    final bRx = RegExp(r'(.*)\r?/');
    final subs = <String, SenzuPlayerSubtitle>{};
    var initName = '';
    for (final m in trackRx.allMatches(content)) {
      final lang = m.group(1) ?? '',
          name = m.group(2) ?? lang,
          raw = m.group(3) ?? '';
      if (raw.isEmpty) continue;
      final url = urlRx.hasMatch(raw)
          ? raw
          : '${bRx.firstMatch(baseUrl)?.group(0) ?? ''}$raw';
      try {
        final vtt = await _resolveVtt(url, h);
        if (vtt.isNotEmpty) {
          subs[name] = SenzuPlayerSubtitle.content(vtt, url);
          if (initName.isEmpty &&
              (initLang.isEmpty ||
                  lang.toLowerCase() == initLang.toLowerCase() ||
                  name.toLowerCase() == initLang.toLowerCase())) {
            initName = name;
          }
        }
      } catch (_) {}
    }
    if (initName.isEmpty && subs.isNotEmpty) initName = subs.keys.first;
    return _SubRes(subs, initName);
  }

  static Future<String> _resolveVtt(String url, Map<String, String>? h) async {
    final r = await http.get(Uri.parse(url), headers: h ?? {});
    if (r.statusCode != 200) throw Exception('Sub HTTP ${r.statusCode}');
    final body = utf8.decode(r.bodyBytes);
    return _isM3u8(body) ? await _mergeVtt(body, url, h) : body;
  }

  static bool _isM3u8(String s) {
    final t = s.trimLeft();
    return t.startsWith('#EXTM3U') ||
        t.contains('#EXTINF') ||
        t.contains('#EXT-X-TARGETDURATION');
  }

  static Future<String> _mergeVtt(
    String playlist,
    String plUrl,
    Map<String, String>? h,
  ) async {
    final urlRx = RegExp(r'^https?://', caseSensitive: false);
    final bRx = RegExp(r'(.*)\r?/');
    final segRx = RegExp(
      r'#EXTINF:([\d.]+),?\r?\n([^\r\n#][^\r\n]*)',
      multiLine: true,
    );
    final base = bRx.firstMatch(plUrl)?.group(0) ?? '';
    var off = Duration.zero;
    final futures = segRx.allMatches(playlist).map((m) {
      final d = double.tryParse(m.group(1) ?? '0') ?? 0.0;
      final s = m.group(2)!.trim();
      final u = urlRx.hasMatch(s) ? s : '$base$s';
      final o = off;
      off += Duration(milliseconds: (d * 1000).round());
      return _fetchSeg(u, h, o);
    });
    return _combine(await Future.wait(futures));
  }

  static Future<_Seg> _fetchSeg(
    String url,
    Map<String, String>? h,
    Duration off,
  ) async {
    try {
      final r = await http.get(Uri.parse(url), headers: h ?? {});
      return _Seg(r.statusCode == 200 ? utf8.decode(r.bodyBytes) : '', off);
    } catch (_) {
      return _Seg('', off);
    }
  }

  static String _combine(List<_Seg> segs) {
    final buf = StringBuffer('WEBVTT\n\n');
    final tsRx = RegExp(
      r'(\d{2}:\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3})',
    );
    var idx = 1;
    for (final seg in segs) {
      if (seg.content.isEmpty) continue;
      final lines = seg.content.replaceAll('\r\n', '\n').split('\n');
      var i = 0;
      if (lines.isNotEmpty && lines[0].startsWith('WEBVTT')) {
        i = 1;
        while (i < lines.length && lines[i].trim().isEmpty) {
          i++;
        }
        if (i < lines.length && lines[i].startsWith('NOTE')) {
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            i++;
          }
        }
      }
      final cue = StringBuffer();
      var inCue = false;
      for (; i < lines.length; i++) {
        final line = lines[i];
        if (tsRx.hasMatch(line)) {
          inCue = true;
          final adj = line.replaceAllMapped(tsRx, (m) {
            final s = _pts(m.group(1)!) + seg.off;
            final e = _pts(m.group(2)!) + seg.off;
            return '${_fts(s)} --> ${_fts(e)}';
          });
          cue.writeln('${idx++}');
          cue.writeln(adj);
        } else if (inCue) {
          cue.writeln(line);
          if (line.trim().isEmpty) {
            buf.write(cue);
            cue.clear();
            inCue = false;
          }
        }
      }
      if (cue.isNotEmpty) {
        buf.write(cue);
        buf.write('\n');
      }
    }
    return buf.toString();
  }

  static Duration _pts(String ts) {
    final p = ts.split(':'), sm = p[2].split('.');
    return Duration(
      hours: int.parse(p[0]),
      minutes: int.parse(p[1]),
      seconds: int.parse(sm[0]),
      milliseconds: int.parse(sm.length > 1 ? sm[1] : '0'),
    );
  }

  static String _fts(Duration d) => '${d.inHours.toString().padLeft(2, '0')}:'
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}.'
      '${d.inMilliseconds.remainder(1000).toString().padLeft(3, '0')}';
}

class _SubRes {
  const _SubRes(this.subtitles, this.initialName);
  final Map<String, SenzuPlayerSubtitle> subtitles;
  final String initialName;
}

class _Seg {
  const _Seg(this.content, this.off);
  final String content;
  final Duration off;
}
