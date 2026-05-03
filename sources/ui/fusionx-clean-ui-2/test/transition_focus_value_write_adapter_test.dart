import 'package:flutter_test/flutter_test.dart';
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
}
