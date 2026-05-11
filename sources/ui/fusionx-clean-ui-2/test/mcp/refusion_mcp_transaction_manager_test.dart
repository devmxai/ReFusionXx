import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_capability.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_command_result.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_transaction.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_transaction_manager.dart';

void main() {
  group('RefusionMcpTransactionManager', () {
    test('stages and commits transaction with revision update', () {
      final manager = RefusionMcpTransactionManager(
        idFactory: () => 'txn_1',
      );
      var revision = 10;
      final command = RefusionMcpCommandEnvelope(
        commandId: 'cmd_1',
        sessionId: 'session_1',
        projectId: 'active',
        type: 'refusion.apply_scene_program',
        capability: RefusionMcpCapability.sceneWrite,
        mode: RefusionMcpCommandMode.commit,
        idempotencyKey: 'turn-1',
        expectedRevision: 10,
      );
      final pending = manager.stage(
        RefusionMcpTransactionDraft(
          command: command,
          revisionBefore: revision,
          summary: 'Apply scene',
          commit: () {
            revision = 11;
            return RefusionMcpCommitExecution(
              revisionAfter: revision,
            );
          },
        ),
      );
      expect(pending.id, 'txn_1');
      expect(manager.pendingTransactions.length, 1);
      final committed = manager.commit(
        transactionId: pending.id,
        expectedRevision: 10,
        actualRevision: 10,
      );
      expect(committed.revisionAfter, 11);
      expect(manager.pendingTransactions, isEmpty);
      expect(manager.recentCommittedTransactions.length, 1);
    });

    test('rejects commit when revision mismatches', () {
      final manager = RefusionMcpTransactionManager(idFactory: () => 'txn_2');
      final command = RefusionMcpCommandEnvelope(
        commandId: 'cmd_2',
        sessionId: 'session_1',
        projectId: 'active',
        type: 'refusion.apply_scene_program',
        capability: RefusionMcpCapability.sceneWrite,
        mode: RefusionMcpCommandMode.commit,
        idempotencyKey: 'turn-2',
        expectedRevision: 2,
      );
      final pending = manager.stage(
        RefusionMcpTransactionDraft(
          command: command,
          revisionBefore: 2,
          summary: 'Apply scene',
          commit: () => const RefusionMcpCommitExecution(revisionAfter: 3),
        ),
      );
      expect(
        () => manager.commit(
          transactionId: pending.id,
          expectedRevision: 2,
          actualRevision: 5,
        ),
        throwsA(
          isA<RefusionMcpTransactionManagerException>().having(
            (error) => error.code,
            'code',
            RefusionMcpCommandErrorCode.revisionConflict,
          ),
        ),
      );
    });

    test('supports undo and redo using provided callbacks', () {
      final manager = RefusionMcpTransactionManager(idFactory: () => 'txn_3');
      var revision = 20;
      final command = RefusionMcpCommandEnvelope(
        commandId: 'cmd_3',
        sessionId: 'session_1',
        projectId: 'active',
        type: 'refusion.keyframe_edit',
        capability: RefusionMcpCapability.motionWrite,
        mode: RefusionMcpCommandMode.commit,
        idempotencyKey: 'turn-3',
        expectedRevision: 20,
      );
      final pending = manager.stage(
        RefusionMcpTransactionDraft(
          command: command,
          revisionBefore: revision,
          summary: 'Edit keyframe',
          commit: () {
            revision = 21;
            return RefusionMcpCommitExecution(
              revisionAfter: revision,
              undo: () {
                revision = 20;
                return revision;
              },
              redo: () {
                revision = 21;
                return revision;
              },
            );
          },
        ),
      );
      manager.commit(
        transactionId: pending.id,
        expectedRevision: 20,
        actualRevision: 20,
      );
      final undone = manager.undo();
      expect(undone.revisionAfter, 20);
      final redone = manager.redo();
      expect(redone.revisionAfter, 21);
    });
  });
}
