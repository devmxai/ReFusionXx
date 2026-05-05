enum TrueFrameRenderBackendMode {
  preview,
  liveScrub,
  playback,
  export,
}

class TrueFrameRenderBackendRouteDecision {
  const TrueFrameRenderBackendRouteDecision({
    required this.mode,
    required this.usesProfessionalSurface,
    required this.suppressesStage5Preview,
    required this.reason,
  });

  final TrueFrameRenderBackendMode mode;
  final bool usesProfessionalSurface;
  final bool suppressesStage5Preview;
  final String reason;
}

abstract class TrueFrameRenderBackend {
  const TrueFrameRenderBackend();

  TrueFrameRenderBackendMode modeForState({
    required bool isTimelineScrubbing,
    required bool isPlaying,
  });

  TrueFrameRenderBackendRouteDecision routeManualTransition({
    required TrueFrameRenderBackendMode mode,
    required bool hasRenderablePlan,
    required bool isManualTransition,
    required bool hasTemporalMotionBlur,
    required bool hasPresentedFirstFrame,
  });
}

class TrueFrameManualTransitionRenderBackend extends TrueFrameRenderBackend {
  const TrueFrameManualTransitionRenderBackend();

  @override
  TrueFrameRenderBackendMode modeForState({
    required bool isTimelineScrubbing,
    required bool isPlaying,
  }) {
    if (isTimelineScrubbing) {
      return TrueFrameRenderBackendMode.liveScrub;
    }
    if (isPlaying) {
      return TrueFrameRenderBackendMode.playback;
    }
    return TrueFrameRenderBackendMode.preview;
  }

  @override
  TrueFrameRenderBackendRouteDecision routeManualTransition({
    required TrueFrameRenderBackendMode mode,
    required bool hasRenderablePlan,
    required bool isManualTransition,
    required bool hasTemporalMotionBlur,
    required bool hasPresentedFirstFrame,
  }) {
    if (!hasRenderablePlan) {
      return TrueFrameRenderBackendRouteDecision(
        mode: mode,
        usesProfessionalSurface: false,
        suppressesStage5Preview: false,
        reason: 'no_renderable_plan',
      );
    }

    if (!isManualTransition) {
      return TrueFrameRenderBackendRouteDecision(
        mode: mode,
        usesProfessionalSurface: true,
        suppressesStage5Preview: true,
        reason: 'non_manual_transition_backend_owner',
      );
    }

    if (!hasTemporalMotionBlur) {
      return TrueFrameRenderBackendRouteDecision(
        mode: mode,
        usesProfessionalSurface: true,
        suppressesStage5Preview: false,
        reason: 'manual_transition_no_temporal_blur_keep_stage5_presenter',
      );
    }

    return TrueFrameRenderBackendRouteDecision(
      mode: mode,
      usesProfessionalSurface: true,
      suppressesStage5Preview: hasPresentedFirstFrame,
      reason: hasPresentedFirstFrame
          ? 'manual_temporal_blur_professional_surface_presented'
          : 'manual_temporal_blur_waiting_first_frame',
    );
  }
}
