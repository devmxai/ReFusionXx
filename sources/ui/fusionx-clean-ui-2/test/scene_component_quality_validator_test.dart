import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_component_quality_validator.dart';

void main() {
  const validator = SceneComponentQualityValidator();

  ReFusionSceneProgram _professionalPromptProgram({
    required bool componentAuthored,
    bool includeFadeOnlyChildren = false,
    bool incoherentExit = false,
    bool canvasSizedShell = false,
    bool missingPromptIcons = false,
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
          'width': canvasSizedShell ? 1080.0 : 820.0,
          'height': canvasSizedShell ? 640.0 : 112.0,
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
      required String iconName,
    }) {
      return ReFusionSceneProgramElement(
        id: id,
        kind: 'icon',
        properties: <String, Object?>{
          'parentId': 'prompt-shell',
          'position': <String, Object?>{'x': x, 'y': 0.0},
          'width': 34.0,
          'height': 34.0,
          'icon': iconName,
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
              iconName: 'plus',
            ),
            if (!missingPromptIcons)
              icon(
                id: 'prompt-mic-icon',
                x: 256.0,
                layerDurationMs: iconLayerDuration,
                iconName: 'mic',
              ),
            if (!missingPromptIcons)
              icon(
                id: 'prompt-voice-icon',
                x: 344.0,
                layerDurationMs: iconLayerDuration,
                iconName: 'volume',
              ),
          ],
        ),
      ],
    );
  }

  ReFusionSceneProgram _featureCardsSiblingProgram({
    required bool repeatedMotion,
  }) {
    ReFusionSceneProgramLayer cardLayer({
      required String id,
      required double x,
      required List<ReFusionSceneProgramChannel> channels,
    }) {
      return ReFusionSceneProgramLayer(
        id: 'layer-$id',
        kind: 'shape',
        startMs: 0,
        durationMs: 1600,
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'shell-$id',
            kind: 'shape',
            properties: <String, Object?>{
              'componentType': 'FeatureCard',
              'componentId': id,
              'layoutRole': 'container',
              'position': <String, Object?>{'x': x, 'y': 0.0},
              'width': 360.0,
              'height': 180.0,
              'professionalStrict': true,
            },
            channels: channels,
          ),
        ],
      );
    }

    List<ReFusionSceneProgramChannel> fadeOnly() {
      return <ReFusionSceneProgramChannel>[
        ReFusionSceneProgramChannel(
          target: 'self',
          property: 'opacity',
          keyframes: const <ReFusionSceneProgramKeyframe>[
            ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
            ReFusionSceneProgramKeyframe(timeMs: 420, value: 1.0),
          ],
        ),
      ];
    }

    List<ReFusionSceneProgramChannel> slide() {
      return <ReFusionSceneProgramChannel>[
        ReFusionSceneProgramChannel(
          target: 'self',
          property: 'position.x',
          keyframes: const <ReFusionSceneProgramKeyframe>[
            ReFusionSceneProgramKeyframe(timeMs: 0, value: -80.0),
            ReFusionSceneProgramKeyframe(timeMs: 420, value: 0.0),
          ],
        ),
        ReFusionSceneProgramChannel(
          target: 'self',
          property: 'opacity',
          keyframes: const <ReFusionSceneProgramKeyframe>[
            ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
            ReFusionSceneProgramKeyframe(timeMs: 420, value: 1.0),
          ],
        ),
      ];
    }

    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: repeatedMotion
          ? 'Professional FeatureCard Repeated'
          : 'Professional FeatureCard Varied',
      durationMs: 1800,
      frameRate: 30.0,
      layers: <ReFusionSceneProgramLayer>[
        cardLayer(id: 'fc-1', x: -260.0, channels: fadeOnly()),
        cardLayer(id: 'fc-2', x: -80.0, channels: fadeOnly()),
        cardLayer(
          id: 'fc-3',
          x: 100.0,
          channels: repeatedMotion ? fadeOnly() : slide(),
        ),
        cardLayer(
          id: 'fc-4',
          x: 280.0,
          channels: repeatedMotion ? fadeOnly() : slide(),
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
              'COMPONENT_QA::PROMPT_BAR_SPLIT_SHELL_FRAME',
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

  test('rejects sibling components that over-repeat one motion signature', () {
    final result = validator.validate(
      _featureCardsSiblingProgram(repeatedMotion: true),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('COMPONENT_QA::MOTION_VARIETY_LOW'),
      ),
      isTrue,
    );
  });

  test('rejects prompt shell that resolves to canvas-like size', () {
    final result = validator.validate(
      _professionalPromptProgram(
        componentAuthored: true,
        canvasSizedShell: true,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('COMPONENT_QA::COMPONENT_SIZED_AS_CANVAS'),
      ),
      isTrue,
    );
  });

  test('rejects prompt bars missing required icon contract', () {
    final result = validator.validate(
      _professionalPromptProgram(
        componentAuthored: true,
        missingPromptIcons: true,
      ),
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('COMPONENT_QA::ICON_CONTRACT_NOT_RENDERED'),
      ),
      isTrue,
    );
  });

  test('accepts sibling components when motion signatures are diverse enough',
      () {
    final result = validator.validate(
      _featureCardsSiblingProgram(repeatedMotion: false),
    );

    final varietyErrors = result.issues.where(
      (issue) =>
          issue.severity == ReFusionSceneProgramIssueSeverity.error &&
          issue.message.contains('COMPONENT_QA::MOTION_VARIETY_LOW'),
    );
    expect(varietyErrors, isEmpty,
        reason: varietyErrors.map((issue) => issue.message).join('\n'));
  });
}
