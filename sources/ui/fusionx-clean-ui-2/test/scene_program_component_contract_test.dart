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
                'parentId': 'prompt-shell',
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
          'borderWidth': 2,
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
            'fitPolicy': 'shrinkToFit',
          },
          'position': <String, Object?>{'x': -76, 'y': -40},
          'fontSize': 32,
          'fontWeight': 400,
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
          'borderWidth': 2,
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
            'fitPolicy': 'shrinkToFit',
          },
          'position': <String, Object?>{'x': -76, 'y': -40},
          'fontSize': 32,
          'fontWeight': 400,
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

  test('rejects FeatureCard body text when fit policy is clip', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Feature Card Contract Test',
        durationMs: 2600,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'file-card-shell-layer',
            kind: 'shape',
            startMs: 100,
            durationMs: 1800,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'fileCardOneShell',
                kind: 'shape',
                properties: const <String, Object?>{
                  'layoutRole': 'container',
                  'componentType': 'FeatureCard',
                  'position': <String, Object?>{'x': 0, 'y': 0},
                  'width': 640,
                  'height': 180,
                },
              ),
            ],
          ),
          ReFusionSceneProgramLayer(
            id: 'file-card-title-layer',
            kind: 'text',
            startMs: 180,
            durationMs: 1720,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'fileCardOneTitle',
                kind: 'text',
                text: 'Montage',
                properties: const <String, Object?>{
                  'parentId': 'fileCardOneShell',
                  'position': <String, Object?>{'x': 90, 'y': -26},
                  'fontSize': 26,
                  'textFrame': <String, Object?>{
                    'width': 300,
                    'height': 34,
                    'maxLines': 1,
                    'fitPolicy': 'shrinkToFit',
                  },
                },
              ),
              ReFusionSceneProgramElement(
                id: 'fileCardOneStatus',
                kind: 'text',
                text: 'Retouch, grade, and',
                properties: const <String, Object?>{
                  'parentId': 'fileCardOneShell',
                  'position': <String, Object?>{'x': 90, 'y': 34},
                  'fontSize': 30,
                  'lineHeight': 1,
                  'textFrame': <String, Object?>{
                    'width': 260,
                    'height': 34,
                    'maxLines': 1,
                    'fitPolicy': 'clip',
                  },
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('FEATURE_TEXT_CLIPPED'),
      ),
      isTrue,
    );
  });

  test('rejects CTAButton label when fit policy is clip', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'CTA Contract Test',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'cta-shell-layer',
            kind: 'shape',
            startMs: 200,
            durationMs: 1600,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'availableNowPill',
                kind: 'shape',
                properties: const <String, Object?>{
                  'componentType': 'CTAButton',
                  'layoutRole': 'container',
                  'position': <String, Object?>{'x': 0, 'y': 0},
                  'width': 680,
                  'height': 150,
                },
              ),
            ],
          ),
          ReFusionSceneProgramLayer(
            id: 'cta-label-layer',
            kind: 'text',
            startMs: 280,
            durationMs: 1520,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'availableNowText',
                kind: 'text',
                text: 'Available now',
                properties: const <String, Object?>{
                  'parentId': 'availableNowPill',
                  'position': <String, Object?>{'x': -70, 'y': 0},
                  'fontSize': 58,
                  'lineHeight': 1,
                  'textFrame': <String, Object?>{
                    'width': 360,
                    'height': 62,
                    'maxLines': 1,
                    'fitPolicy': 'clip',
                  },
                },
              ),
            ],
          ),
          ReFusionSceneProgramLayer(
            id: 'cta-icon-layer',
            kind: 'shape',
            startMs: 340,
            durationMs: 1460,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'availableNowArrow',
                kind: 'icon',
                properties: const <String, Object?>{
                  'parentId': 'availableNowPill',
                  'position': <String, Object?>{'x': 225, 'y': 0},
                  'width': 54,
                  'height': 54,
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('CTA_LABEL_OVERFLOW'),
      ),
      isTrue,
    );
  });
}
