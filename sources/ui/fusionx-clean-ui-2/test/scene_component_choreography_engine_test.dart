import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_brand_motion_profile.dart';
import 'package:refusion_app/features/editor/domain/services/scene_component_choreography_engine.dart';
import 'package:refusion_app/features/editor/domain/services/scene_component_choreography_models.dart';

void main() {
  const engine = SceneComponentChoreographyEngine();
  const techProfile = SceneBrandMotionProfile(
    id: r'$motion.brand.tech',
    style: 'tech',
    shellEnterRecipe: r'$motion.slideInFromLeft',
    shellExitRecipe: r'$motion.pushBack',
    iconEnterRecipe: r'$motion.iconPop',
    labelEnterRecipe: r'$motion.wordCascadeUp',
    bodyEnterRecipe: r'$motion.wordCascadeUp',
  );

  test('builds coherent FeatureCard enter/exit choreography', () {
    final plan = engine.planFeatureCard(
      enterStartMs: 800,
      enterEndMs: 1300,
      outroStartMs: 2300,
      outroEndMs: 3200,
      motionProfile: techProfile,
    );

    expect(
      plan.issues.where((issue) => issue.severity.name == 'error'),
      isEmpty,
    );
    expect(plan.enterSpans, hasLength(4));
    expect(plan.exitSpans, hasLength(4));
    expect(
      plan.issues.any(
        (issue) => issue.message.contains(kSceneComponentChoreographyProofTag),
      ),
      isTrue,
    );

    final enterByRole = <String, SceneComponentChoreographySpan>{
      for (final span in plan.enterSpans) span.role: span,
    };
    expect(
        enterByRole['shell']!.startMs, lessThan(enterByRole['icon']!.startMs));
    expect(
        enterByRole['icon']!.startMs, lessThan(enterByRole['label']!.startMs));
    expect(
        enterByRole['label']!.startMs, lessThan(enterByRole['body']!.startMs));

    final exitByRole = <String, SceneComponentChoreographySpan>{
      for (final span in plan.exitSpans) span.role: span,
    };
    expect(exitByRole['body']!.startMs, lessThan(exitByRole['label']!.startMs));
    expect(exitByRole['label']!.startMs, lessThan(exitByRole['icon']!.startMs));
    expect(exitByRole['icon']!.startMs, lessThan(exitByRole['shell']!.startMs));
  });
}
