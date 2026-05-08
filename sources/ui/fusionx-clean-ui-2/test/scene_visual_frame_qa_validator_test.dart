import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_visual_frame_qa_validator.dart';

void main() {
  const validator = SceneVisualFrameQaValidator();

  test('emits frame probe proof for reveal channels', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'QA probes',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'prompt-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 2400,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'prompt-text',
                kind: 'text',
                text: 'generate new offer for my business',
                properties: const <String, Object?>{
                  'fontSize': 32,
                  'textFrame': <String, Object?>{
                    'width': 520,
                    'height': 56,
                    'maxLines': 1,
                    'overflow': 'clip',
                    'fitPolicy': 'shrinkToFit',
                  },
                },
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'prompt-text',
                property: 'typewriterProgress',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 200, value: 0.0),
                  ReFusionSceneProgramKeyframe(timeMs: 1300, value: 1.0),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.any(
        (issue) => issue.message.contains('TF_SCENE_VISUAL_FRAME_QA_PROOF'),
      ),
      isTrue,
    );
  });

  test('errors when reveal text overflows with no supported fit policy', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'QA overflow',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'prompt-layer',
            kind: 'text',
            startMs: 0,
            durationMs: 2400,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'prompt-text',
                kind: 'text',
                text: 'generate new offer for my business with weekly promos',
                properties: const <String, Object?>{
                  'fontSize': 40,
                  'textFrame': <String, Object?>{
                    'width': 300,
                    'maxLines': 1,
                    'overflow': 'clip',
                    'fitPolicy': 'none',
                  },
                },
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'prompt-text',
                property: 'typewriterProgress',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 200, value: 0.0),
                  ReFusionSceneProgramKeyframe(timeMs: 1300, value: 1.0),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('bounded frame overflow detected'),
      ),
      isTrue,
    );
  });

  test('checks static bounded text overflow without reveal channel', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'QA static overflow',
        durationMs: 2400,
        frameRate: 30,
        layers: <ReFusionSceneProgramLayer>[
          ReFusionSceneProgramLayer(
            id: 'card-layer',
            kind: 'shape',
            startMs: 0,
            durationMs: 2400,
            elements: <ReFusionSceneProgramElement>[
              ReFusionSceneProgramElement(
                id: 'feedback-body',
                kind: 'text',
                text:
                    'Very long static text body that should trigger bounded overflow checks in visual QA.',
                properties: const <String, Object?>{
                  'fontSize': 32,
                  'lineHeight': 1.2,
                  'textFrame': <String, Object?>{
                    'width': 260,
                    'height': 64,
                    'maxLines': 1,
                    'overflow': 'ellipsis',
                    'fitPolicy': 'none',
                  },
                },
              ),
            ],
          ),
        ],
      ),
    );

    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('static bounded frame overflow detected'),
      ),
      isTrue,
    );
  });
}
