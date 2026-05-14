import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';

void main() {
  group('CreativeTransactionEnvelope', () {
    test('schema validation accepts valid transaction', () {
      const envelope = CreativeTransactionEnvelope(
        transactionId: 'tx-1',
        schemaVersion: 1,
        source: CreativeTransactionSource.mcpAgent,
        intent: CreativeTransactionIntent.textUpdateContent,
        projectId: 'project-1',
        compositionId: 'composition-1',
        baseRevision: 4,
        target: CreativeTargetRef(layerId: 'layer-1'),
        operations: <CreativeTransactionOperation>[
          CreativeTransactionOperation(
            kind: 'text.update_content',
            payload: <String, Object?>{'text': 'Hello'},
          ),
        ],
      );

      expect(envelope.isValid, isTrue);
      expect(envelope.validate(), isEmpty);
    });

    test('schema validation rejects missing compositionId', () {
      const envelope = CreativeTransactionEnvelope(
        transactionId: 'tx-1',
        schemaVersion: 1,
        source: CreativeTransactionSource.manualUi,
        intent: CreativeTransactionIntent.textInsert,
        projectId: 'project-1',
        compositionId: '',
        baseRevision: 0,
        operations: <CreativeTransactionOperation>[
          CreativeTransactionOperation(kind: 'text.insert'),
        ],
      );

      expect(envelope.isValid, isFalse);
      expect(
        envelope.validate(),
        contains('compositionId is required.'),
      );
    });

    test('schema validation rejects update without target', () {
      const envelope = CreativeTransactionEnvelope(
        transactionId: 'tx-2',
        schemaVersion: 1,
        source: CreativeTransactionSource.script,
        intent: CreativeTransactionIntent.layerUpdate,
        projectId: 'project-1',
        compositionId: 'composition-1',
        baseRevision: 4,
        operations: <CreativeTransactionOperation>[
          CreativeTransactionOperation(kind: 'layer.update'),
        ],
      );

      expect(envelope.isValid, isFalse);
      expect(
        envelope.validate(),
        contains('target is required for this intent.'),
      );
    });
  });

  group('CreativeTransactionSource coverage', () {
    test('covers all mandatory sources', () {
      const all = CreativeTransactionSource.values;
      expect(all, contains(CreativeTransactionSource.manualUi));
      expect(all, contains(CreativeTransactionSource.mcpAgent));
      expect(all, contains(CreativeTransactionSource.script));
      expect(all, contains(CreativeTransactionSource.template));
      expect(all, contains(CreativeTransactionSource.import));
      expect(all, contains(CreativeTransactionSource.migration));
      expect(all.length, 6);
    });
  });

  group('CreativeProofLevel ordering', () {
    test('proof level ordering is deterministic', () {
      expect(
          CreativeProofLevel.none.rank, lessThan(CreativeProofLevel.data.rank));
      expect(CreativeProofLevel.data.rank,
          lessThan(CreativeProofLevel.graph.rank));
      expect(
        CreativeProofLevel.graph.rank,
        lessThan(CreativeProofLevel.timeline.rank),
      );
      expect(
        CreativeProofLevel.timeline.rank,
        lessThan(CreativeProofLevel.frame.rank),
      );
      expect(
        CreativeProofLevel.frame.rank,
        lessThan(CreativeProofLevel.renderer.rank),
      );
    });
  });

  group('LegacyPathCleanupRecord', () {
    test('requires path id and reason', () {
      expect(
        () => LegacyPathCleanupRecord(
          pathId: '',
          decision: LegacyPathCleanupDecision.block,
          reason: 'Block unsafe path.',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => LegacyPathCleanupRecord(
          pathId: 'mcp.legacy.path',
          decision: LegacyPathCleanupDecision.adapterOnly,
          reason: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts explicit cleanup decision', () {
      final record = LegacyPathCleanupRecord(
        pathId: 'mcp.legacy.path',
        decision: LegacyPathCleanupDecision.canonicalize,
        reason: 'Route through canonical transaction only.',
        owner: 'editor-runtime',
      );

      expect(record.pathId, 'mcp.legacy.path');
      expect(record.decision, LegacyPathCleanupDecision.canonicalize);
      expect(record.reason, isNotEmpty);
    });
  });
}
