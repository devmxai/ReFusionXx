import '../models/refusion_motion_director_models.dart';
import 'scene_brand_motion_profile.dart';
import 'scene_component_choreography_models.dart';

class SceneComponentChoreographyEngine {
  const SceneComponentChoreographyEngine();

  static const List<SceneComponentChoreographyStep> _featureCardSteps =
      <SceneComponentChoreographyStep>[
    SceneComponentChoreographyStep(
      role: 'shell',
      targetScope: 'cardShell',
      enterOffsetMs: 0,
      enterTailMs: 0,
      exitOffsetMs: 105,
    ),
    SceneComponentChoreographyStep(
      role: 'icon',
      targetScope: 'icon',
      enterOffsetMs: 70,
      enterTailMs: 0,
      exitOffsetMs: 70,
    ),
    SceneComponentChoreographyStep(
      role: 'label',
      targetScope: 'body',
      enterOffsetMs: 110,
      enterTailMs: 80,
      exitOffsetMs: 35,
    ),
    SceneComponentChoreographyStep(
      role: 'body',
      targetScope: 'body',
      enterOffsetMs: 170,
      enterTailMs: 140,
      exitOffsetMs: 0,
    ),
  ];

  SceneComponentChoreographyPlan planFeatureCard({
    required int enterStartMs,
    required int enterEndMs,
    required int outroStartMs,
    required int outroEndMs,
    required SceneBrandMotionProfile motionProfile,
  }) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final enterSpans = <SceneComponentChoreographySpan>[];
    final exitSpans = <SceneComponentChoreographySpan>[];

    if (enterEndMs <= enterStartMs || outroEndMs <= outroStartMs) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'FeatureCard choreography received invalid beat timing bounds.',
          path: 'componentChoreography.featureCard',
        ),
      );
      return SceneComponentChoreographyPlan(
        enterSpans: const <SceneComponentChoreographySpan>[],
        exitSpans: const <SceneComponentChoreographySpan>[],
        issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
      );
    }

    for (final step in _featureCardSteps) {
      final enterStart = enterStartMs + step.enterOffsetMs;
      final enterEnd = (enterEndMs + step.enterTailMs).clamp(
        enterStart + 120,
        outroStartMs - 20,
      );
      enterSpans.add(
        SceneComponentChoreographySpan(
          role: step.role,
          targetScope: step.targetScope,
          recipeId: _enterRecipeFor(step: step, profile: motionProfile),
          startMs: enterStart,
          endMs: enterEnd,
          phase: 'enter',
        ),
      );
    }

    // Exit in reverse narrative order: body -> label -> icon -> shell.
    final exitDuration = outroEndMs - outroStartMs;
    for (final step in _featureCardSteps) {
      final exitStart = (outroStartMs + step.exitOffsetMs).clamp(
        outroStartMs,
        outroEndMs - 80,
      );
      final tailFactor = step.role == 'shell' ? 1.0 : 0.88;
      final exitEnd = (exitStart + (exitDuration * tailFactor).round())
          .clamp(exitStart + 80, outroEndMs);
      exitSpans.add(
        SceneComponentChoreographySpan(
          role: step.role,
          targetScope: step.targetScope,
          recipeId: _exitRecipeFor(step: step, profile: motionProfile),
          startMs: exitStart,
          endMs: exitEnd,
          phase: 'exit',
        ),
      );
    }

    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.info,
        message: '$kSceneComponentChoreographyProofTag '
            'component=FeatureCard '
            'profile=${motionProfile.id} '
            'enterSteps=${enterSpans.length} '
            'exitSteps=${exitSpans.length} '
            'fallbackReason=none',
        path: 'componentChoreography.featureCard',
      ),
    );

    return SceneComponentChoreographyPlan(
      enterSpans: List<SceneComponentChoreographySpan>.unmodifiable(enterSpans),
      exitSpans: List<SceneComponentChoreographySpan>.unmodifiable(exitSpans),
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  String _enterRecipeFor({
    required SceneComponentChoreographyStep step,
    required SceneBrandMotionProfile profile,
  }) {
    if (step.enterRecipeOverride != null) {
      return step.enterRecipeOverride!;
    }
    switch (step.role) {
      case 'shell':
        return profile.shellEnterRecipe;
      case 'icon':
        return profile.iconEnterRecipe;
      case 'label':
        return profile.labelEnterRecipe;
      case 'body':
        return profile.bodyEnterRecipe;
      default:
        return profile.shellEnterRecipe;
    }
  }

  String _exitRecipeFor({
    required SceneComponentChoreographyStep step,
    required SceneBrandMotionProfile profile,
  }) {
    if (step.exitRecipeOverride != null) {
      return step.exitRecipeOverride!;
    }
    if (step.role == 'shell') {
      return profile.shellExitRecipe;
    }
    return r'$motion.fadeCollapse';
  }
}
