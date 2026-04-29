import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/composition_workspace_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/composition_workspace_inspector_adapter.dart';

void main() {
  const adapter = CompositionWorkspaceInspectorAdapter();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  MotionProjectModel project() {
    final titleElement = MotionElementModel(
      id: 'title-element',
      layerId: 'title-layer',
      kind: MotionElementKind.text,
      localRange: range(0, 3000),
      name: 'Title Text',
      properties: <MotionPropertyAssignment>[
        MotionPropertyAssignment(
          target: const MotionPropertyTarget(
            kind: MotionTargetKind.element,
            targetId: 'title-element',
            sceneId: 'source-a',
            layerId: 'title-layer',
            elementId: 'title-element',
          ),
          definition: MotionPropertyCatalog.opacity,
          value: const MotionPropertyValue.scalar(0.8),
        ),
      ],
    );
    final lineElement = MotionElementModel(
      id: 'line-element',
      layerId: 'line-layer',
      kind: MotionElementKind.shape,
      shapeKind: MotionShapeKind.line,
      localRange: range(0, 3000),
      name: 'Reveal Line',
    );

    return MotionProjectModel(
      id: 'project',
      name: 'Brand Motion',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'root',
          name: 'Root Composition',
          projectRange: range(0, 6000),
          layers: const <MotionLayerModel>[],
        ),
        MotionSceneModel(
          id: 'source-a',
          name: 'Scene 01 Source',
          projectRange: range(0, 3000),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'line-layer',
              sceneId: 'source-a',
              kind: MotionLayerKind.shape,
              visibleRange: range(0, 3000),
              zIndex: 0,
              name: 'Line Layer',
              elements: <MotionElementModel>[lineElement],
            ),
            MotionLayerModel(
              id: 'title-layer',
              sceneId: 'source-a',
              kind: MotionLayerKind.text,
              visibleRange: range(200, 3200),
              zIndex: 10,
              name: 'Title Layer',
              blendMode: MotionBlendMode.screen,
              elements: <MotionElementModel>[titleElement],
            ),
          ],
        ),
      ],
    );
  }

  CompositionSceneClipModel sceneClip({
    String id = 'scene-clip-a',
    String sourceSceneId = 'source-a',
    String? name = 'Scene 01',
    int startMs = 500,
    int durationMs = 3000,
    int zIndex = 7,
  }) {
    return CompositionSceneClipModel(
      id: id,
      sourceSceneId: sourceSceneId,
      name: name,
      startTime: ms(startMs),
      durationTime: ms(durationMs),
      sourceInTime: TimelineTime.zero,
      sourceOutTime: ms(durationMs),
      timeScale: 1.25,
      instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
        opacity: 0.75,
        zIndex: zIndex,
        transform: const CompositionSceneClipInstanceTransform(
          positionX: 120,
          positionY: -32,
          scaleX: 0.6,
          scaleY: 0.7,
          rotationDegrees: 8,
        ),
        effectIds: const <String>['scene-shadow', 'scene-glow'],
      ),
    );
  }

  CompositionWorkspaceModel workspace({
    CompositionWorkspaceSelection selection =
        const CompositionWorkspaceSelection.none(),
  }) {
    return CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root',
      currentRootTime: ms(1200),
      selection: selection,
      rootBackgroundLayers: <CompositionRootBackgroundLayerModel>[
        CompositionRootBackgroundLayerModel(
          id: 'bg',
          name: 'Studio Background',
          zIndex: -100,
          colorArgb: 0xFF111111,
        ),
      ],
      sceneClips: <CompositionSceneClipModel>[sceneClip()],
    );
  }

  MotionPropertyChannelModel revealChannel() {
    return MotionPropertyChannelModel(
      id: 'title-reveal',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'title-element',
        sceneId: 'source-a',
        layerId: 'title-layer',
        elementId: 'title-element',
      ),
      definition: MotionPropertyCatalog.revealProgress,
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'kf-a',
          channelId: 'title-reveal',
          time: ms(0),
          value: const MotionPropertyValue.scalar(0),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
        MotionKeyframeModel(
          id: 'kf-b',
          channelId: 'title-reveal',
          time: ms(900),
          value: const MotionPropertyValue.scalar(1),
          interpolationToNext: const MotionInterpolationSpec.easeOut(),
        ),
      ],
    );
  }

  MotionPropertyChannelModel layerOpacityChannel() {
    return MotionPropertyChannelModel(
      id: 'title-layer-opacity',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.layer,
        targetId: 'title-layer',
        sceneId: 'source-a',
        layerId: 'title-layer',
      ),
      definition: MotionPropertyCatalog.opacity,
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'layer-kf-a',
          channelId: 'title-layer-opacity',
          time: ms(200),
          value: const MotionPropertyValue.scalar(0.4),
          interpolationToNext: const MotionInterpolationSpec.easeInOut(),
        ),
      ],
    );
  }

  test('inspects the root composition format and structure', () {
    final result = adapter.inspect(workspace: workspace());

    expect(result.hasIssues, isFalse);
    expect(result.model!.targetKind,
        CompositionWorkspaceInspectorTargetKind.rootComposition);
    expect(result.model!.title, 'Root Composition');
    expect(result.model!.propertyById('format.width')!.value, 1080);
    expect(result.model!.propertyById('format.height')!.value, 1920);
    expect(result.model!.propertyById('format.fps')!.value, 30);
    expect(result.model!.propertyById('structure.sceneClips')!.value, 1);
    expect(result.model!.hasEditableProperties, isTrue);
  });

  test('inspects a Scene Clip instance without exploding its source layers',
      () {
    final result = adapter.inspect(
      workspace: workspace(
        selection: const CompositionWorkspaceSelection.sceneClip(
          sceneClipId: 'scene-clip-a',
        ),
      ),
    );

    expect(result.hasIssues, isFalse);
    expect(result.model!.targetKind,
        CompositionWorkspaceInspectorTargetKind.sceneClipInstance);
    expect(result.model!.subtitle, 'Instance of Scene 01 Source');
    expect(result.model!.propertyById('timing.startMs')!.value, 500);
    expect(result.model!.propertyById('timing.timeScale')!.value, 1.25);
    expect(result.model!.propertyById('transform.positionX')!.value, 120);
    expect(result.model!.propertyById('transform.scaleY')!.value, 0.7);
    expect(result.model!.propertyById('style.opacity')!.value, 0.75);
    expect(result.model!.propertyById('drawOrder.zIndex')!.value, 7);
    expect(result.model!.propertyById('effects.count')!.value, 2);
  });

  test('inspects source layers and element graph channel ownership', () {
    final channels = <MotionPropertyChannelModel>[
      revealChannel(),
      layerOpacityChannel(),
    ];

    final layerResult = adapter.inspect(
      workspace: workspace(
        selection: const CompositionWorkspaceSelection.layer(
          sourceSceneId: 'source-a',
          layerId: 'title-layer',
          sceneClipId: 'scene-clip-a',
        ),
      ),
      channels: channels,
    );

    expect(layerResult.hasIssues, isFalse);
    expect(layerResult.model!.targetKind,
        CompositionWorkspaceInspectorTargetKind.layer);
    expect(layerResult.model!.propertyById('style.blendMode')!.value, 'screen');
    expect(layerResult.model!.propertyById('graph.elements')!.value, 1);
    expect(layerResult.model!.propertyById('graph.channels')!.value, 1);

    final elementResult = adapter.inspect(
      workspace: workspace(
        selection: const CompositionWorkspaceSelection.element(
          sourceSceneId: 'source-a',
          layerId: 'title-layer',
          elementId: 'title-element',
          sceneClipId: 'scene-clip-a',
        ),
      ),
      channels: channels,
    );

    expect(elementResult.hasIssues, isFalse);
    expect(elementResult.model!.targetKind,
        CompositionWorkspaceInspectorTargetKind.element);
    expect(elementResult.model!.propertyById('source.kind')!.value, 'text');
    expect(elementResult.model!.propertyById('style.opacity')!.value, 0.8);
    expect(elementResult.model!.propertyById('graph.channels')!.value, 1);
  });

  test('inspects a selected keyframe with editable timing and value', () {
    final result = adapter.inspect(
      workspace: workspace(
        selection: const CompositionWorkspaceSelection.keyframe(
          sourceSceneId: 'source-a',
          layerId: 'title-layer',
          elementId: 'title-element',
          channelId: 'title-reveal',
          keyframeId: 'kf-b',
          sceneClipId: 'scene-clip-a',
        ),
      ),
      channels: <MotionPropertyChannelModel>[revealChannel()],
    );

    expect(result.hasIssues, isFalse);
    expect(result.model!.targetKind,
        CompositionWorkspaceInspectorTargetKind.keyframe);
    expect(result.model!.subtitle, 'text.revealProgress');
    expect(result.model!.propertyById('timing.timeMs')!.value, 900);
    expect(result.model!.propertyById('graph.value')!.value, 1);
    expect(result.model!.propertyById('graph.value')!.isEditable, isTrue);
    expect(result.model!.propertyById('graph.interpolation')!.value, 'easeOut');
  });

  test('reports missing selected targets instead of returning fake values', () {
    final result = adapter.inspect(
      workspace: workspace(
        selection: const CompositionWorkspaceSelection.element(
          sourceSceneId: 'source-a',
          layerId: 'title-layer',
          elementId: 'missing-element',
        ),
      ),
      channels: <MotionPropertyChannelModel>[revealChannel()],
    );

    expect(result.hasModel, isFalse);
    expect(result.issues.single.code,
        CompositionWorkspaceInspectorIssueCode.missingElement);
    expect(result.issues.single.targetId, 'missing-element');
  });
}
