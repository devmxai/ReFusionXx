import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/normal_transition_timeline_adapter.dart';

void main() {
  final catalogResult = const NormalTransitionCatalog().loadBuiltIns();
  final definition = catalogResult.definitionById('cross_dissolve')!;
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
    expect(transition.durationTime.inMilliseconds, 2000);
    expect(transition.resolvedLeadingDurationTime.inMilliseconds, 1000);
    expect(transition.resolvedTrailingDurationTime.inMilliseconds, 1000);
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

  test('maps graph-backed fade and zoom timeline presets', () {
    final fadeDefinition = catalogResult.definitionById('fade_black')!;
    final zoomDefinition = catalogResult.definitionById('zoom_in_camera')!;
    final distortionDefinition =
        catalogResult.definitionById('distortion_zoom_in_v1')!;
    final fadeTransition = TimelineTrackTransitionData(
      id: 'transition-fade',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.fadeBlack,
      durationTime: TimelineTime.fromMilliseconds(900),
      parameterValues: const <String, double>{'hold': 0.12},
    );
    final zoomTransition = TimelineTrackTransitionData(
      id: 'transition-zoom',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.zoomInCamera,
      durationTime: TimelineTime.fromMilliseconds(4000),
      parameterValues: const <String, double>{'outgoingBoostScale': 2.1},
    );
    final distortionTransition = TimelineTrackTransitionData(
      id: 'transition-distortion-zoom',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.distortionZoomInV1,
      durationTime: TimelineTime.fromMilliseconds(4000),
      parameterValues: const <String, double>{'lensDistortionPeak': 0.4},
    );

    final fade = adapter.fromTimelineTransition(
      transition: fadeTransition,
      trackId: 'video-main',
      definition: fadeDefinition,
    );
    final zoom = adapter.fromTimelineTransition(
      transition: zoomTransition,
      trackId: 'video-main',
      definition: zoomDefinition,
    );
    final distortion = adapter.fromTimelineTransition(
      transition: distortionTransition,
      trackId: 'video-main',
      definition: distortionDefinition,
    );

    expect(fade.canAdapt, isTrue);
    expect(fade.node!.definitionId, 'fade_black');
    expect(fade.node!.parameterValues['hold'], 0.12);
    expect(fade.instance!.channels, hasLength(2));
    expect(zoom.canAdapt, isTrue);
    expect(zoom.node!.definitionId, 'zoom_in_camera');
    expect(zoom.node!.parameterValues['outgoingBoostScale'], 2.1);
    expect(zoom.instance!.channels, hasLength(6));
    expect(distortion.canAdapt, isTrue);
    expect(distortion.node!.definitionId, 'distortion_zoom_in_v1');
    expect(distortion.node!.parameterValues['lensDistortionPeak'], 0.4);
    expect(distortion.instance!.channels, hasLength(6));
  });

  test('rejects non-normal timeline presets', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
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
