import '../models/refusion_scene_program_models.dart';
import 'scene_icon_alignment_engine.dart';
import 'scene_optical_bounds.dart';

const String kSceneIconAlignmentProofTag = 'TF_SCENE_ICON_ALIGNMENT_PROOF';

class SceneIconAlignmentValidationResult {
  SceneIconAlignmentValidationResult({
    required List<ReFusionSceneProgramIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneIconAlignmentValidator {
  const SceneIconAlignmentValidator({
    this.maxCenterDeltaPx = 3.0,
    this.maxCenterDeltaRatio = 0.05,
    SceneIconAlignmentEngine alignmentEngine = const SceneIconAlignmentEngine(),
  }) : _alignmentEngine = alignmentEngine;

  final double maxCenterDeltaPx;
  final double maxCenterDeltaRatio;
  final SceneIconAlignmentEngine _alignmentEngine;

  SceneIconAlignmentValidationResult validate(ReFusionSceneProgram program) {
    final issues = <ReFusionSceneProgramIssue>[];
    var evaluated = 0;
    var errors = 0;
    for (final layer in program.layers) {
      final elementsById = <String, ReFusionSceneProgramElement>{
        for (final element in layer.elements) element.id: element,
      };
      for (final element in layer.elements) {
        if (!SceneOpticalBounds.looksLikeAlignableIcon(element)) {
          continue;
        }
        final rawParentId = element.properties['parentId'];
        if (rawParentId is! String || rawParentId.trim().isEmpty) {
          continue;
        }
        final parentId = rawParentId.trim();
        final parent = elementsById[parentId] ??
            _findParentAcrossLayers(program: program, parentId: parentId);
        if (parent == null) {
          continue;
        }
        final parentRect = SceneOpticalBounds.rectFor(parent);
        final iconRect = SceneOpticalBounds.rectFor(element);
        if (parentRect == null || iconRect == null) {
          continue;
        }
        final profile = SceneOpticalBounds.profileFor(element);
        final measurement = _alignmentEngine.measure(
          parentRect: parentRect,
          iconRect: iconRect,
          profile: profile,
        );
        final allowedDelta = _maxAllowedCenterDelta(parentRect.minDimension);
        final centerAligned = measurement.centerDeltaDistance <= allowedDelta;
        final safeZoneSatisfied = measurement.safeZoneSatisfied;
        final passed = centerAligned && safeZoneSatisfied;
        evaluated += 1;
        if (!passed) {
          errors += 1;
        }

        final fallbackReason =
            passed ? 'none' : (!centerAligned ? 'center_delta' : 'safe_zone');
        final severity = passed
            ? ReFusionSceneProgramIssueSeverity.info
            : ReFusionSceneProgramIssueSeverity.error;
        issues.add(
          ReFusionSceneProgramIssue(
            severity: severity,
            message: '$kSceneIconAlignmentProofTag '
                'sceneId=${program.name} '
                'layerId=${layer.id} '
                'targetId=${element.id} '
                'parentId=$parentId '
                'profileId=${profile.id} '
                'centerDeltaPx=${measurement.centerDeltaDistance.toStringAsFixed(2)} '
                'allowedDeltaPx=${allowedDelta.toStringAsFixed(2)} '
                'safeZoneSatisfied=${safeZoneSatisfied.toString()} '
                'safeZoneMinX=${measurement.requiredSafeMarginX.toStringAsFixed(2)} '
                'safeZoneMinY=${measurement.requiredSafeMarginY.toStringAsFixed(2)} '
                'actualMinMarginX=${measurement.minMarginX.toStringAsFixed(2)} '
                'actualMinMarginY=${measurement.minMarginY.toStringAsFixed(2)} '
                'fallbackReason=$fallbackReason',
            path: 'layers.${layer.id}.elements.${element.id}',
          ),
        );
      }
    }

    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneIconAlignmentProofTag '
            'sceneId=${program.name} '
            'evaluated=$evaluated '
            'errors=$errors '
            'status=${errors == 0 ? 'pass' : 'fail'}',
        path: r'$',
      ),
    );

    return SceneIconAlignmentValidationResult(issues: issues);
  }

  double _maxAllowedCenterDelta(double parentMinDimension) {
    final ratioAllowance = parentMinDimension * maxCenterDeltaRatio;
    return ratioAllowance > maxCenterDeltaPx
        ? ratioAllowance
        : maxCenterDeltaPx;
  }

  ReFusionSceneProgramElement? _findParentAcrossLayers({
    required ReFusionSceneProgram program,
    required String parentId,
  }) {
    for (final layer in program.layers) {
      for (final element in layer.elements) {
        if (element.id == parentId) {
          return element;
        }
      }
    }
    return null;
  }
}
