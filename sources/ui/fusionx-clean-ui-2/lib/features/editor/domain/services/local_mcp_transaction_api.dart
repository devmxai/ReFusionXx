import '../models/creative_transaction_contract_models.dart';
import '../models/in_app_virtual_project_workspace_models.dart';
import 'creative_target_resolver.dart';
import 'creative_transaction_validator.dart';
import 'in_app_virtual_project_workspace.dart';
import 'unified_creative_apply_engine.dart';

class LocalMcpTransactionApi {
  const LocalMcpTransactionApi({
    this.workspaceBuilder = const CreativeWorkspaceSnapshotBuilder(),
    this.targetResolver = const CreativeTargetResolver(),
    this.validator = const CreativeTransactionValidator(),
    this.dryRunEngine = const CreativeTransactionDryRunEngine(),
    this.applyEngine = const UnifiedCreativeApplyEngine(),
  });

  final CreativeWorkspaceSnapshotBuilder workspaceBuilder;
  final CreativeTargetResolver targetResolver;
  final CreativeTransactionValidator validator;
  final CreativeTransactionDryRunEngine dryRunEngine;
  final UnifiedCreativeApplyEngine applyEngine;

  InAppVirtualProjectWorkspaceSnapshot readSnapshot({
    required InAppVirtualProjectWorkspace workspace,
    required CreativeWorkspaceSnapshotBuildRequest request,
  }) {
    return workspaceBuilder.build(workspace, request);
  }

  CreativeTransactionValidationResult validateTransaction({
    required CreativeTransactionEnvelope transaction,
    required CreativeTransactionValidationContext context,
  }) {
    return validator.validate(transaction, context);
  }

  CreativeTransactionDryRunResult dryRunTransaction({
    required CreativeTransactionEnvelope transaction,
    required CreativeTransactionValidationContext context,
  }) {
    return dryRunEngine.dryRun(transaction, context);
  }

  CreativeTargetResolution resolveTarget({
    required InAppVirtualProjectWorkspaceSnapshot snapshot,
    required CreativeTargetResolutionRequest request,
  }) {
    return targetResolver.resolve(
      CreativeTargetResolutionRequest(
        layers: snapshot.workspace.layers,
        target: request.target,
        transactionCreatedLayerId: request.transactionCreatedLayerId,
        selectedLayerIds: request.selectedLayerIds.isEmpty
            ? snapshot.workspace.selection
            : request.selectedLayerIds,
        allowSelectedFallback: request.allowSelectedFallback,
        explicitUserMentionLayerId: request.explicitUserMentionLayerId,
        spatialCandidateLayerIds: request.spatialCandidateLayerIds,
        textQuery: request.textQuery,
        textByLayerId: request.textByLayerId,
      ),
    );
  }

  LocalMcpApplyResponse applyTransaction({
    required UnifiedCreativeState state,
    required CreativeApplyContext context,
    required CreativeTransactionEnvelope transaction,
    CreativeApplyLedger ledger = const CreativeApplyLedger(),
  }) {
    final normalized = _normalizeTransactionTarget(
      state: state,
      transaction: transaction,
    );
    if (!normalized.ok) {
      final validation = CreativeTransactionValidationResult(
        isValid: false,
        issues: <String>[normalized.errorCode],
      );
      final failedResult = CreativeApplyResult(
        success: false,
        state: state,
        validation: validation,
        diff: const CreativeTransactionDiff(),
        ledger: ledger.append(
          CreativeApplyLedgerEntry(
            transactionId: transaction.transactionId,
            intent: transaction.intent,
            result: 'failed_target_resolution',
            revisionAfter: state.revision,
          ),
        ),
        error: normalized.errorCode,
      );
      return LocalMcpApplyResponse(
        result: failedResult,
        proof: _buildProof(transaction, failedResult),
      );
    }
    final effectiveTransaction = normalized.transaction ?? transaction;
    final result = applyEngine.apply(
      state: state,
      context: context,
      transaction: effectiveTransaction,
      ledger: ledger,
    );
    return LocalMcpApplyResponse(
      result: result,
      proof: _buildProof(effectiveTransaction, result),
    );
  }
}

class LocalMcpApplyResponse {
  const LocalMcpApplyResponse({
    required this.result,
    required this.proof,
  });

  final CreativeApplyResult result;
  final CreativeApplyProof proof;
}

class _NormalizedTransactionTarget {
  const _NormalizedTransactionTarget({
    required this.ok,
    this.transaction,
    this.errorCode = '',
  });

  final bool ok;
  final CreativeTransactionEnvelope? transaction;
  final String errorCode;
}

_NormalizedTransactionTarget _normalizeTransactionTarget({
  required UnifiedCreativeState state,
  required CreativeTransactionEnvelope transaction,
}) {
  if (!_requiresResolvedLayerTarget(transaction.intent)) {
    return _NormalizedTransactionTarget(ok: true, transaction: transaction);
  }
  final target = transaction.target;
  if (target == null) {
    return const _NormalizedTransactionTarget(
      ok: false,
      errorCode: 'TARGET_NOT_FOUND',
    );
  }
  if (_hasText(target.layerId)) {
    return _NormalizedTransactionTarget(ok: true, transaction: transaction);
  }

  final layers =
      state.layers.values.map((node) => node.identity).toList(growable: false);
  final textByLayerId = <String, String>{};
  for (final entry in state.layers.entries) {
    final text = entry.value.text.trim();
    if (text.isNotEmpty) {
      textByLayerId[entry.key] = text;
    }
  }

  const resolver = CreativeTargetResolver();
  final resolution = resolver.resolve(
    CreativeTargetResolutionRequest(
      layers: layers,
      target: target,
      selectedLayerIds: state.selectedLayerId == null
          ? const <String>[]
          : <String>[state.selectedLayerId!],
      allowSelectedFallback: false,
      textByLayerId: textByLayerId,
    ),
  );

  if (resolution.result == CreativeTargetResolutionResult.resolvedAmbiguous) {
    return const _NormalizedTransactionTarget(
      ok: false,
      errorCode: 'AMBIGUOUS_TARGET',
    );
  }
  if (resolution.result ==
      CreativeTargetResolutionResult.blockedUnsafeFallback) {
    return const _NormalizedTransactionTarget(
      ok: false,
      errorCode: 'UNSAFE_FALLBACK_BLOCKED',
    );
  }
  final resolvedLayerId = resolution.layerId?.trim();
  if (resolvedLayerId == null || resolvedLayerId.isEmpty) {
    return const _NormalizedTransactionTarget(
      ok: false,
      errorCode: 'TARGET_NOT_FOUND',
    );
  }

  final normalizedTarget = CreativeTargetRef(
    layerId: resolvedLayerId,
    layerAlias: target.layerAlias,
    clipId: target.clipId,
    elementId: target.elementId,
  );

  return _NormalizedTransactionTarget(
    ok: true,
    transaction: CreativeTransactionEnvelope(
      transactionId: transaction.transactionId,
      schemaVersion: transaction.schemaVersion,
      source: transaction.source,
      intent: transaction.intent,
      projectId: transaction.projectId,
      compositionId: transaction.compositionId,
      baseRevision: transaction.baseRevision,
      operations: transaction.operations,
      target: normalizedTarget,
      idempotencyKey: transaction.idempotencyKey,
      proofLevel: transaction.proofLevel,
      basisSnapshotId: transaction.basisSnapshotId,
      basisCompositionRevision: transaction.basisCompositionRevision,
      basisGraphRevision: transaction.basisGraphRevision,
      basisFrame: transaction.basisFrame,
      basisTargetLayerId: transaction.basisTargetLayerId,
    ),
  );
}

bool _requiresResolvedLayerTarget(CreativeTransactionIntent intent) {
  return intent == CreativeTransactionIntent.layerUpdate ||
      intent == CreativeTransactionIntent.layerDelete ||
      intent == CreativeTransactionIntent.layerSelect ||
      intent == CreativeTransactionIntent.textUpdateContent ||
      intent == CreativeTransactionIntent.transformPatch ||
      intent == CreativeTransactionIntent.keyframeBatchApply ||
      intent == CreativeTransactionIntent.animationApplyRecipe ||
      intent == CreativeTransactionIntent.effectApply;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

CreativeApplyProof _buildProof(
  CreativeTransactionEnvelope transaction,
  CreativeApplyResult result,
) {
  if (!result.success) {
    return CreativeApplyProof(
      level: CreativeProofLevel.data,
      dataApplied: false,
      localGraphApplied: false,
      timelineVisible: false,
      frameEvaluated: false,
      visualProgramEmitted: false,
      rendererApplied: false,
      targetLayerId: transaction.target?.layerId,
      operationApplied: transaction.intent.name,
      createdLayerCount: 0,
      updatedLayerCount: 0,
    );
  }

  final isInsert = transaction.intent == CreativeTransactionIntent.textInsert ||
      transaction.intent == CreativeTransactionIntent.shapeInsert ||
      transaction.intent == CreativeTransactionIntent.backgroundSetSolid ||
      transaction.intent == CreativeTransactionIntent.layerInsert;
  final isUpdate =
      transaction.intent == CreativeTransactionIntent.layerUpdate ||
          transaction.intent == CreativeTransactionIntent.textUpdateContent ||
          transaction.intent == CreativeTransactionIntent.transformPatch ||
          transaction.intent == CreativeTransactionIntent.layerSelect;

  return CreativeApplyProof(
    level: CreativeProofLevel.graph,
    dataApplied: true,
    localGraphApplied: true,
    timelineVisible: true,
    frameEvaluated: true,
    visualProgramEmitted: true,
    rendererApplied: false,
    targetLayerId: transaction.target?.layerId,
    operationApplied: transaction.intent.name,
    createdLayerCount: isInsert ? 1 : 0,
    updatedLayerCount: isUpdate ? 1 : 0,
  );
}
