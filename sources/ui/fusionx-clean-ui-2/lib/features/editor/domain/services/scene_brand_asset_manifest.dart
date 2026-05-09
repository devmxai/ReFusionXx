enum SceneBrandAssetSourceKind {
  bundledRegistry,
  userProvided,
  externalReference,
}

enum SceneBrandLicenseStatus {
  allowed,
  userMustProvide,
  restricted,
  unknown,
}

enum SceneBrandAssetVariant {
  canonical,
  monochrome,
  inverse,
  wordmark,
}

class SceneBrandAssetManifestEntry {
  const SceneBrandAssetManifestEntry({
    required this.brandId,
    required this.sourceKind,
    required this.licenseStatus,
    required this.fallbackIconToken,
    required this.source,
    required this.usageNotes,
    required this.declaredHash,
    this.iconAssetPath,
    this.monochromeAssetPath,
    this.inverseAssetPath,
    this.wordmarkAssetPath,
    this.canonicalColors = const <String>[],
    this.allowedVariants = const <SceneBrandAssetVariant>{
      SceneBrandAssetVariant.canonical,
    },
    this.allowColorOverride = false,
  });

  final String brandId;
  final SceneBrandAssetSourceKind sourceKind;
  final SceneBrandLicenseStatus licenseStatus;
  final String fallbackIconToken;
  final String source;
  final String usageNotes;
  final String declaredHash;
  final String? iconAssetPath;
  final String? monochromeAssetPath;
  final String? inverseAssetPath;
  final String? wordmarkAssetPath;
  final List<String> canonicalColors;
  final Set<SceneBrandAssetVariant> allowedVariants;
  final bool allowColorOverride;

  String canonicalHash() {
    final payload = <String>[
      brandId,
      sourceKind.name,
      licenseStatus.name,
      fallbackIconToken,
      source,
      usageNotes,
      iconAssetPath ?? '',
      monochromeAssetPath ?? '',
      inverseAssetPath ?? '',
      wordmarkAssetPath ?? '',
      canonicalColors.join('|'),
      allowedVariants
          .map((value) => value.name)
          .toList(growable: false)
          .join('|'),
      allowColorOverride.toString(),
    ].join('::');
    return _fnv1a64(payload);
  }

  static String _fnv1a64(String input) {
    const int fnvPrime = 0x100000001b3;
    const int fnvOffset = 0xcbf29ce484222325;
    var hash = fnvOffset;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

class SceneBrandAssetManifest {
  const SceneBrandAssetManifest({
    required this.entries,
  });

  final List<SceneBrandAssetManifestEntry> entries;

  SceneBrandAssetManifestEntry? findByBrandId(String brandId) {
    final normalized = _normalize(brandId);
    for (final entry in entries) {
      if (_normalize(entry.brandId) == normalized) {
        return entry;
      }
    }
    return null;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
