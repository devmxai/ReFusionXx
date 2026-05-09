import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_motion_recipe_library.dart';
import 'package:refusion_app/features/editor/domain/services/scene_motion_recipe_models.dart';

void main() {
  const library = SceneMotionRecipeLibrary();

  test('contains professional baseline recipe coverage', () {
    expect(library.all.length, greaterThanOrEqualTo(12));
    expect(library.find(r'$motion.slideInFromLeft'), isNotNull);
    expect(library.find(r'$motion.cardSpringEntrance'), isNotNull);
    expect(library.find(r'$motion.wordCascadeUp'), isNotNull);
    expect(library.find(r'$motion.fadeCollapse'), isNotNull);
    expect(library.find(r'$motion.fadeRaise'), isNotNull);
  });

  test('supports token and raw-id lookup for the same recipe', () {
    final byToken = library.find(r'$motion.scaleInBounce');
    final byId = library.find('scaleInBounce');

    expect(byToken, isNotNull);
    expect(byId, isNotNull);
    expect(byToken!.id, byId!.id);
    expect(byToken.category, SceneMotionRecipeCategory.entrance);
  });

  test('every recipe definition is executable and target-bounded', () {
    for (final definition in library.all) {
      expect(definition.channels, isNotEmpty, reason: definition.id);
      expect(definition.allowedTargets, isNotEmpty, reason: definition.id);
      expect(definition.defaultDurationToken, startsWith(r'$duration.'));
      expect(definition.easingToken, startsWith(r'$easing.'));
    }
  });
}
