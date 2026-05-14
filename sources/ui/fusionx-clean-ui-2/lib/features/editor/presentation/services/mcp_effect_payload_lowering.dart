import 'package:flutter/foundation.dart';

@immutable
class McpLoweredEffectMutation {
  const McpLoweredEffectMutation({
    this.circleMask,
    this.cornerRadius,
    this.borderWidth,
    this.borderColorHex,
    this.glowBlur,
    this.glowOpacity,
    this.glowColorHex,
    this.centerX,
    this.centerY,
    this.scaleX,
    this.scaleY,
    this.rotationDegrees,
  });

  final bool? circleMask;
  final double? cornerRadius;
  final double? borderWidth;
  final String? borderColorHex;
  final double? glowBlur;
  final double? glowOpacity;
  final String? glowColorHex;
  final double? centerX;
  final double? centerY;
  final double? scaleX;
  final double? scaleY;
  final double? rotationDegrees;

  bool get hasAny =>
      circleMask != null ||
      cornerRadius != null ||
      borderWidth != null ||
      borderColorHex != null ||
      glowBlur != null ||
      glowOpacity != null ||
      glowColorHex != null ||
      centerX != null ||
      centerY != null ||
      scaleX != null ||
      scaleY != null ||
      rotationDegrees != null;

  McpLoweredEffectMutation merge(McpLoweredEffectMutation other) {
    return McpLoweredEffectMutation(
      circleMask: other.circleMask ?? circleMask,
      cornerRadius: other.cornerRadius ?? cornerRadius,
      borderWidth: other.borderWidth ?? borderWidth,
      borderColorHex: other.borderColorHex ?? borderColorHex,
      glowBlur: other.glowBlur ?? glowBlur,
      glowOpacity: other.glowOpacity ?? glowOpacity,
      glowColorHex: other.glowColorHex ?? glowColorHex,
      centerX: other.centerX ?? centerX,
      centerY: other.centerY ?? centerY,
      scaleX: other.scaleX ?? scaleX,
      scaleY: other.scaleY ?? scaleY,
      rotationDegrees: other.rotationDegrees ?? rotationDegrees,
    );
  }
}

class McpEffectPayloadLowering {
  const McpEffectPayloadLowering();

  McpLoweredEffectMutation lower({
    required Map<String, Object?> payload,
    required Map<String, Object?> updates,
  }) {
    final payloadStyle = _asMap(payload['style']);
    final updatesStyle = _asMap(updates['style']);
    final nestedPayload = _asMap(payload['payload']);
    final nestedUpdatesPayload = _asMap(updates['payload']);
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
    var result = const McpLoweredEffectMutation();
    for (final candidate in effectCandidates) {
      for (final effect in _asEffectEntries(candidate)) {
        result = result.merge(_lowerEffectEntry(effect));
      }
    }
    return result;
  }

  List<Map<String, Object?>> _asEffectEntries(Object? value) {
    if (value == null) {
      return const <Map<String, Object?>>[];
    }
    if (value is List) {
      final entries = <Map<String, Object?>>[];
      for (final entry in value) {
        final effectMap = _asEffectEntryMap(entry);
        if (effectMap != null) {
          entries.add(effectMap);
        }
      }
      return entries;
    }
    final single = _asEffectEntryMap(value);
    if (single == null) {
      return const <Map<String, Object?>>[];
    }
    return <Map<String, Object?>>[single];
  }

  Map<String, Object?>? _asEffectEntryMap(Object? value) {
    if (value is String) {
      return <String, Object?>{'type': value};
    }
    final map = _asMap(value);
    if (map.isEmpty) {
      return null;
    }
    return map;
  }

  McpLoweredEffectMutation _lowerEffectEntry(Map<String, Object?> effect) {
    final normalizedType = _normalizeType(_firstText(<Object?>[
      effect['type'],
      effect['effectType'],
      effect['effect'],
      effect['id'],
      effect['name'],
    ]));
    final params = _asMap(effect['params']);
    switch (normalizedType) {
      case 'mask':
      case 'clip_path':
      case 'clip_path_circle':
      case 'render_mask':
        return _lowerMaskLike(effect: effect, params: params);
      case 'border':
      case 'stroke':
        return McpLoweredEffectMutation(
          borderWidth: _firstNumber(<Object?>[
            params['width'],
            params['strokeWidth'],
            effect['width'],
            effect['strokeWidth'],
          ]),
          borderColorHex: _firstText(<Object?>[
            params['color'],
            params['strokeColor'],
            effect['color'],
            effect['strokeColor'],
          ]),
        );
      case 'glow':
      case 'shadow':
        return McpLoweredEffectMutation(
          glowBlur: _firstNumber(<Object?>[
            params['blur'],
            params['radius'],
            params['amount'],
            effect['blur'],
          ]),
          glowOpacity: _firstNumber(<Object?>[
            params['opacity'],
            params['alpha'],
            params['intensity'],
            effect['opacity'],
          ]),
          glowColorHex: _firstText(<Object?>[
            params['color'],
            params['strokeColor'],
            effect['color'],
          ]),
        );
      case 'transform':
        return _lowerTransformLike(effect: effect, params: params);
      default:
        return const McpLoweredEffectMutation();
    }
  }

  McpLoweredEffectMutation _lowerMaskLike({
    required Map<String, Object?> effect,
    required Map<String, Object?> params,
  }) {
    final shape = _normalizeType(_firstText(<Object?>[
      params['shape'],
      params['type'],
      effect['shape'],
      effect['maskType'],
    ]));
    final circleMask = shape == 'circle'
        ? true
        : (shape == 'none' || shape == 'off' ? false : null);
    return McpLoweredEffectMutation(
      circleMask: circleMask,
      cornerRadius: _firstNumber(<Object?>[
        params['radius'],
        params['cornerRadius'],
        effect['radius'],
        effect['cornerRadius'],
      ]),
    );
  }

  McpLoweredEffectMutation _lowerTransformLike({
    required Map<String, Object?> effect,
    required Map<String, Object?> params,
  }) {
    final uniformScale = _firstNumber(<Object?>[
      params['scale'],
      effect['scale'],
    ]);
    return McpLoweredEffectMutation(
      centerX: _firstNumber(<Object?>[
        params['x'],
        params['centerX'],
        effect['x'],
        effect['centerX'],
      ]),
      centerY: _firstNumber(<Object?>[
        params['y'],
        params['centerY'],
        effect['y'],
        effect['centerY'],
      ]),
      scaleX: _firstNumber(<Object?>[
        params['scaleX'],
        effect['scaleX'],
        uniformScale,
      ]),
      scaleY: _firstNumber(<Object?>[
        params['scaleY'],
        effect['scaleY'],
        uniformScale,
      ]),
      rotationDegrees: _firstNumber(<Object?>[
        params['rotation'],
        params['rotationDeg'],
        effect['rotation'],
        effect['rotationDeg'],
      ]),
    );
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

  static double? _firstNumber(List<Object?> values) {
    for (final value in values) {
      final resolved = _asNumber(value);
      if (resolved != null) {
        return resolved;
      }
    }
    return null;
  }

  static double? _asNumber(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static String _normalizeType(String? raw) {
    if (raw == null) {
      return '';
    }
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}
