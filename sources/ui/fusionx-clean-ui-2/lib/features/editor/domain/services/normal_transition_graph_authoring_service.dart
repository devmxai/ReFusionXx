import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_normal_transition_models.dart';
import 'normal_transition_authoring_service.dart';
import 'normal_transition_motion_graph_lowerer.dart';

enum NormalTransitionGraphChannelRole {
  outgoing,
  incoming,
}

@immutable
class NormalTransitionGraphChannelBinding {
  const NormalTransitionGraphChannelBinding({
    required this.channelId,
    required this.role,
    required this.target,
    required this.propertyId,
  });

  final String channelId;
  final NormalTransitionGraphChannelRole role;
  final MotionPropertyTarget target;
  final String propertyId;
}

@immutable
class NormalTransitionGraphAuthoringBundle {
  NormalTransitionGraphAuthoringBundle({
    required this.animationGroupId,
    required this.presetId,
    required this.transitionWindowId,
    required this.nodeId,
    required this.instanceId,
    required this.windowRange,
    required List<MotionPropertyChannelModel> channels,
    required List<NormalTransitionGraphChannelBinding> channelBindings,
  })  : channels = List.unmodifiable(channels),
        channelBindings = List.unmodifiable(channelBindings);

  final String animationGroupId;
  final String presetId;
  final String transitionWindowId;
  final String nodeId;
  final String instanceId;
  final TimelineTimeRange windowRange;
  final List<MotionPropertyChannelModel> channels;
  final List<NormalTransitionGraphChannelBinding> channelBindings;

  List<MotionPropertyChannelModel> channelsForRole(
    NormalTransitionGraphChannelRole role,
  ) {
    final channelIds = channelBindings
        .where((binding) => binding.role == role)
        .map((binding) => binding.channelId)
        .toSet();
    return channels
        .where((channel) => channelIds.contains(channel.id))
        .toList(growable: false);
  }

  NormalTransitionGraphChannelBinding? bindingForChannel(String channelId) {
    for (final binding in channelBindings) {
      if (binding.channelId == channelId) {
        return binding;
      }
    }
    return null;
  }

  Map<String, String> metadataForChannel(String channelId) {
    final binding = bindingForChannel(channelId);
    return <String, String>{
      'animationGroupId': animationGroupId,
      'presetId': presetId,
      'transitionWindowId': transitionWindowId,
      'nodeId': nodeId,
      'instanceId': instanceId,
      if (binding != null) 'role': binding.role.name,
      if (binding != null) 'propertyId': binding.propertyId,
    };
  }
}

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
    this.bundle,
    this.node,
    this.instance,
    this.window,
  })  : issues = List.unmodifiable(issues),
        graphChannels = List.unmodifiable(graphChannels);

  final NormalTransitionNode? node;
  final NormalTransitionInstance? instance;
  final NormalTransitionOverlapWindow? window;
  final NormalTransitionGraphAuthoringBundle? bundle;
  final List<MotionPropertyChannelModel> graphChannels;
  final List<NormalTransitionIssue> issues;

  bool get hasErrors => issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );

  bool get canApply =>
      node != null &&
      instance != null &&
      window != null &&
      bundle != null &&
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

    final bundle = _bundleFor(
      node: node,
      instance: instance,
      window: window,
      channels: lowered.channels,
      outgoingTarget: request.outgoingTarget,
      incomingTarget: request.incomingTarget,
    );

    return NormalTransitionGraphApplyResult(
      node: node,
      instance: instance,
      window: window,
      bundle: bundle,
      graphChannels: lowered.channels,
      issues: issues,
    );
  }

  NormalTransitionGraphAuthoringBundle _bundleFor({
    required NormalTransitionNode node,
    required NormalTransitionInstance instance,
    required NormalTransitionOverlapWindow window,
    required List<MotionPropertyChannelModel> channels,
    required MotionPropertyTarget outgoingTarget,
    required MotionPropertyTarget incomingTarget,
  }) {
    return NormalTransitionGraphAuthoringBundle(
      animationGroupId: 'transition.${node.id}.group',
      presetId: node.definitionId,
      transitionWindowId: node.id,
      nodeId: node.id,
      instanceId: instance.id,
      windowRange: TimelineTimeRange(
        start: window.start,
        endExclusive: window.endExclusive,
      ),
      channels: channels,
      channelBindings: channels
          .map(
            (channel) => NormalTransitionGraphChannelBinding(
              channelId: channel.id,
              role: _roleForChannel(
                channel: channel,
                outgoingTarget: outgoingTarget,
                incomingTarget: incomingTarget,
              ),
              target: channel.target,
              propertyId: channel.definition.id,
            ),
          )
          .toList(growable: false),
    );
  }

  NormalTransitionGraphChannelRole _roleForChannel({
    required MotionPropertyChannelModel channel,
    required MotionPropertyTarget outgoingTarget,
    required MotionPropertyTarget incomingTarget,
  }) {
    if (channel.target.canonicalAddress == outgoingTarget.canonicalAddress) {
      return NormalTransitionGraphChannelRole.outgoing;
    }
    if (channel.target.canonicalAddress == incomingTarget.canonicalAddress) {
      return NormalTransitionGraphChannelRole.incoming;
    }
    if (channel.target.targetId == outgoingTarget.targetId) {
      return NormalTransitionGraphChannelRole.outgoing;
    }
    if (channel.target.targetId == incomingTarget.targetId) {
      return NormalTransitionGraphChannelRole.incoming;
    }
    return NormalTransitionGraphChannelRole.incoming;
  }
}
