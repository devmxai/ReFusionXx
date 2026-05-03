import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/manual_transition_lane_to_motion_channel_adapter.dart';

void main() {
  const adapter = ManualTransitionLaneToMotionChannelAdapter();

  test('maps scale lane to paired scale channels in transition window', () {
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
    final incomingScaleX = result.channels.firstWhere(
      (channel) =>
          channel.definition.id == 'transform.scale.x' &&
          channel.target.targetId == 'clip-b',
    );
    expect(scaleX.keyframes.length, 2);
    expect(scaleY.keyframes.length, 2);
    expect(incomingScaleX.keyframes.length, 2);
    expect(scaleX.keyframes.first.time, TimelineTime.fromMilliseconds(4000));
    expect(scaleX.keyframes.last.time, TimelineTime.fromMilliseconds(6000));
    expect(scaleX.keyframes.first.value.rawValue, 1.0);
    expect(scaleX.keyframes.last.value.rawValue, 2.0);
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
