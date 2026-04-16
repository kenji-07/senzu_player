import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:senzu_player/src/data/models/senzu_token_provider.dart';

class SenzuTokenManager {
  SenzuTokenManager({required this.config});
  final SenzuTokenConfig config;

  Timer? _refreshTimer;

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
      _doRefresh(sourceName, currentHeaders, onRefreshed);
      return;
    }

    _refreshTimer = Timer(Duration(seconds: delay), () {
      _doRefresh(sourceName, currentHeaders, onRefreshed);
    });
  }

  Future<void> _doRefresh(
    String sourceName,
    Map<String, String> headers,
    void Function(String, Map<String, String>) onRefreshed,
  ) async {
    try {
      final result = await config.onRefresh(sourceName, headers);
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

  void cancel() => _refreshTimer?.cancel();
}
