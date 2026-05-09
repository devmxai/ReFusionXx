import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_brand_asset_manifest.dart';
import 'package:refusion_app/features/editor/domain/services/scene_brand_asset_pipeline.dart';
import 'package:refusion_app/features/editor/domain/services/scene_brand_asset_policy.dart';
import 'package:refusion_app/features/editor/domain/services/scene_icon_token.dart';

void main() {
  test('detects manifest hash mismatch', () {
    final entry = SceneBrandAssetManifestEntry(
      brandId: r'$brand.test',
      sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
      licenseStatus: SceneBrandLicenseStatus.allowed,
      fallbackIconToken: r'$icon.brandFallback',
      source: 'unit-test',
      usageNotes: 'hash mismatch test',
      declaredHash: 'deadbeef',
      iconAssetPath: 'assets/brands/test/icon.svg',
    );
    final pipeline = SceneBrandAssetPipeline(
      manifest: SceneBrandAssetManifest(
          entries: <SceneBrandAssetManifestEntry>[entry]),
    );
    const token = SceneBrandToken(
      id: r'$brand.test',
      displayName: 'Test',
      category: 'test',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'allowed',
      allowedInGeneratedScenes: true,
    );
    const policy = SceneBrandAssetPolicy(
      allowUnlicensedBrandInGeneratedScenes: true,
    );

    final resolution = pipeline.resolve(
      brandToken: token,
      policy: policy,
    );

    expect(
      resolution.issues.any((issue) => issue.message.contains('hash mismatch')),
      isTrue,
    );
  });

  test('rejects color override when manifest does not allow it', () {
    final seed = SceneBrandAssetManifestEntry(
      brandId: r'$brand.test',
      sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
      licenseStatus: SceneBrandLicenseStatus.allowed,
      fallbackIconToken: r'$icon.brandFallback',
      source: 'unit-test',
      usageNotes: 'color override test',
      declaredHash: 'pending',
      iconAssetPath: 'assets/brands/test/icon.svg',
      allowColorOverride: false,
    );
    final entry = SceneBrandAssetManifestEntry(
      brandId: seed.brandId,
      sourceKind: seed.sourceKind,
      licenseStatus: seed.licenseStatus,
      fallbackIconToken: seed.fallbackIconToken,
      source: seed.source,
      usageNotes: seed.usageNotes,
      declaredHash: seed.canonicalHash(),
      iconAssetPath: seed.iconAssetPath,
      allowColorOverride: seed.allowColorOverride,
    );
    final pipeline = SceneBrandAssetPipeline(
      manifest: SceneBrandAssetManifest(
          entries: <SceneBrandAssetManifestEntry>[entry]),
    );
    const token = SceneBrandToken(
      id: r'$brand.test',
      displayName: 'Test',
      category: 'test',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'allowed',
      allowedInGeneratedScenes: true,
    );

    final resolution = pipeline.resolve(
      brandToken: token,
      policy: const SceneBrandAssetPolicy(
        allowUnlicensedBrandInGeneratedScenes: true,
      ),
      colorOverrideHex: '#FF00FF',
    );

    expect(
      resolution.issues.any((issue) => issue.message.contains('not allowed')),
      isTrue,
    );
  });

  test('uses semantic fallback for unknown license when policy is strict', () {
    final pipeline = SceneBrandAssetPipeline();
    const token = SceneBrandToken(
      id: r'$brand.chatgpt',
      displayName: 'ChatGPT',
      category: 'ai',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'unknown',
      allowedInGeneratedScenes: true,
    );

    final resolution = pipeline.resolve(
      brandToken: token,
      policy: const SceneBrandAssetPolicy(),
    );

    expect(resolution.shouldFallback, isTrue);
    expect(
      resolution.issues
          .any((issue) => issue.message.contains(kSceneBrandAssetProofTag)),
      isTrue,
    );
  });

  test('accepts user provided brand asset source', () {
    final pipeline = SceneBrandAssetPipeline();
    const token = SceneBrandToken(
      id: r'$brand.figma',
      displayName: 'Figma',
      category: 'productivity',
      fallbackIconToken: r'$icon.presentation',
      licenseStatus: 'userMustProvide',
      allowedInGeneratedScenes: true,
    );

    final resolution = pipeline.resolve(
      brandToken: token,
      policy: const SceneBrandAssetPolicy(),
      userProvidedAsset: const SceneBrandUserProvidedAsset(
        assetPath: '/tmp/user/figma.svg',
        source: 'user upload',
        usageNotes: 'campaign rights owned by user',
      ),
    );

    expect(resolution.sourceKind, SceneBrandAssetSourceKind.userProvided);
    expect(resolution.shouldFallback, isFalse);
    expect(resolution.resolvedAssetPath, '/tmp/user/figma.svg');
  });
}
