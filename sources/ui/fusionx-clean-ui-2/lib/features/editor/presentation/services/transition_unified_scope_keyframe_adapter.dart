import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/services/composition_timeline_projection.dart';
import '../../domain/services/normal_transition_graph_authoring_service.dart';
import '../../domain/services/unified_keyframe_operations.dart';
import '../models/timeline_time.dart';
import 'transition_scope_graph_lane_adapter.dart';
import 'transition_unified_scope_bridge_entry_adapter.dart';
import 'transition_unified_scope_timeline_session_adapter.dart';

class TransitionUnifiedScopeKeyframeOperationResult {
  TransitionUnifiedScopeKeyframeOperationResult({
    required this.session,
    required this.viewModel,
    required List<UnifiedKeyframeIssue> issues,
    required Set<String> selectedKeyframeIds,
    required Set<String> changedKeyframeIds,
    this.selectedLaneId,
  })  : issues = List.unmodifiable(issues),
        selectedKeyframeIds = Set.unmodifiable(selectedKeyframeIds),
        changedKeyframeIds = Set.unmodifiable(changedKeyframeIds);

  final TransitionUnifiedScopeBridgeSession session;
  final TransitionUnifiedScopeTimelineViewModel viewModel;
  final List<UnifiedKeyframeIssue> issues;
  final Set<String> selectedKeyframeIds;
  final Set<String> changedKeyframeIds;
  final String? selectedLaneId;

  bool get hasIssues => issues.isNotEmpty;
  String? get primaryKeyframeId =>
      selectedKeyframeIds.isEmpty ? null : selectedKeyframeIds.first;
}

class TransitionUnifiedScopeAddKeyframeRequest {
  const TransitionUnifiedScopeAddKeyframeRequest({
    required this.session,
    required this.laneId,
    required this.localTime,
    this.value,
    this.interpolation = const MotionInterpolationSpec.linear(),
  });

  final TransitionUnifiedScopeBridgeSession session;
  final String laneId;
  final TimelineTime localTime;
  final MotionPropertyValue? value;
  final MotionInterpolationSpec interpolation;
}

class TransitionUnifiedScopeMoveKeyframeRequest {
  const TransitionUnifiedScopeMoveKeyframeRequest({
    required this.session,
    required this.laneId,
    required this.keyframeId,
    required this.localTime,
  });

  final TransitionUnifiedScopeBridgeSession session;
  final String laneId;
  final String keyframeId;
  final TimelineTime localTime;
}

class TransitionUnifiedScopeSetValueRequest {
  const TransitionUnifiedScopeSetValueRequest({
    required this.session,
    required this.laneId,
    required this.keyframeId,
    required this.value,
  });

  final TransitionUnifiedScopeBridgeSession session;
  final String laneId;
  final String keyframeId;
  final MotionPropertyValue value;
}

class TransitionUnifiedScopeSetInterpolationRequest {
  const TransitionUnifiedScopeSetInterpolationRequest({
    required this.session,
    required this.laneId,
    required this.keyframeId,
    required this.interpolation,
  });

  final TransitionUnifiedScopeBridgeSession session;
  final String laneId;
  final String keyframeId;
  final MotionInterpolationSpec interpolation;
}

class TransitionUnifiedScopeDeleteKeyframeRequest {
  const TransitionUnifiedScopeDeleteKeyframeRequest({
    required this.session,
    required this.laneId,
    required this.keyframeId,
  });

  final TransitionUnifiedScopeBridgeSession session;
  final String laneId;
  final String keyframeId;
}

class TransitionUnifiedScopeKeyframeAdapter {
  const TransitionUnifiedScopeKeyframeAdapter({
    this.operations = const UnifiedKeyframeOperations(),
    this.laneAdapter = const TransitionScopeGraphLaneAdapter(),
    this.timelineSessionAdapter =
        const TransitionUnifiedScopeTimelineSessionAdapter(),
  });

  final UnifiedKeyframeOperations operations;
  final TransitionScopeGraphLaneAdapter laneAdapter;
  final TransitionUnifiedScopeTimelineSessionAdapter timelineSessionAdapter;

  TransitionUnifiedScopeKeyframeOperationResult addKeyframe(
    TransitionUnifiedScopeAddKeyframeRequest request,
  ) {
    final resolved = _resolveLaneChannel(
      session: request.session,
      laneId: request.laneId,
    );
    if (resolved.issue != null) {
      return _blocked(
        session: request.session,
        selectedLaneId: request.laneId,
        issue: resolved.issue!,
      );
    }
    final channel = resolved.channel!;
    final result = operations.addKeyframe(
      UnifiedKeyframeAddRequest(
        channels: request.session.graphBundle.channels,
        target: channel.target,
        activeRange: request.session.scope.localRange,
        definition: channel.definition,
        time: request.localTime,
        value: request.value ?? channel.fallbackValue,
        interpolation: request.interpolation,
      ),
    );
    return _fromOperationResult(
      source: request.session,
      selectedLaneId: request.laneId,
      result: result,
    );
  }

  TransitionUnifiedScopeKeyframeOperationResult moveKeyframe(
    TransitionUnifiedScopeMoveKeyframeRequest request,
  ) {
    final resolved = _resolveLaneChannel(
      session: request.session,
      laneId: request.laneId,
    );
    if (resolved.issue != null) {
      return _blocked(
        session: request.session,
        selectedLaneId: request.laneId,
        issue: resolved.issue!,
      );
    }
    final result = operations.moveKeyframe(
      UnifiedKeyframeMoveRequest(
        channels: request.session.graphBundle.channels,
        channelId: resolved.channel!.id,
        keyframeId: request.keyframeId,
        time: request.localTime,
        activeRange: request.session.scope.localRange,
      ),
    );
    return _fromOperationResult(
      source: request.session,
      selectedLaneId: request.laneId,
      result: result,
    );
  }

  TransitionUnifiedScopeKeyframeOperationResult setKeyframeValue(
    TransitionUnifiedScopeSetValueRequest request,
  ) {
    final resolved = _resolveLaneChannel(
      session: request.session,
      laneId: request.laneId,
    );
    if (resolved.issue != null) {
      return _blocked(
        session: request.session,
        selectedLaneId: request.laneId,
        issue: resolved.issue!,
      );
    }
    final result = operations.setKeyframeValue(
      UnifiedKeyframeValueRequest(
        channels: request.session.graphBundle.channels,
        channelId: resolved.channel!.id,
        keyframeId: request.keyframeId,
        value: request.value,
      ),
    );
    return _fromOperationResult(
      source: request.session,
      selectedLaneId: request.laneId,
      result: result,
    );
  }

  TransitionUnifiedScopeKeyframeOperationResult setKeyframeInterpolation(
    TransitionUnifiedScopeSetInterpolationRequest request,
  ) {
    final resolved = _resolveLaneChannel(
      session: request.session,
      laneId: request.laneId,
    );
    if (resolved.issue != null) {
      return _blocked(
        session: request.session,
        selectedLaneId: request.laneId,
        issue: resolved.issue!,
      );
    }
    final result = operations.setKeyframeInterpolation(
      UnifiedKeyframeInterpolationRequest(
        channels: request.session.graphBundle.channels,
        channelId: resolved.channel!.id,
        keyframeId: request.keyframeId,
        interpolation: request.interpolation,
      ),
    );
    return _fromOperationResult(
      source: request.session,
      selectedLaneId: request.laneId,
      result: result,
    );
  }

  TransitionUnifiedScopeKeyframeOperationResult deleteKeyframe(
    TransitionUnifiedScopeDeleteKeyframeRequest request,
  ) {
    final resolved = _resolveLaneChannel(
      session: request.session,
      laneId: request.laneId,
    );
    if (resolved.issue != null) {
      return _blocked(
        session: request.session,
        selectedLaneId: request.laneId,
        issue: resolved.issue!,
      );
    }
    final result = operations.deleteKeyframe(
      UnifiedKeyframeDeleteRequest(
        channels: request.session.graphBundle.channels,
        channelId: resolved.channel!.id,
        keyframeId: request.keyframeId,
      ),
    );
    return _fromOperationResult(
      source: request.session,
      selectedLaneId: request.laneId,
      result: result,
    );
  }

  _ResolvedTransitionLaneChannel _resolveLaneChannel({
    required TransitionUnifiedScopeBridgeSession session,
    required String laneId,
  }) {
    final binding = session.bindingForLane(laneId);
    if (binding == null) {
      return _ResolvedTransitionLaneChannel(
        issue: UnifiedKeyframeIssue(
          code: UnifiedKeyframeIssueCode.missingChannel,
          message: 'Lane `$laneId` is not bound to a transition channel.',
          channelId: laneId,
        ),
      );
    }
    for (final channel in session.graphBundle.channels) {
      if (channel.id == binding.channelId) {
        return _ResolvedTransitionLaneChannel(channel: channel);
      }
    }
    return _ResolvedTransitionLaneChannel(
      issue: UnifiedKeyframeIssue(
        code: UnifiedKeyframeIssueCode.missingChannel,
        message: 'Transition channel `${binding.channelId}` was not found.',
        channelId: binding.channelId,
      ),
    );
  }

  TransitionUnifiedScopeKeyframeOperationResult _fromOperationResult({
    required TransitionUnifiedScopeBridgeSession source,
    required String selectedLaneId,
    required UnifiedKeyframeOperationResult result,
  }) {
    if (result.hasIssues) {
      return _blocked(
        session: source,
        selectedLaneId: selectedLaneId,
        issues: result.issues,
      );
    }
    final session = _rebuildSession(source: source, channels: result.channels);
    return TransitionUnifiedScopeKeyframeOperationResult(
      session: session,
      viewModel: timelineSessionAdapter.viewModelForSession(session),
      issues: result.issues,
      selectedLaneId: selectedLaneId,
      selectedKeyframeIds: result.selectedKeyframeIds,
      changedKeyframeIds: result.changedKeyframeIds,
    );
  }

  TransitionUnifiedScopeKeyframeOperationResult _blocked({
    required TransitionUnifiedScopeBridgeSession session,
    required String selectedLaneId,
    UnifiedKeyframeIssue? issue,
    List<UnifiedKeyframeIssue>? issues,
  }) {
    return TransitionUnifiedScopeKeyframeOperationResult(
      session: session,
      viewModel: timelineSessionAdapter.viewModelForSession(session),
      issues: issues ?? <UnifiedKeyframeIssue>[issue!],
      selectedLaneId: selectedLaneId,
      selectedKeyframeIds: const <String>{},
      changedKeyframeIds: const <String>{},
    );
  }

  TransitionUnifiedScopeBridgeSession _rebuildSession({
    required TransitionUnifiedScopeBridgeSession source,
    required List<MotionPropertyChannelModel> channels,
  }) {
    final bundle = NormalTransitionGraphAuthoringBundle(
      animationGroupId: source.graphBundle.animationGroupId,
      presetId: source.graphBundle.presetId,
      transitionWindowId: source.graphBundle.transitionWindowId,
      nodeId: source.graphBundle.nodeId,
      instanceId: source.graphBundle.instanceId,
      windowRange: source.graphBundle.windowRange,
      channels: channels,
      channelBindings: source.graphBundle.channelBindings,
    );
    final scope = ScopeProjection(
      id: source.scope.id,
      mode: source.scope.mode,
      projectId: source.scope.projectId,
      sceneId: source.scope.sceneId,
      globalRange: source.scope.globalRange,
      localRange: source.scope.localRange,
      globalTime: source.scope.globalTime,
      localTime: source.scope.localTime,
      layers: source.scope.layers,
      elements: source.scope.elements,
      channels: channels,
      layerId: source.scope.layerId,
      transitionWindowId: source.scope.transitionWindowId,
    );
    final lanes = laneAdapter.lanesForBundle(
      projection: scope,
      bundle: bundle,
      targetClipId: source.laneProjection.lanes.isEmpty
          ? null
          : source.laneProjection.lanes.first.targetClipId,
    );
    return TransitionUnifiedScopeBridgeSession(
      id: source.id,
      project: source.project,
      definition: source.definition,
      graphBundle: bundle,
      scope: scope,
      laneProjection: lanes,
      leftClip: source.leftClip,
      rightClip: source.rightClip,
      trackId: source.trackId,
      leftClipId: source.leftClipId,
      rightClipId: source.rightClipId,
      outgoingLayerId: source.outgoingLayerId,
      incomingLayerId: source.incomingLayerId,
      outgoingElementId: source.outgoingElementId,
      incomingElementId: source.incomingElementId,
      boundaryTime: source.boundaryTime,
    );
  }
}

class _ResolvedTransitionLaneChannel {
  const _ResolvedTransitionLaneChannel({
    this.channel,
    this.issue,
  });

  final MotionPropertyChannelModel? channel;
  final UnifiedKeyframeIssue? issue;
}
