import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_interpolation_parsing.dart';
import '../models/professional_motion_models.dart';
import '../models/professional_motion_text_models.dart';
import '../models/professional_motion_text_preset_serialization.dart';

enum ScopedTextMotionScriptFormat {
  json,
  yaml,
  jsx,
  unknown,
}

enum ScopedTextMotionScriptIssueSeverity {
  error,
  warning,
  info,
}

@immutable
class ScopedTextMotionScriptIssue {
  const ScopedTextMotionScriptIssue({
    required this.severity,
    required this.message,
    this.path,
  });

  final ScopedTextMotionScriptIssueSeverity severity;
  final String message;
  final String? path;
}

@immutable
class ScopedTextMotionScriptKeyframeSpec {
  const ScopedTextMotionScriptKeyframeSpec({
    required this.time,
    required this.value,
    required this.interpolation,
  });

  final TimelineTime time;
  final MotionPropertyValue value;
  final MotionInterpolationSpec interpolation;
}

@immutable
class ScopedTextMotionScriptChannelSpec {
  const ScopedTextMotionScriptChannelSpec({
    required this.property,
    required this.keyframes,
  });

  final String property;
  final List<ScopedTextMotionScriptKeyframeSpec> keyframes;
}

@immutable
class ScopedTextMotionScriptDocument {
  const ScopedTextMotionScriptDocument({
    required this.schemaVersion,
    required this.sourceFormat,
    this.name,
    this.revealUnit,
    this.revealDirection = MotionTextRevealDirection.forward,
    this.channels = const <ScopedTextMotionScriptChannelSpec>[],
    this.animationBlocks = const <MotionTextAnimationBlock>[],
  });

  final String schemaVersion;
  final ScopedTextMotionScriptFormat sourceFormat;
  final String? name;
  final MotionTextRevealUnit? revealUnit;
  final MotionTextRevealDirection revealDirection;
  final List<ScopedTextMotionScriptChannelSpec> channels;
  final List<MotionTextAnimationBlock> animationBlocks;

  bool get hasContent => channels.isNotEmpty || animationBlocks.isNotEmpty;
}

@immutable
class ScopedTextMotionScriptValidationResult {
  const ScopedTextMotionScriptValidationResult({
    required this.format,
    required this.issues,
    this.document,
  });

  final ScopedTextMotionScriptFormat format;
  final List<ScopedTextMotionScriptIssue> issues;
  final ScopedTextMotionScriptDocument? document;

  bool get canApply =>
      document != null &&
      document!.hasContent &&
      !issues.any(
        (issue) => issue.severity == ScopedTextMotionScriptIssueSeverity.error,
      );

  int get channelCount => document?.channels.length ?? 0;

  int get animationBlockCount => document?.animationBlocks.length ?? 0;
}

class ScopedTextMotionScriptImportService {
  const ScopedTextMotionScriptImportService();

  static const String defaultSchemaVersion = 'refusion.scope-text-script/v1';

  ScopedTextMotionScriptValidationResult validate({
    required String source,
    String? fileName,
  }) {
    final trimmed = _normalizeSourceString(source);
    final format = _detectFormat(trimmed, fileName: fileName);
    final issues = <ScopedTextMotionScriptIssue>[];

    if (trimmed.isEmpty) {
      issues.add(
        const ScopedTextMotionScriptIssue(
          severity: ScopedTextMotionScriptIssueSeverity.error,
          message: 'Paste or upload a script before validating.',
          path: 'source',
        ),
      );
      return ScopedTextMotionScriptValidationResult(
        format: format,
        issues: List<ScopedTextMotionScriptIssue>.unmodifiable(issues),
      );
    }

    if (format == ScopedTextMotionScriptFormat.jsx) {
      issues.add(
        const ScopedTextMotionScriptIssue(
          severity: ScopedTextMotionScriptIssueSeverity.error,
          message:
              'JSX adapters are not supported in this build yet. Convert the motion to canonical JSON or YAML first.',
          path: 'source',
        ),
      );
      return ScopedTextMotionScriptValidationResult(
        format: format,
        issues: List<ScopedTextMotionScriptIssue>.unmodifiable(issues),
      );
    }

    final structured = _decodeStructuredSource(
      trimmed,
      format: format,
      issues: issues,
    );
    if (structured is! Map<String, dynamic>) {
      if (issues.isEmpty) {
        issues.add(
          const ScopedTextMotionScriptIssue(
            severity: ScopedTextMotionScriptIssueSeverity.error,
            message: 'The script root must be a single object.',
            path: 'source',
          ),
        );
      }
      return ScopedTextMotionScriptValidationResult(
        format: format,
        issues: List<ScopedTextMotionScriptIssue>.unmodifiable(issues),
      );
    }

    final schemaVersion = _readOptionalString(structured, <String>[
          'schemaVersion',
          'schema',
          'version',
        ]) ??
        defaultSchemaVersion;
    final name = _readOptionalString(structured, <String>[
      'name',
      'label',
      'title',
    ]);

    final channels = _readChannels(
      structured,
      issues: issues,
    );
    final animationBlocks = _readAnimationBlocks(
      structured,
      issues: issues,
    );
    final revealUnit = _readRevealUnit(structured) ??
        _deriveRevealUnitFromBlocks(animationBlocks);
    final revealDirection = _readRevealDirection(structured);

    if (channels.isEmpty && animationBlocks.isEmpty) {
      issues.add(
        const ScopedTextMotionScriptIssue(
          severity: ScopedTextMotionScriptIssueSeverity.error,
          message:
              'No supported motion content was found. Add `channels` or `animationBlocks`.',
          path: 'source',
        ),
      );
    }

    final document = ScopedTextMotionScriptDocument(
      schemaVersion: schemaVersion,
      sourceFormat: format,
      name: name,
      revealUnit: revealUnit,
      revealDirection: revealDirection,
      channels: List<ScopedTextMotionScriptChannelSpec>.unmodifiable(channels),
      animationBlocks: List<MotionTextAnimationBlock>.unmodifiable(
        animationBlocks,
      ),
    );
    return ScopedTextMotionScriptValidationResult(
      format: format,
      document: document,
      issues: List<ScopedTextMotionScriptIssue>.unmodifiable(issues),
    );
  }

  String _normalizeSourceString(String source) {
    final trimmed = source.trim();
    if (!trimmed.startsWith('```')) {
      return trimmed;
    }
    final lines = trimmed.split('\n');
    final cleaned = <String>[];
    for (final line in lines) {
      if (line.trim().startsWith('```')) {
        continue;
      }
      cleaned.add(line);
    }
    return cleaned.join('\n').trim();
  }

  ScopedTextMotionScriptFormat _detectFormat(
    String source, {
    String? fileName,
  }) {
    final normalizedFileName = fileName?.trim().toLowerCase();
    if (normalizedFileName != null && normalizedFileName.contains('.')) {
      if (normalizedFileName.endsWith('.json')) {
        return ScopedTextMotionScriptFormat.json;
      }
      if (normalizedFileName.endsWith('.yaml') ||
          normalizedFileName.endsWith('.yml')) {
        return ScopedTextMotionScriptFormat.yaml;
      }
      if (normalizedFileName.endsWith('.jsx') ||
          normalizedFileName.endsWith('.tsx') ||
          normalizedFileName.endsWith('.js') ||
          normalizedFileName.endsWith('.ts')) {
        return ScopedTextMotionScriptFormat.jsx;
      }
    }
    if (source.startsWith('{') || source.startsWith('[')) {
      return ScopedTextMotionScriptFormat.json;
    }
    if (source.contains('export default') ||
        source.contains('<Sequence') ||
        source.contains('function ') ||
        source.contains('const ') ||
        source.contains('=>')) {
      return ScopedTextMotionScriptFormat.jsx;
    }
    if (source.contains(':')) {
      return ScopedTextMotionScriptFormat.yaml;
    }
    return ScopedTextMotionScriptFormat.unknown;
  }

  Map<String, dynamic>? _decodeStructuredSource(
    String source, {
    required ScopedTextMotionScriptFormat format,
    required List<ScopedTextMotionScriptIssue> issues,
  }) {
    try {
      switch (format) {
        case ScopedTextMotionScriptFormat.json:
          final decoded = jsonDecode(source);
          if (decoded is! Map) {
            return null;
          }
          return _deepConvertToDynamicMap(decoded);
        case ScopedTextMotionScriptFormat.yaml:
        case ScopedTextMotionScriptFormat.unknown:
          final decoded = loadYaml(source);
          if (decoded is! YamlMap && decoded is! Map) {
            return null;
          }
          return _deepConvertToDynamicMap(decoded);
        case ScopedTextMotionScriptFormat.jsx:
          return null;
      }
    } catch (error) {
      issues.add(
        ScopedTextMotionScriptIssue(
          severity: ScopedTextMotionScriptIssueSeverity.error,
          message: 'Unable to parse the script: $error',
          path: 'source',
        ),
      );
      return null;
    }
  }

  Map<String, dynamic> _deepConvertToDynamicMap(Object? value) {
    if (value is YamlMap) {
      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _deepConvertYamlValue(nestedValue),
        ),
      );
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _deepConvertYamlValue(nestedValue),
        ),
      );
    }
    return const <String, dynamic>{};
  }

  Object? _deepConvertYamlValue(Object? value) {
    if (value is YamlMap) {
      return _deepConvertToDynamicMap(value);
    }
    if (value is Map) {
      return _deepConvertToDynamicMap(value);
    }
    if (value is YamlList) {
      return value.map<Object?>((item) => _deepConvertYamlValue(item)).toList(
            growable: false,
          );
    }
    if (value is List) {
      return value.map<Object?>((item) => _deepConvertYamlValue(item)).toList(
            growable: false,
          );
    }
    return value;
  }

  List<ScopedTextMotionScriptChannelSpec> _readChannels(
    Map<String, dynamic> json, {
    required List<ScopedTextMotionScriptIssue> issues,
  }) {
    final source = _readFirstList(json, <String>[
      'channels',
      'animations',
      'properties',
      'tracks',
    ]);
    if (source == null) {
      return const <ScopedTextMotionScriptChannelSpec>[];
    }
    final channels = <ScopedTextMotionScriptChannelSpec>[];
    for (var index = 0; index < source.length; index++) {
      final item = source[index];
      if (item is! Map) {
        issues.add(
          ScopedTextMotionScriptIssue(
            severity: ScopedTextMotionScriptIssueSeverity.error,
            message: 'Each channel must be an object.',
            path: 'channels[$index]',
          ),
        );
        continue;
      }
      final channelJson = _deepConvertToDynamicMap(item);
      final property = _normalizePropertyName(
        _readOptionalString(channelJson, <String>[
          'property',
          'id',
          'name',
        ]),
      );
      if (property == null) {
        issues.add(
          ScopedTextMotionScriptIssue(
            severity: ScopedTextMotionScriptIssueSeverity.error,
            message: 'Channel is missing a supported `property` name.',
            path: 'channels[$index].property',
          ),
        );
        continue;
      }
      final keyframesSource = _readFirstList(channelJson, <String>[
        'keyframes',
        'keys',
      ]);
      if (keyframesSource == null || keyframesSource.isEmpty) {
        issues.add(
          ScopedTextMotionScriptIssue(
            severity: ScopedTextMotionScriptIssueSeverity.error,
            message: 'Channel `$property` needs at least one keyframe.',
            path: 'channels[$index].keyframes',
          ),
        );
        continue;
      }
      final keyframes = <ScopedTextMotionScriptKeyframeSpec>[];
      for (var keyframeIndex = 0;
          keyframeIndex < keyframesSource.length;
          keyframeIndex++) {
        final keyframeItem = keyframesSource[keyframeIndex];
        if (keyframeItem is! Map) {
          issues.add(
            ScopedTextMotionScriptIssue(
              severity: ScopedTextMotionScriptIssueSeverity.error,
              message: 'Each keyframe must be an object.',
              path: 'channels[$index].keyframes[$keyframeIndex]',
            ),
          );
          continue;
        }
        final keyframeJson = _deepConvertToDynamicMap(keyframeItem);
        final keyframe = _readKeyframe(
          property: property,
          json: keyframeJson,
          path: 'channels[$index].keyframes[$keyframeIndex]',
          fps: _readOptionalDouble(json, <String>['fps']),
          issues: issues,
        );
        if (keyframe != null) {
          keyframes.add(keyframe);
        }
      }
      if (keyframes.isEmpty) {
        continue;
      }
      keyframes.sort((left, right) => left.time.compareTo(right.time));
      channels.add(
        ScopedTextMotionScriptChannelSpec(
          property: property,
          keyframes: List<ScopedTextMotionScriptKeyframeSpec>.unmodifiable(
            keyframes,
          ),
        ),
      );
    }
    return List<ScopedTextMotionScriptChannelSpec>.unmodifiable(channels);
  }

  ScopedTextMotionScriptKeyframeSpec? _readKeyframe({
    required String property,
    required Map<String, dynamic> json,
    required String path,
    required double? fps,
    required List<ScopedTextMotionScriptIssue> issues,
  }) {
    final timeMs = _readKeyframeTimeMs(json, fps: fps);
    if (timeMs == null) {
      issues.add(
        ScopedTextMotionScriptIssue(
          severity: ScopedTextMotionScriptIssueSeverity.error,
          message: 'Keyframe is missing `timeMs`, `time`, `ms`, or `frame`.',
          path: '$path.time',
        ),
      );
      return null;
    }
    final value = _readKeyframeValue(
      property: property,
      json: json,
      path: path,
      issues: issues,
    );
    if (value == null) {
      return null;
    }
    final interpolation = _readInterpolation(
      json['easing'] ?? json['interpolation'] ?? json['ease'],
      path: '$path.easing',
      issues: issues,
    );
    return ScopedTextMotionScriptKeyframeSpec(
      time: TimelineTime.fromMilliseconds(timeMs),
      value: value,
      interpolation: interpolation,
    );
  }

  int? _readKeyframeTimeMs(
    Map<String, dynamic> json, {
    required double? fps,
  }) {
    final scalar = _readOptionalDouble(json, <String>[
      'timeMs',
      'time',
      'ms',
    ]);
    if (scalar != null) {
      return scalar.round();
    }
    final frame = _readOptionalDouble(json, <String>['frame', 'frames']);
    if (frame != null) {
      final safeFps = (fps == null || fps <= 0) ? 30.0 : fps;
      return ((frame / safeFps) * 1000.0).round();
    }
    return null;
  }

  MotionPropertyValue? _readKeyframeValue({
    required String property,
    required Map<String, dynamic> json,
    required String path,
    required List<ScopedTextMotionScriptIssue> issues,
  }) {
    final rawValue = json.containsKey('value')
        ? json['value']
        : (json.containsKey('amount') ? json['amount'] : null);
    switch (property) {
      case 'position':
        final point = _readPoint2D(rawValue ?? json, axesFallback: json);
        if (point == null) {
          issues.add(
            ScopedTextMotionScriptIssue(
              severity: ScopedTextMotionScriptIssueSeverity.error,
              message:
                  'Position keyframes need `value: {x, y}` or top-level `x` and `y`.',
              path: '$path.value',
            ),
          );
          return null;
        }
        return MotionPropertyValue.point2D(point);
      case 'scale':
        if (rawValue is num) {
          final uniform = rawValue.toDouble();
          return MotionPropertyValue.point2D(
            MotionPoint2D(x: uniform, y: uniform),
          );
        }
        final scalePoint = _readPoint2D(rawValue ?? json, axesFallback: json);
        if (scalePoint == null) {
          issues.add(
            ScopedTextMotionScriptIssue(
              severity: ScopedTextMotionScriptIssueSeverity.error,
              message: 'Scale keyframes need a number or `value: {x, y}`.',
              path: '$path.value',
            ),
          );
          return null;
        }
        return MotionPropertyValue.point2D(scalePoint);
      default:
        final scalar = _asDouble(rawValue);
        if (scalar == null) {
          issues.add(
            ScopedTextMotionScriptIssue(
              severity: ScopedTextMotionScriptIssueSeverity.error,
              message: 'Property `$property` expects a numeric `value`.',
              path: '$path.value',
            ),
          );
          return null;
        }
        return MotionPropertyValue.scalar(scalar);
    }
  }

  MotionPoint2D? _readPoint2D(
    Object? value, {
    Map<String, dynamic>? axesFallback,
  }) {
    Map<String, dynamic>? pointMap;
    if (value is Map) {
      pointMap = _deepConvertToDynamicMap(value);
    }
    pointMap ??= axesFallback;
    if (pointMap == null) {
      return null;
    }
    final x = _readOptionalDouble(pointMap, <String>['x']);
    final y = _readOptionalDouble(pointMap, <String>['y']);
    if (x == null || y == null) {
      return null;
    }
    return MotionPoint2D(x: x, y: y);
  }

  MotionInterpolationSpec _readInterpolation(
    Object? raw, {
    required String path,
    required List<ScopedTextMotionScriptIssue> issues,
  }) {
    if (raw == null) {
      return const MotionInterpolationSpec.easeInOut();
    }
    if (raw is String) {
      final interpolation = tryParseNamedMotionInterpolationSpec(raw);
      if (interpolation != null) {
        return interpolation;
      }
    }
    if (raw is Map) {
      try {
        return parseCanonicalMotionInterpolationObject(
          _deepConvertToDynamicMap(raw),
        );
      } on MotionInterpolationParseException catch (error) {
        issues.add(
          ScopedTextMotionScriptIssue(
            severity: ScopedTextMotionScriptIssueSeverity.warning,
            message: error.message,
            path: path,
          ),
        );
        return const MotionInterpolationSpec.easeInOut();
      }
    }
    issues.add(
      ScopedTextMotionScriptIssue(
        severity: ScopedTextMotionScriptIssueSeverity.warning,
        message:
            'Unsupported easing was replaced with easeInOut for compatibility.',
        path: path,
      ),
    );
    return const MotionInterpolationSpec.easeInOut();
  }

  List<MotionTextAnimationBlock> _readAnimationBlocks(
    Map<String, dynamic> json, {
    required List<ScopedTextMotionScriptIssue> issues,
  }) {
    final hasBlockSource = json.containsKey('animationBlocks') ||
        json.containsKey('motions') ||
        json.containsKey('blocks');
    if (!hasBlockSource) {
      return const <MotionTextAnimationBlock>[];
    }
    try {
      final preset = MotionTextPresetJsonCodec.fromJson(json);
      return preset.animationBlocks;
    } on MotionTextPresetJsonException catch (error) {
      issues.add(
        ScopedTextMotionScriptIssue(
          severity: ScopedTextMotionScriptIssueSeverity.error,
          message: error.message,
          path: 'animationBlocks',
        ),
      );
      return const <MotionTextAnimationBlock>[];
    }
  }

  MotionTextRevealUnit? _readRevealUnit(Map<String, dynamic> json) {
    final reveal = json['reveal'];
    if (reveal is Map) {
      final revealJson = _deepConvertToDynamicMap(reveal);
      final value = _readOptionalString(revealJson, <String>['by', 'unit']);
      final unit = _normalizeRevealUnit(value);
      if (unit != null) {
        return unit;
      }
    }
    final value = _readOptionalString(json, <String>['revealBy']);
    return _normalizeRevealUnit(value);
  }

  MotionTextRevealDirection _readRevealDirection(Map<String, dynamic> json) {
    final reveal = json['reveal'];
    if (reveal is Map) {
      final revealJson = _deepConvertToDynamicMap(reveal);
      final value = _readOptionalString(revealJson, <String>['direction']);
      final direction = _normalizeRevealDirection(value);
      if (direction != null) {
        return direction;
      }
    }
    final value = _readOptionalString(json, <String>['revealDirection']);
    return _normalizeRevealDirection(value) ??
        MotionTextRevealDirection.forward;
  }

  MotionTextRevealUnit? _deriveRevealUnitFromBlocks(
    List<MotionTextAnimationBlock> animationBlocks,
  ) {
    for (final block in animationBlocks) {
      if (block.revealSpec != null) {
        return block.revealSpec!.unit;
      }
      if (block.kind == MotionTextAnimationKind.wordReveal) {
        return MotionTextRevealUnit.word;
      }
      if (block.kind == MotionTextAnimationKind.letterReveal ||
          block.kind == MotionTextAnimationKind.typewriter) {
        return MotionTextRevealUnit.letter;
      }
    }
    return null;
  }

  MotionTextRevealUnit? _normalizeRevealUnit(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'word':
      case 'words':
        return MotionTextRevealUnit.word;
      case 'letter':
      case 'letters':
      case 'character':
      case 'characters':
        return MotionTextRevealUnit.letter;
      case 'whole':
      case 'wholetext':
      case 'whole_text':
      case 'whole-text':
      case 'text':
        return MotionTextRevealUnit.wholeText;
    }
    return null;
  }

  MotionTextRevealDirection? _normalizeRevealDirection(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'reverse':
      case 'backward':
      case 'rtl':
        return MotionTextRevealDirection.reverse;
      case 'forward':
      case 'ltr':
        return MotionTextRevealDirection.forward;
    }
    return null;
  }

  String? _normalizePropertyName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'opacity':
      case 'alpha':
      case 'fade':
        return 'opacity';
      case 'position':
      case 'translate':
      case 'move':
        return 'position';
      case 'positionx':
      case 'position_x':
      case 'position-x':
      case 'x':
        return 'positionX';
      case 'positiony':
      case 'position_y':
      case 'position-y':
      case 'y':
        return 'positionY';
      case 'scale':
      case 'uniformscale':
      case 'scalepercent':
      case 'zoom':
        return 'scale';
      case 'scalex':
      case 'scale_x':
      case 'scale-x':
        return 'scaleX';
      case 'scaley':
      case 'scale_y':
      case 'scale-y':
        return 'scaleY';
      case 'rotation':
      case 'rotationdegrees':
      case 'angle':
        return 'rotation';
      case 'blur':
      case 'bluramount':
      case 'gaussianblur':
      case 'gaussian_blur':
      case 'gaussian-blur':
        return 'blur';
      case 'reveal':
      case 'revealprogress':
      case 'reveal_progress':
      case 'reveal-progress':
      case 'typeon':
      case 'type_on':
      case 'type-on':
        return 'revealProgress';
    }
    return null;
  }

  List<dynamic>? _readFirstList(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is List) {
        return value;
      }
    }
    return null;
  }

  String? _readOptionalString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  double? _readOptionalDouble(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _asDouble(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}
