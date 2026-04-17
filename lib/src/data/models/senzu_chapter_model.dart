class SenzuChapter {
  const SenzuChapter({
    required this.startMs,
    required this.title,
  });

  final int startMs; // milliseconds — int ашиглавал Duration-с хурдан
  final String title;

  // OP/ED range-аас SenzuChapter үүсгэх factory
  static List<SenzuChapter> fromSkipRanges({
    required Duration opStart,
    required Duration opEnd,
    required Duration edStart,
    required Duration edEnd,
  }) {
    final chapters = <SenzuChapter>[];
    if (opEnd > Duration.zero) {
      chapters.add(SenzuChapter(startMs: opStart.inMilliseconds, title: 'OP'));
      chapters.add(SenzuChapter(startMs: opEnd.inMilliseconds, title: ''));
    }
    if (edEnd > Duration.zero) {
      chapters.add(SenzuChapter(startMs: edStart.inMilliseconds, title: 'ED'));
      chapters.add(SenzuChapter(startMs: edEnd.inMilliseconds, title: ''));
    }
    // startMs-р эрэмбэлнэ — binary search correctness-д шаардлагатай
    chapters.sort((a, b) => a.startMs.compareTo(b.startMs));
    return chapters;
  }
}