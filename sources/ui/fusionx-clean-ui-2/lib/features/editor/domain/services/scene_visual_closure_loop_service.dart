import '../models/refusion_scene_program_models.dart';
import 'scene_semantic_repair_loop_service.dart';

const String kSceneVisualClosureLoopProofTag =
    'TF_SCENE_VISUAL_CLOSURE_LOOP_PROOF';

class SceneVisualClosureRepairAction {
  const SceneVisualClosureRepairAction({
    required this.errorCode,
    required this.suggestedAction,
    required this.suggestedFixPath,
    this.suggestedFixValue,
    this.componentId,
    this.nodeId,
    this.slotId,
    this.frameTimeMs,
    this.measuredBounds,
    this.expectedBounds,
    this.visualDescription,
    this.motionAlternatives = const <String>[],
    this.rawMessage,
  });

  final String errorCode;
  final String suggestedAction;
  final String suggestedFixPath;
  final Object? suggestedFixValue;
  final String? componentId;
  final String? nodeId;
  final String? slotId;
  final int? frameTimeMs;
  final String? measuredBounds;
  final String? expectedBounds;
  final String? visualDescription;
  final List<String> motionAlternatives;
  final String? rawMessage;
}

class SceneVisualClosureAttempt {
  const SceneVisualClosureAttempt({
    required this.attempt,
    required this.issueCountBefore,
    required this.issueCountAfter,
    required this.repairActions,
    required this.approved,
    required this.escalated,
    required this.proofIssues,
    required this.issuesAfter,
  });

  final int attempt;
  final int issueCountBefore;
  final int issueCountAfter;
  final List<SceneVisualClosureRepairAction> repairActions;
  final bool approved;
  final bool escalated;
  final List<ReFusionSceneProgramIssue> proofIssues;
  final List<ReFusionSceneProgramIssue> issuesAfter;
}

class SceneVisualClosureLoopResult {
  const SceneVisualClosureLoopResult({
    required this.attempts,
    required this.approved,
    required this.escalated,
    required this.finalIssues,
  });

  final List<SceneVisualClosureAttempt> attempts;
  final bool approved;
  final bool escalated;
  final List<ReFusionSceneProgramIssue> finalIssues;
}

typedef SceneVisualClosureIssueEvaluator = List<ReFusionSceneProgramIssue>
    Function(
  int attempt,
  List<SceneVisualClosureRepairAction> repairActions,
  List<ReFusionSceneProgramIssue> currentIssues,
);

class SceneVisualClosureLoopService {
  const SceneVisualClosureLoopService({
    SceneSemanticRepairLoopService? semanticRepairLoopService,
  }) : _semanticRepairLoopService =
            semanticRepairLoopService ?? const SceneSemanticRepairLoopService();

  static const int maxAttempts = 3;

  final SceneSemanticRepairLoopService _semanticRepairLoopService;

  List<SceneVisualClosureRepairAction> buildRepairActions(
    List<ReFusionSceneProgramIssue> issues,
  ) {
    final payloads = _semanticRepairLoopService.buildPayloads(issues);
    final actions = <SceneVisualClosureRepairAction>[];
    for (var index = 0; index < payloads.length; index += 1) {
      final payload = payloads[index];
      final sourceIssue = index < issues.length ? issues[index] : null;
      final message = sourceIssue?.message ?? payload.measuredProblem ?? '';
      final resolvedErrorCode = _overrideErrorCodeFromMessage(
        originalCode: payload.errorCode,
        message: message,
      );
      actions.add(
        SceneVisualClosureRepairAction(
          errorCode: resolvedErrorCode,
          suggestedAction: _deterministicAction(resolvedErrorCode),
          suggestedFixPath: _suggestedFixPath(
            errorCode: resolvedErrorCode,
            componentId: payload.componentId,
            slotId: _readField(message, 'slotId='),
          ),
          suggestedFixValue: _suggestedFixValue(resolvedErrorCode),
          componentId: payload.componentId,
          nodeId: _readField(message, 'nodeId='),
          slotId: _readField(message, 'slotId='),
          frameTimeMs: _readInt(message, 'timelineTimeMs=') ??
              _readInt(message, 'frameMs=') ??
              payload.frameMs,
          measuredBounds: _readField(message, 'worldBounds='),
          expectedBounds: _readField(message, 'slotBounds='),
          visualDescription: _visualDescription(
            errorCode: resolvedErrorCode,
            message: sourceIssue?.message ?? payload.measuredProblem ?? '',
          ),
          motionAlternatives: _suggestedMotionAlternatives(resolvedErrorCode),
          rawMessage: sourceIssue?.message ?? payload.measuredProblem,
        ),
      );
    }
    return List<SceneVisualClosureRepairAction>.unmodifiable(actions);
  }

  SceneVisualClosureLoopResult runLoop({
    required List<ReFusionSceneProgramIssue> initialIssues,
    required SceneVisualClosureIssueEvaluator evaluateIssues,
    int maxAttemptsOverride = maxAttempts,
  }) {
    var currentIssues =
        List<ReFusionSceneProgramIssue>.unmodifiable(initialIssues);
    final attempts = <SceneVisualClosureAttempt>[];
    for (var attempt = 1; attempt <= maxAttemptsOverride; attempt += 1) {
      final issueCountBefore = _countBlockingIssues(currentIssues);
      final repairActions = buildRepairActions(currentIssues);
      final nextIssues = List<ReFusionSceneProgramIssue>.unmodifiable(
        evaluateIssues(attempt, repairActions, currentIssues),
      );
      final issueCountAfter = _countBlockingIssues(nextIssues);
      final approved = issueCountAfter == 0;
      final escalated = !approved && attempt == maxAttemptsOverride;
      final proofIssues = _buildProofIssues(
        attempt: attempt,
        issueCountBefore: issueCountBefore,
        issueCountAfter: issueCountAfter,
        repairActions: repairActions,
        approved: approved,
        escalated: escalated,
      );
      attempts.add(
        SceneVisualClosureAttempt(
          attempt: attempt,
          issueCountBefore: issueCountBefore,
          issueCountAfter: issueCountAfter,
          repairActions: repairActions,
          approved: approved,
          escalated: escalated,
          proofIssues: proofIssues,
          issuesAfter: nextIssues,
        ),
      );
      if (approved) {
        return SceneVisualClosureLoopResult(
          attempts: List<SceneVisualClosureAttempt>.unmodifiable(attempts),
          approved: true,
          escalated: false,
          finalIssues: nextIssues,
        );
      }
      currentIssues = nextIssues;
    }

    return SceneVisualClosureLoopResult(
      attempts: List<SceneVisualClosureAttempt>.unmodifiable(attempts),
      approved: false,
      escalated: true,
      finalIssues: currentIssues,
    );
  }

  List<ReFusionSceneProgramIssue> _buildProofIssues({
    required int attempt,
    required int issueCountBefore,
    required int issueCountAfter,
    required List<SceneVisualClosureRepairAction> repairActions,
    required bool approved,
    required bool escalated,
  }) {
    final actions = repairActions.isEmpty
        ? 'none'
        : repairActions.map((action) => action.suggestedAction).join('|');
    return <ReFusionSceneProgramIssue>[
      ReFusionSceneProgramIssue(
        severity: approved
            ? ReFusionSceneProgramIssueSeverity.info
            : ReFusionSceneProgramIssueSeverity.warning,
        message: '$kSceneVisualClosureLoopProofTag '
            'attempt=$attempt '
            'issueCountBefore=$issueCountBefore '
            'issueCountAfter=$issueCountAfter '
            'repairActions=$actions '
            'approved=${approved.toString()} '
            'escalated=${escalated.toString()}',
        path: r'$',
      ),
    ];
  }

  String _deterministicAction(String errorCode) {
    switch (errorCode) {
      case 'TEXT_OVERFLOW_RIGHT':
      case 'TEXT_OVERFLOW_HEIGHT':
        return 'enable_shrink_to_fit';
      case 'SAFE_AREA_VIOLATION':
        return 'reposition_within_safe_area';
      case 'CARD_CHILD_FLOATING':
      case 'MISSING_PARENT_SLOT':
        return 'rebind_to_component_slot';
      case 'UNREADABLE_HOLD':
        return 'increase_hold_duration';
      case 'DUPLICATE_PROPERTY_CHANNEL':
        return 'merge_duplicate_channels';
      case 'BAD_PHRASE_CUT':
        return 'rewrite_or_shorten_text_phrase';
      case 'ICON_OPTICAL_CENTER_OFF':
        return 'apply_optical_icon_alignment';
      case 'MISSING_BRAND_ASSET':
        return 'replace_with_registry_or_semantic_brand_icon';
      case 'MOTION_VARIETY_LOW':
        return 'replace_repetitive_motion_recipes';
      case 'WEAK_COMPONENT_CHOREOGRAPHY':
        return 'enforce_component_choreography_tokens';
      case 'DENSITY_LAYOUT_IMBALANCE':
        return 'reflow_scene_with_composition_solver';
      case 'UNSAFE_SIMULTANEOUS_MOTION':
        return 'reduce_parallel_motion_density';
      case 'SPEEDYGRAPH_BYPASS':
        return 'compile_speedygraph_via_truth_compiler';
      case 'NON_DETERMINISTIC_COMPILATION':
        return 'normalize_nondeterministic_fields';
      default:
        return 'apply_component_safe_correction';
    }
  }

  String _overrideErrorCodeFromMessage({
    required String originalCode,
    required String message,
  }) {
    final normalized =
        message.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (normalized.contains('textoverflowtrue') ||
        normalized.contains('boundedframeoverflowdetected')) {
      return 'TEXT_OVERFLOW_RIGHT';
    }
    if (normalized.contains('parentchilddesynctrue')) {
      return 'MISSING_PARENT_SLOT';
    }
    if (normalized.contains('safeareaviolationtrue')) {
      return 'SAFE_AREA_VIOLATION';
    }
    if (normalized.contains('phrasecut') ||
        normalized.contains('endswithand') ||
        normalized.contains('midphrase')) {
      return 'BAD_PHRASE_CUT';
    }
    if (normalized.contains('opticalcenter') ||
        normalized.contains('deltax') && normalized.contains('icon')) {
      return 'ICON_OPTICAL_CENTER_OFF';
    }
    if (normalized.contains('brandasset') &&
        (normalized.contains('missing') ||
            normalized.contains('unsupported'))) {
      return 'MISSING_BRAND_ASSET';
    }
    if (normalized.contains('motionvariety') ||
        normalized.contains('repetitivemotion')) {
      return 'MOTION_VARIETY_LOW';
    }
    if (normalized.contains('choreography') &&
        (normalized.contains('weak') || normalized.contains('missing'))) {
      return 'WEAK_COMPONENT_CHOREOGRAPHY';
    }
    if (normalized.contains('density') ||
        normalized.contains('negative') && normalized.contains('space') ||
        normalized.contains('layoutimbalance')) {
      return 'DENSITY_LAYOUT_IMBALANCE';
    }
    if (normalized.contains('simultaneousmotion') ||
        normalized.contains('parallelmotion')) {
      return 'UNSAFE_SIMULTANEOUS_MOTION';
    }
    return originalCode;
  }

  String _suggestedFixPath({
    required String errorCode,
    required String? componentId,
    required String? slotId,
  }) {
    final componentPath =
        componentId == null ? 'components' : 'components.$componentId';
    switch (errorCode) {
      case 'TEXT_OVERFLOW_RIGHT':
      case 'TEXT_OVERFLOW_HEIGHT':
      case 'BAD_PHRASE_CUT':
        final slotPath = slotId == null ? 'slots' : 'slots.$slotId';
        return '$componentPath.$slotPath.textFrame.fitPolicy';
      case 'SAFE_AREA_VIOLATION':
      case 'DENSITY_LAYOUT_IMBALANCE':
        return '$componentPath.compositionIntent';
      case 'ICON_OPTICAL_CENTER_OFF':
        return '$componentPath.componentChoreography.opticalAlignment';
      case 'MISSING_BRAND_ASSET':
        return '$componentPath.brandToken';
      case 'MOTION_VARIETY_LOW':
      case 'UNSAFE_SIMULTANEOUS_MOTION':
        return '$componentPath.motionRecipe';
      case 'WEAK_COMPONENT_CHOREOGRAPHY':
        return '$componentPath.componentChoreography.enterRecipe';
      default:
        return componentPath;
    }
  }

  Object? _suggestedFixValue(String errorCode) {
    switch (errorCode) {
      case 'TEXT_OVERFLOW_RIGHT':
      case 'TEXT_OVERFLOW_HEIGHT':
        return r'$textFit.wrapToLines';
      case 'BAD_PHRASE_CUT':
        return r'$textFit.shorten';
      case 'SAFE_AREA_VIOLATION':
      case 'DENSITY_LAYOUT_IMBALANCE':
        return r'$composition.featureGrid';
      case 'ICON_OPTICAL_CENTER_OFF':
        return 'auto';
      case 'MISSING_BRAND_ASSET':
        return r'$brand.generic';
      case 'MOTION_VARIETY_LOW':
        return r'$motion.cardSpringEntrance';
      case 'WEAK_COMPONENT_CHOREOGRAPHY':
        return r'$motion.scaleIn';
      case 'UNSAFE_SIMULTANEOUS_MOTION':
        return r'$motion.softFadeUp';
      default:
        return null;
    }
  }

  String? _visualDescription({
    required String errorCode,
    required String message,
  }) {
    final summary = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    switch (errorCode) {
      case 'TEXT_OVERFLOW_RIGHT':
      case 'TEXT_OVERFLOW_HEIGHT':
        return 'Text exceeds bounded frame and needs deterministic fit policy.';
      case 'BAD_PHRASE_CUT':
        return 'Body copy is cut mid-phrase and harms readability.';
      case 'ICON_OPTICAL_CENTER_OFF':
        return 'Icon appears optically off-center inside its slot.';
      case 'MISSING_BRAND_ASSET':
        return 'Brand icon is missing from registry-backed asset pipeline.';
      case 'MOTION_VARIETY_LOW':
        return 'Sibling elements rely on repetitive motion patterns.';
      case 'WEAK_COMPONENT_CHOREOGRAPHY':
        return 'Component enter/exit choreography is missing tokenized hooks.';
      case 'DENSITY_LAYOUT_IMBALANCE':
        return 'Layout density exceeds professional composition balance.';
      case 'UNSAFE_SIMULTANEOUS_MOTION':
        return 'Too many concurrent motions reduce readability.';
      default:
        return summary.isEmpty ? null : summary;
    }
  }

  List<String> _suggestedMotionAlternatives(String errorCode) {
    if (errorCode != 'MOTION_VARIETY_LOW') {
      return const <String>[];
    }
    return const <String>[
      r'$motion.slideInFromLeft',
      r'$motion.slideInFromRight',
      r'$motion.scaleInBounce',
      r'$motion.rotateIn',
    ];
  }

  int _countBlockingIssues(List<ReFusionSceneProgramIssue> issues) {
    return issues
        .where((issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error)
        .length;
  }

  String? _readField(String message, String marker) {
    final escaped = RegExp.escape(marker);
    final match = RegExp('$escaped([^ ]+)').firstMatch(message);
    return match?.group(1);
  }

  int? _readInt(String message, String marker) {
    final value = _readField(message, marker);
    return value == null ? null : int.tryParse(value);
  }
}
