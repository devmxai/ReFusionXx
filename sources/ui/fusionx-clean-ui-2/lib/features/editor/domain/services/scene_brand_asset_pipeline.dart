import '../models/refusion_motion_director_models.dart';
import 'scene_brand_asset_manifest.dart';
import 'scene_brand_asset_policy.dart';
import 'scene_brand_asset_cache.dart';
import 'scene_icon_token.dart';

const String kSceneBrandAssetProofTag = 'TF_SCENE_BRAND_ASSET_PROOF';

class SceneBrandUserProvidedAsset {
  const SceneBrandUserProvidedAsset({
    required this.assetPath,
    required this.source,
    required this.usageNotes,
    this.wordmarkPath,
  });

  final String assetPath;
  final String source;
  final String usageNotes;
  final String? wordmarkPath;
}

class SceneBrandAssetPipelineResolution {
  const SceneBrandAssetPipelineResolution({
    required this.brandId,
    required this.shouldFallback,
    required this.fallbackIconToken,
    required this.licenseStatus,
    required this.sourceKind,
    required this.hashMatched,
    required this.allowColorOverride,
    required this.issues,
    this.resolvedAssetPath,
    this.resolvedVariant = SceneBrandAssetVariant.canonical,
  });

  final String brandId;
  final bool shouldFallback;
  final String fallbackIconToken;
  final SceneBrandLicenseStatus licenseStatus;
  final SceneBrandAssetSourceKind sourceKind;
  final bool hashMatched;
  final bool allowColorOverride;
  final String? resolvedAssetPath;
  final SceneBrandAssetVariant resolvedVariant;
  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}

class SceneBrandAssetPipeline {
  SceneBrandAssetPipeline({
    SceneBrandAssetManifest? manifest,
    SceneBrandAssetCache? cache,
  })  : _manifest = manifest ?? _buildDefaultManifest(),
        _cache = cache ?? SceneBrandAssetCache();

  final SceneBrandAssetManifest _manifest;
  final SceneBrandAssetCache _cache;

  SceneBrandAssetPipelineResolution resolve({
    required SceneBrandToken brandToken,
    required SceneBrandAssetPolicy policy,
    String? colorOverrideHex,
    SceneBrandAssetVariant variant = SceneBrandAssetVariant.canonical,
    SceneBrandUserProvidedAsset? userProvidedAsset,
  }) {
    final cacheKey = _cacheKey(
      brandId: brandToken.id,
      colorOverrideHex: colorOverrideHex,
      variant: variant,
      userProvidedAsset: userProvidedAsset,
      allowUnlicensed: policy.allowUnlicensedBrandInGeneratedScenes,
      failOnUnknownBrand: policy.failOnUnknownBrand,
    );
    final cached = _cache.read(cacheKey);
    if (cached != null) {
      return cached;
    }

    final issues = <ReFusionMotionDirectorIssue>[];
    final manifestEntry = userProvidedAsset == null
        ? _manifest.findByBrandId(brandToken.id)
        : _buildUserProvidedEntry(
            brandToken: brandToken,
            userProvidedAsset: userProvidedAsset,
          );

    if (manifestEntry == null) {
      final resolution = SceneBrandAssetPipelineResolution(
        brandId: brandToken.id,
        shouldFallback: true,
        fallbackIconToken: brandToken.fallbackIconToken,
        licenseStatus: SceneBrandLicenseStatus.unknown,
        sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
        hashMatched: false,
        allowColorOverride: false,
        issues: <ReFusionMotionDirectorIssue>[
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Brand asset manifest entry is missing for `${brandToken.id}`; semantic fallback will be used.',
            path: 'brandAsset.manifest',
          ),
          _proofIssue(
            brandId: brandToken.id,
            sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
            licenseStatus: SceneBrandLicenseStatus.unknown,
            hashMatched: false,
            shouldFallback: true,
            fallbackIconToken: brandToken.fallbackIconToken,
          ),
        ],
      );
      _cache.write(cacheKey, resolution);
      return resolution;
    }

    final computedHash = manifestEntry.canonicalHash();
    final hashMatched = manifestEntry.declaredHash == computedHash;
    if (!hashMatched) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'Brand asset manifest hash mismatch for `${brandToken.id}`. declared=${manifestEntry.declaredHash} computed=$computedHash',
          path: 'brandAsset.manifest.declaredHash',
        ),
      );
    }

    final resolvedVariant = _resolveVariant(
      entry: manifestEntry,
      requested: variant,
      issues: issues,
    );

    final selectedAssetPath = _assetPathForVariant(
      entry: manifestEntry,
      variant: resolvedVariant,
    );

    if (!_isEmpty(colorOverrideHex) && !manifestEntry.allowColorOverride) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'Brand color override is not allowed for `${brandToken.id}`.',
          path: 'brandAsset.colorOverride',
        ),
      );
    }

    var shouldFallback = false;
    switch (manifestEntry.licenseStatus) {
      case SceneBrandLicenseStatus.allowed:
        shouldFallback = false;
      case SceneBrandLicenseStatus.userMustProvide:
        shouldFallback = userProvidedAsset == null;
      case SceneBrandLicenseStatus.restricted:
        shouldFallback = true;
      case SceneBrandLicenseStatus.unknown:
        shouldFallback = !policy.allowUnlicensedBrandInGeneratedScenes;
    }

    if (manifestEntry.licenseStatus == SceneBrandLicenseStatus.unknown &&
        shouldFallback) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Brand `${brandToken.displayName}` has unknown license status; semantic fallback enforced.',
          path: 'brandAsset.licenseStatus',
        ),
      );
    }

    if (manifestEntry.licenseStatus == SceneBrandLicenseStatus.restricted) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Brand `${brandToken.displayName}` is marked restricted; semantic fallback enforced.',
          path: 'brandAsset.licenseStatus',
        ),
      );
    }

    final resolution = SceneBrandAssetPipelineResolution(
      brandId: brandToken.id,
      shouldFallback: shouldFallback || _isEmpty(selectedAssetPath),
      fallbackIconToken: manifestEntry.fallbackIconToken,
      licenseStatus: manifestEntry.licenseStatus,
      sourceKind: manifestEntry.sourceKind,
      hashMatched: hashMatched,
      allowColorOverride: manifestEntry.allowColorOverride,
      resolvedAssetPath: selectedAssetPath,
      resolvedVariant: resolvedVariant,
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(
        <ReFusionMotionDirectorIssue>[
          ...issues,
          _proofIssue(
            brandId: brandToken.id,
            sourceKind: manifestEntry.sourceKind,
            licenseStatus: manifestEntry.licenseStatus,
            hashMatched: hashMatched,
            shouldFallback: shouldFallback || _isEmpty(selectedAssetPath),
            fallbackIconToken: manifestEntry.fallbackIconToken,
          ),
        ],
      ),
    );
    _cache.write(cacheKey, resolution);
    return resolution;
  }

  SceneBrandAssetManifestEntry _buildUserProvidedEntry({
    required SceneBrandToken brandToken,
    required SceneBrandUserProvidedAsset userProvidedAsset,
  }) {
    final seed = SceneBrandAssetManifestEntry(
      brandId: brandToken.id,
      sourceKind: SceneBrandAssetSourceKind.userProvided,
      licenseStatus: SceneBrandLicenseStatus.userMustProvide,
      fallbackIconToken: brandToken.fallbackIconToken,
      source: userProvidedAsset.source,
      usageNotes: userProvidedAsset.usageNotes,
      declaredHash: 'pending',
      iconAssetPath: userProvidedAsset.assetPath,
      wordmarkAssetPath: userProvidedAsset.wordmarkPath,
      allowedVariants: const <SceneBrandAssetVariant>{
        SceneBrandAssetVariant.canonical,
        SceneBrandAssetVariant.wordmark,
      },
      allowColorOverride: false,
    );
    return SceneBrandAssetManifestEntry(
      brandId: seed.brandId,
      sourceKind: seed.sourceKind,
      licenseStatus: seed.licenseStatus,
      fallbackIconToken: seed.fallbackIconToken,
      source: seed.source,
      usageNotes: seed.usageNotes,
      declaredHash: seed.canonicalHash(),
      iconAssetPath: seed.iconAssetPath,
      wordmarkAssetPath: seed.wordmarkAssetPath,
      allowedVariants: seed.allowedVariants,
      allowColorOverride: seed.allowColorOverride,
    );
  }

  SceneBrandAssetVariant _resolveVariant({
    required SceneBrandAssetManifestEntry entry,
    required SceneBrandAssetVariant requested,
    required List<ReFusionMotionDirectorIssue> issues,
  }) {
    if (entry.allowedVariants.contains(requested)) {
      return requested;
    }
    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.warning,
        message:
            'Brand asset variant `${requested.name}` is not allowed for `${entry.brandId}`; canonical variant used.',
        path: 'brandAsset.variant',
      ),
    );
    return SceneBrandAssetVariant.canonical;
  }

  String? _assetPathForVariant({
    required SceneBrandAssetManifestEntry entry,
    required SceneBrandAssetVariant variant,
  }) {
    switch (variant) {
      case SceneBrandAssetVariant.canonical:
        return entry.iconAssetPath;
      case SceneBrandAssetVariant.monochrome:
        return entry.monochromeAssetPath;
      case SceneBrandAssetVariant.inverse:
        return entry.inverseAssetPath;
      case SceneBrandAssetVariant.wordmark:
        return entry.wordmarkAssetPath;
    }
  }

  ReFusionMotionDirectorIssue _proofIssue({
    required String brandId,
    required SceneBrandAssetSourceKind sourceKind,
    required SceneBrandLicenseStatus licenseStatus,
    required bool hashMatched,
    required bool shouldFallback,
    required String fallbackIconToken,
  }) {
    return ReFusionMotionDirectorIssue(
      severity: ReFusionMotionDirectorIssueSeverity.info,
      message: '$kSceneBrandAssetProofTag '
          'brandId=$brandId '
          'sourceKind=${sourceKind.name} '
          'licenseStatus=${licenseStatus.name} '
          'hashMatched=$hashMatched '
          'shouldFallback=$shouldFallback '
          'fallbackIconToken=$fallbackIconToken',
      path: 'brandAssetPipeline',
    );
  }

  static SceneBrandAssetManifest _buildDefaultManifest() {
    final seedEntries = <SceneBrandAssetManifestEntry>[
      SceneBrandAssetManifestEntry(
        brandId: r'$brand.chatgpt',
        sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
        licenseStatus: SceneBrandLicenseStatus.unknown,
        fallbackIconToken: r'$icon.chat',
        source: 'brand-registry',
        usageNotes: 'Use semantic fallback unless legal status is approved.',
        declaredHash: 'pending',
        iconAssetPath: 'assets/brands/chatgpt/icon.svg',
        monochromeAssetPath: 'assets/brands/chatgpt/icon_mono.svg',
        allowedVariants: const <SceneBrandAssetVariant>{
          SceneBrandAssetVariant.canonical,
          SceneBrandAssetVariant.monochrome,
        },
        canonicalColors: const <String>['#10A37F'],
        allowColorOverride: false,
      ),
      SceneBrandAssetManifestEntry(
        brandId: r'$brand.github',
        sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
        licenseStatus: SceneBrandLicenseStatus.unknown,
        fallbackIconToken: r'$icon.brandFallback',
        source: 'brand-registry',
        usageNotes: 'Bundled path allowed only with legal approval.',
        declaredHash: 'pending',
        iconAssetPath: 'assets/brands/github/icon.svg',
        monochromeAssetPath: 'assets/brands/github/icon_mono.svg',
        allowedVariants: const <SceneBrandAssetVariant>{
          SceneBrandAssetVariant.canonical,
          SceneBrandAssetVariant.monochrome,
        },
        canonicalColors: const <String>['#171515'],
      ),
      SceneBrandAssetManifestEntry(
        brandId: r'$brand.youtube',
        sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
        licenseStatus: SceneBrandLicenseStatus.restricted,
        fallbackIconToken: r'$icon.brandFallback',
        source: 'brand-registry',
        usageNotes: 'Restricted in generated scenes; always fallback.',
        declaredHash: 'pending',
        iconAssetPath: 'assets/brands/youtube/icon.svg',
        canonicalColors: const <String>['#FF0000'],
      ),
      SceneBrandAssetManifestEntry(
        brandId: r'$brand.figma',
        sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
        licenseStatus: SceneBrandLicenseStatus.userMustProvide,
        fallbackIconToken: r'$icon.presentation',
        source: 'brand-registry',
        usageNotes: 'Use user-provided asset path when needed.',
        declaredHash: 'pending',
        iconAssetPath: 'assets/brands/figma/icon.svg',
        canonicalColors: const <String>['#1ABCFE', '#0ACF83'],
      ),
      SceneBrandAssetManifestEntry(
        brandId: r'$brand.meta',
        sourceKind: SceneBrandAssetSourceKind.bundledRegistry,
        licenseStatus: SceneBrandLicenseStatus.unknown,
        fallbackIconToken: r'$icon.brandFallback',
        source: 'brand-registry',
        usageNotes: 'Fallback until approved asset rights are confirmed.',
        declaredHash: 'pending',
        iconAssetPath: 'assets/brands/meta/icon.svg',
        monochromeAssetPath: 'assets/brands/meta/icon_mono.svg',
        allowedVariants: const <SceneBrandAssetVariant>{
          SceneBrandAssetVariant.canonical,
          SceneBrandAssetVariant.monochrome,
        },
        canonicalColors: const <String>['#0668E1'],
      ),
    ];
    final finalized = <SceneBrandAssetManifestEntry>[];
    for (final entry in seedEntries) {
      final withHash = SceneBrandAssetManifestEntry(
        brandId: entry.brandId,
        sourceKind: entry.sourceKind,
        licenseStatus: entry.licenseStatus,
        fallbackIconToken: entry.fallbackIconToken,
        source: entry.source,
        usageNotes: entry.usageNotes,
        declaredHash: 'placeholder',
        iconAssetPath: entry.iconAssetPath,
        monochromeAssetPath: entry.monochromeAssetPath,
        inverseAssetPath: entry.inverseAssetPath,
        wordmarkAssetPath: entry.wordmarkAssetPath,
        canonicalColors: entry.canonicalColors,
        allowedVariants: entry.allowedVariants,
        allowColorOverride: entry.allowColorOverride,
      );
      finalized.add(
        SceneBrandAssetManifestEntry(
          brandId: withHash.brandId,
          sourceKind: withHash.sourceKind,
          licenseStatus: withHash.licenseStatus,
          fallbackIconToken: withHash.fallbackIconToken,
          source: withHash.source,
          usageNotes: withHash.usageNotes,
          declaredHash: withHash.canonicalHash(),
          iconAssetPath: withHash.iconAssetPath,
          monochromeAssetPath: withHash.monochromeAssetPath,
          inverseAssetPath: withHash.inverseAssetPath,
          wordmarkAssetPath: withHash.wordmarkAssetPath,
          canonicalColors: withHash.canonicalColors,
          allowedVariants: withHash.allowedVariants,
          allowColorOverride: withHash.allowColorOverride,
        ),
      );
    }
    return SceneBrandAssetManifest(entries: finalized);
  }

  static String _cacheKey({
    required String brandId,
    required String? colorOverrideHex,
    required SceneBrandAssetVariant variant,
    required SceneBrandUserProvidedAsset? userProvidedAsset,
    required bool allowUnlicensed,
    required bool failOnUnknownBrand,
  }) {
    return <String>[
      brandId,
      colorOverrideHex ?? '',
      variant.name,
      userProvidedAsset?.assetPath ?? '',
      userProvidedAsset?.wordmarkPath ?? '',
      allowUnlicensed.toString(),
      failOnUnknownBrand.toString(),
    ].join('::');
  }

  static bool _isEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
