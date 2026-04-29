import '../models/refusion_motion_director_models.dart';
import 'professional_scene_timing_contract.dart';

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
  const ReFusionMotionDirectorLinter({
    ProfessionalSceneTimingContractValidator timingContractValidator =
        const ProfessionalSceneTimingContractValidator(),
  }) : _timingContractValidator = timingContractValidator;

  final ProfessionalSceneTimingContractValidator _timingContractValidator;

  ReFusionMotionDirectorLintResult lint(ReFusionMotionDirectorPlan plan) {
    final issues = <ReFusionMotionDirectorIssue>[];
    _lintPlanHeader(plan, issues);
    _lintComponents(plan, issues);
    _lintBeats(plan, issues);
    _lintPrimitives(plan, issues);
    issues.addAll(_timingContractValidator.validateDirectorPlan(plan).issues);
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
    final previousBeats = <ReFusionMotionDirectorBeat>[];
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
      for (final previousBeat in previousBeats) {
        if (!_beatsOverlap(previousBeat, beat)) {
          continue;
        }
        final sharedRefs = _sharedComponentRefs(previousBeat, beat);
        final hasExplicitRefs = previousBeat.componentRefs.isNotEmpty &&
            beat.componentRefs.isNotEmpty;
        final hasSafeSharedComponentHandoff = hasExplicitRefs &&
            sharedRefs.isNotEmpty &&
            _hasDisjointSharedComponentPrimitiveHandoff(
              plan: plan,
              left: previousBeat,
              right: beat,
              sharedRefs: sharedRefs,
            );
        final hasExplicitParallelIntent =
            _hasExplicitParallelIntent(previousBeat, beat);
        final hasExplicitHandoffIntent =
            _hasExplicitHandoffIntent(previousBeat, beat);
        final hasDistinctRefs = hasExplicitRefs && sharedRefs.isEmpty;
        final isAmbiguous = !hasExplicitRefs ||
            (sharedRefs.isNotEmpty &&
                (!hasSafeSharedComponentHandoff ||
                    !hasExplicitHandoffIntent)) ||
            (hasDistinctRefs && !hasExplicitParallelIntent);
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: isAmbiguous
                ? ReFusionMotionDirectorIssueSeverity.error
                : ReFusionMotionDirectorIssueSeverity.warning,
            message: isAmbiguous
                ? sharedRefs.isEmpty && hasExplicitRefs
                    ? 'Beat `${beat.id}` overlaps beat `${previousBeat.id}` on distinct components without explicit parallel intent. Mark the overlap as parallel/while/meanwhile choreography or separate the beats.'
                    : hasSafeSharedComponentHandoff && !hasExplicitHandoffIntent
                        ? 'Beat `${beat.id}` overlaps beat `${previousBeat.id}` on shared component handoff without explicit handoff intent. Mark the overlap as handoff/morph/transform choreography or separate the beats.'
                        : 'Beat `${beat.id}` overlaps beat `${previousBeat.id}` on the same or unspecified components. Put shared-component motion in one intentional beat.'
                : sharedRefs.isNotEmpty
                    ? 'Beat `${beat.id}` overlaps beat `${previousBeat.id}` on shared components, but their overlapping primitives animate disjoint properties. Accepted as intentional handoff choreography.'
                    : 'Beat `${beat.id}` overlaps beat `${previousBeat.id}` on distinct components. Accepted as intentional parallel choreography.',
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
      previousBeats.add(beat);
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
            severity: ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Typewriter primitive `${primitive.id}` omitted numeric fromValue/toValue. ReFusion will default to 0.0 -> 1.0.',
            path: path,
          ),
        );
      }
      final effectiveFrom = from ?? 0.0;
      final effectiveTo = to ?? 1.0;
      if (effectiveTo < effectiveFrom) {
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

  bool _beatsOverlap(
    ReFusionMotionDirectorBeat left,
    ReFusionMotionDirectorBeat right,
  ) {
    return left.startMs < right.endMs && right.startMs < left.endMs;
  }

  Set<String> _sharedComponentRefs(
    ReFusionMotionDirectorBeat left,
    ReFusionMotionDirectorBeat right,
  ) {
    return left.componentRefs.toSet().intersection(right.componentRefs.toSet());
  }

  bool _hasDisjointSharedComponentPrimitiveHandoff({
    required ReFusionMotionDirectorPlan plan,
    required ReFusionMotionDirectorBeat left,
    required ReFusionMotionDirectorBeat right,
    required Set<String> sharedRefs,
  }) {
    final overlapStartMs =
        left.startMs > right.startMs ? left.startMs : right.startMs;
    final overlapEndMs = left.endMs < right.endMs ? left.endMs : right.endMs;
    if (overlapEndMs <= overlapStartMs) {
      return false;
    }

    var hasInspectableSharedRef = false;
    for (final sharedRef in sharedRefs) {
      final leftProperties = _overlappingPrimitivePropertyGroups(
        plan: plan,
        beatId: left.id,
        componentId: sharedRef,
        overlapStartMs: overlapStartMs,
        overlapEndMs: overlapEndMs,
      );
      final rightProperties = _overlappingPrimitivePropertyGroups(
        plan: plan,
        beatId: right.id,
        componentId: sharedRef,
        overlapStartMs: overlapStartMs,
        overlapEndMs: overlapEndMs,
      );
      if (leftProperties.isEmpty || rightProperties.isEmpty) {
        return false;
      }
      hasInspectableSharedRef = true;
      if (leftProperties.intersection(rightProperties).isNotEmpty) {
        return false;
      }
    }
    return hasInspectableSharedRef;
  }

  bool _hasExplicitParallelIntent(
    ReFusionMotionDirectorBeat left,
    ReFusionMotionDirectorBeat right,
  ) {
    final text = _normalizeToken(
      '${left.label} ${left.intent} ${right.label} ${right.intent}',
    );
    return text.contains('parallel') ||
        text.contains('while') ||
        text.contains('meanwhile') ||
        text.contains('alongside') ||
        text.contains('simultaneous') ||
        text.contains('together') ||
        text.contains('during') ||
        text.contains('asbackground') ||
        text.contains('backgroundsettle') ||
        text.contains('backgroundsettles');
  }

  bool _hasExplicitHandoffIntent(
    ReFusionMotionDirectorBeat left,
    ReFusionMotionDirectorBeat right,
  ) {
    final text = _normalizeToken(
      '${left.label} ${left.intent} ${right.label} ${right.intent}',
    );
    return text.contains('handoff') ||
        text.contains('handsoff') ||
        text.contains('morph') ||
        text.contains('transform') ||
        text.contains('transition') ||
        text.contains('turnsinto') ||
        text.contains('becomes') ||
        text.contains('expand') ||
        text.contains('collapse') ||
        text.contains('samecomponent') ||
        text.contains('sameshell') ||
        text.contains('sameelement');
  }

  Set<String> _overlappingPrimitivePropertyGroups({
    required ReFusionMotionDirectorPlan plan,
    required String beatId,
    required String componentId,
    required int overlapStartMs,
    required int overlapEndMs,
  }) {
    final properties = <String>{};
    for (final primitive in plan.primitives) {
      if (primitive.beatId != beatId ||
          primitive.targetComponentId != componentId ||
          !_timeRangesOverlap(
            primitive.startMs,
            primitive.endMs,
            overlapStartMs,
            overlapEndMs,
          )) {
        continue;
      }
      final property = _propertyGroupForPrimitive(primitive);
      if (property != null) {
        properties.add(property);
      }
    }
    return properties;
  }

  bool _timeRangesOverlap(
    int leftStartMs,
    int leftEndMs,
    int rightStartMs,
    int rightEndMs,
  ) {
    return leftStartMs < rightEndMs && rightStartMs < leftEndMs;
  }

  String? _propertyGroupForPrimitive(
    ReFusionMotionDirectorPrimitive primitive,
  ) {
    final explicit = primitive.property?.trim();
    final property = explicit != null && explicit.isNotEmpty
        ? explicit
        : _propertyForPrimitiveKind(primitive.kind);
    if (property == null) {
      return null;
    }
    final normalized = _normalizeToken(property);
    if (normalized == 'positionx' ||
        normalized == 'positiony' ||
        normalized == 'x' ||
        normalized == 'y') {
      return 'position';
    }
    if (normalized == 'scalex' || normalized == 'scaley') {
      return 'scale';
    }
    if (normalized == 'typingprogress' ||
        normalized == 'letterrevealprogress' ||
        normalized == 'letterreveal' ||
        normalized == 'reveal') {
      return 'typewriterprogress';
    }
    return normalized;
  }

  String? _propertyForPrimitiveKind(String kind) {
    final normalizedKind = _normalizeToken(kind);
    if (normalizedKind == 'typewriter' ||
        normalizedKind == 'typing' ||
        normalizedKind == 'letterreveal') {
      return 'typewriterProgress';
    }
    if (normalizedKind == 'enter' ||
        normalizedKind == 'fade' ||
        normalizedKind == 'opacity') {
      return 'opacity';
    }
    if (normalizedKind == 'move' || normalizedKind == 'slide') {
      return 'position';
    }
    if (normalizedKind == 'scale' ||
        normalizedKind == 'press' ||
        normalizedKind == 'cover') {
      return 'scale';
    }
    if (normalizedKind == 'widthgrow' || normalizedKind == 'linegrow') {
      return 'width';
    }
    if (normalizedKind == 'blur' || normalizedKind == 'deblur') {
      return 'blur';
    }
    if (normalizedKind == 'colorpulse' || normalizedKind == 'color') {
      return 'color';
    }
    return null;
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
