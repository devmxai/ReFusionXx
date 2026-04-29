import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/composition_workspace_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/root_composition_layer_projection_adapter.dart';

void main() {
  const adapter = RootCompositionLayerProjectionAdapter();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  CompositionSceneClipModel sceneClip({
    String id = 'scene-clip',
    String sourceSceneId = 'source-scene',
    String? name = 'Scene 01',
    int startMs = 0,
    int durationMs = 3000,
    int zIndex = 0,
    double opacity = 1,
    bool isEnabled = true,
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
        opacity: opacity,
        zIndex: zIndex,
        transform: const CompositionSceneClipInstanceTransform(
          positionX: 120,
          positionY: -24,
          scaleX: 0.55,
          scaleY: 0.55,
        ),
        effectIds: const <String>['scene-shadow'],
        metadata: const <String, String>{'role': 'card'},
      ),
      isEnabled: isEnabled,
    );
  }

  test('projects root backgrounds and scene clip instances in draw order', () {
    final result = adapter.project(
      rootRange: range(0, 6000),
      backgroundLayers: <CompositionRootBackgroundLayerModel>[
        CompositionRootBackgroundLayerModel(
          id: 'root-bg',
          name: 'Canvas Background',
          colorArgb: 0xFF111111,
          zIndex: -100,
        ),
      ],
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(id: 'scene-card', zIndex: 10, opacity: 0.82),
      ],
    );

    expect(result.hasIssues, isFalse);
    expect(result.layers.map((layer) => layer.id), <String>[
      'root-bg',
      'scene-card',
    ]);

    final background = result.layers.first;
    expect(background.isBackground, isTrue);
    expect(background.rootRange.start.inMilliseconds, 0);
    expect(background.rootRange.endExclusive.inMilliseconds, 6000);
    expect(background.label, 'Canvas Background');

    final sceneLayer = result.layers.last;
    expect(sceneLayer.isSceneClip, isTrue);
    expect(sceneLayer.label, 'Scene 01');
    expect(sceneLayer.sourceSceneId, 'source-scene');
    expect(sceneLayer.zIndex, 10);
    expect(sceneLayer.opacity, 0.82);
    expect(sceneLayer.sceneClipTransform!.scaleX, 0.55);
    expect(sceneLayer.sceneClipEffectIds, <String>['scene-shadow']);
    expect(sceneLayer.metadata['role'], 'card');
  });

  test('allows overlapping scene cards and sorts by instance z-index', () {
    final result = adapter.project(
      rootRange: range(0, 5000),
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(
          id: 'front-card',
          sourceSceneId: 'front-source',
          startMs: 500,
          durationMs: 3000,
          zIndex: 20,
        ),
        sceneClip(
          id: 'back-card',
          sourceSceneId: 'back-source',
          startMs: 0,
          durationMs: 4000,
          zIndex: 4,
        ),
      ],
    );

    expect(result.hasIssues, isFalse);
    expect(result.layers.map((layer) => layer.id), <String>[
      'back-card',
      'front-card',
    ]);
    expect(
      result.layersAtRootTime(ms(1000)).map((layer) => layer.id),
      <String>['back-card', 'front-card'],
    );
  });

  test('clips visible ranges to the root composition range', () {
    final result = adapter.project(
      rootRange: range(1000, 4000),
      backgroundLayers: <CompositionRootBackgroundLayerModel>[
        CompositionRootBackgroundLayerModel(
          id: 'timed-bg',
          visibleRange: range(0, 2500),
        ),
      ],
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(
          id: 'late-scene',
          startMs: 3000,
          durationMs: 3000,
        ),
      ],
    );

    expect(result.layers, hasLength(2));
    expect(result.layers[0].rootRange.start.inMilliseconds, 1000);
    expect(result.layers[0].rootRange.endExclusive.inMilliseconds, 2500);
    expect(result.layers[1].rootRange.start.inMilliseconds, 3000);
    expect(result.layers[1].rootRange.endExclusive.inMilliseconds, 4000);
  });

  test('reports invalid layers without projecting them', () {
    final result = adapter.project(
      rootRange: range(0, 3000),
      backgroundLayers: <CompositionRootBackgroundLayerModel>[
        CompositionRootBackgroundLayerModel(
          id: 'bad-bg',
          opacity: 1.4,
        ),
      ],
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(
          id: 'bad-scene',
          durationMs: -100,
        ),
      ],
    );

    expect(result.layers, isEmpty);
    expect(
      result.issues.map((issue) => issue.code),
      <RootCompositionLayerProjectionIssueCode>[
        RootCompositionLayerProjectionIssueCode.invalidBackgroundLayer,
        RootCompositionLayerProjectionIssueCode.invalidSceneClip,
      ],
    );
  });

  test('projects directly from a composition workspace model', () {
    final project = MotionProjectModel(
      id: 'project',
      name: 'Project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'root',
          name: 'Root',
          projectRange: range(0, 5000),
          layers: const <MotionLayerModel>[],
        ),
      ],
    );
    final workspace = CompositionWorkspaceModel(
      project: project,
      rootSceneId: 'root',
      currentRootTime: ms(1500),
      rootBackgroundLayers: <CompositionRootBackgroundLayerModel>[
        CompositionRootBackgroundLayerModel(id: 'root-bg'),
      ],
      sceneClips: <CompositionSceneClipModel>[
        sceneClip(id: 'scene-clip', durationMs: 5000),
      ],
    );

    final result = adapter.projectWorkspace(workspace);

    expect(result.layers, hasLength(2));
    expect(result.layersAtRootTime(ms(1500)), hasLength(2));
  });
}
