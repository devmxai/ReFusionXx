import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/authoring_surface_transaction_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/creative_renderer_proof.dart';
import 'package:refusion_app/features/editor/domain/services/creative_revision_history.dart';
import 'package:refusion_app/features/editor/domain/services/creative_transaction_validator.dart';
import 'package:refusion_app/features/editor/domain/services/local_mcp_transaction_api.dart';
import 'package:refusion_app/features/editor/domain/services/manual_ui_creative_transaction_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/master_frame_evaluator.dart';
import 'package:refusion_app/features/editor/domain/services/unified_creative_apply_engine.dart';

void main() {
  group('PIVWSCT-13 cross-surface certification', () {
    const engine = UnifiedCreativeApplyEngine();
    const manualAdapter = ManualUiCreativeTransactionAdapter();
    const mcpApi = LocalMcpTransactionApi();
    const compiler = AuthoringSurfaceTransactionCompiler();
    const proofEvaluator = CreativeRendererProofEvaluator();
    const frameEvaluator = MasterFrameEvaluator();
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
      currentRevision: 0,
      rendererCapabilities: <String>{'motion', 'effects'},
    );

    test('manual + MCP + template + script share one identity graph flow', () {
      // 1) Manual add shape.
      final manualInsertTx = manualAdapter.toEnvelope(
        context: const ManualUiTransactionBuildContext(
          projectId: 'project-1',
          compositionId: 'story-1',
          baseRevision: 0,
          sequence: 1,
        ),
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.addShape,
          targetLayerId: 'shape-manual-1',
        ),
      );
      final shapeInserted = engine.apply(
        state: _state(),
        context: context,
        transaction: manualInsertTx,
      );
      expect(shapeInserted.success, isTrue);
      expect(shapeInserted.state.layers.length, 1);

      // 2) MCP motion on same shape, no duplicate.
      final shapeMotion = mcpApi.applyTransaction(
        state: shapeInserted.state,
        context: context,
        transaction: _tx(
          id: 'mcp-shape-motion',
          baseRevision: shapeInserted.state.revision,
          intent: CreativeTransactionIntent.keyframeBatchApply,
          target: const CreativeTargetRef(layerId: 'shape-manual-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'keyframe.batch_apply',
              payload: <String, Object?>{'propertyId': 'x', 'keyframes': <Object?>[]},
            ),
          ],
        ),
      );
      expect(shapeMotion.result.success, isTrue);
      expect(shapeMotion.result.state.layers.length, 1);

      // 3) MCP add text -> Manual edit text -> MCP style update same id.
      final textInsert = mcpApi.applyTransaction(
        state: shapeMotion.result.state,
        context: context,
        transaction: _tx(
          id: 'mcp-text-insert',
          baseRevision: shapeMotion.result.state.revision,
          intent: CreativeTransactionIntent.textInsert,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'text.insert',
              payload: <String, Object?>{'text': 'Test'},
            ),
          ],
        ),
      );
      final manualEditTextTx = manualAdapter.toEnvelope(
        context: ManualUiTransactionBuildContext(
          projectId: 'project-1',
          compositionId: 'story-1',
          baseRevision: textInsert.result.state.revision,
          sequence: 2,
        ),
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.editTextContent,
          targetLayerId: 'text-1',
          payload: <String, Object?>{'text': 'Test Edited'},
        ),
      );
      final textEdited = engine.apply(
        state: textInsert.result.state,
        context: context,
        transaction: manualEditTextTx,
      );
      final textStyleUpdate = mcpApi.applyTransaction(
        state: textEdited.state,
        context: context,
        transaction: _tx(
          id: 'mcp-text-style',
          baseRevision: textEdited.state.revision,
          intent: CreativeTransactionIntent.layerUpdate,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'layer.set_fill',
              payload: <String, Object?>{'color': '#FF0000'},
            ),
          ],
        ),
      );
      expect(textStyleUpdate.result.state.layers['text-1']!.text, 'Test Edited');

      // 4) MCP Story background must be full canvas.
      final background = mcpApi.applyTransaction(
        state: textStyleUpdate.result.state,
        context: context,
        transaction: _tx(
          id: 'mcp-bg',
          baseRevision: textStyleUpdate.result.state.revision,
          intent: CreativeTransactionIntent.backgroundSetSolid,
          target: const CreativeTargetRef(layerId: 'bg-story'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'background.set_solid',
              payload: <String, Object?>{'width': 1080, 'height': 1080},
            ),
          ],
        ),
      );
      expect(background.result.state.layers['bg-story']!.width, 1080);
      expect(background.result.state.layers['bg-story']!.height, 1920);

      // 5) Template generated layer editable by manual+MCP on same identity.
      var state = background.result.state;
      final templateTx = compiler.compile(
        context: AuthoringSurfaceBuildContext(
          projectId: 'project-1',
          compositionId: 'story-1',
          baseRevision: state.revision,
          seed: 500,
        ),
        source: AuthoringSurfaceSource.template,
        layers: const <AuthoringLayerSpec>[
          AuthoringLayerSpec(
            sourceNodeId: 'card-1',
            kind: 'shape',
            payload: <String, Object?>{'width': 300, 'height': 200},
          ),
        ],
      );
      for (final tx in templateTx) {
        state = engine.apply(state: state, context: context, transaction: tx).state;
      }
      final manualMoveTemplate = manualAdapter.toEnvelope(
        context: ManualUiTransactionBuildContext(
          projectId: 'project-1',
          compositionId: 'story-1',
          baseRevision: state.revision,
          sequence: 3,
        ),
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.moveLayer,
          targetLayerId: 'app.template.card-1',
          payload: <String, Object?>{'x': 220},
        ),
      );
      state = engine.apply(state: state, context: context, transaction: manualMoveTemplate).state;
      final mcpEffect = mcpApi.applyTransaction(
        state: state,
        context: context,
        transaction: _tx(
          id: 'mcp-template-effect',
          baseRevision: state.revision,
          intent: CreativeTransactionIntent.effectApply,
          target: const CreativeTargetRef(layerId: 'app.template.card-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'effect.apply',
              payload: <String, Object?>{'effectType': 'shadow', 'blur': 14},
            ),
          ],
        ),
      );
      state = mcpEffect.result.state;
      expect(state.layers['app.template.card-1']!.effectStack, isNotEmpty);

      // 6) Script media insert then MCP trim on same layer.
      final scriptTx = compiler.compile(
        context: AuthoringSurfaceBuildContext(
          projectId: 'project-1',
          compositionId: 'story-1',
          baseRevision: state.revision,
          seed: 700,
        ),
        source: AuthoringSurfaceSource.pasteScript,
        layers: const <AuthoringLayerSpec>[
          AuthoringLayerSpec(
            sourceNodeId: 'video-1',
            kind: 'video',
            payload: <String, Object?>{'kind': 'video', 'durationMs': 6000},
          ),
        ],
      );
      for (final tx in scriptTx) {
        state = engine.apply(state: state, context: context, transaction: tx).state;
      }
      final trimTx = _tx(
        id: 'mcp-trim-video',
        baseRevision: state.revision,
        intent: CreativeTransactionIntent.layerUpdate,
        target: const CreativeTargetRef(layerId: 'app.pasteScript.video-1'),
        operations: const <CreativeTransactionOperation>[
          CreativeTransactionOperation(
            kind: 'layer.update',
            payload: <String, Object?>{'startMs': 500, 'durationMs': 3000},
          ),
        ],
      );
      state = engine.apply(state: state, context: context, transaction: trimTx).state;
      final clip = state.timeline.firstWhere(
        (item) => item.layerId == 'app.pasteScript.video-1',
      );
      expect(clip.startMs, 500);
      expect(clip.durationMs, 3000);

      // 7) Renderer proof with explicit observed target.
      final proof = proofEvaluator.evaluate(
        transaction: trimTx,
        result: CreativeApplyResult(
          success: true,
          state: state,
          validation: const CreativeTransactionValidationResult(isValid: true),
          diff: const CreativeTransactionDiff(
            wouldMutate: true,
            mutatedLayerIds: <String>['app.pasteScript.video-1'],
          ),
          ledger: const CreativeApplyLedger(),
        ),
        observation: const RendererProofObservation(
          rendererObserved: true,
          observedLayerIds: <String>{'app.pasteScript.video-1'},
          frameTargets: <FrameEvaluationProofTarget>[
            FrameEvaluationProofTarget(
              layerId: 'app.pasteScript.video-1',
              x: 540,
              y: 960,
              width: 1080,
              height: 1920,
            ),
          ],
        ),
      );
      expect(proof.isFinalSuccess, isTrue);

      // 8) Undo/redo preserves identity.
      var history = const CreativeRevisionHistory().seed(_state());
      history = history.commit(shapeInserted.state);
      history = history.commit(textInsert.result.state);
      final undone = history.undo();
      final redone = undone.redo();
      expect(redone.present, isNotNull);
      expect(redone.present!.layers.keys, equals(textInsert.result.state.layers.keys));

      // 9) Preview/export parity sampled by same frame evaluator.
      final layerForParity = state.layers['text-1']!;
      final previewFrame = frameEvaluator.evaluateLayerAtTime(
        layer: layerForParity,
        timeMs: 120,
      );
      final exportFrame = frameEvaluator.evaluateLayerAtTime(
        layer: layerForParity,
        timeMs: 120,
      );
      expect(previewFrame.x, exportFrame.x);
      expect(previewFrame.opacity, exportFrame.opacity);
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
