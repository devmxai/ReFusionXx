import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/authoring_surface_transaction_compiler.dart';

void main() {
  group('AuthoringSurfaceTransactionCompiler', () {
    const compiler = AuthoringSurfaceTransactionCompiler();
    const context = AuthoringSurfaceBuildContext(
      projectId: 'project-1',
      compositionId: 'story-1',
      baseRevision: 3,
      seed: 100,
    );

    test('scene program and template use stable app-owned layer ids', () {
      final sceneTx = compiler.compile(
        context: context,
        source: AuthoringSurfaceSource.sceneProgram,
        layers: const <AuthoringLayerSpec>[
          AuthoringLayerSpec(
            sourceNodeId: 'hero-title',
            kind: 'text',
            payload: <String, Object?>{'text': 'Hello'},
          ),
        ],
      );
      final templateTx = compiler.compile(
        context: context,
        source: AuthoringSurfaceSource.template,
        layers: const <AuthoringLayerSpec>[
          AuthoringLayerSpec(
            sourceNodeId: 'hero-title',
            kind: 'text',
            payload: <String, Object?>{'text': 'Hello'},
          ),
        ],
      );

      expect(sceneTx.first.target?.layerId, 'app.sceneProgram.hero-title');
      expect(templateTx.first.target?.layerId, 'app.template.hero-title');
    });

    test('text insert + recipe + effect produce same target identity chain', () {
      final transactions = compiler.compile(
        context: context,
        source: AuthoringSurfaceSource.sceneProgram,
        layers: const <AuthoringLayerSpec>[
          AuthoringLayerSpec(
            sourceNodeId: 'title',
            kind: 'text',
            payload: <String, Object?>{'text': 'TEST'},
            animationRecipeId: 'popUp',
            effectType: 'glow',
            effectPayload: <String, Object?>{'radius': 12},
          ),
        ],
      );

      expect(transactions.length, 3);
      final layerId = transactions.first.target?.layerId;
      expect(layerId, isNotNull);
      expect(transactions[1].target?.layerId, layerId);
      expect(transactions[2].target?.layerId, layerId);
      expect(
        transactions.map((tx) => tx.intent).toList(growable: false),
        <CreativeTransactionIntent>[
          CreativeTransactionIntent.textInsert,
          CreativeTransactionIntent.animationApplyRecipe,
          CreativeTransactionIntent.effectApply,
        ],
      );
    });

    test('media import uses layerInsert intent and keeps source alias', () {
      final transactions = compiler.compile(
        context: context,
        source: AuthoringSurfaceSource.importMedia,
        layers: const <AuthoringLayerSpec>[
          AuthoringLayerSpec(
            sourceNodeId: 'media-asset-1',
            kind: 'video',
            payload: <String, Object?>{'assetId': 'asset-1'},
          ),
        ],
      );

      expect(transactions.length, 1);
      expect(transactions.first.intent, CreativeTransactionIntent.layerInsert);
      expect(transactions.first.target?.layerAlias, 'media-asset-1');
      expect(
        transactions.first.operations.single.payload['sourceNodeId'],
        'media-asset-1',
      );
    });
  });
}
