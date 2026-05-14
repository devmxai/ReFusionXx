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
    this.motionChannels = const <UnifiedCreativeMotionChannel>[],
    this.effectStack = const <UnifiedCreativeEffectEntry>[],
    this.startMs = 0,
    this.durationMs = 0,
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
  final List<UnifiedCreativeMotionChannel> motionChannels;
  final List<UnifiedCreativeEffectEntry> effectStack;
  final int startMs;
  final int durationMs;

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
    List<UnifiedCreativeMotionChannel>? motionChannels,
    List<UnifiedCreativeEffectEntry>? effectStack,
    int? startMs,
    int? durationMs,
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
      motionChannels: motionChannels ?? this.motionChannels,
      effectStack: effectStack ?? this.effectStack,
      startMs: startMs ?? this.startMs,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

class UnifiedCreativeKeyframe {
  const UnifiedCreativeKeyframe({
    required this.timeMs,
    required this.value,
    this.easing = 'linear',
  });

  final int timeMs;
  final double value;
  final String easing;
}

class UnifiedCreativeMotionChannel {
  const UnifiedCreativeMotionChannel({
    required this.channelId,
    required this.layerId,
    required this.propertyId,
    this.keyframes = const <UnifiedCreativeKeyframe>[],
  });

  final String channelId;
  final String layerId;
  final String propertyId;
  final List<UnifiedCreativeKeyframe> keyframes;
}

class UnifiedCreativeEffectEntry {
  const UnifiedCreativeEffectEntry({
    required this.effectId,
    required this.effectType,
    this.params = const <String, Object?>{},
    this.rendererConformant = true,
    this.order = 0,
  });

  final String effectId;
  final String effectType;
  final Map<String, Object?> params;
  final bool rendererConformant;
  final int order;

  UnifiedCreativeEffectEntry copyWith({
    String? effectId,
    String? effectType,
    Map<String, Object?>? params,
    bool? rendererConformant,
    int? order,
  }) {
    return UnifiedCreativeEffectEntry(
      effectId: effectId ?? this.effectId,
      effectType: effectType ?? this.effectType,
      params: params ?? this.params,
      rendererConformant: rendererConformant ?? this.rendererConformant,
      order: order ?? this.order,
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

    final domainError = _domainPreflightError(
      state: state,
      transaction: dryRun.normalizedEnvelope,
    );
    if (_hasText(domainError)) {
      return CreativeApplyResult(
        success: false,
        state: state,
        validation: dryRun.validation,
        diff: const CreativeTransactionDiff(),
        ledger: ledger.append(
          CreativeApplyLedgerEntry(
            transactionId: transaction.transactionId,
            intent: transaction.intent,
            result: 'failed_domain_preflight',
            revisionAfter: state.revision,
          ),
        ),
        error: domainError!,
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
      CreativeTransactionIntent.layerInsert =>
        _applyLayerInsert(draft, context, transaction),
      CreativeTransactionIntent.layerUpdate =>
        _applyLayerUpdate(draft, transaction),
      CreativeTransactionIntent.layerDelete =>
        _applyLayerDelete(draft, transaction),
      CreativeTransactionIntent.animationApplyRecipe =>
        _applyAnimationRecipe(draft, transaction),
      CreativeTransactionIntent.keyframeBatchApply =>
        _applyKeyframeBatch(draft, transaction),
      CreativeTransactionIntent.effectApply =>
        _applyEffectApply(draft, transaction),
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

  UnifiedCreativeState _applyLayerInsert(
    UnifiedCreativeState draft,
    CreativeApplyContext context,
    CreativeTransactionEnvelope transaction,
  ) {
    final payload = transaction.operations.first.payload;
    final layerId = transaction.target?.layerId ?? 'layer-${draft.revision + 1}';
    final kind = (payload['kind'] as String?) ?? 'visual';
    final identity = CreativeLayerIdentity(
      layerId: layerId,
      kind: kind,
      compositionId: draft.compositionId,
      timelineTrackId: kind == 'audio' ? 'audio' : 'media',
      zOrder: 5,
      createdBy: transaction.source,
      createdAtRevision: draft.revision + 1,
      updatedAtRevision: draft.revision + 1,
    );
    final node = UnifiedCreativeLayerNode(
      identity: identity,
      x: _asDouble(payload['x'], context.compositionSpec.width / 2),
      y: _asDouble(payload['y'], context.compositionSpec.height / 2),
      width: _asDouble(payload['width'], context.compositionSpec.width.toDouble()),
      height: _asDouble(payload['height'], context.compositionSpec.height.toDouble()),
      opacity: _asDouble(payload['opacity'], 1),
      fillColor: (payload['fillColor'] as String?) ?? '#FFFFFF',
      text: (payload['text'] as String?) ?? '',
      startMs: _asInt(payload['startMs']),
      durationMs: _asInt(payload['durationMs']) <= 0
          ? context.compositionSpec.durationMs
          : _asInt(payload['durationMs']),
    );
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: node};
    final timeline = <UnifiedCreativeTimelineClip>[
      ...draft.timeline.where((clip) => clip.layerId != layerId),
      UnifiedCreativeTimelineClip(
        clipId: 'clip-$layerId',
        layerId: layerId,
        trackId: identity.timelineTrackId,
        startMs: node.startMs,
        durationMs: node.durationMs,
      ),
    ];
    return draft.copy(layers: layers, timeline: timeline, selectedLayerId: layerId);
  }

  UnifiedCreativeState _applyLayerUpdate(
    UnifiedCreativeState draft,
    CreativeTransactionEnvelope transaction,
  ) {
    final layerId = transaction.target?.layerId ?? '';
    final current = draft.layers[layerId];
    if (current == null) {
      return draft;
    }
    final payload = transaction.operations.first.payload;
    final hasStartMs = payload.containsKey('startMs');
    final hasDurationMs = payload.containsKey('durationMs');
    final updatedNode = current.copyWith(
      fillColor: (payload['color'] as String?) ??
          (payload['fillColor'] as String?) ??
          current.fillColor,
      opacity: _asDouble(payload['opacity'], current.opacity),
      text: (payload['text'] as String?) ?? current.text,
      startMs: hasStartMs ? _asInt(payload['startMs']) : current.startMs,
      durationMs: hasDurationMs ? _asInt(payload['durationMs']) : current.durationMs,
    );
    final layers = <String, UnifiedCreativeLayerNode>{
      ...draft.layers,
      layerId: updatedNode,
    };
    final timeline = <UnifiedCreativeTimelineClip>[
      for (final clip in draft.timeline)
        if (clip.layerId == layerId)
          UnifiedCreativeTimelineClip(
            clipId: clip.clipId,
            layerId: clip.layerId,
            trackId: clip.trackId,
            startMs: updatedNode.startMs,
            durationMs: updatedNode.durationMs,
          )
        else
          clip,
    ];
    return draft.copy(layers: layers, timeline: timeline, selectedLayerId: layerId);
  }

  UnifiedCreativeState _applyLayerDelete(
    UnifiedCreativeState draft,
    CreativeTransactionEnvelope transaction,
  ) {
    final layerId = transaction.target?.layerId ?? '';
    if (!_hasText(layerId) || !draft.layers.containsKey(layerId)) {
      return draft;
    }
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers}..remove(layerId);
    final timeline =
        draft.timeline.where((clip) => clip.layerId != layerId).toList(growable: false);
    final clearSelection = draft.selectedLayerId == layerId;
    return draft.copy(
      layers: layers,
      timeline: timeline,
      clearSelection: clearSelection,
    );
  }

  UnifiedCreativeState _applyAnimationRecipe(
    UnifiedCreativeState draft,
    CreativeTransactionEnvelope transaction,
  ) {
    final layerId = transaction.target?.layerId ?? '';
    final current = draft.layers[layerId];
    if (current == null) {
      return draft;
    }
    final payload = transaction.operations.first.payload;
    final recipeId = (payload['recipeId'] as String?) ?? '';
    final lowered = _lowerRecipeToChannels(
      recipeId: recipeId,
      layerId: layerId,
      current: current,
    );
    if (lowered.isEmpty) {
      return draft;
    }
    final merged = _mergeChannels(current.motionChannels, lowered);
    final updated = current.copyWith(motionChannels: merged);
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: updated};
    return draft.copy(layers: layers, selectedLayerId: layerId);
  }

  UnifiedCreativeState _applyKeyframeBatch(
    UnifiedCreativeState draft,
    CreativeTransactionEnvelope transaction,
  ) {
    final layerId = transaction.target?.layerId ?? '';
    final current = draft.layers[layerId];
    if (current == null) {
      return draft;
    }
    final payload = transaction.operations.first.payload;
    final propertyId = (payload['propertyId'] as String?) ?? '';
    if (!_hasText(propertyId)) {
      return draft;
    }
    final rawKeyframes = payload['keyframes'];
    final parsed = <UnifiedCreativeKeyframe>[];
    if (rawKeyframes is List) {
      for (final item in rawKeyframes) {
        if (item is! Map) {
          continue;
        }
        final map = item.cast<Object?, Object?>();
        final timeMs = _asInt(map['timeMs']);
        final valueRaw = map['value'];
        final value = valueRaw is num ? valueRaw.toDouble() : double.nan;
        if (!value.isFinite || timeMs < 0) {
          continue;
        }
        parsed.add(
          UnifiedCreativeKeyframe(
            timeMs: timeMs,
            value: value,
            easing: (map['easing'] as String?) ?? 'linear',
          ),
        );
      }
    }
    if (parsed.isEmpty) {
      parsed.add(
        UnifiedCreativeKeyframe(
          timeMs: 0,
          value: _currentPropertyValue(current, propertyId),
        ),
      );
    }
    final channel = UnifiedCreativeMotionChannel(
      channelId: '$layerId.$propertyId',
      layerId: layerId,
      propertyId: propertyId,
      keyframes: parsed,
    );
    final merged = _mergeChannels(
      current.motionChannels,
      <UnifiedCreativeMotionChannel>[channel],
    );
    final updated = current.copyWith(motionChannels: merged);
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: updated};
    return draft.copy(layers: layers, selectedLayerId: layerId);
  }

  UnifiedCreativeState _applyEffectApply(
    UnifiedCreativeState draft,
    CreativeTransactionEnvelope transaction,
  ) {
    final layerId = transaction.target?.layerId ?? '';
    final current = draft.layers[layerId];
    if (current == null) {
      return draft;
    }
    final payload = transaction.operations.first.payload;
    final effectType = (payload['effectType'] as String?) ?? '';
    if (!_hasText(effectType)) {
      return draft;
    }
    final explicitStack = payload['explicitStack'] == true;
    final rendererConformant = payload['rendererConformant'] != false;
    final params = <String, Object?>{...payload}..remove('effectType');
    params.remove('explicitStack');
    params.remove('rendererConformant');
    final nextEffects = <UnifiedCreativeEffectEntry>[...current.effectStack];
    final existingIndex =
        nextEffects.indexWhere((entry) => entry.effectType == effectType);
    if (existingIndex >= 0 && !explicitStack) {
      final existing = nextEffects[existingIndex];
      nextEffects[existingIndex] = existing.copyWith(
        params: params,
        rendererConformant: rendererConformant,
      );
    } else {
      nextEffects.add(
        UnifiedCreativeEffectEntry(
          effectId: '$layerId.$effectType.${nextEffects.length + 1}',
          effectType: effectType,
          params: params,
          rendererConformant: rendererConformant,
          order: nextEffects.length,
        ),
      );
    }
    final updated = current.copyWith(effectStack: nextEffects);
    final layers = <String, UnifiedCreativeLayerNode>{...draft.layers, layerId: updated};
    return draft.copy(layers: layers, selectedLayerId: layerId);
  }

  String? _domainPreflightError({
    required UnifiedCreativeState state,
    required CreativeTransactionEnvelope transaction,
  }) {
    if (transaction.intent == CreativeTransactionIntent.animationApplyRecipe) {
      final payload = transaction.operations.first.payload;
      final recipeId = (payload['recipeId'] as String?) ?? '';
      if (!_isKnownRecipe(recipeId)) {
        return 'UNKNOWN_MOTION_RECIPE';
      }
    }
    if (transaction.intent == CreativeTransactionIntent.effectApply ||
        transaction.intent == CreativeTransactionIntent.keyframeBatchApply ||
        transaction.intent == CreativeTransactionIntent.animationApplyRecipe ||
        transaction.intent == CreativeTransactionIntent.transformPatch ||
        transaction.intent == CreativeTransactionIntent.textUpdateContent ||
        transaction.intent == CreativeTransactionIntent.layerUpdate) {
      final layerId = transaction.target?.layerId ?? '';
      if (!_hasText(layerId) || !state.layers.containsKey(layerId)) {
        return 'TARGET_NOT_FOUND';
      }
    }
    return null;
  }

  List<String> _mutatedLayerIds(CreativeTransactionEnvelope transaction) {
    final layerId = transaction.target?.layerId;
    if (_hasText(layerId)) {
      return <String>[layerId!];
    }
    return const <String>[];
  }
}

bool _isKnownRecipe(String recipeId) {
  return const <String>{
    'popUp',
    'scaleInBounce',
    'slideInFromLeft',
  }.contains(recipeId.trim());
}

List<UnifiedCreativeMotionChannel> _lowerRecipeToChannels({
  required String recipeId,
  required String layerId,
  required UnifiedCreativeLayerNode current,
}) {
  final normalized = recipeId.trim();
  if (normalized == 'popUp' || normalized == 'scaleInBounce') {
    return <UnifiedCreativeMotionChannel>[
      UnifiedCreativeMotionChannel(
        channelId: '$layerId.scaleX',
        layerId: layerId,
        propertyId: 'scaleX',
        keyframes: const <UnifiedCreativeKeyframe>[
          UnifiedCreativeKeyframe(timeMs: 0, value: 0.2),
          UnifiedCreativeKeyframe(timeMs: 180, value: 1.15, easing: 'easeOutBack'),
          UnifiedCreativeKeyframe(timeMs: 360, value: 1.0, easing: 'easeOut'),
        ],
      ),
      UnifiedCreativeMotionChannel(
        channelId: '$layerId.scaleY',
        layerId: layerId,
        propertyId: 'scaleY',
        keyframes: const <UnifiedCreativeKeyframe>[
          UnifiedCreativeKeyframe(timeMs: 0, value: 0.2),
          UnifiedCreativeKeyframe(timeMs: 180, value: 1.15, easing: 'easeOutBack'),
          UnifiedCreativeKeyframe(timeMs: 360, value: 1.0, easing: 'easeOut'),
        ],
      ),
      UnifiedCreativeMotionChannel(
        channelId: '$layerId.opacity',
        layerId: layerId,
        propertyId: 'opacity',
        keyframes: const <UnifiedCreativeKeyframe>[
          UnifiedCreativeKeyframe(timeMs: 0, value: 0),
          UnifiedCreativeKeyframe(timeMs: 180, value: 1),
        ],
      ),
    ];
  }
  if (normalized == 'slideInFromLeft') {
    return <UnifiedCreativeMotionChannel>[
      UnifiedCreativeMotionChannel(
        channelId: '$layerId.x',
        layerId: layerId,
        propertyId: 'x',
        keyframes: <UnifiedCreativeKeyframe>[
          UnifiedCreativeKeyframe(timeMs: 0, value: current.x - 220),
          UnifiedCreativeKeyframe(timeMs: 280, value: current.x, easing: 'easeOut'),
        ],
      ),
      UnifiedCreativeMotionChannel(
        channelId: '$layerId.opacity',
        layerId: layerId,
        propertyId: 'opacity',
        keyframes: const <UnifiedCreativeKeyframe>[
          UnifiedCreativeKeyframe(timeMs: 0, value: 0),
          UnifiedCreativeKeyframe(timeMs: 220, value: 1),
        ],
      ),
    ];
  }
  return const <UnifiedCreativeMotionChannel>[];
}

List<UnifiedCreativeMotionChannel> _mergeChannels(
  List<UnifiedCreativeMotionChannel> existing,
  List<UnifiedCreativeMotionChannel> incoming,
) {
  final byProperty = <String, UnifiedCreativeMotionChannel>{
    for (final channel in existing) channel.propertyId: channel,
  };
  for (final channel in incoming) {
    byProperty[channel.propertyId] = channel;
  }
  return byProperty.values.toList(growable: false);
}

double _currentPropertyValue(UnifiedCreativeLayerNode node, String propertyId) {
  return switch (propertyId) {
    'x' || 'positionX' => node.x,
    'y' || 'positionY' => node.y,
    'scaleX' => node.scaleX,
    'scaleY' => node.scaleY,
    'rotation' => node.rotation,
    'opacity' => node.opacity,
    _ => 0,
  };
}

double _asDouble(Object? value, num fallback) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return fallback.toDouble();
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

int _asInt(Object? value) {
  if (value is num && value.isFinite) {
    return value.round();
  }
  return 0;
}
