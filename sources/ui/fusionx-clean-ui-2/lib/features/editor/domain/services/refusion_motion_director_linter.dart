import '../models/refusion_motion_director_models.dart';

class ReFusionMotionDirectorLintResult {
  ReFusionMotionDirectorLintResult({
    required List<ReFusionMotionDirectorIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class ReFusionMotionDirectorLinter {
  const ReFusionMotionDirectorLinter();

  ReFusionMotionDirectorLintResult lint(ReFusionMotionDirectorPlan plan) {
    final issues = <ReFusionMotionDirectorIssue>[];
    _lintPlanHeader(plan, issues);
    _lintComponents(plan, issues);
    _lintBeats(plan, issues);
    _lintPrimitives(plan, issues);
    return ReFusionMotionDirectorLintResult(issues: issues);
  }

  void _lintPlanHeader(
    ReFusionMotionDirectorPlan plan,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    if (plan.schemaVersion != ReFusionMotionDirectorPlan.currentSchemaVersion) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'Unsupported director schema `${plan.schemaVersion}`. Expected `${ReFusionMotionDirectorPlan.currentSchemaVersion}`.',
          path: 'schemaVersion',
        ),
      );
    }
    if (plan.durationMs <= 0) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan duration must be greater than zero.',
          path: 'durationMs',
        ),
      );
    }
    if (plan.frameRate <= 0) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan frameRate must be greater than zero.',
          path: 'frameRate',
        ),
      );
    }
    if (plan.canvasWidth <= 0 || plan.canvasHeight <= 0) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan canvas size must be positive.',
          path: 'canvas',
        ),
      );
    }
    if (plan.beats.isEmpty) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan must include ordered beats.',
          path: 'beats',
        ),
      );
    }
    if (plan.components.isEmpty) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Director plan must include semantic components.',
          path: 'components',
        ),
      );
    }
  }

  void _lintComponents(
    ReFusionMotionDirectorPlan plan,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    final ids = <String>{};
    for (var index = 0; index < plan.components.length; index += 1) {
      final component = plan.components[index];
      final path = 'components[$index]';
      if (component.id.trim().isEmpty) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Component id must not be empty.',
            path: '$path.id',
          ),
        );
      } else if (!ids.add(component.id)) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Duplicate component id `${component.id}`.',
            path: '$path.id',
          ),
        );
      }
      if (component.role.trim().isEmpty) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Component `${component.id}` must declare a role.',
            path: '$path.role',
          ),
        );
      }
    }
  }

  void _lintBeats(
    ReFusionMotionDirectorPlan plan,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    final componentIds =
        plan.components.map((component) => component.id).toSet();
    final ids = <String>{};
    var previousEndMs = 0;
    for (var index = 0; index < plan.beats.length; index += 1) {
      final beat = plan.beats[index];
      final path = 'beats[$index]';
      if (beat.id.trim().isEmpty) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Beat id must not be empty.',
            path: '$path.id',
          ),
        );
      } else if (!ids.add(beat.id)) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Duplicate beat id `${beat.id}`.',
            path: '$path.id',
          ),
        );
      }
      if (beat.startMs < 0 || beat.endMs > plan.durationMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Beat `${beat.id}` must stay inside the composition duration.',
            path: path,
          ),
        );
      }
      if (beat.endMs <= beat.startMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Beat `${beat.id}` must have positive duration.',
            path: path,
          ),
        );
      }
      if (index > 0 && beat.startMs < previousEndMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Beat `${beat.id}` overlaps the previous beat. Use ordered beats instead of ambiguous simultaneous scene direction.',
            path: '$path.startMs',
          ),
        );
      }
      if (index > 0 && beat.startMs > previousEndMs + 900) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Beat `${beat.id}` leaves a long empty gap before it starts.',
            path: '$path.startMs',
          ),
        );
      }
      for (final componentRef in beat.componentRefs) {
        if (!componentIds.contains(componentRef)) {
          issues.add(
            ReFusionMotionDirectorIssue(
              severity: ReFusionMotionDirectorIssueSeverity.error,
              message:
                  'Beat `${beat.id}` references unknown component `$componentRef`.',
              path: '$path.componentRefs',
            ),
          );
        }
      }
      previousEndMs = beat.endMs > previousEndMs ? beat.endMs : previousEndMs;
    }
  }

  void _lintPrimitives(
    ReFusionMotionDirectorPlan plan,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    final beatById = <String, ReFusionMotionDirectorBeat>{
      for (final beat in plan.beats) beat.id: beat,
    };
    final componentIds =
        plan.components.map((component) => component.id).toSet();
    final ids = <String>{};
    for (var index = 0; index < plan.primitives.length; index += 1) {
      final primitive = plan.primitives[index];
      final path = 'primitives[$index]';
      if (primitive.id.trim().isEmpty) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Primitive id must not be empty.',
            path: '$path.id',
          ),
        );
      } else if (!ids.add(primitive.id)) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Duplicate primitive id `${primitive.id}`.',
            path: '$path.id',
          ),
        );
      }
      if (!componentIds.contains(primitive.targetComponentId)) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Primitive `${primitive.id}` targets unknown component `${primitive.targetComponentId}`.',
            path: '$path.targetComponentId',
          ),
        );
      }
      final beat = beatById[primitive.beatId];
      if (beat == null) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Primitive `${primitive.id}` references unknown beat `${primitive.beatId}`.',
            path: '$path.beatId',
          ),
        );
      }
      if (primitive.startMs < 0 || primitive.endMs > plan.durationMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Primitive `${primitive.id}` must stay inside the composition duration.',
            path: path,
          ),
        );
      }
      if (primitive.endMs <= primitive.startMs) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message: 'Primitive `${primitive.id}` must have positive duration.',
            path: path,
          ),
        );
      }
      if (beat != null &&
          (primitive.startMs < beat.startMs || primitive.endMs > beat.endMs)) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Primitive `${primitive.id}` must stay inside its owning beat `${beat.id}`.',
            path: path,
          ),
        );
      }
      _lintPrimitiveKind(primitive, path, issues);
    }
    if (plan.primitives.isEmpty) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Director plan has no primitives. The scene may validate but has no choreographed motion.',
          path: 'primitives',
        ),
      );
    }
  }

  void _lintPrimitiveKind(
    ReFusionMotionDirectorPrimitive primitive,
    String path,
    List<ReFusionMotionDirectorIssue> issues,
  ) {
    final kind = _normalizeToken(primitive.kind);
    if (kind.isEmpty) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message: 'Primitive `${primitive.id}` must declare a kind.',
          path: '$path.kind',
        ),
      );
      return;
    }
    if (kind == 'typewriter' || kind == 'typing' || kind == 'letterreveal') {
      final from = _numberValue(primitive.fromValue);
      final to = _numberValue(primitive.toValue);
      if (from == null || to == null) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Typewriter primitive `${primitive.id}` must declare numeric fromValue and toValue.',
            path: path,
          ),
        );
        return;
      }
      if (to < from) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Typewriter primitive `${primitive.id}` runs backward. Keyboard typing must progress from 0 toward 1.',
            path: path,
          ),
        );
      }
    }
  }

  double? _numberValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
