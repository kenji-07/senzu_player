typedef TokenRefreshCallback = Future<Map<String, String>> Function(
  String sourceName,
  Map<String, String> currentHeaders,
);

class SenzuTokenConfig {
  const SenzuTokenConfig({
    required this.onRefresh,
    this.refreshBeforeExpirySec = 60,
    this.tokenExpiryHeader = 'x-token-expiry',
  });

  /// Шинэ signed URL болон header буцаах callback
  /// Return: {'url': '...', 'Authorization': 'Bearer ...'}
  final TokenRefreshCallback onRefresh;

  /// Token дуусахаас хэдэн секундийн өмнө refresh хийх
  final int refreshBeforeExpirySec;

  /// Response header-с expiry цаг уншдаг key
  final String tokenExpiryHeader;
}
