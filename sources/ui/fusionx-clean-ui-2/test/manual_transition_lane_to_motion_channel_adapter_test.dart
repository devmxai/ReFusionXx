import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/manual_transition_lane_to_motion_channel_adapter.dart';

void main() {
  const adapter = ManualTransitionLaneToMotionChannelAdapter();

  test('maps scale lane to active-source scale channels in transition window',
      () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(2000),
      manualEffectIds: const <String>['scale'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'scale',
          label: 'Scale',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeIds: <String>['k0', 'k1'],
          keyframeValues: <double>[0.0, 100.0],
        ),
      ],
    );

    final result = adapter.projectChannels(
      request: ManualTransitionLaneChannelProjectionRequest(
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(5000),
        projectId: 'project-1',
      ),
    );

    expect(result.issues, isEmpty);
    expect(result.channels.length, 4);
    final scaleX = result.channels.firstWhere(
      (channel) =>
          channel.definition.id == 'transform.scale.x' &&
          channel.target.targetId == 'clip-a',
    );
    final scaleY = result.channels.firstWhere(
      (channel) =>
          channel.definition.id == 'transform.scale.y' &&
          channel.target.targetId == 'clip-a',
    );
    expect(scaleX.keyframes.length, 2);
    expect(scaleY.keyframes.length, 2);
    expect(scaleX.keyframes.first.time, TimelineTime.fromMilliseconds(4000));
    expect(scaleX.keyframes.last.time, TimelineTime.fromMilliseconds(6000));
    expect(scaleX.keyframes.first.value.rawValue, 1.0);
    expect(scaleX.keyframes.last.value.rawValue, 2.0);
    expect(
      result.channels.any((channel) => channel.target.targetId == 'clip-b'),
      isTrue,
    );
    final incomingScaleX = result.channels.firstWhere(
      (channel) =>
          channel.definition.id == 'transform.scale.x' &&
          channel.target.targetId == 'clip-b',
    );
    expect(incomingScaleX.keyframes.first.time,
        TimelineTime.fromMilliseconds(4000));
    expect(incomingScaleX.keyframes.last.time,
        TimelineTime.fromMilliseconds(6000));
    expect(incomingScaleX.keyframes.first.value.rawValue, 1.0);
    expect(incomingScaleX.keyframes.last.value.rawValue, 2.0);
  });

  test('keeps explicit right-side manual lane scoped to incoming clip', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(2000),
      manualEffectIds: const <String>['scale'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'scale',
          label: 'Scale',
          targetClipId: 'clip-b',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[0.0, 50.0],
        ),
      ],
    );

    final result = adapter.projectChannels(
      request: ManualTransitionLaneChannelProjectionRequest(
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(5000),
        projectId: 'project-1',
      ),
    );

    expect(result.issues, isEmpty);
    expect(result.channels.length, 2);
    expect(
      result.channels.map((channel) => channel.target.targetId).toSet(),
      <String>{'clip-b'},
    );
  });

  test('maps manual keyframes across the explicit transition focus window', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(2000),
      manualEffectIds: const <String>['scale'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'scale',
          label: 'Scale',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.125, 0.5],
          keyframeIds: <String>['k0', 'k1'],
          keyframeValues: <double>[0.0, 70.0],
        ),
      ],
    );

    final result = adapter.projectChannels(
      request: ManualTransitionLaneChannelProjectionRequest(
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(4000),
        projectId: 'project-1',
        windowStartTime: TimelineTime.zero,
        windowEndTime: TimelineTime.fromMilliseconds(8000),
      ),
    );

    expect(result.issues, isEmpty);
    final scaleX = result.channels.firstWhere(
      (channel) => channel.definition.id == 'transform.scale.x',
    );
    expect(scaleX.keyframes.first.time, TimelineTime.fromMilliseconds(1000));
    expect(scaleX.keyframes.last.time, TimelineTime.fromMilliseconds(4000));
    expect(scaleX.keyframes.first.value.rawValue, 1.0);
    expect(scaleX.keyframes.last.value.rawValue, 1.7);
  });

  test('maps opacity lane from percent to renderer scalar', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1000),
      manualEffectIds: const <String>['opacity'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'opacity',
          label: 'Opacity',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[100.0, 0.0],
        ),
      ],
    );

    final result = adapter.projectChannels(
      request: ManualTransitionLaneChannelProjectionRequest(
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(2000),
        projectId: 'project-1',
      ),
    );

    expect(result.issues, isEmpty);
    expect(result.channels.length, 2);
    final opacity = result.channels.firstWhere(
      (channel) => channel.target.targetId == 'clip-a',
    );
    expect(opacity.definition.id, 'visual.opacity');
    expect(opacity.keyframes.length, 2);
    expect(opacity.keyframes.first.value.rawValue, 1.0);
    expect(opacity.keyframes.last.value.rawValue, 0.0);
    final incomingOpacity = result.channels.firstWhere(
      (channel) => channel.target.targetId == 'clip-b',
    );
    expect(incomingOpacity.definition.id, 'visual.opacity');
    expect(incomingOpacity.keyframes.first.value.rawValue, 1.0);
    expect(incomingOpacity.keyframes.last.value.rawValue, 0.0);
  });

  test('maps focus scoped lane target ids back to real clip ids', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(2000),
      manualEffectIds: const <String>['rotation'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'rotation',
          label: 'Rotation',
          targetClipId: 'transition-1::focus-left',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeIds: <String>['k0', 'k1'],
          keyframeValues: <double>[0.0, 90.0],
        ),
      ],
    );

    final result = adapter.projectChannels(
      request: ManualTransitionLaneChannelProjectionRequest(
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(5000),
        projectId: 'project-1',
      ),
    );

    expect(result.issues, isEmpty);
    expect(result.channels.length, 1);
    final rotation = result.channels.single;
    expect(rotation.definition.id, 'transform.rotation.degrees');
    expect(rotation.target.targetId, 'clip-a');
    expect(rotation.keyframes.first.value.rawValue, 0.0);
    expect(rotation.keyframes.last.value.rawValue, 90.0);
  });

  test('reports unsupported lane ids as issues', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1000),
      manualEffectIds: const <String>['unsupported_lane'],
    );

    final result = adapter.projectChannels(
      request: ManualTransitionLaneChannelProjectionRequest(
        transition: transition,
        seamTime: TimelineTime.fromMilliseconds(2000),
        projectId: 'project-1',
      ),
    );

    expect(result.channels, isEmpty);
    expect(result.issues.length, 1);
    expect(
      result.issues.single.code,
      ManualTransitionLaneChannelIssueCode.unsupportedLane,
    );
    expect(result.issues.single.laneId, 'unsupported_lane');
  });
}
