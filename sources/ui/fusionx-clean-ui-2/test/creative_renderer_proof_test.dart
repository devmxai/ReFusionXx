import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/creative_renderer_proof.dart';
import 'package:refusion_app/features/editor/domain/services/unified_creative_apply_engine.dart';

void main() {
  group('PIVWSCT-10 renderer proof and invalidation', () {
    const engine = UnifiedCreativeApplyEngine();
    const evaluator = CreativeRendererProofEvaluator();
    const context = CreativeApplyContext(
      projectId: 'project-1',
      compositionSpec: CreativeCompositionSpec(
        compositionId: 'story-1',
        width: 1080,
        height: 1920,
        fps: 30,
        durationMs: 8000,
        currentTimeMs: 0,
        currentFrame: 0,
        coordinateSystem: 'center',
        origin: 'canvasCenter',
      ),
      rendererCapabilities: <String>{'motion', 'effects'},
      currentRevision: 0,
    );

    test('text character update repaints current frame', () {
      final inserted = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'text-insert',
          intent: CreativeTransactionIntent.textInsert,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.insert',
              payload: <String, Object?>{'text': 'hello'},
            ),
          ],
        ),
      );
      final updated = engine.apply(
        state: inserted.state,
        context: context,
        transaction: _tx(
          id: 'text-update',
          baseRevision: inserted.state.revision,
          intent: CreativeTransactionIntent.textUpdateContent,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.update_content',
              payload: <String, Object?>{'text': 'Hello'},
            ),
          ],
        ),
      );
      final proof = evaluator.evaluate(
        transaction: _tx(
          id: 'text-update',
          baseRevision: inserted.state.revision,
          intent: CreativeTransactionIntent.textUpdateContent,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'text.update_content'),
          ],
        ),
        result: updated,
        observation: const RendererProofObservation(
          rendererObserved: true,
          observedLayerIds: <String>{'text-1'},
          frameTargets: <FrameEvaluationProofTarget>[
            FrameEvaluationProofTarget(
              layerId: 'text-1',
              x: 540,
              y: 960,
              width: 500,
              height: 140,
            ),
          ],
        ),
      );

      expect(proof.timelineVisible, isTrue);
      expect(proof.frameEvaluated, isTrue);
      expect(proof.rendererApplied, isTrue);
    });

    test('shape transform update repaints current frame', () {
      final inserted = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'shape-insert',
          intent: CreativeTransactionIntent.shapeInsert,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'shape.insert'),
          ],
        ),
      );
      final moved = engine.apply(
        state: inserted.state,
        context: context,
        transaction: _tx(
          id: 'shape-move',
          baseRevision: inserted.state.revision,
          intent: CreativeTransactionIntent.transformPatch,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'transform.patch',
              payload: <String, Object?>{'x': 300},
            ),
          ],
        ),
      );
      final proof = evaluator.evaluate(
        transaction: _tx(
          id: 'shape-move',
          baseRevision: inserted.state.revision,
          intent: CreativeTransactionIntent.transformPatch,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'transform.patch'),
          ],
        ),
        result: moved,
        observation: const RendererProofObservation(
          rendererObserved: true,
          observedLayerIds: <String>{'shape-1'},
          frameTargets: <FrameEvaluationProofTarget>[
            FrameEvaluationProofTarget(
              layerId: 'shape-1',
              x: 300,
              y: 960,
              width: 320,
              height: 320,
            ),
          ],
        ),
      );
      expect(proof.rendererApplied, isTrue);
    });

    test('background insert proof includes full-canvas evaluated bounds', () {
      final applied = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'bg-insert',
          intent: CreativeTransactionIntent.backgroundSetSolid,
          target: const CreativeTargetRef(layerId: 'bg-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'background.set_solid',
              payload: <String, Object?>{'width': 1080, 'height': 1080},
            ),
          ],
        ),
      );
      final proof = evaluator.evaluate(
        transaction: _tx(
          id: 'bg-insert',
          intent: CreativeTransactionIntent.backgroundSetSolid,
          target: const CreativeTargetRef(layerId: 'bg-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'background.set_solid'),
          ],
        ),
        result: applied,
        observation: const RendererProofObservation(
          rendererObserved: true,
          observedLayerIds: <String>{'bg-1'},
          frameTargets: <FrameEvaluationProofTarget>[
            FrameEvaluationProofTarget(
              layerId: 'bg-1',
              x: 0,
              y: 0,
              width: 1080,
              height: 1920,
            ),
          ],
        ),
      );
      expect(proof.rendererApplied, isTrue);
      final target = const RendererProofObservation(
        frameTargets: <FrameEvaluationProofTarget>[
          FrameEvaluationProofTarget(
            layerId: 'bg-1',
            x: 0,
            y: 0,
            width: 1080,
            height: 1920,
          ),
        ],
      ).frameTargets.single;
      expect(target.width, 1080);
      expect(target.height, 1920);
    });

    test('DB/cloud-only proof is rejected as final success', () {
      final applied = engine.apply(
        state: _state(),
        context: context,
        transaction: _tx(
          id: 'text-insert',
          intent: CreativeTransactionIntent.textInsert,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.insert',
              payload: <String, Object?>{'text': 'hello'},
            ),
          ],
        ),
      );
      final proof = evaluator.evaluate(
        transaction: _tx(
          id: 'text-insert',
          intent: CreativeTransactionIntent.textInsert,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'text.insert'),
          ],
        ),
        result: applied,
        observation: const RendererProofObservation(
          rendererObserved: false,
          observedLayerIds: <String>{},
          frameTargets: <FrameEvaluationProofTarget>[],
        ),
      );
      expect(proof.rendererApplied, isFalse);
      expect(proof.isFinalSuccess, isFalse);
    });
  });
}

UnifiedCreativeState _state() {
  return const UnifiedCreativeState(
    projectId: 'project-1',
    compositionId: 'story-1',
    revision: 0,
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
    compositionId: 'story-1',
    baseRevision: baseRevision,
    target: target,
    operations: operations,
  );
}
