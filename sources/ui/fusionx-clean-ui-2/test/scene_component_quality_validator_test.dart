import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_component_quality_validator.dart';

void main() {
  const validator = SceneComponentQualityValidator();

  ReFusionSceneProgram _professionalPromptProgram({
    required bool componentAuthored,
    bool includeFadeOnlyChildren = false,
    bool incoherentExit = false,
  }) {
    ReFusionSceneProgramElement shell({
      required double borderWidth,
      required int layerDurationMs,
    }) {
      return ReFusionSceneProgramElement(
        id: 'prompt-shell',
        kind: 'shape',
        properties: <String, Object?>{
          'position': const <String, Object?>{'x': 0.0, 'y': 320.0},
          'width': 820.0,
          'height': 112.0,
          'layoutRole': 'container',
          'shapeKind': 'roundedRectangle',
          'borderWidth': borderWidth,
          if (componentAuthored) 'componentType': 'PromptInputBar',
          if (componentAuthored) 'componentId': 'prompt-input-1',
        },
        channels: includeFadeOnlyChildren
            ? <ReFusionSceneProgramChannel>[
                ReFusionSceneProgramChannel(
                  target: 'self',
                  property: 'opacity',
                  keyframes: const <ReFusionSceneProgramKeyframe>[
                    ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
                    ReFusionSceneProgramKeyframe(timeMs: 400, value: 1.0),
                  ],
                ),
              ]
            : const <ReFusionSceneProgramChannel>[],
      );
    }

    ReFusionSceneProgramElement text({
      required String id,
      required String textValue,
      required int layerDurationMs,
    }) {
      return ReFusionSceneProgramElement(
        id: id,
        kind: 'text',
        text: textValue,
        properties: <String, Object?>{
          'parentId': 'prompt-shell',
          'position': const <String, Object?>{'x': -90.0, 'y': 0.0},
          'fontSize': 30.0,
          'fontWeight': 400.0,
          'layoutRole': 'content',
          'slotId': 'primaryText',
          'textFrame': const <String, Object?>{
            'width': 420.0,
            'height': 56.0,
            'maxLines': 1,
            'fitPolicy': 'shrinkToFit',
          },
          if (componentAuthored) 'componentType': 'PromptInputBar',
          if (componentAuthored) 'componentId': 'prompt-input-1',
        },
        channels: includeFadeOnlyChildren
            ? <ReFusionSceneProgramChannel>[
                ReFusionSceneProgramChannel(
                  target: 'self',
                  property: 'opacity',
                  keyframes: const <ReFusionSceneProgramKeyframe>[
                    ReFusionSceneProgramKeyframe(timeMs: 80, value: 0.0),
                    ReFusionSceneProgramKeyframe(timeMs: 480, value: 1.0),
                  ],
                ),
              ]
            : const <ReFusionSceneProgramChannel>[],
      );
    }

    ReFusionSceneProgramElement icon({
      required String id,
      required double x,
      required int layerDurationMs,
    }) {
      return ReFusionSceneProgramElement(
        id: id,
        kind: 'icon',
        properties: <String, Object?>{
          'parentId': 'prompt-shell',
          'position': <String, Object?>{'x': x, 'y': 0.0},
          'width': 34.0,
          'height': 34.0,
          'layoutRole': 'accessory',
          if (componentAuthored) 'componentType': 'PromptInputBar',
          if (componentAuthored) 'componentId': 'prompt-input-1',
        },
        channels: includeFadeOnlyChildren
            ? <ReFusionSceneProgramChannel>[
                ReFusionSceneProgramChannel(
                  target: 'self',
                  property: 'opacity',
                  keyframes: const <ReFusionSceneProgramKeyframe>[
                    ReFusionSceneProgramKeyframe(timeMs: 120, value: 0.0),
                    ReFusionSceneProgramKeyframe(timeMs: 520, value: 1.0),
                  ],
                ),
              ]
            : const <ReFusionSceneProgramChannel>[],
      );
    }

    final shellLayerDuration = 2300;
    final textLayerDuration = incoherentExit ? 1800 : 2300;
    final iconLayerDuration = incoherentExit ? 1500 : 2300;

    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: componentAuthored
          ? 'Professional Prompt Authored'
          : 'Professional Prompt Raw',
      durationMs: 2500,
      frameRate: 30.0,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'prompt-shell-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: shellLayerDuration,
          elements: <ReFusionSceneProgramElement>[
            shell(
              borderWidth: componentAuthored ? 1.2 : 0.0,
              layerDurationMs: shellLayerDuration,
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'prompt-text-layer',
          kind: 'text',
          startMs: 0,
          durationMs: textLayerDuration,
          elements: <ReFusionSceneProgramElement>[
            text(
              id: 'prompt-text',
              textValue: 'Our fastest motion',
              layerDurationMs: textLayerDuration,
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'prompt-icons-layer',
          kind: 'icon',
          startMs: 0,
          durationMs: iconLayerDuration,
          elements: <ReFusionSceneProgramElement>[
            icon(
              id: 'prompt-plus-icon',
              x: -338.0,
              layerDurationMs: iconLayerDuration,
            ),
            icon(
              id: 'prompt-mic-icon',
              x: 256.0,
              layerDurationMs: iconLayerDuration,
            ),
            icon(
              id: 'prompt-voice-icon',
              x: 344.0,
              layerDurationMs: iconLayerDuration,
            ),
          ],
        ),
      ],
    );
  }

  test('rejects raw-layer professional prompt bars', () {
    final result = validator.validate(
      _professionalPromptProgram(componentAuthored: false),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains(
              'COMPONENT_QA::RAW_LAYER_USED_WHERE_COMPONENT_EXISTS',
            ),
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('repair='),
      ),
      isTrue,
    );
  });

  test('accepts component-authored professional prompt bars', () {
    final result = validator.validate(
      _professionalPromptProgram(componentAuthored: true),
    );

    final componentErrors = result.issues.where(
      (issue) =>
          issue.severity == ReFusionSceneProgramIssueSeverity.error &&
          issue.message.contains('COMPONENT_QA::'),
    );
    expect(
      componentErrors,
      isEmpty,
      reason: componentErrors.map((issue) => issue.message).join('\n'),
    );
    expect(result.isValid, isTrue);
  });

  test('rejects repeated fade-only component motion', () {
    final result = validator.validate(
      _professionalPromptProgram(
        componentAuthored: true,
        includeFadeOnlyChildren: true,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains(
              'COMPONENT_QA::REPEATED_UNCOORDINATED_FADES',
            ),
      ),
      isTrue,
    );
  });

  test('rejects incoherent component group exits', () {
    final result = validator.validate(
      _professionalPromptProgram(
        componentAuthored: true,
        incoherentExit: true,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('COMPONENT_QA::GROUP_EXIT_INCOHERENT'),
      ),
      isTrue,
    );
  });
}
