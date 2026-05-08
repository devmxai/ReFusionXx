import '../models/refusion_scene_program_models.dart';
import 'scene_semantic_repair_loop_service.dart';

const String kSceneVisualClosureLoopProofTag =
    'TF_SCENE_VISUAL_CLOSURE_LOOP_PROOF';

class SceneVisualClosureRepairAction {
  const SceneVisualClosureRepairAction({
    required this.errorCode,
    required this.suggestedAction,
    this.componentId,
    this.nodeId,
    this.slotId,
    this.frameTimeMs,
    this.measuredBounds,
    this.expectedBounds,
    this.rawMessage,
  });

  final String errorCode;
  final String suggestedAction;
  final String? componentId;
  final String? nodeId;
  final String? slotId;
  final int? frameTimeMs;
  final String? measuredBounds;
  final String? expectedBounds;
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
          componentId: payload.componentId,
          nodeId: _readField(message, 'nodeId='),
          slotId: _readField(message, 'slotId='),
          frameTimeMs: _readInt(message, 'timelineTimeMs=') ??
              _readInt(message, 'frameMs=') ??
              payload.frameMs,
          measuredBounds: _readField(message, 'worldBounds='),
          expectedBounds: _readField(message, 'slotBounds='),
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
    return originalCode;
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
