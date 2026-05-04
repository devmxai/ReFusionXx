import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_scope_channel_time_mapper.dart';
import 'package:refusion_app/features/editor/domain/services/scene_scope_session.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const mapper = SceneScopeChannelTimeMapper();
  const resolver = SceneScopeSessionResolver();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: ms(startMs),
      endExclusive: ms(endMs),
    );
  }

  MotionProjectModel project() {
    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'source-scene',
          projectRange: range(500, 3500),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'layer-1',
              sceneId: 'source-scene',
              kind: MotionLayerKind.video,
              visibleRange: range(500, 3500),
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'element-1',
                  layerId: 'layer-1',
                  kind: MotionElementKind.videoClip,
                  localRange: range(0, 3000),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  CompositionSceneClipModel sceneClip() {
    return CompositionSceneClipModel(
      id: 'scene-clip',
      sourceSceneId: 'source-scene',
      startTime: ms(2000),
      durationTime: ms(3000),
      sourceInTime: ms(500),
      sourceOutTime: ms(3500),
      instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
        transform: CompositionSceneClipInstanceTransform.identity,
      ),
    );
  }

  MotionPropertyChannelModel sourceChannel() {
    return MotionPropertyChannelModel(
      id: 'channel.scale.x',
      target: const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: 'element-1',
        projectId: 'project',
        sceneId: 'source-scene',
        layerId: 'layer-1',
        elementId: 'element-1',
      ),
      definition: MotionPropertyCatalog.scaleX,
      activeRange: range(500, 3500),
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: 'k0',
          channelId: 'channel.scale.x',
          time: ms(500),
          value: const MotionPropertyValue.scalar(1),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
        MotionKeyframeModel(
          id: 'k1',
          channelId: 'channel.scale.x',
          time: ms(3500),
          value: const MotionPropertyValue.scalar(2),
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  SceneScopeSession openSession() {
    return resolver
        .open(
          SceneScopeSessionRequest(
            project: project(),
            rootTime: ms(2500),
            sceneClips: <CompositionSceneClipModel>[sceneClip()],
            channels: <MotionPropertyChannelModel>[sourceChannel()],
          ),
        )
        .session!;
  }

  test('maps channel timing from source-time to local-time', () {
    final session = openSession();
    final local = mapper.channelToLocalTime(session, sourceChannel());

    expect(local.activeRange, isNotNull);
    expect(local.activeRange!.start.inMilliseconds, 0);
    expect(local.activeRange!.endExclusive.inMilliseconds, 3000);
    expect(local.keyframes.first.time.inMilliseconds, 0);
    expect(local.keyframes.last.time.inMilliseconds, 3000);
  });

  test('maps channel timing from local-time back to source-time', () {
    final session = openSession();
    final local = mapper.channelToLocalTime(session, sourceChannel());
    final source = mapper.channelToSourceTime(session, local);

    expect(source.activeRange, isNotNull);
    expect(source.activeRange!.start.inMilliseconds, 500);
    expect(source.activeRange!.endExclusive.inMilliseconds, 3500);
    expect(source.keyframes.first.time.inMilliseconds, 500);
    expect(source.keyframes.last.time.inMilliseconds, 3500);
  });
}
