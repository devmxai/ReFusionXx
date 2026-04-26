import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_keyframe_timeline_projection.dart';

void main() {
  const service = UnifiedKeyframeTimelineProjectionService();
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

  MotionKeyframeModel scalarKeyframe({
    required String id,
    required String channelId,
    required double seconds,
    required double value,
  }) {
    return MotionKeyframeModel(
      id: id,
      channelId: channelId,
      time: time(seconds),
      value: MotionPropertyValue.scalar(value),
      interpolationToNext: const MotionInterpolationSpec.linear(),
    );
  }

  test('projects scalar graph channels into timeline lanes by stable ID', () {
    final channel = MotionPropertyChannelModel(
      id: 'opacity-channel',
      target: target,
      definition: MotionPropertyCatalog.opacity,
      activeRange: range(1, 4),
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'opacity-start',
          channelId: 'opacity-channel',
          seconds: 1,
          value: 0.25,
        ),
        scalarKeyframe(
          id: 'opacity-end',
          channelId: 'opacity-channel',
          seconds: 3,
          value: 0.8,
        ),
      ],
    );

    final result = service.projectChannel(
      channel: channel,
      window: range(0, 5),
      targetClipId: 'clip-1',
      label: 'Opacity',
      valueScale: 100,
    );

    expect(result.hasIssues, isFalse);
    final lane = result.lane!;
    expect(lane.id, 'opacity-channel');
    expect(lane.label, 'Opacity');
    expect(lane.targetClipId, 'clip-1');
    expect(lane.keyframeIds, <String>['opacity-start', 'opacity-end']);
    expect(lane.normalizedKeyframeStops, <double>[0.2, 0.6]);
    expect(lane.keyframeValues, <double>[25, 80]);
    expect(lane.trackSpanStartProgress, 0.2);
    expect(lane.trackSpanEndProgress, 0.8);
  });

  test('ignores keyframes outside the requested timeline window', () {
    final channel = MotionPropertyChannelModel(
      id: 'scale-channel',
      target: target,
      definition: MotionPropertyCatalog.scaleX,
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'before',
          channelId: 'scale-channel',
          seconds: -1,
          value: 0.4,
        ),
        scalarKeyframe(
          id: 'inside',
          channelId: 'scale-channel',
          seconds: 1.5,
          value: 1.2,
        ),
        scalarKeyframe(
          id: 'after',
          channelId: 'scale-channel',
          seconds: 6,
          value: 1.4,
        ),
      ],
    );

    final result = service.projectChannel(
      channel: channel,
      window: range(0, 3),
      targetClipId: 'clip-1',
    );

    expect(result.hasIssues, isFalse);
    expect(result.lane!.keyframeIds, <String>['inside']);
    expect(result.lane!.normalizedKeyframeStops, <double>[0.5]);
    expect(result.lane!.keyframeValues, <double>[1.2]);
  });

  test('rejects non-scalar channels instead of creating fake UI lanes', () {
    final cropChannel = MotionPropertyChannelModel(
      id: 'crop-channel',
      target: target,
      definition: MotionPropertyCatalog.cropRect,
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'crop-start',
          channelId: 'crop-channel',
          time: time(1),
          value: const MotionPropertyValue.rect(
            MotionRect(left: 0, top: 0, width: 1, height: 1),
          ),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );

    final result = service.projectChannel(
      channel: cropChannel,
      window: range(0, 3),
      targetClipId: 'clip-1',
    );

    expect(result.lane, isNull);
    expect(result.hasIssues, isTrue);
    expect(
      result.issues.single.code,
      UnifiedKeyframeProjectionIssueCode.unsupportedValueKind,
    );
  });

  test('rejects empty projection windows', () {
    final channel = MotionPropertyChannelModel(
      id: 'opacity-channel',
      target: target,
      definition: MotionPropertyCatalog.opacity,
    );

    final result = service.projectChannel(
      channel: channel,
      window: range(2, 2),
      targetClipId: 'clip-1',
    );

    expect(result.lane, isNull);
    expect(result.hasIssues, isTrue);
    expect(
      result.issues.single.code,
      UnifiedKeyframeProjectionIssueCode.emptyWindow,
    );
  });
}
