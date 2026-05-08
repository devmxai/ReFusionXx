import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_blueprint_compiler.dart';

void main() {
  final compiler = SceneSemanticBlueprintCompiler();

  Map<String, Object?> buildPayload() {
    return <String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'name': 'Deterministic Prompt',
      'durationMs': 2600,
      'frameRate': 30,
      'metadata': <String, Object?>{
        'canvasProfile': 'story_9_16',
      },
      'components': <Object?>[
        <String, Object?>{
          'id': 'prompt',
          'type': 'PromptInputBar',
          'variant': 'focused',
          'properties': <String, Object?>{
            'promptText': 'generate a premium campaign',
            'anchor': r'$anchor.goldenTop',
            'width': r'$spacing.3xl',
            'height': r'$spacing.2xl',
            'fontSize': r'$spacing.lg',
            'lineHeight': 1.0,
          },
          'slots': <String, Object?>{
            'primaryText': <String, Object?>{
              'text': 'generate a premium campaign',
              'textFrame': <String, Object?>{
                'width': r'$spacing.3xl',
                'height': r'$spacing.xl',
                'maxLines': 1,
                'overflow': 'ellipsis',
                'fitPolicy': 'shrinkToFit',
              },
            },
            'trailingAccessory': 'send',
          },
          'motionIntents': <String, Object?>{
            'enter': <String, Object?>{
              'easing': r'$easing.slowFastSlow',
            },
          },
        },
      ],
      'beats': <Object?>[
        <String, Object?>{
          'id': 'intro',
          'startMs': 0,
          'endMs': 1200,
          'intent': 'prompt text enter',
          'componentRefs': <String>['prompt'],
        },
      ],
    };
  }

  test('fails closed when raw numbers are present and override is disabled', () {
    final result = compiler.compile(
      payload: buildPayload(),
      allowRawValueOverride: false,
      determinismIterations: 2,
    );
    expect(result.isValid, isFalse);
    expect(
      result.issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('Raw numeric values detected'),
      ),
      isTrue,
    );
  });

  test('allows raw value override and emits determinism proof', () {
    final result = compiler.compile(
      payload: buildPayload(),
      allowRawValueOverride: true,
      determinismIterations: 2,
    );
    expect(result.isValid, isTrue);
    expect(result.blueprintHash, isNotNull);
    expect(result.sceneProgramHash, isNotNull);
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains(kSceneDeterminismProofTag) &&
            issue.message.contains('deterministic=true') &&
            issue.message.contains('tokenResolutionHash=') &&
            issue.message.contains('passed=true'),
      ),
      isTrue,
    );
  });

  test('returns stable sceneProgram hash across 100 repeated compiles', () {
    String? baselineHash;
    for (var index = 0; index < 100; index += 1) {
      final result = compiler.compile(
        payload: buildPayload(),
        allowRawValueOverride: true,
        determinismIterations: 3,
      );
      expect(result.isValid, isTrue, reason: 'compile index=$index');
      expect(result.sceneProgramHash, isNotNull, reason: 'compile index=$index');
      baselineHash ??= result.sceneProgramHash;
      expect(
        result.sceneProgramHash,
        equals(baselineHash),
        reason: 'sceneProgram hash changed at compile index=$index',
      );
    }
  });
}
