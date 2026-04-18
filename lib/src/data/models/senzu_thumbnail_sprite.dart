import 'package:flutter/material.dart';

class SenzuThumbnailSprite {
  const SenzuThumbnailSprite({
    required this.url,
    required this.columns,
    required this.rows,
    required this.intervalSec,
    // Дотооддоо ашиглагдана — байхгүй бол null
    double? thumbWidth,
    double? thumbHeight,
  })  : _thumbWidth = thumbWidth,
        _thumbHeight = thumbHeight;

  final String url;
  final int columns, rows;
  final int intervalSec;

  final double? _thumbWidth;
  final double? _thumbHeight;

  /// Sprite sheet-ийн нийт хэмжээ мэдэгдэж байвал нэг thumbnail-ийн хэмжээг
  /// буцаана. Мэдэгдэхгүй бол null.
  ///
  double? get thumbWidth  => _thumbWidth;
  double? get thumbHeight => _thumbHeight;

  /// Тухайн position-д харгалзах sprite sheet дэх index
  int indexAt(Duration position) {
    return position.inSeconds ~/ intervalSec;
  }

  /// Column + row index
  ({int col, int row}) gridAt(Duration position) {
    final idx = indexAt(position);
    return (col: idx % columns, row: idx ~/ columns);
  }

  /// Sprite sheet дотор тухайн thumbnail-ийн байршил.
  /// [sheetWidth], [sheetHeight] — бодит зургийн хэмжээ (pixels).
  Rect rectAt(Duration position, {double? sheetWidth, double? sheetHeight}) {
    final tw = sheetWidth  != null ? sheetWidth  / columns : (_thumbWidth  ?? 160);
    final th = sheetHeight != null ? sheetHeight / rows    : (_thumbHeight ?? 90);
    final g  = gridAt(position);
    return Rect.fromLTWH(g.col * tw, g.row * th, tw, th);
  }

  /// FractionalOffset — CachedNetworkImage alignment-д ашиглана
  FractionalOffset fractionalOffsetAt(Duration position) {
    final g   = gridAt(position);
    final fx  = columns > 1 ? g.col / (columns - 1) : 0.0;
    final fy  = rows    > 1 ? g.row / (rows    - 1) : 0.0;
    return FractionalOffset(fx.clamp(0.0, 1.0), fy.clamp(0.0, 1.0));
  }
}