import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_brand_asset_policy.dart';
import 'package:refusion_app/features/editor/domain/services/scene_icon_registry.dart';

void main() {
  test('resolves semantic icon token directly', () {
    const registry = SceneIconRegistry();
    final icon = registry.findIconToken(r'$icon.audioEngineering');
    expect(icon, isNotNull);
    expect(icon!.iconName, 'mic');
  });

  test('fails closed on unknown brand token by default', () {
    const registry = SceneIconRegistry();
    final resolution = registry.resolveBrand(r'$brand.unknown');
    expect(resolution.isValid, isFalse);
    expect(
      resolution.issues
          .any((issue) => issue.message.contains('not in the registry')),
      isTrue,
    );
  });

  test('known brand falls back to semantic icon when legal state is pending',
      () {
    const registry = SceneIconRegistry();
    final resolution = registry.resolveBrand(r'$brand.chatgpt');
    expect(resolution.brandToken, isNotNull);
    expect(resolution.fallbackIconToken, isNotNull);
    expect(
      resolution.issues
          .any((issue) => issue.message.contains(kSceneBrandRegistryProofTag)),
      isTrue,
    );
    expect(
      resolution.issues
          .any((issue) => issue.message.contains('semantic fallback')),
      isTrue,
    );
  });

  test('policy can allow unknown brand as warning path', () {
    const registry = SceneIconRegistry(
      brandPolicy: SceneBrandAssetPolicy(
        failOnUnknownBrand: false,
      ),
    );
    final resolution = registry.resolveBrand(r'$brand.unknown');
    expect(resolution.isValid, isTrue);
    expect(
      resolution.issues
          .any((issue) => issue.message.contains('unknown; fallback semantic')),
      isTrue,
    );
  });
}
