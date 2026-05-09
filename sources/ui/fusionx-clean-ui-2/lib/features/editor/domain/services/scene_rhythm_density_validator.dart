import 'dart:math' as math;

import '../models/refusion_motion_director_models.dart';

const String kSceneRhythmDensityProofTag = 'TF_SCENE_RHYTHM_DENSITY_PROOF';

class SceneRhythmDensityValidationResult {
  const SceneRhythmDensityValidationResult({
    required this.issues,
  });

  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class SceneRhythmDensityValidator {
  const SceneRhythmDensityValidator({
    this.minBeatDurationMs = 400,
    this.maxBeatDurationMs = 2000,
    this.maxSimultaneousMotions = 14,
    this.maxDominantMotionKindRatio = 0.60,
  });

  final int minBeatDurationMs;
  final int maxBeatDurationMs;
  final int maxSimultaneousMotions;
  final double maxDominantMotionKindRatio;

  SceneRhythmDensityValidationResult validate(
    ReFusionMotionDirectorPlan plan,
  ) {
    final issues = <ReFusionMotionDirectorIssue>[];
    _validateBeatDurations(plan: plan, issues: issues);
    _validateSimultaneousDensity(plan: plan, issues: issues);
    _validateMotionVariety(plan: plan, issues: issues);

    issues.add(
      ReFusionMotionDirectorIssue(
        severity: issues.any(
          (issue) =>
              issue.severity == ReFusionMotionDirectorIssueSeverity.error,
        )
            ? ReFusionMotionDirectorIssueSeverity.error
            : ReFusionMotionDirectorIssueSeverity.info,
        message: '$kSceneRhythmDensityProofTag '
            'beatCount=${plan.beats.length} '
            'primitiveCount=${plan.primitives.length} '
            'maxSimultaneous=$maxSimultaneousMotions '
            'maxDominantRatio=${maxDominantMotionKindRatio.toStringAsFixed(2)}',
        path: 'rhythmDensity',
      ),
    );

    return SceneRhythmDensityValidationResult(
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  void _validateBeatDurations({
    required ReFusionMotionDirectorPlan plan,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    for (final beat in plan.beats) {
      final duration = beat.durationMs;
      if (duration < minBeatDurationMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: duration < (minBeatDurationMs * 0.6)
                ? ReFusionMotionDirectorIssueSeverity.error
                : ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Beat `${beat.id}` duration $duration ms is too short for readable pacing.',
            path: 'beats.${beat.id}',
          ),
        );
      }
      if (duration > maxBeatDurationMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: duration > (maxBeatDurationMs * 1.5)
                ? ReFusionMotionDirectorIssueSeverity.error
                : ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Beat `${beat.id}` duration $duration ms is too long and may feel static.',
            path: 'beats.${beat.id}',
          ),
        );
      }
    }
  }

  void _validateSimultaneousDensity({
    required ReFusionMotionDirectorPlan plan,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    final boundaries = <int>{
      0,
      plan.durationMs,
      ...plan.primitives.expand((primitive) => <int>[
            primitive.startMs,
            primitive.endMs,
          ]),
    }.toList(growable: false)
      ..sort();
    var maxSimultaneous = 0;
    for (var index = 0; index < boundaries.length - 1; index += 1) {
      final mid = ((boundaries[index] + boundaries[index + 1]) / 2).round();
      final active = plan.primitives
          .where((primitive) {
            return primitive.startMs <= mid && primitive.endMs > mid;
          })
          .map((primitive) => primitive.targetComponentId)
          .toSet()
          .length;
      maxSimultaneous = math.max(maxSimultaneous, active);
    }
    if (maxSimultaneous > maxSimultaneousMotions) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: maxSimultaneous > (maxSimultaneousMotions + 10)
              ? ReFusionMotionDirectorIssueSeverity.error
              : ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Simultaneous motion density $maxSimultaneous exceeds budget $maxSimultaneousMotions.',
          path: 'primitives',
        ),
      );
    }
  }

  void _validateMotionVariety({
    required ReFusionMotionDirectorPlan plan,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    final featuresBeat = plan.beats.where((beat) {
      final token = _normalize(beat.id);
      return token == 'features' || token == 'feature';
    }).firstOrNull;
    if (featuresBeat == null) {
      return;
    }
    final featureShells = plan.components
        .where((component) {
          return component.id.endsWith('-shell');
        })
        .map((component) => component.id)
        .toSet();
    if (featureShells.isEmpty) {
      return;
    }
    final kinds = plan.primitives
        .where((primitive) {
          return primitive.beatId == featuresBeat.id &&
              featureShells.contains(primitive.targetComponentId);
        })
        .map((primitive) => _normalize(primitive.kind))
        .where((kind) => kind.isNotEmpty)
        .toList(growable: false);
    if (kinds.length < 2) {
      return;
    }
    final counts = <String, int>{};
    for (final kind in kinds) {
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    final dominantCount = counts.values.fold<int>(0, math.max);
    final dominantRatio = dominantCount / kinds.length;
    if (dominantRatio > maxDominantMotionKindRatio) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: dominantRatio > 0.85
              ? ReFusionMotionDirectorIssueSeverity.error
              : ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Motion variety is too low in features beat; dominant motion kind ratio '
              '${dominantRatio.toStringAsFixed(2)} exceeds '
              '${maxDominantMotionKindRatio.toStringAsFixed(2)}.',
          path: 'primitives.features',
        ),
      );
    }
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

extension<E> on Iterable<E> {
  E? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
