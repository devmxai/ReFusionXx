import '../models/timeline_mock_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';

const String kTransitionFocusGraphPresetParameterPrefix = '__tf_graph_preset__';
const String kTransitionFocusGraphVelocityParameterPrefix =
    '__tf_graph_velocity__';

String transitionFocusGraphPresetParameterKey({
  required String laneId,
  required String keyframeId,
}) {
  return '$kTransitionFocusGraphPresetParameterPrefix$laneId::$keyframeId';
}

double transitionFocusGraphPresetParameterValue(int presetIndex) {
  return presetIndex.clamp(0, 8).toDouble();
}

int transitionFocusGraphPresetIndex(double? parameterValue) {
  if (parameterValue == null) {
    return 0;
  }
  return parameterValue.round().clamp(0, 8);
}

String transitionFocusGraphVelocityParameterKey({
  required String laneId,
  required String keyframeId,
  required String field,
}) {
  return '$kTransitionFocusGraphVelocityParameterPrefix$laneId::$keyframeId::$field';
}

double _encodeBool(bool value) => value ? 1.0 : 0.0;
bool _decodeBool(double? value, {required bool fallback}) {
  if (value == null) {
    return fallback;
  }
  return value >= 0.5;
}

MotionKeyframeVelocity transitionFocusGraphVelocityFromParameters({
  required TimelineTrackTransitionData transition,
  required String laneId,
  required String keyframeId,
  MotionKeyframeVelocity? fallback,
}) {
  double? read(String field) =>
      transition.parameterValues[transitionFocusGraphVelocityParameterKey(
        laneId: laneId,
        keyframeId: keyframeId,
        field: field,
      )];
  final hasVelocityOverride = read('incomingSpeed') != null ||
      read('outgoingSpeed') != null ||
      read('incomingInfluence') != null ||
      read('outgoingInfluence') != null ||
      read('incomingHandleLocked') != null ||
      read('outgoingHandleLocked') != null ||
      read('continuous') != null;
  return MotionKeyframeVelocity(
    incomingSpeed: read('incomingSpeed') ?? fallback?.incomingSpeed,
    outgoingSpeed: read('outgoingSpeed') ?? fallback?.outgoingSpeed,
    incomingInfluence: read('incomingInfluence') ?? fallback?.incomingInfluence,
    outgoingInfluence: read('outgoingInfluence') ?? fallback?.outgoingInfluence,
    incomingHandleLocked: _decodeBool(
      read('incomingHandleLocked'),
      fallback: fallback?.incomingHandleLocked ?? false,
    ),
    outgoingHandleLocked: _decodeBool(
      read('outgoingHandleLocked'),
      fallback: fallback?.outgoingHandleLocked ?? false,
    ),
    continuous: _decodeBool(
      read('continuous'),
      fallback: fallback?.continuous ?? false,
    ),
    roving: fallback?.roving ?? false,
    presetId: hasVelocityOverride
        ? 'customSpeedGraph'
        : (fallback?.presetId ?? 'linear'),
  );
}

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
    final isMotionBlurAmountLane = laneId == 'motion_blur' ||
        laneId == 'transform.motion_blur' ||
        laneId == 'position.motion_blur' ||
        laneId == 'scale.motion_blur' ||
        laneId == 'rotation.motion_blur';
    return transition.copyWith(
      manualAnimationLanes: List<TimelineAnimationLaneData>.unmodifiable(lanes),
      manualEffectIds: transition.manualEffectIds.contains(laneId)
          ? transition.manualEffectIds
          : <String>[...transition.manualEffectIds, laneId],
      parameterValues: isMotionBlurAmountLane
          ? <String, double>{
              ...transition.parameterValues,
              laneId: value,
            }
          : transition.parameterValues,
    );
  }

  TimelineTrackTransitionData writeLaneKeyframeGraphPreset({
    required TimelineTrackTransitionData transition,
    required String laneId,
    required int keyframeIndex,
    required int presetIndex,
  }) {
    final lane = transition.manualAnimationLaneById(laneId);
    if (lane == null) {
      return transition;
    }
    final stops = lane.normalizedKeyframeStops;
    if (keyframeIndex < 0 || keyframeIndex >= stops.length) {
      return transition;
    }
    final keyframeIds = List<String>.from(lane.keyframeIds);
    while (keyframeIds.length < stops.length) {
      keyframeIds.add('$laneId#${keyframeIds.length}');
    }
    final keyframeId = keyframeIds[keyframeIndex];
    final key = transitionFocusGraphPresetParameterKey(
      laneId: laneId,
      keyframeId: keyframeId,
    );
    return transition.copyWith(
      parameterValues: <String, double>{
        ...transition.parameterValues,
        key: transitionFocusGraphPresetParameterValue(presetIndex),
      },
    );
  }

  TimelineTrackTransitionData writeLaneKeyframeGraphVelocity({
    required TimelineTrackTransitionData transition,
    required String laneId,
    required int keyframeIndex,
    required MotionKeyframeVelocity velocity,
  }) {
    final lane = transition.manualAnimationLaneById(laneId);
    if (lane == null) {
      return transition;
    }
    final stops = lane.normalizedKeyframeStops;
    if (keyframeIndex < 0 || keyframeIndex >= stops.length) {
      return transition;
    }
    final keyframeIds = List<String>.from(lane.keyframeIds);
    while (keyframeIds.length < stops.length) {
      keyframeIds.add('$laneId#${keyframeIds.length}');
    }
    final keyframeId = keyframeIds[keyframeIndex];
    final nextValues = <String, double>{...transition.parameterValues};
    void write(String field, double value) {
      nextValues[transitionFocusGraphVelocityParameterKey(
        laneId: laneId,
        keyframeId: keyframeId,
        field: field,
      )] = value;
    }

    write('incomingSpeed', velocity.incomingSpeed ?? 0.0);
    write('outgoingSpeed', velocity.outgoingSpeed ?? 0.0);
    write('incomingInfluence', velocity.incomingInfluence ?? 33.333);
    write('outgoingInfluence', velocity.outgoingInfluence ?? 33.333);
    write('incomingHandleLocked', _encodeBool(velocity.incomingHandleLocked));
    write('outgoingHandleLocked', _encodeBool(velocity.outgoingHandleLocked));
    write('continuous', _encodeBool(velocity.continuous));
    return transition.copyWith(parameterValues: nextValues);
  }
}
