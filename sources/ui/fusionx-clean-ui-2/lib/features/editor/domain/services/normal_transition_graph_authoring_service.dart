import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_normal_transition_models.dart';
import 'normal_transition_authoring_service.dart';
import 'normal_transition_motion_graph_lowerer.dart';

@immutable
class NormalTransitionGraphApplyRequest {
  NormalTransitionGraphApplyRequest({
    required this.definition,
    required this.trackId,
    required this.leftClipId,
    required this.rightClipId,
    required this.boundaryTime,
    required this.leftAvailableTail,
    required this.rightAvailableHead,
    required this.outgoingTarget,
    required this.incomingTarget,
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
  final MotionPropertyTarget outgoingTarget;
  final MotionPropertyTarget incomingTarget;
  final String? nodeId;
  final String? instanceId;
  final TimelineTime? duration;
  final NormalTransitionAlignment alignment;
  final NormalTransitionSourceKind sourceKind;
  final String? sourceHash;
  final Map<String, Object> parameterOverrides;
}

@immutable
class NormalTransitionGraphApplyResult {
  NormalTransitionGraphApplyResult({
    required List<NormalTransitionIssue> issues,
    required List<MotionPropertyChannelModel> graphChannels,
    this.node,
    this.instance,
    this.window,
  })  : issues = List.unmodifiable(issues),
        graphChannels = List.unmodifiable(graphChannels);

  final NormalTransitionNode? node;
  final NormalTransitionInstance? instance;
  final NormalTransitionOverlapWindow? window;
  final List<MotionPropertyChannelModel> graphChannels;
  final List<NormalTransitionIssue> issues;

  bool get hasErrors => issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );

  bool get canApply =>
      node != null &&
      instance != null &&
      window != null &&
      graphChannels.isNotEmpty &&
      !hasErrors;
}

class NormalTransitionGraphAuthoringService {
  const NormalTransitionGraphAuthoringService({
    this.authoring = const NormalTransitionAuthoringService(),
    this.lowerer = const NormalTransitionMotionGraphLowerer(),
  });

  final NormalTransitionAuthoringService authoring;
  final NormalTransitionMotionGraphLowerer lowerer;

  NormalTransitionGraphApplyResult createFromDefinition(
    NormalTransitionGraphApplyRequest request,
  ) {
    final authored = authoring.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: request.definition,
        trackId: request.trackId,
        leftClipId: request.leftClipId,
        rightClipId: request.rightClipId,
        boundaryTime: request.boundaryTime,
        leftAvailableTail: request.leftAvailableTail,
        rightAvailableHead: request.rightAvailableHead,
        nodeId: request.nodeId,
        instanceId: request.instanceId,
        duration: request.duration,
        alignment: request.alignment,
        sourceKind: request.sourceKind,
        sourceHash: request.sourceHash,
        parameterOverrides: request.parameterOverrides,
      ),
    );
    final issues = <NormalTransitionIssue>[...authored.issues];
    final node = authored.node;
    final instance = authored.instance;
    final window = authored.window;
    if (!authored.canApply ||
        node == null ||
        instance == null ||
        window == null) {
      return NormalTransitionGraphApplyResult(
        node: node,
        instance: instance,
        window: window,
        graphChannels: const <MotionPropertyChannelModel>[],
        issues: issues,
      );
    }

    final lowered = lowerer.lower(
      NormalTransitionMotionGraphLoweringRequest(
        node: node,
        instance: instance,
        window: window,
        outgoingTarget: request.outgoingTarget,
        incomingTarget: request.incomingTarget,
      ),
    );
    issues.addAll(lowered.issues);
    if (lowered.channels.isEmpty && !lowered.hasErrors) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message:
              'Transition `${request.definition.definitionId}` produced no graph channels.',
          path: 'channels',
        ),
      );
    }

    return NormalTransitionGraphApplyResult(
      node: node,
      instance: instance,
      window: window,
      graphChannels: lowered.channels,
      issues: issues,
    );
  }
}
