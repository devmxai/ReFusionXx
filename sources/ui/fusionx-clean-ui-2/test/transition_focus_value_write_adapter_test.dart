import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_focus_value_write_adapter.dart';

void main() {
  const adapter = TransitionFocusValueWriteAdapter();

  test('updates selected keyframe value inside manual animation lane', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1200),
      manualEffectIds: const <String>['scale'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'scale',
          label: 'Scale',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeIds: <String>['k0', 'k1'],
          keyframeValues: <double>[0.0, 0.0],
        ),
      ],
    );

    final updated = adapter.writeLaneKeyframeValue(
      transition: transition,
      laneId: 'scale',
      keyframeIndex: 1,
      value: 100.0,
      fallbackValue: 0.0,
    );

    final lane = updated.manualAnimationLaneById('scale');
    expect(lane, isNotNull);
    expect(lane!.keyframeValues, <double>[0.0, 100.0]);
    expect(updated.manualEffectIds, contains('scale'));
  });

  test('keeps transition unchanged when keyframe index is invalid', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1200),
      manualEffectIds: const <String>['scale'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'scale',
          label: 'Scale',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[0.0, 100.0],
        ),
      ],
    );

    final updated = adapter.writeLaneKeyframeValue(
      transition: transition,
      laneId: 'scale',
      keyframeIndex: 4,
      value: 55.0,
      fallbackValue: 0.0,
    );

    expect(identical(updated, transition), isTrue);
    expect(
      updated.manualAnimationLaneById('scale')!.keyframeValues,
      <double>[0.0, 100.0],
    );
  });

  test('persists motion blur amount as lane setting and keyframe value', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1200),
      manualEffectIds: const <String>['rotation', 'rotation.motion_blur'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'rotation.motion_blur',
          label: 'Rotation Motion Blur',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeIds: <String>['mb0', 'mb1'],
          keyframeValues: <double>[0.0, 0.0],
        ),
      ],
    );

    final updated = adapter.writeLaneKeyframeValue(
      transition: transition,
      laneId: 'rotation.motion_blur',
      keyframeIndex: 1,
      value: 100.0,
      fallbackValue: 0.0,
    );

    final lane = updated.manualAnimationLaneById('rotation.motion_blur');
    expect(lane, isNotNull);
    expect(lane!.keyframeValues, <double>[0.0, 100.0]);
    expect(updated.parameterValue('rotation.motion_blur'), 100.0);
    expect(updated.manualEffectIds, contains('rotation.motion_blur'));
  });

  test('persists graph preset selection for transition focus keyframe', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1200),
      manualEffectIds: const <String>['rotation'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'rotation',
          label: 'Rotation',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeIds: <String>['rot-0', 'rot-1'],
          keyframeValues: <double>[0.0, 360.0],
        ),
      ],
    );

    final updated = adapter.writeLaneKeyframeGraphPreset(
      transition: transition,
      laneId: 'rotation',
      keyframeIndex: 0,
      presetIndex: 4,
    );

    expect(
      updated.parameterValue('__tf_graph_preset__rotation::rot-0',
          fallback: -1),
      4.0,
    );
  });

  test('persists custom graph velocity fields for transition focus keyframe',
      () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1200),
      manualEffectIds: const <String>['rotation'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'rotation',
          label: 'Rotation',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeIds: <String>['rot-0', 'rot-1'],
          keyframeValues: <double>[0.0, 360.0],
        ),
      ],
    );

    final updated = adapter.writeLaneKeyframeGraphVelocity(
      transition: transition,
      laneId: 'rotation',
      keyframeIndex: 1,
      velocity: const MotionKeyframeVelocity(
        incomingSpeed: 88.0,
        outgoingSpeed: 44.0,
        incomingInfluence: 81.0,
        outgoingInfluence: 69.0,
        incomingHandleLocked: true,
        outgoingHandleLocked: false,
        continuous: false,
        presetId: 'customSpeedGraph',
      ),
    );

    expect(
      updated.parameterValue(
        '__tf_graph_velocity__rotation::rot-1::incomingSpeed',
        fallback: -1,
      ),
      88.0,
    );
    expect(
      updated.parameterValue(
        '__tf_graph_velocity__rotation::rot-1::outgoingSpeed',
        fallback: -1,
      ),
      44.0,
    );
    expect(
      updated.parameterValue(
        '__tf_graph_velocity__rotation::rot-1::incomingInfluence',
        fallback: -1,
      ),
      81.0,
    );
    expect(
      updated.parameterValue(
        '__tf_graph_velocity__rotation::rot-1::outgoingInfluence',
        fallback: -1,
      ),
      69.0,
    );
    expect(
      updated.parameterValue(
        '__tf_graph_velocity__rotation::rot-1::incomingHandleLocked',
        fallback: -1,
      ),
      1.0,
    );
    expect(
      updated.parameterValue(
        '__tf_graph_velocity__rotation::rot-1::outgoingHandleLocked',
        fallback: -1,
      ),
      0.0,
    );
    expect(
      updated.parameterValue(
        '__tf_graph_velocity__rotation::rot-1::continuous',
        fallback: -1,
      ),
      0.0,
    );
  });

  test('recovers persisted custom graph velocity from transition parameters', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1200),
      parameterValues: const <String, double>{
        '__tf_graph_velocity__rotation::rot-1::incomingSpeed': 72.0,
        '__tf_graph_velocity__rotation::rot-1::outgoingSpeed': 36.0,
        '__tf_graph_velocity__rotation::rot-1::incomingInfluence': 77.0,
        '__tf_graph_velocity__rotation::rot-1::outgoingInfluence': 64.0,
        '__tf_graph_velocity__rotation::rot-1::incomingHandleLocked': 1.0,
        '__tf_graph_velocity__rotation::rot-1::outgoingHandleLocked': 0.0,
        '__tf_graph_velocity__rotation::rot-1::continuous': 0.0,
      },
      manualEffectIds: const <String>['rotation'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'rotation',
          label: 'Rotation',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeIds: <String>['rot-0', 'rot-1'],
          keyframeValues: <double>[0.0, 360.0],
        ),
      ],
    );

    final velocity = transitionFocusGraphVelocityFromParameters(
      transition: transition,
      laneId: 'rotation',
      keyframeId: 'rot-1',
      fallback: const MotionKeyframeVelocity(
        incomingSpeed: 0.0,
        outgoingSpeed: 0.0,
        incomingInfluence: 33.333,
        outgoingInfluence: 33.333,
        continuous: true,
        presetId: 'easyEase',
      ),
    );

    expect(velocity.incomingSpeed, 72.0);
    expect(velocity.outgoingSpeed, 36.0);
    expect(velocity.incomingInfluence, 77.0);
    expect(velocity.outgoingInfluence, 64.0);
    expect(velocity.incomingHandleLocked, isTrue);
    expect(velocity.outgoingHandleLocked, isFalse);
    expect(velocity.continuous, isFalse);
    expect(velocity.presetId, 'customSpeedGraph');
  });
}
