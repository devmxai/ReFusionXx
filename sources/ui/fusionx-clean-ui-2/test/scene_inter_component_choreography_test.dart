import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_inter_component_choreography.dart';

void main() {
  const solver = SceneInterComponentChoreographySolver();

  test('emits proof and preserves grouped choreography output', () {
    final components = <ReFusionMotionDirectorComponent>[
      ReFusionMotionDirectorComponent(
        id: 'title',
        role: 'text.headline',
        label: 'Title',
      ),
      for (var index = 1; index <= 2; index += 1)
        ReFusionMotionDirectorComponent(
          id: 'feature-card-$index-shell',
          role: 'shape.card',
          label: 'Card $index Shell',
        ),
    ];
    final primitives = <ReFusionMotionDirectorPrimitive>[
      const ReFusionMotionDirectorPrimitive(
        id: 'feature-card-1-shell-enter',
        beatId: 'features',
        targetComponentId: 'feature-card-1-shell',
        kind: 'slide',
        property: 'position',
        startMs: 1000,
        endMs: 1300,
        fromValue: <String, double>{'x': -180, 'y': 0},
        toValue: <String, double>{'x': 0, 'y': 0},
        easing: 'slowFastSlow',
      ),
      const ReFusionMotionDirectorPrimitive(
        id: 'feature-card-2-shell-enter',
        beatId: 'features',
        targetComponentId: 'feature-card-2-shell',
        kind: 'slide',
        property: 'position',
        startMs: 1000,
        endMs: 1300,
        fromValue: <String, double>{'x': -180, 'y': 0},
        toValue: <String, double>{'x': 0, 'y': 0},
        easing: 'slowFastSlow',
      ),
      const ReFusionMotionDirectorPrimitive(
        id: 'feature-card-1-shell-exit',
        beatId: 'outro',
        targetComponentId: 'feature-card-1-shell',
        kind: 'slide',
        property: 'position',
        startMs: 2400,
        endMs: 3000,
        fromValue: <String, double>{'x': 0, 'y': 0},
        toValue: <String, double>{'x': 0, 'y': 120},
        easing: 'fastSlow',
      ),
      const ReFusionMotionDirectorPrimitive(
        id: 'feature-card-2-shell-exit',
        beatId: 'outro',
        targetComponentId: 'feature-card-2-shell',
        kind: 'slide',
        property: 'position',
        startMs: 2400,
        endMs: 3000,
        fromValue: <String, double>{'x': 0, 'y': 0},
        toValue: <String, double>{'x': 0, 'y': 120},
        easing: 'fastSlow',
      ),
    ];

    final result = solver.solve(
      components: components,
      primitives: primitives,
      featureBeatId: 'features',
      outroBeatId: 'outro',
    );

    expect(result.components, isNotEmpty);
    expect(result.primitives, isNotEmpty);
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains(kSceneInterComponentChoreographyProofTag),
      ),
      isTrue,
    );
  });
}
