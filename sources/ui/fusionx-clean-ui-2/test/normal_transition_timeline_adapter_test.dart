import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/normal_transition_timeline_adapter.dart';

void main() {
  final definition =
      const NormalTransitionCatalog().loadBuiltIns().definitionById(
            'cross_dissolve',
          )!;
  const authoring = NormalTransitionAuthoringService();
  const adapter = NormalTransitionTimelineAdapter();

  test('converts authored cross dissolve into timeline transition data', () {
    final apply = authoring.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: definition,
        trackId: 'video-main',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: TimelineTime.fromMilliseconds(5000),
        leftAvailableTail: TimelineTime.fromMilliseconds(1000),
        rightAvailableHead: TimelineTime.fromMilliseconds(1000),
        parameterOverrides: const <String, Object>{'softness': 0.75},
      ),
    );

    final transition = adapter.toTimelineTransition(
      node: apply.node!,
      instance: apply.instance!,
      window: apply.window,
    );

    expect(transition, isNotNull);
    expect(transition!.preset, TimelineTransitionPreset.crossDissolve);
    expect(transition.durationTime.inMilliseconds, 720);
    expect(transition.resolvedLeadingDurationTime.inMilliseconds, 360);
    expect(transition.resolvedTrailingDurationTime.inMilliseconds, 360);
    expect(transition.parameterValues['softness'], 0.75);
  });

  test('converts timeline cross dissolve back to normal transition state', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.crossDissolve,
      durationTime: TimelineTime.fromMilliseconds(720),
      parameterValues: const <String, double>{'softness': 0.25},
    );

    final result = adapter.fromTimelineTransition(
      transition: transition,
      trackId: 'video-main',
      definition: definition,
    );

    expect(result.canAdapt, isTrue);
    expect(result.node!.definitionId, 'cross_dissolve');
    expect(result.node!.parameterValues['softness'], 0.25);
    expect(result.instance!.channels, hasLength(2));
    expect(result.instance!.nodeId, result.node!.id);
  });

  test('rejects non-normal timeline presets', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.fadeBlack,
      durationTime: TimelineTime.fromMilliseconds(540),
    );

    final result = adapter.fromTimelineTransition(
      transition: transition,
      trackId: 'video-main',
      definition: definition,
    );

    expect(result.canAdapt, isFalse);
    expect(result.issues.single.path, 'preset');
  });
}
