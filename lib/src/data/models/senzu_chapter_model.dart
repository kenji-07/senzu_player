
class SenzuChapter {
  const SenzuChapter({
    required this.startMs,
    required this.title,
    this.showOnProgressBar = true,
    this.isSkippable = false,
    this.skipToMs,
  });

  /// Chapter эхлэх цаг (milliseconds).
  /// int ашигласан нь Duration-с илүү хурдан hash/compare хийдэг.
  final int startMs;

  /// Progress bar tooltip болон panel дотор харуулах нэр.
  /// Хоосон string ("") байж болно — заагч зурах ч label харуулахгүй.
  final String title;

  /// Progress bar дээр заагч (marker) зурах эсэх.
  /// OP/ED-ийн эхлэл/төгсгөлийн хоёрдогч chapter-т false тохируулна.
  final bool showOnProgressBar;

  /// true бол overlay дээр "Skip" товч харуулна.
  final bool isSkippable;

  /// Skip товч дарагдахад seek хийх цаг (ms).
  /// null бол дараагийн chapter-ийн startMs ашиглана.
  final int? skipToMs;

  // ── Convenience ────────────────────────────────────────────────────────────

  /// UI дээр харуулах label — title хоосон бол null буцаана
  String? get label => title.isEmpty ? null : title;

  Duration get startDuration => Duration(milliseconds: startMs);

  static List<SenzuChapter> fromSkipRanges({
    required Duration opStart,
    required Duration opEnd,
    required Duration edStart,
    required Duration edEnd,
  }) {
    final chapters = <SenzuChapter>[];

    if (opEnd > Duration.zero && opEnd > opStart) {
      // OP эхлэл — skip товч харуулна
      chapters.add(SenzuChapter(
        startMs: opStart.inMilliseconds,
        title: 'OP',
        showOnProgressBar: true,
        isSkippable: true,
        skipToMs: opEnd.inMilliseconds,
      ));
      // OP төгсгөл — separator зурна, skip хийхгүй
      chapters.add(SenzuChapter(
        startMs: opEnd.inMilliseconds,
        title: '',
        showOnProgressBar: false,
        isSkippable: false,
      ));
    }

    if (edEnd > Duration.zero && edEnd > edStart) {
      // ED эхлэл — skip товч харуулна
      chapters.add(SenzuChapter(
        startMs: edStart.inMilliseconds,
        title: 'ED',
        showOnProgressBar: true,
        isSkippable: true,
        skipToMs: edEnd.inMilliseconds,
      ));
      // ED төгсгөл — separator
      chapters.add(SenzuChapter(
        startMs: edEnd.inMilliseconds,
        title: '',
        showOnProgressBar: false,
        isSkippable: false,
      ));
    }

    // Binary search-д зориулж startMs-р эрэмбэлнэ
    chapters.sort((a, b) => a.startMs.compareTo(b.startMs));
    return chapters;
  }

  // ── Equality ───────────────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SenzuChapter &&
          other.startMs == startMs &&
          other.title == title;

  @override
  int get hashCode => Object.hash(startMs, title);

  @override
  String toString() => 'SenzuChapter(startMs=$startMs, title="$title")';
}