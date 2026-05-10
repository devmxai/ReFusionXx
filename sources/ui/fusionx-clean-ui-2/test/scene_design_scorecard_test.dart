import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_design_scorecard.dart';

void main() {
  const evaluator = SceneDesignScorecardEvaluator();

  test('emits design scorecard proof diagnostics', () {
    final result = evaluator.evaluate(
      _buildPromptProgram(
        name: 'Professional Prompt Scorecard',
        strict: true,
      ),
      strictProfessional: true,
    );

    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneDesignScorecardProofTag),
      ),
      isTrue,
    );
    expect(result.scorecard.overallScore, inInclusiveRange(0, 100));
  });

  test('flags multiple primary focal elements in strict mode', () {
    final result = evaluator.evaluate(
      _buildMultiplePrimaryProgram(),
      strictProfessional: true,
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message
                .contains('DESIGN_SCORECARD::MULTIPLE_PRIMARY_FOCAL_ELEMENTS'),
      ),
      isTrue,
    );
  });

  test('flags high simultaneous animation density', () {
    final result = evaluator.evaluate(
      _buildHighDensityMotionProgram(),
      strictProfessional: true,
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains(
              'DESIGN_SCORECARD::SIMULTANEOUS_ANIMATION_DENSITY_HIGH',
            ),
      ),
      isTrue,
    );
  });
}

ReFusionSceneProgram _buildPromptProgram({
  required String name,
  required bool strict,
}) {
  return ReFusionSceneProgram(
    schemaVersion: 'refusion.scene-program/v1',
    name: name,
    durationMs: 2400,
    frameRate: 30,
    layers: <ReFusionSceneProgramLayer>[
      ReFusionSceneProgramLayer(
        id: 'shell-layer',
        kind: 'shape',
        startMs: 0,
        durationMs: 2100,
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'prompt-shell',
            kind: 'shape',
            properties: <String, Object?>{
              'componentType': 'PromptInputBar',
              'componentId': 'prompt-1',
              'layoutRole': 'container',
              'position': const <String, Object?>{'x': 0.0, 'y': 160.0},
              'width': 860.0,
              'height': 118.0,
              'borderWidth': 1.2,
              if (strict) 'professionalStrict': true,
            },
            channels: <ReFusionSceneProgramChannel>[
              ReFusionSceneProgramChannel(
                target: 'self',
                property: 'position.y',
                keyframes: const <ReFusionSceneProgramKeyframe>[
                  ReFusionSceneProgramKeyframe(timeMs: 0, value: 220.0),
                  ReFusionSceneProgramKeyframe(timeMs: 420, value: 160.0),
                ],
              ),
            ],
          ),
        ],
      ),
      ReFusionSceneProgramLayer(
        id: 'text-layer',
        kind: 'text',
        startMs: 0,
        durationMs: 2100,
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'prompt-text',
            kind: 'text',
            text: 'Our smartest, fastest motion',
            properties: <String, Object?>{
              'componentType': 'PromptInputBar',
              'componentId': 'prompt-1',
              'parentId': 'prompt-shell',
              'slotId': 'primaryText',
              'layoutRole': 'content',
              'position': const <String, Object?>{'x': -80.0, 'y': 0.0},
              'fontSize': 30.0,
              'fontWeight': 400.0,
              'textFrame': const <String, Object?>{
                'width': 440.0,
                'height': 58.0,
                'maxLines': 1,
                'fitPolicy': 'shrinkToFit',
              },
              if (strict) 'professionalStrict': true,
            },
          ),
        ],
      ),
      ReFusionSceneProgramLayer(
        id: 'icon-layer',
        kind: 'icon',
        startMs: 0,
        durationMs: 2100,
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'prompt-plus',
            kind: 'icon',
            properties: <String, Object?>{
              'componentType': 'PromptInputBar',
              'componentId': 'prompt-1',
              'parentId': 'prompt-shell',
              'slotId': 'leadingIcon',
              'layoutRole': 'accessory',
              'position': const <String, Object?>{'x': -338.0, 'y': 0.0},
              'width': 34.0,
              'height': 34.0,
              if (strict) 'professionalStrict': true,
            },
          ),
          ReFusionSceneProgramElement(
            id: 'prompt-mic',
            kind: 'icon',
            properties: <String, Object?>{
              'componentType': 'PromptInputBar',
              'componentId': 'prompt-1',
              'parentId': 'prompt-shell',
              'slotId': 'trailingMic',
              'layoutRole': 'accessory',
              'position': const <String, Object?>{'x': 258.0, 'y': 0.0},
              'width': 34.0,
              'height': 34.0,
              if (strict) 'professionalStrict': true,
            },
          ),
        ],
      ),
    ],
  );
}

ReFusionSceneProgram _buildMultiplePrimaryProgram() {
  return ReFusionSceneProgram(
    schemaVersion: 'refusion.scene-program/v1',
    name: 'Professional Multiple Primary',
    durationMs: 2200,
    frameRate: 30,
    layers: <ReFusionSceneProgramLayer>[
      ReFusionSceneProgramLayer(
        id: 'title-a',
        kind: 'text',
        startMs: 0,
        durationMs: 1600,
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'headline-a',
            kind: 'text',
            text: 'Think deeper',
            properties: const <String, Object?>{
              'role': 'primary',
              'fontSize': 82.0,
              'position': <String, Object?>{'x': -120.0, 'y': -200.0},
              'professionalStrict': true,
            },
          ),
        ],
      ),
      ReFusionSceneProgramLayer(
        id: 'title-b',
        kind: 'text',
        startMs: 0,
        durationMs: 1600,
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'headline-b',
            kind: 'text',
            text: 'Think faster',
            properties: const <String, Object?>{
              'role': 'primary',
              'fontSize': 82.0,
              'position': <String, Object?>{'x': 120.0, 'y': -200.0},
              'professionalStrict': true,
            },
          ),
        ],
      ),
    ],
  );
}

ReFusionSceneProgram _buildHighDensityMotionProgram() {
  ReFusionSceneProgramLayer movingLayer({
    required String id,
    required double x,
  }) {
    return ReFusionSceneProgramLayer(
      id: 'layer-$id',
      kind: 'shape',
      startMs: 0,
      durationMs: 1600,
      elements: <ReFusionSceneProgramElement>[
        ReFusionSceneProgramElement(
          id: id,
          kind: 'shape',
          properties: <String, Object?>{
            'componentType': 'FeatureCard',
            'componentId': id,
            'layoutRole': 'container',
            'position': <String, Object?>{'x': x, 'y': 120.0},
            'width': 260.0,
            'height': 140.0,
            'professionalStrict': true,
          },
          channels: <ReFusionSceneProgramChannel>[
            ReFusionSceneProgramChannel(
              target: 'self',
              property: 'opacity',
              keyframes: const <ReFusionSceneProgramKeyframe>[
                ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
                ReFusionSceneProgramKeyframe(timeMs: 260, value: 1.0),
              ],
            ),
            ReFusionSceneProgramChannel(
              target: 'self',
              property: 'position.y',
              keyframes: const <ReFusionSceneProgramKeyframe>[
                ReFusionSceneProgramKeyframe(timeMs: 0, value: 260.0),
                ReFusionSceneProgramKeyframe(timeMs: 260, value: 120.0),
              ],
            ),
          ],
        ),
      ],
    );
  }

  return ReFusionSceneProgram(
    schemaVersion: 'refusion.scene-program/v1',
    name: 'Professional High Motion Density',
    durationMs: 2000,
    frameRate: 30,
    layers: <ReFusionSceneProgramLayer>[
      movingLayer(id: 'card-1', x: -420.0),
      movingLayer(id: 'card-2', x: -250.0),
      movingLayer(id: 'card-3', x: -80.0),
      movingLayer(id: 'card-4', x: 90.0),
      movingLayer(id: 'card-5', x: 260.0),
      movingLayer(id: 'card-6', x: 430.0),
    ],
  );
}
