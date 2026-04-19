class SenzuCastMedia {
  const SenzuCastMedia({
    required this.url,
    required this.title,
    this.description = '',
    this.posterUrl,
    this.subtitleUrl,
    this.subtitleLanguage = 'en',
    this.mimeType,
    this.positionMs = 0,
    this.durationMs = 0, 
    this.isLive = false,
    this.releaseDate, 
    this.studio,            
    this.httpHeaders = const {},   
    this.subtitleHeaders = const {},  
    this.availableSubtitles = const [],
    this.availableAudioTracks = const [],
    this.availableQualities = const [],
    this.selectedSubtitleId,
    this.selectedAudioId,
  });

  final String url;
  final String title;
  final String description;
  final String? posterUrl;
  final String? subtitleUrl;
  final String subtitleLanguage;
  final String? mimeType;
  final int positionMs;
  final int durationMs; 
  final bool isLive;
  final String? releaseDate;
  final String? studio;
  final Map<String, String> httpHeaders;
  final Map<String, String> subtitleHeaders;
  final List<CastSubtitleTrack> availableSubtitles;
  final List<CastAudioTrack> availableAudioTracks;
  final List<CastQualityOption> availableQualities;
   final int? selectedSubtitleId;
  final int? selectedAudioId;

  String get resolvedMimeType {
    if (mimeType != null) return mimeType!;
    if (url.contains('.m3u8')) return 'application/x-mpegURL';
    if (url.contains('.mpd'))  return 'application/dash+xml';
    if (url.contains('.mp4'))  return 'video/mp4';
    return 'video/mp4';
  }

  Map<String, dynamic> toMap() => {
    'url':              url,
    'title':            title,
    'description':      description,
    'posterUrl':        posterUrl ?? '',
    'subtitleUrl':      subtitleUrl ?? '',
    'subtitleLanguage': subtitleLanguage,
    'mimeType':         resolvedMimeType,
    'positionMs':       positionMs,
    'durationMs':       durationMs, 
    'isLive':           isLive,
    'releaseDate':      releaseDate ?? '',
    'studio':           studio ?? '',
    'httpHeaders':      httpHeaders,
    'subtitleHeaders':  subtitleHeaders,
    'availableSubtitles':   availableSubtitles.map((s) => s.toMap()).toList(),
    'availableAudioTracks': availableAudioTracks.map((a) => a.toMap()).toList(),
    'availableQualities':   availableQualities.map((q) => q.toMap()).toList(),
    'selectedSubtitleId': selectedSubtitleId,
    'selectedAudioId': selectedAudioId,
  };
}

class CastSubtitleTrack {
  const CastSubtitleTrack({
    required this.id,
    required this.language,
    required this.name,
    required this.url,
    this.headers = const {},
  });
  final int id;
  final String language;
  final String name;
  final String url;
  final Map<String, String> headers;

  Map<String, dynamic> toMap() => {
    'id': id, 'language': language,
    'name': name, 'url': url, 'headers': headers,
  };
}

class CastAudioTrack {
  const CastAudioTrack({
    required this.id,
    required this.language,
    required this.name,
  });
  final int id;
  final String language;
  final String name;

  Map<String, dynamic> toMap() => {
    'id': id, 'language': language, 'name': name,
  };
}

class CastQualityOption {
  const CastQualityOption({
    required this.label,
    required this.url,
    this.headers = const {},
  });
  final String label;
  final String url;
  final Map<String, String> headers;

  Map<String, dynamic> toMap() => {
    'label': label, 'url': url, 'headers': headers,
  };
}