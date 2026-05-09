import '../models/refusion_motion_director_models.dart';
import '../models/scene_director_brief_models.dart';
import '../models/scene_semantic_blueprint_models.dart';
import '../models/refusion_scene_program_models.dart';
import 'scene_director_blueprint_compiler.dart';
import 'scene_director_plan_validator.dart';
import 'scene_director_planner.dart';

class SceneDirectorIntelligenceResult {
  const SceneDirectorIntelligenceResult({
    required this.issues,
    this.brief,
    this.plan,
    this.blueprint,
  });

  final SceneDirectorBrief? brief;
  final ReFusionMotionDirectorPlan? plan;
  final SemanticSceneBlueprint? blueprint;
  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid =>
      brief != null &&
      plan != null &&
      blueprint != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class SceneDirectorIntelligence {
  const SceneDirectorIntelligence({
    SceneDirectorPlanValidator validator = const SceneDirectorPlanValidator(),
    SceneDirectorPlanner planner = const SceneDirectorPlanner(),
    SceneDirectorBlueprintCompiler blueprintCompiler =
        const SceneDirectorBlueprintCompiler(),
  })  : _validator = validator,
        _planner = planner,
        _blueprintCompiler = blueprintCompiler;

  final SceneDirectorPlanValidator _validator;
  final SceneDirectorPlanner _planner;
  final SceneDirectorBlueprintCompiler _blueprintCompiler;

  SceneDirectorIntelligenceResult compileFromRawBrief(Object? rawBrief) {
    final validation = _validator.validate(rawBrief);
    final issues = <ReFusionMotionDirectorIssue>[
      ...validation.issues.map(_toDirectorIssue),
    ];
    if (!validation.isValid || validation.brief == null) {
      return SceneDirectorIntelligenceResult(
        issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
      );
    }

    final planResult = _planner.plan(validation.brief!);
    issues.addAll(planResult.issues);
    if (!planResult.isValid || planResult.plan == null) {
      return SceneDirectorIntelligenceResult(
        brief: validation.brief,
        issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
      );
    }

    final compileResult = _blueprintCompiler.compile(
      plan: planResult.plan!,
      sourceBrief: validation.brief,
    );
    issues.addAll(compileResult.issues);
    return SceneDirectorIntelligenceResult(
      brief: validation.brief,
      plan: planResult.plan,
      blueprint: compileResult.blueprint,
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  ReFusionMotionDirectorIssue _toDirectorIssue(
    ReFusionSceneProgramIssue issue,
  ) {
    return ReFusionMotionDirectorIssue(
      severity: switch (issue.severity) {
        ReFusionSceneProgramIssueSeverity.error =>
          ReFusionMotionDirectorIssueSeverity.error,
        ReFusionSceneProgramIssueSeverity.warning =>
          ReFusionMotionDirectorIssueSeverity.warning,
        ReFusionSceneProgramIssueSeverity.info =>
          ReFusionMotionDirectorIssueSeverity.info,
      },
      message: issue.message,
      path: issue.path,
    );
  }
}
