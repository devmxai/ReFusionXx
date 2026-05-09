import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_rhythm_density_validator.dart';

void main() {
  const validator = SceneRhythmDensityValidator();

  test('accepts balanced rhythm and density', () {
    final plan = ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: 'Balanced',
      durationMs: 3200,
      frameRate: 30,
      beats: <ReFusionMotionDirectorBeat>[
        ReFusionMotionDirectorBeat(
          id: 'intro',
          label: 'Intro',
          startMs: 0,
          endMs: 900,
          intent: 'Intro',
        ),
        ReFusionMotionDirectorBeat(
          id: 'features',
          label: 'Features',
          startMs: 900,
          endMs: 2400,
          intent: 'Features',
        ),
      ],
      components: <ReFusionMotionDirectorComponent>[
        ReFusionMotionDirectorComponent(
            id: 'feature-1-shell', role: 'shape.card', label: 'A'),
        ReFusionMotionDirectorComponent(
            id: 'feature-2-shell', role: 'shape.card', label: 'B'),
      ],
      primitives: const <ReFusionMotionDirectorPrimitive>[
        ReFusionMotionDirectorPrimitive(
          id: 'feature-1-enter-0',
          beatId: 'features',
          targetComponentId: 'feature-1-shell',
          kind: 'slide',
          startMs: 900,
          endMs: 1400,
        ),
        ReFusionMotionDirectorPrimitive(
          id: 'feature-1-enter-1',
          beatId: 'features',
          targetComponentId: 'feature-1-shell',
          kind: 'opacity',
          startMs: 920,
          endMs: 1450,
        ),
        ReFusionMotionDirectorPrimitive(
          id: 'feature-2-enter-0',
          beatId: 'features',
          targetComponentId: 'feature-2-shell',
          kind: 'scale',
          startMs: 980,
          endMs: 1500,
        ),
      ],
    );

    final result = validator.validate(plan);
    expect(result.isValid, isTrue);
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneRhythmDensityProofTag),
      ),
      isTrue,
    );
  });

  test('rejects low motion variety and short beats', () {
    final plan = ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: 'Low variety',
      durationMs: 2200,
      frameRate: 30,
      beats: <ReFusionMotionDirectorBeat>[
        ReFusionMotionDirectorBeat(
          id: 'features',
          label: 'Features',
          startMs: 0,
          endMs: 220,
          intent: 'Too short',
        ),
      ],
      components: <ReFusionMotionDirectorComponent>[
        ReFusionMotionDirectorComponent(
            id: 'feature-1-shell', role: 'shape.card', label: 'A'),
        ReFusionMotionDirectorComponent(
            id: 'feature-2-shell', role: 'shape.card', label: 'B'),
      ],
      primitives: const <ReFusionMotionDirectorPrimitive>[
        ReFusionMotionDirectorPrimitive(
          id: 'feature-1-enter-0',
          beatId: 'features',
          targetComponentId: 'feature-1-shell',
          kind: 'opacity',
          startMs: 0,
          endMs: 120,
        ),
        ReFusionMotionDirectorPrimitive(
          id: 'feature-2-enter-0',
          beatId: 'features',
          targetComponentId: 'feature-2-shell',
          kind: 'opacity',
          startMs: 10,
          endMs: 130,
        ),
      ],
    );

    final result = validator.validate(plan);
    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) => issue.message.contains('too short'),
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) => issue.message.contains('Motion variety is too low'),
      ),
      isTrue,
    );
  });
}
