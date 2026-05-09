import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_director_blueprint_compiler.dart';

void main() {
  const compiler = SceneDirectorBlueprintCompiler();

  test('compiles director plan into semantic blueprint with proof', () {
    final plan = ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: 'Blueprint compile test',
      durationMs: 2400,
      frameRate: 30,
      canvasWidth: 1080,
      canvasHeight: 1920,
      beats: <ReFusionMotionDirectorBeat>[
        ReFusionMotionDirectorBeat(
          id: 'intro',
          label: 'Intro',
          startMs: 0,
          endMs: 1200,
          intent: 'Enter hero',
          componentRefs: const <String>['title'],
        ),
      ],
      components: <ReFusionMotionDirectorComponent>[
        ReFusionMotionDirectorComponent(
          id: 'title',
          role: 'text.headline',
          label: 'Title',
          properties: const <String, Object?>{
            'text': 'Hello',
            'x': 0,
            'y': -260,
          },
        ),
      ],
      primitives: const <ReFusionMotionDirectorPrimitive>[
        ReFusionMotionDirectorPrimitive(
          id: 'title-enter',
          beatId: 'intro',
          targetComponentId: 'title',
          kind: 'slide',
          startMs: 0,
          endMs: 600,
          property: 'y',
          fromValue: -420,
          toValue: -260,
          easing: 'fastSlow',
        ),
      ],
    );

    final result = compiler.compile(plan: plan);

    expect(result.blueprint.schemaVersion, 'refusion.semantic-blueprint/v5');
    expect(result.blueprint.components, hasLength(1));
    expect(result.blueprint.beats, hasLength(1));
    expect(result.blueprint.components.first.type, 'MotionTextBlock');
    expect(result.blueprint.components.first.iconToken, startsWith(r'$icon.'));
    expect(result.blueprint.components.first.motionRecipe,
        startsWith(r'$motion.'));
    expect(result.blueprint.compositionIntent, startsWith(r'$composition.'));
    expect(result.blueprint.tasteProfile, startsWith(r'$taste.'));
    final timeline = result.blueprint.components.first.motionIntents['timeline']
        as List<Object?>;
    expect(timeline, hasLength(1));
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneDirectorPlannerProofTag),
      ),
      isTrue,
    );
  });
}
