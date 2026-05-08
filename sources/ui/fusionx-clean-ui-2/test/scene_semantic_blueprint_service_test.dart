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
}
