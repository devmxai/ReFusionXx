import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_blueprint_service.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_token_registry.dart';

void main() {
  test('validates blueprint schema and warns unsupported root fields', () {
    final service = SceneSemanticBlueprintService();
    final result = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Prompt Demo',
      'durationMs': 4200,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'prompt',
          'type': 'PromptInputBar',
          'properties': <String, Object?>{
            'promptText': 'generate a premium promo scene',
            'anchor': r'$anchor.goldenTop',
          },
          'slots': <String, Object?>{
            'primaryText': r'$typography.input',
            'trailingAccessory': 'send',
          },
        },
      ],
      'extraField': true,
    });

    expect(result.isValid, isTrue);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.warning &&
            issue.path == 'extraField',
      ),
      isTrue,
    );
  });

  test('lowers simple PromptInputBar blueprint to editable SceneProgram', () {
    final service = SceneSemanticBlueprintService(
      tokenRegistry: SceneSemanticTokenRegistry(
        anchors: const <String, Object?>{
          'goldenTop': <String, Object?>{'x': 12.0, 'y': -220.0},
        },
      ),
    );
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Prompt Demo',
      'durationMs': 4200,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'prompt',
          'type': 'PromptInputBar',
          'properties': <String, Object?>{
            'promptText': 'generate new offer for my business',
            'anchor': r'$anchor.goldenTop',
            'width': 840,
            'height': 108,
          },
          'slots': <String, Object?>{
            'primaryText': r'$typography.input',
            'trailingAccessory': 'send',
          },
        },
      ],
      'beats': <Object?>[
        <String, Object?>{
          'id': 'prompt-enter',
          'startMs': 0,
          'endMs': 2200,
          'intent': 'enter then type',
        },
      ],
    });
    expect(validation.isValid, isTrue);

    final lowered = service.lowerToSceneProgram(validation.blueprint!);
    expect(lowered.isValid, isTrue,
        reason: lowered.issues.map((issue) => issue.message).join('\n'));
    expect(lowered.program, isNotNull);
    expect(lowered.program!.schemaVersion, 'refusion.scene-program/v1');
    expect(lowered.program!.layers, hasLength(1));

    final layer = lowered.program!.layers.single;
    expect(layer.id, 'prompt-layer');
    expect(
        layer.elements.map((it) => it.id),
        containsAll(<String>[
          'prompt-shell',
          'prompt-text',
          'prompt-send-button',
          'prompt-send-icon',
        ]));

    final shell =
        layer.elements.firstWhere((element) => element.id == 'prompt-shell');
    final shellPosition = shell.properties['position'] as Map<String, Object?>;
    expect(shellPosition['x'], 12.0);
    expect(shellPosition['y'], -220.0);

    expect(
      lowered.issues.any(
        (issue) => issue.message.contains(kSceneBlueprintCompilerProofTag),
      ),
      isTrue,
    );
  });

  test('fails closed when component type is unsupported', () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Unsupported',
      'durationMs': 2400,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'unsupported',
          'type': 'UnknownCard',
          'slots': <String, Object?>{
            'body': 'text',
          },
        },
      ],
    });
    final lowered = service.lowerToSceneProgram(validation.blueprint!);

    expect(lowered.isValid, isFalse);
    expect(
      lowered.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('Unsupported semantic component'),
      ),
      isTrue,
    );
  });

  test('motion intent easing compiles through speedgraph truth compiler', () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'SpeedGraph Dependency Gate',
      'durationMs': 2600,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'prompt',
          'type': 'PromptInputBar',
          'motionIntents': <String, Object?>{
            'enter': <String, Object?>{
              'easing': r'$easing.slowFastSlow',
            },
          },
          'slots': <String, Object?>{
            'primaryText': r'$typography.input',
            'trailingAccessory': 'send',
          },
        },
      ],
    });
    expect(validation.isValid, isTrue);

    final lowered = service.lowerToSceneProgram(validation.blueprint!);
    expect(lowered.isValid, isTrue,
        reason: lowered.issues.map((issue) => issue.message).join('\n'));
    expect(
      lowered.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.info &&
            issue.message.contains(kSceneSpeedyGraphDependencyProofTag) &&
            issue.message.contains('canonicalPreset=slowFastSlow') &&
            issue.message.contains('routedThroughTruthCompiler=true'),
      ),
      isTrue,
    );
  });

  test('rejects direct bezier literals in semantic motion intents', () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'SpeedGraph Bypass Rejection',
      'durationMs': 2600,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'prompt',
          'type': 'PromptInputBar',
          'motionIntents': <String, Object?>{
            'enter': <String, Object?>{
              'bezier': <String, Object?>{
                'x1': 0.2,
                'y1': 0.0,
                'x2': 0.8,
                'y2': 1.0,
              },
            },
          },
          'slots': <String, Object?>{
            'primaryText': r'$typography.input',
            'trailingAccessory': 'send',
          },
        },
      ],
    });
    expect(validation.isValid, isTrue);

    final lowered = service.lowerToSceneProgram(validation.blueprint!);
    expect(lowered.isValid, isFalse);
    expect(
      lowered.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            (issue.path?.contains('components.prompt.motionIntents') ??
                false) &&
            issue.message.contains('rejected direct bezier literals'),
      ),
      isTrue,
    );
  });

  test('fails closed for unsupported PromptInputBar variant', () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Bad Variant',
      'durationMs': 2000,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'prompt',
          'type': 'PromptInputBar',
          'variant': 'hoveredGlow',
          'slots': <String, Object?>{
            'primaryText': r'$typography.input',
            'trailingAccessory': 'send',
          },
        },
      ],
    });

    expect(validation.isValid, isFalse);
    expect(
      validation.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            (issue.path?.contains('components[0].variant') ?? false) &&
            issue.message.contains('Unsupported variant'),
      ),
      isTrue,
    );
  });

  test('fails closed for unsupported PromptInputBar slot', () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Bad Slot',
      'durationMs': 2000,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'prompt',
          'type': 'PromptInputBar',
          'slots': <String, Object?>{
            'primaryText': r'$typography.input',
            'trailingAccessory': 'send',
            'randomSlot': 'not-allowed',
          },
        },
      ],
    });

    expect(validation.isValid, isFalse);
    expect(
      validation.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            (issue.path?.contains('components[0].slots.randomSlot') ?? false) &&
            issue.message.contains('is not supported'),
      ),
      isTrue,
    );
  });

  test('accepts supported PromptInputBar variants', () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Focused Prompt',
      'durationMs': 2000,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'prompt',
          'type': 'PromptInputBar',
          'variant': 'focused',
          'slots': <String, Object?>{
            'primaryText': r'$typography.input',
            'trailingAccessory': 'send',
          },
        },
      ],
    });

    expect(validation.isValid, isTrue);
    expect(
      validation.issues.any(
        (issue) => issue.message.contains('TF_SCENE_COMPONENT_REGISTRY_PROOF'),
      ),
      isTrue,
    );
  });

  test('fails closed for unsupported text fit policy', () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Bad Text Policy',
      'durationMs': 2000,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'feedback-card',
          'type': 'FeedbackCard',
          'slots': <String, Object?>{
            'leadingIcon': 'gmail',
            'title': <String, Object?>{
              'text': 'Gmail',
              'textFrame': <String, Object?>{
                'width': 220,
                'height': 48,
                'maxLines': 1,
                'overflow': 'ellipsis',
                'fitPolicy': 'autoMagic',
              },
            },
            'body': <String, Object?>{
              'text': 'This body text should fit inside the card frame.',
              'textFrame': <String, Object?>{
                'width': 420,
                'height': 160,
                'maxLines': 4,
                'overflow': 'ellipsis',
                'fitPolicy': 'wrapToLines',
              },
            },
          },
        },
      ],
    });

    expect(validation.isValid, isFalse);
    expect(
      validation.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            (issue.path?.contains('fitPolicy') ?? false) &&
            issue.message.contains('Unsupported fit policy'),
      ),
      isTrue,
    );
  });

  test('fails closed when bounded text slot misses textFrame contract', () {
    final service = SceneSemanticBlueprintService();
    final validation = service.validate(<String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Missing Text Frame',
      'durationMs': 2000,
      'frameRate': 30,
      'components': <Object?>[
        <String, Object?>{
          'id': 'feedback-card',
          'type': 'FeedbackCard',
          'slots': <String, Object?>{
            'leadingIcon': 'gmail',
            'title': 'Gmail',
            'body': 'Body text without frame should fail.',
          },
        },
      ],
    });

    expect(validation.isValid, isFalse);
    expect(
      validation.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            (issue.path?.contains('textFrame') ?? false) &&
            issue.message.contains('requires a `textFrame` contract'),
      ),
      isTrue,
    );
  });
}
