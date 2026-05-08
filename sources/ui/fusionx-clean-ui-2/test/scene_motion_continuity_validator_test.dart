import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_motion_continuity_validator.dart';

void main() {
  const validator = SceneMotionContinuityValidator();

  test('warns when icon-to-prompt overlap has no continuity declaration', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Prompt continuity',
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
                id: 'app-icon',
                kind: 'shape',
              ),
              ReFusionSceneProgramElement(
                id: 'prompt-shell',
                kind: 'shape',
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'app-icon',
                property: 'opacity',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 200, value: 1.0),
                  ReFusionSceneProgramKeyframe(timeMs: 500, value: 0.0),
                ],
              ),
              ReFusionSceneProgramChannel(
                target: 'prompt-shell',
                property: 'opacity',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 300, value: 0.0),
                  ReFusionSceneProgramKeyframe(timeMs: 650, value: 1.0),
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
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.warning &&
            issue.message.contains('continuity declaration'),
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) => issue.message.contains('TF_SCENE_MOTION_CONTINUITY_PROOF'),
      ),
      isTrue,
    );
  });

  test('accepts explicit dissolve continuity declaration', () {
    final result = validator.validate(
      ReFusionSceneProgram(
        schemaVersion: 'refusion.scene-program/v1',
        name: 'Prompt continuity declared',
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
                id: 'app-icon',
                kind: 'shape',
              ),
              ReFusionSceneProgramElement(
                id: 'prompt-shell',
                kind: 'shape',
                properties: const <String, Object?>{
                  'continuity': <String, Object?>{
                    'kind': 'dissolve',
                    'sourceId': 'app-icon',
                  },
                },
              ),
            ],
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'app-icon',
                property: 'opacity',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 200, value: 1.0),
                  ReFusionSceneProgramKeyframe(timeMs: 500, value: 0.0),
                ],
              ),
              ReFusionSceneProgramChannel(
                target: 'prompt-shell',
                property: 'opacity',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 300, value: 0.0),
                  ReFusionSceneProgramKeyframe(timeMs: 650, value: 1.0),
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
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('Continuity declaration'),
      ),
      isFalse,
    );
  });
}
