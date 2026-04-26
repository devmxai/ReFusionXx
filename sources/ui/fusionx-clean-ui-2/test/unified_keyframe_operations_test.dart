import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/unified_keyframe_operations.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const operations = UnifiedKeyframeOperations();
  const target = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'element-1',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'layer',
    elementId: 'element-1',
  );

  TimelineTime at(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: at(start),
      endExclusive: at(end),
    );
  }

  UnifiedKeyframeOperationResult addScalar({
    required List<MotionPropertyChannelModel> channels,
    required MotionPropertyDefinition definition,
    required double time,
    required double value,
  }) {
    return operations.addKeyframe(
      UnifiedKeyframeAddRequest(
        channels: channels,
        target: target,
        activeRange: range(0, 5),
        definition: definition,
        time: at(time),
        value: MotionPropertyValue.scalar(value),
      ),
    );
  }

  test('adds keyframes as stable identities and keeps them sorted', () {
    final first = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.opacity,
      time: 3,
      value: 0.3,
    );
    final second = addScalar(
      channels: first.channels,
      definition: MotionPropertyCatalog.opacity,
      time: 1,
      value: 0.1,
    );

    expect(second.hasIssues, isFalse);
    final keyframes = second.channels.single.keyframes;
    expect(keyframes.map((keyframe) => keyframe.time), <TimelineTime>[
      at(1),
      at(3),
    ]);
    expect(keyframes.map((keyframe) => keyframe.id).toSet(), hasLength(2));
    expect(second.selectedKeyframeIds, <String>{keyframes.first.id});
  });

  test('moving a keyframe across another keyframe preserves identity', () {
    final first = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.positionX,
      time: 1,
      value: 10,
    );
    final second = addScalar(
      channels: first.channels,
      definition: MotionPropertyCatalog.positionX,
      time: 3,
      value: 30,
    );
    final channel = second.channels.single;
    final movedKeyframe = channel.keyframes.last;

    final moved = operations.moveKeyframe(
      UnifiedKeyframeMoveRequest(
        channels: second.channels,
        channelId: channel.id,
        keyframeId: movedKeyframe.id,
        time: at(0.5),
        activeRange: range(0, 5),
      ),
    );

    expect(moved.hasIssues, isFalse);
    final keyframes = moved.channels.single.keyframes;
    expect(keyframes.first.id, movedKeyframe.id);
    expect(keyframes.first.time, at(0.5));
    expect(keyframes.first.value.rawValue, 30);
    expect(moved.selectedKeyframeIds, <String>{movedKeyframe.id});
  });

  test('moving onto another keyframe is rejected without dropping data', () {
    final first = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.positionX,
      time: 1,
      value: 10,
    );
    final second = addScalar(
      channels: first.channels,
      definition: MotionPropertyCatalog.positionX,
      time: 3,
      value: 30,
    );
    final channel = second.channels.single;
    final movedKeyframe = channel.keyframes.last;

    final moved = operations.moveKeyframe(
      UnifiedKeyframeMoveRequest(
        channels: second.channels,
        channelId: channel.id,
        keyframeId: movedKeyframe.id,
        time: at(1),
        activeRange: range(0, 5),
      ),
    );

    expect(moved.hasIssues, isTrue);
    expect(
      moved.issues.single.code,
      UnifiedKeyframeIssueCode.keyframeTimeCollision,
    );
    expect(moved.channels.single.keyframes, hasLength(2));
    expect(moved.channels.single.keyframes.last.id, movedKeyframe.id);
    expect(moved.channels.single.keyframes.last.time, at(3));
  });

  test('updates an existing keyframe at the same time without changing id', () {
    final initial = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.opacity,
      time: 2,
      value: 0.2,
    );
    final originalKeyframe = initial.channels.single.keyframes.single;

    final updated = addScalar(
      channels: initial.channels,
      definition: MotionPropertyCatalog.opacity,
      time: 2,
      value: 0.8,
    );

    expect(updated.hasIssues, isFalse);
    expect(updated.channels.single.keyframes, hasLength(1));
    expect(updated.channels.single.keyframes.single.id, originalKeyframe.id);
    expect(updated.channels.single.keyframes.single.value.rawValue, 0.8);
  });

  test('moves grouped position keyframes together to the playhead', () {
    final x = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.positionX,
      time: 1,
      value: 100,
    );
    final y = addScalar(
      channels: x.channels,
      definition: MotionPropertyCatalog.positionY,
      time: 1,
      value: 200,
    );
    final xKeyframe = y.channels
        .singleWhere(
          (channel) =>
              channel.definition.id == MotionPropertyCatalog.positionX.id,
        )
        .keyframes
        .single;
    final yKeyframe = y.channels
        .singleWhere(
          (channel) =>
              channel.definition.id == MotionPropertyCatalog.positionY.id,
        )
        .keyframes
        .single;

    final moved = operations.moveSelectedKeyframesToTime(
      UnifiedKeyframeMoveSelectionRequest(
        channels: y.channels,
        keyframeIds: <String>{xKeyframe.id, yKeyframe.id},
        anchorKeyframeId: xKeyframe.id,
        anchorTargetTime: at(2.5),
        activeRange: range(0, 5),
      ),
    );

    expect(moved.hasIssues, isFalse);
    for (final channel in moved.channels) {
      expect(channel.keyframes.single.time, at(2.5));
    }
    expect(moved.selectedKeyframeIds, <String>{xKeyframe.id, yKeyframe.id});
  });

  test('set value, interpolation, delete, and select target stable ids', () {
    final initial = addScalar(
      channels: const <MotionPropertyChannelModel>[],
      definition: MotionPropertyCatalog.opacity,
      time: 1,
      value: 0.2,
    );
    final channel = initial.channels.single;
    final keyframe = channel.keyframes.single;

    final valueChanged = operations.setKeyframeValue(
      UnifiedKeyframeValueRequest(
        channels: initial.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
        value: const MotionPropertyValue.scalar(0.9),
      ),
    );
    final interpolationChanged = operations.setKeyframeInterpolation(
      UnifiedKeyframeInterpolationRequest(
        channels: valueChanged.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
        interpolation: const MotionInterpolationSpec.easeInOut(),
      ),
    );
    final selection = operations.selectKeyframe(
      channels: interpolationChanged.channels,
      keyframeId: keyframe.id,
    );
    final deleted = operations.deleteKeyframe(
      UnifiedKeyframeDeleteRequest(
        channels: interpolationChanged.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
      ),
    );

    expect(valueChanged.channels.single.keyframes.single.id, keyframe.id);
    expect(valueChanged.channels.single.keyframes.single.value.rawValue, 0.9);
    expect(
      interpolationChanged
          .channels.single.keyframes.single.interpolationToNext.kind,
      MotionInterpolationKind.easeInOut,
    );
    expect(selection.selectedKeyframeIds, <String>{keyframe.id});
    expect(deleted.channels.single.keyframes, isEmpty);
  });
}
