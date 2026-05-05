enum TrueFrameRenderBackendMode {
  preview,
  liveScrub,
  playback,
  export,
}

enum TrueFrameRenderOwner {
  stage5Presenter,
  professionalCompositor,
  exportAdapter,
  blocked,
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

class TrueFrameNodeRenderRouteDecision {
  const TrueFrameNodeRenderRouteDecision({
    required this.mode,
    required this.owner,
    required this.reason,
    required this.suppressesStage5Preview,
    required this.blockers,
  });

  final TrueFrameRenderBackendMode mode;
  final TrueFrameRenderOwner owner;
  final String reason;
  final bool suppressesStage5Preview;
  final List<String> blockers;
}

abstract class TrueFrameRenderBackend {
  const TrueFrameRenderBackend();

  TrueFrameRenderBackendMode modeForState({
    required bool isExporting,
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

  TrueFrameNodeRenderRouteDecision routeNodeFamilies({
    required TrueFrameRenderBackendMode mode,
    required List<String> resolvedLayerFamilies,
    required bool hasRenderablePlan,
    required bool hasTemporalMotionBlur,
    required bool hasPresentedFirstFrame,
    required bool isManualTransition,
  });
}

class TrueFrameManualTransitionRenderBackend extends TrueFrameRenderBackend {
  const TrueFrameManualTransitionRenderBackend();

  static const Set<String> _phaseISupportedFamilies = <String>{
    'videoLayer',
    'imageLayer',
    'textLayer',
    'shapeLayer',
    'groupPrecomp',
    'sceneClipInstance',
    'adjustmentControl',
  };

  @override
  TrueFrameRenderBackendMode modeForState({
    required bool isExporting,
    required bool isTimelineScrubbing,
    required bool isPlaying,
  }) {
    if (isExporting) {
      return TrueFrameRenderBackendMode.export;
    }
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

  @override
  TrueFrameNodeRenderRouteDecision routeNodeFamilies({
    required TrueFrameRenderBackendMode mode,
    required List<String> resolvedLayerFamilies,
    required bool hasRenderablePlan,
    required bool hasTemporalMotionBlur,
    required bool hasPresentedFirstFrame,
    required bool isManualTransition,
  }) {
    if (!hasRenderablePlan) {
      return TrueFrameNodeRenderRouteDecision(
        mode: mode,
        owner: TrueFrameRenderOwner.stage5Presenter,
        reason: 'trueframe_node_no_renderable_plan',
        suppressesStage5Preview: false,
        blockers: const <String>['trueframe_node_no_renderable_plan'],
      );
    }

    final familySet = resolvedLayerFamilies.toSet();
    final unsupportedFamilies = familySet
        .where((family) => !_phaseISupportedFamilies.contains(family))
        .toList(growable: false);
    if (unsupportedFamilies.isNotEmpty) {
      return TrueFrameNodeRenderRouteDecision(
        mode: mode,
        owner: TrueFrameRenderOwner.blocked,
        reason: 'trueframe_node_unsupported_layer_families',
        suppressesStage5Preview: false,
        blockers: List<String>.unmodifiable(
          <String>[
            for (final family in unsupportedFamilies)
              'trueframe_node_family_not_supported:$family',
          ],
        ),
      );
    }

    if (mode == TrueFrameRenderBackendMode.export) {
      return const TrueFrameNodeRenderRouteDecision(
        mode: TrueFrameRenderBackendMode.export,
        owner: TrueFrameRenderOwner.exportAdapter,
        reason: 'trueframe_node_export_adapter_owner',
        suppressesStage5Preview: false,
        blockers: <String>[],
      );
    }

    final transitionRoute = routeManualTransition(
      mode: mode,
      hasRenderablePlan: hasRenderablePlan,
      isManualTransition: isManualTransition,
      hasTemporalMotionBlur: hasTemporalMotionBlur,
      hasPresentedFirstFrame: hasPresentedFirstFrame,
    );
    if (transitionRoute.usesProfessionalSurface) {
      return TrueFrameNodeRenderRouteDecision(
        mode: mode,
        owner: TrueFrameRenderOwner.professionalCompositor,
        reason:
            'trueframe_node_professional_compositor_owner:${transitionRoute.reason}',
        suppressesStage5Preview: transitionRoute.suppressesStage5Preview,
        blockers: const <String>[],
      );
    }
    return TrueFrameNodeRenderRouteDecision(
      mode: mode,
      owner: TrueFrameRenderOwner.stage5Presenter,
      reason: 'trueframe_node_stage5_presenter_owner:${transitionRoute.reason}',
      suppressesStage5Preview: false,
      blockers: const <String>[],
    );
  }
}
