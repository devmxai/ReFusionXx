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
    final rendererApplied = rendererAppliedOverride ?? didApply;
    return <String, Object?>{
      'dataApplied': dataApplied,
      'localGraphApplied': localGraphApplied,
      'timelineVisible': timelineVisible,
      'frameEvaluated': frameEvaluated,
      'visualProgramEmitted': visualProgramEmitted,
      'rendererApplied': rendererApplied,
      'playerInvalidated': playerInvalidated,
      'visualBoundsVerified': rendererApplied,
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
      'timelineVisible': false,
      'playerInvalidated': false,
      'frameEvaluated': false,
      'visualProgramEmitted': false,
      'rendererApplied': false,
      'visualBoundsVerified': false,
    };
  }
}
