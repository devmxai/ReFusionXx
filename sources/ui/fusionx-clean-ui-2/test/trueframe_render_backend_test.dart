import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/trueframe_render_backend.dart';

void main() {
  const backend = TrueFrameManualTransitionRenderBackend();

  test('maps timeline scrubbing and playback state to backend mode', () {
    expect(
      backend.modeForState(
        isExporting: false,
        isTimelineScrubbing: true,
        isPlaying: false,
      ),
      TrueFrameRenderBackendMode.liveScrub,
    );
    expect(
      backend.modeForState(
        isExporting: false,
        isTimelineScrubbing: false,
        isPlaying: true,
      ),
      TrueFrameRenderBackendMode.playback,
    );
    expect(
      backend.modeForState(
        isExporting: false,
        isTimelineScrubbing: false,
        isPlaying: false,
      ),
      TrueFrameRenderBackendMode.preview,
    );
    expect(
      backend.modeForState(
        isExporting: true,
        isTimelineScrubbing: true,
        isPlaying: true,
      ),
      TrueFrameRenderBackendMode.export,
    );
  });

  test('routes manual temporal blur realtime through professional gate', () {
    final decision = backend.routeNodeFamilies(
      mode: TrueFrameRenderBackendMode.liveScrub,
      resolvedLayerFamilies: const <String>['videoLayer'],
      hasRenderablePlan: true,
      hasTemporalMotionBlur: true,
      hasPresentedFirstFrame: false,
      isManualTransition: true,
    );

    expect(decision.owner, TrueFrameRenderOwner.professionalCompositor);
    expect(decision.suppressesStage5Preview, isFalse);
    expect(
      decision.reason,
      contains('manual_temporal_blur_realtime_waiting_real_frame'),
    );
  });

  test('suppresses stage5 only after a real manual temporal blur frame', () {
    final decision = backend.routeNodeFamilies(
      mode: TrueFrameRenderBackendMode.playback,
      resolvedLayerFamilies: const <String>['videoLayer'],
      hasRenderablePlan: true,
      hasTemporalMotionBlur: true,
      hasPresentedFirstFrame: true,
      isManualTransition: true,
    );

    expect(decision.owner, TrueFrameRenderOwner.professionalCompositor);
    expect(decision.suppressesStage5Preview, isTrue);
    expect(
      decision.reason,
      contains('manual_temporal_blur_realtime_professional_surface_presented'),
    );
  });

  test('keeps manual transition on stage5 when temporal plan is not active',
      () {
    final decision = backend.routeNodeFamilies(
      mode: TrueFrameRenderBackendMode.preview,
      resolvedLayerFamilies: const <String>['videoLayer'],
      hasRenderablePlan: true,
      hasTemporalMotionBlur: false,
      hasPresentedFirstFrame: false,
      isManualTransition: true,
    );

    expect(decision.owner, TrueFrameRenderOwner.stage5Presenter);
    expect(decision.suppressesStage5Preview, isFalse);
    expect(
      decision.reason,
      contains('manual_transition_no_temporal_blur_stage5_presenter_owner'),
    );
  });

  test('routes non-manual transitions to professional backend ownership', () {
    final decision = backend.routeNodeFamilies(
      mode: TrueFrameRenderBackendMode.preview,
      resolvedLayerFamilies: const <String>['videoLayer'],
      hasRenderablePlan: true,
      hasTemporalMotionBlur: false,
      hasPresentedFirstFrame: false,
      isManualTransition: false,
    );

    expect(decision.owner, TrueFrameRenderOwner.professionalCompositor);
    expect(decision.suppressesStage5Preview, isTrue);
    expect(decision.reason, contains('non_manual_transition_backend_owner'));
  });

  test('routes supported phase I node families to professional compositor', () {
    final decision = backend.routeNodeFamilies(
      mode: TrueFrameRenderBackendMode.preview,
      resolvedLayerFamilies: const <String>['videoLayer', 'shapeLayer'],
      hasRenderablePlan: true,
      hasTemporalMotionBlur: false,
      hasPresentedFirstFrame: false,
      isManualTransition: false,
    );

    expect(decision.owner, TrueFrameRenderOwner.professionalCompositor);
    expect(decision.blockers, isEmpty);
    expect(decision.reason,
        contains('trueframe_node_professional_compositor_owner'));
  });

  test('blocks unsupported node families explicitly', () {
    final decision = backend.routeNodeFamilies(
      mode: TrueFrameRenderBackendMode.preview,
      resolvedLayerFamilies: const <String>['cameraLayer'],
      hasRenderablePlan: true,
      hasTemporalMotionBlur: false,
      hasPresentedFirstFrame: false,
      isManualTransition: false,
    );

    expect(decision.owner, TrueFrameRenderOwner.blocked);
    expect(
      decision.blockers,
      contains('trueframe_node_family_not_supported:cameraLayer'),
    );
  });

  test('routes export mode to export adapter owner', () {
    final decision = backend.routeNodeFamilies(
      mode: TrueFrameRenderBackendMode.export,
      resolvedLayerFamilies: const <String>['textLayer'],
      hasRenderablePlan: true,
      hasTemporalMotionBlur: false,
      hasPresentedFirstFrame: false,
      isManualTransition: false,
    );

    expect(decision.owner, TrueFrameRenderOwner.exportAdapter);
    expect(decision.blockers, isEmpty);
    expect(decision.reason, 'trueframe_node_export_adapter_owner');
  });
}
