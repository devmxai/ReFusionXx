import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/design_token_resolver.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_token_registry.dart';

void main() {
  test('resolves canonical type and spacing scales for story profile', () {
    const resolver = DesignTokenResolver();
    final result = resolver.resolveRoot(canvasProfile: 'story_9_16');

    final typography = result.root['typography'] as Map<String, Object?>;
    final spacing = result.root['spacing'] as Map<String, Object?>;
    final safeArea = result.root['safeArea'] as Map<String, Object?>;
    final currentSafeArea = safeArea['current'] as Map<String, Object?>;

    expect(result.proof, contains(kSceneDesignTokenResolverProofTag));
    expect(typography['caption'], <String, Object?>{
      'fontSize': 14.0,
      'fontWeight': 400,
      'lineHeight': 1.25,
    });
    expect(typography['hero'], <String, Object?>{
      'fontSize': 70.0,
      'fontWeight': 800,
      'lineHeight': 1.0,
    });
    expect(spacing['2xs'], 4.0);
    expect(spacing['4xl'], 96.0);
    expect(currentSafeArea['top'], 120.0);
    expect(currentSafeArea['bottom'], 140.0);
  });

  test('safe area current token follows canvas profile', () {
    const resolver = DesignTokenResolver();
    final result = resolver.resolveRoot(canvasProfile: 'widescreen_16_9');
    final safeArea = result.root['safeArea'] as Map<String, Object?>;
    final currentSafeArea = safeArea['current'] as Map<String, Object?>;

    expect(currentSafeArea['left'], 96.0);
    expect(currentSafeArea['right'], 96.0);
    expect(result.canvasProfile, 'widescreen_16_9');
  });

  test('scene token registry exposes new design-system groups', () {
    final registry = SceneSemanticTokenRegistry(
      canvasProfile: 'portrait_4_5',
    );
    final result = registry.resolveBlueprintValue(<String, Object?>{
      'stroke': r'$stroke.regular',
      'safeTop': r'$safeArea.current.top',
      'energy': r'$motionEnergy.balanced',
      'titleScale': r'$typography.title',
      'spacing': r'$spacing.4xl',
    });

    expect(result.isValid, isTrue,
        reason: result.errors.map((it) => it.message).join('\n'));
    final value = result.value as Map<String, Object?>;
    expect(value['stroke'], 2.0);
    expect(value['safeTop'], 96.0);
    expect(value['spacing'], 96.0);
    expect(value['titleScale'], <String, Object?>{
      'fontSize': 35.0,
      'fontWeight': 650,
      'lineHeight': 1.15,
    });
    expect(value['energy'], <String, Object?>{
      'durationMultiplier': 1.0,
      'overshoot': 0.08,
    });
  });
}
