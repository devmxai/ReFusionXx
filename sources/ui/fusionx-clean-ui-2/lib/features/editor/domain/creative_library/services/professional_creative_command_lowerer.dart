import '../models/professional_creative_library_registry_models.dart';

class CreativeLoweringProjection {
  const CreativeLoweringProjection({
    required this.ok,
    this.blockerCode,
    this.blockerReason,
    this.graphNodes = const <Map<String, Object?>>[],
    this.timelineClips = const <Map<String, Object?>>[],
    this.effectInstances = const <Map<String, Object?>>[],
    this.motionChannels = const <Map<String, Object?>>[],
    this.updatedTargetIds = const <String>{},
  });

  final bool ok;
  final String? blockerCode;
  final String? blockerReason;
  final List<Map<String, Object?>> graphNodes;
  final List<Map<String, Object?>> timelineClips;
  final List<Map<String, Object?>> effectInstances;
  final List<Map<String, Object?>> motionChannels;
  final Set<String> updatedTargetIds;

  bool get timelineVisible => timelineClips.isNotEmpty;
  bool get graphVisible => graphNodes.isNotEmpty;

  Map<String, Object?> toProofMap() {
    return <String, Object?>{
      'graphVisible': graphVisible,
      'timelineVisible': timelineVisible,
      'graphNodeCount': graphNodes.length,
      'timelineClipCount': timelineClips.length,
      'effectInstanceCount': effectInstances.length,
      'motionChannelCount': motionChannels.length,
      'updatedTargetIds': updatedTargetIds.toList(growable: false),
    };
  }
}

class ProfessionalCreativeCommandLowerer {
  const ProfessionalCreativeCommandLowerer();

  CreativeLoweringProjection lower({
    required List<ProfessionalSceneCommandEnvelope> envelopes,
  }) {
    final graphNodes = <Map<String, Object?>>[];
    final timelineClips = <Map<String, Object?>>[];
    final effectInstances = <Map<String, Object?>>[];
    final motionChannels = <Map<String, Object?>>[];
    final updatedTargetIds = <String>{};

    for (final envelope in envelopes) {
      final targetId = envelope.targetId.trim();
      if (targetId.isEmpty) {
        return const CreativeLoweringProjection(
          ok: false,
          blockerCode: 'TARGET_REQUIRED',
          blockerReason: 'Target id is required for lowering.',
        );
      }
      final payload = envelope.payload;
      final capabilityId = _asText(payload['capabilityId']) ?? 'unknown';

      switch (envelope.commandFamily) {
        case CommandFamilyDefinition.insertComponent:
        case CommandFamilyDefinition.insertText:
        case CommandFamilyDefinition.insertShape:
        case CommandFamilyDefinition.insertMedia:
          graphNodes.add(<String, Object?>{
            'targetId': targetId,
            'capabilityId': capabilityId,
            'nodeKind': envelope.commandFamily.name,
            'payload': payload,
          });
          timelineClips.add(_buildTimelineClip(targetId, payload));
          break;
        case CommandFamilyDefinition.updateComponent:
        case CommandFamilyDefinition.updateText:
        case CommandFamilyDefinition.updateShape:
        case CommandFamilyDefinition.updateMediaBinding:
        case CommandFamilyDefinition.setLayout:
        case CommandFamilyDefinition.setTransform:
          updatedTargetIds.add(targetId);
          graphNodes.add(<String, Object?>{
            'targetId': targetId,
            'capabilityId': capabilityId,
            'patch': payload,
            'mode': 'update',
          });
          if (timelineClips
              .every((clip) => _asText(clip['targetId']) != targetId)) {
            timelineClips.add(_buildTimelineClip(targetId, payload));
          }
          break;
        case CommandFamilyDefinition.applyEffect:
        case CommandFamilyDefinition.updateEffect:
        case CommandFamilyDefinition.removeEffect:
          effectInstances.add(<String, Object?>{
            'targetId': targetId,
            'capabilityId': capabilityId,
            'commandFamily': envelope.commandFamily.name,
            'params': payload,
          });
          if (graphNodes
              .every((node) => _asText(node['targetId']) != targetId)) {
            graphNodes.add(<String, Object?>{
              'targetId': targetId,
              'capabilityId': capabilityId,
              'nodeKind': 'effectHost',
            });
          }
          break;
        case CommandFamilyDefinition.applyMotionRecipe:
        case CommandFamilyDefinition.applyKeyframes:
        case CommandFamilyDefinition.editKeyframe:
          motionChannels.add(<String, Object?>{
            'targetId': targetId,
            'capabilityId': capabilityId,
            'commandFamily': envelope.commandFamily.name,
            'params': payload,
          });
          if (graphNodes
              .every((node) => _asText(node['targetId']) != targetId)) {
            graphNodes.add(<String, Object?>{
              'targetId': targetId,
              'capabilityId': capabilityId,
              'nodeKind': 'motionHost',
            });
          }
          break;
        case CommandFamilyDefinition.insertTemplate:
        case CommandFamilyDefinition.compileTemplate:
          graphNodes.add(<String, Object?>{
            'targetId': targetId,
            'capabilityId': capabilityId,
            'nodeKind': 'template',
            'payload': payload,
          });
          timelineClips.add(_buildTimelineClip(targetId, payload));
          break;
        default:
          return CreativeLoweringProjection(
            ok: false,
            blockerCode: 'UNSUPPORTED_COMMAND_FAMILY_FOR_LOWERING',
            blockerReason:
                'Lowerer does not support `${envelope.commandFamily.name}`.',
            graphNodes: graphNodes,
            timelineClips: timelineClips,
            effectInstances: effectInstances,
            motionChannels: motionChannels,
            updatedTargetIds: updatedTargetIds,
          );
      }
    }

    return CreativeLoweringProjection(
      ok: true,
      graphNodes: List<Map<String, Object?>>.unmodifiable(graphNodes),
      timelineClips: List<Map<String, Object?>>.unmodifiable(timelineClips),
      effectInstances: List<Map<String, Object?>>.unmodifiable(effectInstances),
      motionChannels: List<Map<String, Object?>>.unmodifiable(motionChannels),
      updatedTargetIds: Set<String>.unmodifiable(updatedTargetIds),
    );
  }

  Map<String, Object?> _buildTimelineClip(
    String targetId,
    Map<String, Object?> payload,
  ) {
    final startMs = _asInt(payload['startMs']) ?? 0;
    final durationMs = _asInt(payload['durationMs']) ?? 1000;
    return <String, Object?>{
      'targetId': targetId,
      'timelineClipId': 'clip.$targetId',
      'trackKind': _asText(payload['trackKind']) ?? 'visual',
      'startMs': startMs < 0 ? 0 : startMs,
      'durationMs': durationMs <= 0 ? 1 : durationMs,
      'zIndex': _asInt(payload['zIndex']) ?? 0,
    };
  }

  String? _asText(Object? value) {
    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
