import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureChaptersPage extends StatelessWidget {
  const FeatureChaptersPage({Key? key}) : super(key: key);

  // ── fromSkipRanges helper ────────────────────────────────────────────────
  static final _skipRangeChapters = SenzuChapter.fromSkipRanges(
    opStart: const Duration(seconds: 5),
    opEnd:   const Duration(seconds: 30),
    edStart: const Duration(minutes: 1, seconds: 30),
    edEnd:   const Duration(minutes: 2),
  );

  // ── Manual chapters ──────────────────────────────────────────────────────
  static const _manualChapters = [
    SenzuChapter(startMs: 0,      title: 'Cold Open',  showOnProgressBar: true),
    SenzuChapter(startMs: 5000,   title: 'OP',         showOnProgressBar: true,  isSkippable: true, skipToMs: 30000),
    SenzuChapter(startMs: 30000,  title: '',           showOnProgressBar: false),
    SenzuChapter(startMs: 35000,  title: 'Act I',      showOnProgressBar: true),
    SenzuChapter(startMs: 70000,  title: 'Act II',     showOnProgressBar: true),
    SenzuChapter(startMs: 90000,  title: 'ED',         showOnProgressBar: true,  isSkippable: true, skipToMs: 120000),
    SenzuChapter(startMs: 120000, title: '',           showOnProgressBar: false),
    SenzuChapter(startMs: 125000, title: 'Post-credits', showOnProgressBar: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('5. Chapters & Skip OP/ED'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── fromSkipRanges ─────────────────────────────────────────────
            _label('fromSkipRanges — OP at 0:05 / ED at 1:30'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              chapters: _skipRangeChapters,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'Anime Episode 1',
                description: 'OP/ED skip demo',
              ),
            ),
            const SizedBox(height: 16),
            _chapterList(_skipRangeChapters),
            const SizedBox(height: 24),

            // ── Manual chapters ────────────────────────────────────────────
            _label('Manual chapters — Cold Open / Act I / Act II / ED / Post-credits'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              chapters: _manualChapters,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(
                title: 'Manual Chapters',
                description: '8 chapters with skip buttons',
              ),
            ),
            const SizedBox(height: 16),
            _chapterList(_manualChapters),
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

  Widget _chapterList(List<SenzuChapter> chapters) {
    final visible = chapters.where((c) => c.label != null).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: visible
            .map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          _fmtMs(c.startMs),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c.label!,
                        style: TextStyle(
                          color: c.isSkippable ? const Color(0xFF00CA13) : Colors.white70,
                          fontSize: 12,
                          fontWeight: c.isSkippable ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (c.isSkippable) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00CA13).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('skippable',
                              style: TextStyle(
                                  color: Color(0xFF00CA13), fontSize: 9)),
                        ),
                      ],
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}