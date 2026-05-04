import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/master_frame_evaluation_read_adapter.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  CompositionSceneClipModel clip() {
    return CompositionSceneClipModel(
      id: 'scene-clip',
      sourceSceneId: 'scene-1',
      startTime: ms(0),
      durationTime: ms(3000),
      sourceInTime: ms(500),
      sourceOutTime: ms(3500),
      instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
        transform: CompositionSceneClipInstanceTransform.identity,
      ),
    );
  }

  MotionPropertyChannelModel opacityChannel() {
    return MotionPropertyChannelModel(
      id: 'channel.opacity',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project-1',
        sceneId: 'scene-1',
        layerId: 'layer-1',
        elementId: 'element-1',
      ),
      definition: MotionPropertyCatalog.opacity,
      activeRange:
          TimelineTimeRange(start: TimelineTime.zero, endExclusive: ms(3000)),
      keyframes: <MotionKeyframeModel>[
        const MotionKeyframeModel(
          id: 'k0',
          channelId: 'channel.opacity',
          time: TimelineTime.zero,
          value: MotionPropertyValue.scalar(0),
          interpolationToNext: MotionInterpolationSpec.linear(),
        ),
        MotionKeyframeModel(
          id: 'k1',
          channelId: 'channel.opacity',
          time: ms(3000),
          value: const MotionPropertyValue.scalar(100),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  MotionPropertyChannelModel rootOpacityChannel() {
    return MotionPropertyChannelModel(
      id: 'channel.root.opacity',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.project,
        targetId: 'project-1',
        projectId: 'project-1',
      ),
      definition: MotionPropertyCatalog.opacity,
      activeRange:
          TimelineTimeRange(start: TimelineTime.zero, endExclusive: ms(3000)),
      keyframes: <MotionKeyframeModel>[
        const MotionKeyframeModel(
          id: 'rk0',
          channelId: 'channel.root.opacity',
          time: TimelineTime.zero,
          value: MotionPropertyValue.scalar(0),
          interpolationToNext: MotionInterpolationSpec.linear(),
        ),
        MotionKeyframeModel(
          id: 'rk1',
          channelId: 'channel.root.opacity',
          time: ms(3000),
          value: const MotionPropertyValue.scalar(100),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  test('builds read-only frame evaluation from clock + clips + channels', () {
    final adapter = MasterFrameEvaluationReadAdapter();
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(6000),
      initialTime: ms(1500),
    );
    final frame = adapter.evaluate(
      clock: clock.snapshot,
      frameRate: 30,
      sceneClips: <CompositionSceneClipModel>[clip()],
      channels: <MotionPropertyChannelModel>[opacityChannel()],
    );

    expect(frame.projections, isNotEmpty);
    expect(frame.visibleLayerIds, contains('layer-1'));
    expect(frame.evaluatedChannels, isNotEmpty);
    final opacity = frame.evaluatedChannels.first;
    expect(opacity.propertyDefinitionId, 'opacity');
    expect(opacity.mapping.renderer.scalar, closeTo(0.6666, 0.02));
    expect(frame.diagnostics, isEmpty);
  });

  test('evaluates root-scoped project channels once per frame', () {
    final adapter = MasterFrameEvaluationReadAdapter();
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(6000),
      initialTime: ms(1500),
    );
    final frame = adapter.evaluate(
      clock: clock.snapshot,
      frameRate: 30,
      sceneClips: <CompositionSceneClipModel>[clip()],
      channels: <MotionPropertyChannelModel>[
        opacityChannel(),
        rootOpacityChannel(),
      ],
    );

    final rootEvaluations = frame.evaluatedChannels
        .where((entry) => entry.sourceChannelId == 'channel.root.opacity')
        .toList(growable: false);
    expect(rootEvaluations, hasLength(1));
    expect(rootEvaluations.single.domain, const MasterTimeDomain.root());
    expect(rootEvaluations.single.mapping.renderer.scalar, closeTo(0.5, 0.02));
  });
}
