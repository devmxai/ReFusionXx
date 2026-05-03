import '../models/timeline_mock_models.dart';

class TransitionFocusValueWriteAdapter {
  const TransitionFocusValueWriteAdapter();

  TimelineTrackTransitionData writeLaneKeyframeValue({
    required TimelineTrackTransitionData transition,
    required String laneId,
    required int keyframeIndex,
    required double value,
    required double fallbackValue,
  }) {
    final laneIndex = transition.manualAnimationLanes.indexWhere(
      (lane) => lane.id == laneId,
    );
    if (laneIndex < 0) {
      return transition;
    }
    final lanes = List<TimelineAnimationLaneData>.from(
      transition.manualAnimationLanes,
    );
    final lane = lanes[laneIndex];
    final values = lane
        .alignedKeyframeValues(
          fallbackValue: fallbackValue,
          clampToPercent: false,
        )
        .toList();
    if (keyframeIndex < 0 || keyframeIndex >= values.length) {
      return transition;
    }
    values[keyframeIndex] = value;
    lanes[laneIndex] = lane.copyWith(
      keyframeValues: List<double>.unmodifiable(values),
    );
    return transition.copyWith(
      manualAnimationLanes: List<TimelineAnimationLaneData>.unmodifiable(lanes),
      manualEffectIds: transition.manualEffectIds.contains(laneId)
          ? transition.manualEffectIds
          : <String>[...transition.manualEffectIds, laneId],
    );
  }
}
