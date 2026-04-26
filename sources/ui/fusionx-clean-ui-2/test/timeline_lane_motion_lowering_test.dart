import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/timeline_lane_motion_lowering.dart';

void main() {
  const service = TimelineLaneMotionLoweringService();
  const target = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'text-1',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'layer',
    elementId: 'text-1',
  );

  TimelineTime time(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(start: time(start), endExclusive: time(end));
  }

  test('lowers a timeline lane into a stable scalar motion channel', () {
    const lane = TimelineAnimationLaneData(
      id: 'opacity-channel',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0, 0.5, 1],
      keyframeIds: <String>['kf-a', 'kf-b', 'kf-c'],
      keyframeValues: <double>[0, 50, 100],
    );

    final result = service.lowerLane(
      lane: lane,
      target: target,
      definition: MotionPropertyCatalog.opacity,
      activeRange: range(2, 6),
      valueScale: 100,
      interpolation: const MotionInterpolationSpec.easeInOut(),
    );

    expect(result.hasIssues, isFalse);
    final channel = result.channel!;
    expect(channel.id, 'opacity-channel');
    expect(channel.target, target);
    expect(channel.activeRange!.start, time(2));
    expect(channel.activeRange!.endExclusive, time(6));
    expect(channel.keyframes.map((keyframe) => keyframe.id), <String>[
      'kf-a',
      'kf-b',
      'kf-c',
    ]);
    expect(channel.keyframes.map((keyframe) => keyframe.time), <TimelineTime>[
      time(2),
      time(4),
      time(6),
    ]);
    expect(
      channel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[0, 0.5, 1],
    );
    expect(
      channel.keyframes.map((keyframe) => keyframe.interpolationToNext.kind),
      <MotionInterpolationKind>[
        MotionInterpolationKind.easeInOut,
        MotionInterpolationKind.easeInOut,
        MotionInterpolationKind.easeInOut,
      ],
    );
  });

  test('creates deterministic keyframe IDs when old lanes have none', () {
    const lane = TimelineAnimationLaneData(
      id: 'rotation-channel',
      label: 'Rotation',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0.25],
      keyframeValues: <double>[90],
    );

    final result = service.lowerLane(
      lane: lane,
      target: target,
      definition: MotionPropertyCatalog.rotationDegrees,
      activeRange: range(0, 4),
    );

    expect(result.hasIssues, isFalse);
    expect(result.channel!.keyframes.single.id, 'rotation-channel.keyframe.0');
    expect(result.channel!.keyframes.single.time, time(1));
    expect(result.channel!.keyframes.single.value.rawValue, 90);
  });

  test('rejects duplicate keyframe times instead of silently merging them', () {
    const lane = TimelineAnimationLaneData(
      id: 'opacity-channel',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0.5, 0.5],
      keyframeValues: <double>[20, 80],
    );

    final result = service.lowerLane(
      lane: lane,
      target: target,
      definition: MotionPropertyCatalog.opacity,
      activeRange: range(0, 2),
    );

    expect(result.channel, isNull);
    expect(result.hasIssues, isTrue);
    expect(
      result.issues.single.code,
      TimelineLaneMotionLoweringIssueCode.duplicateKeyframeTime,
    );
  });

  test('rejects non-scalar property definitions', () {
    const lane = TimelineAnimationLaneData(
      id: 'crop-channel',
      label: 'Crop',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0],
      keyframeValues: <double>[1],
    );

    final result = service.lowerLane(
      lane: lane,
      target: target,
      definition: MotionPropertyCatalog.cropRect,
      activeRange: range(0, 1),
    );

    expect(result.channel, isNull);
    expect(result.hasIssues, isTrue);
    expect(
      result.issues.single.code,
      TimelineLaneMotionLoweringIssueCode.unsupportedValueKind,
    );
  });
}
