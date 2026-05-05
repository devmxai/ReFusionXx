import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
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

  test('maps motion blur lane to active-source temporal blur amount channels',
      () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1000),
      manualEffectIds: const <String>['motion_blur'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'motion_blur',
          label: 'Motion Blur',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[0.0, 100.0],
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
    expect(result.channels.length, 18);
    expect(
      result.channels.map((channel) => channel.target.targetId).toSet(),
      <String>{'clip-a', 'clip-b'},
    );
    expect(
      result.channels.map((channel) => channel.definition.id).toSet(),
      <String>{
        MotionPropertyCatalog.motionBlurAmount.id,
        MotionPropertyCatalog.motionBlurShutterAngle.id,
        MotionPropertyCatalog.motionBlurShutterPhase.id,
        MotionPropertyCatalog.motionBlurSamples.id,
        MotionPropertyCatalog.motionBlurAdaptiveSampleLimit.id,
        MotionPropertyCatalog.motionBlurMaxTrailPx.id,
        MotionPropertyCatalog.motionBlurAffectPosition.id,
        MotionPropertyCatalog.motionBlurAffectScale.id,
        MotionPropertyCatalog.motionBlurAffectRotation.id,
      },
    );
    final amount = result.channels.firstWhere(
      (channel) =>
          channel.target.targetId == 'clip-a' &&
          channel.definition.id == MotionPropertyCatalog.motionBlurAmount.id,
    );
    expect(amount.keyframes.first.value.rawValue, 0.0);
    expect(amount.keyframes.last.value.rawValue, 100.0);
    final shutterAngle = result.channels.firstWhere(
      (channel) =>
          channel.target.targetId == 'clip-a' &&
          channel.definition.id ==
              MotionPropertyCatalog.motionBlurShutterAngle.id,
    );
    expect(shutterAngle.baseValue?.rawValue, 180.0);
  });

  test('maps professional motion blur settings as one effect policy', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1000),
      parameterValues: const <String, double>{
        'motion_blur_shutter_angle': 270.0,
        'motion_blur_shutter_phase': -135.0,
        'motion_blur_samples': 12.0,
        'motion_blur_adaptive_samples': 24.0,
        'motion_blur_max_trail': 360.0,
      },
      manualEffectIds: const <String>['motion_blur'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'motion_blur',
          label: 'Motion Blur',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[0.0, 80.0],
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
    expect(
      result.channels
          .where((channel) => channel.target.targetId == 'clip-a')
          .map((channel) => channel.definition.id)
          .toSet(),
      <String>{
        MotionPropertyCatalog.motionBlurAmount.id,
        MotionPropertyCatalog.motionBlurShutterAngle.id,
        MotionPropertyCatalog.motionBlurShutterPhase.id,
        MotionPropertyCatalog.motionBlurSamples.id,
        MotionPropertyCatalog.motionBlurAdaptiveSampleLimit.id,
        MotionPropertyCatalog.motionBlurMaxTrailPx.id,
        MotionPropertyCatalog.motionBlurAffectPosition.id,
        MotionPropertyCatalog.motionBlurAffectScale.id,
        MotionPropertyCatalog.motionBlurAffectRotation.id,
      },
    );
    final amount = result.channels.firstWhere(
      (channel) =>
          channel.target.targetId == 'clip-a' &&
          channel.definition.id == MotionPropertyCatalog.motionBlurAmount.id,
    );
    expect(amount.keyframes.last.value.rawValue, 80.0);
    final samples = result.channels.firstWhere(
      (channel) =>
          channel.target.targetId == 'clip-a' &&
          channel.definition.id == MotionPropertyCatalog.motionBlurSamples.id,
    );
    expect(samples.keyframes, isEmpty);
    expect(samples.baseValue?.rawValue, 12);
    final shutterPhase = result.channels.firstWhere(
      (channel) =>
          channel.target.targetId == 'clip-a' &&
          channel.definition.id ==
              MotionPropertyCatalog.motionBlurShutterPhase.id,
    );
    expect(shutterPhase.keyframes, isEmpty);
    expect(shutterPhase.baseValue?.rawValue, -135.0);
  });

  test('maps scale motion blur modifier to scale-only shutter policy', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1000),
      parameterValues: const <String, double>{
        'scale.motion_blur.shutter_angle': 360.0,
        'scale.motion_blur.samples': 16.0,
      },
      manualEffectIds: const <String>['scale', 'scale.motion_blur'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'scale',
          label: 'Scale',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[0.0, 85.0],
        ),
        TimelineAnimationLaneData(
          id: 'scale.motion_blur',
          label: 'Scale Motion Blur',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[0.0, 70.0],
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
    final clipAChannels = result.channels
        .where((channel) => channel.target.targetId == 'clip-a')
        .toList(growable: false);
    final amount = clipAChannels.firstWhere(
      (channel) =>
          channel.definition.id == MotionPropertyCatalog.motionBlurAmount.id,
    );
    expect(amount.keyframes.last.value.rawValue, 70.0);
    final shutterAngle = clipAChannels.firstWhere(
      (channel) =>
          channel.definition.id ==
          MotionPropertyCatalog.motionBlurShutterAngle.id,
    );
    expect(shutterAngle.baseValue?.rawValue, 360.0);
    final samples = clipAChannels.firstWhere(
      (channel) =>
          channel.definition.id == MotionPropertyCatalog.motionBlurSamples.id,
    );
    expect(samples.baseValue?.rawValue, 16);
    final affectPosition = clipAChannels.firstWhere(
      (channel) =>
          channel.definition.id ==
          MotionPropertyCatalog.motionBlurAffectPosition.id,
    );
    final affectScale = clipAChannels.firstWhere(
      (channel) =>
          channel.definition.id ==
          MotionPropertyCatalog.motionBlurAffectScale.id,
    );
    final affectRotation = clipAChannels.firstWhere(
      (channel) =>
          channel.definition.id ==
          MotionPropertyCatalog.motionBlurAffectRotation.id,
    );
    expect(affectPosition.baseValue?.rawValue, isFalse);
    expect(affectScale.baseValue?.rawValue, isTrue);
    expect(affectRotation.baseValue?.rawValue, isFalse);
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
