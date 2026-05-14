import 'mcp_text_layer_resolution.dart';

class McpShapeLayerResolution {
  const McpShapeLayerResolution._();

  static String? resolveCandidateLayerId({
    required String remoteLayerId,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
    required bool Function(String layerId) exists,
  }) {
    return McpTextLayerResolution.resolveCandidateLayerId(
      remoteLayerId: remoteLayerId,
      payload: payload,
      updates: updates,
      payloadPayload: payloadPayload,
      updatesPayload: updatesPayload,
      exists: exists,
    );
  }

  static bool requestsUpdate({
    required String operation,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
    required List<String> aliases,
  }) {
    final normalized = operation.trim().toLowerCase();
    final insertKeyword = normalized.contains('insert') ||
        normalized.contains('add') ||
        normalized.contains('create') ||
        normalized.contains('new');
    final explicitUpdateOperation = normalized.contains('update') ||
        normalized.contains('edit') ||
        normalized.contains('mutate') ||
        normalized.contains('patch') ||
        normalized.contains('set') ||
        normalized.contains('transform') ||
        normalized.contains('style');
    final baseUpdateIntent = McpTextLayerResolution.requestsUpdate(
      payload: payload,
      updates: updates,
      payloadPayload: payloadPayload,
      updatesPayload: updatesPayload,
    );
    final hasTargetHints = aliases.isNotEmpty ||
        _firstText(<Object?>[
              payload['targetLayerId'],
              payload['layerId'],
              payload['requestedLayerId'],
              payload['localLayerId'],
              updates['targetLayerId'],
              updates['layerId'],
              updates['requestedLayerId'],
              updates['localLayerId'],
              payloadPayload['targetLayerId'],
              payloadPayload['layerId'],
              payloadPayload['requestedLayerId'],
              payloadPayload['localLayerId'],
              updatesPayload['targetLayerId'],
              updatesPayload['layerId'],
              updatesPayload['requestedLayerId'],
              updatesPayload['localLayerId'],
            ]) !=
            null;
    final hasPatchMap = updates.isNotEmpty || updatesPayload.isNotEmpty;

    if (insertKeyword && !hasTargetHints) {
      return false;
    }
    if (explicitUpdateOperation) {
      return true;
    }
    if (hasTargetHints) {
      return true;
    }
    if (!insertKeyword && hasPatchMap) {
      return true;
    }
    return baseUpdateIntent;
  }

  static bool shouldBlockInsert({
    required bool updateIntent,
    required String? resolvedLayerId,
    required bool resolvedTargetIsShapeElement,
  }) {
    return McpTextLayerResolution.shouldBlockInsert(
      updateIntent: updateIntent,
      resolvedLayerId: resolvedLayerId,
      resolvedTargetIsTextElement: resolvedTargetIsShapeElement,
    );
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
