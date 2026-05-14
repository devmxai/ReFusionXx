import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/models/in_app_virtual_project_workspace_models.dart';
import 'package:refusion_app/features/editor/domain/services/in_app_virtual_project_workspace.dart';
import 'package:refusion_app/features/editor/domain/services/local_mcp_transaction_api.dart';
import 'package:refusion_app/features/editor/domain/services/creative_transaction_validator.dart';
import 'package:refusion_app/features/editor/domain/services/unified_creative_apply_engine.dart';

void main() {
  const api = LocalMcpTransactionApi();
  const workspace = InAppVirtualProjectWorkspace();
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
  );

  test('MCP reads current Story composition spec', () {
    final snapshot = api.readSnapshot(
      workspace: workspace,
      request: _buildRequest(
        revision: 1,
        layers: const <CreativeLayerIdentity>[],
      ),
    );

    expect(snapshot.workspace.compositionSpec.width, 1080);
    expect(snapshot.workspace.compositionSpec.height, 1920);
  });

  test('MCP background insert uses Story bounds', () {
    final response = api.applyTransaction(
      state: _state(),
      context: context,
      transaction: _tx(
        id: 'tx-bg',
        intent: CreativeTransactionIntent.backgroundSetSolid,
        target: const CreativeTargetRef(layerId: 'bg-story'),
        operations: const <CreativeTransactionOperation>[
          CreativeTransactionOperation(
            kind: 'background.set_solid',
            payload: <String, Object?>{
              'width': 1080,
              'height': 1080,
              'color': '#FFFFFF',
            },
          ),
        ],
      ),
    );

    final node = response.result.state.layers['bg-story'];
    expect(response.result.success, isTrue);
    expect(node, isNotNull);
    expect(node!.width, 1080);
    expect(node.height, 1920);
  });

  test('MCP text insert then update keeps same layer count', () {
    final inserted = api.applyTransaction(
      state: _state(),
      context: context,
      transaction: _tx(
        id: 'tx-insert',
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
    final updated = api.applyTransaction(
      state: inserted.result.state,
      context: context,
      transaction: _tx(
        id: 'tx-update',
        intent: CreativeTransactionIntent.textUpdateContent,
        baseRevision: inserted.result.state.revision,
        target: const CreativeTargetRef(layerId: 'text-1'),
        operations: const <CreativeTransactionOperation>[
          CreativeTransactionOperation(
            kind: 'text.update_content',
            payload: <String, Object?>{'text': 'hello updated'},
          ),
        ],
      ),
    );

    expect(updated.result.success, isTrue);
    expect(updated.result.state.layers.length, 1);
    expect(updated.result.state.layers['text-1']?.text, 'hello updated');
  });

  test('MCP animation/effect update requires target layerId', () {
    final validation = api.validateTransaction(
      transaction: _tx(
        id: 'tx-effect',
        intent: CreativeTransactionIntent.effectApply,
        operations: const <CreativeTransactionOperation>[
          CreativeTransactionOperation(kind: 'effect.apply'),
        ],
      ),
      context: const CreativeTransactionValidationContext(
        openCompositionId: 'story-1',
        currentRevision: 0,
        canvasWidth: 1080,
        canvasHeight: 1920,
      ),
    );

    expect(validation.isValid, isFalse);
    expect(
      validation.issues.any((issue) => issue.contains('target')),
      isTrue,
    );
  });

  test('MCP transaction proof includes renderer target ids', () {
    final response = api.applyTransaction(
      state: _state(),
      context: context,
      transaction: _tx(
        id: 'tx-update-proof',
        intent: CreativeTransactionIntent.textInsert,
        target: const CreativeTargetRef(layerId: 'text-proof'),
        operations: const <CreativeTransactionOperation>[
          CreativeTransactionOperation(
            kind: 'text.insert',
            payload: <String, Object?>{'text': 'proof'},
          ),
        ],
      ),
    );

    expect(response.proof.targetLayerId, 'text-proof');
    expect(response.proof.operationApplied, 'textInsert');
  });
}

CreativeWorkspaceSnapshotBuildRequest _buildRequest({
  required int revision,
  required List<CreativeLayerIdentity> layers,
}) {
  return CreativeWorkspaceSnapshotBuildRequest(
    projectId: 'project-1',
    compositionId: 'story-1',
    revision: revision,
    compositionSpec: const CompositionSpecSnapshot(
      spec: CreativeCompositionSpec(
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
    ),
    layerGraph: LayerGraphSnapshot(
      nodes: layers
          .map(
            (layer) => LayerGraphNodeSnapshot(
              layer: layer,
              x: 100,
              y: 100,
              width: 200,
              height: 200,
            ),
          )
          .toList(growable: false),
    ),
    timeline: TimelineGraphSnapshot(
      clips: layers
          .map(
            (layer) => TimelineClipSnapshot(
              clipId: 'clip-${layer.layerId}',
              layerId: layer.layerId,
              trackId: layer.timelineTrackId,
              startMs: 0,
              durationMs: 8000,
            ),
          )
          .toList(growable: false),
    ),
    selection: const SelectionSnapshot(),
    frame: const FrameSnapshotSummary(currentFrame: 0, currentTimeMs: 0),
    renderer: const RendererCapabilitySnapshot(
      rendererName: 'stage5',
      effectCapabilities: <String>['motion', 'effects'],
    ),
  );
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
