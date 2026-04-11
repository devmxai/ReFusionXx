import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
class TimelineTime implements Comparable<TimelineTime> {
  const TimelineTime({
    required this.value,
    this.timescale = projectTimescale,
  }) : assert(timescale > 0, 'timescale must be positive');

  static const int projectTimescale = 1000000;
  static const TimelineTime zero = TimelineTime(value: 0);

  final int value;
  final int timescale;

  factory TimelineTime.fromProjectTicks(int ticks) {
    return TimelineTime(value: ticks, timescale: projectTimescale);
  }

  factory TimelineTime.fromMilliseconds(int milliseconds) {
    return TimelineTime(
      value: milliseconds * 1000,
      timescale: projectTimescale,
    );
  }

  factory TimelineTime.fromSecondsDouble(double seconds) {
    final safeSeconds = seconds.isFinite ? seconds : 0.0;
    return TimelineTime(
      value: (safeSeconds * projectTimescale).round(),
      timescale: projectTimescale,
    );
  }

  int get inProjectTicks => rescaledTo(projectTimescale).value;

  int get inMilliseconds => rescaledTo(1000).value;

  double get inSecondsDouble => value / timescale;

  bool get isZero => value == 0;

  TimelineTime rescaledTo(int targetTimescale) {
    assert(targetTimescale > 0, 'targetTimescale must be positive');
    if (timescale == targetTimescale) {
      return this;
    }
    final numerator = BigInt.from(value) * BigInt.from(targetTimescale);
    final denominator = BigInt.from(timescale);
    var quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator).abs();
    if (remainder * BigInt.from(2) >= denominator.abs()) {
      quotient += BigInt.from(value >= 0 ? 1 : -1);
    }
    return TimelineTime(
      value: quotient.toInt(),
      timescale: targetTimescale,
    );
  }

  TimelineTime clamp(TimelineTime lower, TimelineTime upper) {
    assert(lower <= upper, 'lower must be <= upper');
    if (this < lower) {
      return lower;
    }
    if (this > upper) {
      return upper;
    }
    return this;
  }

  TimelineTime operator +(TimelineTime other) {
    final right = other.rescaledTo(timescale);
    return TimelineTime(value: value + right.value, timescale: timescale);
  }

  TimelineTime operator -(TimelineTime other) {
    final right = other.rescaledTo(timescale);
    return TimelineTime(value: value - right.value, timescale: timescale);
  }

  @override
  int compareTo(TimelineTime other) {
    final left = BigInt.from(value) * BigInt.from(other.timescale);
    final right = BigInt.from(other.value) * BigInt.from(timescale);
    return left.compareTo(right);
  }

  bool operator <(TimelineTime other) => compareTo(other) < 0;

  bool operator <=(TimelineTime other) => compareTo(other) <= 0;

  bool operator >(TimelineTime other) => compareTo(other) > 0;

  bool operator >=(TimelineTime other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TimelineTime && compareTo(other) == 0;
  }

  @override
  int get hashCode => Object.hash(rescaledTo(projectTimescale).value, projectTimescale);

  @override
  String toString() => 'TimelineTime(value: $value, timescale: $timescale)';
}

@immutable
class TimelineTimeRange {
  const TimelineTimeRange({
    required this.start,
    required this.endExclusive,
  }) : assert(
         start <= endExclusive,
         'start must be <= endExclusive',
       );

  final TimelineTime start;
  final TimelineTime endExclusive;

  TimelineTime get duration => endExclusive - start;

  bool contains(TimelineTime time) => time >= start && time < endExclusive;

  TimelineTimeRange shiftBy(TimelineTime delta) {
    return TimelineTimeRange(
      start: start + delta,
      endExclusive: endExclusive + delta,
    );
  }

  TimelineTimeRange clampToNonNegative() {
    final zero = TimelineTime.zero.rescaledTo(start.timescale);
    final safeStart = start < zero ? zero : start;
    final safeEnd = endExclusive < safeStart ? safeStart : endExclusive;
    return TimelineTimeRange(start: safeStart, endExclusive: safeEnd);
  }

  @override
  String toString() => 'TimelineTimeRange(start: $start, endExclusive: $endExclusive)';
}

double timelineTicksToSeconds(int ticks) {
  return ticks / TimelineTime.projectTimescale;
}

int secondsToTimelineTicks(double seconds) {
  final safeSeconds = seconds.isFinite ? seconds : 0.0;
  return (safeSeconds * TimelineTime.projectTimescale).round();
}

double clampSecondsToTimelineRange(
  double seconds, {
  required double lower,
  required double upper,
}) {
  if (!seconds.isFinite) {
    return lower;
  }
  return math.min(math.max(seconds, lower), upper);
}
