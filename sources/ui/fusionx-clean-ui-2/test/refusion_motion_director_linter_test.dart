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
              id: 'send',
              label: 'Send press and cover',
              startMs: 1900,
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
              startMs: 1960,
              endMs: 2140,
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
              startMs: 2300,
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

  test('rejects overlapping beats because the choreography is ambiguous', () {
    final result = linter.lint(
      promptBarPlan(
        beats: <ReFusionMotionDirectorBeat>[
          ReFusionMotionDirectorBeat(
            id: 'enter',
            label: 'Enter',
            startMs: 0,
            endMs: 1000,
            intent: 'Enter.',
          ),
          ReFusionMotionDirectorBeat(
            id: 'typing',
            label: 'Typing',
            startMs: 800,
            endMs: 1600,
            intent: 'Type.',
          ),
        ],
        primitives: const <ReFusionMotionDirectorPrimitive>[],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('overlaps the previous beat'),
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
