import 'dart:collection';

import 'design_duration_scale.dart';
import 'design_radius_scale.dart';
import 'design_spacing_scale.dart';
import 'design_type_scale.dart';

const String kSceneDesignTokenResolverProofTag =
    'TF_SCENE_DESIGN_TOKEN_RESOLVER_PROOF';

class DesignTokenResolverResult {
  const DesignTokenResolverResult({
    required this.root,
    required this.canvasProfile,
    required this.proof,
  });

  final Map<String, Object?> root;
  final String canvasProfile;
  final String proof;
}

class DesignTokenResolver {
  const DesignTokenResolver();

  DesignTokenResolverResult resolveRoot({
    String canvasProfile = 'story_9_16',
  }) {
    final normalizedProfile = _normalizeProfile(canvasProfile);
    final safeAreaCurrent = _safeAreaByProfile[normalizedProfile]!;
    final root = <String, Object?>{
      'spacing': designSpacingScale,
      'typography': <String, Object?>{
        ...designTypeScale,
        ...designTypeScaleLegacyAliases,
      },
      'radius': designRadiusScale,
      'duration': designDurationScale,
      'stroke': _strokeScale,
      'shadow': _shadowScale,
      'motionEnergy': _motionEnergyScale,
      'safeArea': <String, Object?>{
        'current': safeAreaCurrent,
        ..._safeAreaByProfile,
      },
      'colorRole': _colorRoles,
    };

    return DesignTokenResolverResult(
      root: _freezeMap(root),
      canvasProfile: normalizedProfile,
      proof:
          '$kSceneDesignTokenResolverProofTag profile=$normalizedProfile groups=${root.length}',
    );
  }

  String _normalizeProfile(String profile) {
    final trimmed = profile.trim();
    if (_safeAreaByProfile.containsKey(trimmed)) {
      return trimmed;
    }
    return 'story_9_16';
  }

  static Map<String, Object?> _freezeMap(Map<String, Object?> map) {
    final next = <String, Object?>{};
    for (final entry in map.entries) {
      next[entry.key] = _deepCopy(entry.value);
    }
    return UnmodifiableMapView<String, Object?>(next);
  }

  static Object? _deepCopy(Object? value) {
    if (value is Map) {
      final next = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          continue;
        }
        next[entry.key as String] = _deepCopy(entry.value);
      }
      return UnmodifiableMapView<String, Object?>(next);
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_deepCopy));
    }
    return value;
  }
}

const Map<String, Object?> _strokeScale = <String, Object?>{
  'hairline': 1.0,
  'thin': 1.5,
  'regular': 2.0,
  'medium': 3.0,
  'thick': 4.0,
};

const Map<String, Object?> _shadowScale = <String, Object?>{
  'soft': <String, Object?>{
    'opacity': 0.12,
    'blur': 20.0,
    'offsetY': 8.0,
    'color': '#000000',
  },
  'card': <String, Object?>{
    'opacity': 0.18,
    'blur': 28.0,
    'offsetY': 14.0,
    'color': '#000000',
  },
  'hero': <String, Object?>{
    'opacity': 0.24,
    'blur': 42.0,
    'offsetY': 22.0,
    'color': '#000000',
  },
};

const Map<String, Object?> _motionEnergyScale = <String, Object?>{
  'calm': <String, Object?>{
    'durationMultiplier': 1.15,
    'overshoot': 0.0,
  },
  'balanced': <String, Object?>{
    'durationMultiplier': 1.0,
    'overshoot': 0.08,
  },
  'snappy': <String, Object?>{
    'durationMultiplier': 0.85,
    'overshoot': 0.14,
  },
};

const Map<String, Map<String, Object?>> _safeAreaByProfile =
    <String, Map<String, Object?>>{
  'story_9_16': <String, Object?>{
    'top': 120.0,
    'bottom': 140.0,
    'left': 48.0,
    'right': 48.0,
  },
  'widescreen_16_9': <String, Object?>{
    'top': 72.0,
    'bottom': 72.0,
    'left': 96.0,
    'right': 96.0,
  },
  'square_1_1': <String, Object?>{
    'top': 84.0,
    'bottom': 84.0,
    'left': 84.0,
    'right': 84.0,
  },
  'portrait_4_5': <String, Object?>{
    'top': 96.0,
    'bottom': 112.0,
    'left': 56.0,
    'right': 56.0,
  },
};

const Map<String, Object?> _colorRoles = <String, Object?>{
  'surface': <String, Object?>{
    'base': '#0B1020',
    'elevated': '#111827',
    'inverse': '#F8FAFC',
  },
  'text': <String, Object?>{
    'primary': '#F8FAFC',
    'secondary': '#CBD5E1',
    'inverse': '#101827',
  },
  'accent': <String, Object?>{
    'primary': '#3B82F6',
    'secondary': '#7C3AED',
    'success': '#22C55E',
    'warning': '#F59E0B',
  },
};
