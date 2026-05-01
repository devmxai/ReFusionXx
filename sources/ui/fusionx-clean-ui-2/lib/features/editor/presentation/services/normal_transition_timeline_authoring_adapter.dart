import '../../domain/models/professional_normal_transition_models.dart';
import '../../domain/services/normal_transition_authoring_service.dart';
import '../../domain/services/normal_transition_catalog.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'normal_transition_timeline_adapter.dart';

class NormalTransitionTimelineAuthoringAdapter {
  const NormalTransitionTimelineAuthoringAdapter({
    this.catalog = const NormalTransitionCatalog(),
    this.authoringService = const NormalTransitionAuthoringService(),
    this.timelineAdapter = const NormalTransitionTimelineAdapter(),
  });

  final NormalTransitionCatalog catalog;
  final NormalTransitionAuthoringService authoringService;
  final NormalTransitionTimelineAdapter timelineAdapter;

  bool isNormalPreset(TimelineTransitionPreset preset) {
    return timelineAdapter.definitionIdForPreset(preset) != null;
  }

  NormalTransitionTimelineAuthoringResult createBuiltInPresetTransition({
    required TimelineTransitionPreset preset,
    required String trackId,
    required String leftClipId,
    required String rightClipId,
    required TimelineTime boundaryTime,
    required TimelineTime leftAvailableTail,
    required TimelineTime rightAvailableHead,
    NormalTransitionAlignment alignment = NormalTransitionAlignment.symmetric,
  }) {
    final definitionResult = _definitionForPreset(preset);
    final definition = definitionResult.definition;
    if (definition == null) {
      return NormalTransitionTimelineAuthoringResult(
        issues: definitionResult.issues,
      );
    }
    final applyResult = authoringService.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: definition,
        trackId: trackId,
        leftClipId: leftClipId,
        rightClipId: rightClipId,
        boundaryTime: boundaryTime,
        leftAvailableTail: leftAvailableTail,
        rightAvailableHead: rightAvailableHead,
        alignment: alignment,
      ),
    );
    if (!applyResult.canApply) {
      return NormalTransitionTimelineAuthoringResult(
        issues: applyResult.issues,
        window: applyResult.window,
      );
    }
    final transition = timelineAdapter.toTimelineTransition(
      node: applyResult.node!,
      instance: applyResult.instance!,
      window: applyResult.window,
    );
    if (transition == null) {
      return const NormalTransitionTimelineAuthoringResult(
        issues: <NormalTransitionIssue>[
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Authored transition could not be adapted to timeline state.',
            path: 'timelineAdapter',
          ),
        ],
      );
    }
    return NormalTransitionTimelineAuthoringResult(
      transition: transition,
      node: applyResult.node,
      instance: applyResult.instance,
      window: applyResult.window,
      issues: applyResult.issues,
    );
  }

  NormalTransitionTimelineAuthoringResult rehydrateTimelineTransition({
    required TimelineTrackTransitionData transition,
    required String trackId,
  }) {
    final definitionResult = _definitionForPreset(transition.preset);
    final definition = definitionResult.definition;
    if (definition == null) {
      return NormalTransitionTimelineAuthoringResult(
        issues: definitionResult.issues,
      );
    }
    final adapted = timelineAdapter.fromTimelineTransition(
      transition: transition,
      trackId: trackId,
      definition: definition,
    );
    if (!adapted.canAdapt) {
      return NormalTransitionTimelineAuthoringResult(
        issues: adapted.issues,
      );
    }
    return NormalTransitionTimelineAuthoringResult(
      transition: transition,
      node: adapted.node,
      instance: adapted.instance,
      issues: adapted.issues,
    );
  }

  _NormalTransitionDefinitionLookupResult _definitionForPreset(
    TimelineTransitionPreset preset,
  ) {
    final definitionId = timelineAdapter.definitionIdForPreset(preset);
    if (definitionId == null) {
      return _NormalTransitionDefinitionLookupResult(
        issues: <NormalTransitionIssue>[
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Timeline preset `${preset.name}` is not registered as a normal transition.',
            path: 'preset',
          ),
        ],
      );
    }
    final catalogResult = catalog.loadBuiltIns();
    if (!catalogResult.isValid) {
      return _NormalTransitionDefinitionLookupResult(
        issues: catalogResult.issues,
      );
    }
    final definition = catalogResult.definitionById(definitionId);
    if (definition == null) {
      return _NormalTransitionDefinitionLookupResult(
        issues: <NormalTransitionIssue>[
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Normal transition definition `$definitionId` was not found in the built-in catalog.',
            path: 'definitionId',
          ),
        ],
      );
    }
    return _NormalTransitionDefinitionLookupResult(
      definition: definition,
      issues: const <NormalTransitionIssue>[],
    );
  }
}

class NormalTransitionTimelineAuthoringResult {
  const NormalTransitionTimelineAuthoringResult({
    required this.issues,
    this.transition,
    this.node,
    this.instance,
    this.window,
  });

  final TimelineTrackTransitionData? transition;
  final NormalTransitionNode? node;
  final NormalTransitionInstance? instance;
  final NormalTransitionOverlapWindow? window;
  final List<NormalTransitionIssue> issues;

  bool get canApply =>
      transition != null &&
      node != null &&
      instance != null &&
      !issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );
}

class _NormalTransitionDefinitionLookupResult {
  const _NormalTransitionDefinitionLookupResult({
    required this.issues,
    this.definition,
  });

  final NormalTransitionDefinition? definition;
  final List<NormalTransitionIssue> issues;
}
