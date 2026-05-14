import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/cloud_transaction_relay_sync.dart';
import 'package:refusion_app/features/editor/domain/services/creative_renderer_proof.dart';

void main() {
  group('PIVWSCT-11 cloud relay sync', () {
    const coordinator = CloudRelaySyncCoordinator();

    test('local MCP command does not wait for polling/cloud for visible success', () {
      final decision = coordinator.onLocalTransactionApplied(
        proof: const CreativeApplyProof(
          level: CreativeProofLevel.renderer,
          dataApplied: true,
          localGraphApplied: true,
          timelineVisible: true,
          frameEvaluated: true,
          visualProgramEmitted: true,
          rendererApplied: true,
        ),
      );
      expect(decision.appliedLocallyFirst, isTrue);
      expect(decision.waitForCloudBeforeVisibleSuccess, isFalse);
      expect(decision.shouldMirrorToCloud, isTrue);
    });

    test('remote cloud command relays same canonical transaction', () {
      const tx = CreativeTransactionEnvelope(
        transactionId: 'tx-1',
        schemaVersion: 1,
        source: CreativeTransactionSource.mcpAgent,
        intent: CreativeTransactionIntent.textInsert,
        projectId: 'project-1',
        compositionId: 'story-1',
        baseRevision: 0,
        operations: <CreativeTransactionOperation>[
          CreativeTransactionOperation(kind: 'text.insert'),
        ],
      );
      final relay = coordinator.toRelayCommand(
        commandId: 'cmd-1',
        transaction: tx,
      );
      expect(relay.commandId, 'cmd-1');
      expect(relay.transaction.transactionId, 'tx-1');
      expect(relay.transaction.intent, CreativeTransactionIntent.textInsert);
    });

    test('cloud-only row cannot mark appApplied without app proof ledger', () {
      const record = CloudAppAppliedRecord(
        commandId: 'cmd-1',
        appApplied: true,
        proofSource: 'cloud-row-only',
      );
      const emptyLedger = RendererProofLedger();
      expect(
        coordinator.canMarkCloudAppApplied(
          record: record,
          ledger: emptyLedger,
        ),
        isFalse,
      );
    });

    test('cloud appApplied allowed only with matching renderer proof entry', () {
      const proof = CreativeApplyProof(
        level: CreativeProofLevel.renderer,
        dataApplied: true,
        localGraphApplied: true,
        timelineVisible: true,
        frameEvaluated: true,
        visualProgramEmitted: true,
        rendererApplied: true,
      );
      const ledger = RendererProofLedger(
        entries: <RendererProofLedgerEntry>[
          RendererProofLedgerEntry(
            transactionId: 'cmd-1',
            proof: proof,
            latencyMs: 120,
          ),
        ],
      );
      const record = CloudAppAppliedRecord(
        commandId: 'cmd-1',
        appApplied: true,
        proofSource: 'app-proof-ledger',
      );
      expect(
        coordinator.canMarkCloudAppApplied(
          record: record,
          ledger: ledger,
        ),
        isTrue,
      );
    });
  });
}
