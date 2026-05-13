class McpSceneCommandDispatcher {
  const McpSceneCommandDispatcher();

  List<McpSceneCommand> dispatchRemoteLayers({
    required List<Map<String, Object?>> remoteLayers,
    required bool Function(Map<String, Object?> remoteLayer)
        hasBackgroundVisualIntent,
    required bool Function(Map<String, Object?> remoteLayer)
        hasTimelineMutationIntent,
  }) {
    final commands = <McpSceneCommand>[];
    for (final remoteLayer in remoteLayers) {
      final payload = _asMap(remoteLayer['payload']);
      final updates = _asMap(payload['updates']);
      final operation = _firstText(<Object?>[
            payload['operation'],
            updates['operation'],
          ])?.toLowerCase() ??
          '';
      final kind = _firstText(<Object?>[
            remoteLayer['layer_kind'],
            remoteLayer['layerKind'],
            remoteLayer['kind'],
            payload['kind'],
          ])?.toLowerCase() ??
          '';
      final hasLegacyAnimationPayload = operation.contains('animate') ||
          operation.contains('keyframe') ||
          _asMap(payload['animation']).isNotEmpty ||
          _asMap(updates['animation']).isNotEmpty;
      if (hasLegacyAnimationPayload) {
        commands.add(
          McpSceneCommand(
            type: McpSceneCommandType.applyLegacyAnimation,
            remoteLayer: remoteLayer,
          ),
        );
      }
      if (kind == 'text') {
        commands.add(
          McpSceneCommand(
            type: McpSceneCommandType.applyTextLayer,
            remoteLayer: remoteLayer,
          ),
        );
      } else if (kind == 'solid') {
        commands.add(
          McpSceneCommand(
            type: McpSceneCommandType.applySolidLayer,
            remoteLayer: remoteLayer,
          ),
        );
      } else if (kind == 'media') {
        commands.add(
          McpSceneCommand(
            type: McpSceneCommandType.registerMediaBinding,
            remoteLayer: remoteLayer,
          ),
        );
      } else if (hasBackgroundVisualIntent(remoteLayer)) {
        commands.add(
          McpSceneCommand(
            type: McpSceneCommandType.applySolidLayer,
            remoteLayer: remoteLayer,
          ),
        );
      }
      if (hasTimelineMutationIntent(remoteLayer)) {
        commands.add(
          McpSceneCommand(
            type: McpSceneCommandType.applyTimelineMutation,
            remoteLayer: remoteLayer,
          ),
        );
      }
    }
    return List<McpSceneCommand>.unmodifiable(commands);
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

enum McpSceneCommandType {
  applyLegacyAnimation,
  applyTextLayer,
  applySolidLayer,
  registerMediaBinding,
  applyTimelineMutation,
}

class McpSceneCommand {
  const McpSceneCommand({
    required this.type,
    required this.remoteLayer,
  });

  final McpSceneCommandType type;
  final Map<String, Object?> remoteLayer;
}
