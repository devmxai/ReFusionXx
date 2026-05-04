import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_frame_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  MasterTimeSnapshot snapshot({
    required int frameIndex,
    required int commitFrameNumber,
  }) {
    return MasterTimeSnapshot(
      rootTime: TimelineTime.fromMilliseconds(frameIndex * 10),
      presentationTime: TimelineTime.fromMilliseconds(frameIndex * 10),
      frameIndex: frameIndex,
      frameRate: 60,
      commitFrameNumber: commitFrameNumber,
      monotonicTimeUs: frameIndex * 1000,
      phase: MasterClockPhase.playing,
      authority: MasterClockAuthority.user,
      renderMode: MasterRenderMode.preview,
      sourceScope: MasterTimeScope.rootComposition,
    );
  }

  const mapping = MasterPropertyValueMapping(
    ui: MasterValueLayer(scalar: 1),
    engine: MasterValueLayer(scalar: 1),
    renderer: MasterValueLayer(scalar: 1),
    uiUnit: MasterValueUnit.percentUi,
    engineUnit: MasterValueUnit.normalized01,
    rendererUnit: MasterValueUnit.normalized01,
  );

  test('copyWith updates selected fields and preserves unmodified values', () {
    final initial = MasterFrameEvaluation(
      time: snapshot(frameIndex: 5, commitFrameNumber: 10),
      visibleLayerIds: const <String>['layer-a'],
      activeTransitionIds: const <String>['transition-a'],
      effectParameters: const <String, MasterPropertyValueMapping>{
        'opacity': mapping,
      },
      diagnostics: const <String>['initial'],
    );

    final updated = initial.copyWith(
      time: snapshot(frameIndex: 7, commitFrameNumber: 11),
      visibleLayerIds: const <String>['layer-b', 'layer-c'],
      diagnostics: const <String>['updated'],
    );

    expect(updated.time.frameIndex, 7);
    expect(updated.time.commitFrameNumber, 11);
    expect(updated.visibleLayerIds, <String>['layer-b', 'layer-c']);
    expect(updated.diagnostics, <String>['updated']);
    expect(updated.activeTransitionIds, <String>['transition-a']);
    expect(updated.effectParameters, initial.effectParameters);
  });
}
