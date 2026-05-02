import '../../domain/models/professional_normal_transition_models.dart';
import '../models/timeline_mock_models.dart';

class NormalTransitionTimelineAdapter {
  const NormalTransitionTimelineAdapter();

  static const String crossDissolveDefinitionId = 'cross_dissolve';
  static const String fadeBlackDefinitionId = 'fade_black';
  static const String zoomInCameraDefinitionId = 'zoom_in_camera';
  static const String distortionZoomInV1DefinitionId = 'distortion_zoom_in_v1';

  TimelineTransitionPreset? presetForDefinitionId(String definitionId) {
    return switch (definitionId) {
      crossDissolveDefinitionId => TimelineTransitionPreset.crossDissolve,
      fadeBlackDefinitionId => TimelineTransitionPreset.fadeBlack,
      zoomInCameraDefinitionId => TimelineTransitionPreset.zoomInCamera,
      distortionZoomInV1DefinitionId =>
        TimelineTransitionPreset.distortionZoomInV1,
      _ => null,
    };
  }

  String? definitionIdForPreset(TimelineTransitionPreset preset) {
    return switch (preset) {
      TimelineTransitionPreset.crossDissolve => crossDissolveDefinitionId,
      TimelineTransitionPreset.fadeBlack => fadeBlackDefinitionId,
      TimelineTransitionPreset.zoomInCamera => zoomInCameraDefinitionId,
      TimelineTransitionPreset.zoomInPro => zoomInCameraDefinitionId,
      TimelineTransitionPreset.distortionZoomInV1 =>
        distortionZoomInV1DefinitionId,
      TimelineTransitionPreset.manual ||
      TimelineTransitionPreset.aiGenerated =>
        null,
    };
  }

  TimelineTrackTransitionData? toTimelineTransition({
    required NormalTransitionNode node,
    required NormalTransitionInstance instance,
    NormalTransitionOverlapWindow? window,
  }) {
    final preset = presetForDefinitionId(node.definitionId);
    if (preset == null || instance.nodeId != node.id) {
      return null;
    }
    return TimelineTrackTransitionData(
      id: node.id,
      leftClipId: node.leftClipId,
      rightClipId: node.rightClipId,
      preset: preset,
      durationTime: node.duration,
      leadingDurationTime: window?.leadingDuration,
      trailingDurationTime: window?.trailingDuration,
      curve: TimelineTransitionCurve.linear,
      parameterValues: _doubleParameterValues(instance.parameterValues),
    );
  }

  NormalTransitionTimelineAdapterResult fromTimelineTransition({
    required TimelineTrackTransitionData transition,
    required String trackId,
    required NormalTransitionDefinition definition,
    NormalTransitionSourceKind sourceKind =
        NormalTransitionSourceKind.builtInPreset,
  }) {
    final definitionId = definitionIdForPreset(transition.preset);
    if (definitionId == null) {
      return NormalTransitionTimelineAdapterResult(
        issues: <NormalTransitionIssue>[
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Timeline preset `${transition.preset.name}` is not a normal transition preset.',
            path: 'preset',
          ),
        ],
      );
    }
    if (definition.definitionId != definitionId) {
      return NormalTransitionTimelineAdapterResult(
        issues: <NormalTransitionIssue>[
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Definition `${definition.definitionId}` does not match preset `${transition.preset.name}`.',
            path: 'definitionId',
          ),
        ],
      );
    }
    final parameterValues = <String, Object>{
      ...definition.defaultParameterValues,
      ...transition.parameterValues,
    };
    final instanceId = '${transition.id}.instance';
    final node = NormalTransitionNode(
      id: transition.id,
      trackId: trackId,
      leftClipId: transition.leftClipId,
      rightClipId: transition.rightClipId,
      definitionId: definition.definitionId,
      duration: transition.durationTime,
      alignment: NormalTransitionAlignment.symmetric,
      schemaVersion: definition.schemaVersion,
      parameterValues: parameterValues,
      instanceId: instanceId,
    );
    final instance = NormalTransitionInstance(
      id: instanceId,
      nodeId: node.id,
      definitionId: definition.definitionId,
      sourceKind: sourceKind,
      sourceHash: _defaultSourceHash(definition),
      schemaVersion: definition.schemaVersion,
      parameterValues: parameterValues,
      channels: definition.channels,
    );
    return NormalTransitionTimelineAdapterResult(
      node: node,
      instance: instance,
      issues: const <NormalTransitionIssue>[],
    );
  }

  Map<String, double> _doubleParameterValues(Map<String, Object> parameters) {
    return Map<String, double>.unmodifiable(<String, double>{
      for (final entry in parameters.entries)
        if (entry.value is num) entry.key: (entry.value as num).toDouble(),
    });
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
}

class NormalTransitionTimelineAdapterResult {
  const NormalTransitionTimelineAdapterResult({
    required this.issues,
    this.node,
    this.instance,
  });

  final NormalTransitionNode? node;
  final NormalTransitionInstance? instance;
  final List<NormalTransitionIssue> issues;

  bool get canAdapt =>
      node != null &&
      instance != null &&
      !issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );
}
