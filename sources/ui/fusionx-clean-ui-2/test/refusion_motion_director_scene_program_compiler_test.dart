import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_motion_director_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_motion_director_scene_program_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_lowerer.dart';

void main() {
  const compiler = ReFusionMotionDirectorSceneProgramCompiler();
  const lowerer = ReFusionSceneProgramLowerer();

  ReFusionMotionDirectorPlan promptBarPlan({
    List<ReFusionMotionDirectorPrimitive>? primitives,
  }) {
    return ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: 'Director Prompt Bar',
      durationMs: 4200,
      frameRate: 30,
      components: <ReFusionMotionDirectorComponent>[
        ReFusionMotionDirectorComponent(
          id: 'background',
          role: 'background.canvas',
          label: 'Background',
          properties: const <String, Object?>{
            'color': '#070A12',
          },
        ),
        ReFusionMotionDirectorComponent(
          id: 'prompt-shell',
          role: 'promptInputBar.shell',
          label: 'Prompt shell',
          properties: const <String, Object?>{
            'position': <String, Object?>{'x': 0, 'y': 0},
          },
        ),
        ReFusionMotionDirectorComponent(
          id: 'prompt-text',
          role: 'text.typewriter',
          label: 'Typed prompt',
          properties: const <String, Object?>{
            'text': 'hello world',
            'position': <String, Object?>{'x': -74, 'y': 2},
          },
        ),
        ReFusionMotionDirectorComponent(
          id: 'send-button',
          role: 'button.send',
          label: 'Send button',
          properties: const <String, Object?>{
            'position': <String, Object?>{'x': 364, 'y': 0},
          },
        ),
        ReFusionMotionDirectorComponent(
          id: 'cover-circle',
          role: 'circle.cover',
          label: 'Cover circle',
          properties: const <String, Object?>{
            'position': <String, Object?>{'x': 364, 'y': 0},
          },
        ),
      ],
      beats: <ReFusionMotionDirectorBeat>[
        ReFusionMotionDirectorBeat(
          id: 'enter',
          label: 'Enter',
          startMs: 0,
          endMs: 520,
          intent: 'Prompt shell enters.',
          componentRefs: const <String>['prompt-shell'],
        ),
        ReFusionMotionDirectorBeat(
          id: 'typing',
          label: 'Typing',
          startMs: 520,
          endMs: 1900,
          intent: 'Text types on.',
          componentRefs: const <String>['prompt-text'],
        ),
        ReFusionMotionDirectorBeat(
          id: 'action',
          label: 'Send and cover',
          startMs: 1900,
          endMs: 4200,
          intent: 'Send button presses and circle covers the screen.',
          componentRefs: const <String>['send-button', 'cover-circle'],
        ),
      ],
      primitives: primitives ??
          const <ReFusionMotionDirectorPrimitive>[
            ReFusionMotionDirectorPrimitive(
              id: 'shell-scale',
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
              id: 'type-prompt',
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
              beatId: 'action',
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
              id: 'cover',
              beatId: 'action',
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

  test('compiles a director prompt bar plan to editable Scene Program layers',
      () {
    final result = compiler.compile(promptBarPlan());

    expect(result.isValid, isTrue);
    final program = result.program!;
    expect(program.schemaVersion, 'refusion.scene-program/v1');
    expect(program.layers, hasLength(5));
    expect(
      program.layers.map((layer) => layer.id),
      containsAll(<String>[
        'background-layer',
        'prompt-shell-layer',
        'prompt-text-layer',
        'send-button-layer',
        'cover-circle-layer',
      ]),
    );

    final textLayer = program.layers.firstWhere(
      (layer) => layer.id == 'prompt-text-layer',
    );
    expect(textLayer.kind, 'text');
    expect(textLayer.elements.single.text, 'hello world');
    expect(
      textLayer.elements.single.channels.single.property,
      'typewriterProgress',
    );
    expect(
      textLayer.elements.single.channels.single.keyframes
          .map((keyframe) => keyframe.timeMs),
      <int>[520, 1900],
    );
  });

  test('compiled scene program lowers into graph channels and text bindings',
      () {
    final compileResult = compiler.compile(promptBarPlan());
    final loweringResult = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(
        program: compileResult.program!,
        projectId: 'director-project',
        sceneId: 'director-scene',
      ),
    );

    expect(loweringResult.hasErrors, isFalse);
    expect(loweringResult.project.scenes.single.layers, hasLength(5));
    expect(loweringResult.channels.length, greaterThanOrEqualTo(4));
    expect(loweringResult.textAnimationBindings, hasLength(1));
    expect(
      loweringResult.textAnimationBindings.single.elementTarget.targetId,
      'prompt-text',
    );
  });

  test('defaults omitted typewriter primitive values to type-on range', () {
    final result = compiler.compile(
      promptBarPlan(
        primitives: const <ReFusionMotionDirectorPrimitive>[
          ReFusionMotionDirectorPrimitive(
            id: 'type-prompt',
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
    final textLayer = result.program!.layers.firstWhere(
      (layer) => layer.id == 'prompt-text-layer',
    );
    final keyframes = textLayer.elements.single.channels.single.keyframes;
    expect(keyframes.map((keyframe) => keyframe.value), <Object>[0.0, 1.0]);
    expect(
      result.issues.where(
        (issue) => issue.message.contains('default to 0.0 -> 1.0'),
      ),
      isNotEmpty,
    );
  });

  test('does not compile director plans that fail linting', () {
    final badPlan = ReFusionMotionDirectorPlan(
      schemaVersion: ReFusionMotionDirectorPlan.currentSchemaVersion,
      name: 'Bad Plan',
      durationMs: 1000,
      frameRate: 30,
      components: <ReFusionMotionDirectorComponent>[
        ReFusionMotionDirectorComponent(
          id: 'title',
          role: 'text.typewriter',
          label: 'Title',
        ),
      ],
      beats: <ReFusionMotionDirectorBeat>[
        ReFusionMotionDirectorBeat(
          id: 'typing',
          label: 'Typing',
          startMs: 0,
          endMs: 1000,
          intent: 'Type.',
        ),
      ],
      primitives: const <ReFusionMotionDirectorPrimitive>[
        ReFusionMotionDirectorPrimitive(
          id: 'reverse-type',
          beatId: 'typing',
          targetComponentId: 'title',
          kind: 'typewriter',
          startMs: 0,
          endMs: 1000,
          fromValue: 1.0,
          toValue: 0.0,
        ),
      ],
    );

    final result = compiler.compile(badPlan);

    expect(result.isValid, isFalse);
    expect(result.program, isNull);
    expect(
      result.issues.where((issue) => issue.message.contains('runs backward')),
      isNotEmpty,
    );
  });
}
