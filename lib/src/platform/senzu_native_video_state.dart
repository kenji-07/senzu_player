// lib/src/platform/senzu_native_video_state.dart

/// Mirrors the EventChannel "playback" event schema from native.
///
/// Field names are intentionally identical to those read by
/// [SenzuPlaybackController._onFrame] so that controller needs zero changes.
class SenzuNativeVideoState {
  const SenzuNativeVideoState({
    this.position       = Duration.zero,
    this.duration       = Duration.zero,
    this.isPlaying      = false,
    this.isBuffering    = false,
    this.buffered       = const [],
    this.errorDescription,
    this.isInitialized  = false,
  });

  /// Current playback position.
  final Duration position;

  /// Total duration of the media. Zero if unknown (e.g. live stream).
  final Duration duration;

  /// Whether the player is actively playing.
  final bool isPlaying;

  /// Whether the player is waiting for more data.
  final bool isBuffering;

  /// Loaded / buffered time ranges as [DurationRange] pairs.
  final List<DurationRange> buffered;

  /// Non-null when the player encountered a fatal error.
  final String? errorDescription;

  /// True after [SenzuNativeVideoController.initialize] resolves.
  final bool isInitialized;

  // ── Convenience getters used by SenzuPlaybackController ────────────────

  /// Returns true if the position has reached (or exceeded) the duration.
  bool get isCompleted =>
      isInitialized &&
      duration > Duration.zero &&
      position >= duration;

  /// Returns a value in [0, 1] representing playback progress.
  double get progress {
    if (!isInitialized || duration == Duration.zero) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  // ── Factory from EventChannel map ──────────────────────────────────────

  factory SenzuNativeVideoState.fromMap(Map<dynamic, dynamic> map) {
    final posMs = _toLong(map['position']) ?? 0;
    final durMs = _toLong(map['duration']) ?? 0;

    final rawBuffered = map['buffered'];
    final bufferedRanges = <DurationRange>[];
    if (rawBuffered is List) {
      for (final item in rawBuffered) {
        if (item is Map) {
          final start = _toLong(item['start']) ?? 0;
          final end   = _toLong(item['end'])   ?? 0;
          bufferedRanges.add(DurationRange(
            Duration(milliseconds: start),
            Duration(milliseconds: end),
          ));
        }
      }
    }

    return SenzuNativeVideoState(
      position       : Duration(milliseconds: posMs),
      duration       : Duration(milliseconds: durMs),
      isPlaying      : (map['isPlaying']   as bool?) ?? false,
      isBuffering    : (map['isBuffering'] as bool?) ?? false,
      buffered       : bufferedRanges,
      errorDescription: map['error'] as String?,
      isInitialized  : true,
    );
  }

  // ── copyWith ────────────────────────────────────────────────────────────

  SenzuNativeVideoState copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isBuffering,
    List<DurationRange>? buffered,
    String? errorDescription,
    bool? isInitialized,
  }) {
    return SenzuNativeVideoState(
      position        : position        ?? this.position,
      duration        : duration        ?? this.duration,
      isPlaying       : isPlaying       ?? this.isPlaying,
      isBuffering     : isBuffering     ?? this.isBuffering,
      buffered        : buffered        ?? this.buffered,
      errorDescription: errorDescription ?? this.errorDescription,
      isInitialized   : isInitialized   ?? this.isInitialized,
    );
  }

  @override
  String toString() =>
      'SenzuNativeVideoState(pos=${position.inMilliseconds}ms, '
      'dur=${duration.inMilliseconds}ms, playing=$isPlaying, '
      'buffering=$isBuffering, error=$errorDescription)';

  // ── Private helpers ─────────────────────────────────────────────────────

  static int? _toLong(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return null;
  }
}

/// A range of time within a media item.
class DurationRange {
  const DurationRange(this.start, this.end);

  final Duration start;
  final Duration end;

  /// Returns a value in [0, 1] indicating what fraction of [total] this
  /// range covers at its start point.
  double startFraction(Duration total) {
    if (total == Duration.zero) return 0.0;
    return (start.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Returns a value in [0, 1] indicating what fraction of [total] this
  /// range covers at its end point.
  double endFraction(Duration total) {
    if (total == Duration.zero) return 0.0;
    return (end.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  String toString() => 'DurationRange(${start.inMilliseconds}ms → ${end.inMilliseconds}ms)';
}