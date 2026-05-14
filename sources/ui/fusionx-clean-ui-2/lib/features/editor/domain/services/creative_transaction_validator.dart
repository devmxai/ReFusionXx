import '../models/creative_transaction_contract_models.dart';

enum CreativeTransactionConflictPolicy {
  reject,
  allowRebase,
}

class CreativeTransactionValidationContext {
  const CreativeTransactionValidationContext({
    required this.openCompositionId,
    required this.currentRevision,
    required this.canvasWidth,
    required this.canvasHeight,
    this.rendererCapabilities = const <String>{},
    this.conflictPolicy = CreativeTransactionConflictPolicy.reject,
  });

  final String openCompositionId;
  final int currentRevision;
  final int canvasWidth;
  final int canvasHeight;
  final Set<String> rendererCapabilities;
  final CreativeTransactionConflictPolicy conflictPolicy;
}

class CreativeTransactionValidationResult {
  const CreativeTransactionValidationResult({
    required this.isValid,
    this.issues = const <String>[],
    this.conflictDetected = false,
  });

  final bool isValid;
  final List<String> issues;
  final bool conflictDetected;
}

class CreativeTransactionDiff {
  const CreativeTransactionDiff({
    this.wouldMutate = false,
    this.mutatedLayerIds = const <String>[],
    this.normalizedBackgroundBounds = false,
  });

  final bool wouldMutate;
  final List<String> mutatedLayerIds;
  final bool normalizedBackgroundBounds;
}

class CreativeTransactionDryRunResult {
  const CreativeTransactionDryRunResult({
    required this.validation,
    required this.normalizedEnvelope,
    required this.diff,
  });

  final CreativeTransactionValidationResult validation;
  final CreativeTransactionEnvelope normalizedEnvelope;
  final CreativeTransactionDiff diff;
}

class CreativeTransactionValidator {
  const CreativeTransactionValidator();

  CreativeTransactionValidationResult validate(
    CreativeTransactionEnvelope envelope,
    CreativeTransactionValidationContext context,
  ) {
    final issues = <String>[...envelope.validate()];
    var conflictDetected = false;

    if (envelope.compositionId != context.openCompositionId) {
      issues.add('compositionId does not match open composition.');
    }
    if (envelope.baseRevision != context.currentRevision) {
      conflictDetected = true;
      if (context.conflictPolicy == CreativeTransactionConflictPolicy.reject) {
        issues.add(
          'baseRevision conflict: expected ${context.currentRevision}, got ${envelope.baseRevision}.',
        );
      }
    }
    if (envelope.intent == CreativeTransactionIntent.layerInsert &&
        (envelope.target?.hasIdentity ?? false)) {
      final hasExplicitDuplicate = envelope.operations.any((operation) {
        final payload = operation.payload;
        return payload['allowDuplicate'] == true;
      });
      if (!hasExplicitDuplicate) {
        issues
            .add('insert intent with target requires explicit duplicate mode.');
      }
    }
    if (_requiresRendererCapability(envelope.intent)) {
      final hasCapability = context.rendererCapabilities.contains('motion') ||
          context.rendererCapabilities.contains('effects');
      if (!hasCapability) {
        issues
            .add('renderer capability declaration missing for motion/effect.');
      }
    }

    return CreativeTransactionValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      conflictDetected: conflictDetected,
    );
  }
}

class CreativeTransactionDryRunEngine {
  const CreativeTransactionDryRunEngine({
    this.validator = const CreativeTransactionValidator(),
  });

  final CreativeTransactionValidator validator;

  CreativeTransactionDryRunResult dryRun(
    CreativeTransactionEnvelope envelope,
    CreativeTransactionValidationContext context,
  ) {
    var normalizedBackgroundBounds = false;
    final normalizedOperations = envelope.operations.map((operation) {
      if (envelope.intent != CreativeTransactionIntent.backgroundSetSolid) {
        return operation;
      }
      final payload = Map<String, Object?>.of(operation.payload);
      final width = _asInt(payload['width']);
      final height = _asInt(payload['height']);
      final x = _asInt(payload['x']);
      final y = _asInt(payload['y']);
      final shouldNormalize = width != context.canvasWidth ||
          height != context.canvasHeight ||
          x != 0 ||
          y != 0;
      if (!shouldNormalize) {
        return operation;
      }
      normalizedBackgroundBounds = true;
      payload['x'] = 0;
      payload['y'] = 0;
      payload['width'] = context.canvasWidth;
      payload['height'] = context.canvasHeight;
      return CreativeTransactionOperation(
        kind: operation.kind,
        payload: payload,
      );
    }).toList(growable: false);

    final normalizedEnvelope = CreativeTransactionEnvelope(
      transactionId: envelope.transactionId,
      schemaVersion: envelope.schemaVersion,
      source: envelope.source,
      intent: envelope.intent,
      projectId: envelope.projectId,
      compositionId: envelope.compositionId,
      baseRevision: envelope.baseRevision,
      target: envelope.target,
      operations: normalizedOperations,
      idempotencyKey: envelope.idempotencyKey,
      proofLevel: envelope.proofLevel,
    );

    final validation = validator.validate(normalizedEnvelope, context);
    final layerId = normalizedEnvelope.target?.layerId;

    final diff = CreativeTransactionDiff(
      wouldMutate: validation.isValid,
      mutatedLayerIds:
          _hasText(layerId) ? <String>[layerId!] : const <String>[],
      normalizedBackgroundBounds: normalizedBackgroundBounds,
    );

    return CreativeTransactionDryRunResult(
      validation: validation,
      normalizedEnvelope: normalizedEnvelope,
      diff: diff,
    );
  }
}

bool _requiresRendererCapability(CreativeTransactionIntent intent) {
  return intent == CreativeTransactionIntent.animationApplyRecipe ||
      intent == CreativeTransactionIntent.effectApply ||
      intent == CreativeTransactionIntent.keyframeBatchApply;
}

int _asInt(Object? value) {
  if (value is num && value.isFinite) {
    return value.round();
  }
  return 0;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
