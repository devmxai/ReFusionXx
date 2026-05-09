import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_motion_recipe_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/scene_motion_recipe_models.dart';

void main() {
  const compiler = SceneMotionRecipeCompiler();

  test('compiles popInSpring into scale and opacity primitives', () {
    final result = compiler.compile(
      const SceneMotionRecipeCompileRequest(
        recipeId: r'$motion.popInSpring',
        targetComponentId: 'hero-card',
        targetScope: 'cardShell',
        beatId: 'intro',
        startMs: 0,
        endMs: 480,
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.primitives, hasLength(greaterThanOrEqualTo(3)));
    final properties =
        result.primitives.map((primitive) => primitive.property).toSet();
    expect(properties.contains('scale'), isTrue);
    expect(properties.contains('opacity'), isTrue);
  });

  test('compiles gridStaggerProfessional with stagger offset by index', () {
    final first = compiler.compile(
      const SceneMotionRecipeCompileRequest(
        recipeId: r'$motion.gridStaggerProfessional',
        targetComponentId: 'card-1',
        targetScope: 'cardShell',
        beatId: 'features',
        startMs: 1000,
        endMs: 1600,
        index: 0,
      ),
    );
    final second = compiler.compile(
      const SceneMotionRecipeCompileRequest(
        recipeId: r'$motion.gridStaggerProfessional',
        targetComponentId: 'card-2',
        targetScope: 'cardShell',
        beatId: 'features',
        startMs: 1000,
        endMs: 1600,
        index: 1,
      ),
    );

    expect(first.isValid, isTrue);
    expect(second.isValid, isTrue);
    expect(second.primitives.first.startMs,
        greaterThan(first.primitives.first.startMs));
  });

  test('rejects unknown recipe ids', () {
    final result = compiler.compile(
      const SceneMotionRecipeCompileRequest(
        recipeId: r'$motion.notReal',
        targetComponentId: 'target',
        targetScope: 'component',
        beatId: 'intro',
        startMs: 0,
        endMs: 400,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues
          .any((issue) => issue.message.contains('Unknown motion recipe')),
      isTrue,
    );
  });
}
