import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/composition_workspace_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const targetResolver = CompositionWorkspaceInsertionTargetResolver();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  MotionSceneModel scene({
    required String id,
    required int durationMs,
    List<MotionLayerModel> layers = const <MotionLayerModel>[],
  }) {
    return MotionSceneModel(
      id: id,
      name: id,
      projectRange: range(0, durationMs),
      layers: layers,
    );
  }

  MotionProjectModel project() {
    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1920, height: 1080),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        scene(id: 'root-scene', durationMs: 12000),
        scene(
          id: 'intro-source',
          durationMs: 5000,
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'title-layer',
              sceneId: 'intro-source',
              kind: MotionLayerKind.text,
              visibleRange: range(0, 5000),
              elements: const <MotionElementModel>[],
            ),
          ],
        ),
      ],
    );
  }

  CompositionSceneClipModel introClip() {
    return CompositionSceneClipModel(
      id: 'intro-clip',
      sourceSceneId: 'intro-source',
      startTime: ms(2000),
      durationTime: ms(5000),
      sourceInTime: ms(0),
      sourceOutTime: ms(5000),
    );
  }

  test('models root composition and reusable source compositions', () {
    final workspace = CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root-scene',
      currentRootTime: ms(3500),
      sceneClips: <CompositionSceneClipModel>[introClip()],
    );

    expect(workspace.validate(), isEmpty);
    expect(workspace.rootScene!.id, 'root-scene');
    expect(workspace.rootDurationTime.inMilliseconds, 12000);
    expect(workspace.sourceScenes.map((scene) => scene.id), <String>[
      'intro-source',
    ]);
    expect(workspace.sceneClipAtCurrentRootTime!.id, 'intro-clip');
    expect(
      workspace.sceneClipAtCurrentRootTime!.rootToLocalTime(ms(3500)),
      ms(1500),
    );
  });

  test('derives scene-scope time without moving the root clock', () {
    final workspace = CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root-scene',
      currentRootTime: ms(4500),
      sceneClips: <CompositionSceneClipModel>[introClip()],
      activeScope: const CompositionWorkspaceScope.scene(
        rootSceneId: 'root-scene',
        sceneClipId: 'intro-clip',
        sourceSceneId: 'intro-source',
      ),
    );

    final context = workspace.timeContext();

    expect(context.rootTime, ms(4500));
    expect(context.sourceTime, ms(2500));
    expect(context.localTime, ms(2500));
    expect(context.sceneClip!.id, 'intro-clip');
    expect(context.scope.kind, CompositionWorkspaceScopeKind.sceneComposition);
  });

  test('scene action creates new clips or modifies selected scene clips', () {
    final createWorkspace = CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root-scene',
      currentRootTime: ms(7000),
      sceneClips: <CompositionSceneClipModel>[introClip()],
    );

    final createTarget = targetResolver.resolveSceneAction(createWorkspace);
    expect(
      createTarget.action,
      CompositionWorkspaceInsertionAction.createSceneClip,
    );
    expect(createTarget.rootTime, ms(7000));
    expect(createTarget.sceneClipId, isNull);

    final modifyWorkspace = CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root-scene',
      currentRootTime: ms(3750),
      sceneClips: <CompositionSceneClipModel>[introClip()],
      selection: const CompositionWorkspaceSelection.sceneClip(
        sceneClipId: 'intro-clip',
      ),
    );

    final modifyTarget = targetResolver.resolveSceneAction(modifyWorkspace);
    expect(
      modifyTarget.action,
      CompositionWorkspaceInsertionAction.modifySceneClip,
    );
    expect(modifyTarget.sceneClipId, 'intro-clip');
    expect(modifyTarget.sourceSceneId, 'intro-source');
    expect(modifyTarget.localTime, ms(1750));
  });

  test('add button targets the active composition scope', () {
    final rootWorkspace = CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root-scene',
      currentRootTime: ms(1000),
      sceneClips: <CompositionSceneClipModel>[introClip()],
    );
    final rootTarget = targetResolver.resolveLayerInsert(
      rootWorkspace,
      layerKind: CompositionWorkspaceInsertableLayerKind.video,
    );

    expect(rootTarget.sourceSceneId, 'root-scene');
    expect(rootTarget.sceneClipId, isNull);
    expect(rootTarget.localTime, ms(1000));
    expect(rootTarget.layerKind!.motionLayerKind, MotionLayerKind.video);

    final sceneWorkspace = CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root-scene',
      currentRootTime: ms(3000),
      sceneClips: <CompositionSceneClipModel>[introClip()],
      activeScope: const CompositionWorkspaceScope.scene(
        rootSceneId: 'root-scene',
        sceneClipId: 'intro-clip',
        sourceSceneId: 'intro-source',
      ),
    );
    final sceneTarget = targetResolver.resolveLayerInsert(
      sceneWorkspace,
      layerKind: CompositionWorkspaceInsertableLayerKind.shape,
    );

    expect(sceneTarget.sourceSceneId, 'intro-source');
    expect(sceneTarget.sceneClipId, 'intro-clip');
    expect(sceneTarget.localTime, ms(1000));
    expect(sceneTarget.layerKind!.motionLayerKind, MotionLayerKind.shape);
  });

  test('selection edit can target a precise keyframe inside a layer scope', () {
    final workspace = CompositionWorkspaceModel(
      project: project(),
      rootSceneId: 'root-scene',
      currentRootTime: ms(3250),
      sceneClips: <CompositionSceneClipModel>[introClip()],
      activeScope: const CompositionWorkspaceScope.layer(
        rootSceneId: 'root-scene',
        sceneClipId: 'intro-clip',
        sourceSceneId: 'intro-source',
        layerId: 'title-layer',
      ),
      selection: const CompositionWorkspaceSelection.keyframe(
        sceneClipId: 'intro-clip',
        sourceSceneId: 'intro-source',
        layerId: 'title-layer',
        elementId: 'title-element',
        channelId: 'title.opacity',
        keyframeId: 'title.opacity.k1',
      ),
    );

    final target = targetResolver.resolveSelectionEdit(workspace);

    expect(target.action, CompositionWorkspaceInsertionAction.editKeyframe);
    expect(target.sourceSceneId, 'intro-source');
    expect(target.sceneClipId, 'intro-clip');
    expect(target.layerId, 'title-layer');
    expect(target.elementId, 'title-element');
    expect(target.channelId, 'title.opacity');
    expect(target.keyframeId, 'title.opacity.k1');
    expect(target.localTime, ms(1250));
  });

  test('reports missing root and missing source composition contracts', () {
    final workspace = CompositionWorkspaceModel(
      project: MotionProjectModel(
        id: 'project',
        format: const MotionProjectFormat(
          canvasSize: MotionSize2D(width: 1080, height: 1920),
        ),
        frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
        scenes: <MotionSceneModel>[scene(id: 'other-root', durationMs: 1000)],
      ),
      rootSceneId: 'root-scene',
      currentRootTime: TimelineTime.zero,
      sceneClips: <CompositionSceneClipModel>[
        CompositionSceneClipModel(
          id: 'missing-source-clip',
          sourceSceneId: 'missing-source',
          startTime: TimelineTime.zero,
          durationTime: ms(1000),
        ),
      ],
    );

    expect(
      workspace.validate().map((issue) => issue.code),
      containsAll(<CompositionWorkspaceIssueCode>[
        CompositionWorkspaceIssueCode.missingRootScene,
        CompositionWorkspaceIssueCode.missingSourceScene,
      ]),
    );
  });
}
