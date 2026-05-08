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

  test('fails closed when raw numbers are present and override is disabled',
      () {
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
    expect(result.hctHash, isNotNull);
    expect(result.sceneProgramHash, isNotNull);
    expect(result.runtimeTree, isNotNull);
    expect(result.sourceMaps, isNotNull);
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains(kSceneDeterminismProofTag) &&
            issue.message.contains('deterministic=true') &&
            issue.message.contains('tokenResolutionHash=') &&
            issue.message.contains('traversalHash=') &&
            issue.message.contains('geometryProbeHashes=') &&
            issue.message.contains('drift=') &&
            issue.message.contains('passed=true'),
      ),
      isTrue,
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains(kSceneHctBlueprintCompilerProofTag) &&
            issue.message.contains('runtimeNodes='),
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
      expect(result.sceneProgramHash, isNotNull,
          reason: 'compile index=$index');
      expect(result.hctHash, isNotNull, reason: 'compile index=$index');
      baselineHash ??= result.sceneProgramHash;
      expect(
        result.sceneProgramHash,
        equals(baselineHash),
        reason: 'sceneProgram hash changed at compile index=$index',
      );
    }
  });

  test('compiles prompt input bar to runtime tree with slot and leaf nodes',
      () {
    final result = compiler.compile(
      payload: buildPayload(),
      allowRawValueOverride: true,
      determinismIterations: 2,
    );

    expect(result.isValid, isTrue);
    final tree = result.runtimeTree;
    expect(tree, isNotNull);
    final nodeIds = tree!.nodeById.keys.toSet();
    expect(nodeIds.contains('__scene_root__'), isTrue);
    expect(nodeIds.contains('prompt'), isTrue);
    expect(nodeIds.contains('prompt::slot::primaryText'), isTrue);
    expect(nodeIds.contains('prompt::slot::trailingAccessory'), isTrue);
    expect(nodeIds.contains('prompt::slot::primaryText::leaf'), isTrue);
    expect(nodeIds.contains('prompt::slot::trailingAccessory::leaf'), isTrue);
    expect(tree.parentOf['prompt'], startsWith('__beat__'));
    expect(tree.parentOf['prompt::slot::primaryText'], 'prompt');
    expect(
      tree.parentOf['prompt::slot::primaryText::leaf'],
      'prompt::slot::primaryText',
    );
  });

  test('builds source maps from blueprint ids to runtime nodes and layers', () {
    final result = compiler.compile(
      payload: buildPayload(),
      allowRawValueOverride: true,
      determinismIterations: 2,
    );

    expect(result.isValid, isTrue);
    final maps = result.sourceMaps!;
    final runtimeNodes = maps.runtimeNodeIdsByComponentId['prompt'];
    expect(runtimeNodes, isNotNull);
    expect(runtimeNodes!.contains('prompt'), isTrue);
    expect(runtimeNodes.contains('prompt::slot::primaryText'), isTrue);
    expect(
        maps.runtimeNodeToComponentId['prompt::slot::primaryText'], 'prompt');
    expect(maps.runtimeNodeToLayerId['prompt'], 'prompt-layer');
    expect(
      maps.runtimeNodeToLayerId['prompt::slot::primaryText::leaf'],
      'prompt-layer',
    );
  });
}
