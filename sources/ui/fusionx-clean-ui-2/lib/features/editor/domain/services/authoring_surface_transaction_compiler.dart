import '../models/creative_transaction_contract_models.dart';

enum AuthoringSurfaceSource {
  sceneProgram,
  directorPlan,
  pasteScript,
  template,
  importMedia,
}

class AuthoringSurfaceBuildContext {
  const AuthoringSurfaceBuildContext({
    required this.projectId,
    required this.compositionId,
    required this.baseRevision,
    required this.seed,
  });

  final String projectId;
  final String compositionId;
  final int baseRevision;
  final int seed;
}

class AuthoringLayerSpec {
  const AuthoringLayerSpec({
    required this.sourceNodeId,
    required this.kind,
    this.payload = const <String, Object?>{},
    this.animationRecipeId,
    this.effectType,
    this.effectPayload = const <String, Object?>{},
  });

  final String sourceNodeId;
  final String kind;
  final Map<String, Object?> payload;
  final String? animationRecipeId;
  final String? effectType;
  final Map<String, Object?> effectPayload;
}

class AuthoringSurfaceTransactionCompiler {
  const AuthoringSurfaceTransactionCompiler();

  List<CreativeTransactionEnvelope> compile({
    required AuthoringSurfaceBuildContext context,
    required AuthoringSurfaceSource source,
    required List<AuthoringLayerSpec> layers,
  }) {
    final transactions = <CreativeTransactionEnvelope>[];
    var sequence = context.seed;
    for (final spec in layers) {
      final layerId = _layerId(source, spec.sourceNodeId);
      final insertIntent = _insertIntentFor(spec.kind);
      final insertOp = _insertOperationFor(spec.kind);
      transactions.add(
        CreativeTransactionEnvelope(
          transactionId: '${source.name}-$sequence-${spec.sourceNodeId}-insert',
          schemaVersion: 1,
          source: _toTxSource(source),
          intent: insertIntent,
          projectId: context.projectId,
          compositionId: context.compositionId,
          baseRevision: context.baseRevision,
          target: CreativeTargetRef(layerId: layerId, layerAlias: spec.sourceNodeId),
          operations: <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: insertOp,
              payload: <String, Object?>{
                ...spec.payload,
                'layerId': layerId,
                'sourceNodeId': spec.sourceNodeId,
              },
            ),
          ],
          idempotencyKey: '${source.name}.$sequence.${spec.sourceNodeId}.insert',
        ),
      );
      sequence++;

      if (_hasText(spec.animationRecipeId)) {
        transactions.add(
          CreativeTransactionEnvelope(
            transactionId:
                '${source.name}-$sequence-${spec.sourceNodeId}-animation',
            schemaVersion: 1,
            source: _toTxSource(source),
            intent: CreativeTransactionIntent.animationApplyRecipe,
            projectId: context.projectId,
            compositionId: context.compositionId,
            baseRevision: context.baseRevision,
            target: CreativeTargetRef(layerId: layerId, layerAlias: spec.sourceNodeId),
            operations: <CreativeTransactionOperation>[
              CreativeTransactionOperation(
                kind: 'animation.apply_recipe',
                payload: <String, Object?>{
                  'recipeId': spec.animationRecipeId,
                  'layerId': layerId,
                },
              ),
            ],
            idempotencyKey:
                '${source.name}.$sequence.${spec.sourceNodeId}.animation',
          ),
        );
        sequence++;
      }

      if (_hasText(spec.effectType)) {
        transactions.add(
          CreativeTransactionEnvelope(
            transactionId: '${source.name}-$sequence-${spec.sourceNodeId}-effect',
            schemaVersion: 1,
            source: _toTxSource(source),
            intent: CreativeTransactionIntent.effectApply,
            projectId: context.projectId,
            compositionId: context.compositionId,
            baseRevision: context.baseRevision,
            target: CreativeTargetRef(layerId: layerId, layerAlias: spec.sourceNodeId),
            operations: <CreativeTransactionOperation>[
              CreativeTransactionOperation(
                kind: 'effect.apply',
                payload: <String, Object?>{
                  'effectType': spec.effectType,
                  ...spec.effectPayload,
                  'layerId': layerId,
                },
              ),
            ],
            idempotencyKey: '${source.name}.$sequence.${spec.sourceNodeId}.effect',
          ),
        );
      }
      sequence++;
    }
    return transactions;
  }
}

CreativeTransactionSource _toTxSource(AuthoringSurfaceSource source) {
  return switch (source) {
    AuthoringSurfaceSource.sceneProgram ||
    AuthoringSurfaceSource.directorPlan ||
    AuthoringSurfaceSource.pasteScript =>
      CreativeTransactionSource.script,
    AuthoringSurfaceSource.template => CreativeTransactionSource.template,
    AuthoringSurfaceSource.importMedia => CreativeTransactionSource.import,
  };
}

CreativeTransactionIntent _insertIntentFor(String kind) {
  final normalized = kind.trim().toLowerCase();
  return switch (normalized) {
    'background' || 'solid' => CreativeTransactionIntent.backgroundSetSolid,
    'text' => CreativeTransactionIntent.textInsert,
    'shape' => CreativeTransactionIntent.shapeInsert,
    _ => CreativeTransactionIntent.layerInsert,
  };
}

String _insertOperationFor(String kind) {
  final normalized = kind.trim().toLowerCase();
  return switch (normalized) {
    'background' || 'solid' => 'background.set_solid',
    'text' => 'text.insert',
    'shape' => 'shape.insert',
    _ => 'layer.insert',
  };
}

String _layerId(AuthoringSurfaceSource source, String sourceNodeId) {
  final normalized = sourceNodeId.trim().isEmpty ? 'node' : sourceNodeId.trim();
  return 'app.${source.name}.$normalized';
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
