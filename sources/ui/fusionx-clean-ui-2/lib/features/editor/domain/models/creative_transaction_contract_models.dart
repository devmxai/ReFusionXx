enum CreativeTransactionSource {
  manualUi,
  mcpAgent,
  script,
  template,
  import,
  migration,
}

enum CreativeTransactionIntent {
  layerInsert,
  layerUpdate,
  layerDelete,
  backgroundSetSolid,
  shapeInsert,
  textInsert,
  textUpdateContent,
  transformPatch,
  layerSelect,
  keyframeBatchApply,
  animationApplyRecipe,
  effectApply,
}

enum CreativeProofLevel {
  none(0),
  data(1),
  graph(2),
  timeline(3),
  frame(4),
  renderer(5);

  const CreativeProofLevel(this.rank);
  final int rank;
}

enum LegacyPathCleanupDecision {
  canonicalize,
  adapterOnly,
  featureFlag,
  migrate,
  delete,
  block,
}

class CreativeTargetRef {
  const CreativeTargetRef({
    this.layerId,
    this.layerAlias,
    this.clipId,
    this.elementId,
  });

  final String? layerId;
  final String? layerAlias;
  final String? clipId;
  final String? elementId;

  bool get hasIdentity =>
      _hasText(layerId) ||
      _hasText(layerAlias) ||
      _hasText(clipId) ||
      _hasText(elementId);
}

class CreativeLayerAlias {
  const CreativeLayerAlias({
    required this.kind,
    required this.value,
  });

  final String kind;
  final String value;
}

class CreativeLayerIdentity {
  const CreativeLayerIdentity({
    required this.layerId,
    required this.kind,
    required this.compositionId,
    required this.timelineTrackId,
    required this.zOrder,
    required this.createdBy,
    required this.createdAtRevision,
    required this.updatedAtRevision,
    this.aliases = const <CreativeLayerAlias>[],
  });

  final String layerId;
  final String kind;
  final String compositionId;
  final String timelineTrackId;
  final int zOrder;
  final CreativeTransactionSource createdBy;
  final int createdAtRevision;
  final int updatedAtRevision;
  final List<CreativeLayerAlias> aliases;
}

class CreativeCompositionSpec {
  const CreativeCompositionSpec({
    required this.compositionId,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationMs,
    required this.currentTimeMs,
    required this.currentFrame,
    required this.coordinateSystem,
    required this.origin,
    this.fpsNumerator,
    this.fpsDenominator,
    this.durationInFrames,
    this.compositionRevision = 0,
    this.graphRevision = 0,
  });

  final String compositionId;
  final int width;
  final int height;
  final int fps;
  final int durationMs;
  final int currentTimeMs;
  final int currentFrame;
  final String coordinateSystem;
  final String origin;
  final int? fpsNumerator;
  final int? fpsDenominator;
  final int? durationInFrames;
  final int compositionRevision;
  final int graphRevision;

  int get resolvedFpsNumerator => fpsNumerator ?? fps;
  int get resolvedFpsDenominator => (fpsDenominator ?? 1) <= 0
      ? 1
      : (fpsDenominator ?? 1);
  int get resolvedDurationInFrames =>
      durationInFrames ??
      (((durationMs / 1000.0) * (resolvedFpsNumerator / resolvedFpsDenominator))
          .round());
}

class ViewportProjectionState {
  const ViewportProjectionState({
    required this.compositionId,
    required this.devicePixelRatio,
    required this.viewportScale,
    required this.viewportOffsetX,
    required this.viewportOffsetY,
    this.editorPreviewClipRadius = 0,
  });

  final String compositionId;
  final double devicePixelRatio;
  final double viewportScale;
  final double viewportOffsetX;
  final double viewportOffsetY;
  final double editorPreviewClipRadius;
}

class FrameEvaluationRequest {
  const FrameEvaluationRequest({
    required this.compositionId,
    required this.fpsNumerator,
    required this.fpsDenominator,
    required this.durationInFrames,
    required this.rootFrame,
    required this.rootTimeMs,
    this.sceneFrame,
    this.sceneTimeMs,
    this.clipLocalFrame,
    this.clipLocalTimeMs,
    this.elementLocalFrame,
    this.effectLocalFrame,
    this.transitionProgress,
    this.roundingMode = 'round',
  });

  final String compositionId;
  final int fpsNumerator;
  final int fpsDenominator;
  final int durationInFrames;
  final int rootFrame;
  final int rootTimeMs;
  final int? sceneFrame;
  final int? sceneTimeMs;
  final int? clipLocalFrame;
  final int? clipLocalTimeMs;
  final int? elementLocalFrame;
  final int? effectLocalFrame;
  final double? transitionProgress;
  final String roundingMode;
}

class CoordinateInputV1 {
  const CoordinateInputV1({
    required this.space,
    this.unit = 'compositionPx',
    this.x,
    this.y,
    this.centerX,
    this.centerY,
    this.normalizedX,
    this.normalizedY,
    this.anchor,
    this.zone,
  });

  final String space;
  final String unit;
  final double? x;
  final double? y;
  final double? centerX;
  final double? centerY;
  final double? normalizedX;
  final double? normalizedY;
  final String? anchor;
  final String? zone;
}

class CanvasDiagnosticV1 {
  const CanvasDiagnosticV1({
    required this.code,
    required this.message,
    this.severity = 'error',
    this.repairHint,
    this.fieldPath,
    this.blocking = true,
  });

  final String code;
  final String message;
  final String severity;
  final String? repairHint;
  final String? fieldPath;
  final bool blocking;
}

class CreativeTransactionOperation {
  const CreativeTransactionOperation({
    required this.kind,
    this.payload = const <String, Object?>{},
  });

  final String kind;
  final Map<String, Object?> payload;
}

class CreativeApplyProof {
  const CreativeApplyProof({
    required this.level,
    required this.dataApplied,
    required this.localGraphApplied,
    required this.timelineVisible,
    required this.frameEvaluated,
    required this.visualProgramEmitted,
    required this.rendererApplied,
    this.targetLayerId,
    this.operationApplied,
    this.createdLayerCount = 0,
    this.updatedLayerCount = 0,
  });

  final CreativeProofLevel level;
  final bool dataApplied;
  final bool localGraphApplied;
  final bool timelineVisible;
  final bool frameEvaluated;
  final bool visualProgramEmitted;
  final bool rendererApplied;
  final String? targetLayerId;
  final String? operationApplied;
  final int createdLayerCount;
  final int updatedLayerCount;

  bool get isFinalSuccess =>
      dataApplied &&
      localGraphApplied &&
      timelineVisible &&
      frameEvaluated &&
      visualProgramEmitted &&
      rendererApplied &&
      level.rank >= CreativeProofLevel.renderer.rank;
}

class CreativeWorkspaceSnapshot {
  const CreativeWorkspaceSnapshot({
    required this.projectId,
    required this.compositionId,
    required this.revision,
    required this.compositionSpec,
    this.layers = const <CreativeLayerIdentity>[],
    this.selection = const <String>[],
    this.diagnostics = const <String>[],
  });

  final String projectId;
  final String compositionId;
  final int revision;
  final CreativeCompositionSpec compositionSpec;
  final List<CreativeLayerIdentity> layers;
  final List<String> selection;
  final List<String> diagnostics;
}

class LegacyPathCleanupRecord {
  LegacyPathCleanupRecord({
    required this.pathId,
    required this.decision,
    required this.reason,
    this.owner = '',
  }) {
    if (!_hasText(pathId)) {
      throw ArgumentError('pathId is required.');
    }
    if (!_hasText(reason)) {
      throw ArgumentError('reason is required.');
    }
  }

  final String pathId;
  final LegacyPathCleanupDecision decision;
  final String reason;
  final String owner;
}

class CreativeTransactionEnvelope {
  const CreativeTransactionEnvelope({
    required this.transactionId,
    required this.schemaVersion,
    required this.source,
    required this.intent,
    required this.projectId,
    required this.compositionId,
    required this.baseRevision,
    required this.operations,
    this.target,
    this.idempotencyKey = '',
    this.proofLevel = CreativeProofLevel.renderer,
    this.basisSnapshotId,
    this.basisCompositionRevision,
    this.basisGraphRevision,
    this.basisFrame,
    this.basisTargetLayerId,
  });

  final String transactionId;
  final int schemaVersion;
  final CreativeTransactionSource source;
  final CreativeTransactionIntent intent;
  final String projectId;
  final String compositionId;
  final int baseRevision;
  final CreativeTargetRef? target;
  final List<CreativeTransactionOperation> operations;
  final String idempotencyKey;
  final CreativeProofLevel proofLevel;
  final String? basisSnapshotId;
  final int? basisCompositionRevision;
  final int? basisGraphRevision;
  final int? basisFrame;
  final String? basisTargetLayerId;

  List<String> validate() {
    final issues = <String>[];
    if (!_hasText(transactionId)) {
      issues.add('transactionId is required.');
    }
    if (schemaVersion <= 0) {
      issues.add('schemaVersion must be positive.');
    }
    if (!_hasText(projectId)) {
      issues.add('projectId is required.');
    }
    if (!_hasText(compositionId)) {
      issues.add('compositionId is required.');
    }
    if (baseRevision < 0) {
      issues.add('baseRevision must be >= 0.');
    }
    if (operations.isEmpty) {
      issues.add('operations must not be empty.');
    }
    if (_intentRequiresTarget(intent) && !(target?.hasIdentity ?? false)) {
      issues.add('target is required for this intent.');
    }
    return issues;
  }

  bool get isValid => validate().isEmpty;
}

bool _intentRequiresTarget(CreativeTransactionIntent intent) {
  return switch (intent) {
    CreativeTransactionIntent.layerUpdate ||
    CreativeTransactionIntent.layerDelete ||
    CreativeTransactionIntent.textUpdateContent ||
    CreativeTransactionIntent.transformPatch ||
    CreativeTransactionIntent.layerSelect ||
    CreativeTransactionIntent.keyframeBatchApply ||
    CreativeTransactionIntent.animationApplyRecipe ||
    CreativeTransactionIntent.effectApply =>
      true,
    CreativeTransactionIntent.layerInsert ||
    CreativeTransactionIntent.backgroundSetSolid ||
    CreativeTransactionIntent.shapeInsert ||
    CreativeTransactionIntent.textInsert =>
      false,
  };
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
