import '../../domain/models/professional_normal_transition_models.dart';
import '../../domain/services/composition_timeline_projection.dart';
import '../services/transition_scope_graph_authoring_adapter.dart';
import '../services/transition_scope_graph_lane_adapter.dart';

typedef TransitionScopeGraphAuthoringDelegate
    = TransitionScopeGraphAuthoringResult Function(
  TransitionScopeGraphAuthoringRequest request,
);

enum TransitionUnifiedScopeEntryFallbackReason {
  graphApplyBlocked,
  projectionBlocked,
  laneProjectionBlocked,
}

class TransitionUnifiedScopeEntryResult {
  TransitionUnifiedScopeEntryResult._({
    this.blockReason,
    this.unifiedScope,
    List<NormalTransitionIssue> graphIssues = const <NormalTransitionIssue>[],
    List<CompositionProjectionIssue> projectionIssues =
        const <CompositionProjectionIssue>[],
    List<TransitionScopeGraphLaneIssue> laneIssues =
        const <TransitionScopeGraphLaneIssue>[],
  })  : graphIssues = List.unmodifiable(graphIssues),
        projectionIssues = List.unmodifiable(projectionIssues),
        laneIssues = List.unmodifiable(laneIssues);

  factory TransitionUnifiedScopeEntryResult.blocked({
    required TransitionUnifiedScopeEntryFallbackReason blockReason,
    TransitionScopeGraphAuthoringResult? unifiedScope,
    List<NormalTransitionIssue> graphIssues = const <NormalTransitionIssue>[],
    List<CompositionProjectionIssue> projectionIssues =
        const <CompositionProjectionIssue>[],
    List<TransitionScopeGraphLaneIssue> laneIssues =
        const <TransitionScopeGraphLaneIssue>[],
  }) {
    return TransitionUnifiedScopeEntryResult._(
      blockReason: blockReason,
      unifiedScope: unifiedScope,
      graphIssues: graphIssues,
      projectionIssues: projectionIssues,
      laneIssues: laneIssues,
    );
  }

  factory TransitionUnifiedScopeEntryResult.opened({
    required TransitionScopeGraphAuthoringResult unifiedScope,
    List<NormalTransitionIssue> graphIssues = const <NormalTransitionIssue>[],
    List<CompositionProjectionIssue> projectionIssues =
        const <CompositionProjectionIssue>[],
    List<TransitionScopeGraphLaneIssue> laneIssues =
        const <TransitionScopeGraphLaneIssue>[],
  }) {
    return TransitionUnifiedScopeEntryResult._(
      unifiedScope: unifiedScope,
      graphIssues: graphIssues,
      projectionIssues: projectionIssues,
      laneIssues: laneIssues,
    );
  }

  final TransitionUnifiedScopeEntryFallbackReason? blockReason;
  final TransitionScopeGraphAuthoringResult? unifiedScope;
  final List<NormalTransitionIssue> graphIssues;
  final List<CompositionProjectionIssue> projectionIssues;
  final List<TransitionScopeGraphLaneIssue> laneIssues;

  bool get opensUnifiedScope => blockReason == null && unifiedScope != null;
}

class TransitionUnifiedScopeEntryGate {
  TransitionUnifiedScopeEntryGate({
    TransitionScopeGraphAuthoringAdapter adapter =
        const TransitionScopeGraphAuthoringAdapter(),
    TransitionScopeGraphAuthoringDelegate? applyPresetToUnifiedScope,
  }) : _applyPresetToUnifiedScope =
            applyPresetToUnifiedScope ?? adapter.applyPresetToUnifiedScope;

  final TransitionScopeGraphAuthoringDelegate _applyPresetToUnifiedScope;

  TransitionUnifiedScopeEntryResult resolveEntry(
    TransitionScopeGraphAuthoringRequest request,
  ) {
    final result = _applyPresetToUnifiedScope(request);
    if (!result.graph.canApply) {
      return TransitionUnifiedScopeEntryResult.blocked(
        blockReason:
            TransitionUnifiedScopeEntryFallbackReason.graphApplyBlocked,
        unifiedScope: result,
        graphIssues: result.graph.issues,
      );
    }

    if (result.scope == null || result.projectionIssues.isNotEmpty) {
      return TransitionUnifiedScopeEntryResult.blocked(
        blockReason:
            TransitionUnifiedScopeEntryFallbackReason.projectionBlocked,
        unifiedScope: result,
        graphIssues: result.graph.issues,
        projectionIssues: result.projectionIssues,
      );
    }

    if (result.lanes == null || result.lanes!.hasIssues) {
      return TransitionUnifiedScopeEntryResult.blocked(
        blockReason:
            TransitionUnifiedScopeEntryFallbackReason.laneProjectionBlocked,
        unifiedScope: result,
        graphIssues: result.graph.issues,
        projectionIssues: result.projectionIssues,
        laneIssues:
            result.lanes?.issues ?? const <TransitionScopeGraphLaneIssue>[],
      );
    }

    return TransitionUnifiedScopeEntryResult.opened(
      unifiedScope: result,
      graphIssues: result.graph.issues,
      projectionIssues: result.projectionIssues,
      laneIssues: result.lanes!.issues,
    );
  }
}
