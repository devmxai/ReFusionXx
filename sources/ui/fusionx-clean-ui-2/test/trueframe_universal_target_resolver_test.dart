import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/trueframe_universal_target_resolver.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MotionProjectModel _project() {
    return MotionProjectModel(
      id: 'project-1',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene-1',
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: ms(10000),
          ),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'layer-1',
              sceneId: 'scene-1',
              kind: MotionLayerKind.video,
              visibleRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: ms(10000),
              ),
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'element-1',
                  layerId: 'layer-1',
                  kind: MotionElementKind.videoClip,
                  localRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: ms(10000),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<CompositionSceneClipModel> _sceneClips() {
    return <CompositionSceneClipModel>[
      CompositionSceneClipModel(
        id: 'clip-A',
        sourceSceneId: 'scene-1',
        startTime: TimelineTime.zero,
        durationTime: ms(6000),
        sourceInTime: TimelineTime.zero,
        sourceOutTime: ms(6000),
        instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
          transform: CompositionSceneClipInstanceTransform.identity,
        ),
      ),
      CompositionSceneClipModel(
        id: 'clip-B',
        sourceSceneId: 'scene-1',
        startTime: ms(6000),
        durationTime: ms(4000),
        sourceInTime: TimelineTime.zero,
        sourceOutTime: ms(4000),
        instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
          transform: CompositionSceneClipInstanceTransform.identity,
        ),
      ),
    ];
  }

  test('resolves transition role targets into canonical transition nodes', () {
    const resolver = TrueFrameUniversalTargetResolver();
    final context = resolver.buildContext(
      project: _project(),
      sceneClips: _sceneClips(),
      transitionRoleClipIdByRole: const <String, String>{
        'outgoing': 'clip-A',
        'incoming': 'clip-B',
      },
    );
    final result = resolver.resolveMotionTarget(
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'outgoing',
      ),
      context: context,
      channelId: 'channel-outgoing',
    );

    expect(result.isResolved, isTrue);
    expect(result.resolvedTarget, isNotNull);
    expect(result.resolvedTarget!.kind,
        TrueFrameResolvedTargetKind.transitionRole);
    expect(result.resolvedTarget!.sceneClipId, 'clip-A');
    expect(result.resolvedTarget!.canonicalTargetId, 'clip-A');
    expect(
      result.diagnostics,
      contains(
        'resolved_transition_role:channel-outgoing:outgoing->clip-A',
      ),
    );
  });

  test('resolves scene clip instance targets as canonical scene clip nodes',
      () {
    const resolver = TrueFrameUniversalTargetResolver();
    final context = resolver.buildContext(
      project: _project(),
      sceneClips: _sceneClips(),
    );
    final result = resolver.resolveMotionTarget(
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'clip-B',
      ),
      context: context,
      channelId: 'channel-scene-clip',
    );

    expect(result.isResolved, isTrue);
    expect(result.resolvedTarget, isNotNull);
    expect(result.resolvedTarget!.kind,
        TrueFrameResolvedTargetKind.sceneClipInstance);
    expect(result.resolvedTarget!.nodeId, 'scene-clip:clip-B');
    expect(
      result.diagnostics,
      contains('resolved_scene_clip_instance:channel-scene-clip:clip-B'),
    );
  });

  test('resolves known element targets into element nodes', () {
    const resolver = TrueFrameUniversalTargetResolver();
    final context = resolver.buildContext(
      project: _project(),
      sceneClips: _sceneClips(),
    );
    final result = resolver.resolveMotionTarget(
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
      ),
      context: context,
      channelId: 'channel-element',
    );

    expect(result.isResolved, isTrue);
    expect(result.resolvedTarget, isNotNull);
    expect(result.resolvedTarget!.kind, TrueFrameResolvedTargetKind.element);
    expect(result.resolvedTarget!.nodeId, 'element:element-1');
  });

  test('resolves known group targets into group nodes', () {
    const resolver = TrueFrameUniversalTargetResolver();
    final context = resolver.buildContext(
      project: _project(),
      sceneClips: _sceneClips(),
      knownGroupIds: const <String>{'group:hero-pack'},
    );
    final result = resolver.resolveMotionTarget(
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.layer,
        targetId: 'group:hero-pack',
      ),
      context: context,
      channelId: 'channel-group',
    );

    expect(result.isResolved, isTrue);
    expect(result.resolvedTarget, isNotNull);
    expect(result.resolvedTarget!.kind, TrueFrameResolvedTargetKind.group);
    expect(result.resolvedTarget!.nodeId, 'group:group:hero-pack');
  });

  test('reports blocker for unknown element target', () {
    const resolver = TrueFrameUniversalTargetResolver();
    final context = resolver.buildContext(
      project: _project(),
      sceneClips: _sceneClips(),
    );
    final result = resolver.resolveMotionTarget(
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'unknown-element',
      ),
      context: context,
      channelId: 'channel-unknown',
    );

    expect(result.isResolved, isFalse);
    expect(result.resolvedTarget, isNull);
    expect(result.blocker, 'unknown_element_id');
  });
}
