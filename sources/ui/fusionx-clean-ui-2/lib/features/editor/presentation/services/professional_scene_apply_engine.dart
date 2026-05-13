import '../../domain/models/professional_scene_command_models.dart';

typedef ProfessionalSceneCommandExecutor = bool Function(
  ProfessionalSceneCommand command,
);

typedef ProfessionalSceneCommandRepresentationChecker = bool Function(
  ProfessionalSceneCommand command,
);

class ProfessionalSceneApplyBatchResult {
  const ProfessionalSceneApplyBatchResult({
    required this.didApply,
    required this.hasRepresentedRemoteLayer,
    required this.receipt,
  });

  final bool didApply;
  final bool hasRepresentedRemoteLayer;
  final ProfessionalSceneApplyReceipt receipt;
}

class ProfessionalSceneApplyEngine {
  const ProfessionalSceneApplyEngine();

  ProfessionalSceneApplyBatchResult apply({
    required List<ProfessionalSceneCommand> commands,
    required int receivedRemoteLayers,
    required ProfessionalSceneCommandExecutor execute,
    required ProfessionalSceneCommandRepresentationChecker isRepresented,
  }) {
    var didApply = false;
    var hasRepresentedRemoteLayer = false;
    var appliedCommandCount = 0;
    var createdLayerCount = 0;
    var updatedLayerCount = 0;
    final appliedKinds = <String>{};
    final targetLayerIds = <String>{};
    for (final command in commands) {
      final applied = execute(command);
      if (applied) {
        didApply = true;
        appliedCommandCount += 1;
        appliedKinds.add(command.type.name);
        final targetId = command.target.id?.trim() ?? '';
        if (targetId.isNotEmpty) {
          targetLayerIds.add(targetId);
        }
        switch (command.type) {
          case ProfessionalSceneCommandType.applyTextLayer:
          case ProfessionalSceneCommandType.applySolidLayer:
            createdLayerCount += 1;
            break;
          case ProfessionalSceneCommandType.applyLegacyAnimation:
          case ProfessionalSceneCommandType.applyTimelineMutation:
          case ProfessionalSceneCommandType.registerMediaBinding:
            updatedLayerCount += 1;
            break;
        }
      }
      if (isRepresented(command)) {
        hasRepresentedRemoteLayer = true;
      }
    }
    String operationApplied = 'motion';
    if (createdLayerCount > 0 && updatedLayerCount > 0) {
      operationApplied = 'mixed';
    } else if (createdLayerCount > 0) {
      operationApplied = 'insert';
    } else if (updatedLayerCount > 0) {
      operationApplied = 'update';
    }
    return ProfessionalSceneApplyBatchResult(
      didApply: didApply,
      hasRepresentedRemoteLayer: hasRepresentedRemoteLayer,
      receipt: ProfessionalSceneApplyReceipt(
        appliedCommandCount: appliedCommandCount,
        appliedCommandTypes: appliedKinds.toList(growable: false),
        receivedRemoteLayers: receivedRemoteLayers,
        operationApplied: operationApplied,
        createdLayerCount: createdLayerCount,
        updatedLayerCount: updatedLayerCount,
        targetLayerIds: targetLayerIds.toList(growable: false),
      ),
    );
  }
}
