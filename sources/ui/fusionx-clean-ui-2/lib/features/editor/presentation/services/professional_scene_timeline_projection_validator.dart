import '../../domain/models/professional_scene_command_models.dart';

class ProfessionalSceneTimelineProjectionValidationResult {
  const ProfessionalSceneTimelineProjectionValidationResult({
    required this.targetCount,
    required this.projectedCount,
    required this.timelineVisible,
    required this.targetProjectionComplete,
    required this.projectedTargetIds,
    required this.missingTargetIds,
  });

  final int targetCount;
  final int projectedCount;
  final bool timelineVisible;
  final bool targetProjectionComplete;
  final List<String> projectedTargetIds;
  final List<String> missingTargetIds;

  Map<String, Object?> toProofMap() {
    return <String, Object?>{
      'targetCount': targetCount,
      'projectedTargetCount': projectedCount,
      'targetProjectionComplete': targetProjectionComplete,
      if (projectedTargetIds.isNotEmpty)
        'projectedTargetIds': projectedTargetIds,
      if (missingTargetIds.isNotEmpty) 'missingTargetIds': missingTargetIds,
    };
  }
}

class ProfessionalSceneTimelineProjectionValidator {
  const ProfessionalSceneTimelineProjectionValidator();

  ProfessionalSceneTimelineProjectionValidationResult validate({
    required ProfessionalSceneApplyReceipt receipt,
    required bool Function(String targetLayerId) isRepresentedLocally,
    required bool didApply,
    required bool hasRepresentedRemoteLayer,
  }) {
    final targets = <String>{
      for (final raw in receipt.targetLayerIds)
        if (raw.trim().isNotEmpty) raw.trim(),
    }.toList(growable: false);
    if (targets.isEmpty) {
      final visible = didApply || hasRepresentedRemoteLayer;
      return ProfessionalSceneTimelineProjectionValidationResult(
        targetCount: 0,
        projectedCount: visible ? 1 : 0,
        timelineVisible: visible,
        targetProjectionComplete: true,
        projectedTargetIds: const <String>[],
        missingTargetIds: const <String>[],
      );
    }
    final projected = <String>[];
    final missing = <String>[];
    for (final target in targets) {
      if (isRepresentedLocally(target)) {
        projected.add(target);
      } else {
        missing.add(target);
      }
    }
    return ProfessionalSceneTimelineProjectionValidationResult(
      targetCount: targets.length,
      projectedCount: projected.length,
      timelineVisible: projected.isNotEmpty,
      targetProjectionComplete: missing.isEmpty,
      projectedTargetIds: List<String>.unmodifiable(projected),
      missingTargetIds: List<String>.unmodifiable(missing),
    );
  }
}
