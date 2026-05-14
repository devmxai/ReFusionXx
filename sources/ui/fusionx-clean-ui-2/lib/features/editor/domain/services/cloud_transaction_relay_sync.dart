import '../models/creative_transaction_contract_models.dart';
import 'creative_renderer_proof.dart';

class CloudRelayCommand {
  const CloudRelayCommand({
    required this.commandId,
    required this.transaction,
  });

  final String commandId;
  final CreativeTransactionEnvelope transaction;
}

class LocalEditRelayDecision {
  const LocalEditRelayDecision({
    required this.appliedLocallyFirst,
    required this.waitForCloudBeforeVisibleSuccess,
    required this.shouldMirrorToCloud,
  });

  final bool appliedLocallyFirst;
  final bool waitForCloudBeforeVisibleSuccess;
  final bool shouldMirrorToCloud;
}

class CloudAppAppliedRecord {
  const CloudAppAppliedRecord({
    required this.commandId,
    required this.appApplied,
    this.proofSource = '',
  });

  final String commandId;
  final bool appApplied;
  final String proofSource;
}

class CloudRelaySyncCoordinator {
  const CloudRelaySyncCoordinator();

  LocalEditRelayDecision onLocalTransactionApplied({
    required CreativeApplyProof proof,
  }) {
    return const LocalEditRelayDecision(
      appliedLocallyFirst: true,
      waitForCloudBeforeVisibleSuccess: false,
      shouldMirrorToCloud: true,
    );
  }

  bool canMarkCloudAppApplied({
    required CloudAppAppliedRecord record,
    required RendererProofLedger ledger,
  }) {
    if (!record.appApplied) {
      return true;
    }
    final hasLedgerProof = ledger.entries.any(
      (entry) => entry.transactionId == record.commandId && entry.proof.isFinalSuccess,
    );
    if (!hasLedgerProof) {
      return false;
    }
    return record.proofSource == 'app-proof-ledger';
  }

  CloudRelayCommand toRelayCommand({
    required String commandId,
    required CreativeTransactionEnvelope transaction,
  }) {
    return CloudRelayCommand(commandId: commandId, transaction: transaction);
  }
}
