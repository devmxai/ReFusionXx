import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/universal_target_resolver.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MotionProjectModel buildProject() {
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

  List<CompositionSceneClipModel> buildSceneClips() {
    return <CompositionSceneClipModel>[
      CompositionSceneClipModel(
        id: 'scene-clip-1',
        sourceSceneId: 'scene-1',
        startTime: TimelineTime.zero,
        durationTime: ms(10000),
        sourceInTime: TimelineTime.zero,
        sourceOutTime: ms(10000),
        instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
          transform: CompositionSceneClipInstanceTransform.identity,
        ),
      ),
    ];
  }

  MotionPropertyChannelModel buildChannel(MotionPropertyTarget target) {
    return MotionPropertyChannelModel(
      id: 'channel-1',
      target: target,
      definition: MotionPropertyCatalog.scaleX,
    );
  }

  test('infers scene and layer ownership for element target', () {
    const resolver = UniversalTargetResolver();
    final context = resolver.buildContext(
      project: buildProject(),
      sceneClips: buildSceneClips(),
    );
    final result = resolver.resolveChannel(
      channel: buildChannel(
        const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'element-1',
          projectId: 'project-1',
        ),
      ),
      context: context,
    );

    expect(result.isResolved, isTrue);
    expect(result.channel, isNotNull);
    expect(result.channel!.target.sceneId, 'scene-1');
    expect(result.channel!.target.layerId, 'layer-1');
    expect(result.channel!.target.elementId, 'element-1');
    expect(
      result.diagnostics,
      contains('inferred_scene_id:channel-1:scene-1'),
    );
    expect(
      result.diagnostics,
      contains('inferred_layer_id:channel-1:layer-1'),
    );
  });

  test('reports blocker when target ownership cannot be resolved', () {
    const resolver = UniversalTargetResolver();
    final context = resolver.buildContext(
      project: buildProject(),
      sceneClips: buildSceneClips(),
    );
    final result = resolver.resolveChannel(
      channel: buildChannel(
        const MotionPropertyTarget(
          kind: MotionTargetKind.layer,
          targetId: 'layer-unknown',
          projectId: 'project-1',
        ),
      ),
      context: context,
    );

    expect(result.isResolved, isFalse);
    expect(result.channel, isNull);
    expect(result.blocker, 'missing_scene_id');
  });

  test('canonicalizes targetId to explicit element identity', () {
    const resolver = UniversalTargetResolver();
    final context = resolver.buildContext(
      project: buildProject(),
      sceneClips: buildSceneClips(),
    );
    final result = resolver.resolveChannel(
      channel: buildChannel(
        const MotionPropertyTarget(
          kind: MotionTargetKind.element,
          targetId: 'legacy-clip-id',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
          elementId: 'element-1',
        ),
      ),
      context: context,
    );

    expect(result.isResolved, isTrue);
    expect(result.channel, isNotNull);
    expect(result.channel!.target.targetId, 'element-1');
    expect(
      result.diagnostics,
      contains(
        'canonical_target_id:channel-1:legacy-clip-id->element-1',
      ),
    );
  });

  test('canonicalizes targetId to explicit layer identity', () {
    const resolver = UniversalTargetResolver();
    final context = resolver.buildContext(
      project: buildProject(),
      sceneClips: buildSceneClips(),
    );
    final result = resolver.resolveChannel(
      channel: buildChannel(
        const MotionPropertyTarget(
          kind: MotionTargetKind.layer,
          targetId: 'legacy-layer-id',
          projectId: 'project-1',
          sceneId: 'scene-1',
          layerId: 'layer-1',
        ),
      ),
      context: context,
    );

    expect(result.isResolved, isTrue);
    expect(result.channel, isNotNull);
    expect(result.channel!.target.targetId, 'layer-1');
    expect(
      result.diagnostics,
      contains(
        'canonical_target_id:channel-1:legacy-layer-id->layer-1',
      ),
    );
  });
}
