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
        'type': type,
        'licenseUrl': licenseUrl,
        'certificateUrl': certificateUrl,
        'headers': headers,
      };
}
