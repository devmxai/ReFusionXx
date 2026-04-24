import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/normal_transition_timeline_authoring_adapter.dart';

void main() {
  const adapter = NormalTransitionTimelineAuthoringAdapter();

  test('creates a cross dissolve through canonical normal transition authoring',
      () {
    final result = adapter.createBuiltInPresetTransition(
      preset: TimelineTransitionPreset.crossDissolve,
      trackId: 'video-main',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      boundaryTime: TimelineTime.fromMilliseconds(5000),
      leftAvailableTail: TimelineTime.fromMilliseconds(1000),
      rightAvailableHead: TimelineTime.fromMilliseconds(1000),
    );

    expect(result.canApply, isTrue);
    expect(result.transition!.preset, TimelineTransitionPreset.crossDissolve);
    expect(result.transition!.durationTime.inMilliseconds, 720);
    expect(result.node!.definitionId, 'cross_dissolve');
    expect(result.instance!.nodeId, result.node!.id);
  });

  test('rejects presets outside the normal transition registry', () {
    final result = adapter.createBuiltInPresetTransition(
      preset: TimelineTransitionPreset.fadeBlack,
      trackId: 'video-main',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      boundaryTime: TimelineTime.fromMilliseconds(5000),
      leftAvailableTail: TimelineTime.fromMilliseconds(1000),
      rightAvailableHead: TimelineTime.fromMilliseconds(1000),
    );

    expect(result.canApply, isFalse);
    expect(result.issues.single.path, 'preset');
  });

  test('rehydrates timeline cross dissolve edits back to normal state', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition.video-main.clip-a.clip-b.cross-dissolve',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.crossDissolve,
      durationTime: TimelineTime.fromMilliseconds(880),
      parameterValues: const <String, double>{'softness': 0.7},
    );

    final result = adapter.rehydrateTimelineTransition(
      transition: transition,
      trackId: 'video-main',
    );

    expect(result.canApply, isTrue);
    expect(result.node!.duration.inMilliseconds, 880);
    expect(result.node!.parameterValues['softness'], 0.7);
    expect(result.instance!.parameterValues['softness'], 0.7);
  });

  test('rejects insufficient transition handles before UI state is mutated',
      () {
    final result = adapter.createBuiltInPresetTransition(
      preset: TimelineTransitionPreset.crossDissolve,
      trackId: 'video-main',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      boundaryTime: TimelineTime.fromMilliseconds(5000),
      leftAvailableTail: TimelineTime.fromMilliseconds(200),
      rightAvailableHead: TimelineTime.fromMilliseconds(1000),
    );

    expect(result.canApply, isFalse);
    expect(result.transition, isNull);
    expect(result.issues.map((issue) => issue.path), contains('leftClipId'));
  });
}
