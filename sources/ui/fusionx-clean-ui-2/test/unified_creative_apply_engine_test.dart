import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/unified_creative_apply_engine.dart';

void main() {
  group('UnifiedCreativeApplyEngine', () {
    const engine = UnifiedCreativeApplyEngine();
    const context = CreativeApplyContext(
      projectId: 'project-1',
      compositionSpec: CreativeCompositionSpec(
        compositionId: 'composition-1',
        width: 1080,
        height: 1920,
        fps: 30,
        durationMs: 8000,
        currentTimeMs: 0,
        currentFrame: 0,
        coordinateSystem: 'center',
        origin: 'canvasCenter',
      ),
      currentRevision: 0,
    );

    test(
      'insert background creates graph layer + timeline projection + full bounds',
      () {
        final result = engine.apply(
          state: _state(),
          context: context,
          transaction: _tx(
            id: 'tx-bg',
            intent: CreativeTransactionIntent.backgroundSetSolid,
            target: const CreativeTargetRef(layerId: 'bg-1'),
            operations: const <CreativeTransactionOperation>[
              CreativeTransactionOperation(
                kind: 'background.set_solid',
                payload: <String, Object?>{
                  'color': '#FFFFFF',
                  'width': 1080,
                  'height': 1080,
                },
              ),
            ],
          ),
        );

        expect(result.success, isTrue);
        final node = result.state.layers['bg-1'];
        expect(node, isNotNull);
        expect(node!.width, 1080);
        expect(node.height, 1920);
        expect(
          result.state.timeline.any((clip) => clip.layerId == 'bg-1'),
          isTrue,
        );
      },
    );

    test('text insert creates one layer id', () {
      final result = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'tx-text-insert',
          intent: CreativeTransactionIntent.textInsert,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.insert',
              payload: <String, Object?>{'text': 'Hello'},
            ),
          ],
        ),
      );
      expect(result.success, isTrue);
      expect(result.state.layers.length, 1);
      expect(result.state.layers.keys.single, 'text-1');
    });

    test('text update changes same layer id and does not increase layer count',
        () {
      final inserted = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'tx-text-insert',
          intent: CreativeTransactionIntent.textInsert,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.insert',
              payload: <String, Object?>{'text': 'Hello'},
            ),
          ],
        ),
      );
      final updated = engine.apply(
        state: inserted.state,
        context: context,
        transaction: _tx(
          id: 'tx-text-update',
          intent: CreativeTransactionIntent.textUpdateContent,
          baseRevision: inserted.state.revision,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.update_content',
              payload: <String, Object?>{'text': 'Hello Updated'},
            ),
          ],
        ),
      );
      expect(updated.success, isTrue);
      expect(updated.state.layers.length, 1);
      expect(updated.state.layers['text-1']!.text, 'Hello Updated');
    });

    test('transform patch updates current bounds seen by state', () {
      final inserted = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'tx-shape-insert',
          intent: CreativeTransactionIntent.shapeInsert,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'shape.insert'),
          ],
        ),
      );
      final patched = engine.apply(
        state: inserted.state,
        context: context,
        transaction: _tx(
          id: 'tx-transform',
          intent: CreativeTransactionIntent.transformPatch,
          baseRevision: inserted.state.revision,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'transform.patch',
              payload: <String, Object?>{
                'x': 200,
                'y': 400,
                'width': 600,
                'height': 500,
              },
            ),
          ],
        ),
      );
      expect(patched.success, isTrue);
      final node = patched.state.layers['shape-1']!;
      expect(node.x, 200);
      expect(node.y, 400);
      expect(node.width, 600);
      expect(node.height, 500);
    });

    test('failed update leaves revision unchanged', () {
      final base = _state(revision: 5);
      final failed = engine.apply(
        state: base,
        context: context,
        transaction: _tx(
          id: 'tx-failed-update',
          intent: CreativeTransactionIntent.textUpdateContent,
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'text.update_content'),
          ],
        ),
      );
      expect(failed.success, isFalse);
      expect(failed.state.revision, 5);
    });
  });
}

UnifiedCreativeState _state({int revision = 0}) {
  return UnifiedCreativeState(
    projectId: 'project-1',
    compositionId: 'composition-1',
    revision: revision,
  );
}

CreativeTransactionEnvelope _tx({
  required String id,
  required CreativeTransactionIntent intent,
  int baseRevision = 0,
  CreativeTargetRef? target,
  required List<CreativeTransactionOperation> operations,
}) {
  return CreativeTransactionEnvelope(
    transactionId: id,
    schemaVersion: 1,
    source: CreativeTransactionSource.mcpAgent,
    intent: intent,
    projectId: 'project-1',
    compositionId: 'composition-1',
    baseRevision: baseRevision,
    target: target,
    operations: operations,
  );
}
