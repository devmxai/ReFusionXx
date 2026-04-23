import 'dart:convert';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';

class MotionTextPresetJsonException implements Exception {
  MotionTextPresetJsonException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MotionTextPresetJsonCodec {
  MotionTextPresetJsonCodec._();

  static MotionTextPresetDefinition parsePresetString(String source) {
    final decoded = jsonDecode(_normalizeSourceString(source));
    if (decoded is! Map) {
      throw MotionTextPresetJsonException(
        'Preset JSON must be a single object.',
      );
    }
    return fromJson(
        _normalizeNestedJsonStrings(Map<String, dynamic>.from(decoded)));
  }

  static MotionTextPresetDefinition fromJson(Map<String, dynamic> json) {
    final animationBlocks =
        _readAnimationBlocks(_readAnimationBlockSource(json));
    if (animationBlocks.isEmpty) {
      throw MotionTextPresetJsonException(
        'Preset `animationBlocks` must contain at least one block.',
      );
    }

    final rawText = _readOptionalString(json, 'defaultText') ??
        _readOptionalString(json, 'text') ??
        _readOptionalString(json, 'content');
    final defaultText = rawText != null && rawText.trim().isNotEmpty
        ? rawText.trim()
        : 'Your Text';

    final rawLabel = _readOptionalString(json, 'label') ??
        _readOptionalString(json, 'name') ??
        _readOptionalString(json, 'title');
    final label = _resolveGeneratedLabel(
      explicitLabel: rawLabel,
      defaultText: defaultText,
      animationBlocks: animationBlocks,
    );

    final rawId = _readOptionalString(json, 'id') ??
        _readOptionalString(json, 'presetId');
    final id = _resolveGeneratedId(rawId, label);
    final description = _readOptionalString(json, 'description');
    final kind = _readPresetKind(json['kind']);
    final parameters = _readParameterDefinitions(json['parameters']);
    final staticProperties = _readStaticProperties(
      json['staticProperties'],
      targetFactory: () => const MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: '__preset_target__',
      ),
    );

    return MotionTextPresetDefinition(
      id: id,
      kind: kind,
      label: label,
      defaultText: defaultText,
      description: description,
      parameters: parameters,
      staticProperties: staticProperties,
      animationBlocks: animationBlocks,
    );
  }

  static Object? _readAnimationBlockSource(Map<String, dynamic> json) {
    if (json.containsKey('animationBlocks')) {
      return json['animationBlocks'];
    }
    if (json.containsKey('motions')) {
      return json['motions'];
    }
    if (json.containsKey('blocks')) {
      return json['blocks'];
    }
    return null;
  }

  static String _normalizeSourceString(String source) {
    final trimmed = source.trim();
    if (trimmed.startsWith('```')) {
      final lines = trimmed.split('\n');
      final cleanedLines = <String>[];
      for (final line in lines) {
        if (line.trim().startsWith('```')) {
          continue;
        }
        cleanedLines.add(line);
      }
      return cleanedLines.join('\n').trim();
    }
    return trimmed;
  }

  static Map<String, dynamic> _normalizeNestedJsonStrings(
    Map<String, dynamic> json,
  ) {
    final normalized = Map<String, dynamic>.from(json);
    for (final key in <String>[
      'animationBlocks',
      'motions',
      'blocks',
      'parameters',
      'staticProperties',
    ]) {
      final value = normalized[key];
      if (value is! String) {
        continue;
      }
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        normalized[key] = jsonDecode(trimmed);
      } catch (_) {
        // Keep the original value so the later validation message points to
        // the field that is still malformed.
      }
    }
    return normalized;
  }

  static String _resolveGeneratedLabel({
    required String? explicitLabel,
    required String defaultText,
    required List<MotionTextAnimationBlock> animationBlocks,
  }) {
    final trimmedLabel = explicitLabel?.trim();
    if (trimmedLabel != null && trimmedLabel.isNotEmpty) {
      return trimmedLabel;
    }
    final trimmedText = defaultText.trim();
    if (trimmedText.isNotEmpty && trimmedText != 'Your Text') {
      return trimmedText.length <= 32
          ? trimmedText
          : '${trimmedText.substring(0, 32).trimRight()}...';
    }
    final firstKind = animationBlocks.first.kind.name;
    return _titleCaseFromCamelCase(firstKind);
  }

  static String _resolveGeneratedId(String? rawId, String label) {
    final trimmedId = rawId?.trim();
    if (trimmedId != null && trimmedId.isNotEmpty) {
      return trimmedId;
    }
    final slug = _slugifyLabel(label);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'custom.generated.$slug.$timestamp';
  }

  static String _slugifyLabel(String label) {
    final lower = label.toLowerCase();
    final buffer = StringBuffer();
    var previousWasSeparator = false;
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final isAsciiLetter = rune >= 97 && rune <= 122;
      final isDigit = rune >= 48 && rune <= 57;
      if (isAsciiLetter || isDigit) {
        buffer.write(char);
        previousWasSeparator = false;
        continue;
      }
      if (!previousWasSeparator) {
        buffer.write('_');
        previousWasSeparator = true;
      }
    }
    final slug = buffer.toString().replaceAll(RegExp('_+'), '_').replaceAll(
          RegExp(r'^_|_$'),
          '',
        );
    if (slug.isNotEmpty) {
      return slug;
    }
    return 'preset';
  }

  static String _titleCaseFromCamelCase(String source) {
    final buffer = StringBuffer();
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      final isUppercase =
          char.toUpperCase() == char && char.toLowerCase() != char;
      if (index == 0) {
        buffer.write(char.toUpperCase());
        continue;
      }
      if (isUppercase) {
        buffer.write(' ');
      }
      buffer.write(char);
    }
    return buffer.toString().trim();
  }

  static List<MotionTextPresetParameterDefinition> _readParameterDefinitions(
    Object? raw,
  ) {
    if (raw == null) {
      return const <MotionTextPresetParameterDefinition>[];
    }
    if (raw is! List) {
      throw MotionTextPresetJsonException('`parameters` must be a list.');
    }
    return raw.map((item) {
      if (item is! Map) {
        throw MotionTextPresetJsonException(
          'Each item in `parameters` must be an object.',
        );
      }
      final json = Map<String, dynamic>.from(item);
      final defaultValueRaw =
          json.containsKey('default') ? json['default'] : json['defaultValue'];
      if (defaultValueRaw == null) {
        throw MotionTextPresetJsonException(
          'Parameter `${json['id'] ?? 'unknown'}` is missing `default`.',
        );
      }
      return MotionTextPresetParameterDefinition(
        id: _readRequiredString(json, 'id'),
        label: _readRequiredString(json, 'label'),
        defaultValue: _readPropertyValue(defaultValueRaw),
        minValue: _readOptionalDouble(json, 'min'),
        maxValue: _readOptionalDouble(json, 'max'),
        description: _readOptionalString(json, 'description'),
      );
    }).toList(growable: false);
  }

  static List<MotionPropertyAssignment> _readStaticProperties(
    Object? raw, {
    required MotionPropertyTarget Function() targetFactory,
  }) {
    if (raw == null) {
      return const <MotionPropertyAssignment>[];
    }
    if (raw is! List) {
      throw MotionTextPresetJsonException('`staticProperties` must be a list.');
    }
    return raw.map((item) {
      if (item is! Map) {
        throw MotionTextPresetJsonException(
          'Each item in `staticProperties` must be an object.',
        );
      }
      final json = Map<String, dynamic>.from(item);
      final propertyId = _readOptionalString(json, 'propertyId') ??
          _readOptionalString(json, 'property');
      if (propertyId == null || propertyId.isEmpty) {
        throw MotionTextPresetJsonException(
          'Each static property must include `propertyId`.',
        );
      }
      final definition = _propertyDefinitionById[propertyId];
      if (definition == null) {
        throw MotionTextPresetJsonException(
          'Unsupported static property `$propertyId`.',
        );
      }
      return MotionPropertyAssignment(
        target: targetFactory(),
        definition: definition,
        value: _readPropertyValue(json['value'],
            expectedKind: definition.valueKind),
      );
    }).toList(growable: false);
  }

  static List<MotionTextAnimationBlock> _readAnimationBlocks(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        throw MotionTextPresetJsonException(
          '`animationBlocks` must not be empty.',
        );
      }
      try {
        return _readAnimationBlocks(jsonDecode(trimmed));
      } catch (_) {
        throw MotionTextPresetJsonException(
          '`animationBlocks` string must contain a valid JSON array.',
        );
      }
    }
    if (raw is! List) {
      throw MotionTextPresetJsonException(
        '`animationBlocks` must be a list.',
      );
    }
    return raw.map((item) {
      if (item is! Map) {
        throw MotionTextPresetJsonException(
          'Each item in `animationBlocks` must be an object.',
        );
      }
      final json = Map<String, dynamic>.from(item);
      final startMs = _readRequiredIntAlias(json, <String>['startMs', 'start']);
      final endMs = _readEndMilliseconds(json, startMs);
      if (endMs <= startMs) {
        throw MotionTextPresetJsonException(
          'Animation block `${json['id'] ?? 'unknown'}` must have endMs > startMs.',
        );
      }
      return MotionTextAnimationBlock(
        id: _resolveGeneratedBlockId(
          rawId: _readOptionalString(json, 'id') ??
              _readOptionalString(json, 'blockId'),
          kind: _readAnimationKind(json['kind']),
          startMs: startMs,
        ),
        kind: _readAnimationKind(json['kind']),
        relativeRange: TimelineTimeRange(
          start: TimelineTime.fromMilliseconds(startMs),
          endExclusive: TimelineTime.fromMilliseconds(endMs),
        ),
        interpolation: _readInterpolation(json['interpolation']),
        revealSpec: _readRevealSpec(json['revealSpec']),
        parameters: _readParameterValues(json['parameters']),
      );
    }).toList(growable: false);
  }

  static int _readEndMilliseconds(Map<String, dynamic> json, int startMs) {
    if (json.containsKey('endMs') || json.containsKey('end')) {
      return _readRequiredIntAlias(json, <String>['endMs', 'end']);
    }
    final durationMs = _readRequiredIntAlias(
      json,
      <String>['durationMs', 'duration'],
    );
    return startMs + durationMs;
  }

  static String _resolveGeneratedBlockId({
    required String? rawId,
    required MotionTextAnimationKind kind,
    required int startMs,
  }) {
    final trimmedId = rawId?.trim();
    if (trimmedId != null && trimmedId.isNotEmpty) {
      return trimmedId;
    }
    return '${kind.name}_$startMs';
  }

  static MotionInterpolationSpec _readInterpolation(Object? raw) {
    if (raw == null) {
      return const MotionInterpolationSpec.easeInOut();
    }
    if (raw is String) {
      return _interpolationFromKind(_parseInterpolationKind(raw));
    }
    if (raw is! Map) {
      throw MotionTextPresetJsonException(
        '`interpolation` must be a string or object.',
      );
    }
    final json = Map<String, dynamic>.from(raw);
    final kind = _parseInterpolationKind(_readRequiredString(json, 'kind'));
    switch (kind) {
      case MotionInterpolationKind.cubicBezier:
        return MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: _readDouble(json, 'x1'),
            y1: _readDouble(json, 'y1'),
            x2: _readDouble(json, 'x2'),
            y2: _readDouble(json, 'y2'),
          ),
        );
      case MotionInterpolationKind.spring:
        return MotionInterpolationSpec.spring(
          spring: MotionSpringSpec(
            stiffness: _readDouble(json, 'stiffness'),
            damping: _readDouble(json, 'damping'),
            mass: _readOptionalDouble(json, 'mass') ?? 1.0,
            initialVelocity:
                _readOptionalDouble(json, 'initialVelocity') ?? 0.0,
          ),
        );
      case MotionInterpolationKind.bounce:
        return MotionInterpolationSpec.bounce(
          bounce: MotionBounceSpec(
            amplitude:
                _readOptionalDouble(json, 'amplitude') ??
                kDefaultMotionBounceSpec.amplitude,
            bounces:
                _readOptionalInt(json, 'bounces') ??
                _readOptionalInt(json, 'bounceCount') ??
                kDefaultMotionBounceSpec.bounces,
            decay:
                _readOptionalDouble(json, 'decay') ??
                kDefaultMotionBounceSpec.decay,
          ),
        );
      case MotionInterpolationKind.elastic:
        return MotionInterpolationSpec.elastic(
          elastic: MotionElasticSpec(
            amplitude:
                _readOptionalDouble(json, 'amplitude') ??
                kDefaultMotionElasticSpec.amplitude,
            period:
                _readOptionalDouble(json, 'period') ??
                kDefaultMotionElasticSpec.period,
            decay:
                _readOptionalDouble(json, 'decay') ??
                kDefaultMotionElasticSpec.decay,
          ),
        );
      case MotionInterpolationKind.hold:
      case MotionInterpolationKind.linear:
      case MotionInterpolationKind.easeIn:
      case MotionInterpolationKind.easeOut:
      case MotionInterpolationKind.easeInOut:
        return _interpolationFromKind(kind);
    }
  }

  static MotionTextRevealSpec? _readRevealSpec(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is! Map) {
      throw MotionTextPresetJsonException('`revealSpec` must be an object.');
    }
    final json = Map<String, dynamic>.from(raw);
    return MotionTextRevealSpec(
      unit: _readRevealUnit(json['unit']),
      stagger: TimelineTime.fromMilliseconds(
        _readOptionalInt(json, 'staggerMs') ?? 0,
      ),
    );
  }

  static Map<String, MotionPropertyValue> _readParameterValues(Object? raw) {
    if (raw == null) {
      return const <String, MotionPropertyValue>{};
    }
    if (raw is! Map) {
      throw MotionTextPresetJsonException('`parameters` must be an object.');
    }
    return Map<String, MotionPropertyValue>.unmodifiable({
      for (final entry in raw.entries)
        entry.key.toString(): _readPropertyValue(entry.value),
    });
  }

  static MotionPropertyValue _readPropertyValue(
    Object? raw, {
    MotionPropertyValueKind? expectedKind,
  }) {
    if (raw == null) {
      throw MotionTextPresetJsonException('Preset property value is missing.');
    }
    if (raw is num) {
      if (expectedKind == MotionPropertyValueKind.integer) {
        return MotionPropertyValue.integer(raw.toInt());
      }
      return MotionPropertyValue.scalar(raw.toDouble());
    }
    if (raw is bool) {
      return MotionPropertyValue.boolean(raw);
    }
    if (raw is String) {
      if (expectedKind == MotionPropertyValueKind.colorArgb) {
        final normalized = raw.replaceFirst('#', '');
        final value = int.tryParse(normalized, radix: 16);
        if (value == null) {
          throw MotionTextPresetJsonException(
            'Invalid color value `$raw`. Use hex like #FFFFFFFF.',
          );
        }
        return MotionPropertyValue.colorArgb(value);
      }
      return MotionPropertyValue.stringValue(raw);
    }
    if (raw is Map) {
      final json = Map<String, dynamic>.from(raw);
      if (json.containsKey('x') && json.containsKey('y')) {
        return MotionPropertyValue.point2D(
          MotionPoint2D(
            x: _toDouble(json['x']),
            y: _toDouble(json['y']),
          ),
        );
      }
      if (json.containsKey('width') && json.containsKey('height')) {
        return MotionPropertyValue.size2D(
          MotionSize2D(
            width: _toDouble(json['width']),
            height: _toDouble(json['height']),
          ),
        );
      }
      if (json.containsKey('left') &&
          json.containsKey('top') &&
          json.containsKey('width') &&
          json.containsKey('height')) {
        return MotionPropertyValue.rect(
          MotionRect(
            left: _toDouble(json['left']),
            top: _toDouble(json['top']),
            width: _toDouble(json['width']),
            height: _toDouble(json['height']),
          ),
        );
      }
      if (json.containsKey('value')) {
        return _readPropertyValue(json['value'], expectedKind: expectedKind);
      }
    }
    throw MotionTextPresetJsonException(
      'Unsupported preset property value: `$raw`.',
    );
  }

  static MotionTextPresetKind _readPresetKind(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return MotionTextPresetKind.custom;
    }
    switch (value) {
      case 'hiWord':
        return MotionTextPresetKind.hiWord;
      case 'reviewGen':
        return MotionTextPresetKind.reviewGen;
      case 'cinematic':
        return MotionTextPresetKind.cinematic;
      case 'custom':
        return MotionTextPresetKind.custom;
      default:
        throw MotionTextPresetJsonException(
            'Unsupported preset kind `$value`.');
    }
  }

  static MotionTextAnimationKind _readAnimationKind(Object? raw) {
    final value = raw?.toString().trim();
    switch (value) {
      case 'fadeIn':
        return MotionTextAnimationKind.fadeIn;
      case 'fadeOut':
        return MotionTextAnimationKind.fadeOut;
      case 'wordReveal':
        return MotionTextAnimationKind.wordReveal;
      case 'letterReveal':
        return MotionTextAnimationKind.letterReveal;
      case 'typewriter':
        return MotionTextAnimationKind.typewriter;
      case 'elasticPop':
        return MotionTextAnimationKind.elasticPop;
      case 'scaleIn':
        return MotionTextAnimationKind.scaleIn;
      case 'scaleOut':
        return MotionTextAnimationKind.scaleOut;
      case 'blurIn':
        return MotionTextAnimationKind.blurIn;
      case 'blurOut':
        return MotionTextAnimationKind.blurOut;
      case 'rotationSettle':
        return MotionTextAnimationKind.rotationSettle;
      case 'cinematicEntrance':
        return MotionTextAnimationKind.cinematicEntrance;
      case 'cinematicExit':
        return MotionTextAnimationKind.cinematicExit;
      default:
        throw MotionTextPresetJsonException(
          'Unsupported animation kind `${raw ?? ''}`.',
        );
    }
  }

  static MotionInterpolationKind _parseInterpolationKind(String raw) {
    switch (raw.trim()) {
      case 'hold':
        return MotionInterpolationKind.hold;
      case 'linear':
        return MotionInterpolationKind.linear;
      case 'easeIn':
        return MotionInterpolationKind.easeIn;
      case 'easeOut':
        return MotionInterpolationKind.easeOut;
      case 'easeInOut':
        return MotionInterpolationKind.easeInOut;
      case 'cubicBezier':
        return MotionInterpolationKind.cubicBezier;
      case 'spring':
        return MotionInterpolationKind.spring;
      case 'bounce':
        return MotionInterpolationKind.bounce;
      case 'elastic':
        return MotionInterpolationKind.elastic;
      default:
        throw MotionTextPresetJsonException(
          'Unsupported interpolation kind `$raw`.',
        );
    }
  }

  static MotionInterpolationSpec _interpolationFromKind(
    MotionInterpolationKind kind,
  ) {
    switch (kind) {
      case MotionInterpolationKind.hold:
        return const MotionInterpolationSpec.hold();
      case MotionInterpolationKind.linear:
        return const MotionInterpolationSpec.linear();
      case MotionInterpolationKind.bounce:
        return const MotionInterpolationSpec.bounce();
      case MotionInterpolationKind.elastic:
        return const MotionInterpolationSpec.elastic();
      case MotionInterpolationKind.easeIn:
        return const MotionInterpolationSpec.easeIn();
      case MotionInterpolationKind.easeOut:
        return const MotionInterpolationSpec.easeOut();
      case MotionInterpolationKind.easeInOut:
        return const MotionInterpolationSpec.easeInOut();
      case MotionInterpolationKind.cubicBezier:
        return const MotionInterpolationSpec.cubicBezier(
          bezier: MotionBezierControlPoints(
            x1: 0.25,
            y1: 0.1,
            x2: 0.25,
            y2: 1.0,
          ),
        );
      case MotionInterpolationKind.spring:
        return const MotionInterpolationSpec.spring();
    }
  }

  static MotionTextRevealUnit _readRevealUnit(Object? raw) {
    final value = raw?.toString().trim();
    switch (value) {
      case null:
      case '':
      case 'wholeText':
        return MotionTextRevealUnit.wholeText;
      case 'word':
        return MotionTextRevealUnit.word;
      case 'letter':
        return MotionTextRevealUnit.letter;
      default:
        throw MotionTextPresetJsonException(
          'Unsupported reveal unit `$value`.',
        );
    }
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = _readOptionalString(json, key);
    if (value == null || value.isEmpty) {
      throw MotionTextPresetJsonException('Missing required `$key`.');
    }
    return value;
  }

  static String? _readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    return value.toString();
  }

  static int _readRequiredIntAlias(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) {
        continue;
      }
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      throw MotionTextPresetJsonException('`$key` must be a number.');
    }
    throw MotionTextPresetJsonException(
      'Missing required `${keys.join(' or ')}`.',
    );
  }

  static int? _readOptionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw MotionTextPresetJsonException('`$key` must be a number.');
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      throw MotionTextPresetJsonException('Missing required `$key`.');
    }
    return _toDouble(value);
  }

  static double? _readOptionalDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    return _toDouble(value);
  }

  static double _toDouble(Object value) {
    if (value is num) {
      return value.toDouble();
    }
    throw MotionTextPresetJsonException('`$value` must be numeric.');
  }

  static final Map<String, MotionPropertyDefinition> _propertyDefinitionById =
      <String, MotionPropertyDefinition>{
    MotionPropertyCatalog.positionX.id: MotionPropertyCatalog.positionX,
    MotionPropertyCatalog.positionY.id: MotionPropertyCatalog.positionY,
    MotionPropertyCatalog.scaleX.id: MotionPropertyCatalog.scaleX,
    MotionPropertyCatalog.scaleY.id: MotionPropertyCatalog.scaleY,
    MotionPropertyCatalog.rotationDegrees.id:
        MotionPropertyCatalog.rotationDegrees,
    MotionPropertyCatalog.opacity.id: MotionPropertyCatalog.opacity,
    MotionPropertyCatalog.blurAmount.id: MotionPropertyCatalog.blurAmount,
    MotionPropertyCatalog.blurHorizontal.id:
        MotionPropertyCatalog.blurHorizontal,
    MotionPropertyCatalog.blurVertical.id: MotionPropertyCatalog.blurVertical,
    MotionPropertyCatalog.blurMix.id: MotionPropertyCatalog.blurMix,
    MotionPropertyCatalog.blurEdgeMode.id: MotionPropertyCatalog.blurEdgeMode,
    MotionPropertyCatalog.blurCrop.id: MotionPropertyCatalog.blurCrop,
    MotionPropertyCatalog.fontSize.id: MotionPropertyCatalog.fontSize,
    MotionPropertyCatalog.letterSpacing.id: MotionPropertyCatalog.letterSpacing,
    MotionPropertyCatalog.revealProgress.id:
        MotionPropertyCatalog.revealProgress,
    MotionPropertyCatalog.width.id: MotionPropertyCatalog.width,
    MotionPropertyCatalog.height.id: MotionPropertyCatalog.height,
    MotionPropertyCatalog.cornerRadius.id: MotionPropertyCatalog.cornerRadius,
  };
}
