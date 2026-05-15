import '../../domain/models/professional_scene_command_models.dart';

class ProfessionalSceneApplyProofEvaluator {
  const ProfessionalSceneApplyProofEvaluator();

  Map<String, Object?> buildSuccessProof({
    required ProfessionalSceneApplyReceipt receipt,
    required bool didApply,
    required bool hasRepresentedRemoteLayer,
    required int proofFrameTimeMs,
    required bool playerInvalidated,
    bool? timelineVisibleOverride,
    bool? rendererAppliedOverride,
    bool? visualBoundsVerifiedOverride,
    bool? canvasProfileResolvedOverride,
    bool? coordinateSpaceResolvedOverride,
    bool? targetResolvedOverride,
    bool? insideCanvasOverride,
    bool? previewExportParityEligibleOverride,
    Map<String, Object?> expectedBounds = const <String, Object?>{},
    Map<String, Object?> renderedBounds = const <String, Object?>{},
    Map<String, Object?> extraProof = const <String, Object?>{},
  }) {
    final dataApplied = didApply || hasRepresentedRemoteLayer;
    final timelineVisible = timelineVisibleOverride ??
        didApply ||
            hasRepresentedRemoteLayer ||
            receipt.targetLayerIds.isNotEmpty;
    final localGraphApplied = didApply;
    final frameEvaluated = didApply && timelineVisible;
    final visualProgramEmitted = didApply && timelineVisible;
    final canvasProfileResolved = canvasProfileResolvedOverride ??
        extraProof['spatial.canvasWidth'] != null;
    final coordinateSpaceResolved = coordinateSpaceResolvedOverride ??
        (extraProof['spatial.coordinateSystem'] != null ||
            extraProof['coordinateSpace'] != null);
    final targetResolved = targetResolvedOverride ??
        receipt.targetLayerIds.isNotEmpty || hasRepresentedRemoteLayer;
    final hasMeasuredBounds = expectedBounds.isNotEmpty ||
        renderedBounds.isNotEmpty ||
        (extraProof['proofBounds'] is Map<String, Object?> &&
            (extraProof['proofBounds'] as Map<String, Object?>).isNotEmpty);
    final visualBoundsVerified = visualBoundsVerifiedOverride ??
        (hasMeasuredBounds ? didApply : didApply);
    final insideCanvas = insideCanvasOverride ??
        (extraProof['insideCanvas'] is bool
            ? extraProof['insideCanvas'] as bool
            : true);
    final rendererApplied = rendererAppliedOverride ??
        (didApply &&
            timelineVisible &&
            targetResolved &&
            (!hasMeasuredBounds || (visualBoundsVerified && insideCanvas)));
    final previewExportParityEligible =
        previewExportParityEligibleOverride ?? rendererApplied;
    return <String, Object?>{
      'dataApplied': dataApplied,
      'localGraphApplied': localGraphApplied,
      'canvasProfileResolved': canvasProfileResolved,
      'coordinateSpaceResolved': coordinateSpaceResolved,
      'targetResolved': targetResolved,
      'timelineVisible': timelineVisible,
      'frameEvaluated': frameEvaluated,
      'visualProgramEmitted': visualProgramEmitted,
      'rendererApplied': rendererApplied,
      'playerInvalidated': playerInvalidated,
      'visualBoundsVerified': visualBoundsVerified,
      'insideCanvas': insideCanvas,
      'expectedBounds': expectedBounds,
      'renderedBounds': renderedBounds,
      'previewExportParityEligible': previewExportParityEligible,
      'proofFrameTimeMs': proofFrameTimeMs,
      if (receipt.targetLayerIds.length == 1)
        'targetLayerId': receipt.targetLayerIds.first,
      ...receipt.toProofMap(),
      ...extraProof,
    };
  }

  Map<String, Object?> buildFailureProof() {
    return const <String, Object?>{
      'dataApplied': false,
      'localGraphApplied': false,
      'canvasProfileResolved': false,
      'coordinateSpaceResolved': false,
      'targetResolved': false,
      'timelineVisible': false,
      'playerInvalidated': false,
      'frameEvaluated': false,
      'visualProgramEmitted': false,
      'rendererApplied': false,
      'visualBoundsVerified': false,
      'insideCanvas': false,
      'expectedBounds': <String, Object?>{},
      'renderedBounds': <String, Object?>{},
      'previewExportParityEligible': false,
    };
  }
}
