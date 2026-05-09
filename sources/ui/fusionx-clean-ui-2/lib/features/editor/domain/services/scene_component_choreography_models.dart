import '../models/refusion_motion_director_models.dart';

const String kSceneComponentChoreographyProofTag =
    'TF_SCENE_COMPONENT_CHOREOGRAPHY_PROOF';

class SceneComponentChoreographyStep {
  const SceneComponentChoreographyStep({
    required this.role,
    required this.targetScope,
    required this.enterOffsetMs,
    required this.enterTailMs,
    required this.exitOffsetMs,
    this.enterRecipeOverride,
    this.exitRecipeOverride,
  });

  final String role;
  final String targetScope;
  final int enterOffsetMs;
  final int enterTailMs;
  final int exitOffsetMs;
  final String? enterRecipeOverride;
  final String? exitRecipeOverride;
}

class SceneComponentChoreographySpan {
  const SceneComponentChoreographySpan({
    required this.role,
    required this.targetScope,
    required this.recipeId,
    required this.startMs,
    required this.endMs,
    required this.phase,
  });

  final String role;
  final String targetScope;
  final String recipeId;
  final int startMs;
  final int endMs;
  final String phase;
}

class SceneComponentChoreographyPlan {
  const SceneComponentChoreographyPlan({
    required this.enterSpans,
    required this.exitSpans,
    required this.issues,
  });

  final List<SceneComponentChoreographySpan> enterSpans;
  final List<SceneComponentChoreographySpan> exitSpans;
  final List<ReFusionMotionDirectorIssue> issues;
}
