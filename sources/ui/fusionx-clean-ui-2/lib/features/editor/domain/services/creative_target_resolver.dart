import '../models/creative_transaction_contract_models.dart';

enum CreativeTargetResolutionResult {
  resolvedSingle,
  resolvedAmbiguous,
  missingTarget,
  blockedUnsafeFallback,
}

class CreativeTargetAmbiguityDiagnostic {
  const CreativeTargetAmbiguityDiagnostic({
    required this.reason,
    required this.candidateLayerIds,
  });

  final String reason;
  final List<String> candidateLayerIds;
}

class CreativeTargetResolution {
  const CreativeTargetResolution({
    required this.result,
    this.layerId,
    this.resolutionSource = 'none',
    this.ambiguity,
  });

  final CreativeTargetResolutionResult result;
  final String? layerId;
  final String resolutionSource;
  final CreativeTargetAmbiguityDiagnostic? ambiguity;
}

class CreativeTargetResolutionRequest {
  const CreativeTargetResolutionRequest({
    required this.layers,
    this.target,
    this.transactionCreatedLayerId,
    this.selectedLayerIds = const <String>[],
    this.allowSelectedFallback = false,
    this.explicitUserMentionLayerId,
    this.spatialCandidateLayerIds = const <String>[],
    this.textQuery,
    this.textByLayerId = const <String, String>{},
  });

  final List<CreativeLayerIdentity> layers;
  final CreativeTargetRef? target;
  final String? transactionCreatedLayerId;
  final List<String> selectedLayerIds;
  final bool allowSelectedFallback;
  final String? explicitUserMentionLayerId;
  final List<String> spatialCandidateLayerIds;
  final String? textQuery;
  final Map<String, String> textByLayerId;
}

class CreativeLayerAliasIndex {
  CreativeLayerAliasIndex._(this._aliasToLayerId, this._layerIds);

  final Map<String, String> _aliasToLayerId;
  final Set<String> _layerIds;

  factory CreativeLayerAliasIndex.fromLayers(
      List<CreativeLayerIdentity> layers) {
    final aliasToLayerId = <String, String>{};
    final layerIds = <String>{};
    for (final layer in layers) {
      layerIds.add(layer.layerId);
      for (final alias in layer.aliases) {
        final key = _normalize(alias.value);
        if (key.isEmpty) {
          continue;
        }
        aliasToLayerId[key] = layer.layerId;
      }
    }
    return CreativeLayerAliasIndex._(aliasToLayerId, layerIds);
  }

  bool hasLayerId(String? layerId) {
    final key = _normalize(layerId);
    return key.isNotEmpty && _layerIds.contains(key);
  }

  String? resolveAlias(String? alias) {
    final key = _normalize(alias);
    if (key.isEmpty) {
      return null;
    }
    return _aliasToLayerId[key];
  }
}

class CreativeTargetResolver {
  const CreativeTargetResolver();

  CreativeTargetResolution resolve(CreativeTargetResolutionRequest request) {
    final aliasIndex = CreativeLayerAliasIndex.fromLayers(request.layers);

    final canonicalLayerId = _normalize(request.target?.layerId);
    if (aliasIndex.hasLayerId(canonicalLayerId)) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedSingle,
        layerId: canonicalLayerId,
        resolutionSource: 'canonicalLayerId',
      );
    }

    final transactionCreatedLayerId =
        _normalize(request.transactionCreatedLayerId);
    if (aliasIndex.hasLayerId(transactionCreatedLayerId)) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedSingle,
        layerId: transactionCreatedLayerId,
        resolutionSource: 'transactionCreatedLayerId',
      );
    }

    final aliasResolvedLayerId =
        aliasIndex.resolveAlias(request.target?.layerAlias);
    if (_hasText(aliasResolvedLayerId)) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedSingle,
        layerId: aliasResolvedLayerId,
        resolutionSource: 'aliasExactMatch',
      );
    }

    final selectedCandidates = _filterExistingLayerIds(
      request.selectedLayerIds,
      aliasIndex,
    );
    if (selectedCandidates.length == 1) {
      if (request.allowSelectedFallback) {
        return CreativeTargetResolution(
          result: CreativeTargetResolutionResult.resolvedSingle,
          layerId: selectedCandidates.single,
          resolutionSource: 'selectedLayer',
        );
      }
      return const CreativeTargetResolution(
        result: CreativeTargetResolutionResult.blockedUnsafeFallback,
        resolutionSource: 'selectedLayerBlocked',
      );
    }
    if (selectedCandidates.length > 1) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedAmbiguous,
        resolutionSource: 'selectedLayerAmbiguous',
        ambiguity: CreativeTargetAmbiguityDiagnostic(
          reason: 'AMBIGUOUS_TARGET',
          candidateLayerIds: selectedCandidates,
        ),
      );
    }

    final mentionLayerId = _normalize(request.explicitUserMentionLayerId);
    if (aliasIndex.hasLayerId(mentionLayerId)) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedSingle,
        layerId: mentionLayerId,
        resolutionSource: 'explicitUserMention',
      );
    }

    final textCandidates = _resolveTextCandidates(request, aliasIndex);
    if (textCandidates.length == 1) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedSingle,
        layerId: textCandidates.single,
        resolutionSource: 'textQuerySingle',
      );
    }
    if (textCandidates.length > 1) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedAmbiguous,
        resolutionSource: 'textQueryAmbiguous',
        ambiguity: CreativeTargetAmbiguityDiagnostic(
          reason: 'AMBIGUOUS_TARGET',
          candidateLayerIds: textCandidates,
        ),
      );
    }

    final spatialCandidates = _filterExistingLayerIds(
      request.spatialCandidateLayerIds,
      aliasIndex,
    );
    if (spatialCandidates.length == 1) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedSingle,
        layerId: spatialCandidates.single,
        resolutionSource: 'spatialSingleMatch',
      );
    }
    if (spatialCandidates.length > 1) {
      return CreativeTargetResolution(
        result: CreativeTargetResolutionResult.resolvedAmbiguous,
        resolutionSource: 'spatialAmbiguous',
        ambiguity: CreativeTargetAmbiguityDiagnostic(
          reason: 'AMBIGUOUS_TARGET',
          candidateLayerIds: spatialCandidates,
        ),
      );
    }

    return const CreativeTargetResolution(
      result: CreativeTargetResolutionResult.missingTarget,
      resolutionSource: 'none',
    );
  }

  List<String> _resolveTextCandidates(
    CreativeTargetResolutionRequest request,
    CreativeLayerAliasIndex aliasIndex,
  ) {
    final query = _normalizeText(request.textQuery);
    if (query.isEmpty) {
      return const <String>[];
    }
    final matches = <String>[];
    request.textByLayerId.forEach((layerId, textValue) {
      if (!aliasIndex.hasLayerId(layerId)) {
        return;
      }
      if (_normalizeText(textValue) == query) {
        matches.add(layerId.trim());
      }
    });
    return matches;
  }

  List<String> _filterExistingLayerIds(
    List<String> candidates,
    CreativeLayerAliasIndex aliasIndex,
  ) {
    final result = <String>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      final normalized = _normalize(candidate);
      if (normalized.isEmpty || !aliasIndex.hasLayerId(normalized)) {
        continue;
      }
      if (seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }
}

String _normalize(String? value) => (value ?? '').trim();

bool _hasText(String? value) => _normalize(value).isNotEmpty;

String _normalizeText(String? value) => _normalize(value).toLowerCase();
