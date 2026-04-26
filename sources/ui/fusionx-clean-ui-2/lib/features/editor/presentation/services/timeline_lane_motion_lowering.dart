import 'package:flutter/foundation.dart';

import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

enum TimelineLaneMotionLoweringIssueCode {
  emptyActiveRange,
  unsupportedValueKind,
  duplicateKeyframeTime,
}

@immutable
class TimelineLaneMotionLoweringIssue {
  const TimelineLaneMotionLoweringIssue({
    required this.code,
    required this.message,
  });

  final TimelineLaneMotionLoweringIssueCode code;
  final String message;
}

@immutable
class TimelineLaneMotionLoweringResult {
  const TimelineLaneMotionLoweringResult({
    this.channel,
    this.issues = const <TimelineLaneMotionLoweringIssue>[],
  });

  final MotionPropertyChannelModel? channel;
  final List<TimelineLaneMotionLoweringIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

@immutable
class TimelineLaneMotionLoweringRequest {
  const TimelineLaneMotionLoweringRequest({
    required this.lane,
    required this.target,
    required this.definition,
    required this.activeRange,
    this.valueScale = 1.0,
    this.interpolation = const MotionInterpolationSpec.linear(),
  });

  final TimelineAnimationLaneData lane;
  final MotionPropertyTarget target;
  final MotionPropertyDefinition definition;
  final TimelineTimeRange activeRange;
  final double valueScale;
  final MotionInterpolationSpec interpolation;
}

@immutable
class TimelineLaneMotionLoweringBatchResult {
  TimelineLaneMotionLoweringBatchResult({
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
    List<TimelineLaneMotionLoweringIssue> issues =
        const <TimelineLaneMotionLoweringIssue>[],
  })  : channels = List.unmodifiable(channels),
        issues = List.unmodifiable(issues);

  final List<MotionPropertyChannelModel> channels;
  final List<TimelineLaneMotionLoweringIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class TimelineLaneMotionLoweringService {
  const TimelineLaneMotionLoweringService();

  TimelineLaneMotionLoweringBatchResult lowerLanes({
    required Iterable<TimelineLaneMotionLoweringRequest> requests,
  }) {
    final channels = <MotionPropertyChannelModel>[];
    final issues = <TimelineLaneMotionLoweringIssue>[];
    for (final request in requests) {
      final result = lowerLane(
        lane: request.lane,
        target: request.target,
        definition: request.definition,
        activeRange: request.activeRange,
        valueScale: request.valueScale,
        interpolation: request.interpolation,
      );
      if (result.channel != null) {
        channels.add(result.channel!);
      }
      issues.addAll(result.issues);
    }
    return TimelineLaneMotionLoweringBatchResult(
      channels: channels,
      issues: issues,
    );
  }

  TimelineLaneMotionLoweringResult lowerLane({
    required TimelineAnimationLaneData lane,
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
    required TimelineTimeRange activeRange,
    double valueScale = 1.0,
    MotionInterpolationSpec interpolation =
        const MotionInterpolationSpec.linear(),
  }) {
    if (activeRange.endExclusive <= activeRange.start) {
      return const TimelineLaneMotionLoweringResult(
        issues: <TimelineLaneMotionLoweringIssue>[
          TimelineLaneMotionLoweringIssue(
            code: TimelineLaneMotionLoweringIssueCode.emptyActiveRange,
            message: 'Cannot lower a lane into an empty active range.',
          ),
        ],
      );
    }

    if (!_isTimelineScalar(definition.valueKind)) {
      return TimelineLaneMotionLoweringResult(
        issues: <TimelineLaneMotionLoweringIssue>[
          TimelineLaneMotionLoweringIssue(
            code: TimelineLaneMotionLoweringIssueCode.unsupportedValueKind,
            message:
                'Property ${definition.id} cannot be lowered from a scalar timeline lane.',
          ),
        ],
      );
    }

    final stops = lane.normalizedKeyframeStops
        .map((stop) => stop.clamp(0.0, 1.0).toDouble())
        .toList(growable: false);
    final values = lane.alignedKeyframeValues(clampToPercent: false);
    final keyframes = <MotionKeyframeModel>[];
    final seenTimes = <int>{};
    for (var index = 0; index < stops.length; index += 1) {
      final time = _timeAtProgress(activeRange, stops[index]);
      final ticks = time.inProjectTicks;
      if (!seenTimes.add(ticks)) {
        return TimelineLaneMotionLoweringResult(
          issues: <TimelineLaneMotionLoweringIssue>[
            TimelineLaneMotionLoweringIssue(
              code: TimelineLaneMotionLoweringIssueCode.duplicateKeyframeTime,
              message:
                  'Lane ${lane.id} has multiple keyframes at the same timeline tick.',
            ),
          ],
        );
      }
      keyframes.add(
        MotionKeyframeModel(
          id: _keyframeIdAt(lane, index),
          channelId: lane.id,
          time: time,
          value: _motionValueFor(
            definition.valueKind,
            values[index],
            valueScale,
          ),
          interpolationToNext: interpolation,
        ),
      );
    }

    keyframes.sort((left, right) => left.time.compareTo(right.time));

    return TimelineLaneMotionLoweringResult(
      channel: MotionPropertyChannelModel(
        id: lane.id,
        target: target,
        definition: definition,
        activeRange: activeRange,
        keyframes: List<MotionKeyframeModel>.unmodifiable(keyframes),
      ),
    );
  }

  bool _isTimelineScalar(MotionPropertyValueKind kind) {
    return kind == MotionPropertyValueKind.scalar ||
        kind == MotionPropertyValueKind.integer;
  }

  TimelineTime _timeAtProgress(TimelineTimeRange range, double progress) {
    final startTicks = range.start.inProjectTicks;
    final durationTicks = range.duration.inProjectTicks;
    return TimelineTime.fromProjectTicks(
      startTicks + (durationTicks * progress).round(),
    );
  }

  String _keyframeIdAt(TimelineAnimationLaneData lane, int index) {
    if (index < lane.keyframeIds.length && lane.keyframeIds[index].isNotEmpty) {
      return lane.keyframeIds[index];
    }
    return '${lane.id}.keyframe.$index';
  }

  MotionPropertyValue _motionValueFor(
    MotionPropertyValueKind kind,
    double value,
    double valueScale,
  ) {
    final safeScale = valueScale == 0 ? 1.0 : valueScale;
    final raw = value / safeScale;
    return switch (kind) {
      MotionPropertyValueKind.scalar => MotionPropertyValue.scalar(raw),
      MotionPropertyValueKind.integer =>
        MotionPropertyValue.integer(raw.round()),
      _ => throw StateError('Unsupported scalar timeline kind: $kind'),
    };
  }
}
