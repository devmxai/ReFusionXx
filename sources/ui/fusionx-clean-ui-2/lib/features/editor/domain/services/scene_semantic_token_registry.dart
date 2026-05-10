import 'dart:collection';

import 'design_duration_scale.dart';
import 'design_radius_scale.dart';
import 'design_spacing_scale.dart';
import 'design_token_resolver.dart';
import 'design_type_scale.dart';

const String kSceneTokenRegistryProofTag = 'TF_SCENE_TOKEN_REGISTRY_PROOF';

class SceneSemanticTokenRegistryError {
  const SceneSemanticTokenRegistryError({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;
}

class SceneSemanticTokenResolution {
  const SceneSemanticTokenResolution({
    required this.value,
    required this.errors,
    required this.proof,
  });

  final Object? value;
  final List<SceneSemanticTokenRegistryError> errors;
  final String proof;

  bool get isValid => errors.isEmpty;
}

/// Resolves `$token.path` and `${token.path}` references into native values.
///
/// v2-01 scope:
/// - deterministic token registry;
/// - strict unknown-token errors;
/// - deep resolution for map/list semantic blueprints.
class SceneSemanticTokenRegistry {
  SceneSemanticTokenRegistry({
    String canvasProfile = 'story_9_16',
    Map<String, Object?>? components,
    Map<String, Object?>? spacing,
    Map<String, Object?>? typography,
    Map<String, Object?>? colors,
    Map<String, Object?>? radius,
    Map<String, Object?>? shadows,
    Map<String, Object?>? stroke,
    Map<String, Object?>? safeArea,
    Map<String, Object?>? motionEnergy,
    Map<String, Object?>? duration,
    Map<String, Object?>? easing,
    Map<String, Object?>? anchors,
    Map<String, Object?>? motionRecipes,
    Map<String, Object?>? beatPresets,
  }) : _root = _buildRoot(
          canvasProfile: canvasProfile,
          components: components,
          spacing: spacing,
          typography: typography,
          colors: colors,
          radius: radius,
          shadows: shadows,
          stroke: stroke,
          safeArea: safeArea,
          motionEnergy: motionEnergy,
          duration: duration,
          easing: easing,
          anchors: anchors,
          motionRecipes: motionRecipes,
          beatPresets: beatPresets,
        );

  final Map<String, Object?> _root;

  SceneSemanticTokenResolution resolveToken(
    String token, {
    String location = r'$',
  }) {
    final errors = <SceneSemanticTokenRegistryError>[];
    final normalized = _normalizeToken(token);
    final resolved = _lookup(normalized, location, errors);
    final proof = _proofMessage(
      mode: 'single',
      tokenCount: 1,
      resolvedCount: errors.isEmpty ? 1 : 0,
      errorCount: errors.length,
    );
    return SceneSemanticTokenResolution(
      value: resolved,
      errors: List.unmodifiable(errors),
      proof: proof,
    );
  }

  SceneSemanticTokenResolution resolveBlueprintValue(Object? value) {
    final errors = <SceneSemanticTokenRegistryError>[];
    var tokenCount = 0;
    var resolvedCount = 0;

    Object? walk(Object? node, String path) {
      if (node is String) {
        final maybeToken = _tryParseToken(node);
        if (maybeToken == null) {
          return node;
        }
        tokenCount += 1;
        final beforeErrors = errors.length;
        final resolved = _lookup(maybeToken, path, errors);
        if (errors.length == beforeErrors) {
          resolvedCount += 1;
          return _deepCopyValue(resolved);
        }
        return node;
      }
      if (node is List) {
        return List<Object?>.unmodifiable(
          node.asMap().entries.map((entry) {
            return walk(entry.value, '$path[${entry.key}]');
          }),
        );
      }
      if (node is Map) {
        final next = <String, Object?>{};
        for (final entry in node.entries) {
          if (entry.key is! String) {
            continue;
          }
          next[entry.key as String] =
              walk(entry.value, '$path.${entry.key as String}');
        }
        return UnmodifiableMapView<String, Object?>(next);
      }
      return node;
    }

    final resolvedValue = walk(value, r'$');
    final proof = _proofMessage(
      mode: 'blueprint',
      tokenCount: tokenCount,
      resolvedCount: resolvedCount,
      errorCount: errors.length,
    );
    return SceneSemanticTokenResolution(
      value: resolvedValue,
      errors: List.unmodifiable(errors),
      proof: proof,
    );
  }

  static Map<String, Object?> _buildRoot({
    required String canvasProfile,
    Map<String, Object?>? components,
    Map<String, Object?>? spacing,
    Map<String, Object?>? typography,
    Map<String, Object?>? colors,
    Map<String, Object?>? radius,
    Map<String, Object?>? shadows,
    Map<String, Object?>? stroke,
    Map<String, Object?>? safeArea,
    Map<String, Object?>? motionEnergy,
    Map<String, Object?>? duration,
    Map<String, Object?>? easing,
    Map<String, Object?>? anchors,
    Map<String, Object?>? motionRecipes,
    Map<String, Object?>? beatPresets,
  }) {
    final resolved = const DesignTokenResolver().resolveRoot(
      canvasProfile: canvasProfile,
    );
    final resolvedRoot = resolved.root;
    return UnmodifiableMapView<String, Object?>(
      <String, Object?>{
        'component': _freezeMap(_mergeShallow(_defaultComponents, components)),
        'spacing': _freezeMap(
          _mergeShallow(
            resolvedRoot['spacing'] as Map<String, Object?>,
            spacing,
          ),
        ),
        'typography': _freezeMap(
          _mergeShallow(
            resolvedRoot['typography'] as Map<String, Object?>,
            typography,
          ),
        ),
        'color': _freezeMap(_mergeShallow(_defaultColors, colors)),
        'colorRole': _freezeMap(
          _mergeShallow(
            resolvedRoot['colorRole'] as Map<String, Object?>,
            colors,
          ),
        ),
        'radius': _freezeMap(
          _mergeShallow(
            resolvedRoot['radius'] as Map<String, Object?>,
            radius,
          ),
        ),
        'shadow': _freezeMap(
          _mergeShallow(
            resolvedRoot['shadow'] as Map<String, Object?>,
            shadows,
          ),
        ),
        'stroke': _freezeMap(
          _mergeShallow(
            resolvedRoot['stroke'] as Map<String, Object?>,
            stroke,
          ),
        ),
        'safeArea': _freezeMap(
          _mergeShallow(
            resolvedRoot['safeArea'] as Map<String, Object?>,
            safeArea,
          ),
        ),
        'motionEnergy': _freezeMap(
          _mergeShallow(
            resolvedRoot['motionEnergy'] as Map<String, Object?>,
            motionEnergy,
          ),
        ),
        'duration': _freezeMap(
          _mergeShallow(
            resolvedRoot['duration'] as Map<String, Object?>,
            duration,
          ),
        ),
        'easing': _freezeMap(_mergeShallow(_defaultEasing, easing)),
        'anchor': _freezeMap(_mergeShallow(_defaultAnchors, anchors)),
        'motion':
            _freezeMap(_mergeShallow(_defaultMotionRecipes, motionRecipes)),
        'beat': _freezeMap(_mergeShallow(_defaultBeatPresets, beatPresets)),
      },
    );
  }

  static Map<String, Object?> _mergeShallow(
    Map<String, Object?> base,
    Map<String, Object?>? override,
  ) {
    if (override == null || override.isEmpty) {
      return base;
    }
    final merged = <String, Object?>{...base};
    for (final entry in override.entries) {
      merged[entry.key] = entry.value;
    }
    return merged;
  }

  static Map<String, Object?> _freezeMap(Map<String, Object?> map) {
    final next = <String, Object?>{};
    for (final entry in map.entries) {
      next[entry.key] = _deepCopyValue(entry.value);
    }
    return UnmodifiableMapView<String, Object?>(next);
  }

  static Object? _deepCopyValue(Object? value) {
    if (value is Map) {
      final next = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          continue;
        }
        next[entry.key as String] = _deepCopyValue(entry.value);
      }
      return UnmodifiableMapView<String, Object?>(next);
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_deepCopyValue));
    }
    return value;
  }

  Object? _lookup(
    String normalizedToken,
    String location,
    List<SceneSemanticTokenRegistryError> errors,
  ) {
    if (normalizedToken.isEmpty) {
      errors.add(
        SceneSemanticTokenRegistryError(
          code: 'invalid_token',
          path: location,
          message: 'Token is empty.',
        ),
      );
      return null;
    }
    final parts = normalizedToken.split('.');
    var cursor = _root;
    Object? current = cursor[parts.first];
    if (current == null) {
      errors.add(
        SceneSemanticTokenRegistryError(
          code: 'unknown_token',
          path: location,
          message:
              'Unknown token root `${parts.first}` for `$normalizedToken`.',
        ),
      );
      return null;
    }
    for (var index = 1; index < parts.length; index += 1) {
      final segment = parts[index];
      if (current is Map<String, Object?> && current.containsKey(segment)) {
        current = current[segment];
        continue;
      }
      errors.add(
        SceneSemanticTokenRegistryError(
          code: 'unknown_token',
          path: location,
          message: 'Unknown token path `$normalizedToken`.',
        ),
      );
      return null;
    }
    return current;
  }

  String _normalizeToken(String token) {
    final parsed = _tryParseToken(token);
    return parsed ?? token.trim();
  }

  String? _tryParseToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith(r'${') && trimmed.endsWith('}')) {
      return trimmed.substring(2, trimmed.length - 1).trim();
    }
    if (trimmed.startsWith(r'$')) {
      return trimmed.substring(1).trim();
    }
    return null;
  }

  String _proofMessage({
    required String mode,
    required int tokenCount,
    required int resolvedCount,
    required int errorCount,
  }) {
    return '$kSceneTokenRegistryProofTag '
        'mode=$mode tokenCount=$tokenCount '
        'resolvedCount=$resolvedCount errorCount=$errorCount';
  }
}

const Map<String, Object?> _defaultSpacing = designSpacingScale;

const Map<String, Object?> _defaultComponents = <String, Object?>{
  'PromptInputBar': 'PromptInputBar',
  'SearchBar': 'SearchBar',
  'TextField': 'TextField',
  'FeatureCard': 'FeatureCard',
  'FeedbackCard': 'FeedbackCard',
  'StatCard': 'StatCard',
  'TestimonialCard': 'TestimonialCard',
  'ProductCard': 'ProductCard',
  'ImageCard': 'ImageCard',
  'FeatureGrid': 'FeatureGrid',
  'FeatureList': 'FeatureList',
  'AppIconIntro': 'AppIconIntro',
  'HeroSection': 'HeroSection',
  'BrandLogo': 'BrandLogo',
  'AvatarBadge': 'AvatarBadge',
  'ResultCard': 'ResultCard',
  'Toast': 'Toast',
  'AlertCard': 'AlertCard',
  'ProgressIndicator': 'ProgressIndicator',
  'MotionTextBlock': 'MotionTextBlock',
  'KineticTitle': 'KineticTitle',
  'TypingPrompt': 'TypingPrompt',
  'QuoteBlock': 'QuoteBlock',
  'IconButton': 'IconButton',
  'FAB': 'FAB',
  'ToggleButton': 'ToggleButton',
  'CTAButton': 'CTAButton',
  'DashboardPanel': 'DashboardPanel',
  'FloatingWindowCard': 'FloatingWindowCard',
  'OrbitalRing': 'OrbitalRing',
  'OrbitalFeatureRing': 'OrbitalFeatureRing',
  'TimelineStrip': 'TimelineStrip',
  'AudioWaveform': 'AudioWaveform',
  'VideoPlayer': 'VideoPlayer',
  'ColorGradePanel': 'ColorGradePanel',
};

const Map<String, Object?> _defaultTypography = <String, Object?>{
  ...designTypeScale,
  ...designTypeScaleLegacyAliases,
};

const Map<String, Object?> _defaultColors = <String, Object?>{
  'surface': <String, Object?>{
    'base': '#0B1020',
    'elevated': '#111827',
    'contrast': '#F8FAFC',
  },
  'text': <String, Object?>{
    'primary': '#F8FAFC',
    'secondary': '#CBD5E1',
    'inverse': '#101827',
  },
  'accent': <String, Object?>{
    'cyan': '#66E3FF',
    'blue': '#3B82F6',
    'violet': '#7C3AED',
    'success': '#22C55E',
  },
};

const Map<String, Object?> _defaultRadius = designRadiusScale;

const Map<String, Object?> _defaultShadows = <String, Object?>{
  'card': <String, Object?>{
    'opacity': 0.24,
    'blur': 28.0,
    'offsetX': 0.0,
    'offsetY': 14.0,
    'color': '#000000',
  },
  'hero': <String, Object?>{
    'opacity': 0.32,
    'blur': 42.0,
    'offsetX': 0.0,
    'offsetY': 26.0,
    'color': '#000000',
  },
};

const Map<String, Object?> _defaultDuration = designDurationScale;

const Map<String, Object?> _defaultEasing = <String, Object?>{
  'linear': 'linear',
  'easyEase': 'easyEase',
  'fastSlow': 'fastSlow',
  'slowFast': 'slowFast',
  'slowFastSlow': 'slowFastSlow',
  'snappy': 'fastSlow',
  'expressive': 'slowFastSlow',
};

const Map<String, Object?> _defaultAnchors = <String, Object?>{
  'center': <String, Object?>{'x': 0.0, 'y': 0.0},
  'goldenTop': <String, Object?>{'x': 0.0, 'y': -240.0},
  'goldenBottom': <String, Object?>{'x': 0.0, 'y': 240.0},
  'leftSafe': <String, Object?>{'x': -360.0, 'y': 0.0},
  'rightSafe': <String, Object?>{'x': 360.0, 'y': 0.0},
};

const Map<String, Object?> _defaultMotionRecipes = <String, Object?>{
  'softFadeUp': <String, Object?>{
    'fromOpacity': 0.0,
    'toOpacity': 1.0,
    'fromOffsetY': 32.0,
    'toOffsetY': 0.0,
    'easing': 'fastSlow',
  },
  'scaleFromOrigin': <String, Object?>{
    'fromScale': 0.82,
    'toScale': 1.0,
    'easing': 'slowFastSlow',
  },
  'typewriterFixedFrame': <String, Object?>{
    'property': 'typewriterProgress',
    'from': 0.0,
    'to': 1.0,
    'easing': 'linear',
  },
};

const Map<String, Object?> _defaultBeatPresets = <String, Object?>{
  'intro': <String, Object?>{
    'enterRatio': 0.35,
    'holdRatio': 0.4,
    'exitRatio': 0.25,
  },
  'feature': <String, Object?>{
    'enterRatio': 0.25,
    'holdRatio': 0.55,
    'exitRatio': 0.2,
  },
  'outro': <String, Object?>{
    'enterRatio': 0.2,
    'holdRatio': 0.5,
    'exitRatio': 0.3,
  },
};
