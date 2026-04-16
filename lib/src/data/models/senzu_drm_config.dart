/// FairPlay (iOS) / Widevine (Android) DRM тохиргоо.
///
/// Хэрэглээ:
/// ```dart
/// VideoSource.fromUrl(
///   'https://...m3u8',
///   drm: SenzuDrmConfig.fairPlay(
///     licenseUrl: 'https://license.example.com/fps',
///     certificateUrl: 'https://license.example.com/cert',
///     headers: {'Authorization': 'Bearer ...'},
///   ),
/// )
/// ```
class SenzuDrmConfig {
  const SenzuDrmConfig.fairPlay({
    required this.licenseUrl,
    required this.certificateUrl,
    this.headers = const {},
  }) : type = 'fairplay';

  const SenzuDrmConfig.widevine({
    required this.licenseUrl,
    this.certificateUrl = '',
    this.headers = const {},
  }) : type = 'widevine';

  final String type;
  final String licenseUrl;
  final String certificateUrl;
  final Map<String, String> headers;

  Map<String, dynamic> toMap() => {
        'type':           type,
        'licenseUrl':     licenseUrl,
        'certificateUrl': certificateUrl,
        'headers':        headers,
      };
}