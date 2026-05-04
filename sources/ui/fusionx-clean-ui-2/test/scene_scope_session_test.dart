import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_scope_session.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const resolver = SceneScopeSessionResolver();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  MotionElementModel textElement() {
    return MotionElementModel(
      id: 'title-element',
      layerId: 'title-layer',
      kind: MotionElementKind.text,
      localRange: range(0, 3000),
      name: 'Title',
    );
  }

  MotionProjectModel project() {
    final element = textElement();
    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 60, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'root-scene',
          name: 'Root',
          projectRange: range(0, 6000),
          layers: const <MotionLayerModel>[],
        ),
        MotionSceneModel(
          id: 'source-scene',
          name: 'Generated Scene',
          projectRange: range(500, 3500),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'title-layer',
              sceneId: 'source-scene',
              kind: MotionLayerKind.text,
              visibleRange: range(500, 3500),
              zIndex: 0,
              elements: <MotionElementModel>[element],
            ),
          ],
        ),
      ],
    );
  }

  MotionPropertyChannelModel opacityChannel() {
    return MotionPropertyChannelModel(
      id: 'title.opacity',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'title-element',
        projectId: 'project',
        sceneId: 'source-scene',
        layerId: 'title-layer',
        elementId: 'title-element',
      ),
      definition: MotionPropertyCatalog.opacity,
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'title.opacity.0',
          channelId: 'title.opacity',
          time: ms(500),
          value: const MotionPropertyValue.scalar(0),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  CompositionSceneClipModel sceneClip({
    String id = 'scene-clip',
    String sourceSceneId = 'source-scene',
  }) {
    return CompositionSceneClipModel(
      id: id,
      sourceSceneId: sourceSceneId,
      name: 'Generated Scene',
      startTime: ms(2000),
      durationTime: ms(3000),
      sourceInTime: ms(500),
      sourceOutTime: ms(3500),
    );
  }

  test('opens a scene clip as a local scene scope session', () {
    final result = resolver.open(
      SceneScopeSessionRequest(
        project: project(),
        rootTime: ms(2750),
        sceneClipId: 'scene-clip',
        sceneClips: <CompositionSceneClipModel>[sceneClip()],
        channels: <MotionPropertyChannelModel>[opacityChannel()],
      ),
    );

    expect(result.hasIssues, isFalse);
    final session = result.session!;
    expect(session.id, 'scene-scope.scene-clip.source-scene');
    expect(session.rootTime.inMilliseconds, 2750);
    expect(session.sourceTime.inMilliseconds, 1250);
    expect(session.localTime.inMilliseconds, 750);
    expect(session.rootRange.start.inMilliseconds, 2000);
    expect(session.sourceRange.start.inMilliseconds, 500);
    expect(session.localRange.endExclusive.inMilliseconds, 3000);
    expect(session.layers.single.id, 'title-layer');
    expect(session.elements.single.id, 'title-element');
    expect(session.channels.single.id, 'title.opacity');
    expect(session.localToRoot(ms(1000)).inMilliseconds, 3000);
    expect(session.rootToLocal(ms(3000)).inMilliseconds, 1000);
    expect(session.sourceToLocal(ms(1500)).inMilliseconds, 1000);
    expect(session.localToSource(ms(1000)).inMilliseconds, 1500);
  });

  test('can open the scene clip that contains the current root time', () {
    final result = resolver.open(
      SceneScopeSessionRequest(
        project: project(),
        rootTime: ms(2500),
        sceneClips: <CompositionSceneClipModel>[
          sceneClip(id: 'first'),
          CompositionSceneClipModel(
            id: 'second',
            sourceSceneId: 'source-scene',
            startTime: ms(6000),
            durationTime: ms(1000),
          ),
        ],
      ),
    );

    expect(result.hasIssues, isFalse);
    expect(result.session!.sceneClipId, 'first');
    expect(result.session!.localTime.inMilliseconds, 500);
  });

  test('reports missing scene clip and missing source scene', () {
    final missingClip = resolver.open(
      SceneScopeSessionRequest(
        project: project(),
        rootTime: ms(0),
        sceneClipId: 'missing',
        sceneClips: <CompositionSceneClipModel>[sceneClip()],
      ),
    );

    expect(missingClip.hasIssues, isTrue);
    expect(
      missingClip.issues.single.code,
      SceneScopeSessionIssueCode.missingSceneClip,
    );

    final missingSource = resolver.open(
      SceneScopeSessionRequest(
        project: project(),
        rootTime: ms(2500),
        sceneClips: <CompositionSceneClipModel>[
          sceneClip(sourceSceneId: 'missing-source'),
        ],
      ),
    );

    expect(missingSource.hasIssues, isTrue);
    expect(
      missingSource.issues.single.code,
      SceneScopeSessionIssueCode.missingSourceScene,
    );
  });

  test('rejects invalid scene clip sessions before projection', () {
    final result = resolver.open(
      SceneScopeSessionRequest(
        project: project(),
        rootTime: ms(0),
        sceneClipId: 'bad',
        sceneClips: <CompositionSceneClipModel>[
          CompositionSceneClipModel(
            id: 'bad',
            sourceSceneId: 'source-scene',
            startTime: ms(0),
            durationTime: ms(0),
          ),
        ],
      ),
    );

    expect(result.hasIssues, isTrue);
    expect(
      result.issues.map((issue) => issue.code),
      everyElement(SceneScopeSessionIssueCode.invalidSceneClip),
    );
  });

  test('scope stack preserves root and scene navigation frames', () {
    final session = resolver
        .open(
          SceneScopeSessionRequest(
            project: project(),
            rootTime: ms(2500),
            sceneClips: <CompositionSceneClipModel>[sceneClip()],
          ),
        )
        .session!;

    final stack = ScopeStack(
      frames: <ScopeStackFrame>[
        ScopeStackFrame.root(projectId: 'project', sceneId: 'root-scene'),
      ],
    ).push(ScopeStackFrame.scene(session));

    expect(stack.current!.kind, ScopeStackFrameKind.scene);
    expect(stack.current!.sceneClipId, 'scene-clip');
    expect(stack.canPop, isTrue);
    expect(stack.pop().current!.kind, ScopeStackFrameKind.root);
  });
}
