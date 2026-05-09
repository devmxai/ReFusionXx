import '../models/refusion_motion_director_models.dart';
import 'scene_icon_token.dart';

const String kSceneBrandRegistryProofTag = 'TF_SCENE_BRAND_REGISTRY_PROOF';

class SceneBrandAssetPolicy {
  const SceneBrandAssetPolicy({
    this.allowUnlicensedBrandInGeneratedScenes = false,
    this.failOnUnknownBrand = true,
  });

  final bool allowUnlicensedBrandInGeneratedScenes;
  final bool failOnUnknownBrand;
}

class SceneBrandResolution {
  const SceneBrandResolution({
    required this.brandToken,
    required this.fallbackIconToken,
    required this.issues,
  });

  final SceneBrandToken? brandToken;
  final SceneIconToken? fallbackIconToken;
  final List<ReFusionMotionDirectorIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionMotionDirectorIssueSeverity.error,
      );
}
