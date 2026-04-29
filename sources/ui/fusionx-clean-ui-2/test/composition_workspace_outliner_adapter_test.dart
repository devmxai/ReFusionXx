import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/composition_workspace_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/composition_workspace_outliner_adapter.dart';

void main() {
  const adapter = CompositionWorkspaceOutlinerAdapter();

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
              visibleRange: range(0, 3000),
              zIndex: 10,
              name: 'Title Layer',
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
    int startMs = 0,
    int durationMs = 3000,
    int zIndex = 0,
  }) {
    return CompositionSceneClipModel(
      id: id,
      sourceSceneId: sourceSceneId,
      name: name,
      startTime: ms(startMs),
      durationTime: ms(durationMs),
      sourceInTime: TimelineTime.zero,
      sourceOutTime: ms(durationMs),
      instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
        zIndex: zIndex,
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
        ),
      ],
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(id: 'front-scene', name: 'Foreground Scene', zIndex: 10),
        sceneClip(
          id: 'back-scene',
          name: 'Background Scene',
          startMs: 0,
          durationMs: 3000,
          zIndex: 1,
        ),
      ],
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
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  test('builds a professional workspace hierarchy', () {
    final result = adapter.build(workspace: workspace());

    expect(result.hasIssues, isFalse);
    expect(result.root.label, 'Brand Motion');
    expect(result.root.kind, CompositionWorkspaceOutlinerNodeKind.project);
    expect(result.root.children.map((node) => node.kind), <Object>[
      CompositionWorkspaceOutlinerNodeKind.assetsGroup,
      CompositionWorkspaceOutlinerNodeKind.rootComposition,
      CompositionWorkspaceOutlinerNodeKind.sourceCompositionsGroup,
    ]);

    final rootComposition = result.findById('rootComposition:root')!;
    expect(rootComposition.children.map((node) => node.kind), <Object>[
      CompositionWorkspaceOutlinerNodeKind.backgroundLayersGroup,
      CompositionWorkspaceOutlinerNodeKind.sceneClipsGroup,
    ]);
    expect(
      result.findById('rootBackground:bg')!.label,
      'Studio Background',
    );
    expect(
      result.findById('sceneClips:root')!.children.map((node) => node.label),
      <String>['Background Scene', 'Foreground Scene'],
    );

    final source = result.findById('sourceComposition:source-a')!;
    expect(source.label, 'Scene 01 Source');
    expect(
      source.children.map((node) => node.label),
      <String>['Line Layer', 'Title Layer'],
    );
    expect(result.findById('element:title-element')!.label, 'Title Text');
  });

  test('marks the selected scene clip with a selection target', () {
    final result = adapter.build(
      workspace: workspace(
        selection: const CompositionWorkspaceSelection.sceneClip(
          sceneClipId: 'front-scene',
        ),
      ),
    );

    final selected = result.selectedNode!;
    expect(selected.id, 'sceneClip:front-scene');
    expect(selected.workspaceSelection!.sceneClipId, 'front-scene');
  });

  test('shows editable channels under their target element', () {
    final result = adapter.build(
      workspace: workspace(
        selection: const CompositionWorkspaceSelection.keyframe(
          sourceSceneId: 'source-a',
          layerId: 'title-layer',
          elementId: 'title-element',
          channelId: 'title-reveal',
          keyframeId: 'kf-a',
        ),
      ),
      channels: <MotionPropertyChannelModel>[revealChannel()],
    );

    final channelNode = result.findById('channel:title-reveal')!;
    expect(channelNode.label, 'text.revealProgress');
    expect(channelNode.isSelected, isTrue);
    expect(channelNode.sourceSceneId, 'source-a');
    expect(channelNode.layerId, 'title-layer');
    expect(channelNode.elementId, 'title-element');
  });

  test('forwards root projection issues without hiding valid nodes', () {
    final badWorkspace = CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root',
      currentRootTime: TimelineTime.zero,
      rootBackgroundLayers: <CompositionRootBackgroundLayerModel>[
        CompositionRootBackgroundLayerModel(id: 'bad-bg', opacity: -1),
      ],
      sceneClips: <CompositionSceneClipModel>[sceneClip()],
    );

    final result = adapter.build(workspace: badWorkspace);

    expect(result.hasIssues, isTrue);
    expect(result.issues.single.nodeId, 'bad-bg');
    expect(result.findById('sceneClip:scene-clip-a'), isNotNull);
  });
}
