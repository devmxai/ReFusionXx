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
    final result = applyEngine.apply(
      state: state,
      context: context,
      transaction: transaction,
      ledger: ledger,
    );
    return LocalMcpApplyResponse(
      result: result,
      proof: _buildProof(transaction, result),
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
  final isUpdate = transaction.intent == CreativeTransactionIntent.layerUpdate ||
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
