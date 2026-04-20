import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureQualityPage extends StatefulWidget {
  const FeatureQualityPage({Key? key}) : super(key: key);

  @override
  State<FeatureQualityPage> createState() => _FeatureQualityPageState();
}

class _FeatureQualityPageState extends State<FeatureQualityPage> {
  Map<String, VideoSource>? _parsedSources;
  bool _loading = true;
  String? _error;
  String _lastQuality = '';

  @override
  void initState() {
    super.initState();
    _parseSources();
  }

  Future<void> _parseSources() async {
    try {
      final sources = await VideoSource.fromM3u8PlaylistUrl(
        'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        autoSubtitle: true,
      );
      if (mounted) {
        setState(() {
          _parsedSources = sources;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('2. Multi-Quality'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Auto-parsed from M3U8 ──────────────────────────────────────
            _label('Auto-parsed from M3U8 playlist'),
            if (_loading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF00CA13))),
              )
            else if (_error != null)
              Container(
                height: 200,
                color: Colors.red.withValues(alpha: 0.1),
                child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
              )
            else
              SenzuPlayer(
                source: _parsedSources!,
                defaultAspectRatio: 16 / 9,
                enableQuality: true,
                adaptiveBitrate: true,
                onQualityChanged: (q) => setState(() => _lastQuality = q),
                meta: const SenzuMetaData(
                  title: 'Multi-Quality Stream',
                  description: 'Parsed from M3U8 master playlist',
                ),
              ),

            if (_lastQuality.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Quality changed → $_lastQuality',
                  style: const TextStyle(color: Color(0xFF00CA13), fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),

            // ── Manual quality map ─────────────────────────────────────────
            _label('Manual quality map'),
            SenzuPlayer(
              source: {
                '1080p': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                ),
                '720p': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                ),
                '480p': VideoSource.fromUrl(
                  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                ),
              },
              defaultAspectRatio: 16 / 9,
              enableQuality: true,
              adaptiveBitrate: false,
              meta: const SenzuMetaData(title: 'Manual Quality'),
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
}