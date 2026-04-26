import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/layer_scope_motion_projection_adapter.dart';

void main() {
  const adapter = LayerScopeMotionProjectionAdapter();

  TimelineTime time(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(start: time(start), endExclusive: time(end));
  }

  MotionPropertyTarget elementTarget(String elementId) {
    return MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: elementId,
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'layer',
      elementId: elementId,
    );
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

  MotionPropertyChannelModel scalarChannel({
    required String id,
    required String elementId,
    required MotionPropertyDefinition definition,
    required List<MotionKeyframeModel> keyframes,
    TimelineTimeRange? activeRange,
  }) {
    return MotionPropertyChannelModel(
      id: id,
      target: elementTarget(elementId),
      definition: definition,
      activeRange: activeRange,
      keyframes: keyframes,
    );
  }

  test('projects only opacity for the selected layer scope element by default',
      () {
    final opacity = scalarChannel(
      id: 'title-opacity',
      elementId: 'title',
      definition: MotionPropertyCatalog.opacity,
      activeRange: range(0.5, 2),
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'opacity-in',
          channelId: 'title-opacity',
          seconds: 0.5,
          value: 0,
        ),
        scalarKeyframe(
          id: 'opacity-full',
          channelId: 'title-opacity',
          seconds: 1.5,
          value: 1,
        ),
      ],
    );
    final scale = scalarChannel(
      id: 'title-scale-x',
      elementId: 'title',
      definition: MotionPropertyCatalog.scaleX,
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'scale-start',
          channelId: 'title-scale-x',
          seconds: 1,
          value: 1.2,
        ),
      ],
    );
    final otherOpacity = scalarChannel(
      id: 'subtitle-opacity',
      elementId: 'subtitle',
      definition: MotionPropertyCatalog.opacity,
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'subtitle-in',
          channelId: 'subtitle-opacity',
          seconds: 1,
          value: 0.5,
        ),
      ],
    );

    final result = adapter.projectElement(
      channels: <MotionPropertyChannelModel>[opacity, scale, otherOpacity],
      elementId: 'title',
      targetClipId: 'clip-title',
      window: range(0, 2),
    );

    expect(result.hasIssues, isFalse);
    expect(result.lanes, hasLength(1));
    final lane = result.lanes.single;
    expect(lane.id, 'title-opacity');
    expect(lane.label, 'Opacity');
    expect(lane.targetClipId, 'clip-title');
    expect(lane.keyframeIds, <String>['opacity-in', 'opacity-full']);
    expect(lane.normalizedKeyframeStops, <double>[0.25, 0.75]);
    expect(lane.keyframeValues, <double>[0, 100]);
    expect(lane.trackSpanStartProgress, 0.25);
    expect(lane.trackSpanEndProgress, 1);
  });

  test('can opt into additional element property families without UI rewrites',
      () {
    final opacity = scalarChannel(
      id: 'title-opacity',
      elementId: 'title',
      definition: MotionPropertyCatalog.opacity,
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'opacity-full',
          channelId: 'title-opacity',
          seconds: 0,
          value: 1,
        ),
      ],
    );
    final scaleX = scalarChannel(
      id: 'title-scale-x',
      elementId: 'title',
      definition: MotionPropertyCatalog.scaleX,
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'scale-x-start',
          channelId: 'title-scale-x',
          seconds: 1,
          value: 1.5,
        ),
      ],
    );
    final scaleY = scalarChannel(
      id: 'title-scale-y',
      elementId: 'title',
      definition: MotionPropertyCatalog.scaleY,
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'scale-y-start',
          channelId: 'title-scale-y',
          seconds: 1,
          value: 0.8,
        ),
      ],
    );

    final result = adapter.projectElement(
      channels: <MotionPropertyChannelModel>[opacity, scaleX, scaleY],
      elementId: 'title',
      targetClipId: 'clip-title',
      window: range(0, 2),
      propertyIds: const <String>{
        'visual.opacity',
        'transform.scale.x',
        'transform.scale.y',
      },
    );

    expect(result.hasIssues, isFalse);
    expect(
      result.lanes.map((lane) => lane.label),
      <String>['Opacity', 'Scale X', 'Scale Y'],
    );
    expect(result.lanes[1].keyframeValues, <double>[150]);
    expect(result.lanes[2].keyframeValues, <double>[80]);
  });

  test('reports unsupported selected properties without blocking valid lanes',
      () {
    final opacity = scalarChannel(
      id: 'title-opacity',
      elementId: 'title',
      definition: MotionPropertyCatalog.opacity,
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'opacity-full',
          channelId: 'title-opacity',
          seconds: 1,
          value: 1,
        ),
      ],
    );
    final crop = MotionPropertyChannelModel(
      id: 'title-crop',
      target: elementTarget('title'),
      definition: MotionPropertyCatalog.cropRect,
    );

    final result = adapter.projectElement(
      channels: <MotionPropertyChannelModel>[opacity, crop],
      elementId: 'title',
      targetClipId: 'clip-title',
      window: range(0, 2),
      propertyIds: const <String>{
        'visual.opacity',
        'crop.rect',
      },
    );

    expect(result.lanes.map((lane) => lane.id), <String>['title-opacity']);
    expect(result.hasIssues, isTrue);
    expect(result.issues.single.channelId, 'title-crop');
    expect(result.issues.single.targetId, 'title');
    expect(
      result.issues.single.code,
      LayerScopeMotionProjectionIssueCode.projectionIssue,
    );
  });

  test('returns an empty projection for unmatched elements', () {
    final opacity = scalarChannel(
      id: 'subtitle-opacity',
      elementId: 'subtitle',
      definition: MotionPropertyCatalog.opacity,
      keyframes: <MotionKeyframeModel>[
        scalarKeyframe(
          id: 'subtitle-in',
          channelId: 'subtitle-opacity',
          seconds: 1,
          value: 0.5,
        ),
      ],
    );

    final result = adapter.projectElement(
      channels: <MotionPropertyChannelModel>[opacity],
      elementId: 'title',
      targetClipId: 'clip-title',
      window: range(0, 2),
    );

    expect(result.lanes, isEmpty);
    expect(result.hasIssues, isFalse);
  });
}
