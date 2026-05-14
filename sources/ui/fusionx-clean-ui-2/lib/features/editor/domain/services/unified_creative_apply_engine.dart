import '../models/creative_transaction_contract_models.dart';
import 'creative_transaction_validator.dart';

class CreativeApplyContext {
  const CreativeApplyContext({
    required this.projectId,
    required this.compositionSpec,
    required this.currentRevision,
    this.rendererCapabilities = const <String>{'motion', 'effects'},
  });

  final String projectId;
  final CreativeCompositionSpec compositionSpec;
  final int currentRevision;
  final Set<String> rendererCapabilities;
}

class CreativeAtomicMutationScope {
  const CreativeAtomicMutationScope();

  UnifiedCreativeState begin(UnifiedCreativeState state) => state.copy();
}

class CreativeRevisionManager {
  const CreativeRevisionManager();

  int nextRevision(int current) => current + 1;
}

class CreativeApplyLedgerEntry {
  const CreativeApplyLedgerEntry({
    required this.transactionId,
    required this.intent,
    required this.result,
    required this.revisionAfter,
  });

  final String transactionId;
  final CreativeTransactionIntent intent;
  final String result;
  final int revisionAfter;
}

class CreativeApplyLedger {
  const CreativeApplyLedger({this.entries = const <CreativeApplyLedgerEntry>[]});

  final List<CreativeApplyLedgerEntry> entries;

  CreativeApplyLedger append(CreativeApplyLedgerEntry entry) {
    return CreativeApplyLedger(
      entries: <CreativeApplyLedgerEntry>[...entries, entry],
    );
  }
}

class CreativeApplyResult {
  const CreativeApplyResult({
    required this.success,
    required this.state,
    required this.validation,
    required this.diff,
    required this.ledger,
    this.error = '',
  });

  final bool success;
  final UnifiedCreativeState state;
  final CreativeTransactionValidationResult validation;
  final CreativeTransactionDiff diff;
  final CreativeApplyLedger ledger;
  final String error;
}

class UnifiedCreativeLayerNode {
  const UnifiedCreativeLayerNode({
    required this.identity,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
    this.fillColor = '#FFFFFF',
    this.text = '',
  });

  final CreativeLayerIdentity identity;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final double opacity;
  final String fillColor;
  final String text;

  UnifiedCreativeLayerNode copyWith({
    CreativeLayerIdentity? identity,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? opacity,
    String? fillColor,
    String? text,
  }) {
    return UnifiedCreativeLayerNode(
      identity: identity ?? this.identity,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      opacity: opacity ?? this.opacity,
      fillColor: fillColor ?? this.fillColor,
      text: text ?? this.text,
    );
  }
}

class UnifiedCreativeTimelineClip {
  const UnifiedCreativeTimelineClip({
    required this.clipId,
    required this.layerId,
    required this.trackId,
    required this.startMs,
    required this.durationMs,
  });

  final String clipId;
  final String layerId;
  final String trackId;
  final int startMs;
  final int durationMs;
}

class UnifiedCreativeState {
  const UnifiedCreativeState({
    required this.projectId,
    required this.compositionId,
    required this.revision,
    this.layers = const <String, UnifiedCreativeLayerNode>{},
    this.timeline = const <UnifiedCreativeTimelineClip>[],
    this.selectedLayerId,
  });

  final String projectId;
  final String compositionId;
  final int revision;
  final Map<String, UnifiedCreativeLayerNode> layers;
  final List<UnifiedCreativeTimelineClip> timeline;
  final String? selectedLayerId;

  UnifiedCreativeState copy({
    String? projectId,
    String? compositionId,
    int? revision,
    Map<String, UnifiedCreativeLayerNode>? layers,
    List<UnifiedCreativeTimelineClip>? timeline,
    String? selectedLayerId,
    bool clearSelection = false,
  }) {
    return UnifiedCreativeState(
      projectId: projectId ?? this.projectId,
      compositionId: compositionId ?? this.compositionId,
      revision: revision ?? this.revision,
      layers: layers ?? this.layers,
      timeline: timeline ?? this.timeline,
      selectedLayerId: clearSelection
          ? null
          : (selectedLayerId ?? this.selectedLayerId),
    );
  }

  UnifiedCreativeState copyWithRevision(int nextRevision) {
    return copy(revision: nextRevision);
  }
}

class UnifiedCreativeApplyEngine {
  const UnifiedCreativeApplyEngine({
    this.validator = const CreativeTransactionValidator(),
    this.dryRunEngine = const CreativeTransactionDryRunEngine(),
    this.atomicScope = const CreativeAtomicMutationScope(),
    this.revisionManager = const CreativeRevisionManager(),
  });

  final CreativeTransactionValidator validator;
  final CreativeTransactionDryRunEngine dryRunEngine;
  final CreativeAtomicMutationScope atomicScope;
  final CreativeRevisionManager revisionManager;

  CreativeApplyResult apply({
    required UnifiedCreativeState state,
    required CreativeApplyContext context,
    required CreativeTransactionEnvelope transaction,
    CreativeApplyLedger ledger = const CreativeApplyLedger(),
  }) {
    final validationContext = CreativeTransactionValidationContext(
      openCompositionId: context.compositionSpec.compositionId,
      currentRevision: state.revision,
      canvasWidth: context.compositionSpec.width,
      canvasHeight: context.compositionSpec.height,
      rendererCapabilities: context.rendererCapabilities,
      conflictPolicy: CreativeTransactionConflictPolicy.reject,
    );
    final dryRun = dryRunEngine.dryRun(transaction, validationContext);
    if (!dryRun.validation.isValid) {
      return CreativeApplyResult(
        success: false,
        state: state,
        validation: dryRun.validation,
        diff: const CreativeTransactionDiff(),
        ledger: ledger.append(
          CreativeApplyLedgerEntry(
            transactionId: transaction.transactionId,
            intent: transaction.intent,
            result: 'failed_validation',
            revisionAfter: state.revision,
          ),
        ),
        error: dryRun.validation.issues.join(' | '),
      );
    }

    final draft = atomicScope.begin(state);
    final next = _applyDraft(draft, context, dryRun.normalizedEnvelope);
    final nextRevision = revisionManager.nextRevision(state.revision);
    final committed = next.copyWithRevision(nextRevision);
    final diff = CreativeTransactionDiff(
      wouldMutate: true,
      mutatedLayerIds: _mutatedLayerIds(transaction),
      normalizedBackgroundBounds: dryRun.diff.normalizedBackgroundBounds,
    );
    return CreativeApplyResult(
      success: true,
      state: committed,
      validation: dryRun.validation,
      diff: diff,
      ledger: ledger.append(
        CreativeApplyLedgerEntry(
          transactionId: transaction.transactionId,
          intent: transaction.intent,
          result: 'applied',
          revisionAfter: committed.revision,
        ),
      ),
    );
  }

  UnifiedCreativeState _applyDraft(
    UnifiedCreativeState draft,
    CreativeApplyContext context,
    CreativeTransactionEnvelope transaction,
  ) {
    return switch (transaction.intent) {
      CreativeTransactionIntent.backgroundSetSolid =>
        _applyBackgroundSetSolid(draft, context, transaction),
      CreativeTransactionIntent.shapeInsert =>
        _applyShapeInsert(draft, context, transaction),
      CreativeTransactionIntent.textInsert =>
        _applyTextInsert(draft, context, transaction),
      CreativeTransactionIntent.textUpdateContent =>
        _applyTextUpdate(draft, transaction),
      CreativeTransactionIntent.transformPatch =>
        _applyTransformPatch(draft, transaction),
      CreativeTransactionIntent.layerSelect =>
        _applySelectLayer(draft, transaction),
      _ => draft,
    };
  }

  UnifiedCreativeState _applyBackgroundSetSolid(
    UnifiedCreativeState draft,
    CreativeApplyContext context,
    CreativeTransactionEnvelope transaction,
  ) {
    final payload = transaction.operations.isEmpty
        ? const <String, Object?>{}
        : transaction.operations.first.payload;
    final layerId =
        transaction.target?.layerId ?? 'background-${draft.revision + 1}';
    final color = (payload['color'] as String?) ?? '#FFFFFF';
    final identity = CreativeLayerIdentity(
      layerId: layerId,
      kind: 'solid',
      compositionId: draft.compositionId,
      timelineTrackId: 'shape',
      zOrder: -1000,
      createdBy: transaction.source,
      createdAtRevision: draft.revision + 1,
      updatedAtRevision: draft.revision + 1,
    );
    final node = UnifiedCreativeLayerNode(
      identity: identity,
      x: 0,
      y: 0,
      width: context.compositionSpec.width.toDouble(),
      height: context.compositionSpec.height.toDouble(),
      fillColor: color,
      opacity: 1,
    );
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: node};
    final timeline = <UnifiedCreativeTimelineClip>[
      ...draft.timeline.where((clip) => clip.layerId != layerId),
      UnifiedCreativeTimelineClip(
        clipId: 'clip-$layerId',
        layerId: layerId,
        trackId: 'shape',
        startMs: 0,
        durationMs: context.compositionSpec.durationMs,
      ),
    ];
    return draft.copy(
      layers: layers,
      timeline: timeline,
      selectedLayerId: layerId,
    );
  }

  UnifiedCreativeState _applyShapeInsert(
    UnifiedCreativeState draft,
    CreativeApplyContext context,
    CreativeTransactionEnvelope transaction,
  ) {
    final payload = transaction.operations.first.payload;
    final layerId = transaction.target?.layerId ?? 'shape-${draft.revision + 1}';
    final identity = CreativeLayerIdentity(
      layerId: layerId,
      kind: 'shape',
      compositionId: draft.compositionId,
      timelineTrackId: 'shape',
      zOrder: 0,
      createdBy: transaction.source,
      createdAtRevision: draft.revision + 1,
      updatedAtRevision: draft.revision + 1,
    );
    final node = UnifiedCreativeLayerNode(
      identity: identity,
      x: _asDouble(payload['x'], context.compositionSpec.width / 2),
      y: _asDouble(payload['y'], context.compositionSpec.height / 2),
      width: _asDouble(payload['width'], 320),
      height: _asDouble(payload['height'], 320),
      fillColor: (payload['fillColor'] as String?) ?? '#FFFFFF',
      opacity: _asDouble(payload['opacity'], 1),
    );
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: node};
    final timeline = <UnifiedCreativeTimelineClip>[
      ...draft.timeline,
      UnifiedCreativeTimelineClip(
        clipId: 'clip-$layerId',
        layerId: layerId,
        trackId: 'shape',
        startMs: 0,
        durationMs: context.compositionSpec.durationMs,
      ),
    ];
    return draft.copy(layers: layers, timeline: timeline, selectedLayerId: layerId);
  }

  UnifiedCreativeState _applyTextInsert(
    UnifiedCreativeState draft,
    CreativeApplyContext context,
    CreativeTransactionEnvelope transaction,
  ) {
    final payload = transaction.operations.first.payload;
    final layerId = transaction.target?.layerId ?? 'text-${draft.revision + 1}';
    final identity = CreativeLayerIdentity(
      layerId: layerId,
      kind: 'text',
      compositionId: draft.compositionId,
      timelineTrackId: 'text',
      zOrder: 10,
      createdBy: transaction.source,
      createdAtRevision: draft.revision + 1,
      updatedAtRevision: draft.revision + 1,
    );
    final node = UnifiedCreativeLayerNode(
      identity: identity,
      x: _asDouble(payload['x'], context.compositionSpec.width / 2),
      y: _asDouble(payload['y'], context.compositionSpec.height / 2),
      width: _asDouble(payload['width'], 500),
      height: _asDouble(payload['height'], 140),
      text: (payload['text'] as String?) ?? '',
      fillColor: (payload['color'] as String?) ?? '#FFFFFF',
    );
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: node};
    final timeline = <UnifiedCreativeTimelineClip>[
      ...draft.timeline,
      UnifiedCreativeTimelineClip(
        clipId: 'clip-$layerId',
        layerId: layerId,
        trackId: 'text',
        startMs: 0,
        durationMs: context.compositionSpec.durationMs,
      ),
    ];
    return draft.copy(layers: layers, timeline: timeline, selectedLayerId: layerId);
  }

  UnifiedCreativeState _applyTextUpdate(
    UnifiedCreativeState draft,
    CreativeTransactionEnvelope transaction,
  ) {
    final layerId = transaction.target?.layerId ?? '';
    final current = draft.layers[layerId];
    if (current == null) {
      return draft;
    }
    final payload = transaction.operations.first.payload;
    final updated = current.copyWith(
      text: (payload['text'] as String?) ?? current.text,
      fillColor: (payload['color'] as String?) ?? current.fillColor,
    );
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: updated};
    return draft.copy(layers: layers, selectedLayerId: layerId);
  }

  UnifiedCreativeState _applyTransformPatch(
    UnifiedCreativeState draft,
    CreativeTransactionEnvelope transaction,
  ) {
    final layerId = transaction.target?.layerId ?? '';
    final current = draft.layers[layerId];
    if (current == null) {
      return draft;
    }
    final payload = transaction.operations.first.payload;
    final updated = current.copyWith(
      x: _asDouble(payload['x'], current.x),
      y: _asDouble(payload['y'], current.y),
      width: _asDouble(payload['width'], current.width),
      height: _asDouble(payload['height'], current.height),
      rotation: _asDouble(payload['rotation'], current.rotation),
      scaleX: _asDouble(payload['scaleX'], current.scaleX),
      scaleY: _asDouble(payload['scaleY'], current.scaleY),
      opacity: _asDouble(payload['opacity'], current.opacity),
    );
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: updated};
    return draft.copy(layers: layers, selectedLayerId: layerId);
  }

  UnifiedCreativeState _applySelectLayer(
    UnifiedCreativeState draft,
    CreativeTransactionEnvelope transaction,
  ) {
    final layerId = transaction.target?.layerId;
    if (!_hasText(layerId) || !draft.layers.containsKey(layerId)) {
      return draft;
    }
    return draft.copy(selectedLayerId: layerId);
  }

  List<String> _mutatedLayerIds(CreativeTransactionEnvelope transaction) {
    final layerId = transaction.target?.layerId;
    if (_hasText(layerId)) {
      return <String>[layerId!];
    }
    return const <String>[];
  }
}

double _asDouble(Object? value, num fallback) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return fallback.toDouble();
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
