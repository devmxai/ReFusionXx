class McpTextLayerResolution {
  const McpTextLayerResolution._();

  static String? resolveCandidateLayerId({
    required String remoteLayerId,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> nestedPayload,
    required bool Function(String layerId) exists,
  }) {
    for (final candidate in _targetCandidates(
      remoteLayerId: remoteLayerId,
      payload: payload,
      updates: updates,
      nestedPayload: nestedPayload,
    )) {
      if (exists(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static bool requestsUpdate({
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> nestedPayload,
  }) {
    final operation = _firstText(<Object?>[
          payload['operation'],
          updates['operation'],
          nestedPayload['operation'],
        ])?.toLowerCase() ??
        '';
    if (operation.contains('update') ||
        operation.contains('edit') ||
        operation.contains('mutat')) {
      return true;
    }
    return _firstText(<Object?>[
          payload['targetLayerId'],
          updates['targetLayerId'],
          nestedPayload['targetLayerId'],
          payload['layerId'],
          updates['layerId'],
          nestedPayload['layerId'],
        ]) !=
        null;
  }

  static bool shouldBlockInsert({
    required bool updateIntent,
    required String? resolvedLayerId,
  }) {
    return updateIntent && (resolvedLayerId == null || resolvedLayerId.isEmpty);
  }

  static List<String> _targetCandidates({
    required String remoteLayerId,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> nestedPayload,
  }) {
    final ordered = <String>[
      remoteLayerId,
      _firstText(<Object?>[payload['targetLayerId']]) ?? '',
      _firstText(<Object?>[updates['targetLayerId']]) ?? '',
      _firstText(<Object?>[nestedPayload['targetLayerId']]) ?? '',
      _firstText(<Object?>[payload['layerId']]) ?? '',
      _firstText(<Object?>[updates['layerId']]) ?? '',
      _firstText(<Object?>[nestedPayload['layerId']]) ?? '',
    ];
    final deduped = <String>{};
    for (final raw in ordered) {
      final value = raw.trim();
      if (value.isEmpty || deduped.contains(value)) {
        continue;
      }
      deduped.add(value);
    }
    return List<String>.unmodifiable(deduped);
  }

  static String? _firstText(List<Object?> values) {
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
}
