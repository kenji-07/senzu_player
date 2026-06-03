import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:senzu_player/src/data/models/senzu_token_provider.dart';

class SenzuTokenManager {
  SenzuTokenManager({required this.config});
  final SenzuTokenConfig config;

  Timer? _refreshTimer;
  bool _disposed = false;

  /// URL-д expiry query param байвал автоматаар timer тохируулна
  void scheduleRefresh({
    required String sourceName,
    required String currentUrl,
    required Map<String, String> currentHeaders,
    required void Function(String newUrl, Map<String, String> newHeaders)
        onRefreshed,
  }) {
    _refreshTimer?.cancel();

    final expiry = _extractExpiry(currentUrl);
    if (expiry == null) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final delay = expiry - now - config.refreshBeforeExpirySec;
    if (delay <= 0) {
      if (!_disposed) _doRefresh(sourceName, currentHeaders, onRefreshed);
      return;
    }

    _refreshTimer = Timer(Duration(seconds: delay), () {
      if (!_disposed) _doRefresh(sourceName, currentHeaders, onRefreshed);
    });
  }

  Future<void> _doRefresh(
    String sourceName,
    Map<String, String> headers,
    void Function(String, Map<String, String>) onRefreshed,
  ) async {
    try {
      final result = await config.onRefresh(sourceName, headers);
      // Async хүлээсэн хугацаанд dispose() дуудагдсан байж болно —
      // тийм тохиолдолд callback дуудахгүй.
      if (_disposed) return;
      final newUrl = result['url'] ?? '';
      final newHeaders = Map<String, String>.from(result)..remove('url');
      if (newUrl.isNotEmpty) onRefreshed(newUrl, newHeaders);
    } catch (e) {
      debugPrint('SenzuTokenManager: refresh failed — $e');
    }
  }

  /// URL-с `exp` эсвэл `Expires` query param уншина
  int? _extractExpiry(String url) {
    try {
      final uri = Uri.parse(url);
      final exp = uri.queryParameters['exp'] ??
          uri.queryParameters['Expires'] ??
          uri.queryParameters['expires'];
      return exp != null ? int.tryParse(exp) : null;
    } catch (_) {
      return null;
    }
  }

  /// Timer-г зогсоож, disposed тэмдэглэнэ.
  /// Энэ дараа async refresh дуусаад callback дуудахгүй болно.
  void cancel() {
    _disposed = true;
    _refreshTimer?.cancel();
  }
}
