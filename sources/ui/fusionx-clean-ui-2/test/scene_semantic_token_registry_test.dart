import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_token_registry.dart';

void main() {
  test('resolves known tokens deterministically', () {
    final registry = SceneSemanticTokenRegistry();
    final result = registry.resolveToken(r'$spacing.md');

    expect(result.isValid, isTrue);
    expect(result.value, 16.0);
    expect(result.proof, contains(kSceneTokenRegistryProofTag));
    expect(result.proof, contains('errorCount=0'));
  });

  test('resolves nested tokens inside semantic blueprint payload', () {
    final registry = SceneSemanticTokenRegistry();
    final blueprint = <String, Object?>{
      'component': r'$component.PromptInputBar',
      'layout': <String, Object?>{
        'padding': r'$spacing.lg',
        'anchor': r'$anchor.goldenTop',
      },
      'textStyle': r'$typography.input',
      'timing': <String, Object?>{
        'durationMs': r'$duration.slow',
        'easing': r'$easing.slowFastSlow',
      },
      'beat': r'$beat.feature',
    };

    final result = registry.resolveBlueprintValue(blueprint);

    expect(result.isValid, isTrue,
        reason: result.errors.map((it) => it.message).join('\n'));
    final value = result.value as Map<String, Object?>;
    final layout = value['layout'] as Map<String, Object?>;
    final textStyle = value['textStyle'] as Map<String, Object?>;
    final anchor = layout['anchor'] as Map<String, Object?>;
    final beat = value['beat'] as Map<String, Object?>;

    expect(value['component'], 'PromptInputBar');
    expect(layout['padding'], 24.0);
    expect(anchor['x'], 0.0);
    expect(anchor['y'], -240.0);
    expect(textStyle['fontSize'], 32.0);
    expect(value['timing'], <String, Object?>{
      'durationMs': 860,
      'easing': 'slowFastSlow',
    });
    expect(beat['holdRatio'], 0.55);
    expect(result.proof, contains('mode=blueprint'));
    expect(result.proof, contains('errorCount=0'));
  });

  test('fails closed for unknown token path with structured error', () {
    final registry = SceneSemanticTokenRegistry();
    final result = registry.resolveBlueprintValue(<String, Object?>{
      'padding': r'$spacing.unknownValue',
      'easing': r'$easing.unknownCurve',
    });

    expect(result.isValid, isFalse);
    expect(result.errors, hasLength(2));
    expect(result.errors.first.code, 'unknown_token');
    expect(result.errors.first.path, r'$.padding');
    expect(result.proof, contains('errorCount=2'));
  });

  test('supports registry overrides without changing resolver contract', () {
    final registry = SceneSemanticTokenRegistry(
      spacing: const <String, Object?>{'md': 20.0},
      duration: const <String, Object?>{'slow': 900},
    );
    final result = registry.resolveBlueprintValue(<String, Object?>{
      'padding': r'$spacing.md',
      'durationMs': r'$duration.slow',
      'fallback': r'$spacing.lg',
    });

    expect(result.isValid, isTrue);
    final value = result.value as Map<String, Object?>;
    expect(value['padding'], 20.0);
    expect(value['durationMs'], 900);
    expect(value['fallback'], 24.0);
  });
}
