import '../../domain/models/professional_motion_models.dart';
import '../../domain/models/professional_normal_transition_models.dart';
import '../../domain/services/composition_timeline_projection.dart';
import '../../domain/services/normal_transition_graph_authoring_service.dart';
import '../models/timeline_time.dart';
import 'transition_scope_graph_lane_adapter.dart';

class TransitionScopeGraphAuthoringRequest {
  TransitionScopeGraphAuthoringRequest({
    required this.project,
    required this.sceneId,
    required this.definition,
    required this.trackId,
    required this.leftClipId,
    required this.rightClipId,
    required this.outgoingLayerId,
    required this.incomingLayerId,
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
    this.targetClipId,
    Map<String, Object> parameterOverrides = const <String, Object>{},
  }) : parameterOverrides = Map.unmodifiable(parameterOverrides);

  final MotionProjectModel project;
  final String sceneId;
  final NormalTransitionDefinition definition;
  final String trackId;
  final String leftClipId;
  final String rightClipId;
  final String outgoingLayerId;
  final String incomingLayerId;
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
  final String? targetClipId;
  final Map<String, Object> parameterOverrides;
}

class TransitionScopeGraphAuthoringResult {
  const TransitionScopeGraphAuthoringResult({
    required this.graph,
    required this.projectionIssues,
    this.scope,
    this.lanes,
  });

  final NormalTransitionGraphApplyResult graph;
  final ScopeProjection? scope;
  final TransitionScopeGraphLaneProjection? lanes;
  final List<CompositionProjectionIssue> projectionIssues;

  bool get canOpenUnifiedScope =>
      graph.canApply &&
      scope != null &&
      lanes != null &&
      projectionIssues.isEmpty &&
      !lanes!.hasIssues;
}

class TransitionScopeGraphAuthoringAdapter {
  const TransitionScopeGraphAuthoringAdapter({
    this.graphAuthoring = const NormalTransitionGraphAuthoringService(),
    this.projectionResolver = const CompositionTimelineProjectionResolver(),
    this.laneAdapter = const TransitionScopeGraphLaneAdapter(),
  });

  final NormalTransitionGraphAuthoringService graphAuthoring;
  final CompositionTimelineProjectionResolver projectionResolver;
  final TransitionScopeGraphLaneAdapter laneAdapter;

  TransitionScopeGraphAuthoringResult applyPresetToUnifiedScope(
    TransitionScopeGraphAuthoringRequest request,
  ) {
    final graph = graphAuthoring.createFromDefinition(
      NormalTransitionGraphApplyRequest(
        definition: request.definition,
        trackId: request.trackId,
        leftClipId: request.leftClipId,
        rightClipId: request.rightClipId,
        boundaryTime: request.boundaryTime,
        leftAvailableTail: request.leftAvailableTail,
        rightAvailableHead: request.rightAvailableHead,
        outgoingTarget: request.outgoingTarget,
        incomingTarget: request.incomingTarget,
        nodeId: request.nodeId,
        instanceId: request.instanceId,
        duration: request.duration,
        alignment: request.alignment,
        sourceKind: request.sourceKind,
        sourceHash: request.sourceHash,
        parameterOverrides: request.parameterOverrides,
      ),
    );
    final bundle = graph.bundle;
    if (!graph.canApply || bundle == null) {
      return TransitionScopeGraphAuthoringResult(
        graph: graph,
        projectionIssues: const <CompositionProjectionIssue>[],
      );
    }

    final scopeResult = projectionResolver.resolveTransitionScope(
      project: request.project,
      context: TransitionScopeContext(
        id: bundle.transitionWindowId,
        sceneId: request.sceneId,
        outgoingLayerId: request.outgoingLayerId,
        incomingLayerId: request.incomingLayerId,
        windowRange: bundle.windowRange,
      ),
      globalTime: request.boundaryTime,
      channels: bundle.channels,
    );
    final scope = scopeResult.projection;
    if (scope == null) {
      return TransitionScopeGraphAuthoringResult(
        graph: graph,
        projectionIssues: scopeResult.issues,
      );
    }

    final lanes = laneAdapter.lanesForBundle(
      projection: scope,
      bundle: bundle,
      targetClipId: request.targetClipId ?? bundle.transitionWindowId,
    );
    return TransitionScopeGraphAuthoringResult(
      graph: graph,
      scope: scope,
      lanes: lanes,
      projectionIssues: scopeResult.issues,
    );
  }
}
