import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_canvas_timeline_authoring_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/layer_scope_composition_adapter.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const adapter = LayerScopeCompositionAdapter();

  TimelineTime at(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: at(start),
      endExclusive: at(end),
    );
  }

  MotionProjectModel project() {
    final title = MotionElementModel(
      id: 'title-element',
      layerId: 'title-layer',
      kind: MotionElementKind.text,
      localRange: range(0, 6),
    );
    final image = MotionElementModel(
      id: 'image-element',
      layerId: 'image-layer',
      kind: MotionElementKind.image,
      localRange: range(0, 8),
    );

    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 60, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: range(0, 20),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'title-layer',
              sceneId: 'scene',
              kind: MotionLayerKind.text,
              visibleRange: range(4, 10),
              elements: <MotionElementModel>[title],
            ),
            MotionLayerModel(
              id: 'image-layer',
              sceneId: 'scene',
              kind: MotionLayerKind.image,
              visibleRange: range(8, 16),
              elements: <MotionElementModel>[image],
            ),
          ],
        ),
      ],
    );
  }

  const titleTarget = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'title-element',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'title-layer',
    elementId: 'title-element',
  );

  const imageTarget = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'image-element',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'image-layer',
    elementId: 'image-element',
  );

  test('resolves current layer scope as a composition projection', () {
    final result = adapter.resolveScope(
      project: project(),
      sceneId: 'scene',
      layerId: 'title-layer',
      globalTime: at(6.25),
    );

    expect(result.hasIssues, isFalse);
    final scope = result.projection!;
    expect(scope.id, 'scope.layer.scene.title-layer');
    expect(scope.globalRange.start, at(4));
    expect(scope.localRange.endExclusive, at(6));
    expect(scope.globalTime, at(6.25));
    expect(scope.localTime, at(2.25));
    expect(scope.layers.single.id, 'title-layer');
    expect(scope.elements.single.id, 'title-element');
  });

  test('adds and edits layer scope keyframes through unified operations', () {
    final scope = adapter
        .resolveScope(
          project: project(),
          sceneId: 'scene',
          layerId: 'title-layer',
          globalTime: at(6),
        )
        .projection!;

    final first = adapter.addKeyframe(
      LayerScopeCompositionKeyframeRequest(
        projection: scope,
        channels: const <MotionPropertyChannelModel>[],
        target: titleTarget,
        definition: MotionPropertyCatalog.opacity,
        localTime: at(1),
        value: const MotionPropertyValue.scalar(0),
      ),
    );
    final second = adapter.addKeyframe(
      LayerScopeCompositionKeyframeRequest(
        projection: scope,
        channels: first.channels,
        target: titleTarget,
        definition: MotionPropertyCatalog.opacity,
        localTime: at(4),
        value: const MotionPropertyValue.scalar(1),
        interpolation: const MotionInterpolationSpec.easeInOut(),
      ),
    );

    expect(second.hasIssues, isFalse);
    var channel = second.channels.single;
    expect(channel.id, startsWith('canvasTimeline.'));
    expect(
      channel.keyframes.map((keyframe) => keyframe.time),
      <TimelineTime>[at(1), at(4)],
    );
    expect(channel.keyframes.last.value.rawValue, 1);

    final moved = adapter.moveKeyframe(
      LayerScopeCompositionMoveKeyframeRequest(
        projection: scope,
        channels: second.channels,
        channelId: channel.id,
        keyframeId: channel.keyframes.last.id,
        localTime: at(2),
      ),
    );
    channel = moved.channels.single;
    expect(channel.keyframes.last.time, at(2));

    final valued = adapter.setKeyframeValue(
      LayerScopeCompositionKeyframeValueRequest(
        channels: moved.channels,
        channelId: channel.id,
        keyframeId: channel.keyframes.last.id,
        value: const MotionPropertyValue.scalar(0.75),
      ),
    );
    channel = valued.channels.single;
    expect(channel.keyframes.last.value.rawValue, 0.75);

    final interpolated = adapter.setKeyframeInterpolation(
      LayerScopeCompositionKeyframeInterpolationRequest(
        channels: valued.channels,
        channelId: channel.id,
        keyframeId: channel.keyframes.first.id,
        interpolation: const MotionInterpolationSpec.easeOut(),
      ),
    );
    channel = interpolated.channels.single;
    expect(
      channel.keyframes.first.interpolationToNext.kind,
      MotionInterpolationKind.easeOut,
    );

    final deleted = adapter.deleteKeyframe(
      LayerScopeCompositionDeleteKeyframeRequest(
        channels: interpolated.channels,
        channelId: channel.id,
        keyframeId: channel.keyframes.first.id,
      ),
    );
    expect(deleted.channels.single.keyframes, hasLength(1));
  });

  test('rejects keyframes for targets outside the active layer scope', () {
    final scope = adapter
        .resolveScope(
          project: project(),
          sceneId: 'scene',
          layerId: 'title-layer',
          globalTime: at(6),
        )
        .projection!;

    final result = adapter.addKeyframe(
      LayerScopeCompositionKeyframeRequest(
        projection: scope,
        channels: const <MotionPropertyChannelModel>[],
        target: imageTarget,
        definition: MotionPropertyCatalog.opacity,
        localTime: at(1),
        value: const MotionPropertyValue.scalar(1),
      ),
    );

    expect(result.hasIssues, isTrue);
    expect(
      result.issues.single.code,
      CanvasTimelineAuthoringIssueCode.unsupportedTarget,
    );
    expect(result.channels, isEmpty);
  });
}
