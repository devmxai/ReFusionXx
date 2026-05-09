import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_group_choreography_solver.dart';

void main() {
  const solver = SceneGroupChoreographySolver(
    enterStaggerMs: 80,
    exitStaggerMs: 40,
  );

  List<ReFusionMotionDirectorComponent> buildComponents() {
    return <ReFusionMotionDirectorComponent>[
      for (var index = 1; index <= 4; index += 1)
        ReFusionMotionDirectorComponent(
          id: 'feature-card-$index-shell',
          role: 'shape.card',
          label: 'Card $index Shell',
        ),
      for (var index = 1; index <= 4; index += 1)
        ReFusionMotionDirectorComponent(
          id: 'feature-card-$index-icon',
          role: 'icon',
          label: 'Card $index Icon',
        ),
    ];
  }

  List<ReFusionMotionDirectorPrimitive> buildPrimitives() {
    return <ReFusionMotionDirectorPrimitive>[
      for (var index = 1; index <= 4; index += 1)
        ReFusionMotionDirectorPrimitive(
          id: 'feature-card-$index-shell-enter',
          beatId: 'features',
          targetComponentId: 'feature-card-$index-shell',
          kind: 'slide',
          property: 'position',
          startMs: 1000,
          endMs: 1300,
          fromValue: <String, double>{'x': -180, 'y': 0},
          toValue: <String, double>{'x': 0, 'y': 0},
          easing: 'slowFastSlow',
        ),
      for (var index = 1; index <= 4; index += 1)
        ReFusionMotionDirectorPrimitive(
          id: 'feature-card-$index-shell-exit',
          beatId: 'outro',
          targetComponentId: 'feature-card-$index-shell',
          kind: 'slide',
          property: 'position',
          startMs: 2400,
          endMs: 3000,
          fromValue: <String, double>{'x': 0, 'y': 0},
          toValue: <String, double>{'x': 0, 'y': 120},
          easing: 'fastSlow',
        ),
      for (var index = 1; index <= 4; index += 1)
        ReFusionMotionDirectorPrimitive(
          id: 'feature-card-$index-icon-enter',
          beatId: 'features',
          targetComponentId: 'feature-card-$index-icon',
          kind: 'scale',
          property: 'scale',
          startMs: 1070,
          endMs: 1300,
          fromValue: 0.9,
          toValue: 1.0,
          easing: 'slowFastSlow',
        ),
    ];
  }

  test('applies stagger and coherent exits to feature-card group', () {
    final result = solver.solve(
      components: buildComponents(),
      primitives: buildPrimitives(),
      featureBeatId: 'features',
      outroBeatId: 'outro',
    );

    final shellStarts = <int>[];
    for (var index = 1; index <= 4; index += 1) {
      final primitive = result.primitives.firstWhere(
        (item) =>
            item.beatId == 'features' &&
            item.targetComponentId == 'feature-card-$index-shell',
      );
      shellStarts.add(primitive.startMs);
    }
    expect(shellStarts, <int>[1000, 1080, 1160, 1240]);

    final shellExitStarts = <int>[];
    for (var index = 1; index <= 4; index += 1) {
      final primitive = result.primitives.firstWhere(
        (item) =>
            item.beatId == 'outro' &&
            item.targetComponentId == 'feature-card-$index-shell',
      );
      shellExitStarts.add(primitive.startMs);
    }
    expect(shellExitStarts, <int>[2400, 2440, 2480, 2520]);

    final secondShell = result.primitives.firstWhere(
      (item) =>
          item.beatId == 'features' &&
          item.targetComponentId == 'feature-card-2-shell',
    );
    final secondFrom = secondShell.fromValue as Map<String, Object?>;
    expect(secondFrom['x'], 180);

    expect(
      result.issues.any(
        (issue) => issue.message.contains('FEATURE_CARD_CASCADE_APPLIED'),
      ),
      isTrue,
    );
  });
}
