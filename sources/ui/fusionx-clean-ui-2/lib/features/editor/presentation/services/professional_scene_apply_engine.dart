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
    final appliedKinds = <String>{};
    for (final command in commands) {
      final applied = execute(command);
      if (applied) {
        didApply = true;
        appliedCommandCount += 1;
        appliedKinds.add(command.type.name);
      }
      if (isRepresented(command)) {
        hasRepresentedRemoteLayer = true;
      }
    }
    return ProfessionalSceneApplyBatchResult(
      didApply: didApply,
      hasRepresentedRemoteLayer: hasRepresentedRemoteLayer,
      receipt: ProfessionalSceneApplyReceipt(
        appliedCommandCount: appliedCommandCount,
        appliedCommandTypes: appliedKinds.toList(growable: false),
        receivedRemoteLayers: receivedRemoteLayers,
      ),
    );
  }
}
