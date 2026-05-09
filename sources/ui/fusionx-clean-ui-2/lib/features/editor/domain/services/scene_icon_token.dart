class SceneIconToken {
  const SceneIconToken({
    required this.id,
    required this.iconName,
    required this.category,
    this.tags = const <String>[],
  });

  final String id;
  final String iconName;
  final String category;
  final List<String> tags;
}

class SceneBrandToken {
  const SceneBrandToken({
    required this.id,
    required this.displayName,
    required this.category,
    required this.fallbackIconToken,
    required this.licenseStatus,
    this.assetPath,
    this.wordmarkPath,
    this.allowedInGeneratedScenes = false,
  });

  final String id;
  final String displayName;
  final String category;
  final String fallbackIconToken;
  final String licenseStatus;
  final String? assetPath;
  final String? wordmarkPath;
  final bool allowedInGeneratedScenes;
}
