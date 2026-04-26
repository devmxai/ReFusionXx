import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_canvas_timeline_authoring_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/unified_keyframe_operations.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const service = UnifiedKeyframeOperationService();
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

  CanvasTimelineAuthoringResult addScalar({
    required List<MotionPropertyChannelModel> channels,
    required MotionPropertyDefinition definition,
    required double time,
    required double value,
  }) {
    return service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: channels,
        target: target,
        activeRange: range(0, 5),
        definition: definition,
        time: TimelineTime.fromSecondsDouble(time),
        value: MotionPropertyValue.scalar(value),
      ),
    );
  }

  test('moves a compound position keyframe group by stable identity', () {
    final xInitial = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.positionX,
      time: 1,
      value: 10,
    );
    final yInitial = addScalar(
      channels: xInitial.channels,
      definition: MotionPropertyCatalog.positionY,
      time: 1,
      value: 20,
    );
    final xChannel = yInitial.channels.firstWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.positionX.id,
    );
    final yChannel = yInitial.channels.firstWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.positionY.id,
    );
    final xKeyframe = xChannel.keyframes.single;
    final yKeyframe = yChannel.keyframes.single;

    final moved = service.moveKeyframeGroup(
      UnifiedKeyframeGroupMoveRequest(
        channels: yInitial.channels,
        keyframes: <UnifiedKeyframeReference>[
          UnifiedKeyframeReference(
            channelId: xChannel.id,
            keyframeId: xKeyframe.id,
          ),
          UnifiedKeyframeReference(
            channelId: yChannel.id,
            keyframeId: yKeyframe.id,
          ),
        ],
        activeRange: range(0, 5),
        time: TimelineTime.fromSecondsDouble(2.5),
      ),
    );

    expect(moved.hasIssues, isFalse);
    final movedX = moved.channels.firstWhere(
      (channel) => channel.id == xChannel.id,
    );
    final movedY = moved.channels.firstWhere(
      (channel) => channel.id == yChannel.id,
    );

    expect(movedX.keyframes.single.id, xKeyframe.id);
    expect(movedY.keyframes.single.id, yKeyframe.id);
    expect(
      movedX.keyframes.single.time,
      TimelineTime.fromSecondsDouble(2.5),
    );
    expect(
      movedY.keyframes.single.time,
      TimelineTime.fromSecondsDouble(2.5),
    );
  });

  test('rejects compound moves atomically when one channel collides', () {
    final xStart = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.positionX,
      time: 1,
      value: 10,
    );
    final xWithCollision = addScalar(
      channels: xStart.channels,
      definition: MotionPropertyCatalog.positionX,
      time: 2,
      value: 99,
    );
    final yStart = addScalar(
      channels: xWithCollision.channels,
      definition: MotionPropertyCatalog.positionY,
      time: 1,
      value: 20,
    );
    final xChannel = yStart.channels.firstWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.positionX.id,
    );
    final yChannel = yStart.channels.firstWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.positionY.id,
    );
    final selectedX = xChannel.keyframes.first;
    final selectedY = yChannel.keyframes.single;

    final moved = service.moveKeyframeGroup(
      UnifiedKeyframeGroupMoveRequest(
        channels: yStart.channels,
        keyframes: <UnifiedKeyframeReference>[
          UnifiedKeyframeReference(
            channelId: xChannel.id,
            keyframeId: selectedX.id,
          ),
          UnifiedKeyframeReference(
            channelId: yChannel.id,
            keyframeId: selectedY.id,
          ),
        ],
        activeRange: range(0, 5),
        time: TimelineTime.fromSecondsDouble(2),
      ),
    );

    expect(moved.hasIssues, isTrue);
    expect(
      moved.issues.single.code,
      CanvasTimelineAuthoringIssueCode.keyframeTimeCollision,
    );
    final originalX = moved.channels.firstWhere(
      (channel) => channel.id == xChannel.id,
    );
    final originalY = moved.channels.firstWhere(
      (channel) => channel.id == yChannel.id,
    );

    expect(originalX.keyframes.map((keyframe) => keyframe.time.inMilliseconds),
        <int>[1000, 2000]);
    expect(originalY.keyframes.single.time.inMilliseconds, 1000);
  });

  test('routes value and interpolation edits through the shared service', () {
    final initial = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.opacity,
      time: 1,
      value: 0.2,
    );
    final channel = initial.channels.single;
    final keyframe = channel.keyframes.single;

    final valued = service.setKeyframeValue(
      CanvasTimelineKeyframeValueRequest(
        channels: initial.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
        value: const MotionPropertyValue.scalar(0.8),
      ),
    );
    final eased = service.setKeyframeInterpolation(
      CanvasTimelineKeyframeInterpolationRequest(
        channels: valued.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
        interpolation: const MotionInterpolationSpec.spring(),
      ),
    );

    expect(eased.hasIssues, isFalse);
    final updated = eased.channels.single.keyframes.single;
    expect(updated.id, keyframe.id);
    expect(updated.value.rawValue, 0.8);
    expect(
      updated.interpolationToNext.kind,
      MotionInterpolationKind.spring,
    );
  });
}
