import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/composition_timeline_projection.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_scope_timeline_projection_adapter.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const adapter = UnifiedScopeTimelineProjectionAdapter();

  TimelineTime at(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: at(start),
      endExclusive: at(end),
    );
  }

  const target = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'title-element',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'title-layer',
    elementId: 'title-element',
  );

  ScopeProjection projection({
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final element = MotionElementModel(
      id: 'title-element',
      layerId: 'title-layer',
      kind: MotionElementKind.text,
      localRange: range(0, 8),
    );
    final layer = MotionLayerModel(
      id: 'title-layer',
      sceneId: 'scene',
      kind: MotionLayerKind.text,
      visibleRange: range(4, 12),
      elements: <MotionElementModel>[element],
    );
    return ScopeProjection(
      id: 'scope.layer.scene.title-layer',
      mode: CompositionScopeMode.layer,
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'title-layer',
      globalRange: range(4, 12),
      localRange: range(0, 8),
      globalTime: at(6),
      localTime: at(2),
      layers: <MotionLayerModel>[layer],
      elements: <MotionElementModel>[element],
      channels: channels,
    );
  }

  MotionPropertyChannelModel channel({
    required String id,
    required MotionPropertyDefinition definition,
    required List<MotionKeyframeModel> keyframes,
    TimelineTimeRange? activeRange,
  }) {
    return MotionPropertyChannelModel(
      id: id,
      target: target,
      definition: definition,
      activeRange: activeRange,
      keyframes: keyframes,
    );
  }

  MotionKeyframeModel keyframe({
    required String id,
    required String channelId,
    required double time,
    required MotionPropertyValue value,
  }) {
    return MotionKeyframeModel(
      id: id,
      channelId: channelId,
      time: at(time),
      value: value,
      interpolationToNext: const MotionInterpolationSpec.linear(),
    );
  }

  test('projects graph channels into timeline animation lanes', () {
    final opacity = channel(
      id: 'opacity-channel',
      definition: MotionPropertyCatalog.opacity,
      activeRange: range(1, 5),
      keyframes: <MotionKeyframeModel>[
        keyframe(
          id: 'opacity.k0',
          channelId: 'opacity-channel',
          time: 1,
          value: const MotionPropertyValue.scalar(0.25),
        ),
        keyframe(
          id: 'opacity.k1',
          channelId: 'opacity-channel',
          time: 5,
          value: const MotionPropertyValue.scalar(1),
        ),
      ],
    );

    final lanes = adapter.animationLanesForScope(
      projection(channels: <MotionPropertyChannelModel>[opacity]),
      targetClipId: 'title-clip',
    );

    expect(lanes, hasLength(1));
    final lane = lanes.single;
    expect(lane.id, 'opacity-channel');
    expect(lane.label, 'Opacity');
    expect(lane.targetClipId, 'title-clip');
    expect(lane.normalizedKeyframeStops, <double>[0.125, 0.625]);
    expect(lane.keyframeIds, <String>['opacity.k0', 'opacity.k1']);
    expect(lane.keyframeValues, <double>[0.25, 1]);
    expect(lane.trackSpanStartProgress, 0.125);
    expect(lane.trackSpanEndProgress, 0.625);
  });

  test('keeps stable ids and sorts lanes by label', () {
    final blur = channel(
      id: 'blur-channel',
      definition: MotionPropertyCatalog.blurAmount,
      keyframes: <MotionKeyframeModel>[
        keyframe(
          id: 'blur.k0',
          channelId: 'blur-channel',
          time: 4,
          value: const MotionPropertyValue.scalar(12.5),
        ),
      ],
    );
    final opacity = channel(
      id: 'opacity-channel',
      definition: MotionPropertyCatalog.opacity,
      keyframes: <MotionKeyframeModel>[
        keyframe(
          id: 'opacity.k0',
          channelId: 'opacity-channel',
          time: 2,
          value: const MotionPropertyValue.scalar(0.5),
        ),
      ],
    );

    final lanes = adapter.animationLanesForScope(
      projection(channels: <MotionPropertyChannelModel>[opacity, blur]),
    );

    expect(
      lanes.map((lane) => lane.label),
      <String>['Blur Amount', 'Opacity'],
    );
    expect(
      lanes.map((lane) => lane.keyframeIds.single),
      <String>['blur.k0', 'opacity.k0'],
    );
  });

  test('skips channels that cannot be represented as numeric lanes', () {
    final colorDefinition = MotionPropertyDefinition(
      id: 'shape.fill.color',
      path: const MotionPropertyPath(
        group: MotionPropertyGroup.shape,
        name: 'fillColor',
      ),
      valueKind: MotionPropertyValueKind.colorArgb,
      supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
      defaultValue: const MotionPropertyValue.colorArgb(0xffffffff),
    );
    final color = channel(
      id: 'color-channel',
      definition: colorDefinition,
      keyframes: <MotionKeyframeModel>[
        keyframe(
          id: 'color.k0',
          channelId: 'color-channel',
          time: 1,
          value: const MotionPropertyValue.colorArgb(0xff00ff00),
        ),
      ],
    );

    final lanes = adapter.animationLanesForScope(
      projection(channels: <MotionPropertyChannelModel>[color]),
    );

    expect(lanes, isEmpty);
  });
}
