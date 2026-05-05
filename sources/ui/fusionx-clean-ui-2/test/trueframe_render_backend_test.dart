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
}
