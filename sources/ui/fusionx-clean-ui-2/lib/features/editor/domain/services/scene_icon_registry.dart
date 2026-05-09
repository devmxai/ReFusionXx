import '../models/refusion_motion_director_models.dart';
import 'scene_brand_asset_policy.dart';
import 'scene_brand_asset_pipeline.dart';
import 'scene_icon_token.dart';

class SceneIconRegistry {
  const SceneIconRegistry({
    SceneBrandAssetPolicy brandPolicy = const SceneBrandAssetPolicy(),
    SceneBrandAssetPipeline? brandAssetPipeline,
  })  : _brandPolicy = brandPolicy,
        _brandAssetPipeline = brandAssetPipeline;

  final SceneBrandAssetPolicy _brandPolicy;
  final SceneBrandAssetPipeline? _brandAssetPipeline;

  static final SceneBrandAssetPipeline _defaultBrandAssetPipeline =
      SceneBrandAssetPipeline();

  static const List<SceneIconToken> _semanticIcons = <SceneIconToken>[
    SceneIconToken(
      id: r'$icon.montage',
      iconName: 'wand',
      category: 'editing',
      tags: <String>['fast', 'montage', 'edit'],
    ),
    SceneIconToken(
      id: r'$icon.audioEngineering',
      iconName: 'mic',
      category: 'audio',
      tags: <String>['audio', 'voice', 'dubbing'],
    ),
    SceneIconToken(
      id: r'$icon.captions',
      iconName: 'title',
      category: 'text',
      tags: <String>['caption', 'subtitle', 'text'],
    ),
    SceneIconToken(
      id: r'$icon.imageRetouch',
      iconName: 'image',
      category: 'image',
      tags: <String>['image', 'retouch', 'photo'],
    ),
    SceneIconToken(
      id: r'$icon.colorGrade',
      iconName: 'palette',
      category: 'color',
      tags: <String>['color', 'grade', 'look'],
    ),
    SceneIconToken(
      id: r'$icon.presentation',
      iconName: 'layout',
      category: 'presentation',
      tags: <String>['slides', 'presentation'],
    ),
    SceneIconToken(
      id: r'$icon.upload',
      iconName: 'plus',
      category: 'input',
      tags: <String>['upload', 'add', 'plus'],
    ),
    SceneIconToken(
      id: r'$icon.send',
      iconName: 'send',
      category: 'input',
      tags: <String>['send', 'arrow', 'submit'],
    ),
    SceneIconToken(
      id: r'$icon.chat',
      iconName: 'message',
      category: 'communication',
      tags: <String>['chat', 'prompt'],
    ),
    SceneIconToken(
      id: r'$icon.appBuild',
      iconName: 'sparkles',
      category: 'product',
      tags: <String>['app', 'build', 'feature'],
    ),
    SceneIconToken(
      id: r'$icon.brandFallback',
      iconName: 'globe',
      category: 'fallback',
      tags: <String>['brand', 'generic'],
    ),
  ];

  static const List<SceneBrandToken> _brands = <SceneBrandToken>[
    SceneBrandToken(
      id: r'$brand.chatgpt',
      displayName: 'ChatGPT',
      category: 'ai',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.claude',
      displayName: 'Claude',
      category: 'ai',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.gemini',
      displayName: 'Gemini',
      category: 'ai',
      fallbackIconToken: r'$icon.appBuild',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.perplexity',
      displayName: 'Perplexity',
      category: 'ai',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.grok',
      displayName: 'Grok',
      category: 'ai',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.copilot',
      displayName: 'Copilot',
      category: 'ai',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.mistral',
      displayName: 'Mistral',
      category: 'ai',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.llama',
      displayName: 'Llama',
      category: 'ai',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.meta',
      displayName: 'Meta',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.facebook',
      displayName: 'Facebook',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.instagram',
      displayName: 'Instagram',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.tiktok',
      displayName: 'TikTok',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.snapchat',
      displayName: 'Snapchat',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.threads',
      displayName: 'Threads',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.bluesky',
      displayName: 'Bluesky',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.x',
      displayName: 'X',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.youtube',
      displayName: 'YouTube',
      category: 'creator',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.linkedin',
      displayName: 'LinkedIn',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.reddit',
      displayName: 'Reddit',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.pinterest',
      displayName: 'Pinterest',
      category: 'social',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.apple',
      displayName: 'Apple',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.microsoft',
      displayName: 'Microsoft',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.amazon',
      displayName: 'Amazon',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.oracle',
      displayName: 'Oracle',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.ibm',
      displayName: 'IBM',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.samsung',
      displayName: 'Samsung',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.icloud',
      displayName: 'iCloud',
      category: 'cloud',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.googleDrive',
      displayName: 'Google Drive',
      category: 'cloud',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.dropbox',
      displayName: 'Dropbox',
      category: 'cloud',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.oneDrive',
      displayName: 'OneDrive',
      category: 'cloud',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.aws',
      displayName: 'AWS',
      category: 'cloud',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.github',
      displayName: 'GitHub',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.google',
      displayName: 'Google',
      category: 'tech',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.gmail',
      displayName: 'Gmail',
      category: 'communication',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.slack',
      displayName: 'Slack',
      category: 'communication',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.whatsapp',
      displayName: 'WhatsApp',
      category: 'communication',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.telegram',
      displayName: 'Telegram',
      category: 'communication',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.discord',
      displayName: 'Discord',
      category: 'communication',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.signal',
      displayName: 'Signal',
      category: 'communication',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.zoom',
      displayName: 'Zoom',
      category: 'communication',
      fallbackIconToken: r'$icon.chat',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.figma',
      displayName: 'Figma',
      category: 'productivity',
      fallbackIconToken: r'$icon.presentation',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.canva',
      displayName: 'Canva',
      category: 'productivity',
      fallbackIconToken: r'$icon.presentation',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.notion',
      displayName: 'Notion',
      category: 'productivity',
      fallbackIconToken: r'$icon.presentation',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.adobe',
      displayName: 'Adobe',
      category: 'creator',
      fallbackIconToken: r'$icon.presentation',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.spotify',
      displayName: 'Spotify',
      category: 'creator',
      fallbackIconToken: r'$icon.audioEngineering',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.soundcloud',
      displayName: 'SoundCloud',
      category: 'creator',
      fallbackIconToken: r'$icon.audioEngineering',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.appleMusic',
      displayName: 'Apple Music',
      category: 'creator',
      fallbackIconToken: r'$icon.audioEngineering',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.shopify',
      displayName: 'Shopify',
      category: 'commerce',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.ebay',
      displayName: 'eBay',
      category: 'commerce',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.stripe',
      displayName: 'Stripe',
      category: 'commerce',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
    SceneBrandToken(
      id: r'$brand.paypal',
      displayName: 'PayPal',
      category: 'commerce',
      fallbackIconToken: r'$icon.brandFallback',
      licenseStatus: 'registry-pending',
    ),
  ];

  static final Map<String, SceneIconToken> _semanticById =
      <String, SceneIconToken>{
    for (final icon in _semanticIcons) _normalize(icon.id): icon,
  };

  static final Map<String, SceneBrandToken> _brandById =
      <String, SceneBrandToken>{
    for (final brand in _brands) _normalize(brand.id): brand,
  };

  List<SceneIconToken> get semanticIcons => _semanticIcons;
  List<SceneBrandToken> get brands => _brands;

  SceneIconToken? findIconToken(String tokenOrLabel) {
    final normalized = _normalize(tokenOrLabel);
    final direct = _semanticById[normalized];
    if (direct != null) {
      return direct;
    }
    for (final icon in _semanticIcons) {
      if (_normalize(icon.iconName) == normalized ||
          icon.tags.any((tag) => _normalize(tag) == normalized)) {
        return icon;
      }
    }
    return null;
  }

  SceneBrandToken? findBrandToken(String brandToken) {
    return _brandById[_normalize(brandToken)];
  }

  String resolveIconName({
    String? iconToken,
    String? brandToken,
    String? fallbackText,
    List<ReFusionMotionDirectorIssue>? issues,
  }) {
    final targetIssues = issues ?? <ReFusionMotionDirectorIssue>[];
    if (brandToken != null && brandToken.trim().isNotEmpty) {
      final brandResolution = resolveBrand(brandToken);
      targetIssues.addAll(brandResolution.issues);
      if (brandResolution.fallbackIconToken != null) {
        return brandResolution.fallbackIconToken!.iconName;
      }
    }
    if (iconToken != null && iconToken.trim().isNotEmpty) {
      final icon = findIconToken(iconToken);
      if (icon != null) {
        return icon.iconName;
      }
      targetIssues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Icon token `$iconToken` is not registered; fallback semantic icon applied.',
          path: 'iconToken',
        ),
      );
    }
    final fallback = findIconToken(fallbackText ?? '') ??
        findIconToken(r'$icon.brandFallback')!;
    return fallback.iconName;
  }

  SceneBrandResolution resolveBrand(String brandToken) {
    final issues = <ReFusionMotionDirectorIssue>[];
    final token = findBrandToken(brandToken);
    if (token == null) {
      if (_brandPolicy.failOnUnknownBrand) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Brand token `$brandToken` is not in the registry. Use a known `\$brand.*` token or fallback semantic icon.',
            path: 'brandToken',
          ),
        );
      } else {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.warning,
            message:
                'Brand token `$brandToken` is unknown; fallback semantic icon will be used.',
            path: 'brandToken',
          ),
        );
      }
      final fallback = findIconToken(r'$icon.brandFallback');
      issues.add(_proofIssue(
        knownBrand: false,
        brandToken: brandToken,
        fallbackIcon: fallback?.id ?? 'none',
      ));
      return SceneBrandResolution(
        brandToken: null,
        fallbackIconToken: fallback,
        issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
      );
    }
    final pipeline = _brandAssetPipeline ?? _defaultBrandAssetPipeline;
    final assetResolution = pipeline.resolve(
      brandToken: token,
      policy: _brandPolicy,
    );
    issues.addAll(assetResolution.issues);
    final fallback = findIconToken(
      assetResolution.fallbackIconToken,
    );
    issues.add(_proofIssue(
      knownBrand: true,
      brandToken: brandToken,
      fallbackIcon: fallback?.id ?? 'none',
    ));
    return SceneBrandResolution(
      brandToken: token,
      fallbackIconToken: fallback ?? findIconToken(r'$icon.brandFallback'),
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  ReFusionMotionDirectorIssue _proofIssue({
    required bool knownBrand,
    required String brandToken,
    required String fallbackIcon,
  }) {
    return ReFusionMotionDirectorIssue(
      severity: ReFusionMotionDirectorIssueSeverity.info,
      message: '$kSceneBrandRegistryProofTag '
          'brandToken=$brandToken '
          'knownBrand=$knownBrand '
          'failOnUnknownBrand=${_brandPolicy.failOnUnknownBrand} '
          'allowUnlicensed=${_brandPolicy.allowUnlicensedBrandInGeneratedScenes} '
          'fallbackIcon=$fallbackIcon',
      path: 'brandRegistry',
    );
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
