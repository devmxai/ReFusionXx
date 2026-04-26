import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/timeline_lane_motion_lowering.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_keyframe_timeline_projection.dart';

void main() {
  const lowerer = TimelineLaneMotionLoweringService();
  const projector = UnifiedKeyframeTimelineProjectionService();
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

  test('lowering then projecting preserves scalar keyframe identity and timing',
      () {
    const sourceLane = TimelineAnimationLaneData(
      id: 'opacity-channel',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0.0, 0.375, 1.0],
      keyframeIds: <String>['opacity-a', 'opacity-b', 'opacity-c'],
      keyframeValues: <double>[0, 42, 100],
    );
    final activeRange = range(2, 10);

    final lowered = lowerer.lowerLane(
      lane: sourceLane,
      target: target,
      definition: MotionPropertyCatalog.opacity,
      activeRange: activeRange,
      valueScale: 100,
    );
    expect(lowered.hasIssues, isFalse);

    final projected = projector.projectChannel(
      channel: lowered.channel!,
      window: activeRange,
      targetClipId: 'clip-1',
      label: sourceLane.label,
      valueScale: 100,
    );

    expect(projected.hasIssues, isFalse);
    final roundTrippedLane = projected.lane!;
    expect(roundTrippedLane.id, sourceLane.id);
    expect(roundTrippedLane.label, sourceLane.label);
    expect(roundTrippedLane.targetClipId, sourceLane.targetClipId);
    expect(roundTrippedLane.keyframeIds, sourceLane.keyframeIds);
    expect(
      roundTrippedLane.normalizedKeyframeStops,
      sourceLane.normalizedKeyframeStops,
    );
    expect(roundTrippedLane.keyframeValues, sourceLane.keyframeValues);
  });

  test('batch lowering keeps valid lanes and reports invalid ones', () {
    const opacityLane = TimelineAnimationLaneData(
      id: 'opacity-channel',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0, 1],
      keyframeValues: <double>[0, 100],
    );
    const cropLane = TimelineAnimationLaneData(
      id: 'crop-channel',
      label: 'Crop',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0],
      keyframeValues: <double>[1],
    );

    final result = lowerer.lowerLanes(
      requests: <TimelineLaneMotionLoweringRequest>[
        TimelineLaneMotionLoweringRequest(
          lane: opacityLane,
          target: target,
          definition: MotionPropertyCatalog.opacity,
          activeRange: range(0, 2),
          valueScale: 100,
        ),
        TimelineLaneMotionLoweringRequest(
          lane: cropLane,
          target: target,
          definition: MotionPropertyCatalog.cropRect,
          activeRange: range(0, 2),
        ),
      ],
    );

    expect(result.hasIssues, isTrue);
    expect(result.channels.map((channel) => channel.id), <String>[
      'opacity-channel',
    ]);
    expect(
      result.issues.single.code,
      TimelineLaneMotionLoweringIssueCode.unsupportedValueKind,
    );
  });
}
