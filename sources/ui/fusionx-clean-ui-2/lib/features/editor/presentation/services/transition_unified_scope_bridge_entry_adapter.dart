import '../../domain/models/professional_motion_models.dart';
import '../../domain/models/professional_normal_transition_models.dart';
import '../../domain/services/normal_transition_catalog.dart';
import '../models/timeline_mock_models.dart';
import 'normal_transition_timeline_adapter.dart';
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
    List<NormalTransitionIssue> issues = const <NormalTransitionIssue>[],
  }) : issues = List.unmodifiable(issues);

  final TransitionUnifiedScopeEntryDecision decision;
  final TransitionUnifiedScopeBridgeFallbackReason? fallbackReason;
  final NormalTransitionDefinition? definition;
  final TransitionUnifiedScopeRequestFactoryResult? factoryResult;
  final TransitionUnifiedScopeEntryResult? entryResult;
  final List<NormalTransitionIssue> issues;

  bool get opensUnifiedScope =>
      decision == TransitionUnifiedScopeEntryDecision.unifiedScope &&
      entryResult?.opensUnifiedScope == true;
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
      issues: entryResult.graphIssues,
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
