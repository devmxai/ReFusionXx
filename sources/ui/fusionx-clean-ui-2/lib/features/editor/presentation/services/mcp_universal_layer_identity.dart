enum UniversalLayerApplyIntent {
  insert,
  update,
  styleMutation,
  transformMutation,
  effectMutation,
  motionMutation,
  deleteOperation,
  unknown,
}

enum UniversalLayerResolutionResult {
  resolvedSingle,
  resolvedAmbiguous,
  missingTarget,
  blockedUnsafeFallback,
  unsupportedTargetKind,
}

enum UniversalLayerTargetKind {
  textElement,
  shapeElement,
  backgroundElement,
  imageClip,
  videoClip,
  audioClip,
  timelineClip,
  motionChannel,
  effectInstance,
  unknownLayer,
}

class UniversalLayerTarget {
  const UniversalLayerTarget({
    required this.canonicalTargetId,
    required this.targetKind,
    required this.targetFamily,
    required this.remoteLayerId,
    required this.targetLayerId,
    required this.localLayerId,
    required this.clipId,
    required this.elementId,
    required this.sourceId,
    required this.aliases,
    required this.resolutionSource,
    required this.confidence,
    required this.isAmbiguous,
    required this.isMissing,
    required this.blockers,
    required this.metadata,
  });

  final String? canonicalTargetId;
  final UniversalLayerTargetKind targetKind;
  final String targetFamily;
  final String? remoteLayerId;
  final String? targetLayerId;
  final String? localLayerId;
  final String? clipId;
  final String? elementId;
  final String? sourceId;
  final List<String> aliases;
  final String resolutionSource;
  final double confidence;
  final bool isAmbiguous;
  final bool isMissing;
  final List<String> blockers;
  final Map<String, Object?> metadata;
}

class UniversalLayerResolution {
  const UniversalLayerResolution({
    required this.result,
    required this.target,
    required this.candidates,
  });

  final UniversalLayerResolutionResult result;
  final UniversalLayerTarget? target;
  final List<String> candidates;
}

class UniversalMcpLayerIdentityResolver {
  const UniversalMcpLayerIdentityResolver();

  UniversalLayerResolution resolve({
    required String remoteLayerId,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
    required bool Function(String layerId) exists,
    UniversalLayerTargetKind targetKind = UniversalLayerTargetKind.unknownLayer,
    String targetFamily = 'unknown',
    bool failOnAmbiguity = false,
  }) {
    final candidatesWithSource = _targetCandidatesWithSource(
      remoteLayerId: remoteLayerId,
      payload: payload,
      updates: updates,
      payloadPayload: payloadPayload,
      updatesPayload: updatesPayload,
    );
    final resolved = <_ResolvedCandidate>[];
    for (final candidate in candidatesWithSource) {
      if (exists(candidate.id)) {
        resolved.add(candidate);
      }
    }
    if (resolved.isEmpty) {
      return UniversalLayerResolution(
        result: UniversalLayerResolutionResult.missingTarget,
        target: UniversalLayerTarget(
          canonicalTargetId: null,
          targetKind: targetKind,
          targetFamily: targetFamily,
          remoteLayerId: remoteLayerId,
          targetLayerId: _firstNonEmptyBySource(
              resolved: candidatesWithSource, source: 'targetLayerId'),
          localLayerId: _firstNonEmptyBySource(
              resolved: candidatesWithSource, source: 'localLayerId'),
          clipId: _firstNonEmptyBySource(
              resolved: candidatesWithSource, source: 'clipId'),
          elementId: null,
          sourceId: null,
          aliases: candidatesWithSource
              .map((entry) => entry.id)
              .toList(growable: false),
          resolutionSource: 'none',
          confidence: 0.0,
          isAmbiguous: false,
          isMissing: true,
          blockers: const <String>['TARGET_NOT_FOUND'],
          metadata: const <String, Object?>{},
        ),
        candidates: candidatesWithSource
            .map((entry) => entry.id)
            .toList(growable: false),
      );
    }
    if (resolved.length > 1 && failOnAmbiguity) {
      return UniversalLayerResolution(
        result: UniversalLayerResolutionResult.resolvedAmbiguous,
        target: UniversalLayerTarget(
          canonicalTargetId: null,
          targetKind: targetKind,
          targetFamily: targetFamily,
          remoteLayerId: remoteLayerId,
          targetLayerId: null,
          localLayerId: null,
          clipId: null,
          elementId: null,
          sourceId: null,
          aliases: resolved.map((entry) => entry.id).toList(growable: false),
          resolutionSource: 'multiple',
          confidence: 0.0,
          isAmbiguous: true,
          isMissing: false,
          blockers: const <String>['AMBIGUOUS_TARGET'],
          metadata: const <String, Object?>{},
        ),
        candidates: resolved.map((entry) => entry.id).toList(growable: false),
      );
    }
    final selected = resolved.first;
    return UniversalLayerResolution(
      result: UniversalLayerResolutionResult.resolvedSingle,
      target: UniversalLayerTarget(
        canonicalTargetId: selected.id,
        targetKind: targetKind,
        targetFamily: targetFamily,
        remoteLayerId: remoteLayerId,
        targetLayerId:
            selected.source.contains('targetLayerId') ? selected.id : null,
        localLayerId:
            selected.source.contains('localLayerId') ? selected.id : null,
        clipId: selected.source.contains('clipId') ? selected.id : null,
        elementId: null,
        sourceId: null,
        aliases: candidatesWithSource
            .map((entry) => entry.id)
            .toList(growable: false),
        resolutionSource: selected.source,
        confidence: 1.0,
        isAmbiguous: false,
        isMissing: false,
        blockers: const <String>[],
        metadata: const <String, Object?>{},
      ),
      candidates: resolved.map((entry) => entry.id).toList(growable: false),
    );
  }

  String? _firstNonEmptyBySource({
    required List<_ResolvedCandidate> resolved,
    required String source,
  }) {
    for (final candidate in resolved) {
      if (candidate.source == source) {
        return candidate.id;
      }
    }
    return null;
  }

  List<_ResolvedCandidate> _targetCandidatesWithSource({
    required String remoteLayerId,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
  }) {
    final ordered = <_ResolvedCandidate>[
      _ResolvedCandidate(id: remoteLayerId, source: 'remoteLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payload['targetLayerId']]) ?? '',
          source: 'targetLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updates['targetLayerId']]) ?? '',
          source: 'targetLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payloadPayload['targetLayerId']]) ?? '',
          source: 'targetLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updatesPayload['targetLayerId']]) ?? '',
          source: 'targetLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payload['layerId']]) ?? '',
          source: 'layerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updates['layerId']]) ?? '',
          source: 'layerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payloadPayload['layerId']]) ?? '',
          source: 'layerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updatesPayload['layerId']]) ?? '',
          source: 'layerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payload['requestedLayerId']]) ?? '',
          source: 'requestedLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updates['requestedLayerId']]) ?? '',
          source: 'requestedLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payloadPayload['requestedLayerId']]) ?? '',
          source: 'requestedLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updatesPayload['requestedLayerId']]) ?? '',
          source: 'requestedLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payload['localLayerId']]) ?? '',
          source: 'localLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updates['localLayerId']]) ?? '',
          source: 'localLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payloadPayload['localLayerId']]) ?? '',
          source: 'localLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updatesPayload['localLayerId']]) ?? '',
          source: 'localLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payload['clipId']]) ?? '', source: 'clipId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updates['clipId']]) ?? '', source: 'clipId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payloadPayload['clipId']]) ?? '',
          source: 'clipId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updatesPayload['clipId']]) ?? '',
          source: 'clipId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payload['remoteLayerId']]) ?? '',
          source: 'remoteLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updates['remoteLayerId']]) ?? '',
          source: 'remoteLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[payloadPayload['remoteLayerId']]) ?? '',
          source: 'remoteLayerId'),
      _ResolvedCandidate(
          id: _firstText(<Object?>[updatesPayload['remoteLayerId']]) ?? '',
          source: 'remoteLayerId'),
    ];
    final deduped = <String>{};
    final next = <_ResolvedCandidate>[];
    for (final candidate in ordered) {
      final value = candidate.id.trim();
      if (value.isEmpty || deduped.contains(value)) {
        continue;
      }
      deduped.add(value);
      next.add(_ResolvedCandidate(id: value, source: candidate.source));
    }
    return List<_ResolvedCandidate>.unmodifiable(next);
  }
}

class UniversalLayerApplyIntentClassifier {
  const UniversalLayerApplyIntentClassifier();

  UniversalLayerApplyIntent classify({
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
    String operationHint = '',
  }) {
    final operation = _firstText(<Object?>[
          operationHint,
          payload['operation'],
          updates['operation'],
          payloadPayload['operation'],
          updatesPayload['operation'],
        ])?.toLowerCase() ??
        '';
    final isInsertOperation = operation.contains('insert') ||
        operation.contains('add') ||
        operation.contains('create') ||
        operation.contains('new');
    final isExplicitUpdateOperation = operation.contains('update') ||
        operation.contains('edit') ||
        operation.contains('mutat') ||
        operation.contains('set') ||
        operation.contains('patch');
    final isDeleteOperation =
        operation.contains('delete') || operation.contains('remove');
    final hasTargetHints = _firstText(<Object?>[
          payload['targetLayerId'],
          payload['layerId'],
          payload['requestedLayerId'],
          payload['localLayerId'],
          payload['clipId'],
          updates['targetLayerId'],
          updates['layerId'],
          updates['requestedLayerId'],
          updates['localLayerId'],
          updates['clipId'],
          payloadPayload['targetLayerId'],
          payloadPayload['layerId'],
          payloadPayload['requestedLayerId'],
          payloadPayload['localLayerId'],
          payloadPayload['clipId'],
          updatesPayload['targetLayerId'],
          updatesPayload['layerId'],
          updatesPayload['requestedLayerId'],
          updatesPayload['localLayerId'],
          updatesPayload['clipId'],
        ]) !=
        null;
    final hasMotionMutation = operation.contains('animate') ||
        operation.contains('keyframe') ||
        _asMap(payload['motion']).isNotEmpty ||
        _asMap(payload['animation']).isNotEmpty ||
        _asMap(updates['motion']).isNotEmpty ||
        _asMap(updates['animation']).isNotEmpty ||
        _asMap(payloadPayload['motion']).isNotEmpty ||
        _asMap(payloadPayload['animation']).isNotEmpty ||
        _asMap(updatesPayload['motion']).isNotEmpty ||
        _asMap(updatesPayload['animation']).isNotEmpty;
    if (hasMotionMutation) {
      return UniversalLayerApplyIntent.motionMutation;
    }
    final hasEffectMutation = operation.contains('effect') ||
        _asMap(payload['effect']).isNotEmpty ||
        _asMap(payload['effects']).isNotEmpty ||
        _asMap(updates['effect']).isNotEmpty ||
        _asMap(updates['effects']).isNotEmpty ||
        _asMap(payloadPayload['effect']).isNotEmpty ||
        _asMap(payloadPayload['effects']).isNotEmpty ||
        _asMap(updatesPayload['effect']).isNotEmpty ||
        _asMap(updatesPayload['effects']).isNotEmpty;
    final effectMutationByOperation = operation.contains('effect');
    if (hasEffectMutation &&
        (hasTargetHints ||
            effectMutationByOperation ||
            isExplicitUpdateOperation)) {
      return UniversalLayerApplyIntent.effectMutation;
    }
    final hasStyleMutation = operation.contains('style') ||
        operation.contains('mask') ||
        operation.contains('border') ||
        operation.contains('shadow') ||
        operation.contains('glow') ||
        _asMap(payload['style']).isNotEmpty ||
        _asMap(updates['style']).isNotEmpty ||
        _asMap(payloadPayload['style']).isNotEmpty ||
        _asMap(updatesPayload['style']).isNotEmpty;
    final styleMutationByOperation = operation.contains('style') ||
        operation.contains('mask') ||
        operation.contains('border') ||
        operation.contains('shadow') ||
        operation.contains('glow');
    if (hasStyleMutation &&
        (hasTargetHints ||
            styleMutationByOperation ||
            isExplicitUpdateOperation)) {
      return UniversalLayerApplyIntent.styleMutation;
    }
    final hasTransformMutation = operation.contains('transform') ||
        _firstText(<Object?>[
              payload['x'],
              payload['y'],
              payload['position'],
              payload['centerX'],
              payload['centerY'],
              payload['scale'],
              payload['rotation'],
              updates['x'],
              updates['y'],
              updates['position'],
              updates['centerX'],
              updates['centerY'],
              updates['scale'],
              updates['rotation'],
              payloadPayload['x'],
              payloadPayload['y'],
              payloadPayload['position'],
              payloadPayload['centerX'],
              payloadPayload['centerY'],
              payloadPayload['scale'],
              payloadPayload['rotation'],
              updatesPayload['x'],
              updatesPayload['y'],
              updatesPayload['position'],
              updatesPayload['centerX'],
              updatesPayload['centerY'],
              updatesPayload['scale'],
              updatesPayload['rotation'],
            ]) !=
            null;
    final transformMutationByOperation = operation.contains('transform') ||
        operation.contains('move') ||
        operation.contains('position');
    if (hasTransformMutation &&
        (hasTargetHints ||
            transformMutationByOperation ||
            isExplicitUpdateOperation)) {
      return UniversalLayerApplyIntent.transformMutation;
    }
    if (isDeleteOperation) {
      return UniversalLayerApplyIntent.deleteOperation;
    }
    if (isExplicitUpdateOperation) {
      return UniversalLayerApplyIntent.update;
    }
    if (hasTargetHints) {
      return UniversalLayerApplyIntent.update;
    }
    if (updates.isNotEmpty || updatesPayload.isNotEmpty) {
      return isInsertOperation
          ? UniversalLayerApplyIntent.insert
          : UniversalLayerApplyIntent.update;
    }
    if (isInsertOperation) {
      return UniversalLayerApplyIntent.insert;
    }
    return UniversalLayerApplyIntent.insert;
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      final next = <String, Object?>{};
      value.forEach((key, dynamicValue) {
        if (key is String) {
          next[key] = dynamicValue;
        }
      });
      return next;
    }
    return const <String, Object?>{};
  }
}

class _ResolvedCandidate {
  const _ResolvedCandidate({
    required this.id,
    required this.source,
  });

  final String id;
  final String source;
}

String? _firstText(List<Object?> values) {
  for (final value in values) {
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
  }
  return null;
}
