import 'package:flutter/widgets.dart';

class SenzuPlayerAd {
  SenzuPlayerAd({
    required this.child,
    required this.durationToSkip,
    required this.deepLink,
    this.durationToStart,
    this.fractionToStart,
    this.durationToEnd = const Duration(seconds: 8),
  }) : assert(
          (fractionToStart != null) ^ (durationToStart != null),
          'Exactly one of fractionToStart or durationToStart must be set.',
        );

  final Widget    child;
  final Duration  durationToSkip;
  final String    deepLink;
  final Duration? durationToStart;
  final double?   fractionToStart;
  final Duration  durationToEnd;

  @override
  bool operator ==(Object o) =>
      identical(this, o) || o is SenzuPlayerAd &&
      o.durationToSkip == durationToSkip && o.deepLink == deepLink &&
      o.durationToStart == durationToStart && o.fractionToStart == fractionToStart;

  @override
  int get hashCode =>
      Object.hash(durationToSkip, deepLink, durationToStart, fractionToStart);
}