import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/services/composition_timeline_projection.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

class UnifiedScopeTimelineProjectionAdapter {
  const UnifiedScopeTimelineProjectionAdapter();

  List<TimelineAnimationLaneData> animationLanesForScope(
    ScopeProjection projection, {
    String? targetClipId,
  }) {
    final lanes = <TimelineAnimationLaneData>[];
    for (final channel in projection.channels) {
      final lane = _laneForChannel(
        projection: projection,
        channel: channel,
        targetClipId: targetClipId ?? projection.layerId ?? projection.id,
      );
      if (lane != null) {
        lanes.add(lane);
      }
    }
    lanes.sort((left, right) => left.label.compareTo(right.label));
    return List<TimelineAnimationLaneData>.unmodifiable(lanes);
  }

  TimelineAnimationLaneData? _laneForChannel({
    required ScopeProjection projection,
    required MotionPropertyChannelModel channel,
    required String targetClipId,
  }) {
    final keyframes = channel.keyframes;
    if (keyframes.isEmpty) {
      return null;
    }
    final duration = projection.localRange.duration;
    if (duration <= TimelineTime.zero) {
      return null;
    }

    final sortedKeyframes = List<MotionKeyframeModel>.from(keyframes)
      ..sort((left, right) => left.time.compareTo(right.time));
    final stops = <double>[];
    final ids = <String>[];
    final values = <double>[];

    for (final keyframe in sortedKeyframes) {
      final value = _doubleValueFor(keyframe.value);
      if (value == null) {
        continue;
      }
      stops.add(_progressForLocalTime(keyframe.time, duration));
      ids.add(keyframe.id);
      values.add(value);
    }

    if (stops.isEmpty) {
      return null;
    }

    return TimelineAnimationLaneData(
      id: channel.id,
      label: _labelForDefinition(channel.definition),
      targetClipId: targetClipId,
      normalizedKeyframeStops: List<double>.unmodifiable(stops),
      keyframeIds: List<String>.unmodifiable(ids),
      keyframeValues: List<double>.unmodifiable(values),
      trackSpanStartProgress: _progressForLocalTime(
        channel.activeRange?.start ?? projection.localRange.start,
        duration,
      ),
      trackSpanEndProgress: _progressForLocalTime(
        channel.activeRange?.endExclusive ?? projection.localRange.endExclusive,
        duration,
      ),
    );
  }

  double _progressForLocalTime(TimelineTime time, TimelineTime duration) {
    final durationTicks = duration.inProjectTicks;
    if (durationTicks <= 0) {
      return 0;
    }
    return (time.inProjectTicks / durationTicks).clamp(0.0, 1.0).toDouble();
  }

  double? _doubleValueFor(MotionPropertyValue value) {
    return switch (value.kind) {
      MotionPropertyValueKind.scalar => (value.rawValue as double).toDouble(),
      MotionPropertyValueKind.integer => (value.rawValue as int).toDouble(),
      MotionPropertyValueKind.boolean => (value.rawValue as bool) ? 1.0 : 0.0,
      MotionPropertyValueKind.stringValue ||
      MotionPropertyValueKind.colorArgb ||
      MotionPropertyValueKind.point2D ||
      MotionPropertyValueKind.size2D ||
      MotionPropertyValueKind.rect ||
      MotionPropertyValueKind.enumValue =>
        null,
    };
  }

  String _labelForDefinition(MotionPropertyDefinition definition) {
    final component = definition.path.component;
    final parts = <String>[
      definition.path.name,
      if (component != null && component.isNotEmpty) component,
    ];
    return parts.map(_titleCase).join(' ');
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    final spaced = value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('.', ' ')
        .replaceAll('_', ' ')
        .trim();
    if (spaced.isEmpty) {
      return value;
    }
    return spaced
        .split(RegExp(r'\s+'))
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
