import 'package:flutter/foundation.dart';

import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

enum UnifiedKeyframeProjectionIssueCode {
  emptyWindow,
  unsupportedValueKind,
}

@immutable
class UnifiedKeyframeProjectionIssue {
  const UnifiedKeyframeProjectionIssue({
    required this.code,
    required this.message,
  });

  final UnifiedKeyframeProjectionIssueCode code;
  final String message;
}

@immutable
class UnifiedKeyframeTimelineProjectionResult {
  const UnifiedKeyframeTimelineProjectionResult({
    this.lane,
    this.issues = const <UnifiedKeyframeProjectionIssue>[],
  });

  final TimelineAnimationLaneData? lane;
  final List<UnifiedKeyframeProjectionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

@immutable
class UnifiedKeyframeTimelineProjectionBatchResult {
  UnifiedKeyframeTimelineProjectionBatchResult({
    List<TimelineAnimationLaneData> lanes = const <TimelineAnimationLaneData>[],
    List<UnifiedKeyframeProjectionIssue> issues =
        const <UnifiedKeyframeProjectionIssue>[],
  })  : lanes = List.unmodifiable(lanes),
        issues = List.unmodifiable(issues);

  final List<TimelineAnimationLaneData> lanes;
  final List<UnifiedKeyframeProjectionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class UnifiedKeyframeTimelineProjectionService {
  const UnifiedKeyframeTimelineProjectionService();

  UnifiedKeyframeTimelineProjectionBatchResult projectChannels({
    required Iterable<MotionPropertyChannelModel> channels,
    required TimelineTimeRange window,
    required String targetClipId,
    Map<String, String> labelsByChannelId = const <String, String>{},
    Map<String, double> valueScalesByChannelId = const <String, double>{},
  }) {
    final lanes = <TimelineAnimationLaneData>[];
    final issues = <UnifiedKeyframeProjectionIssue>[];
    for (final channel in channels) {
      final result = projectChannel(
        channel: channel,
        window: window,
        targetClipId: targetClipId,
        label: labelsByChannelId[channel.id],
        valueScale: valueScalesByChannelId[channel.id] ?? 1.0,
      );
      if (result.lane != null) {
        lanes.add(result.lane!);
      }
      issues.addAll(result.issues);
    }
    return UnifiedKeyframeTimelineProjectionBatchResult(
      lanes: lanes,
      issues: issues,
    );
  }

  UnifiedKeyframeTimelineProjectionResult projectChannel({
    required MotionPropertyChannelModel channel,
    required TimelineTimeRange window,
    required String targetClipId,
    String? label,
    double valueScale = 1.0,
  }) {
    if (window.endExclusive <= window.start) {
      return const UnifiedKeyframeTimelineProjectionResult(
        issues: <UnifiedKeyframeProjectionIssue>[
          UnifiedKeyframeProjectionIssue(
            code: UnifiedKeyframeProjectionIssueCode.emptyWindow,
            message:
                'Timeline projection window must have a positive duration.',
          ),
        ],
      );
    }

    if (!_isTimelineScalar(channel.definition.valueKind)) {
      return UnifiedKeyframeTimelineProjectionResult(
        issues: <UnifiedKeyframeProjectionIssue>[
          UnifiedKeyframeProjectionIssue(
            code: UnifiedKeyframeProjectionIssueCode.unsupportedValueKind,
            message:
                'Property ${channel.definition.id} cannot be projected into a scalar timeline lane.',
          ),
        ],
      );
    }

    final normalizedStops = <double>[];
    final keyframeIds = <String>[];
    final keyframeValues = <double>[];
    for (final keyframe in channel.keyframes) {
      if (!_containsInclusiveEnd(window, keyframe.time)) {
        continue;
      }
      final rawValue = keyframe.value.rawValue;
      if (rawValue is! num) {
        return UnifiedKeyframeTimelineProjectionResult(
          issues: <UnifiedKeyframeProjectionIssue>[
            UnifiedKeyframeProjectionIssue(
              code: UnifiedKeyframeProjectionIssueCode.unsupportedValueKind,
              message:
                  'Keyframe ${keyframe.id} has a non-numeric value and cannot be projected.',
            ),
          ],
        );
      }
      normalizedStops.add(_normalizeTime(keyframe.time, window));
      keyframeIds.add(keyframe.id);
      keyframeValues.add(rawValue.toDouble() * valueScale);
    }

    final span = _projectActiveSpan(
      channel.activeRange,
      window,
    );

    return UnifiedKeyframeTimelineProjectionResult(
      lane: TimelineAnimationLaneData(
        id: channel.id,
        label: label ?? _defaultLabelFor(channel.definition),
        targetClipId: targetClipId,
        normalizedKeyframeStops: List<double>.unmodifiable(normalizedStops),
        keyframeIds: List<String>.unmodifiable(keyframeIds),
        keyframeValues: List<double>.unmodifiable(keyframeValues),
        trackSpanStartProgress: span.$1,
        trackSpanEndProgress: span.$2,
      ),
    );
  }

  bool _isTimelineScalar(MotionPropertyValueKind kind) {
    return kind == MotionPropertyValueKind.scalar ||
        kind == MotionPropertyValueKind.integer;
  }

  bool _containsInclusiveEnd(TimelineTimeRange range, TimelineTime time) {
    return time >= range.start && time <= range.endExclusive;
  }

  double _normalizeTime(TimelineTime time, TimelineTimeRange window) {
    final durationTicks = window.duration.inProjectTicks;
    if (durationTicks <= 0) {
      return 0;
    }
    final offsetTicks = (time - window.start).inProjectTicks;
    return (offsetTicks / durationTicks).clamp(0.0, 1.0).toDouble();
  }

  (double?, double?) _projectActiveSpan(
    TimelineTimeRange? activeRange,
    TimelineTimeRange window,
  ) {
    if (activeRange == null) {
      return (null, null);
    }
    final clampedStart =
        activeRange.start < window.start ? window.start : activeRange.start;
    final clampedEnd = activeRange.endExclusive > window.endExclusive
        ? window.endExclusive
        : activeRange.endExclusive;
    if (clampedEnd <= clampedStart) {
      return (0.0, 0.0);
    }
    return (
      _normalizeTime(clampedStart, window),
      _normalizeTime(clampedEnd, window),
    );
  }

  String _defaultLabelFor(MotionPropertyDefinition definition) {
    final component = definition.path.component;
    if (component == null || component.isEmpty) {
      return definition.path.name;
    }
    return '${definition.path.name}.$component';
  }
}
