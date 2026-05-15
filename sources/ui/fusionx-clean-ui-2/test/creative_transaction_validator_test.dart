import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/creative_transaction_validator.dart';

void main() {
  group('CreativeTransactionValidator / DryRun', () {
    const validator = CreativeTransactionValidator();
    const dryRun = CreativeTransactionDryRunEngine();
    const baseContext = CreativeTransactionValidationContext(
      openCompositionId: 'composition-open',
      currentRevision: 10,
      canvasWidth: 1080,
      canvasHeight: 1920,
      rendererCapabilities: <String>{'motion', 'effects'},
    );

    test('wrong compositionId rejects', () {
      final result = validator.validate(
        _envelope(
          intent: CreativeTransactionIntent.textInsert,
          compositionId: 'composition-other',
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'text.insert'),
          ],
        ),
        baseContext,
      );
      expect(result.isValid, isFalse);
      expect(
        result.issues,
        contains('compositionId does not match open composition.'),
      );
    });

    test('stale revision rejects when conflict policy is reject', () {
      final result = validator.validate(
        _envelope(
          intent: CreativeTransactionIntent.textInsert,
          baseRevision: 8,
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'text.insert'),
          ],
        ),
        baseContext,
      );
      expect(result.isValid, isFalse);
      expect(result.conflictDetected, isTrue);
      expect(
        result.issues.any((issue) => issue.contains('baseRevision conflict')),
        isTrue,
      );
    });

    test('stale revision allowed when conflict policy is explicit rebase', () {
      final context = CreativeTransactionValidationContext(
        openCompositionId: baseContext.openCompositionId,
        currentRevision: baseContext.currentRevision,
        canvasWidth: baseContext.canvasWidth,
        canvasHeight: baseContext.canvasHeight,
        rendererCapabilities: baseContext.rendererCapabilities,
        conflictPolicy: CreativeTransactionConflictPolicy.allowRebase,
      );
      final result = validator.validate(
        _envelope(
          intent: CreativeTransactionIntent.textInsert,
          baseRevision: 7,
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'text.insert'),
          ],
        ),
        context,
      );
      expect(result.conflictDetected, isTrue);
      expect(result.issues, isEmpty);
      expect(result.isValid, isTrue);
    });

    test(
        'background square payload normalizes to composition bounds in dry-run',
        () {
      final result = dryRun.dryRun(
        _envelope(
          intent: CreativeTransactionIntent.backgroundSetSolid,
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'background.set_solid',
              payload: <String, Object?>{
                'spatialValidated': true,
                'coordinateSpace': 'centerOrigin',
                'x': 0,
                'y': 0,
                'width': 1080,
                'height': 1080,
              },
            ),
          ],
        ),
        baseContext,
      );
      final payload = result.normalizedEnvelope.operations.single.payload;
      expect(payload['width'], 1080);
      expect(payload['height'], 1920);
      expect(result.diff.normalizedBackgroundBounds, isTrue);
    });

    test('raw x/y without coordinate space rejects as ambiguous', () {
      final result = validator.validate(
        _envelope(
          intent: CreativeTransactionIntent.transformPatch,
          target: const CreativeTargetRef(layerId: 'text-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'transform.patch.position',
              payload: <String, Object?>{
                'spatialValidated': true,
                'x': 540,
                'y': 960,
              },
            ),
          ],
        ),
        baseContext,
      );
      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) => issue.contains('AMBIGUOUS_COORDINATE_SPACE'),
        ),
        isTrue,
      );
    });

    test('screenViewport is blocked for mcp writes', () {
      final result = validator.validate(
        _envelope(
          intent: CreativeTransactionIntent.transformPatch,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'transform.patch.position',
              payload: <String, Object?>{
                'spatialValidated': true,
                'coordinateSpace': 'screenViewport',
                'x': 120,
                'y': 240,
              },
            ),
          ],
        ),
        baseContext,
      );
      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) => issue.contains('UNSUPPORTED_COORDINATE_SPACE'),
        ),
        isTrue,
      );
    });

    test('screenViewport allowed for manual pointer input only', () {
      final result = validator.validate(
        _envelope(
          source: CreativeTransactionSource.manualUi,
          intent: CreativeTransactionIntent.transformPatch,
          target: const CreativeTargetRef(layerId: 'shape-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'transform.patch.position',
              payload: <String, Object?>{
                'coordinateSpace': 'screenViewport',
                'pointerInput': true,
                'x': 120,
                'y': 240,
              },
            ),
          ],
        ),
        baseContext,
      );
      expect(result.isValid, isTrue);
    });

    test('update intent without target rejects', () {
      final result = validator.validate(
        _envelope(
          intent: CreativeTransactionIntent.layerUpdate,
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'layer.update'),
          ],
        ),
        baseContext,
      );
      expect(result.isValid, isFalse);
      expect(
        result.issues,
        contains('target is required for this intent.'),
      );
    });

    test('insert intent with target rejects unless duplicate mode enabled', () {
      final rejected = validator.validate(
        _envelope(
          intent: CreativeTransactionIntent.layerInsert,
          target: const CreativeTargetRef(layerId: 'layer-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(kind: 'layer.insert'),
          ],
        ),
        baseContext,
      );
      expect(rejected.isValid, isFalse);
      expect(
        rejected.issues,
        contains('insert intent with target requires explicit duplicate mode.'),
      );

      final allowed = validator.validate(
        _envelope(
          intent: CreativeTransactionIntent.layerInsert,
          target: const CreativeTargetRef(layerId: 'layer-1'),
          operations: const <CreativeTransactionOperation>[
            CreativeTransactionOperation(
              kind: 'layer.insert',
              payload: <String, Object?>{'allowDuplicate': true},
            ),
          ],
        ),
        baseContext,
      );
      expect(allowed.isValid, isTrue);
    });
  });
}

CreativeTransactionEnvelope _envelope({
  CreativeTransactionSource source = CreativeTransactionSource.mcpAgent,
  required CreativeTransactionIntent intent,
  int baseRevision = 10,
  String compositionId = 'composition-open',
  CreativeTargetRef? target,
  required List<CreativeTransactionOperation> operations,
}) {
  return CreativeTransactionEnvelope(
    transactionId: 'tx-1',
    schemaVersion: 1,
    source: source,
    intent: intent,
    projectId: 'project-1',
    compositionId: compositionId,
    baseRevision: baseRevision,
    target: target,
    operations: operations,
  );
}
