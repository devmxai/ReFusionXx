import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_canvas_timeline_authoring_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/canvas_timeline_unified_keyframe_adapter.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const legacyService = ProfessionalCanvasTimelineAuthoringService();
  final adapter = CanvasTimelineUnifiedKeyframeAdapter();
  const target = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'text-1',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'layer',
    elementId: 'text-1',
  );

  TimelineTime at(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: at(start),
      endExclusive: at(end),
    );
  }

  CanvasTimelineKeyframeRequest addRequest({
    required List<MotionPropertyChannelModel> channels,
    required MotionPropertyDefinition definition,
    required double time,
    required double value,
  }) {
    return CanvasTimelineKeyframeRequest(
      channels: channels,
      target: target,
      activeRange: range(0, 5),
      definition: definition,
      time: at(time),
      value: MotionPropertyValue.scalar(value),
      interpolation: const MotionInterpolationSpec.easeInOut(),
    );
  }

  test('adapter preserves canvas channel and keyframe id contract', () {
    final result = adapter.addKeyframe(
      addRequest(
        channels: const <MotionPropertyChannelModel>[],
        definition: MotionPropertyCatalog.opacity,
        time: 1,
        value: 0.5,
      ),
    );

    expect(result.hasIssues, isFalse);
    final channel = result.channels.single;
    final keyframe = channel.keyframes.single;
    expect(channel.id, startsWith('canvasTimeline.'));
    expect(channel.id, contains(MotionPropertyCatalog.opacity.id));
    expect(keyframe.id, '${channel.id}.${at(1).inProjectTicks}');
  });

  test('adapter add/move/value/interpolation/delete matches canvas behavior',
      () {
    final legacyFirst = legacyService.addKeyframe(
      addRequest(
        channels: const <MotionPropertyChannelModel>[],
        definition: MotionPropertyCatalog.positionX,
        time: 1,
        value: 10,
      ),
    );
    final adapterFirst = adapter.addKeyframe(
      addRequest(
        channels: const <MotionPropertyChannelModel>[],
        definition: MotionPropertyCatalog.positionX,
        time: 1,
        value: 10,
      ),
    );
    final legacySecond = legacyService.addKeyframe(
      addRequest(
        channels: legacyFirst.channels,
        definition: MotionPropertyCatalog.positionX,
        time: 3,
        value: 30,
      ),
    );
    final adapterSecond = adapter.addKeyframe(
      addRequest(
        channels: adapterFirst.channels,
        definition: MotionPropertyCatalog.positionX,
        time: 3,
        value: 30,
      ),
    );

    expect(
        _signature(adapterSecond.channels), _signature(legacySecond.channels));

    final channel = adapterSecond.channels.single;
    final keyframe = channel.keyframes.last;
    final legacyMoved = legacyService.moveKeyframe(
      CanvasTimelineMoveKeyframeRequest(
        channels: legacySecond.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
        activeRange: range(0, 5),
        time: at(0.5),
      ),
    );
    final adapterMoved = adapter.moveKeyframe(
      CanvasTimelineMoveKeyframeRequest(
        channels: adapterSecond.channels,
        channelId: channel.id,
        keyframeId: keyframe.id,
        activeRange: range(0, 5),
        time: at(0.5),
      ),
    );

    expect(_signature(adapterMoved.channels), _signature(legacyMoved.channels));

    final movedChannel = adapterMoved.channels.single;
    final movedKeyframe = movedChannel.keyframes.first;
    final legacyValue = legacyService.setKeyframeValue(
      CanvasTimelineKeyframeValueRequest(
        channels: legacyMoved.channels,
        channelId: movedChannel.id,
        keyframeId: movedKeyframe.id,
        value: const MotionPropertyValue.scalar(42),
      ),
    );
    final adapterValue = adapter.setKeyframeValue(
      CanvasTimelineKeyframeValueRequest(
        channels: adapterMoved.channels,
        channelId: movedChannel.id,
        keyframeId: movedKeyframe.id,
        value: const MotionPropertyValue.scalar(42),
      ),
    );

    expect(_signature(adapterValue.channels), _signature(legacyValue.channels));

    final legacyInterpolation = legacyService.setKeyframeInterpolation(
      CanvasTimelineKeyframeInterpolationRequest(
        channels: legacyValue.channels,
        channelId: movedChannel.id,
        keyframeId: movedKeyframe.id,
        interpolation: const MotionInterpolationSpec.easeOut(),
      ),
    );
    final adapterInterpolation = adapter.setKeyframeInterpolation(
      CanvasTimelineKeyframeInterpolationRequest(
        channels: adapterValue.channels,
        channelId: movedChannel.id,
        keyframeId: movedKeyframe.id,
        interpolation: const MotionInterpolationSpec.easeOut(),
      ),
    );

    expect(
      _signature(adapterInterpolation.channels),
      _signature(legacyInterpolation.channels),
    );

    final legacyDeleted = legacyService.deleteKeyframe(
      CanvasTimelineDeleteKeyframeRequest(
        channels: legacyInterpolation.channels,
        channelId: movedChannel.id,
        keyframeId: movedKeyframe.id,
      ),
    );
    final adapterDeleted = adapter.deleteKeyframe(
      CanvasTimelineDeleteKeyframeRequest(
        channels: adapterInterpolation.channels,
        channelId: movedChannel.id,
        keyframeId: movedKeyframe.id,
      ),
    );

    expect(_signature(adapterDeleted.channels),
        _signature(legacyDeleted.channels));
  });

  test('adapter rejects collisions without changing existing keyframes', () {
    final first = adapter.addKeyframe(
      addRequest(
        channels: const <MotionPropertyChannelModel>[],
        definition: MotionPropertyCatalog.positionX,
        time: 1,
        value: 10,
      ),
    );
    final second = adapter.addKeyframe(
      addRequest(
        channels: first.channels,
        definition: MotionPropertyCatalog.positionX,
        time: 3,
        value: 30,
      ),
    );
    final channel = second.channels.single;
    final movedKeyframe = channel.keyframes.last;

    final moved = adapter.moveKeyframe(
      CanvasTimelineMoveKeyframeRequest(
        channels: second.channels,
        channelId: channel.id,
        keyframeId: movedKeyframe.id,
        activeRange: range(0, 5),
        time: at(1),
      ),
    );

    expect(moved.hasIssues, isTrue);
    expect(
      moved.issues.single.code,
      CanvasTimelineAuthoringIssueCode.keyframeTimeCollision,
    );
    expect(_signature(moved.channels), _signature(second.channels));
  });
}

List<Map<String, Object?>> _signature(
  List<MotionPropertyChannelModel> channels,
) {
  return channels.map((channel) {
    return <String, Object?>{
      'id': channel.id,
      'target': channel.target.canonicalAddress,
      'definition': channel.definition.id,
      'base': channel.baseValue?.rawValue,
      'keyframes': channel.keyframes.map((keyframe) {
        return <String, Object?>{
          'id': keyframe.id,
          'time': keyframe.time.inProjectTicks,
          'value': keyframe.value.rawValue,
          'interpolation': keyframe.interpolationToNext.kind.name,
        };
      }).toList(growable: false),
    };
  }).toList(growable: false);
}
