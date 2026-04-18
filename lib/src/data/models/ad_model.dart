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

  final Widget child;
  final Duration durationToSkip;
  final String deepLink;
  final Duration? durationToStart;
  final double? fractionToStart;
  final Duration durationToEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SenzuPlayerAd &&
          other.durationToSkip == durationToSkip &&
          other.deepLink == deepLink &&
          other.durationToStart == durationToStart &&
          other.fractionToStart == fractionToStart;

  @override
  int get hashCode =>
      Object.hash(durationToSkip, deepLink, durationToStart, fractionToStart);
}
