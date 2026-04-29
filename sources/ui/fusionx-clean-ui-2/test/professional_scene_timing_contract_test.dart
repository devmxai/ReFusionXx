import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/professional_scene_timing_contract.dart';

void main() {
  const validator = ProfessionalSceneTimingContractValidator();
  const formatter = ProfessionalSceneTimingContractIssueFormatter();

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

  test('rejects primitives outside their owning beat range', () {
    final result = validator.validateDirectorPlan(
      plan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'dot-slide',
            beatId: 'dot-move',
            targetComponentId: 'dot',
            kind: 'slide',
            property: 'position',
            startMs: 1700,
            endMs: 2600,
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('inside owning beat'),
      ),
      isNotEmpty,
    );
  });

  test('rejects owning beats that do not reference the animated component', () {
    final result = validator.validateDirectorPlan(
      plan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'dot-slide',
            beatId: 'title-type',
            targetComponentId: 'dot',
            kind: 'slide',
            property: 'position',
            startMs: 100,
            endMs: 600,
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('must reference target component'),
      ),
      isNotEmpty,
    );
  });

  test('warns when visible component final motion ends at scene boundary', () {
    final result = validator.validateDirectorPlan(
      plan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'dot-slide',
            beatId: 'dot-move',
            targetComponentId: 'dot',
            kind: 'slide',
            property: 'position',
            startMs: 1800,
            endMs: 3600,
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionMotionDirectorIssueSeverity.warning &&
            issue.message.contains('final motion ends at the scene boundary'),
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

  test('rejects Scene Program channels without keyframes', () {
    final result = validator.validateSceneProgram(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Empty Channel Program',
        durationMs: 1200,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'title-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 1200,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'title',
                kind: 'text',
                channels: <ReFusionSceneProgramChannel>[
                  ReFusionSceneProgramChannel(
                    target: 'self',
                    property: 'opacity',
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
        (issue) => issue.message.contains('must include keyframes'),
      ),
      isNotEmpty,
    );
  });

  test('formats Scene Program timing issues with repair hints', () {
    final summary = formatter.formatSceneProgramIssues(
      const <ReFusionSceneProgramIssue>[
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Duplicate Scene Program channel `opacity` targets `self`. Merge same-target/property motion into one ordered channel.',
          path: 'layers[0].elements[0].channels[1]',
        ),
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Keyframe `timeMs` must be inside the owning layer duration.',
          path: 'layers[0].elements[0].channels[0].keyframes[2]',
        ),
      ],
    );

    expect(summary, contains('layers[0].elements[0].channels[1]'));
    expect(summary, contains('Fix: merge all keyframes'));
    expect(summary, contains('Fix: use layer-local timeMs'));
  });

  test('formats Director timing issues with repair hints', () {
    final summary = formatter.formatDirectorIssues(
      const <ReFusionMotionDirectorIssue>[
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'Text component `title` must have an explicit readable hold beat of at least 360ms after reveal primitive `title-typewriter`.',
          path: 'components.title',
        ),
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'Primitive `dot-slide` must stay inside owning beat `dot-move` time range.',
          path: 'primitives.dot-slide',
        ),
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'Beat `prompt-enter` overlaps beat `background-enter` on distinct components without explicit parallel intent.',
          path: 'beats[1].startMs',
        ),
      ],
    );

    expect(summary, contains('components.title'));
    expect(summary, contains('Fix: add a readable hold beat'));
    expect(summary, contains('Fix: move the primitive inside its beat'));
    expect(summary, contains('Fix: either separate the beats'));
  });
}
