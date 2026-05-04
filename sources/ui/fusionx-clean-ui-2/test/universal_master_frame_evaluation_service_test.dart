import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/master_frame_evaluation_read_adapter.dart';
import 'package:refusion_app/features/editor/presentation/services/universal_master_frame_evaluation_service.dart';
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
        id: 'clip-1',
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

  MotionPropertyChannelModel goodChannel() {
    return MotionPropertyChannelModel(
      id: 'channel.scale.x',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
      ),
      definition: MotionPropertyCatalog.scaleX,
      keyframes: <MotionKeyframeModel>[
        const MotionKeyframeModel(
          id: 'k0',
          channelId: 'channel.scale.x',
          time: TimelineTime.zero,
          value: MotionPropertyValue.scalar(1),
          interpolationToNext: MotionInterpolationSpec.linear(),
        ),
        MotionKeyframeModel(
          id: 'k1',
          channelId: 'channel.scale.x',
          time: ms(6000),
          value: const MotionPropertyValue.scalar(2),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  MotionPropertyChannelModel badChannel() {
    return MotionPropertyChannelModel(
      id: 'channel.bad.layer.opacity',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.layer,
        targetId: 'layer-unknown',
        projectId: 'project-1',
      ),
      definition: MotionPropertyCatalog.opacity,
    );
  }

  test('evaluates through universal collector and exposes blockers', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(6000),
      initialTime: ms(3000),
    );
    final service = UniversalMasterFrameEvaluationService(
      readAdapter: MasterFrameEvaluationReadAdapter(),
      channelCollector: const UniversalMotionChannelCollector(),
    );
    final result = service.evaluate(
      UniversalMasterFrameEvaluationRequest(
        clock: clock.snapshot,
        frameRate: 30,
        project: buildProject(),
        sceneClips: buildSceneClips(),
        channelSources: <UniversalMotionChannelCollectionSource>[
          UniversalMotionChannelCollectionSource(
            id: 'manual',
            channels: <MotionPropertyChannelModel>[goodChannel()],
          ),
          UniversalMotionChannelCollectionSource(
            id: 'legacy',
            channels: <MotionPropertyChannelModel>[badChannel()],
          ),
        ],
        renderMode: MasterRenderMode.preview,
      ),
    );

    expect(result.channels, hasLength(1));
    expect(
      result.blockers,
      contains(
        'unresolved_target:legacy:channel.bad.layer.opacity:missing_scene_id',
      ),
    );
    expect(result.frame.evaluatedChannels, isNotEmpty);
    expect(
      result.frame.diagnostics,
      contains(
        'unresolved_target:legacy:channel.bad.layer.opacity:missing_scene_id',
      ),
    );
    clock.dispose();
  });

  test('promotes missing master definition diagnostics to blockers', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(6000),
      initialTime: ms(3000),
    );
    final service = UniversalMasterFrameEvaluationService(
      readAdapter: MasterFrameEvaluationReadAdapter(),
      channelCollector: const UniversalMotionChannelCollector(),
    );
    final channel = MotionPropertyChannelModel(
      id: 'channel.text.fontSize',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
        sceneId: 'scene-1',
        layerId: 'layer-1',
        elementId: 'element-1',
      ),
      definition: MotionPropertyCatalog.fontSize,
      keyframes: <MotionKeyframeModel>[
        const MotionKeyframeModel(
          id: 'k0',
          channelId: 'channel.text.fontSize',
          time: TimelineTime.zero,
          value: MotionPropertyValue.scalar(24),
          interpolationToNext: MotionInterpolationSpec.linear(),
        ),
      ],
    );
    final result = service.evaluate(
      UniversalMasterFrameEvaluationRequest(
        clock: clock.snapshot,
        frameRate: 30,
        project: buildProject(),
        sceneClips: buildSceneClips(),
        channelSources: <UniversalMotionChannelCollectionSource>[
          UniversalMotionChannelCollectionSource(
            id: 'text',
            channels: <MotionPropertyChannelModel>[channel],
          ),
        ],
        renderMode: MasterRenderMode.preview,
      ),
    );

    expect(result.frame.evaluatedChannels, isEmpty);
    expect(
      result.blockers,
      contains(
        'master_evaluation_blocked:unevaluated_channel:channel.text.fontSize:missing_property_definition',
      ),
    );
    expect(
      result.frame.diagnostics,
      contains(
        'master_evaluation_blocked:unevaluated_channel:channel.text.fontSize:missing_property_definition',
      ),
    );
    clock.dispose();
  });
}
