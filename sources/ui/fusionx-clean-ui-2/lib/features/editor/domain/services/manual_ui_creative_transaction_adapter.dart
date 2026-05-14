import '../models/creative_transaction_contract_models.dart';

enum ManualUiTransactionCommandKind {
  addBackgroundSolid,
  addText,
  addShape,
  selectLayer,
  moveLayer,
  resizeLayer,
  rotateLayer,
  setOpacity,
  setFillColor,
  editTextContent,
}

class ManualUiTransactionDraft {
  const ManualUiTransactionDraft({
    required this.kind,
    this.targetLayerId,
    this.payload = const <String, Object?>{},
  });

  final ManualUiTransactionCommandKind kind;
  final String? targetLayerId;
  final Map<String, Object?> payload;

  bool get hasTarget =>
      targetLayerId != null && targetLayerId!.trim().isNotEmpty;
}

class ManualUiTransactionBuildContext {
  const ManualUiTransactionBuildContext({
    required this.projectId,
    required this.compositionId,
    required this.baseRevision,
    required this.sequence,
  });

  final String projectId;
  final String compositionId;
  final int baseRevision;
  final int sequence;
}

class ManualUiCreativeTransactionAdapter {
  const ManualUiCreativeTransactionAdapter();

  CreativeTransactionEnvelope toEnvelope({
    required ManualUiTransactionBuildContext context,
    required ManualUiTransactionDraft draft,
  }) {
    final intent = _resolveIntent(draft.kind);
    final operation = CreativeTransactionOperation(
      kind: _operationKind(draft.kind),
      payload: _normalizedPayload(draft),
    );
    final target = _targetFor(draft);
    return CreativeTransactionEnvelope(
      transactionId: 'manual-${context.sequence}-${draft.kind.name}',
      schemaVersion: 1,
      source: CreativeTransactionSource.manualUi,
      intent: intent,
      projectId: context.projectId,
      compositionId: context.compositionId,
      baseRevision: context.baseRevision,
      target: target,
      operations: <CreativeTransactionOperation>[operation],
      idempotencyKey: 'manual.${context.sequence}.${draft.kind.name}',
      proofLevel: CreativeProofLevel.renderer,
    );
  }

  CreativeTransactionIntent _resolveIntent(ManualUiTransactionCommandKind kind) {
    return switch (kind) {
      ManualUiTransactionCommandKind.addBackgroundSolid =>
        CreativeTransactionIntent.backgroundSetSolid,
      ManualUiTransactionCommandKind.addText =>
        CreativeTransactionIntent.textInsert,
      ManualUiTransactionCommandKind.addShape =>
        CreativeTransactionIntent.shapeInsert,
      ManualUiTransactionCommandKind.selectLayer =>
        CreativeTransactionIntent.layerSelect,
      ManualUiTransactionCommandKind.moveLayer ||
      ManualUiTransactionCommandKind.resizeLayer ||
      ManualUiTransactionCommandKind.rotateLayer ||
      ManualUiTransactionCommandKind.setOpacity =>
        CreativeTransactionIntent.transformPatch,
      ManualUiTransactionCommandKind.setFillColor =>
        CreativeTransactionIntent.layerUpdate,
      ManualUiTransactionCommandKind.editTextContent =>
        CreativeTransactionIntent.textUpdateContent,
    };
  }

  String _operationKind(ManualUiTransactionCommandKind kind) {
    return switch (kind) {
      ManualUiTransactionCommandKind.addBackgroundSolid =>
        'background.set_solid',
      ManualUiTransactionCommandKind.addText => 'text.insert',
      ManualUiTransactionCommandKind.addShape => 'shape.insert',
      ManualUiTransactionCommandKind.selectLayer => 'layer.select',
      ManualUiTransactionCommandKind.moveLayer => 'transform.patch.position',
      ManualUiTransactionCommandKind.resizeLayer => 'transform.patch.size',
      ManualUiTransactionCommandKind.rotateLayer => 'transform.patch.rotation',
      ManualUiTransactionCommandKind.setOpacity => 'transform.patch.opacity',
      ManualUiTransactionCommandKind.setFillColor => 'layer.set_fill',
      ManualUiTransactionCommandKind.editTextContent => 'text.update_content',
    };
  }

  Map<String, Object?> _normalizedPayload(ManualUiTransactionDraft draft) {
    final payload = <String, Object?>{...draft.payload};
    switch (draft.kind) {
      case ManualUiTransactionCommandKind.setFillColor:
        final color = payload['color'] as String?;
        if (color != null) {
          payload['color'] = _normalizeHexColor(color);
        }
      case ManualUiTransactionCommandKind.addBackgroundSolid:
        final color = payload['color'] as String?;
        if (color != null) {
          payload['color'] = _normalizeHexColor(color);
        }
      case ManualUiTransactionCommandKind.addText:
      case ManualUiTransactionCommandKind.addShape:
      case ManualUiTransactionCommandKind.selectLayer:
      case ManualUiTransactionCommandKind.moveLayer:
      case ManualUiTransactionCommandKind.resizeLayer:
      case ManualUiTransactionCommandKind.rotateLayer:
      case ManualUiTransactionCommandKind.setOpacity:
      case ManualUiTransactionCommandKind.editTextContent:
        break;
    }
    return payload;
  }

  CreativeTargetRef? _targetFor(ManualUiTransactionDraft draft) {
    if (!draft.hasTarget) {
      return null;
    }
    return CreativeTargetRef(layerId: draft.targetLayerId);
  }
}

String _normalizeHexColor(String color) {
  final raw = color.trim();
  if (raw.isEmpty) {
    return '#FFFFFF';
  }
  var value = raw.startsWith('#') ? raw.substring(1) : raw;
  if (value.length == 3) {
    value = value.split('').map((ch) => '$ch$ch').join();
  }
  if (value.length > 6) {
    value = value.substring(0, 6);
  }
  final normalized = value.padRight(6, '0').toUpperCase();
  return '#$normalized';
}
