import '../models/creative_transaction_contract_models.dart';
import 'unified_creative_apply_engine.dart';

class FrameEvaluationProofTarget {
  const FrameEvaluationProofTarget({
    required this.layerId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String layerId;
  final double x;
  final double y;
  final double width;
  final double height;
}

class RendererProofObservation {
  const RendererProofObservation({
    this.rendererObserved = false,
    this.observedLayerIds = const <String>{},
    this.frameTargets = const <FrameEvaluationProofTarget>[],
    this.rendererCapabilities = const <String>{},
    this.latencyMs = 0,
  });

  final bool rendererObserved;
  final Set<String> observedLayerIds;
  final List<FrameEvaluationProofTarget> frameTargets;
  final Set<String> rendererCapabilities;
  final int latencyMs;
}

class RendererProofLedgerEntry {
  const RendererProofLedgerEntry({
    required this.transactionId,
    required this.proof,
    required this.latencyMs,
  });

  final String transactionId;
  final CreativeApplyProof proof;
  final int latencyMs;
}

class RendererProofLedger {
  const RendererProofLedger({
    this.entries = const <RendererProofLedgerEntry>[],
  });

  final List<RendererProofLedgerEntry> entries;

  RendererProofLedger append(RendererProofLedgerEntry entry) {
    return RendererProofLedger(entries: <RendererProofLedgerEntry>[...entries, entry]);
  }
}

class ApplyLatencyMetrics {
  const ApplyLatencyMetrics({
    this.samplesMs = const <int>[],
  });

  final List<int> samplesMs;

  ApplyLatencyMetrics add(int latencyMs) {
    return ApplyLatencyMetrics(samplesMs: <int>[...samplesMs, latencyMs]);
  }

  int get p95Ms {
    if (samplesMs.isEmpty) {
      return 0;
    }
    final sorted = <int>[...samplesMs]..sort();
    final index = (sorted.length * 0.95).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

class PreviewInvalidationController {
  const PreviewInvalidationController();

  Set<String> invalidatedLayerIds(CreativeApplyResult result) {
    if (!result.success || !result.diff.wouldMutate) {
      return const <String>{};
    }
    return result.diff.mutatedLayerIds.toSet();
  }
}

class CreativeRendererProofEvaluator {
  const CreativeRendererProofEvaluator({
    this.invalidationController = const PreviewInvalidationController(),
  });

  final PreviewInvalidationController invalidationController;

  CreativeApplyProof evaluate({
    required CreativeTransactionEnvelope transaction,
    required CreativeApplyResult result,
    required RendererProofObservation observation,
  }) {
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
      );
    }

    final invalidated = invalidationController.invalidatedLayerIds(result);
    final targetLayerId = transaction.target?.layerId;
    final visibleIntent = _isVisibleIntent(transaction.intent);
    final targetObserved =
        !_hasText(targetLayerId) || observation.observedLayerIds.contains(targetLayerId);
    final hasFrameTarget =
        !_hasText(targetLayerId) || observation.frameTargets.any((t) => t.layerId == targetLayerId);
    final rendererApplied =
        !visibleIntent || (observation.rendererObserved && targetObserved && hasFrameTarget);
    final level = rendererApplied ? CreativeProofLevel.renderer : CreativeProofLevel.graph;

    return CreativeApplyProof(
      level: level,
      dataApplied: true,
      localGraphApplied: true,
      timelineVisible: invalidated.isNotEmpty,
      frameEvaluated: hasFrameTarget,
      visualProgramEmitted: invalidated.isNotEmpty,
      rendererApplied: rendererApplied,
      targetLayerId: targetLayerId,
      operationApplied: transaction.intent.name,
      createdLayerCount: _isInsertIntent(transaction.intent) ? 1 : 0,
      updatedLayerCount: _isUpdateIntent(transaction.intent) ? 1 : 0,
    );
  }
}

bool _isVisibleIntent(CreativeTransactionIntent intent) {
  return switch (intent) {
    CreativeTransactionIntent.layerInsert ||
    CreativeTransactionIntent.layerUpdate ||
    CreativeTransactionIntent.layerDelete ||
    CreativeTransactionIntent.backgroundSetSolid ||
    CreativeTransactionIntent.shapeInsert ||
    CreativeTransactionIntent.textInsert ||
    CreativeTransactionIntent.textUpdateContent ||
    CreativeTransactionIntent.transformPatch ||
    CreativeTransactionIntent.keyframeBatchApply ||
    CreativeTransactionIntent.animationApplyRecipe ||
    CreativeTransactionIntent.effectApply =>
      true,
    CreativeTransactionIntent.layerSelect => false,
  };
}

bool _isInsertIntent(CreativeTransactionIntent intent) {
  return intent == CreativeTransactionIntent.backgroundSetSolid ||
      intent == CreativeTransactionIntent.shapeInsert ||
      intent == CreativeTransactionIntent.textInsert ||
      intent == CreativeTransactionIntent.layerInsert;
}

bool _isUpdateIntent(CreativeTransactionIntent intent) {
  return intent == CreativeTransactionIntent.layerUpdate ||
      intent == CreativeTransactionIntent.textUpdateContent ||
      intent == CreativeTransactionIntent.transformPatch ||
      intent == CreativeTransactionIntent.keyframeBatchApply ||
      intent == CreativeTransactionIntent.animationApplyRecipe ||
      intent == CreativeTransactionIntent.effectApply;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
