import '../../domain/models/professional_scene_command_models.dart';
import 'mcp_universal_layer_identity.dart';

class McpSceneCommandDispatcher {
  const McpSceneCommandDispatcher();

  static const UniversalLayerApplyIntentClassifier _intentClassifier =
      UniversalLayerApplyIntentClassifier();

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
      final payloadPayload = _asMap(payload['payload']);
      final updatesPayload = _asMap(updates['payload']);
      final intent = _intentClassifier.classify(
        payload: payload,
        updates: updates,
        payloadPayload: payloadPayload,
        updatesPayload: updatesPayload,
        operationHint: operation,
      );
      final remoteLayerId = _firstText(<Object?>[
        remoteLayer['id'],
        payload['remoteLayerId'],
      ]);
      final explicitMutationTarget = _firstText(<Object?>[
        payload['targetLayerId'],
        updates['targetLayerId'],
        payloadPayload['targetLayerId'],
        updatesPayload['targetLayerId'],
        payload['layerId'],
        updates['layerId'],
        payloadPayload['layerId'],
        updatesPayload['layerId'],
      ]);
      final isMutationWrapperForDifferentTarget = kind == 'solid' &&
          intent != UniversalLayerApplyIntent.insert &&
          explicitMutationTarget != null &&
          remoteLayerId != null &&
          explicitMutationTarget != remoteLayerId;
      final backgroundIntent = hasBackgroundVisualIntent(remoteLayer);
      if (!isMutationWrapperForDifferentTarget && kind == 'text') {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applyTextLayer,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _targetIdForIntent(
                remoteLayer: remoteLayer,
                payload: payload,
                updates: updates,
                payloadPayload: payloadPayload,
                updatesPayload: updatesPayload,
                intent: intent,
              ),
            ),
            payload: remoteLayer,
          ),
        );
      } else if (!isMutationWrapperForDifferentTarget && backgroundIntent) {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applySolidLayer,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _targetIdForIntent(
                remoteLayer: remoteLayer,
                payload: payload,
                updates: updates,
                payloadPayload: payloadPayload,
                updatesPayload: updatesPayload,
                intent: intent,
              ),
            ),
            payload: remoteLayer,
          ),
        );
      } else if (!isMutationWrapperForDifferentTarget && kind == 'shape') {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applyShapeLayer,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _targetIdForIntent(
                remoteLayer: remoteLayer,
                payload: payload,
                updates: updates,
                payloadPayload: payloadPayload,
                updatesPayload: updatesPayload,
                intent: intent,
              ),
            ),
            payload: remoteLayer,
          ),
        );
      } else if (!isMutationWrapperForDifferentTarget && kind == 'solid') {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.applySolidLayer,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _targetIdForIntent(
                remoteLayer: remoteLayer,
                payload: payload,
                updates: updates,
                payloadPayload: payloadPayload,
                updatesPayload: updatesPayload,
                intent: intent,
              ),
            ),
            payload: remoteLayer,
          ),
        );
      } else if (!isMutationWrapperForDifferentTarget && kind == 'media') {
        commands.add(
          ProfessionalSceneCommand(
            type: ProfessionalSceneCommandType.registerMediaBinding,
            source: ProfessionalSceneCommandSource.mcpAgent,
            target: ProfessionalSceneCommandTarget(
              mode: ProfessionalSceneCommandTargetMode.layerId,
              id: _targetIdForIntent(
                remoteLayer: remoteLayer,
                payload: payload,
                updates: updates,
                payloadPayload: payloadPayload,
                updatesPayload: updatesPayload,
                intent: intent,
              ),
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
              id: _targetIdForIntent(
                remoteLayer: remoteLayer,
                payload: payload,
                updates: updates,
                payloadPayload: payloadPayload,
                updatesPayload: updatesPayload,
                intent: UniversalLayerApplyIntent.motionMutation,
              ),
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
              id: _targetIdForIntent(
                remoteLayer: remoteLayer,
                payload: payload,
                updates: updates,
                payloadPayload: payloadPayload,
                updatesPayload: updatesPayload,
                intent: UniversalLayerApplyIntent.update,
              ),
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

  static String? _targetIdForIntent({
    required Map<String, Object?> remoteLayer,
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
    required Map<String, Object?> payloadPayload,
    required Map<String, Object?> updatesPayload,
    required UniversalLayerApplyIntent intent,
  }) {
    final mutationTarget = _firstText(<Object?>[
      payload['targetLayerId'],
      updates['targetLayerId'],
      payloadPayload['targetLayerId'],
      updatesPayload['targetLayerId'],
      payload['layerId'],
      updates['layerId'],
      payloadPayload['layerId'],
      updatesPayload['layerId'],
      payload['requestedLayerId'],
      updates['requestedLayerId'],
      payloadPayload['requestedLayerId'],
      updatesPayload['requestedLayerId'],
      payload['localLayerId'],
      updates['localLayerId'],
      payloadPayload['localLayerId'],
      updatesPayload['localLayerId'],
      payload['clipId'],
      updates['clipId'],
      payloadPayload['clipId'],
      updatesPayload['clipId'],
    ]);
    if (intent != UniversalLayerApplyIntent.insert) {
      return mutationTarget ??
          _firstText(<Object?>[
            remoteLayer['id'],
            payload['remoteLayerId'],
            updates['remoteLayerId'],
            payloadPayload['remoteLayerId'],
            updatesPayload['remoteLayerId'],
          ]);
    }
    return _firstText(<Object?>[
      remoteLayer['id'],
      payload['remoteLayerId'],
      updates['remoteLayerId'],
      payloadPayload['remoteLayerId'],
      updatesPayload['remoteLayerId'],
      mutationTarget,
    ]);
  }
}
