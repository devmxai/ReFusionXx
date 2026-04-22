import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_canvas_timeline_authoring_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_runtime_helpers.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const service = ProfessionalCanvasTimelineAuthoringService();
  const target = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'text-1',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'layer',
    elementId: 'text-1',
  );

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: TimelineTime.fromSecondsDouble(start),
      endExclusive: TimelineTime.fromSecondsDouble(end),
    );
  }

  test('setProperty writes a static base value without fake keyframes', () {
    final result = service.setProperty(
      CanvasTimelineSetPropertyRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 5),
        definition: MotionPropertyCatalog.opacity,
        value: const MotionPropertyValue.scalar(0.42),
      ),
    );

    expect(result.hasIssues, isFalse);
    expect(result.channels, hasLength(1));
    expect(result.channels.single.baseValue?.rawValue, 0.42);
    expect(result.channels.single.keyframes, isEmpty);
  });

  test('autoKey adds one real keyframe at the requested time', () {
    final result = service.setProperty(
      CanvasTimelineSetPropertyRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 5),
        definition: MotionPropertyCatalog.opacity,
        value: const MotionPropertyValue.scalar(0),
        time: TimelineTime.fromSecondsDouble(2),
        autoKey: true,
      ),
    );

    expect(result.hasIssues, isFalse);
    expect(result.channels.single.keyframes, hasLength(1));
    expect(
      result.channels.single.keyframes.single.time,
      TimelineTime.fromSecondsDouble(2),
    );
    expect(result.channels.single.keyframes.single.value.rawValue, 0);
  });

  test('setKeyframeValue updates the selected keyframe value only', () {
    final initial = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 5),
        definition: MotionPropertyCatalog.opacity,
        time: TimelineTime.fromSecondsDouble(1),
        value: const MotionPropertyValue.scalar(0.2),
      ),
    );
    final channel = initial.channels.single;
    final keyframe = channel.keyframes.single;

    final updated = service.setKeyframeValue(
      CanvasTimelineKeyframeValueRequest(
        channels: initial.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
        value: const MotionPropertyValue.scalar(0.8),
      ),
    );

    expect(updated.hasIssues, isFalse);
    expect(updated.channels.single.keyframes.single.id, keyframe.id);
    expect(updated.channels.single.keyframes.single.value.rawValue, 0.8);
  });

  test('moveKeyframe keeps the keyframe stable and sorts by time', () {
    final first = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 5),
        definition: MotionPropertyCatalog.positionX,
        time: TimelineTime.fromSecondsDouble(1),
        value: const MotionPropertyValue.scalar(10),
      ),
    );
    final second = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: first.channels,
        target: target,
        activeRange: range(0, 5),
        definition: MotionPropertyCatalog.positionX,
        time: TimelineTime.fromSecondsDouble(3),
        value: const MotionPropertyValue.scalar(30),
      ),
    );
    final channel = second.channels.single;
    final movedKeyframe = channel.keyframes.last;

    final moved = service.moveKeyframe(
      CanvasTimelineMoveKeyframeRequest(
        channels: second.channels,
        channelId: channel.id,
        keyframeId: movedKeyframe.id,
        activeRange: range(0, 5),
        time: TimelineTime.fromSecondsDouble(0.5),
      ),
    );

    expect(moved.hasIssues, isFalse);
    expect(moved.channels.single.keyframes, hasLength(2));
    expect(moved.channels.single.keyframes.first.id, movedKeyframe.id);
    expect(
      moved.channels.single.keyframes.first.time,
      TimelineTime.fromSecondsDouble(0.5),
    );
  });

  test('setKeyframeInterpolation updates the selected keyframe easing', () {
    final first = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 5),
        definition: MotionPropertyCatalog.opacity,
        time: TimelineTime.fromSecondsDouble(1),
        value: const MotionPropertyValue.scalar(0.2),
      ),
    );
    final second = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: first.channels,
        target: target,
        activeRange: range(0, 5),
        definition: MotionPropertyCatalog.opacity,
        time: TimelineTime.fromSecondsDouble(4),
        value: const MotionPropertyValue.scalar(1),
      ),
    );
    final channel = second.channels.single;
    final keyframe = channel.keyframes.first;
    final updated = service.setKeyframeInterpolation(
      CanvasTimelineKeyframeInterpolationRequest(
        channels: second.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
        interpolation: const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.3333,
            y1: 0.0,
            x2: 0.6667,
            y2: 1.0,
          ),
        ),
      ),
    );

    expect(updated.hasIssues, isFalse);
    expect(
      updated.channels.single.keyframes.first.interpolationToNext.kind,
      MotionInterpolationKind.cubicBezier,
    );
  });

  test('rejects unsupported property targets without changing channels', () {
    const layerTarget = MotionPropertyTarget(
      kind: MotionTargetKind.layer,
      targetId: 'layer-1',
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer-1',
    );

    final result = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: layerTarget,
        activeRange: range(0, 5),
        definition: MotionPropertyCatalog.positionX,
        time: TimelineTime.fromSecondsDouble(1),
        value: const MotionPropertyValue.scalar(100),
      ),
    );

    expect(result.channels, isEmpty);
    expect(result.issues.single.code,
        CanvasTimelineAuthoringIssueCode.unsupportedTarget);
  });

  test('authored keyframes evaluate through the shared motion sampler', () {
    final first = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 4),
        definition: MotionPropertyCatalog.opacity,
        time: TimelineTime.fromSecondsDouble(0),
        value: const MotionPropertyValue.scalar(0),
      ),
    );
    final second = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: first.channels,
        target: target,
        activeRange: range(0, 4),
        definition: MotionPropertyCatalog.opacity,
        time: TimelineTime.fromSecondsDouble(4),
        value: const MotionPropertyValue.scalar(1),
      ),
    );
    final channel = second.channels.single;
    final sample = const BasicMotionPropertyChannelSampler().sample(
      channel: MotionResolvedPropertyChannel(
        channel: channel,
        projectRange: range(0, 4),
        targetAddress: target.canonicalAddress,
      ),
      time: TimelineTime.fromSecondsDouble(2),
    );

    expect(sample.status, MotionEvaluationStatus.resolved);
    expect(sample.value.rawValue, closeTo(0.5, 0.000001));
  });

  test('cubic bezier interpolation eases slower than linear near the start',
      () {
    final first = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: const <MotionPropertyChannelModel>[],
        target: target,
        activeRange: range(0, 4),
        definition: MotionPropertyCatalog.opacity,
        time: TimelineTime.fromSecondsDouble(0),
        value: const MotionPropertyValue.scalar(0),
        interpolation: const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.3333,
            y1: 0.0,
            x2: 0.6667,
            y2: 1.0,
          ),
        ),
      ),
    );
    final second = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: first.channels,
        target: target,
        activeRange: range(0, 4),
        definition: MotionPropertyCatalog.opacity,
        time: TimelineTime.fromSecondsDouble(4),
        value: const MotionPropertyValue.scalar(1),
      ),
    );
    final channel = second.channels.single;
    final sample = const BasicMotionPropertyChannelSampler().sample(
      channel: MotionResolvedPropertyChannel(
        channel: channel,
        projectRange: range(0, 4),
        targetAddress: target.canonicalAddress,
      ),
      time: TimelineTime.fromSecondsDouble(1),
    );

    expect(sample.status, MotionEvaluationStatus.resolved);
    expect(sample.value.rawValue as double, lessThan(0.25));
  });
}
