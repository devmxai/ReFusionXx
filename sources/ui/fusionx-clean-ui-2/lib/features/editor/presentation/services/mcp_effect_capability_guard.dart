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

  McpEffectCapabilityReport inspectCapabilities(
    List<Map<String, Object?>> remoteLayers,
  ) {
    final detected = <String>{};
    final supported = <String>{};
    final unsupported = <String>{};
    final blockers = <McpEffectCapabilityBlocker>[];
    final layerEffectTypes = <Map<String, Object?>>[];
    for (final remoteLayer in remoteLayers) {
      final layerInspection = _inspectLayerEffectTypes(remoteLayer);
      detected.addAll(layerInspection.detectedEffectTypes);
      supported.addAll(layerInspection.detectedEffectTypes.where(
        (entry) => _supportedEffectTypes.contains(entry),
      ));
      unsupported.addAll(layerInspection.detectedEffectTypes.where(
        (entry) => !_supportedEffectTypes.contains(entry),
      ));
      blockers.addAll(layerInspection.blockers);
      if (layerInspection.layerId != null &&
          layerInspection.detectedEffectTypes.isNotEmpty) {
        layerEffectTypes.add(<String, Object?>{
          'layerId': layerInspection.layerId,
          'effectTypes':
              layerInspection.detectedEffectTypes.toList(growable: false),
        });
      }
    }
    return McpEffectCapabilityReport(
      detectedEffectTypes: List<String>.unmodifiable(detected.toList()..sort()),
      supportedEffectTypes:
          List<String>.unmodifiable(supported.toList()..sort()),
      unsupportedEffectTypes:
          List<String>.unmodifiable(unsupported.toList()..sort()),
      blockers: List<McpEffectCapabilityBlocker>.unmodifiable(blockers),
      layerEffectTypes:
          List<Map<String, Object?>>.unmodifiable(layerEffectTypes),
      supportedRegistry:
          List<String>.unmodifiable(_supportedEffectTypes.toList()..sort()),
    );
  }

  List<McpEffectCapabilityBlocker> detectUnsupportedEffects(
    List<Map<String, Object?>> remoteLayers,
  ) {
    return inspectCapabilities(remoteLayers).blockers;
  }

  _McpLayerEffectInspection _inspectLayerEffectTypes(
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
      return const _McpLayerEffectInspection(
        layerId: null,
        detectedEffectTypes: <String>[],
        blockers: <McpEffectCapabilityBlocker>[],
      );
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
    return _McpLayerEffectInspection(
      layerId: layerId,
      detectedEffectTypes: List<String>.unmodifiable(
        detectedEffectTypes.toList()..sort(),
      ),
      blockers: List<McpEffectCapabilityBlocker>.unmodifiable(blockers),
    );
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

@immutable
class McpEffectCapabilityReport {
  const McpEffectCapabilityReport({
    required this.detectedEffectTypes,
    required this.supportedEffectTypes,
    required this.unsupportedEffectTypes,
    required this.blockers,
    required this.layerEffectTypes,
    required this.supportedRegistry,
  });

  final List<String> detectedEffectTypes;
  final List<String> supportedEffectTypes;
  final List<String> unsupportedEffectTypes;
  final List<McpEffectCapabilityBlocker> blockers;
  final List<Map<String, Object?>> layerEffectTypes;
  final List<String> supportedRegistry;

  bool get hasUnsupportedEffects => unsupportedEffectTypes.isNotEmpty;

  List<Map<String, Object?>> get blockerMaps =>
      blockers.map((entry) => entry.toMap()).toList(growable: false);

  Map<String, Object?> toProofMap() {
    return <String, Object?>{
      'effectCapability.detected': detectedEffectTypes,
      'effectCapability.supported': supportedEffectTypes,
      'effectCapability.unsupported': unsupportedEffectTypes,
      'effectCapability.blockerCount': blockers.length,
      'effectCapability.layerEffectTypes': layerEffectTypes,
      'effectCapability.registry': supportedRegistry,
    };
  }
}

@immutable
class _McpLayerEffectInspection {
  const _McpLayerEffectInspection({
    required this.layerId,
    required this.detectedEffectTypes,
    required this.blockers,
  });

  final String? layerId;
  final List<String> detectedEffectTypes;
  final List<McpEffectCapabilityBlocker> blockers;
}
