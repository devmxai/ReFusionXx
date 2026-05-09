import '../models/refusion_motion_director_models.dart';

enum SceneMotionRecipeCategory {
  entrance,
  exit,
  text,
  icon,
  card,
  group,
  transition,
  emphasis,
}

class SceneMotionRecipeChannel {
  const SceneMotionRecipeChannel({
    required this.kind,
    required this.property,
    required this.fromValue,
    required this.toValue,
    required this.startFraction,
    required this.endFraction,
    this.easing,
    this.note,
  });

  final String kind;
  final String property;
  final Object fromValue;
  final Object toValue;
  final double startFraction;
  final double endFraction;
  final String? easing;
  final String? note;
}

class SceneMotionRecipeDefinition {
  const SceneMotionRecipeDefinition({
    required this.id,
    required this.category,
    required this.channels,
    required this.defaultDurationToken,
    required this.easingToken,
    required this.speedyGraphPreset,
    required this.allowedTargets,
    this.aspectBias = 'balanced',
    this.tasteNotes = '',
    this.staggerMs = 0,
    this.motionBlur = true,
  });

  final String id;
  final SceneMotionRecipeCategory category;
  final List<SceneMotionRecipeChannel> channels;
  final String defaultDurationToken;
  final String easingToken;
  final String speedyGraphPreset;
  final Set<String> allowedTargets;
  final String aspectBias;
  final String tasteNotes;
  final int staggerMs;
  final bool motionBlur;
}

class SceneMotionRecipeCompileRequest {
  const SceneMotionRecipeCompileRequest({
    required this.recipeId,
    required this.targetComponentId,
    required this.beatId,
    required this.startMs,
    required this.endMs,
    this.targetScope = 'component',
    this.index = 0,
    this.staggerMs,
    this.idPrefix,
  });

  final String recipeId;
  final String targetComponentId;
  final String beatId;
  final int startMs;
  final int endMs;
  final String targetScope;
  final int index;
  final int? staggerMs;
  final String? idPrefix;
}

class SceneMotionRecipeCompileResult {
  const SceneMotionRecipeCompileResult({
    required this.primitives,
    required this.issues,
  });

  final List<ReFusionMotionDirectorPrimitive> primitives;
  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}
