import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/creative_transaction_contract_models.dart';
import 'package:refusion_app/features/editor/domain/services/manual_ui_creative_transaction_adapter.dart';

void main() {
  group('ManualUiCreativeTransactionAdapter', () {
    const adapter = ManualUiCreativeTransactionAdapter();
    const context = ManualUiTransactionBuildContext(
      projectId: 'project-1',
      compositionId: 'composition-1',
      baseRevision: 7,
      sequence: 42,
    );

    test('add background builds backgroundSetSolid transaction', () {
      final tx = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.addBackgroundSolid,
          payload: <String, Object?>{'color': '#fff'},
        ),
      );
      expect(tx.source, CreativeTransactionSource.manualUi);
      expect(tx.intent, CreativeTransactionIntent.backgroundSetSolid);
      expect(tx.target, isNull);
      expect(tx.operations.single.kind, 'background.set_solid');
      expect(tx.operations.single.payload['color'], '#FFFFFF');
    });

    test('add text builds textInsert transaction', () {
      final tx = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.addText,
          payload: <String, Object?>{'text': 'Test'},
        ),
      );
      expect(tx.intent, CreativeTransactionIntent.textInsert);
      expect(tx.operations.single.kind, 'text.insert');
      expect(tx.target, isNull);
    });

    test('edit text content maps to textUpdateContent with target identity', () {
      final tx = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.editTextContent,
          targetLayerId: 'text-1',
          payload: <String, Object?>{'text': 'Updated'},
        ),
      );
      expect(tx.intent, CreativeTransactionIntent.textUpdateContent);
      expect(tx.operations.single.kind, 'text.update_content');
      expect(tx.target?.layerId, 'text-1');
    });

    test('set fill color maps to layerUpdate with target identity', () {
      final tx = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.setFillColor,
          targetLayerId: 'shape-1',
          payload: <String, Object?>{'color': 'ff00aa'},
        ),
      );
      expect(tx.intent, CreativeTransactionIntent.layerUpdate);
      expect(tx.operations.single.kind, 'layer.set_fill');
      expect(tx.target?.layerId, 'shape-1');
      expect(tx.operations.single.payload['color'], '#FF00AA');
    });

    test('move/resize/rotate/opacity map to transformPatch intents', () {
      final move = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.moveLayer,
          targetLayerId: 'shape-1',
        ),
      );
      final resize = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.resizeLayer,
          targetLayerId: 'shape-1',
        ),
      );
      final rotate = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.rotateLayer,
          targetLayerId: 'shape-1',
        ),
      );
      final opacity = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.setOpacity,
          targetLayerId: 'shape-1',
        ),
      );

      expect(move.intent, CreativeTransactionIntent.transformPatch);
      expect(resize.intent, CreativeTransactionIntent.transformPatch);
      expect(rotate.intent, CreativeTransactionIntent.transformPatch);
      expect(opacity.intent, CreativeTransactionIntent.transformPatch);
    });

    test('select layer maps to layerSelect with target', () {
      final tx = adapter.toEnvelope(
        context: context,
        draft: const ManualUiTransactionDraft(
          kind: ManualUiTransactionCommandKind.selectLayer,
          targetLayerId: 'shape-2',
        ),
      );
      expect(tx.intent, CreativeTransactionIntent.layerSelect);
      expect(tx.operations.single.kind, 'layer.select');
      expect(tx.target?.layerId, 'shape-2');
    });
  });
}
