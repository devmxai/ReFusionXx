import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_program_component_contract.dart';

void main() {
  const validator = SceneProgramComponentContractValidator();

  ReFusionSceneProgram buildPromptProgram({
    required Map<String, Object?> shellProperties,
    required Map<String, Object?> textProperties,
    required String text,
  }) {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Prompt Contract Test',
      durationMs: 3000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'prompt-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: 3000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'prompt-shell',
              kind: 'shape',
              properties: shellProperties,
            ),
            ReFusionSceneProgramElement(
              id: 'prompt-text',
              kind: 'text',
              text: text,
              properties: textProperties,
            ),
            ReFusionSceneProgramElement(
              id: 'send-button',
              kind: 'shape',
              properties: const <String, Object?>{
                'position': <String, Object?>{'x': 355, 'y': -40},
                'width': 76,
                'height': 76,
              },
            ),
          ],
        ),
      ],
    );
  }

  test('rejects PromptInputBar text without parent and textFrame contract', () {
    final result = validator.validate(
      buildPromptProgram(
        shellProperties: const <String, Object?>{
          'shapeKind': 'roundedRectangle',
          'position': <String, Object?>{'x': 0, 'y': -40},
          'width': 860,
          'height': 118,
        },
        textProperties: const <String, Object?>{
          'position': <String, Object?>{'x': -135, 'y': -28},
          'fontSize': 38,
          'textAlign': 'left',
        },
        text: 'generate new offer for my business',
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('parentId'),
      ),
      isNotEmpty,
    );
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('textFrame'),
      ),
      isNotEmpty,
    );
  });

  test('accepts PromptInputBar text with parent, textFrame, and safe geometry',
      () {
    final result = validator.validate(
      buildPromptProgram(
        shellProperties: const <String, Object?>{
          'layoutRole': 'container',
          'shapeKind': 'roundedRectangle',
          'position': <String, Object?>{'x': 0, 'y': -40},
          'width': 860,
          'height': 118,
          'contentInsets': <String, Object?>{
            'left': 44,
            'right': 124,
            'top': 16,
            'bottom': 16,
          },
        },
        textProperties: const <String, Object?>{
          'parentId': 'prompt-shell',
          'layout': <String, Object?>{
            'slot': 'primaryText',
            'maxWidth': 680,
            'maxLines': 1,
            'overflow': 'clip',
          },
          'textFrame': <String, Object?>{
            'width': 680,
            'height': 60,
            'maxLines': 1,
            'overflow': 'clip',
          },
          'position': <String, Object?>{'x': -76, 'y': -40},
          'fontSize': 32,
          'textAlign': 'left',
        },
        text: 'generate new offer for my business',
      ),
    );

    expect(
      result.issues.where(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      ),
      isEmpty,
    );
    expect(result.isValid, isTrue);
  });

  test('emits geometry and text-fit diagnostics for PromptInputBar', () {
    final result = validator.validate(
      buildPromptProgram(
        shellProperties: const <String, Object?>{
          'layoutRole': 'container',
          'shapeKind': 'roundedRectangle',
          'position': <String, Object?>{'x': 0, 'y': -40},
          'width': 860,
          'height': 118,
          'contentInsets': <String, Object?>{
            'left': 44,
            'right': 124,
            'top': 16,
            'bottom': 16,
          },
        },
        textProperties: const <String, Object?>{
          'parentId': 'prompt-shell',
          'textFrame': <String, Object?>{
            'width': 680,
            'height': 60,
            'maxLines': 1,
            'overflow': 'clip',
          },
          'position': <String, Object?>{'x': -76, 'y': -40},
          'fontSize': 32,
          'textAlign': 'left',
        },
        text: 'generate new offer for my business',
      ),
    );

    expect(
      result.issues.where(
        (issue) => issue.message.contains('TF_SCENE_LAYOUT_GEOMETRY_PROOF'),
      ),
      isNotEmpty,
    );
    expect(
      result.issues.where(
        (issue) => issue.message.contains('TF_SCENE_TEXT_FIT_PROOF'),
      ),
      isNotEmpty,
    );
  });
}
