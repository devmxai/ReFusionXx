import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_normal_transition_models.dart';

@immutable
class NormalTransitionApplyRequest {
  NormalTransitionApplyRequest({
    required this.definition,
    required this.trackId,
    required this.leftClipId,
    required this.rightClipId,
    required this.boundaryTime,
    required this.leftAvailableTail,
    required this.rightAvailableHead,
    this.nodeId,
    this.instanceId,
    this.duration,
    this.alignment = NormalTransitionAlignment.symmetric,
    this.sourceKind = NormalTransitionSourceKind.builtInPreset,
    this.sourceHash,
    Map<String, Object> parameterOverrides = const <String, Object>{},
  }) : parameterOverrides = Map.unmodifiable(parameterOverrides);

  final NormalTransitionDefinition definition;
  final String trackId;
  final String leftClipId;
  final String rightClipId;
  final TimelineTime boundaryTime;
  final TimelineTime leftAvailableTail;
  final TimelineTime rightAvailableHead;
  final String? nodeId;
  final String? instanceId;
  final TimelineTime? duration;
  final NormalTransitionAlignment alignment;
  final NormalTransitionSourceKind sourceKind;
  final String? sourceHash;
  final Map<String, Object> parameterOverrides;
}

@immutable
class NormalTransitionApplyResult {
  const NormalTransitionApplyResult({
    required this.issues,
    this.node,
    this.instance,
    this.window,
  });

  final NormalTransitionNode? node;
  final NormalTransitionInstance? instance;
  final NormalTransitionOverlapWindow? window;
  final List<NormalTransitionIssue> issues;

  bool get canApply =>
      node != null &&
      instance != null &&
      window != null &&
      !issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );
}

class NormalTransitionAuthoringService {
  const NormalTransitionAuthoringService();

  NormalTransitionApplyResult createFromDefinition(
    NormalTransitionApplyRequest request,
  ) {
    final issues = <NormalTransitionIssue>[];
    final duration = request.duration ?? request.definition.defaultDuration;
    _validateDuration(
      duration: duration,
      definition: request.definition,
      issues: issues,
    );
    final parameterValues = _resolveParameterValues(
      definition: request.definition,
      overrides: request.parameterOverrides,
      issues: issues,
    );

    final nodeId = request.nodeId ??
        _defaultNodeId(
          trackId: request.trackId,
          leftClipId: request.leftClipId,
          rightClipId: request.rightClipId,
          definitionId: request.definition.definitionId,
        );
    final instanceId = request.instanceId ?? '$nodeId.instance';
    final node = NormalTransitionNode(
      id: nodeId,
      trackId: request.trackId,
      leftClipId: request.leftClipId,
      rightClipId: request.rightClipId,
      definitionId: request.definition.definitionId,
      duration: duration,
      alignment: request.alignment,
      schemaVersion: request.definition.schemaVersion,
      parameterValues: parameterValues,
      instanceId: instanceId,
    );
    final handleValidation = node.validateHandles(
      boundaryTime: request.boundaryTime,
      leftAvailableTail: request.leftAvailableTail,
      rightAvailableHead: request.rightAvailableHead,
    );
    issues.addAll(handleValidation.issues);

    final hasErrors = issues.any(
      (issue) => issue.severity == NormalTransitionIssueSeverity.error,
    );
    if (hasErrors) {
      return NormalTransitionApplyResult(
        issues: List.unmodifiable(issues),
        window: handleValidation.window,
      );
    }

    final instance = NormalTransitionInstance(
      id: instanceId,
      nodeId: node.id,
      definitionId: request.definition.definitionId,
      sourceKind: request.sourceKind,
      sourceHash: request.sourceHash ?? _defaultSourceHash(request.definition),
      schemaVersion: request.definition.schemaVersion,
      parameterValues: parameterValues,
      channels: request.definition.channels,
    );
    return NormalTransitionApplyResult(
      node: node,
      instance: instance,
      window: handleValidation.window,
      issues: List.unmodifiable(issues),
    );
  }

  void _validateDuration({
    required TimelineTime duration,
    required NormalTransitionDefinition definition,
    required List<NormalTransitionIssue> issues,
  }) {
    if (duration < definition.minDuration) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message:
              'Transition duration is shorter than `${definition.definitionId}` minimum.',
          path: 'duration',
        ),
      );
    }
    if (duration > definition.maxDuration) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message:
              'Transition duration is longer than `${definition.definitionId}` maximum.',
          path: 'duration',
        ),
      );
    }
  }

  Map<String, Object> _resolveParameterValues({
    required NormalTransitionDefinition definition,
    required Map<String, Object> overrides,
    required List<NormalTransitionIssue> issues,
  }) {
    final values = Map<String, Object>.from(definition.defaultParameterValues);
    final schemaByName = <String, NormalTransitionParameterSchema>{
      for (final parameter in definition.parameters) parameter.name: parameter,
    };
    for (final entry in overrides.entries) {
      final schema = schemaByName[entry.key];
      if (schema == null) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Unknown transition parameter `${entry.key}` for `${definition.definitionId}`.',
            path: 'parameters.${entry.key}',
          ),
        );
        continue;
      }
      if (!schema.accepts(entry.value)) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Transition parameter `${entry.key}` does not match its schema.',
            path: 'parameters.${entry.key}',
          ),
        );
        continue;
      }
      values[entry.key] = entry.value;
    }
    return Map<String, Object>.unmodifiable(values);
  }

  String _defaultNodeId({
    required String trackId,
    required String leftClipId,
    required String rightClipId,
    required String definitionId,
  }) {
    return 'transition.${_sanitizeId(trackId)}.${_sanitizeId(leftClipId)}.'
        '${_sanitizeId(rightClipId)}.${_sanitizeId(definitionId)}';
  }

  String _defaultSourceHash(NormalTransitionDefinition definition) {
    return [
      definition.schemaVersion,
      definition.definitionId,
      definition.rendererTier.name,
      definition.channels.length,
      definition.parameters.length,
    ].join(':');
  }

  String _sanitizeId(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]+'), '_');
    return sanitized.isEmpty ? 'item' : sanitized;
  }
}
