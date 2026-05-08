import 'package:flutter/foundation.dart';

import '../models/refusion_scene_program_models.dart';
import 'refusion_scene_program_authoring_service.dart';
import 'scene_visual_frame_qa_validator.dart';

@immutable
class ScenePreRenderSanityGateResult {
  ScenePreRenderSanityGateResult({
    required this.sceneId,
    required this.hctValid,
    required this.frameQaValid,
    required this.blocked,
    required this.fallbackReason,
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final String sceneId;
  final bool hctValid;
  final bool frameQaValid;
  final bool blocked;
  final String fallbackReason;
  final List<ReFusionSceneProgramIssue> issues;
}

class ScenePreRenderSanityGate {
  const ScenePreRenderSanityGate({
    SceneVisualFrameQaValidator? visualFrameQaValidator,
  }) : _visualFrameQaValidator = visualFrameQaValidator ??
            const SceneVisualFrameQaValidator(
              enforceOverflowAsError: true,
            );

  static const String _proofTag = 'TF_SCENE_PRE_RENDER_GATE_PROOF';

  final SceneVisualFrameQaValidator _visualFrameQaValidator;

  ScenePreRenderSanityGateResult validate({
    required ReFusionSceneProgramAuthoringResult authoringResult,
    required String sceneId,
  }) {
    final issues = <ReFusionSceneProgramIssue>[];
    final existingErrors = authoringResult.issues
        .where(
          (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
        )
        .toList(growable: false);
    issues.addAll(existingErrors);

    final program = authoringResult.program;
    if (program == null) {
      final fallbackReason =
          existingErrors.isNotEmpty ? 'authoring_errors' : 'missing_program';
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.info,
          message: '$_proofTag '
              'sceneId=$sceneId '
              'hctValid=false '
              'frameQaValid=false '
              'blocked=true '
              'issueCount=${issues.length} '
              'fallbackReason=$fallbackReason',
          path: 'scene.preRenderGate',
        ),
      );
      return ScenePreRenderSanityGateResult(
        sceneId: sceneId,
        hctValid: false,
        frameQaValid: false,
        blocked: true,
        fallbackReason: fallbackReason,
        issues: issues,
      );
    }

    final strictFrameQaResult = _visualFrameQaValidator.validate(program);
    final strictErrors = strictFrameQaResult.issues
        .where(
          (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
        )
        .toList(growable: false);
    issues.addAll(strictErrors);

    final hctValid = !strictErrors.any(
      (issue) => issue.message.contains('Runtime probe tree invalid'),
    );
    final frameQaValid = strictFrameQaResult.isValid;
    final blocked = issues.any(
      (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
    );
    final fallbackReason = blocked ? _fallbackReasonForIssues(issues) : 'none';

    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$_proofTag '
            'sceneId=$sceneId '
            'hctValid=${hctValid.toString()} '
            'frameQaValid=${frameQaValid.toString()} '
            'blocked=${blocked.toString()} '
            'issueCount=${issues.length} '
            'fallbackReason=$fallbackReason',
        path: 'scene.preRenderGate',
      ),
    );

    return ScenePreRenderSanityGateResult(
      sceneId: sceneId,
      hctValid: hctValid,
      frameQaValid: frameQaValid,
      blocked: blocked,
      fallbackReason: fallbackReason,
      issues: issues,
    );
  }

  String _fallbackReasonForIssues(List<ReFusionSceneProgramIssue> issues) {
    for (final issue in issues) {
      final message = issue.message.toLowerCase();
      if (message.contains('runtime probe tree invalid')) {
        return 'hct_invalid';
      }
      if (message.contains('overflow')) {
        return 'text_overflow';
      }
      if (message.contains('clipped')) {
        return 'clipped';
      }
      if (message.contains('safe area')) {
        return 'safe_area_violation';
      }
      if (message.contains('overlap')) {
        return 'overlap';
      }
      if (message.contains('desync')) {
        return 'parent_child_desync';
      }
      if (message.contains('unreadable')) {
        return 'unreadable_hold';
      }
    }
    return 'validation_failed';
  }
}
