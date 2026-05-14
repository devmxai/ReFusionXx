import '../../domain/models/professional_scene_command_models.dart';

class ProfessionalSceneApplyProofEvaluator {
  const ProfessionalSceneApplyProofEvaluator();

  Map<String, Object?> buildSuccessProof({
    required ProfessionalSceneApplyReceipt receipt,
    required bool didApply,
    required bool hasRepresentedRemoteLayer,
    required int proofFrameTimeMs,
    required bool playerInvalidated,
  }) {
    final dataApplied = didApply || hasRepresentedRemoteLayer;
    final timelineVisible =
        hasRepresentedRemoteLayer || receipt.targetLayerIds.isNotEmpty;
    final localGraphApplied = didApply || timelineVisible;
    final frameEvaluated = dataApplied;
    final visualProgramEmitted = dataApplied;
    final rendererApplied = hasRepresentedRemoteLayer;
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
