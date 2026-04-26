import 'dart:convert';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_interpolation_parsing.dart';
import '../models/professional_motion_models.dart';
import '../models/refusion_scene_program_models.dart';

class ReFusionSceneProgramImportService {
  const ReFusionSceneProgramImportService();

  ReFusionSceneProgramValidationResult validate({
    required String source,
    String? fileName,
  }) {
    final issues = <ReFusionSceneProgramIssue>[];
    final trimmed = _normalizeSourceString(source);
    if (trimmed.isEmpty) {
      return const ReFusionSceneProgramValidationResult(
        issues: <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.emptySource,
            message: 'Paste or upload a ReFusion scene program first.',
            path: 'source',
          ),
        ],
      );
    }

    if (fileName != null && !fileName.trim().toLowerCase().endsWith('.json')) {
      return const ReFusionSceneProgramValidationResult(
        issues: <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.invalidFileType,
            message: 'ReFusion scene programs must be JSON files.',
            path: 'fileName',
          ),
        ],
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      return ReFusionSceneProgramValidationResult(
        issues: <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.invalidJson,
            message: 'Scene program must be valid JSON: ${error.message}.',
            path: 'source',
          ),
        ],
      );
    }

    final root = _asStringKeyedMap(decoded);
    if (root == null) {
      return const ReFusionSceneProgramValidationResult(
        issues: <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.rootNotObject,
            message: 'Scene program root must be a JSON object.',
            path: 'source',
          ),
        ],
      );
    }

    _rejectExecutableFields(root, issues);
    final document = _readDocument(root, issues);
    return ReFusionSceneProgramValidationResult(
      document: issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      )
          ? null
          : document,
      issues: List<ReFusionSceneProgramIssue>.unmodifiable(issues),
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

  ReFusionSceneProgramDocument _readDocument(
    Map<String, dynamic> json,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    final kind = _readString(json, 'kind');
    if (kind != null && kind != 'refusion.sceneProgram') {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.invalidKind,
          message: 'Scene program kind must be `refusion.sceneProgram`.',
          path: 'kind',
        ),
      );
    }

    final schemaVersion = _readString(json, 'schemaVersion');
    if (schemaVersion == null) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.missingSchemaVersion,
          message: '`schemaVersion` is required.',
          path: 'schemaVersion',
        ),
      );
    } else if (schemaVersion != kReFusionSceneProgramSchemaVersion) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.unsupportedSchemaVersion,
          message:
              'Unsupported scene program schema `$schemaVersion`. Expected `$kReFusionSceneProgramSchemaVersion`.',
          path: 'schemaVersion',
        ),
      );
    }

    final id = _requiredString(json, 'id', issues) ?? 'invalid-scene-program';
    final duration = _readDuration(json, issues);
    final elements = _readElements(json, issues);
    final channels = _readChannels(json, issues);

    return ReFusionSceneProgramDocument(
      schemaVersion: schemaVersion ?? kReFusionSceneProgramSchemaVersion,
      id: id,
      name: _readString(json, 'name') ?? _readString(json, 'label'),
      duration: duration,
      elements: elements,
      channels: channels,
    );
  }

  TimelineTime _readDuration(
    Map<String, dynamic> json,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    final durationMs = _readNumber(json, 'durationMs');
    if (durationMs != null) {
      if (durationMs <= 0) {
        issues.add(
          const ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.invalidDuration,
            message: '`durationMs` must be greater than zero.',
            path: 'durationMs',
          ),
        );
        return TimelineTime.zero;
      }
      return TimelineTime.fromMilliseconds(durationMs.round());
    }

    final durationSeconds = _readNumber(json, 'durationSeconds');
    if (durationSeconds != null) {
      if (durationSeconds <= 0) {
        issues.add(
          const ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.invalidDuration,
            message: '`durationSeconds` must be greater than zero.',
            path: 'durationSeconds',
          ),
        );
        return TimelineTime.zero;
      }
      return TimelineTime.fromSecondsDouble(durationSeconds);
    }

    issues.add(
      const ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        code: ReFusionSceneProgramIssueCode.missingRequiredField,
        message: '`durationMs` is required.',
        path: 'durationMs',
      ),
    );
    return TimelineTime.zero;
  }

  List<ReFusionSceneProgramElementSpec> _readElements(
    Map<String, dynamic> json,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    final raw = json['elements'];
    if (raw == null) {
      return const <ReFusionSceneProgramElementSpec>[];
    }
    if (raw is! List) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.invalidList,
          message: '`elements` must be a list.',
          path: 'elements',
        ),
      );
      return const <ReFusionSceneProgramElementSpec>[];
    }

    final elements = <ReFusionSceneProgramElementSpec>[];
    for (var index = 0; index < raw.length; index += 1) {
      final path = 'elements[$index]';
      final entry = _asStringKeyedMap(raw[index]);
      if (entry == null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.invalidObject,
            message: 'Element entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final id = _requiredString(entry, 'id', issues, path: '$path.id');
      final kind = _readElementKind(entry, issues, path: '$path.kind');
      if (id == null || kind == null) {
        continue;
      }
      elements.add(
        ReFusionSceneProgramElementSpec(
          id: id,
          kind: kind,
          layerId: _readString(entry, 'layerId'),
          text: _readString(entry, 'text'),
          range: _readOptionalRange(entry, issues, path: '$path.range'),
        ),
      );
    }
    return List<ReFusionSceneProgramElementSpec>.unmodifiable(elements);
  }

  List<ReFusionSceneProgramChannelSpec> _readChannels(
    Map<String, dynamic> json,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    final raw = json['channels'];
    if (raw == null) {
      return const <ReFusionSceneProgramChannelSpec>[];
    }
    if (raw is! List) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.invalidList,
          message: '`channels` must be a list.',
          path: 'channels',
        ),
      );
      return const <ReFusionSceneProgramChannelSpec>[];
    }

    final channels = <ReFusionSceneProgramChannelSpec>[];
    for (var index = 0; index < raw.length; index += 1) {
      final path = 'channels[$index]';
      final entry = _asStringKeyedMap(raw[index]);
      if (entry == null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.invalidObject,
            message: 'Channel entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final id = _readString(entry, 'id') ?? 'scene-program.channel.$index';
      final targetId =
          _requiredString(entry, 'targetId', issues, path: '$path.targetId');
      final propertyId = _requiredString(
        entry,
        'property',
        issues,
        path: '$path.property',
      );
      final definition =
          propertyId == null ? null : _propertyDefinitionFor(propertyId);
      if (propertyId != null && definition == null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.unsupportedProperty,
            message: 'Unsupported motion property `$propertyId`.',
            path: '$path.property',
          ),
        );
      }
      if (targetId == null || definition == null) {
        continue;
      }
      final keyframes = _readKeyframes(
        entry,
        definition: definition,
        issues: issues,
        path: '$path.keyframes',
      );
      if (keyframes.isEmpty) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.emptyKeyframes,
            message: 'Channel `$id` must declare at least one keyframe.',
            path: '$path.keyframes',
          ),
        );
        continue;
      }
      channels.add(
        ReFusionSceneProgramChannelSpec(
          id: id,
          targetId: targetId,
          definition: definition,
          keyframes: keyframes,
        ),
      );
    }
    return List<ReFusionSceneProgramChannelSpec>.unmodifiable(channels);
  }

  List<ReFusionSceneProgramKeyframeSpec> _readKeyframes(
    Map<String, dynamic> json, {
    required MotionPropertyDefinition definition,
    required List<ReFusionSceneProgramIssue> issues,
    required String path,
  }) {
    final raw = json['keyframes'];
    if (raw is! List) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.invalidList,
          message: '`keyframes` must be a list.',
          path: path,
        ),
      );
      return const <ReFusionSceneProgramKeyframeSpec>[];
    }
    final keyframes = <ReFusionSceneProgramKeyframeSpec>[];
    for (var index = 0; index < raw.length; index += 1) {
      final entry = _asStringKeyedMap(raw[index]);
      final keyframePath = '$path[$index]';
      if (entry == null) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.invalidObject,
            message: 'Keyframe entry must be an object.',
            path: keyframePath,
          ),
        );
        continue;
      }
      final time = _readKeyframeTime(entry, issues, path: keyframePath);
      final value = _readKeyframeValue(
        entry['value'],
        definition,
        issues,
        path: '$keyframePath.value',
      );
      final interpolation =
          _readInterpolation(entry, issues, path: keyframePath);
      if (time == null || value == null) {
        continue;
      }
      keyframes.add(
        ReFusionSceneProgramKeyframeSpec(
          time: time,
          value: value,
          interpolation: interpolation,
        ),
      );
    }
    keyframes.sort((left, right) => left.time.compareTo(right.time));
    return List<ReFusionSceneProgramKeyframeSpec>.unmodifiable(keyframes);
  }

  TimelineTime? _readKeyframeTime(
    Map<String, dynamic> json,
    List<ReFusionSceneProgramIssue> issues, {
    required String path,
  }) {
    final timeMs = _readNumber(json, 'timeMs');
    if (timeMs != null) {
      return TimelineTime.fromMilliseconds(timeMs.round());
    }
    final timeSeconds =
        _readNumber(json, 'timeSeconds') ?? _readNumber(json, 'time');
    if (timeSeconds != null) {
      return TimelineTime.fromSecondsDouble(timeSeconds);
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        code: ReFusionSceneProgramIssueCode.missingRequiredField,
        message: 'Keyframe time must use `timeMs` or `timeSeconds`.',
        path: '$path.timeMs',
      ),
    );
    return null;
  }

  MotionPropertyValue? _readKeyframeValue(
    Object? raw,
    MotionPropertyDefinition definition,
    List<ReFusionSceneProgramIssue> issues, {
    required String path,
  }) {
    switch (definition.valueKind) {
      case MotionPropertyValueKind.scalar:
        final value = _coerceNumber(raw);
        if (value == null) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              code: ReFusionSceneProgramIssueCode.invalidValue,
              message: 'Value for `${definition.id}` must be numeric.',
              path: path,
            ),
          );
          return null;
        }
        return MotionPropertyValue.scalar(value);
      case MotionPropertyValueKind.integer:
        final value = _coerceNumber(raw);
        if (value == null) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              code: ReFusionSceneProgramIssueCode.invalidValue,
              message: 'Value for `${definition.id}` must be numeric.',
              path: path,
            ),
          );
          return null;
        }
        return MotionPropertyValue.integer(value.round());
      case MotionPropertyValueKind.boolean:
      case MotionPropertyValueKind.stringValue:
      case MotionPropertyValueKind.colorArgb:
      case MotionPropertyValueKind.point2D:
      case MotionPropertyValueKind.size2D:
      case MotionPropertyValueKind.rect:
      case MotionPropertyValueKind.enumValue:
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.unsupportedValueKind,
            message:
                'Scene Program V1 currently supports scalar/integer keyframe values only.',
            path: path,
          ),
        );
        return null;
    }
  }

  MotionInterpolationSpec _readInterpolation(
    Map<String, dynamic> json,
    List<ReFusionSceneProgramIssue> issues, {
    required String path,
  }) {
    final raw = json['interpolation'] ?? json['easing'] ?? json['ease'];
    if (raw == null) {
      return const MotionInterpolationSpec.linear();
    }
    if (raw is String) {
      final parsed = tryParseNamedMotionInterpolationSpec(raw);
      if (parsed != null) {
        return parsed;
      }
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.invalidValue,
          message: 'Unsupported interpolation `$raw`.',
          path: '$path.interpolation',
        ),
      );
      return const MotionInterpolationSpec.linear();
    }
    final object = _asStringKeyedMap(raw);
    if (object == null) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.invalidObject,
          message: '`interpolation` must be a string or object.',
          path: '$path.interpolation',
        ),
      );
      return const MotionInterpolationSpec.linear();
    }
    try {
      return parseCanonicalMotionInterpolationObject(object);
    } on MotionInterpolationParseException catch (error) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.invalidValue,
          message: error.message,
          path: '$path.interpolation',
        ),
      );
      return const MotionInterpolationSpec.linear();
    }
  }

  MotionElementKind? _readElementKind(
    Map<String, dynamic> json,
    List<ReFusionSceneProgramIssue> issues, {
    required String path,
  }) {
    final raw = _readString(json, 'kind') ?? _readString(json, 'type');
    switch (raw?.trim().toLowerCase()) {
      case 'text':
        return MotionElementKind.text;
      case 'shape':
        return MotionElementKind.shape;
      case 'image':
        return MotionElementKind.image;
      case 'video':
      case 'videoclip':
        return MotionElementKind.videoClip;
      case null:
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.missingRequiredField,
            message: 'Element `kind` is required.',
            path: path,
          ),
        );
        return null;
      default:
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            code: ReFusionSceneProgramIssueCode.invalidValue,
            message: 'Unsupported element kind `$raw`.',
            path: path,
          ),
        );
        return null;
    }
  }

  TimelineTimeRange? _readOptionalRange(
    Map<String, dynamic> json,
    List<ReFusionSceneProgramIssue> issues, {
    required String path,
  }) {
    final range = _asStringKeyedMap(json['range']);
    if (range == null) {
      return null;
    }
    final startMs = _readNumber(range, 'startMs');
    final endMs = _readNumber(range, 'endMs');
    if (startMs == null || endMs == null || endMs < startMs) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          code: ReFusionSceneProgramIssueCode.invalidDuration,
          message: '`range` must declare valid `startMs` and `endMs`.',
          path: path,
        ),
      );
      return null;
    }
    return TimelineTimeRange(
      start: TimelineTime.fromMilliseconds(startMs.round()),
      endExclusive: TimelineTime.fromMilliseconds(endMs.round()),
    );
  }

  MotionPropertyDefinition? _propertyDefinitionFor(String raw) {
    return _propertyDefinitionsByKey[_normalizePropertyKey(raw)];
  }

  static final Map<String, MotionPropertyDefinition> _propertyDefinitionsByKey =
      <String, MotionPropertyDefinition>{
    for (final definition in <MotionPropertyDefinition>[
      MotionPropertyCatalog.positionX,
      MotionPropertyCatalog.positionY,
      MotionPropertyCatalog.scaleX,
      MotionPropertyCatalog.scaleY,
      MotionPropertyCatalog.rotationDegrees,
      MotionPropertyCatalog.opacity,
      MotionPropertyCatalog.blurAmount,
      MotionPropertyCatalog.blurHorizontal,
      MotionPropertyCatalog.blurVertical,
      MotionPropertyCatalog.blurMix,
      MotionPropertyCatalog.blurEdgeMode,
      MotionPropertyCatalog.blurCrop,
      MotionPropertyCatalog.width,
      MotionPropertyCatalog.height,
    ]) ...<String, MotionPropertyDefinition>{
      _normalizePropertyKey(definition.id): definition,
      _normalizePropertyKey(definition.path.canonicalKey): definition,
    },
  };

  static String _normalizePropertyKey(String raw) {
    return raw.trim().toLowerCase().replaceAll('_', '.').replaceAll('-', '.');
  }

  String? _requiredString(
    Map<String, dynamic> json,
    String key,
    List<ReFusionSceneProgramIssue> issues, {
    String? path,
  }) {
    final value = _readString(json, key);
    if (value != null) {
      return value;
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        code: ReFusionSceneProgramIssueCode.missingRequiredField,
        message: '`$key` is required.',
        path: path ?? key,
      ),
    );
    return null;
  }

  String? _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double? _readNumber(Map<String, dynamic> json, String key) {
    return _coerceNumber(json[key]);
  }

  double? _coerceNumber(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  Map<String, dynamic>? _asStringKeyedMap(Object? value) {
    if (value is Map) {
      final converted = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          return null;
        }
        converted[key] = entry.value;
      }
      return converted;
    }
    return null;
  }

  void _rejectExecutableFields(
    Object? value,
    List<ReFusionSceneProgramIssue> issues, {
    String path = 'source',
  }) {
    const blockedKeys = <String>{
      'code',
      'script',
      'function',
      'eval',
      'import',
      'imports',
      'remoteImport',
      'remoteImports',
      'jsx',
      'javascript',
      'shaderSource',
    };
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key;
        final nextPath = key is String ? '$path.$key' : path;
        if (key is String && blockedKeys.contains(key)) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              code: ReFusionSceneProgramIssueCode.executableField,
              message:
                  'Scene programs must be declarative JSON; `$key` is not supported.',
              path: nextPath,
            ),
          );
        }
        _rejectExecutableFields(entry.value, issues, path: nextPath);
      }
    } else if (value is List) {
      for (var index = 0; index < value.length; index += 1) {
        _rejectExecutableFields(value[index], issues, path: '$path[$index]');
      }
    }
  }
}
