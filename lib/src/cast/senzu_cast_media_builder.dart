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
    this.isLive = false,
  });

  final String url;
  final String title;
  final String description;
  final String? posterUrl;
  final String? subtitleUrl;
  final String subtitleLanguage;
  final String? mimeType;
  final int positionMs;
  final bool isLive;

  /// URL-аас MIME type автоматаар тодорхойлно
  String get resolvedMimeType {
    if (mimeType != null) return mimeType!;
    if (url.contains('.m3u8')) return 'application/x-mpegURL';
    if (url.contains('.mpd'))  return 'application/dash+xml';
    if (url.contains('.mp4'))  return 'video/mp4';
    return 'video/mp4';
  }

  Map<String, dynamic> toMap() => {
    'url':             url,
    'title':           title,
    'description':     description,
    'posterUrl':       posterUrl ?? '',
    'subtitleUrl':     subtitleUrl ?? '',
    'subtitleLanguage': subtitleLanguage,
    'mimeType':        resolvedMimeType,
    'positionMs':      positionMs,
    'isLive':          isLive,
  };
}