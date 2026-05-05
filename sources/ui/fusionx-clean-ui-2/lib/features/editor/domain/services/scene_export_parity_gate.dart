import 'package:flutter/foundation.dart';

import '../models/export_composition_models.dart';

enum SceneExportParityIssueSeverity {
  warning,
  blocker,
}

enum SceneExportParityIssueCode {
  unresolvedCompositionErrors,
  sceneOnlyCanvasRendererMissing,
  missingMotionTextProgram,
  missingAuthoredVisualSurfaceProgram,
  nonTextAuthoredVisualRendererMissing,
  unsupportedMotionCamera,
  unsupportedMotionEffect,
  unsupportedMotionTransition,
  unsupportedInterpolationKind,
}

@immutable
class SceneExportParityIssue {
  const SceneExportParityIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.detail,
  });

  final SceneExportParityIssueCode code;
  final SceneExportParityIssueSeverity severity;
  final String message;
  final String? detail;

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'code': code.name,
        'severity': severity.name,
        'message': message,
        'detail': detail,
      };
}

@immutable
class SceneExportParityResult {
  SceneExportParityResult({
    required this.hasSceneMotion,
    required this.hasBaselineVisualTrack,
    required this.motionElementCount,
    required this.motionTextElementCount,
    required this.motionNonTextElementCount,
    required this.motionChannelCount,
    required this.motionTextProgramNodeCount,
    required this.authoredVisualSurfaceNodeCount,
    required Set<String> authoredVisualSurfaceKinds,
    required List<SceneExportParityIssue> issues,
  })  : authoredVisualSurfaceKinds =
            Set<String>.unmodifiable(authoredVisualSurfaceKinds),
        issues = List.unmodifiable(issues);

  final bool hasSceneMotion;
  final bool hasBaselineVisualTrack;
  final int motionElementCount;
  final int motionTextElementCount;
  final int motionNonTextElementCount;
  final int motionChannelCount;
  final int motionTextProgramNodeCount;
  final int authoredVisualSurfaceNodeCount;
  final Set<String> authoredVisualSurfaceKinds;
  final List<SceneExportParityIssue> issues;

  bool get hasBlockers => issues.any(
        (issue) => issue.severity == SceneExportParityIssueSeverity.blocker,
      );

  bool get isProductionExportReady => hasSceneMotion && !hasBlockers;

  List<SceneExportParityIssueCode> get blockerCodes => issues
      .where(
        (issue) => issue.severity == SceneExportParityIssueSeverity.blocker,
      )
      .map((issue) => issue.code)
      .toList(growable: false);

  Map<String, Object?> toBridgeMap() => <String, Object?>{
        'hasSceneMotion': hasSceneMotion,
        'hasBaselineVisualTrack': hasBaselineVisualTrack,
        'motionElementCount': motionElementCount,
        'motionTextElementCount': motionTextElementCount,
        'motionNonTextElementCount': motionNonTextElementCount,
        'motionChannelCount': motionChannelCount,
        'motionTextProgramNodeCount': motionTextProgramNodeCount,
        'authoredVisualSurfaceNodeCount': authoredVisualSurfaceNodeCount,
        'authoredVisualSurfaceKinds':
            authoredVisualSurfaceKinds.toList(growable: false),
        'hasBlockers': hasBlockers,
        'isProductionExportReady': isProductionExportReady,
        'blockerCodes': blockerCodes.map((code) => code.name).toList(),
        'issues': issues.map((issue) => issue.toBridgeMap()).toList(),
      };
}

class SceneExportParityGate {
  const SceneExportParityGate();

  SceneExportParityResult evaluate(ExportComposition composition) {
    final issues = <SceneExportParityIssue>[];
    final hasSceneMotion = composition.motionElementCount > 0 ||
        composition.motionChannelCount > 0 ||
        composition.motionEffectCount > 0 ||
        composition.motionTransitionCount > 0 ||
        composition.motionCameraCount > 0;
    final hasBaselineVisualTrack = composition.nonEmptyVisualTrackCount > 0;
    final motionTextProgramNodeCount =
        composition.motionTextProgram?.nodes.length ?? 0;
    final authoredVisualSurfaceNodeCount =
        composition.authoredVisualSurfaceProgram?.nodes.length ?? 0;
    final hasUnsupportedCompositorWindows =
        composition.visualCompositorGraph.unsupportedCompositorWindowCount > 0;
    final authoredVisualSurfaceKinds = <String>{
      for (final node
          in composition.authoredVisualSurfaceProgram?.nodes ?? const [])
        if (node.elementKind.isNotEmpty) node.elementKind,
    };

    if (composition.hasErrors) {
      issues.add(
        const SceneExportParityIssue(
          code: SceneExportParityIssueCode.unresolvedCompositionErrors,
          severity: SceneExportParityIssueSeverity.blocker,
          message:
              'Export composition contains unresolved errors and cannot be parity-checked safely.',
        ),
      );
    }

    if (hasSceneMotion && !hasBaselineVisualTrack) {
      issues.add(
        const SceneExportParityIssue(
          code: SceneExportParityIssueCode.sceneOnlyCanvasRendererMissing,
          severity: SceneExportParityIssueSeverity.blocker,
          message:
              'Generated scene content is present without a media baseline track; native scene-only canvas export is not complete yet.',
        ),
      );
    }

    if (composition.motionTextElementCount > 0 &&
        motionTextProgramNodeCount == 0) {
      issues.add(
        const SceneExportParityIssue(
          code: SceneExportParityIssueCode.missingMotionTextProgram,
          severity: SceneExportParityIssueSeverity.blocker,
          message:
              'Text motion exists but the deterministic motion-text export program is missing.',
        ),
      );
    }

    if (composition.motionNonTextElementCount > 0) {
      if (authoredVisualSurfaceNodeCount == 0) {
        issues.add(
          SceneExportParityIssue(
            code:
                SceneExportParityIssueCode.missingAuthoredVisualSurfaceProgram,
            severity: SceneExportParityIssueSeverity.blocker,
            message:
                '${_formatAuthoredVisualSurfaceKinds(authoredVisualSurfaceKinds)} motion exists but the authored visual surface export program is missing.',
          ),
        );
      } else if (hasUnsupportedCompositorWindows) {
        issues.add(
          SceneExportParityIssue(
            code:
                SceneExportParityIssueCode.nonTextAuthoredVisualRendererMissing,
            severity: SceneExportParityIssueSeverity.blocker,
            message:
                '${_formatAuthoredVisualSurfaceKinds(authoredVisualSurfaceKinds)} motion is represented in the authored visual surface program, but the production native export renderer is not complete yet.',
            detail:
                'authoredVisualSurfaceNodeCount=$authoredVisualSurfaceNodeCount; authoredVisualSurfaceKinds=${authoredVisualSurfaceKinds.join(',')}',
          ),
        );
      }
    }

    if (composition.motionCameraCount > 0) {
      issues.add(
        const SceneExportParityIssue(
          code: SceneExportParityIssueCode.unsupportedMotionCamera,
          severity: SceneExportParityIssueSeverity.blocker,
          message:
              'Motion camera bindings are not supported by the current export parity gate.',
        ),
      );
    }
    if (composition.motionEffectCount > 0 && hasUnsupportedCompositorWindows) {
      issues.add(
        const SceneExportParityIssue(
          code: SceneExportParityIssueCode.unsupportedMotionEffect,
          severity: SceneExportParityIssueSeverity.blocker,
          message:
              'Motion effect instances are not supported by the current export parity gate.',
        ),
      );
    }
    if (composition.motionTransitionCount > 0 &&
        hasUnsupportedCompositorWindows) {
      issues.add(
        const SceneExportParityIssue(
          code: SceneExportParityIssueCode.unsupportedMotionTransition,
          severity: SceneExportParityIssueSeverity.blocker,
          message:
              'Motion transition instances are not supported by the current export parity gate.',
        ),
      );
    }
    if (composition.hasUnsupportedInterpolationKinds) {
      issues.add(
        SceneExportParityIssue(
          code: SceneExportParityIssueCode.unsupportedInterpolationKind,
          severity: SceneExportParityIssueSeverity.blocker,
          message:
              'Unsupported interpolation kinds are present and must block export instead of degrading silently.',
          detail: composition.unsupportedInterpolationKinds.join(', '),
        ),
      );
    }

    return SceneExportParityResult(
      hasSceneMotion: hasSceneMotion,
      hasBaselineVisualTrack: hasBaselineVisualTrack,
      motionElementCount: composition.motionElementCount,
      motionTextElementCount: composition.motionTextElementCount,
      motionNonTextElementCount: composition.motionNonTextElementCount,
      motionChannelCount: composition.motionChannelCount,
      motionTextProgramNodeCount: motionTextProgramNodeCount,
      authoredVisualSurfaceNodeCount: authoredVisualSurfaceNodeCount,
      authoredVisualSurfaceKinds: authoredVisualSurfaceKinds,
      issues: List<SceneExportParityIssue>.unmodifiable(issues),
    );
  }
}

String _formatAuthoredVisualSurfaceKinds(Set<String> kinds) {
  if (kinds.isEmpty) {
    return 'Non-text authored visual';
  }
  final labels = <String>[];
  if (kinds.contains('videoClip')) {
    labels.add('video');
  }
  if (kinds.contains('image')) {
    labels.add('image');
  }
  if (kinds.contains('shape')) {
    labels.add('shape');
  }
  if (kinds.contains('mask')) {
    labels.add('mask');
  }
  final unknownLabels = kinds
      .where((kind) =>
          kind != 'videoClip' &&
          kind != 'image' &&
          kind != 'shape' &&
          kind != 'mask')
      .toList()
    ..sort();
  labels.addAll(unknownLabels);
  if (labels.isEmpty) {
    return 'Non-text authored visual';
  }
  return '${labels.join('/')} authored visual';
}
