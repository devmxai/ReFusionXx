import '../models/refusion_motion_director_models.dart';
import 'scene_brand_motion_profile.dart';
import 'scene_icon_registry.dart';

const String kSceneBrandMotionMappingProofTag = 'TF_SCENE_BRAND_MOTION_PROOF';

class SceneBrandMotionMappingResolution {
  const SceneBrandMotionMappingResolution({
    required this.profile,
    required this.issues,
  });

  final SceneBrandMotionProfile profile;
  final List<ReFusionMotionDirectorIssue> issues;
}

class SceneBrandMotionMapping {
  const SceneBrandMotionMapping({
    SceneIconRegistry iconRegistry = const SceneIconRegistry(),
  }) : _iconRegistry = iconRegistry;

  final SceneIconRegistry _iconRegistry;

  static const SceneBrandMotionProfile _techProfile = SceneBrandMotionProfile(
    id: r'$motion.brand.tech',
    style: 'tech',
    shellEnterRecipe: r'$motion.slideInFromLeft',
    shellExitRecipe: r'$motion.pushBack',
    iconEnterRecipe: r'$motion.iconPop',
    labelEnterRecipe: r'$motion.wordCascadeUp',
    bodyEnterRecipe: r'$motion.wordCascadeUp',
    allowElastic: false,
  );

  static const SceneBrandMotionProfile _playfulProfile =
      SceneBrandMotionProfile(
    id: r'$motion.brand.playful',
    style: 'playful',
    shellEnterRecipe: r'$motion.popInSpring',
    shellExitRecipe: r'$motion.slideOutToBottom',
    iconEnterRecipe: r'$motion.iconPop',
    labelEnterRecipe: r'$motion.wordCascadeUp',
    bodyEnterRecipe: r'$motion.wordCascadeUp',
    allowElastic: true,
  );

  static const SceneBrandMotionProfile _minimalProfile =
      SceneBrandMotionProfile(
    id: r'$motion.brand.minimal',
    style: 'minimal',
    shellEnterRecipe: r'$motion.fadeRaise',
    shellExitRecipe: r'$motion.fadeCollapse',
    iconEnterRecipe: r'$motion.fadeRaise',
    labelEnterRecipe: r'$motion.fadeRaise',
    bodyEnterRecipe: r'$motion.fadeRaise',
    allowElastic: false,
  );

  static const SceneBrandMotionProfile _cinematicProfile =
      SceneBrandMotionProfile(
    id: r'$motion.brand.cinematic',
    style: 'cinematic',
    shellEnterRecipe: r'$motion.cardSpringEntrance',
    shellExitRecipe: r'$motion.pushBack',
    iconEnterRecipe: r'$motion.iconPop',
    labelEnterRecipe: r'$motion.wordCascadeUp',
    bodyEnterRecipe: r'$motion.wordCascadeUp',
    allowElastic: false,
  );

  static const SceneBrandMotionProfile _audioProfile = SceneBrandMotionProfile(
    id: r'$motion.brand.audio',
    style: 'audio',
    shellEnterRecipe: r'$motion.slideInFromRight',
    shellExitRecipe: r'$motion.slideOutToRight',
    iconEnterRecipe: r'$motion.iconPop',
    labelEnterRecipe: r'$motion.wordCascadeUp',
    bodyEnterRecipe: r'$motion.wordCascadeUp',
    allowElastic: true,
  );

  SceneBrandMotionMappingResolution resolve({
    String? brandToken,
    String? mood,
    String? label,
    String? body,
  }) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final brand = brandToken == null || brandToken.trim().isEmpty
        ? null
        : _iconRegistry.findBrandToken(brandToken);
    final normalizedMood = _normalize(mood ?? '');
    final normalizedLabel = _normalize(label ?? '');
    final normalizedBody = _normalize(body ?? '');
    final category = _normalize(brand?.category ?? '');

    SceneBrandMotionProfile profile;
    String reason;
    if (category == 'ai' ||
        category == 'tech' ||
        category == 'productivity' ||
        category == 'cloud') {
      profile = _techProfile;
      reason = 'brand_category';
    } else if (category == 'social' ||
        category == 'creator' ||
        category == 'communication' ||
        category == 'commerce') {
      profile = _playfulProfile;
      reason = 'brand_category';
    } else if (normalizedMood.contains('luxury') ||
        normalizedMood.contains('minimal') ||
        normalizedMood.contains('premium')) {
      profile = _minimalProfile;
      reason = 'mood';
    } else if (normalizedMood.contains('cinematic') ||
        normalizedMood.contains('dramatic') ||
        normalizedMood.contains('editorial')) {
      profile = _cinematicProfile;
      reason = 'mood';
    } else if (_isAudioSubject(
        normalizedLabel, normalizedBody, normalizedMood)) {
      profile = _audioProfile;
      reason = 'semantic_subject';
    } else {
      profile = _techProfile;
      reason = 'default';
    }

    issues.add(
      ReFusionMotionDirectorIssue(
        severity: ReFusionMotionDirectorIssueSeverity.info,
        message: '$kSceneBrandMotionMappingProofTag '
            'brandToken=${brandToken ?? 'none'} '
            'brandCategory=${brand?.category ?? 'none'} '
            'selectedProfile=${profile.id} '
            'reason=$reason',
        path: 'brandMotionMapping',
      ),
    );

    if (normalizedMood.contains('luxury') && profile.allowElastic) {
      issues.add(
        const ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Luxury/minimal mood selected a playful elastic motion profile; review if this is intentional.',
          path: 'brandMotionMapping.mood',
        ),
      );
    }

    return SceneBrandMotionMappingResolution(
      profile: profile,
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  bool _isAudioSubject(String label, String body, String mood) {
    return label.contains('voice') ||
        label.contains('audio') ||
        label.contains('dubb') ||
        body.contains('voice') ||
        body.contains('audio') ||
        body.contains('music') ||
        mood.contains('audio') ||
        mood.contains('music');
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
