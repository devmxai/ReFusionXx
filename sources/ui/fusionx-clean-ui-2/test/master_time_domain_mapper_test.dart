import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_time_domain_mapper.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const mapper = MasterTimeDomainMapper();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  CompositionSceneClipModel sceneClip() {
    return CompositionSceneClipModel(
      id: 'clip-1',
      sourceSceneId: 'scene-1',
      startTime: ms(2000),
      durationTime: ms(3000),
      sourceInTime: ms(500),
      sourceOutTime: ms(3500),
      instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
        transform: CompositionSceneClipInstanceTransform.identity,
      ),
    );
  }

  group('MasterTimeSnapshot', () {
    test('maps timeline clock snapshot and deterministic frame index', () {
      final clock = TimelineClockCoordinator(
        timelineDuration: ms(10000),
        initialTime: ms(1000),
      );
      clock.playFrom(ms(1000));
      clock.applyNativeSample(ms(1033));

      final snapshot = MasterTimeSnapshot.fromClockSnapshot(
        clock: clock.snapshot,
        frameRate: 30,
        renderMode: MasterRenderMode.playback,
        sourceScope: MasterTimeScope.rootComposition,
      );

      expect(snapshot.frameIndex, 30);
      expect(snapshot.rootTime.inMilliseconds, 1033);
      expect(snapshot.presentationTime.inMilliseconds, 1033);
      expect(snapshot.commitFrameNumber, greaterThanOrEqualTo(1));
    });

    test('converts frame index back to timeline time', () {
      final time = MasterTimeSnapshot.timeForFrameIndex(
        frameIndex: 60,
        frameRate: 30,
      );
      expect(time.inMilliseconds, 2000);
    });
  });

  group('MasterTimeDomainMapper', () {
    test('maps root time to scene source time', () {
      final projection = mapper.rootToScene(
        rootTime: ms(2500),
        sceneClip: sceneClip(),
      );
      expect(projection.isValid, isTrue);
      expect(projection.outputTime.inMilliseconds, 1000);
    });

    test('maps scene time to layer local and back', () {
      final layerRange = TimelineTimeRange(
        start: ms(700),
        endExclusive: ms(1700),
      );
      final toLayer = mapper.sceneToLayer(
        sceneTime: ms(1000),
        sourceSceneId: 'scene-1',
        layerId: 'layer-1',
        layerRange: layerRange,
      );
      expect(toLayer.outputTime.inMilliseconds, 300);

      final toScene = mapper.layerToScene(
        layerTime: ms(300),
        sourceSceneId: 'scene-1',
        layerId: 'layer-1',
        layerRange: layerRange,
      );
      expect(toScene.outputTime.inMilliseconds, 1000);
    });

    test('maps transition progress and rejects outside range in strict mode',
        () {
      final result = mapper.rootToTransitionProgress(
        rootTime: ms(5000),
        transitionId: 'transition-1',
        seamStart: ms(4800),
        seamDuration: ms(400),
        policy: MasterTimeProjectionPolicy.rejectOutsideRange,
      );
      expect(result.projection.isValid, isTrue);
      expect(result.progress, closeTo(0.5, 0.001));

      final outside = mapper.rootToTransitionProgress(
        rootTime: ms(5500),
        transitionId: 'transition-1',
        seamStart: ms(4800),
        seamDuration: ms(400),
        policy: MasterTimeProjectionPolicy.rejectOutsideRange,
      );
      expect(outside.projection.isValid, isFalse);
      expect(outside.progress, closeTo(1.0, 0.0001));
    });

    test('maps root time to source media through scene clip projection', () {
      final projection = mapper.rootToSourceMedia(
        rootTime: ms(2600),
        sceneClip: sceneClip(),
        mediaId: 'asset-video',
      );
      expect(projection.isValid, isTrue);
      expect(projection.outputTime.inMilliseconds, 1100);
      expect(projection.toDomain,
          const MasterTimeDomain.sourceMedia('asset-video'));
    });
  });
}
