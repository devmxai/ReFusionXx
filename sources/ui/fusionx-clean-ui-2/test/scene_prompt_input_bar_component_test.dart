import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_prompt_input_bar_component.dart';

void main() {
  const validator = ScenePromptInputBarComponentValidator();

  ReFusionSceneProgram buildProgram({
    required Map<String, Object?> plusProperties,
    required int sendLayerDurationMs,
    double shellWidth = 920,
    double shellHeight = 112,
  }) {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Prompt Input Bar Contract',
      durationMs: 2600,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'prompt-shell-layer',
          kind: 'shape',
          startMs: 100,
          durationMs: 1200,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'promptShell',
              kind: 'shape',
              properties: <String, Object?>{
                'layoutRole': 'container',
                'shapeKind': 'roundedRectangle',
                'position': <String, Object?>{'x': 0, 'y': 0},
                'width': shellWidth,
                'height': shellHeight,
                'borderWidth': 2.0,
                'contentInsets': <String, Object?>{
                  'left': 150,
                  'right': 220,
                  'top': 30,
                  'bottom': 30,
                },
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'prompt-plus-layer',
          kind: 'shape',
          startMs: 180,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'promptPlusIcon',
              kind: 'icon',
              properties: plusProperties,
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'prompt-mic-layer',
          kind: 'shape',
          startMs: 240,
          durationMs: 980,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'promptMicIcon',
              kind: 'icon',
              properties: <String, Object?>{
                'parentId': 'promptShell',
                'position': <String, Object?>{'x': 330, 'y': 0},
                'width': 38,
                'height': 38,
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'prompt-text-layer',
          kind: 'text',
          startMs: 260,
          durationMs: 940,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'promptText',
              kind: 'text',
              text: 'Our smartest, fastest motion studio',
              properties: <String, Object?>{
                'parentId': 'promptShell',
                'position': <String, Object?>{'x': -62, 'y': 0},
                'fontSize': 30,
                'fontWeight': 400,
                'textFrame': <String, Object?>{
                  'width': 410,
                  'height': 30,
                  'maxLines': 1,
                  'fitPolicy': 'shrinkToFit',
                },
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'prompt-send-layer',
          kind: 'shape',
          startMs: 280,
          durationMs: sendLayerDurationMs,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'sendButton',
              kind: 'shape',
              properties: <String, Object?>{
                'parentId': 'promptShell',
                'position': <String, Object?>{'x': 430, 'y': 0},
                'width': 76,
                'height': 76,
              },
            ),
            ReFusionSceneProgramElement(
              id: 'promptVoiceIcon',
              kind: 'icon',
              properties: <String, Object?>{
                'parentId': 'sendButton',
                'position': <String, Object?>{'x': 430, 'y': 0},
                'width': 36,
                'height': 36,
              },
            ),
          ],
        ),
      ],
    );
  }

  test('fails when leading plus icon is not parented to shell', () {
    final result = validator.validate(
      buildProgram(
        plusProperties: const <String, Object?>{
          'position': <String, Object?>{'x': -415, 'y': 0},
          'width': 42,
          'height': 42,
        },
        sendLayerDurationMs: 900,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('Leading plus icon must be parented'),
      ),
      isTrue,
    );
  });

  test('fails when child lifecycle exceeds shell lifecycle', () {
    final result = validator.validate(
      buildProgram(
        plusProperties: const <String, Object?>{
          'parentId': 'promptShell',
          'position': <String, Object?>{'x': -415, 'y': 0},
          'width': 42,
          'height': 42,
        },
        sendLayerDurationMs: 1400,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains(
              ScenePromptInputBarComponentValidator.lifecycleProofTag,
            ) &&
            issue.message.contains('insideShell=false'),
      ),
      isTrue,
    );
  });

  test('passes prompt hierarchy proof for valid authored program', () {
    final result = validator.validate(
      buildProgram(
        plusProperties: const <String, Object?>{
          'parentId': 'promptShell',
          'position': <String, Object?>{'x': -415, 'y': 0},
          'width': 42,
          'height': 42,
        },
        sendLayerDurationMs: 900,
      ),
    );

    expect(
      result.issues
          .where(
            (issue) =>
                issue.severity == ReFusionSceneProgramIssueSeverity.error,
          )
          .toList(),
      isEmpty,
      reason: result.issues
          .map((issue) => '${issue.severity} ${issue.path}: ${issue.message}')
          .join('\n'),
    );
    expect(
      result.issues.any(
        (issue) => issue.message.contains(
          ScenePromptInputBarComponentValidator.proofTag,
        ),
      ),
      isTrue,
    );
  });

  test('fails when shell intrinsic bounds look like canvas-sized container',
      () {
    final result = validator.validate(
      buildProgram(
        plusProperties: const <String, Object?>{
          'parentId': 'promptShell',
          'position': <String, Object?>{'x': -415, 'y': 0},
          'width': 42,
          'height': 42,
        },
        sendLayerDurationMs: 900,
        shellWidth: 1080,
        shellHeight: 1920,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('intrinsic size bounds'),
      ),
      isTrue,
    );
  });
}
