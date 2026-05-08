import '../models/refusion_scene_program_models.dart';

const String kSceneRepairLoopProofTag = 'TF_SCENE_REPAIR_LOOP_PROOF';

class SceneSemanticRepairPayload {
  const SceneSemanticRepairPayload({
    required this.errorCode,
    required this.severity,
    this.componentId,
    this.elementId,
    this.frameMs,
    this.measuredProblem,
    this.suggestedAction,
    this.retrySafePayload = const <String, Object?>{},
  });

  final String errorCode;
  final ReFusionSceneProgramIssueSeverity severity;
  final String? componentId;
  final String? elementId;
  final int? frameMs;
  final String? measuredProblem;
  final String? suggestedAction;
  final Map<String, Object?> retrySafePayload;
}

class SceneSemanticRepairAttempt {
  const SceneSemanticRepairAttempt({
    required this.attempt,
    required this.payloads,
    required this.remainingErrors,
    required this.converged,
    required this.proofIssues,
  });

  final int attempt;
  final List<SceneSemanticRepairPayload> payloads;
  final int remainingErrors;
  final bool converged;
  final List<ReFusionSceneProgramIssue> proofIssues;
}

class SceneSemanticRepairLoopResult {
  const SceneSemanticRepairLoopResult({
    required this.attempts,
    required this.converged,
    required this.exhausted,
    required this.finalIssues,
  });

  final List<SceneSemanticRepairAttempt> attempts;
  final bool converged;
  final bool exhausted;
  final List<ReFusionSceneProgramIssue> finalIssues;
}

typedef SceneRepairIssueEvaluator =
    List<ReFusionSceneProgramIssue> Function(int attempt);

class SceneSemanticRepairLoopService {
  const SceneSemanticRepairLoopService();

  static const int maxAttempts = 3;

  List<SceneSemanticRepairPayload> buildPayloads(
    List<ReFusionSceneProgramIssue> issues,
  ) {
    final payloads = <SceneSemanticRepairPayload>[];
    for (final issue in issues) {
      if (issue.severity != ReFusionSceneProgramIssueSeverity.error &&
          issue.severity != ReFusionSceneProgramIssueSeverity.warning) {
        continue;
      }
      final code = _codeForIssue(issue);
      final parsed = _parseIssueContext(issue);
      payloads.add(
        SceneSemanticRepairPayload(
          errorCode: code,
          severity: issue.severity,
          componentId: parsed.componentId,
          elementId: parsed.elementId,
          frameMs: parsed.frameMs,
          measuredProblem: issue.message,
          suggestedAction: _suggestedActionForCode(code),
          retrySafePayload: <String, Object?>{
            'errorCode': code,
            if (parsed.componentId != null) 'componentId': parsed.componentId,
            if (parsed.elementId != null) 'elementId': parsed.elementId,
            if (parsed.frameMs != null) 'frameMs': parsed.frameMs,
          },
        ),
      );
    }
    return List<SceneSemanticRepairPayload>.unmodifiable(payloads);
  }

  SceneSemanticRepairLoopResult runLoop({
    required SceneRepairIssueEvaluator evaluateIssues,
    int maxAttemptsOverride = maxAttempts,
  }) {
    final attempts = <SceneSemanticRepairAttempt>[];
    List<ReFusionSceneProgramIssue> latestIssues = const <ReFusionSceneProgramIssue>[];

    for (var attempt = 1; attempt <= maxAttemptsOverride; attempt += 1) {
      latestIssues = List<ReFusionSceneProgramIssue>.unmodifiable(
        evaluateIssues(attempt),
      );
      final payloads = buildPayloads(latestIssues);
      final remainingErrors = latestIssues
          .where((issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error)
          .length;
      final converged = remainingErrors == 0;
      final proofIssues = _buildProofIssues(
        attempt: attempt,
        payloads: payloads,
        remainingErrors: remainingErrors,
        converged: converged,
      );
      attempts.add(
        SceneSemanticRepairAttempt(
          attempt: attempt,
          payloads: payloads,
          remainingErrors: remainingErrors,
          converged: converged,
          proofIssues: proofIssues,
        ),
      );
      if (converged) {
        return SceneSemanticRepairLoopResult(
          attempts: List<SceneSemanticRepairAttempt>.unmodifiable(attempts),
          converged: true,
          exhausted: false,
          finalIssues: latestIssues,
        );
      }
    }

    return SceneSemanticRepairLoopResult(
      attempts: List<SceneSemanticRepairAttempt>.unmodifiable(attempts),
      converged: false,
      exhausted: true,
      finalIssues: latestIssues,
    );
  }

  List<ReFusionSceneProgramIssue> _buildProofIssues({
    required int attempt,
    required List<SceneSemanticRepairPayload> payloads,
    required int remainingErrors,
    required bool converged,
  }) {
    if (payloads.isEmpty) {
      return <ReFusionSceneProgramIssue>[
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message: '$kSceneRepairLoopProofTag '
              'attempt=$attempt '
              'errorCode=none '
              'componentId=none '
              'elementId=none '
              'frameMs=-1 '
              'suggestedAction=none '
              'repairApplied=false '
              'remainingErrors=$remainingErrors '
              'converged=${converged.toString()} '
              'passed=${converged.toString()} '
              'failureReason=${converged ? 'none' : 'errors_remaining'}',
          path: r'$',
        ),
      ];
    }
    return payloads
        .map(
          (payload) => ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.info,
            message: '$kSceneRepairLoopProofTag '
                'attempt=$attempt '
                'errorCode=${payload.errorCode} '
                'componentId=${payload.componentId ?? 'none'} '
                'elementId=${payload.elementId ?? 'none'} '
                'frameMs=${payload.frameMs ?? -1} '
                'suggestedAction=${payload.suggestedAction ?? 'none'} '
                'repairApplied=false '
                'remainingErrors=$remainingErrors '
                'converged=${converged.toString()} '
                'passed=${converged.toString()} '
                'failureReason=${converged ? 'none' : 'errors_remaining'}',
            path: r'$',
          ),
        )
        .toList(growable: false);
  }

  String _codeForIssue(ReFusionSceneProgramIssue issue) {
    final message = _normalize(issue.message);
    final path = _normalize(issue.path ?? '');
    if (message.contains('boundedframeoverflowdetected')) {
      if (_looksLikeHeightOverflow(issue.message)) {
        return 'TEXT_OVERFLOW_HEIGHT';
      }
      return 'TEXT_OVERFLOW_RIGHT';
    }
    if (path.contains('parent') || path.contains('slot')) {
      return 'MISSING_PARENT_SLOT';
    }
    if (message.contains('floating') || message.contains('overlap')) {
      return 'CARD_CHILD_FLOATING';
    }
    if (message.contains('unsupportedicon')) {
      return 'UNSUPPORTED_ICON';
    }
    if (message.contains('unsupportedsemanticcomponent')) {
      return 'UNSUPPORTED_COMPONENT';
    }
    if (message.contains('unsupported') && message.contains('variant')) {
      return 'UNSUPPORTED_VARIANT';
    }
    if (message.contains('safearea') || message.contains('safeareaviolation')) {
      return 'SAFE_AREA_VIOLATION';
    }
    if (message.contains('duplicate') &&
        message.contains('property') &&
        message.contains('channel')) {
      return 'DUPLICATE_PROPERTY_CHANNEL';
    }
    if (message.contains('unreadablehold') || message.contains('readablehold')) {
      return 'UNREADABLE_HOLD';
    }
    if (message.contains('unfinished') && message.contains('motion')) {
      return 'UNFINISHED_BOUNDARY_MOTION';
    }
    if (message.contains('speedygraph') && message.contains('bypass')) {
      return 'SPEEDYGRAPH_BYPASS';
    }
    if (message.contains('tfscenedeterminismproof') &&
        message.contains('passedfalse')) {
      return 'NON_DETERMINISTIC_COMPILATION';
    }
    return 'UNSUPPORTED_COMPONENT';
  }

  bool _looksLikeHeightOverflow(String message) {
    final estimatedHeight = _readMetric(message, 'estimatedHeight=');
    final frameHeight = _readMetric(message, 'frameHeight=');
    if (estimatedHeight == null || frameHeight == null) {
      return false;
    }
    return estimatedHeight > frameHeight;
  }

  double? _readMetric(String message, String marker) {
    final index = message.indexOf(marker);
    if (index < 0) {
      return null;
    }
    final rest = message.substring(index + marker.length);
    final stop = rest.indexOf(' ');
    final token = (stop < 0 ? rest : rest.substring(0, stop)).trim();
    return double.tryParse(token);
  }

  _IssueContext _parseIssueContext(ReFusionSceneProgramIssue issue) {
    final frameMatch = RegExp(r'frameMs=(\d+)').firstMatch(issue.message);
    final componentMatch = RegExp(r'component(?:Id)?=([A-Za-z0-9_\-]+)')
        .firstMatch(issue.message);
    final elementMatch = RegExp(r'element(?:Id)?=([A-Za-z0-9_\-]+)')
        .firstMatch(issue.message);
    final textElementMatch =
        RegExp(r'Text element `([^`]+)`').firstMatch(issue.message);
    final componentFromPath = _extractComponentFromPath(issue.path);
    return _IssueContext(
      frameMs: frameMatch != null ? int.tryParse(frameMatch.group(1)!) : null,
      componentId: componentMatch?.group(1) ?? componentFromPath,
      elementId:
          elementMatch?.group(1) ?? textElementMatch?.group(1) ?? componentFromPath,
    );
  }

  String? _extractComponentFromPath(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final match =
        RegExp(r'components\.([A-Za-z0-9_\-]+)').firstMatch(path.trim());
    return match?.group(1);
  }

  String _suggestedActionForCode(String code) {
    switch (code) {
      case 'TEXT_OVERFLOW_RIGHT':
      case 'TEXT_OVERFLOW_HEIGHT':
        return 'Adjust textFrame and fitPolicy for bounded text.';
      case 'MISSING_PARENT_SLOT':
        return 'Attach child element to a valid parent slot contract.';
      case 'CARD_CHILD_FLOATING':
        return 'Route loose card content into a registered component hierarchy.';
      case 'UNSUPPORTED_ICON':
        return 'Use an icon id from the supported icon vocabulary.';
      case 'UNSUPPORTED_COMPONENT':
        return 'Replace with a component type from the registry.';
      case 'UNSUPPORTED_VARIANT':
        return 'Use a registered variant for this component.';
      case 'SAFE_AREA_VIOLATION':
        return 'Re-layout element within safe-area boundaries.';
      case 'DUPLICATE_PROPERTY_CHANNEL':
        return 'Merge duplicate target/property channels into one ownership path.';
      case 'UNREADABLE_HOLD':
        return 'Increase hold duration to readable timing policy.';
      case 'UNFINISHED_BOUNDARY_MOTION':
        return 'Close motion at scene boundary with a completed hold state.';
      case 'SPEEDYGRAPH_BYPASS':
        return 'Compile easing through MotionInterpolationTruthCompiler only.';
      case 'NON_DETERMINISTIC_COMPILATION':
        return 'Remove nondeterministic fields and recompile blueprint.';
      default:
        return 'Apply component-safe semantic blueprint corrections.';
    }
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _IssueContext {
  const _IssueContext({
    this.componentId,
    this.elementId,
    this.frameMs,
  });

  final String? componentId;
  final String? elementId;
  final int? frameMs;
}
