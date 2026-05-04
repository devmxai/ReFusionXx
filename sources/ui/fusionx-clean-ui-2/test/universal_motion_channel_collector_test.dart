import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/universal_motion_channel_collector.dart';

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
            endExclusive: ms(6000),
          ),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'layer-1',
              sceneId: 'scene-1',
              kind: MotionLayerKind.video,
              visibleRange: TimelineTimeRange(
                start: TimelineTime.zero,
                endExclusive: ms(6000),
              ),
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'element-1',
                  layerId: 'layer-1',
                  kind: MotionElementKind.videoClip,
                  localRange: TimelineTimeRange(
                    start: TimelineTime.zero,
                    endExclusive: ms(6000),
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
        durationTime: ms(6000),
        sourceInTime: TimelineTime.zero,
        sourceOutTime: ms(6000),
        instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
          transform: CompositionSceneClipInstanceTransform.identity,
        ),
      ),
    ];
  }

  MotionPropertyChannelModel buildChannel({
    required String id,
    required MotionPropertyTarget target,
    required MotionPropertyDefinition definition,
  }) {
    return MotionPropertyChannelModel(
      id: id,
      target: target,
      definition: definition,
      keyframes: const <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'k0',
          channelId: 'unused',
          time: TimelineTime.zero,
          value: MotionPropertyValue.scalar(1),
          interpolationToNext: MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  test('collects unique channels and preserves first source on duplicates', () {
    const collector = UniversalMotionChannelCollector();
    final first = buildChannel(
      id: 'channel.scale.x',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
      ),
      definition: MotionPropertyCatalog.scaleX,
    );
    final duplicate = buildChannel(
      id: 'channel.scale.x',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
      ),
      definition: MotionPropertyCatalog.scaleX,
    );
    final unresolved = buildChannel(
      id: 'channel.opacity.bad',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.layer,
        targetId: 'layer-missing',
        projectId: 'project-1',
      ),
      definition: MotionPropertyCatalog.opacity,
    );
    final result = collector.collect(
      project: buildProject(),
      sceneClips: buildSceneClips(),
      sources: <UniversalMotionChannelCollectionSource>[
        UniversalMotionChannelCollectionSource(
          id: 'manual',
          channels: <MotionPropertyChannelModel>[first],
        ),
        UniversalMotionChannelCollectionSource(
          id: 'transition',
          channels: <MotionPropertyChannelModel>[duplicate, unresolved],
        ),
      ],
    );

    expect(result.channels, hasLength(1));
    expect(result.channels.first.id, 'channel.scale.x');
    expect(
      result.diagnostics,
      contains('duplicate_channel_ignored:transition:channel.scale.x'),
    );
    expect(
      result.blockers,
      contains(
        'unresolved_target:transition:channel.opacity.bad:missing_scene_id',
      ),
    );
  });

  test('flags conflicting duplicate channel ids instead of silently merging',
      () {
    const collector = UniversalMotionChannelCollector();
    final first = buildChannel(
      id: 'channel.scale.x',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
      ),
      definition: MotionPropertyCatalog.scaleX,
    );
    final conflicting = MotionPropertyChannelModel(
      id: 'channel.scale.x',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
      ),
      definition: MotionPropertyCatalog.scaleX,
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'k1',
          channelId: 'channel.scale.x',
          time: ms(1000),
          value: const MotionPropertyValue.scalar(3),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );

    final result = collector.collect(
      project: buildProject(),
      sceneClips: buildSceneClips(),
      sources: <UniversalMotionChannelCollectionSource>[
        UniversalMotionChannelCollectionSource(
          id: 'manual',
          channels: <MotionPropertyChannelModel>[first],
        ),
        UniversalMotionChannelCollectionSource(
          id: 'transition',
          channels: <MotionPropertyChannelModel>[conflicting],
        ),
      ],
    );

    expect(result.channels, hasLength(1));
    expect(
      result.blockers,
      contains(
        'conflicting_channel_definition:channel.scale.x:transition',
      ),
    );
    expect(
      result.diagnostics,
      contains('duplicate_channel_conflict:transition:channel.scale.x'),
    );
  });
}
