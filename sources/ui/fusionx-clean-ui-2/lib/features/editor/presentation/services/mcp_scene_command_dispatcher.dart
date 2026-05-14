import '../../domain/models/professional_scene_command_models.dart';

class McpSceneCommandDispatcher {
  const McpSceneCommandDispatcher();

  List<ProfessionalSceneCommand> dispatchRemoteLayers({
    required List<Map<String, Object?>> remoteLayers,
    required bool Function(Map<String, Object?> remoteLayer)
        hasBackgroundVisualIntent,
    required bool Function(Map<String, Object?> remoteLayer)
        hasTimelineMutationIntent,
  }) {
    final commands = <ProfessionalSceneCommand>[];
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
          _asMap(updates['animation']).isNotEmpty ||
          _asMap(payload['motion']).isNotEmpty ||
          _asMap(updates['motion']).isNotEmpty;
      final backgroundIntent = hasBackgroundVisualIntent(remoteLayer);
      if (kind == 'text') {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applyTextLayer,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _firstText(<Object?>[
                remoteLayer['id'],
                payload['layerId'],
                payload['targetLayerId'],
              ]),
            ),
            payload: remoteLayer,
          ),
        );
      } else if (backgroundIntent) {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applySolidLayer,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _firstText(<Object?>[
                remoteLayer['id'],
                payload['layerId'],
                payload['targetLayerId'],
              ]),
            ),
            payload: remoteLayer,
          ),
        );
      } else if (kind == 'shape') {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applyShapeLayer,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _firstText(<Object?>[
                remoteLayer['id'],
                payload['layerId'],
                payload['targetLayerId'],
              ]),
            ),
            payload: remoteLayer,
          ),
        );
      } else if (kind == 'solid') {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applySolidLayer,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _firstText(<Object?>[
                remoteLayer['id'],
                payload['layerId'],
                payload['targetLayerId'],
              ]),
            ),
            payload: remoteLayer,
          ),
        );
      } else if (kind == 'media') {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.registerMediaBinding,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _firstText(<Object?>[
                remoteLayer['id'],
                payload['layerId'],
                payload['targetLayerId'],
              ]),
            ),
            payload: remoteLayer,
          ),
        );
      }
      if (hasLegacyAnimationPayload) {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applyLegacyAnimation,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _firstText(<Object?>[
                payload['layerId'],
                payload['targetLayerId'],
                updates['layerId'],
                updates['targetLayerId'],
                remoteLayer['id'],
              ]),
            ),
            payload: remoteLayer,
          ),
        );
      }
      if (hasTimelineMutationIntent(remoteLayer)) {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applyTimelineMutation,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _firstText(<Object?>[
                payload['layerId'],
                payload['targetLayerId'],
                updates['layerId'],
                updates['targetLayerId'],
                remoteLayer['id'],
              ]),
            ),
            payload: remoteLayer,
          ),
        );
      }
    }
    return List<ProfessionalSceneCommand>.unmodifiable(commands);
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
