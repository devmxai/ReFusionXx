import '../../domain/models/professional_motion_models.dart';
import '../../domain/models/professional_normal_transition_models.dart';
import '../../domain/services/composition_timeline_projection.dart';
import '../../domain/services/normal_transition_graph_authoring_service.dart';
import '../../domain/services/normal_transition_catalog.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'normal_transition_timeline_adapter.dart';
import 'transition_scope_graph_lane_adapter.dart';
import 'transition_unified_scope_entry_gate.dart';
import 'transition_unified_scope_request_factory.dart';

enum TransitionUnifiedScopeBridgeFallbackReason {
  featureDisabled,
  unsupportedPreset,
  catalogBlocked,
  requestBlocked,
  entryGateBlocked,
}

class TransitionUnifiedScopeBridgeEntryRequest {
  const TransitionUnifiedScopeBridgeEntryRequest({
    required this.track,
    required this.leftClip,
    required this.rightClip,
    required this.preset,
    required this.projectId,
    required this.sceneId,
    required this.trackId,
    this.transition,
    this.format = const MotionProjectFormat(
      canvasSize: MotionSize2D(width: 1080, height: 1920),
    ),
    this.frameRate = const MotionFrameRate(numerator: 30, denominator: 1),
  });

  final TimelineTrackData track;
  final TimelineClipData leftClip;
  final TimelineClipData rightClip;
  final TimelineTransitionPreset preset;
  final TimelineTrackTransitionData? transition;
  final String projectId;
  final String sceneId;
  final String trackId;
  final MotionProjectFormat format;
  final MotionFrameRate frameRate;
}

class TransitionUnifiedScopeBridgeEntryResult {
  TransitionUnifiedScopeBridgeEntryResult({
    required this.decision,
    this.fallbackReason,
    this.definition,
    this.factoryResult,
    this.entryResult,
    this.session,
    List<NormalTransitionIssue> issues = const <NormalTransitionIssue>[],
  }) : issues = List.unmodifiable(issues);

  final TransitionUnifiedScopeEntryDecision decision;
  final TransitionUnifiedScopeBridgeFallbackReason? fallbackReason;
  final NormalTransitionDefinition? definition;
  final TransitionUnifiedScopeRequestFactoryResult? factoryResult;
  final TransitionUnifiedScopeEntryResult? entryResult;
  final TransitionUnifiedScopeBridgeSession? session;
  final List<NormalTransitionIssue> issues;

  bool get opensUnifiedScope =>
      decision == TransitionUnifiedScopeEntryDecision.unifiedScope &&
      entryResult?.opensUnifiedScope == true &&
      session != null;
}

class TransitionUnifiedScopeBridgeSession {
  TransitionUnifiedScopeBridgeSession({
    required this.id,
    required this.project,
    required this.definition,
    required this.graphBundle,
    required this.scope,
    required this.laneProjection,
    required this.trackId,
    required this.leftClipId,
    required this.rightClipId,
    required this.outgoingLayerId,
    required this.incomingLayerId,
    required this.outgoingElementId,
    required this.incomingElementId,
    required this.boundaryTime,
  });

  final String id;
  final MotionProjectModel project;
  final NormalTransitionDefinition definition;
  final NormalTransitionGraphAuthoringBundle graphBundle;
  final ScopeProjection scope;
  final TransitionScopeGraphLaneProjection laneProjection;
  final String trackId;
  final String leftClipId;
  final String rightClipId;
  final String outgoingLayerId;
  final String incomingLayerId;
  final String outgoingElementId;
  final String incomingElementId;
  final TimelineTime boundaryTime;

  String get presetId => graphBundle.presetId;
  String get transitionWindowId => graphBundle.transitionWindowId;
  TimelineTimeRange get globalWorkRange => scope.globalRange;
  TimelineTimeRange get localWorkRange => scope.localRange;
  TimelineTime get initialGlobalTime => scope.globalTime;
  TimelineTime get initialLocalTime => scope.localTime;
  List<TimelineAnimationLaneData> get lanes => laneProjection.lanes;
  List<TransitionScopeGraphLaneBinding> get laneBindings =>
      laneProjection.bindings;

  bool get hasEditableLanes =>
      lanes.isNotEmpty &&
      !laneProjection.hasIssues &&
      scope.mode == CompositionScopeMode.transition;

  TimelineTime globalToLocal(TimelineTime globalTime) {
    return scope.globalToLocal(globalTime);
  }

  TimelineTime localToGlobal(TimelineTime localTime) {
    return scope.localToGlobal(localTime);
  }

  TransitionScopeGraphLaneBinding? bindingForLane(String laneId) {
    return laneProjection.bindingForLane(laneId);
  }

  List<TimelineAnimationLaneData> lanesForRole(
    NormalTransitionGraphChannelRole role,
  ) {
    return laneProjection.lanesForRole(role);
  }
}

class TransitionUnifiedScopeBridgeEntryAdapter {
  TransitionUnifiedScopeBridgeEntryAdapter({
    this.config = const TransitionUnifiedScopeEntryConfig(),
    this.catalog = const NormalTransitionCatalog(),
    this.timelineAdapter = const NormalTransitionTimelineAdapter(),
    this.requestFactory = const TransitionUnifiedScopeRequestFactory(),
    TransitionUnifiedScopeEntryGate? entryGate,
  }) : entryGate = entryGate ?? TransitionUnifiedScopeEntryGate(config: config);

  final TransitionUnifiedScopeEntryConfig config;
  final NormalTransitionCatalog catalog;
  final NormalTransitionTimelineAdapter timelineAdapter;
  final TransitionUnifiedScopeRequestFactory requestFactory;
  final TransitionUnifiedScopeEntryGate entryGate;

  TransitionUnifiedScopeBridgeEntryResult resolveBridgeEntry(
    TransitionUnifiedScopeBridgeEntryRequest request,
  ) {
    if (!config.enableUnifiedTransitionScope) {
      return TransitionUnifiedScopeBridgeEntryResult(
        decision: TransitionUnifiedScopeEntryDecision.legacyTransitionScope,
        fallbackReason:
            TransitionUnifiedScopeBridgeFallbackReason.featureDisabled,
      );
    }

    final definitionId = timelineAdapter.definitionIdForPreset(request.preset);
    if (definitionId == null) {
      return TransitionUnifiedScopeBridgeEntryResult(
        decision: TransitionUnifiedScopeEntryDecision.legacyTransitionScope,
        fallbackReason:
            TransitionUnifiedScopeBridgeFallbackReason.unsupportedPreset,
        issues: <NormalTransitionIssue>[
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Timeline preset `${request.preset.name}` is not yet supported by Unified Transition Scope.',
            path: 'preset',
          ),
        ],
      );
    }

    final catalogResult = catalog.loadBuiltIns();
    if (!catalogResult.isValid) {
      return TransitionUnifiedScopeBridgeEntryResult(
        decision: TransitionUnifiedScopeEntryDecision.legacyTransitionScope,
        fallbackReason:
            TransitionUnifiedScopeBridgeFallbackReason.catalogBlocked,
        issues: catalogResult.issues,
      );
    }

    final definition = catalogResult.definitionById(definitionId);
    if (definition == null) {
      return TransitionUnifiedScopeBridgeEntryResult(
        decision: TransitionUnifiedScopeEntryDecision.legacyTransitionScope,
        fallbackReason:
            TransitionUnifiedScopeBridgeFallbackReason.unsupportedPreset,
        issues: <NormalTransitionIssue>[
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Normal transition definition `$definitionId` was not found.',
            path: 'definitionId',
          ),
        ],
      );
    }

    final factoryResult = requestFactory.createForBoundary(
      track: request.track,
      leftClip: request.leftClip,
      rightClip: request.rightClip,
      definition: definition,
      projectId: request.projectId,
      sceneId: request.sceneId,
      trackId: request.trackId,
      transition: request.transition,
      format: request.format,
      frameRate: request.frameRate,
    );
    final unifiedRequest = factoryResult.request;
    if (!factoryResult.canBuild || unifiedRequest == null) {
      return TransitionUnifiedScopeBridgeEntryResult(
        decision: TransitionUnifiedScopeEntryDecision.legacyTransitionScope,
        fallbackReason:
            TransitionUnifiedScopeBridgeFallbackReason.requestBlocked,
        definition: definition,
        factoryResult: factoryResult,
        issues: factoryResult.issues,
      );
    }

    final entryResult = entryGate.resolveEntry(unifiedRequest);
    if (!entryResult.opensUnifiedScope) {
      final issues = <NormalTransitionIssue>[...entryResult.graphIssues];
      final projectionIssue = _projectionIssueSummary(
        entryResult.projectionIssues,
      );
      if (projectionIssue != null) {
        issues.add(projectionIssue);
      }
      final laneIssue = _laneIssueSummary(entryResult.laneIssues);
      if (laneIssue != null) {
        issues.add(laneIssue);
      }
      return TransitionUnifiedScopeBridgeEntryResult(
        decision: TransitionUnifiedScopeEntryDecision.legacyTransitionScope,
        fallbackReason:
            TransitionUnifiedScopeBridgeFallbackReason.entryGateBlocked,
        definition: definition,
        factoryResult: factoryResult,
        entryResult: entryResult,
        issues: issues,
      );
    }

    return TransitionUnifiedScopeBridgeEntryResult(
      decision: TransitionUnifiedScopeEntryDecision.unifiedScope,
      definition: definition,
      factoryResult: factoryResult,
      entryResult: entryResult,
      session: _buildSession(
        request: request,
        definition: definition,
        factoryResult: factoryResult,
        entryResult: entryResult,
      ),
      issues: entryResult.graphIssues,
    );
  }

  TransitionUnifiedScopeBridgeSession _buildSession({
    required TransitionUnifiedScopeBridgeEntryRequest request,
    required NormalTransitionDefinition definition,
    required TransitionUnifiedScopeRequestFactoryResult factoryResult,
    required TransitionUnifiedScopeEntryResult entryResult,
  }) {
    final unifiedScope = entryResult.unifiedScope!;
    final project = factoryResult.project!;
    final scope = unifiedScope.scope!;
    final laneProjection = unifiedScope.lanes!;
    final graphBundle = unifiedScope.graph.bundle!;
    return TransitionUnifiedScopeBridgeSession(
      id: 'unified.transition.scope.${graphBundle.transitionWindowId}',
      project: project,
      definition: definition,
      graphBundle: graphBundle,
      scope: scope,
      laneProjection: laneProjection,
      trackId: request.trackId,
      leftClipId: request.leftClip.id,
      rightClipId: request.rightClip.id,
      outgoingLayerId: factoryResult.outgoingLayerId!,
      incomingLayerId: factoryResult.incomingLayerId!,
      outgoingElementId: factoryResult.outgoingElementId!,
      incomingElementId: factoryResult.incomingElementId!,
      boundaryTime: factoryResult.boundaryTime!,
    );
  }

  NormalTransitionIssue? _projectionIssueSummary(List<Object> issues) {
    if (issues.isEmpty) {
      return null;
    }
    return NormalTransitionIssue(
      severity: NormalTransitionIssueSeverity.error,
      message:
          'Transition scope projection failed with ${issues.length} issue(s).',
      path: 'projection',
    );
  }

  NormalTransitionIssue? _laneIssueSummary(List<Object> issues) {
    if (issues.isEmpty) {
      return null;
    }
    return NormalTransitionIssue(
      severity: NormalTransitionIssueSeverity.error,
      message:
          'Transition lane projection failed with ${issues.length} issue(s).',
      path: 'lanes',
    );
  }
}
