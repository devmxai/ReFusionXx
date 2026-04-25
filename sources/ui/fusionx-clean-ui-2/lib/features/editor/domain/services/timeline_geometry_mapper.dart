import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';

@immutable
class TimelineGeometryMapper {
  const TimelineGeometryMapper({
    required this.timelineDuration,
    required this.secondsWidth,
    required this.timelineOriginX,
    required this.playheadLeft,
    required this.maxScrollOffset,
  });

  final TimelineTime timelineDuration;
  final double secondsWidth;
  final double timelineOriginX;
  final double playheadLeft;
  final double maxScrollOffset;

  TimelineTime timeForOffset(double offset) {
    final safeSecondsWidth = _safeSecondsWidth(secondsWidth);
    final durationSeconds = timelineDuration.inSecondsDouble;
    final seconds =
        ((offset + playheadLeft - timelineOriginX) / safeSecondsWidth)
            .clamp(0.0, durationSeconds)
            .toDouble();
    return TimelineTime.fromSecondsDouble(seconds);
  }

  double offsetForTime(TimelineTime time) {
    final safeSecondsWidth = _safeSecondsWidth(secondsWidth);
    final clampedTime = time.clamp(TimelineTime.zero, timelineDuration);
    final offset = timelineOriginX +
        (clampedTime.inSecondsDouble * safeSecondsWidth) -
        playheadLeft;
    return offset.clamp(0.0, _safeMaxOffset(maxScrollOffset)).toDouble();
  }

  double offsetDeltaBetween({
    required TimelineTime from,
    required TimelineTime to,
  }) {
    final safeSecondsWidth = _safeSecondsWidth(secondsWidth);
    return (to - from).inSecondsDouble * safeSecondsWidth;
  }

  double pixelsForDuration(TimelineTime duration) {
    final safeSecondsWidth = _safeSecondsWidth(secondsWidth);
    return duration.inSecondsDouble * safeSecondsWidth;
  }

  TimelineTime durationForPixels(double pixels) {
    final safeSecondsWidth = _safeSecondsWidth(secondsWidth);
    final safePixels = pixels.isFinite ? pixels : 0.0;
    return TimelineTime.fromSecondsDouble(safePixels / safeSecondsWidth);
  }

  double offsetForTimeFromAnchor({
    required TimelineTime time,
    required TimelineTime anchorTime,
    required double anchorOffset,
    double? minScrollOffset,
    double? maxScrollOffsetOverride,
  }) {
    final minOffset = minScrollOffset == null || !minScrollOffset.isFinite
        ? 0.0
        : minScrollOffset;
    final maxOffset =
        _safeMaxOffset(maxScrollOffsetOverride ?? maxScrollOffset);
    final offset = anchorOffset +
        offsetDeltaBetween(
          from: anchorTime,
          to: time.clamp(TimelineTime.zero, timelineDuration),
        );
    return offset.clamp(minOffset, maxOffset).toDouble();
  }

  static double _safeSecondsWidth(double value) {
    if (!value.isFinite || value.abs() < 0.0001) {
      return 0.0001;
    }
    return value;
  }

  static double _safeMaxOffset(double value) {
    if (!value.isFinite || value <= 0) {
      return 0.0;
    }
    return value;
  }
}
