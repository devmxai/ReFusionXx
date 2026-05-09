import '../models/refusion_motion_director_models.dart';
import 'scene_group_choreography_solver.dart';

const String kSceneInterComponentChoreographyProofTag =
    'TF_SCENE_INTER_COMPONENT_CHOREOGRAPHY_PROOF';

class SceneInterComponentChoreographyResult {
  const SceneInterComponentChoreographyResult({
    required this.components,
    required this.primitives,
    required this.issues,
  });

  final List<ReFusionMotionDirectorComponent> components;
  final List<ReFusionMotionDirectorPrimitive> primitives;
  final List<ReFusionMotionDirectorIssue> issues;
}

class SceneInterComponentChoreographySolver {
  const SceneInterComponentChoreographySolver({
    SceneGroupChoreographySolver groupSolver =
        const SceneGroupChoreographySolver(),
    this.maxHighEnergyInBeat = 2,
  }) : _groupSolver = groupSolver;

  final SceneGroupChoreographySolver _groupSolver;
  final int maxHighEnergyInBeat;

  SceneInterComponentChoreographyResult solve({
    required List<ReFusionMotionDirectorComponent> components,
    required List<ReFusionMotionDirectorPrimitive> primitives,
    required String featureBeatId,
    required String outroBeatId,
  }) {
    final issues = <ReFusionMotionDirectorIssue>[];

    final grouped = _groupSolver.solve(
      components: components,
      primitives: primitives,
      featureBeatId: featureBeatId,
      outroBeatId: outroBeatId,
    );
    issues.addAll(grouped.issues);

    _enforceSinglePrimaryFocus(components: grouped.components, issues: issues);
    _checkEnergyConservation(
      primitives: grouped.primitives,
      beatId: featureBeatId,
      issues: issues,
    );

    final severity = issues.any(
      (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
    )
        ? ReFusionMotionDirectorIssueSeverity.error
        : ReFusionMotionDirectorIssueSeverity.info;
    issues.add(
      ReFusionMotionDirectorIssue(
        severity: severity,
        message: '$kSceneInterComponentChoreographyProofTag '
            'featureBeatId=$featureBeatId '
            'outroBeatId=$outroBeatId '
            'componentCount=${grouped.components.length} '
            'primitiveCount=${grouped.primitives.length} '
            'groupedCards=${grouped.groupedCardCount} '
            'fallbackReason=none',
        path: 'interComponentChoreography',
      ),
    );

    return SceneInterComponentChoreographyResult(
      components: List<ReFusionMotionDirectorComponent>.unmodifiable(
          grouped.components),
      primitives: List<ReFusionMotionDirectorPrimitive>.unmodifiable(
          grouped.primitives),
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  void _enforceSinglePrimaryFocus({
    required List<ReFusionMotionDirectorComponent> components,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    final primary = components.where((component) {
      final normalizedRole = _normalize(component.role);
      return normalizedRole == 'textheadline' ||
          normalizedRole == 'hero' ||
          normalizedRole == 'primary';
    }).toList(growable: false);
    if (primary.length <= 1) {
      return;
    }
    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.error,
        message:
            'Multiple primary focal components detected (${primary.length}). Keep one primary focal element per beat.',
        path: 'interComponentChoreography.primaryFocus',
      ),
    );
  }

  void _checkEnergyConservation({
    required List<ReFusionMotionDirectorPrimitive> primitives,
    required String beatId,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    final highEnergy = primitives.where((primitive) {
      if (primitive.beatId != beatId) {
        return false;
      }
      final id = _normalize(primitive.id);
      return id.contains('popinspring') ||
          id.contains('cardspringentrance') ||
          id.contains('stampdown') ||
          id.contains('whippan');
    }).length;
    if (highEnergy > maxHighEnergyInBeat) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'High-energy primitives in beat `$beatId` = $highEnergy (max recommended $maxHighEnergyInBeat).',
          path: 'interComponentChoreography.energyConservation',
        ),
      );
    }
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
