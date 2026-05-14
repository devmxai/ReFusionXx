class McpTextLayerResolution {
  const McpTextLayerResolution._();

  static String? resolveCandidateLayerId({
    required String remoteLayerId,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
    required bool Function(String layerId) exists,
  }) {
    for (final candidate in _targetCandidates(
      remoteLayerId: remoteLayerId,
      payload: payload,
      updates: updates,
      payloadPayload: payloadPayload,
      updatesPayload: updatesPayload,
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
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
  }) {
    final operation = _firstText(<Object?>[
          payload['operation'],
          updates['operation'],
          payloadPayload['operation'],
          updatesPayload['operation'],
        ])?.toLowerCase() ??
        '';
    if (operation.contains('update') ||
        operation.contains('edit') ||
        operation.contains('mutat') ||
        operation.contains('set') ||
        operation.contains('patch')) {
      return true;
    }
    final commandHint = _firstText(<Object?>[
          payload['commandFamily'],
          payload['command_family'],
          payload['commandType'],
          payload['command_type'],
          payload['toolName'],
          payload['tool_name'],
          updates['commandFamily'],
          updates['command_family'],
          updates['commandType'],
          updates['command_type'],
          updates['toolName'],
          updates['tool_name'],
          payloadPayload['commandFamily'],
          payloadPayload['command_family'],
          payloadPayload['commandType'],
          payloadPayload['command_type'],
          payloadPayload['toolName'],
          payloadPayload['tool_name'],
          updatesPayload['commandFamily'],
          updatesPayload['command_family'],
          updatesPayload['commandType'],
          updatesPayload['command_type'],
          updatesPayload['toolName'],
          updatesPayload['tool_name'],
        ])?.toLowerCase() ??
        '';
    if (commandHint.contains('update_text') ||
        commandHint.contains('update_layer') ||
        commandHint.contains('edit_text') ||
        commandHint.contains('set_text_style') ||
        commandHint.contains('set_typography') ||
        commandHint.contains('set_transform') ||
        commandHint.contains('apply_keyframes') ||
        commandHint.contains('keyframe_edit') ||
        commandHint.contains('apply_motion_patch')) {
      return true;
    }
    return _firstText(<Object?>[
          payload['targetLayerId'],
          payload['requestedLayerId'],
          payload['localLayerId'],
          updates['targetLayerId'],
          updates['requestedLayerId'],
          updates['localLayerId'],
          payloadPayload['targetLayerId'],
          payloadPayload['requestedLayerId'],
          payloadPayload['localLayerId'],
          updatesPayload['targetLayerId'],
          updatesPayload['requestedLayerId'],
          updatesPayload['localLayerId'],
          payload['layerId'],
          payload['clipId'],
          updates['layerId'],
          updates['clipId'],
          payloadPayload['layerId'],
          payloadPayload['clipId'],
          updatesPayload['layerId'],
          updatesPayload['clipId'],
        ]) !=
        null;
  }

  static bool shouldBlockInsert({
    required bool updateIntent,
    required String? resolvedLayerId,
    required bool resolvedTargetIsTextElement,
  }) {
    if (!updateIntent) {
      return false;
    }
    if (resolvedLayerId == null || resolvedLayerId.isEmpty) {
      return true;
    }
    return !resolvedTargetIsTextElement;
  }

  static List<String> _targetCandidates({
    required String remoteLayerId,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
  }) {
    final ordered = <String>[
      remoteLayerId,
      _firstText(<Object?>[payload['targetLayerId']]) ?? '',
      _firstText(<Object?>[updates['targetLayerId']]) ?? '',
      _firstText(<Object?>[payloadPayload['targetLayerId']]) ?? '',
      _firstText(<Object?>[updatesPayload['targetLayerId']]) ?? '',
      _firstText(<Object?>[payload['layerId']]) ?? '',
      _firstText(<Object?>[updates['layerId']]) ?? '',
      _firstText(<Object?>[payloadPayload['layerId']]) ?? '',
      _firstText(<Object?>[updatesPayload['layerId']]) ?? '',
      _firstText(<Object?>[payload['requestedLayerId']]) ?? '',
      _firstText(<Object?>[updates['requestedLayerId']]) ?? '',
      _firstText(<Object?>[payloadPayload['requestedLayerId']]) ?? '',
      _firstText(<Object?>[updatesPayload['requestedLayerId']]) ?? '',
      _firstText(<Object?>[payload['localLayerId']]) ?? '',
      _firstText(<Object?>[updates['localLayerId']]) ?? '',
      _firstText(<Object?>[payloadPayload['localLayerId']]) ?? '',
      _firstText(<Object?>[updatesPayload['localLayerId']]) ?? '',
      _firstText(<Object?>[payload['clipId']]) ?? '',
      _firstText(<Object?>[updates['clipId']]) ?? '',
      _firstText(<Object?>[payloadPayload['clipId']]) ?? '',
      _firstText(<Object?>[updatesPayload['clipId']]) ?? '',
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
