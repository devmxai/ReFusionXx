import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/composition_timeline_projection.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const resolver = CompositionTimelineProjectionResolver();

  TimelineTime at(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(
      start: at(start),
      endExclusive: at(end),
    );
  }

  MotionPropertyTarget elementTarget({
    required String sceneId,
    required String layerId,
    required String elementId,
  }) {
    return MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: elementId,
      projectId: 'project',
      sceneId: sceneId,
      layerId: layerId,
      elementId: elementId,
    );
  }

  MotionPropertyChannelModel channel({
    required String id,
    required MotionPropertyTarget target,
    MotionPropertyDefinition? definition,
  }) {
    final safeDefinition = definition ?? MotionPropertyCatalog.opacity;
    return MotionPropertyChannelModel(
      id: id,
      target: target,
      definition: safeDefinition,
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: '$id.k0',
          channelId: id,
          time: at(1),
          value: safeDefinition.defaultValue,
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  MotionProjectModel project() {
    final textElement = MotionElementModel(
      id: 'text-element',
      layerId: 'text-layer',
      kind: MotionElementKind.text,
      localRange: range(0, 8),
      name: 'Title',
    );
    final imageElement = MotionElementModel(
      id: 'image-element',
      layerId: 'image-layer',
      kind: MotionElementKind.image,
      localRange: range(0, 7),
      name: 'Image',
    );
    final disabledElement = MotionElementModel(
      id: 'disabled-element',
      layerId: 'disabled-layer',
      kind: MotionElementKind.shape,
      localRange: range(0, 4),
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
              id: 'image-layer',
              sceneId: 'scene',
              kind: MotionLayerKind.image,
              visibleRange: range(9, 16),
              zIndex: 2,
              elements: <MotionElementModel>[imageElement],
            ),
            MotionLayerModel(
              id: 'text-layer',
              sceneId: 'scene',
              kind: MotionLayerKind.text,
              visibleRange: range(5, 13),
              zIndex: 1,
              elements: <MotionElementModel>[textElement],
            ),
            MotionLayerModel(
              id: 'disabled-layer',
              sceneId: 'scene',
              kind: MotionLayerKind.shape,
              visibleRange: range(2, 6),
              zIndex: 0,
              isEnabled: false,
              elements: <MotionElementModel>[disabledElement],
            ),
          ],
        ),
      ],
    );
  }

  test('composition projection keeps global time as canonical truth', () {
    final result = resolver.resolveComposition(
      project: project(),
      sceneId: 'scene',
      globalTime: at(10),
      channels: <MotionPropertyChannelModel>[
        channel(
          id: 'text.opacity',
          target: elementTarget(
            sceneId: 'scene',
            layerId: 'text-layer',
            elementId: 'text-element',
          ),
        ),
      ],
    );

    expect(result.hasIssues, isFalse);
    final projection = result.projection!;
    expect(projection.projectId, 'project');
    expect(projection.sceneId, 'scene');
    expect(projection.globalTime, at(10));
    expect(projection.duration, at(20));
    expect(
      projection.layers.map((layer) => layer.id),
      <String>['text-layer', 'image-layer'],
    );
    expect(projection.channels.single.id, 'text.opacity');
  });

  test('layer scope derives local time and filters target channels', () {
    final textChannel = channel(
      id: 'text.opacity',
      target: elementTarget(
        sceneId: 'scene',
        layerId: 'text-layer',
        elementId: 'text-element',
      ),
    );
    final imageChannel = channel(
      id: 'image.opacity',
      target: elementTarget(
        sceneId: 'scene',
        layerId: 'image-layer',
        elementId: 'image-element',
      ),
    );

    final result = resolver.resolveLayerScope(
      project: project(),
      sceneId: 'scene',
      layerId: 'text-layer',
      globalTime: at(8.5),
      channels: <MotionPropertyChannelModel>[textChannel, imageChannel],
    );

    expect(result.hasIssues, isFalse);
    final scope = result.projection!;
    expect(scope.mode, CompositionScopeMode.layer);
    expect(scope.globalTime, at(8.5));
    expect(scope.localTime, at(3.5));
    expect(scope.globalRange.start, at(5));
    expect(scope.localRange.endExclusive, at(8));
    expect(scope.layers.single.id, 'text-layer');
    expect(scope.elements.single.id, 'text-element');
    expect(scope.channels.single.id, 'text.opacity');
    expect(scope.localToGlobal(at(2)), at(7));
    expect(scope.globalToLocal(at(12)), at(7));
  });

  test('transition scope is a composition-time projection over two layers', () {
    final textChannel = channel(
      id: 'text.opacity',
      target: elementTarget(
        sceneId: 'scene',
        layerId: 'text-layer',
        elementId: 'text-element',
      ),
    );
    final imageChannel = channel(
      id: 'image.blur',
      target: elementTarget(
        sceneId: 'scene',
        layerId: 'image-layer',
        elementId: 'image-element',
      ),
      definition: MotionPropertyCatalog.blurAmount,
    );

    final result = resolver.resolveTransitionScope(
      project: project(),
      context: TransitionScopeContext(
        id: 'transition-1',
        sceneId: 'scene',
        outgoingLayerId: 'text-layer',
        incomingLayerId: 'image-layer',
        windowRange: range(10, 12),
      ),
      globalTime: at(10.75),
      channels: <MotionPropertyChannelModel>[textChannel, imageChannel],
    );

    expect(result.hasIssues, isFalse);
    final scope = result.projection!;
    expect(scope.mode, CompositionScopeMode.transition);
    expect(scope.globalTime, at(10.75));
    expect(scope.localTime, at(0.75));
    expect(scope.transitionWindowId, 'transition-1');
    expect(
      scope.layers.map((layer) => layer.id),
      <String>['text-layer', 'image-layer'],
    );
    expect(
      scope.channels.map((channel) => channel.id),
      <String>['text.opacity', 'image.blur'],
    );
    expect(scope.globalToLocal(at(20)), at(2));
  });

  test('missing scene or layer returns explicit issues', () {
    final missingScene = resolver.resolveSceneScope(
      project: project(),
      sceneId: 'missing-scene',
      globalTime: at(0),
    );
    expect(missingScene.hasIssues, isTrue);
    expect(
      missingScene.issues.single.code,
      CompositionProjectionIssueCode.missingScene,
    );

    final missingLayer = resolver.resolveLayerScope(
      project: project(),
      sceneId: 'scene',
      layerId: 'missing-layer',
      globalTime: at(0),
    );
    expect(missingLayer.hasIssues, isTrue);
    expect(
      missingLayer.issues.single.code,
      CompositionProjectionIssueCode.missingLayer,
    );
  });

  test('scene program output can pass through composition projections', () {
    const authoringService = ReFusionSceneProgramAuthoringService();
    final source = File(
      'test/fixtures/refusion_scene_programs/first_generated_scene.json',
    ).readAsStringSync();
    final authoring = authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: source,
        projectId: 'generated-project',
        sceneId: 'generated-scene',
      ),
    );
    expect(authoring.isValid, isTrue);

    final sceneProjection = resolver.resolveSceneScope(
      project: authoring.project!,
      sceneId: 'generated-scene',
      globalTime: TimelineTime.fromMilliseconds(900),
      channels: authoring.channels,
    );

    expect(sceneProjection.hasIssues, isFalse);
    final sceneScope = sceneProjection.projection!;
    expect(sceneScope.mode, CompositionScopeMode.scene);
    expect(sceneScope.globalTime.inMilliseconds, 900);
    expect(sceneScope.localTime.inMilliseconds, 900);
    expect(
      sceneScope.layers.map((layer) => layer.id),
      <String>['background-layer', 'accent-orb-layer', 'title-layer'],
    );
    expect(sceneScope.elements, hasLength(3));
    expect(sceneScope.channels, hasLength(8));

    final layerProjection = resolver.resolveLayerScope(
      project: authoring.project!,
      sceneId: 'generated-scene',
      layerId: 'title-layer',
      globalTime: TimelineTime.fromMilliseconds(900),
      channels: authoring.channels,
    );

    expect(layerProjection.hasIssues, isFalse);
    final titleScope = layerProjection.projection!;
    expect(titleScope.mode, CompositionScopeMode.layer);
    expect(titleScope.layerId, 'title-layer');
    expect(titleScope.globalTime.inMilliseconds, 900);
    expect(titleScope.localTime.inMilliseconds, 600);
    expect(titleScope.layers.single.id, 'title-layer');
    expect(titleScope.elements.single.id, 'hero-title');
    expect(
      titleScope.channels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.positionX.id,
        MotionPropertyCatalog.positionY.id,
        MotionPropertyCatalog.opacity.id,
        MotionPropertyCatalog.scaleX.id,
        MotionPropertyCatalog.scaleY.id,
      ]),
    );
  });
}
