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
                    'maxLines': 1,
                    'overflow': 'clip',
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

  test('warns when reveal text likely overflows fixed frame', () {
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
            issue.severity == ReFusionSceneProgramIssueSeverity.warning &&
            issue.message.contains('may overflow'),
      ),
      isTrue,
    );
  });
}
