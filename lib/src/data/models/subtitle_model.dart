import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum SubtitleType { webvtt, srt }

enum SubtitleInitializeType { network, decrypt, string }

/// @deprecated Use [SubtitleInitializeType]. Removed in v3.0.0.
@Deprecated('Use SubtitleInitializeType instead.')
typedef SubtitleIntializeType = SubtitleInitializeType;

// ── SubtitleData ──────────────────────────────────────────────────────────────

class SubtitleData {
  const SubtitleData({
    this.start = Duration.zero,
    this.end = Duration.zero,
    this.text = '',
    required this.url,
  });
  final Duration start;
  final Duration end;
  final String text;
  final String url;
}

// ── SenzuPlayerSubtitle ───────────────────────────────────────────────────────

class SenzuPlayerSubtitle {
  SenzuPlayerSubtitle.network(
    this.url_, {
    this.type = SubtitleType.webvtt,
    Map<String, String>? headers,
  })  : initType = SubtitleInitializeType.network,
        keyHex = null,
        ivHex = null,
        content = '' {
    if (headers != null) _headers.addAll(headers);
  }

  SenzuPlayerSubtitle.content(
    this.content,
    this.url_, {
    this.type = SubtitleType.webvtt,
    Map<String, String>? headers,
  })  : initType = SubtitleInitializeType.string,
        keyHex = null,
        ivHex = null {
    if (headers != null) _headers.addAll(headers);
  }

  SenzuPlayerSubtitle.decrypt(
    this.url_, {
    required this.keyHex,
    required this.ivHex,
    this.type = SubtitleType.webvtt,
    Map<String, String>? headers,
  })  : initType = SubtitleInitializeType.decrypt,
        content = '' {
    if (headers != null) _headers.addAll(headers);
  }

  final SubtitleInitializeType initType;
  final SubtitleType type;
  final String? keyHex;
  final String? ivHex;
  String content;
  final String url_;
  final Map<String, String> _headers = {};
  final List<SubtitleData> _subs = [];

  List<SubtitleData> get subtitles => List.unmodifiable(_subs);

  Future<void> initialize() async {
    switch (initType) {
      case SubtitleInitializeType.network:
        final r = await http.get(Uri.parse(url_), headers: _headers);
        content = r.statusCode == 200 ? utf8.decode(r.bodyBytes) : '';
        _parse();
      case SubtitleInitializeType.decrypt:
        final r = await http.get(Uri.parse(url_), headers: _headers);
        content = r.statusCode == 200
            ? _decryptCdn(utf8.decode(r.bodyBytes), keyHex!, ivHex!)
            : '';
        _parse();
      case SubtitleInitializeType.string:
        _parse();
    }
  }

  void _parse() {
    _subs.clear();
    final re = type == SubtitleType.webvtt
        ? RegExp(
            r'(\d+)?\n(?:(\d{1,}):)?(?:(\d{1,2}):)?(\d{1,2})[.,]+(\d+)\s*-->\s*(?:(\d{1,2}):)?(?:(\d{1,2}):)?(\d{1,2}).(\d+)(?:.*(?:\r?(?!\r?).*)*)\n(.*(?:\r?\n(?!\r?\n).*)*)',
            caseSensitive: false,
            multiLine: true)
        : RegExp(
            r'((\d{2}):(\d{2}):(\d{2})\,(\d+)) +--> +((\d{2}):(\d{2}):(\d{2})\,(\d{3})).*[\r\n]+\s*((?:(?!\r?\n\r?).)*(\r\n|\r|\n)(?:.*))',
            caseSensitive: false,
            multiLine: true);

    for (final m in re.allMatches(content)) {
      _subs.add(SubtitleData(
        start: _dur(m, 2, 3, 4, 5),
        end: _dur(m, 6, 7, 8, 9),
        text: _strip(m.group(10) ?? '').trim(),
        url: url_,
      ));
    }
  }

  Duration _dur(RegExpMatch m, int hG, int mG, int sG, int msG) {
    int h = 0, mn = 0;
    if (m.group(mG) == null && m.group(hG) != null) {
      mn = int.parse(m.group(hG)!.replaceAll(':', ''));
    } else {
      mn = int.parse(m.group(mG)?.replaceAll(':', '') ?? '0');
      h = int.parse(m.group(hG)?.replaceAll(':', '') ?? '0');
    }
    return Duration(
      hours: h,
      minutes: mn,
      seconds: int.parse(m.group(sG)?.replaceAll(':', '') ?? '0'),
      milliseconds: int.parse(m.group(msG) ?? '0'),
    );
  }

  String _strip(String s) {
    final re = RegExp(r'(<[^>]*>)', multiLine: true);
    var out = s;
    for (final m in re.allMatches(s)) {
      out = out.replaceAll(m.group(0)!, m.group(0) == '<br>' ? '\n' : '');
    }
    return out;
  }

  // ── AES-128-CBC (AESEngine — security fix over AESFastEngine) ────────────

  String _decryptCdn(String text, String kHex, String iHex) {
    String decoded;
    try {
      decoded =
          utf8.decode(base64Decode(text.trim().replaceAll(RegExp(r'\s+'), '')));
    } catch (_) {
      decoded = text;
    }
    final lines =
        decoded.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final key = _hb(kHex), iv = _hb(iHex);
    if (key.length != 16 || iv.length != 16)
      throw ArgumentError('key/iv must be 16 bytes');

    final tsRx =
        RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}$');
    bool isHex(String s) =>
        s.isNotEmpty &&
        s.length % 2 == 0 &&
        RegExp(r'^[0-9a-fA-F]+$').hasMatch(s);
    bool isCueId(String s) => s.length == 32 && isHex(s);

    return lines.map((line) {
      final t = line.trim();
      if (t.isEmpty || t == 'WEBVTT' || tsRx.hasMatch(t) || isCueId(t))
        return line;
      if (isHex(t)) {
        try {
          return _aes(t, key, iv);
        } catch (_) {}
      }
      return line;
    }).join('\n');
  }

  String _aes(String hex, Uint8List key, Uint8List iv) {
    final c =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
    c.init(
        false,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
            ParametersWithIV(KeyParameter(key), iv), null));
    return utf8.decode(c.process(_hb(hex)), allowMalformed: true);
  }

  Uint8List _hb(String hex) {
    final h = hex.trim();
    final o = Uint8List(h.length ~/ 2);
    for (var i = 0; i < h.length; i += 2) {
      o[i ~/ 2] = int.parse(h.substring(i, i + 2), radix: 16);
    }
    return o;
  }
}
