import 'package:flutter/foundation.dart';

@immutable
class McpEffectCapabilityBlocker {
  const McpEffectCapabilityBlocker({
    required this.code,
    required this.message,
    required this.effectType,
    this.layerId,
  });

  final String code;
  final String message;
  final String effectType;
  final String? layerId;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code,
      'message': message,
      'effectType': effectType,
      if (layerId != null && layerId!.isNotEmpty) 'layerId': layerId,
    };
  }
}

class McpEffectCapabilityGuard {
  const McpEffectCapabilityGuard();

  static const Set<String> _supportedEffectTypes = <String>{
    'mask',
    'clip_path',
    'clip_path_circle',
    'render_mask',
    'corner_radius',
    'border',
    'stroke',
    'glow',
    'shadow',
    'motion_blur',
    'gaussian_blur',
    'transform',
    'opacity',
  };

  List<McpEffectCapabilityBlocker> detectUnsupportedEffects(
    List<Map<String, Object?>> remoteLayers,
  ) {
    final blockers = <McpEffectCapabilityBlocker>[];
    for (final remoteLayer in remoteLayers) {
      blockers.addAll(_detectLayerUnsupportedEffects(remoteLayer));
    }
    return List<McpEffectCapabilityBlocker>.unmodifiable(blockers);
  }

  List<McpEffectCapabilityBlocker> _detectLayerUnsupportedEffects(
    Map<String, Object?> remoteLayer,
  ) {
    final payload = _asMap(remoteLayer['payload']);
    final updates = _asMap(payload['updates']);
    final payloadStyle = _asMap(payload['style']);
    final updatesStyle = _asMap(updates['style']);
    final nestedPayload = _asMap(payload['payload']);
    final nestedUpdatesPayload = _asMap(updates['payload']);
    final layerId = _firstText(<Object?>[
      remoteLayer['id'],
      payload['layerId'],
      payload['targetLayerId'],
      updates['layerId'],
      updates['targetLayerId'],
    ]);
    final effectCandidates = <Object?>[
      payload['effect'],
      updates['effect'],
      payload['effects'],
      updates['effects'],
      payloadStyle['effect'],
      payloadStyle['effects'],
      updatesStyle['effect'],
      updatesStyle['effects'],
      nestedPayload['effect'],
      nestedPayload['effects'],
      nestedUpdatesPayload['effect'],
      nestedUpdatesPayload['effects'],
    ];
    final detectedEffectTypes = <String>{};
    for (final candidate in effectCandidates) {
      detectedEffectTypes.addAll(_extractEffectTypes(candidate));
    }
    if (detectedEffectTypes.isEmpty) {
      return const <McpEffectCapabilityBlocker>[];
    }
    final blockers = <McpEffectCapabilityBlocker>[];
    for (final effectType in detectedEffectTypes) {
      if (_supportedEffectTypes.contains(effectType)) {
        continue;
      }
      blockers.add(
        McpEffectCapabilityBlocker(
          code: 'UNSUPPORTED_EFFECT_CAPABILITY',
          message:
              'Effect `$effectType` is not supported by the active renderer path.',
          effectType: effectType,
          layerId: layerId,
        ),
      );
    }
    return blockers;
  }

  Set<String> _extractEffectTypes(Object? value) {
    if (value == null) {
      return const <String>{};
    }
    if (value is String) {
      final normalized = _normalizeEffectType(value);
      if (normalized == null) {
        return const <String>{};
      }
      return <String>{normalized};
    }
    if (value is List) {
      final types = <String>{};
      for (final entry in value) {
        types.addAll(_extractEffectTypes(entry));
      }
      return types;
    }
    final map = _asMap(value);
    if (map.isNotEmpty) {
      final normalized = _normalizeEffectType(
        _firstText(<Object?>[
          map['type'],
          map['effectType'],
          map['effect'],
          map['id'],
          map['name'],
        ]),
      );
      if (normalized != null) {
        return <String>{normalized};
      }
    }
    return const <String>{};
  }

  String? _normalizeEffectType(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      final next = <String, Object?>{};
      value.forEach((key, dynamicValue) {
        if (key is String) {
          next[key] = dynamicValue;
        }
      });
      return next;
    }
    return const <String, Object?>{};
  }

  static String? _firstText(List<Object?> values) {
    for (final value in values) {
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }
    return null;
  }
}
