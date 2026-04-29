import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_director_linter.dart';

void main() {
  const linter = ReFusionMotionDirectorLinter();

  ReFusionMotionDirectorPlan promptBarPlan({
    List<ReFusionMotionDirectorBeat>? beats,
    List<ReFusionMotionDirectorComponent>? components,
    List<ReFusionMotionDirectorPrimitive>? primitives,
  }) {
    return ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: 'Prompt Bar Director Plan',
      durationMs: 4200,
      frameRate: 30,
      components: components ??
          <ReFusionMotionDirectorComponent>[
            ReFusionMotionDirectorComponent(
              id: 'prompt-shell',
              role: 'promptInputBar.shell',
              label: 'Prompt shell',
            ),
            ReFusionMotionDirectorComponent(
              id: 'prompt-text',
              role: 'text.typewriter',
              label: 'Typed prompt',
            ),
            ReFusionMotionDirectorComponent(
              id: 'send-button',
              role: 'button.send',
              label: 'Send button',
            ),
            ReFusionMotionDirectorComponent(
              id: 'cover-circle',
              role: 'shape.revealCover',
              label: 'Reveal circle',
            ),
          ],
      beats: beats ??
          <ReFusionMotionDirectorBeat>[
            ReFusionMotionDirectorBeat(
              id: 'enter',
              label: 'Prompt bar enters',
              startMs: 0,
              endMs: 520,
              intent: 'Introduce the input shell with a clean ease-out.',
              componentRefs: const <String>['prompt-shell'],
            ),
            ReFusionMotionDirectorBeat(
              id: 'typing',
              label: 'Type the prompt',
              startMs: 520,
              endMs: 1900,
              intent: 'Reveal text like real keyboard input.',
              componentRefs: const <String>['prompt-text'],
            ),
            ReFusionMotionDirectorBeat(
              id: 'readable-hold',
              label: 'Readable hold',
              startMs: 1900,
              endMs: 2260,
              intent: 'Hold the typed prompt so it can be read.',
              componentRefs: const <String>['prompt-text'],
            ),
            ReFusionMotionDirectorBeat(
              id: 'send',
              label: 'Send press and cover',
              startMs: 2260,
              endMs: 4200,
              intent:
                  'Press send, collapse the prompt bar, and cover the screen.',
              componentRefs: const <String>[
                'send-button',
                'cover-circle',
              ],
            ),
          ],
      primitives: primitives ??
          const <ReFusionMotionDirectorPrimitive>[
            ReFusionMotionDirectorPrimitive(
              id: 'shell-scale-in',
              beatId: 'enter',
              targetComponentId: 'prompt-shell',
              kind: 'scale',
              property: 'scale',
              startMs: 0,
              endMs: 520,
              fromValue: 0.92,
              toValue: 1.0,
              easing: 'easeOut',
            ),
            ReFusionMotionDirectorPrimitive(
              id: 'text-type-on',
              beatId: 'typing',
              targetComponentId: 'prompt-text',
              kind: 'typewriter',
              property: 'typewriterProgress',
              startMs: 520,
              endMs: 1900,
              fromValue: 0.0,
              toValue: 1.0,
              easing: 'linear',
            ),
            ReFusionMotionDirectorPrimitive(
              id: 'send-press',
              beatId: 'send',
              targetComponentId: 'send-button',
              kind: 'press',
              property: 'scale',
              startMs: 2320,
              endMs: 2500,
              fromValue: 1.0,
              toValue: 0.92,
              easing: 'easeInOut',
            ),
            ReFusionMotionDirectorPrimitive(
              id: 'circle-cover',
              beatId: 'send',
              targetComponentId: 'cover-circle',
              kind: 'cover',
              property: 'scale',
              startMs: 2660,
              endMs: 4200,
              fromValue: 0.0,
              toValue: 32.0,
              easing: 'easeInOut',
            ),
          ],
    );
  }

  test('accepts an ordered professional beat plan', () {
    final result = linter.lint(promptBarPlan());

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test('accepts overlapping beats when component refs are distinct', () {
    final result = linter.lint(
      promptBarPlan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'background-enter',
            label: 'Background enter',
            startMs: 0,
            endMs: 1000,
            intent: 'Bring in the background.',
            componentRefs: const <String>['cover-circle'],
          ),
          ReFusionMotionDirectorBeat(
            id: 'prompt-enter',
            label: 'Prompt enter',
            startMs: 800,
            endMs: 1600,
            intent: 'Bring in the prompt shell while the background settles.',
            componentRefs: const <String>['prompt-shell'],
          ),
        ],
        primitives: const <ReFusionMotionDirectorPrimitive>[],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('Accepted as intentional parallel'),
      ),
      isNotEmpty,
    );
  });

  test('rejects distinct-component beat overlap without parallel intent', () {
    final result = linter.lint(
      promptBarPlan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'background-enter',
            label: 'Background enter',
            startMs: 0,
            endMs: 1000,
            intent: 'Bring in the background.',
            componentRefs: const <String>['cover-circle'],
          ),
          ReFusionMotionDirectorBeat(
            id: 'prompt-enter',
            label: 'Prompt enter',
            startMs: 800,
            endMs: 1600,
            intent: 'Bring in the prompt shell.',
            componentRefs: const <String>['prompt-shell'],
          ),
        ],
        primitives: const <ReFusionMotionDirectorPrimitive>[],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('without explicit parallel intent'),
      ),
      isNotEmpty,
    );
  });

  test('rejects overlapping beats when shared components are ambiguous', () {
    final result = linter.lint(
      promptBarPlan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'enter',
            label: 'Enter',
            startMs: 0,
            endMs: 1000,
            intent: 'Enter.',
            componentRefs: const <String>['prompt-shell'],
          ),
          ReFusionMotionDirectorBeat(
            id: 'typing',
            label: 'Typing',
            startMs: 800,
            endMs: 1600,
            intent: 'Type.',
            componentRefs: const <String>['prompt-shell'],
          ),
        ],
        primitives: const <ReFusionMotionDirectorPrimitive>[],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('overlaps beat `enter`'),
      ),
      isNotEmpty,
    );
  });

  test('accepts shared-component beat handoff with disjoint properties', () {
    final result = linter.lint(
      promptBarPlan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'circle-pop',
            label: 'Circle pop',
            startMs: 300,
            endMs: 1500,
            intent: 'The prompt shell scales into view.',
            componentRefs: const <String>['prompt-shell'],
          ),
          ReFusionMotionDirectorBeat(
            id: 'input-expand',
            label: 'Input expand',
            startMs: 1400,
            endMs: 3100,
            intent: 'The same shell expands horizontally.',
            componentRefs: const <String>['prompt-shell'],
          ),
        ],
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'shell-pop-scale',
            beatId: 'circle-pop',
            targetComponentId: 'prompt-shell',
            kind: 'scale',
            property: 'scale',
            startMs: 300,
            endMs: 1500,
            fromValue: 0.2,
            toValue: 1.0,
          ),
          ReFusionMotionDirectorPrimitive(
            id: 'shell-expand-width',
            beatId: 'input-expand',
            targetComponentId: 'prompt-shell',
            kind: 'widthGrow',
            property: 'width',
            startMs: 1400,
            endMs: 3100,
            fromValue: 112,
            toValue: 780,
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('Accepted as intentional handoff'),
      ),
      isNotEmpty,
    );
  });

  test('rejects shared-component handoff without explicit handoff intent', () {
    final result = linter.lint(
      promptBarPlan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'circle-pop',
            label: 'Circle pop',
            startMs: 300,
            endMs: 1500,
            intent: 'The prompt shell scales into view.',
            componentRefs: const <String>['prompt-shell'],
          ),
          ReFusionMotionDirectorBeat(
            id: 'input-grow',
            label: 'Input grow',
            startMs: 1400,
            endMs: 3100,
            intent: 'The prompt shell changes width.',
            componentRefs: const <String>['prompt-shell'],
          ),
        ],
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'shell-pop-scale',
            beatId: 'circle-pop',
            targetComponentId: 'prompt-shell',
            kind: 'scale',
            property: 'scale',
            startMs: 300,
            endMs: 1500,
            fromValue: 0.2,
            toValue: 1.0,
          ),
          ReFusionMotionDirectorPrimitive(
            id: 'shell-grow-width',
            beatId: 'input-grow',
            targetComponentId: 'prompt-shell',
            kind: 'widthGrow',
            property: 'width',
            startMs: 1400,
            endMs: 3100,
            fromValue: 112,
            toValue: 780,
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('without explicit handoff intent'),
      ),
      isNotEmpty,
    );
  });

  test('rejects shared-component beat overlap on the same property', () {
    final result = linter.lint(
      promptBarPlan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'scale-a',
            label: 'Scale A',
            startMs: 300,
            endMs: 1500,
            intent: 'First scale move.',
            componentRefs: const <String>['prompt-shell'],
          ),
          ReFusionMotionDirectorBeat(
            id: 'scale-b',
            label: 'Scale B',
            startMs: 1400,
            endMs: 2200,
            intent: 'Second scale move.',
            componentRefs: const <String>['prompt-shell'],
          ),
        ],
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'scale-a-primitive',
            beatId: 'scale-a',
            targetComponentId: 'prompt-shell',
            kind: 'scale',
            property: 'scale',
            startMs: 300,
            endMs: 1500,
            fromValue: 0.2,
            toValue: 1.0,
          ),
          ReFusionMotionDirectorPrimitive(
            id: 'scale-b-primitive',
            beatId: 'scale-b',
            targetComponentId: 'prompt-shell',
            kind: 'scale',
            property: 'scale',
            startMs: 1400,
            endMs: 2200,
            fromValue: 1.0,
            toValue: 0.8,
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('overlaps beat `scale-a`'),
      ),
      isNotEmpty,
    );
  });

  test('warns and accepts typewriter primitives with omitted range values', () {
    final result = linter.lint(
      promptBarPlan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'text-type-on',
            beatId: 'typing',
            targetComponentId: 'prompt-text',
            kind: 'typewriter',
            property: 'typewriterProgress',
            startMs: 520,
            endMs: 1900,
            easing: 'linear',
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('default to 0.0 -> 1.0'),
      ),
      isNotEmpty,
    );
  });

  test('rejects primitives outside their owning beat or unknown targets', () {
    final result = linter.lint(
      promptBarPlan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'bad-primitive',
            beatId: 'typing',
            targetComponentId: 'missing-text',
            kind: 'opacity',
            property: 'opacity',
            startMs: 400,
            endMs: 2100,
            fromValue: 0.0,
            toValue: 1.0,
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('targets unknown component'),
      ),
      isNotEmpty,
    );
    expect(
      result.issues.where(
        (issue) => issue.message.contains('inside its owning beat'),
      ),
      isNotEmpty,
    );
  });

  test('rejects backward typewriter primitives', () {
    final result = linter.lint(
      promptBarPlan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'delete-effect',
            beatId: 'typing',
            targetComponentId: 'prompt-text',
            kind: 'typewriter',
            property: 'typewriterProgress',
            startMs: 600,
            endMs: 1600,
            fromValue: 1.0,
            toValue: 0.0,
            easing: 'linear',
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('runs backward'),
      ),
      isNotEmpty,
    );
  });
}
