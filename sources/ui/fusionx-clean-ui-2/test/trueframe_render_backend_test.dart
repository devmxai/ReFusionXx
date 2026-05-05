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

  test('keeps stage5 visible while manual temporal blur waits first frame', () {
    final decision = backend.routeManualTransition(
      mode: TrueFrameRenderBackendMode.liveScrub,
      hasRenderablePlan: true,
      isManualTransition: true,
      hasTemporalMotionBlur: true,
      hasPresentedFirstFrame: false,
    );

    expect(decision.usesProfessionalSurface, isTrue);
    expect(decision.suppressesStage5Preview, isFalse);
    expect(decision.reason, 'manual_temporal_blur_waiting_first_frame');
  });

  test('suppresses stage5 after manual temporal blur first frame presents', () {
    final decision = backend.routeManualTransition(
      mode: TrueFrameRenderBackendMode.playback,
      hasRenderablePlan: true,
      isManualTransition: true,
      hasTemporalMotionBlur: true,
      hasPresentedFirstFrame: true,
    );

    expect(decision.usesProfessionalSurface, isTrue);
    expect(decision.suppressesStage5Preview, isTrue);
    expect(
      decision.reason,
      'manual_temporal_blur_professional_surface_presented',
    );
  });

  test('routes non-manual transitions to professional backend ownership', () {
    final decision = backend.routeManualTransition(
      mode: TrueFrameRenderBackendMode.preview,
      hasRenderablePlan: true,
      isManualTransition: false,
      hasTemporalMotionBlur: false,
      hasPresentedFirstFrame: false,
    );

    expect(decision.usesProfessionalSurface, isTrue);
    expect(decision.suppressesStage5Preview, isTrue);
    expect(decision.reason, 'non_manual_transition_backend_owner');
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
