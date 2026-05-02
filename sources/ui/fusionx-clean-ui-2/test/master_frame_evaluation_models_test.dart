import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_frame_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MasterTimeSnapshot timeSnapshot() {
    return MasterTimeSnapshot(
      rootTime: ms(1000),
      presentationTime: ms(1000),
      frameIndex: 30,
      frameRate: 30,
      commitFrameNumber: 7,
      monotonicTimeUs: 2000,
      phase: MasterClockPhase.playing,
      authority: MasterClockAuthority.nativeTransport,
      renderMode: MasterRenderMode.playback,
      sourceScope: MasterTimeScope.rootComposition,
    );
  }

  test('stores immutable projection and evaluated values snapshot', () {
    const mapping = MasterPropertyValueMapping(
      ui: MasterValueLayer(scalar: 100),
      engine: MasterValueLayer(scalar: 1),
      renderer: MasterValueLayer(scalar: 1),
      uiUnit: MasterValueUnit.percentUi,
      engineUnit: MasterValueUnit.normalized01,
      rendererUnit: MasterValueUnit.normalized01,
    );
    final frame = MasterFrameEvaluation(
      time: timeSnapshot(),
      projections: <MasterTimeProjection>[
        MasterTimeProjection(
          fromDomain: const MasterTimeDomain.root(),
          toDomain: const MasterTimeDomain.scene('scene-1'),
          inputTime: ms(1000),
          outputTime: ms(500),
          validRange: TimelineTimeRange(start: ms(500), endExclusive: ms(2500)),
          policy: MasterTimeProjectionPolicy.clamp,
          reason: 'root_to_scene',
        ),
      ],
      visibleLayerIds: const <String>['layer-1'],
      activeTransitionIds: const <String>['transition-1'],
      evaluatedChannels: const <MasterEvaluatedPropertyValue>[
        MasterEvaluatedPropertyValue(
          targetId: 'element-1',
          propertyDefinitionId: 'opacity',
          domain: MasterTimeDomain.scene('scene-1'),
          mapping: mapping,
          sourceChannelId: 'channel-1',
          status: 'resolved',
        ),
      ],
      diagnostics: const <String>['ok'],
    );

    expect(frame.time.frameIndex, 30);
    expect(frame.projections, hasLength(1));
    expect(frame.visibleLayerIds, <String>['layer-1']);
    expect(frame.activeTransitionIds, <String>['transition-1']);
    expect(frame.evaluatedChannels.single.propertyDefinitionId, 'opacity');
    expect(frame.evaluatedChannels.single.mapping.renderer.scalar, 1);
    expect(frame.diagnostics.single, 'ok');
  });
}
