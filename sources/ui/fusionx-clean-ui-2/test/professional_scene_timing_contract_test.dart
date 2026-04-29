import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/professional_scene_timing_contract.dart';

void main() {
  const validator = ProfessionalSceneTimingContractValidator();

  ReFusionMotionDirectorPlan plan({
    List<ReFusionMotionDirectorBeat>? beats,
    List<ReFusionMotionDirectorPrimitive>? primitives,
  }) {
    return ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: 'Timing Contract Plan',
      durationMs: 3600,
      frameRate: 30,
      components: <ReFusionMotionDirectorComponent>[
        ReFusionMotionDirectorComponent(
          id: 'title',
          role: 'text.typewriter',
          label: 'Title',
        ),
        ReFusionMotionDirectorComponent(
          id: 'dot',
          role: 'shape.circle',
          label: 'Moving dot',
        ),
      ],
      beats: beats ??
          <ReFusionMotionDirectorBeat>[
            ReFusionMotionDirectorBeat(
              id: 'title-type',
              label: 'Title types',
              startMs: 0,
              endMs: 1200,
              intent: 'Reveal the title.',
              componentRefs: const <String>['title'],
            ),
            ReFusionMotionDirectorBeat(
              id: 'title-hold',
              label: 'Readable hold',
              startMs: 1200,
              endMs: 1800,
              intent: 'Hold the title so it can be read.',
              componentRefs: const <String>['title'],
            ),
            ReFusionMotionDirectorBeat(
              id: 'dot-move',
              label: 'Dot moves',
              startMs: 1800,
              endMs: 3600,
              intent: 'Move the dot.',
              componentRefs: const <String>['dot'],
            ),
          ],
      primitives: primitives ??
          const <ReFusionMotionDirectorPrimitive>[
            ReFusionMotionDirectorPrimitive(
              id: 'title-typewriter',
              beatId: 'title-type',
              targetComponentId: 'title',
              kind: 'typewriter',
              property: 'typewriterProgress',
              startMs: 0,
              endMs: 1200,
              fromValue: 0.0,
              toValue: 1.0,
              easing: 'linear',
            ),
            ReFusionMotionDirectorPrimitive(
              id: 'dot-slide',
              beatId: 'dot-move',
              targetComponentId: 'dot',
              kind: 'slide',
              property: 'position',
              startMs: 1800,
              endMs: 2600,
              fromValue: <String, Object?>{'x': -120, 'y': 0},
              toValue: <String, Object?>{'x': 120, 'y': 0},
            ),
          ],
    );
  }

  test('accepts explicit text reveal followed by readable hold', () {
    final result = validator.validateDirectorPlan(plan());

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
    final titleTiming = result.componentTimings.singleWhere(
      (timing) => timing.componentId == 'title',
    );
    expect(titleTiming.startMs, 0);
    expect(titleTiming.endMs, 1800);
    expect(titleTiming.hasReadableHold, isTrue);
  });

  test('rejects text reveal without explicit readable hold', () {
    final result = validator.validateDirectorPlan(
      plan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'title-type',
            label: 'Title types',
            startMs: 0,
            endMs: 1200,
            intent: 'Reveal the title.',
            componentRefs: const <String>['title'],
          ),
          ReFusionMotionDirectorBeat(
            id: 'dot-move',
            label: 'Dot moves',
            startMs: 1200,
            endMs: 3600,
            intent: 'Move the dot.',
            componentRefs: const <String>['dot'],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('readable hold beat'),
      ),
      isNotEmpty,
    );
  });

  test('rejects text reveal that ends at the scene boundary', () {
    final result = validator.validateDirectorPlan(
      plan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'title-type',
            label: 'Title types',
            startMs: 0,
            endMs: 3600,
            intent: 'Reveal the title.',
            componentRefs: const <String>['title'],
          ),
        ],
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'title-typewriter',
            beatId: 'title-type',
            targetComponentId: 'title',
            kind: 'typewriter',
            property: 'typewriterProgress',
            startMs: 0,
            endMs: 3600,
            fromValue: 0.0,
            toValue: 1.0,
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('ends at the scene boundary'),
      ),
      isNotEmpty,
    );
  });

  test('rejects overlapping same-target same-property primitives', () {
    final result = validator.validateDirectorPlan(
      plan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'dot-slide-a',
            beatId: 'dot-move',
            targetComponentId: 'dot',
            kind: 'slide',
            property: 'position',
            startMs: 1800,
            endMs: 2600,
          ),
          ReFusionMotionDirectorPrimitive(
            id: 'dot-slide-b',
            beatId: 'dot-move',
            targetComponentId: 'dot',
            kind: 'slide',
            property: 'position',
            startMs: 2400,
            endMs: 3200,
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) =>
            issue.message.contains('overlap on the same target/property'),
      ),
      isNotEmpty,
    );
  });

  test('warns for sequential same-property primitives until compiler merge',
      () {
    final result = validator.validateDirectorPlan(
      plan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'dot-slide-a',
            beatId: 'dot-move',
            targetComponentId: 'dot',
            kind: 'slide',
            property: 'position',
            startMs: 1800,
            endMs: 2400,
          ),
          ReFusionMotionDirectorPrimitive(
            id: 'dot-slide-b',
            beatId: 'dot-move',
            targetComponentId: 'dot',
            kind: 'slide',
            property: 'position',
            startMs: 2400,
            endMs: 3200,
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('compiler will merge'),
      ),
      isNotEmpty,
    );
  });

  test('validates Scene Program layer spans and duplicate channels', () {
    final result = validator.validateSceneProgram(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Bad Program',
        durationMs: 1200,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'title-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 1000,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'title',
                kind: 'text',
                channels: <ReFusionSceneProgramChannel>[
                  ReFusionSceneProgramChannel(
                    target: 'self',
                    property: 'opacity',
                    keyframes: const <ReFusionSceneProgramKeyframe>[
                      ReFusionSceneProgramKeyframe(
                        timeMs: 0,
                        value: 0.0,
                      ),
                      ReFusionSceneProgramKeyframe(
                        timeMs: 1200,
                        value: 1.0,
                      ),
                    ],
                  ),
                  ReFusionSceneProgramChannel(
                    target: 'self',
                    property: 'opacity',
                    keyframes: const <ReFusionSceneProgramKeyframe>[
                      ReFusionSceneProgramKeyframe(
                        timeMs: 200,
                        value: 1.0,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('Duplicate Scene Program channel'),
      ),
      isNotEmpty,
    );
    expect(
      result.issues.where(
        (issue) => issue.message.contains('inside the owning layer duration'),
      ),
      isNotEmpty,
    );
  });
}
