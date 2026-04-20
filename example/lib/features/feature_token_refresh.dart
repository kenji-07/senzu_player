import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureTokenRefreshPage extends StatefulWidget {
  const FeatureTokenRefreshPage({Key? key}) : super(key: key);
  @override
  State<FeatureTokenRefreshPage> createState() => _FeatureTokenRefreshPageState();
}

class _FeatureTokenRefreshPageState extends State<FeatureTokenRefreshPage> {
  final _logs = <String>[];
  int _refreshCount = 0;

  void _addLog(String msg) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';
    setState(() => _logs.insert(0, '[$ts] $msg'));
    if (_logs.length > 20) _logs.removeLast();
  }

  // Simulate signed URL refresh
  Future<Map<String, String>> _onRefresh(
      String sourceName, Map<String, String> currentHeaders) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _refreshCount++;
    final fakeExpiry =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 30;
    final newUrl =
        'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8?exp=$fakeExpiry&sig=fake_sig_$_refreshCount';
    _addLog('Refreshed! count=$_refreshCount exp=$fakeExpiry');
    return {
      'url': newUrl,
      'Authorization': 'Bearer refreshed_token_$_refreshCount',
    };
  }

  @override
  Widget build(BuildContext context) {
    // Build a URL with a fake 30-second expiry
    final expiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 30;
    final signedUrl =
        'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8?exp=$expiry&sig=initial_sig';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('10. Token Refresh'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBox(
              'URL contains ?exp= query param.\n'
              'SenzuTokenManager refreshes 60s before expiry.\n'
              'In this demo expiry is set to 30s → refreshes immediately.',
            ),
            const SizedBox(height: 16),

            _label('Auto token refresh'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  signedUrl,
                  httpHeaders: {
                    'Authorization': 'Bearer initial_token',
                  },
                ),
              },
              tokenConfig: SenzuTokenConfig(
                refreshBeforeExpirySec: 60,
                onRefresh: _onRefresh,
              ),
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'Token Refresh Demo',
                description: 'Signed URL auto-refreshes',
              ),
            ),
            const SizedBox(height: 20),

            _label('Refresh Log'),
            if (_logs.isEmpty)
              const Text('No refreshes yet.',
                  style: TextStyle(color: Colors.white38, fontSize: 12))
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _logs
                      .map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(l,
                                style: const TextStyle(
                                    color: Color(0xFF00CA13),
                                    fontSize: 11,
                                    fontFamily: 'monospace')),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _infoBox(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.6)),
      );
}