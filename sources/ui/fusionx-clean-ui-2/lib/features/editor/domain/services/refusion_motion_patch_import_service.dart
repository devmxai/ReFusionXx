import 'dart:convert';

import '../models/professional_motion_models.dart';
import '../models/refusion_motion_patch_models.dart';
import 'scene_mention_index.dart';

class ReFusionMotionPatchImportResult {
  ReFusionMotionPatchImportResult({
    required List<ReFusionMotionPatchIssue> issues,
    this.patch,
    List<ReFusionMotionPatchResolvedChannel> resolvedChannels =
        const <ReFusionMotionPatchResolvedChannel>[],
  })  : issues = List.unmodifiable(issues),
        resolvedChannels = List.unmodifiable(resolvedChannels);

  final ReFusionMotionPatch? patch;
  final List<ReFusionMotionPatchResolvedChannel> resolvedChannels;
  final List<ReFusionMotionPatchIssue> issues;

  bool get isValid =>
      patch != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionMotionPatchIssueSeverity.error,
      );
}

class ReFusionMotionPatchImportService {
  const ReFusionMotionPatchImportService();

  static const String schemaVersion = 'refusion.motion-patch/v1';

  static const Set<String> _blockedKeys = <String>{
    'code',
    'script',
    'function',
    'eval',
    'imports',
    'remoteImports',
    'shaderSource',
    'runtime',
    'nativeCommand',
    'shell',
    'url',
  };

  static const Set<String> _supportedActions = <String>{
    'animate',
  };

  ReFusionMotionPatchImportResult validate({
    required String source,
    required List<SceneMentionEntity> mentionEntities,
    required int scopeDurationMs,
    String? fileName,
  }) {
    final issues = <ReFusionMotionPatchIssue>[];
    final decoded = _decode(source, fileName: fileName, issues: issues);
    if (decoded == null) {
      return ReFusionMotionPatchImportResult(issues: issues);
    }
    _checkBlockedKeys(decoded, issues: issues);

    final rawSchemaVersion =
        _readString(decoded, const <String>['schemaVersion', 'version']);
    if (rawSchemaVersion == null) {
      issues.add(
        const ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message: 'Motion patch must declare `schemaVersion`.',
          path: 'schemaVersion',
        ),
      );
    } else if (rawSchemaVersion != schemaVersion) {
      issues.add(
        ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message:
              'Unsupported motion patch schema `$rawSchemaVersion`. Expected `$schemaVersion`.',
          path: 'schemaVersion',
        ),
      );
    }

    final safeScopeDurationMs = scopeDurationMs > 0 ? scopeDurationMs : 1;
    final patchDurationMs = _readPositiveInt(
      decoded,
      const <String>['scopeDurationMs', 'durationMs'],
      fallback: safeScopeDurationMs,
      issues: issues,
    );
    if (patchDurationMs > safeScopeDurationMs) {
      issues.add(
        ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message:
              'Motion patch duration `$patchDurationMs` exceeds scope duration `$safeScopeDurationMs`.',
          path: 'durationMs',
        ),
      );
    }

    final operations = _readOperations(
      decoded['operations'] ?? decoded['animations'] ?? decoded['channels'],
      scopeDurationMs: safeScopeDurationMs,
      mentionEntities: mentionEntities,
      issues: issues,
    );
    if (operations.operations.isEmpty) {
      issues.add(
        const ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message: 'Motion patch must include at least one operation.',
          path: 'operations',
        ),
      );
    }

    final patch = ReFusionMotionPatch(
      schemaVersion: rawSchemaVersion ?? schemaVersion,
      name: _readString(decoded, const <String>['name', 'title']) ??
          'Untitled Motion Patch',
      scopeDurationMs: patchDurationMs,
      operations: operations.operations,
    );
    return ReFusionMotionPatchImportResult(
      patch: patch,
      resolvedChannels: operations.resolvedChannels,
      issues: issues,
    );
  }

  Map<String, dynamic>? _decode(
    String source, {
    required String? fileName,
    required List<ReFusionMotionPatchIssue> issues,
  }) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      issues.add(
        ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message: 'Motion patch JSON root must be an object.',
          path: fileName,
        ),
      );
      return null;
    } on FormatException catch (error) {
      issues.add(
        ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message: 'Invalid JSON: ${error.message}.',
          path: fileName,
        ),
      );
      return null;
    }
  }

  void _checkBlockedKeys(
    Object? value, {
    required List<ReFusionMotionPatchIssue> issues,
    String path = '',
  }) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key;
        final keyPath = path.isEmpty ? '$key' : '$path.$key';
        if (key is String && _blockedKeys.contains(key)) {
          issues.add(
            ReFusionMotionPatchIssue(
              severity: ReFusionMotionPatchIssueSeverity.error,
              message:
                  'Motion patches must be declarative JSON; `$key` is not supported.',
              path: keyPath,
            ),
          );
        }
        _checkBlockedKeys(entry.value, issues: issues, path: keyPath);
      }
      return;
    }
    if (value is List) {
      for (var index = 0; index < value.length; index += 1) {
        _checkBlockedKeys(
          value[index],
          issues: issues,
          path: '$path[$index]',
        );
      }
    }
  }

  _OperationsReadResult _readOperations(
    Object? raw, {
    required int scopeDurationMs,
    required List<SceneMentionEntity> mentionEntities,
    required List<ReFusionMotionPatchIssue> issues,
  }) {
    if (raw is! List) {
      issues.add(
        const ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message: '`operations` must be a list.',
          path: 'operations',
        ),
      );
      return const _OperationsReadResult();
    }
    final operations = <ReFusionMotionPatchOperation>[];
    final resolvedChannels = <ReFusionMotionPatchResolvedChannel>[];
    for (var index = 0; index < raw.length; index += 1) {
      final path = 'operations[$index]';
      final entry = raw[index];
      if (entry is! Map<String, dynamic>) {
        issues.add(
          ReFusionMotionPatchIssue(
            severity: ReFusionMotionPatchIssueSeverity.error,
            message: 'Motion patch operation must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final operation = _readOperation(
        entry,
        path: path,
        fallbackId: 'op-$index',
        scopeDurationMs: scopeDurationMs,
        issues: issues,
      );
      operations.add(operation);
      final entity = _resolveTarget(
        operation.target,
        mentionEntities: mentionEntities,
      );
      if (entity == null) {
        issues.add(
          ReFusionMotionPatchIssue(
            severity: ReFusionMotionPatchIssueSeverity.error,
            message: 'Unknown motion patch target `${operation.target}`.',
            path: '$path.target',
          ),
        );
        continue;
      }

      final properties = _definitionsForProperty(operation.property);
      if (properties.isEmpty) {
        issues.add(
          ReFusionMotionPatchIssue(
            severity: ReFusionMotionPatchIssueSeverity.error,
            message:
                'Unsupported motion patch property `${operation.property}`.',
            path: '$path.property',
          ),
        );
        continue;
      }
      for (final property in properties) {
        if (!_entitySupportsProperty(entity, property.definition)) {
          issues.add(
            ReFusionMotionPatchIssue(
              severity: ReFusionMotionPatchIssueSeverity.error,
              message:
                  'Target `${entity.displayName}` does not support property `${property.definition.id}`.',
              path: '$path.property',
            ),
          );
          continue;
        }
        _validateKeyframeValues(
          operation,
          property: property,
          path: path,
          issues: issues,
        );
        resolvedChannels.add(
          ReFusionMotionPatchResolvedChannel(
            operation: operation,
            definition: property.definition,
            target: MotionPropertyTarget(
              kind: MotionTargetKind.element,
              targetId: entity.targetId,
              sceneId: entity.sceneId,
              layerId: entity.layerId,
              elementId: entity.elementId,
            ),
            component: property.component,
          ),
        );
      }
    }
    return _OperationsReadResult(
      operations: operations,
      resolvedChannels: resolvedChannels,
    );
  }

  ReFusionMotionPatchOperation _readOperation(
    Map<String, dynamic> entry, {
    required String path,
    required String fallbackId,
    required int scopeDurationMs,
    required List<ReFusionMotionPatchIssue> issues,
  }) {
    final action =
        (_readString(entry, const <String>['action', 'op']) ?? 'animate')
            .trim();
    if (!_supportedActions.contains(action)) {
      issues.add(
        ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message:
              'Motion patch action `$action` is not supported. Use `animate`.',
          path: '$path.action',
        ),
      );
    }
    final keyframes = _readKeyframes(
      entry['keyframes'],
      scopeDurationMs: scopeDurationMs,
      path: '$path.keyframes',
      issues: issues,
    );
    return ReFusionMotionPatchOperation(
      id: _readString(entry, const <String>['id']) ?? fallbackId,
      action: action,
      target: _readString(entry, const <String>[
            'target',
            'mention',
            'mentionId',
            'targetId',
          ]) ??
          '',
      property: _readString(entry, const <String>['property']) ?? '',
      keyframes: keyframes,
    );
  }

  List<ReFusionMotionPatchKeyframe> _readKeyframes(
    Object? raw, {
    required int scopeDurationMs,
    required String path,
    required List<ReFusionMotionPatchIssue> issues,
  }) {
    if (raw is! List || raw.isEmpty) {
      issues.add(
        ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message: 'Motion patch operation must include keyframes.',
          path: path,
        ),
      );
      return const <ReFusionMotionPatchKeyframe>[];
    }
    final keyframes = <ReFusionMotionPatchKeyframe>[];
    var wasUnsorted = false;
    var previousTime = -1;
    for (var index = 0; index < raw.length; index += 1) {
      final itemPath = '$path[$index]';
      final entry = raw[index];
      if (entry is! Map<String, dynamic>) {
        issues.add(
          ReFusionMotionPatchIssue(
            severity: ReFusionMotionPatchIssueSeverity.error,
            message: 'Keyframe must be an object.',
            path: itemPath,
          ),
        );
        continue;
      }
      final timeMs = _readInt(entry, 'timeMs', issues: issues, path: itemPath);
      if (timeMs < 0 || timeMs > scopeDurationMs) {
        issues.add(
          ReFusionMotionPatchIssue(
            severity: ReFusionMotionPatchIssueSeverity.error,
            message:
                'Keyframe `timeMs` must be inside the active scope range 0..$scopeDurationMs.',
            path: '$itemPath.timeMs',
          ),
        );
      }
      if (timeMs < previousTime) {
        wasUnsorted = true;
      }
      previousTime = timeMs;
      if (!entry.containsKey('value')) {
        issues.add(
          ReFusionMotionPatchIssue(
            severity: ReFusionMotionPatchIssueSeverity.error,
            message: 'Keyframe must include `value`.',
            path: '$itemPath.value',
          ),
        );
      }
      keyframes.add(
        ReFusionMotionPatchKeyframe(
          timeMs: timeMs,
          value: entry['value'] ?? 0,
          easing: _readString(entry, const <String>['easing']) ?? 'linear',
        ),
      );
    }
    if (wasUnsorted) {
      issues.add(
        ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.warning,
          message:
              'Motion patch keyframes were not sorted and were normalized by time.',
          path: path,
        ),
      );
      keyframes.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    }
    return keyframes;
  }

  void _validateKeyframeValues(
    ReFusionMotionPatchOperation operation, {
    required _PatchProperty property,
    required String path,
    required List<ReFusionMotionPatchIssue> issues,
  }) {
    for (var index = 0; index < operation.keyframes.length; index += 1) {
      final value = operation.keyframes[index].value;
      if (_isValueCompatible(value, property: property)) {
        continue;
      }
      issues.add(
        ReFusionMotionPatchIssue(
          severity: ReFusionMotionPatchIssueSeverity.error,
          message:
              'Value for `${property.definition.id}` is not compatible with `${property.definition.valueKind.name}`.',
          path: '$path.keyframes[$index].value',
        ),
      );
    }
  }

  bool _isValueCompatible(Object? value, {required _PatchProperty property}) {
    if (property.component != null && value is Map) {
      return value[property.component] is num;
    }
    switch (property.definition.valueKind) {
      case MotionPropertyValueKind.scalar:
        return value is num;
      case MotionPropertyValueKind.integer:
        return value is int;
      case MotionPropertyValueKind.boolean:
        return value is bool;
      case MotionPropertyValueKind.stringValue:
      case MotionPropertyValueKind.enumValue:
        return value is String;
      case MotionPropertyValueKind.colorArgb:
        return value is int || (value is String && value.startsWith('#'));
      case MotionPropertyValueKind.point2D:
        return value is Map && value['x'] is num && value['y'] is num;
      case MotionPropertyValueKind.size2D:
        return value is Map && value['width'] is num && value['height'] is num;
      case MotionPropertyValueKind.rect:
        return value is Map &&
            value['left'] is num &&
            value['top'] is num &&
            value['width'] is num &&
            value['height'] is num;
    }
  }

  SceneMentionEntity? _resolveTarget(
    String rawTarget, {
    required List<SceneMentionEntity> mentionEntities,
  }) {
    final target = rawTarget.trim();
    if (target.isEmpty) {
      return null;
    }
    for (final entity in mentionEntities) {
      if (target == entity.mentionId || target == entity.targetId) {
        return entity;
      }
    }
    final normalized = _normalizeMentionTarget(target);
    for (final entity in mentionEntities) {
      if (normalized == _normalizeMentionTarget(entity.displayName) ||
          normalized == _normalizeMentionTarget(entity.baseDisplayName)) {
        return entity;
      }
    }
    return null;
  }

  bool _entitySupportsProperty(
    SceneMentionEntity entity,
    MotionPropertyDefinition definition,
  ) {
    return entity.supportedProperties.any(
      (property) => property.id == definition.id,
    );
  }

  List<_PatchProperty> _definitionsForProperty(String property) {
    final normalized = _normalizeToken(property);
    return switch (normalized) {
      'position' || 'transformposition' => <_PatchProperty>[
          _PatchProperty(
            definition: MotionPropertyCatalog.positionX,
            component: 'x',
          ),
          _PatchProperty(
            definition: MotionPropertyCatalog.positionY,
            component: 'y',
          ),
        ],
      'positionx' || 'x' || 'transformpositionx' => <_PatchProperty>[
          _PatchProperty(
            definition: MotionPropertyCatalog.positionX,
            component: 'x',
          ),
        ],
      'positiony' || 'y' || 'transformpositiony' => <_PatchProperty>[
          _PatchProperty(
            definition: MotionPropertyCatalog.positionY,
            component: 'y',
          ),
        ],
      'scale' || 'transformscale' => <_PatchProperty>[
          _PatchProperty(
            definition: MotionPropertyCatalog.scaleX,
            component: 'x',
          ),
          _PatchProperty(
            definition: MotionPropertyCatalog.scaleY,
            component: 'y',
          ),
        ],
      'scalex' || 'transformscalex' => <_PatchProperty>[
          _PatchProperty(
            definition: MotionPropertyCatalog.scaleX,
            component: 'x',
          ),
        ],
      'scaley' || 'transformscaley' => <_PatchProperty>[
          _PatchProperty(
            definition: MotionPropertyCatalog.scaleY,
            component: 'y',
          ),
        ],
      'rotation' ||
      'rotationdegrees' ||
      'transformrotation' ||
      'transformrotationdegrees' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.rotationDegrees),
        ],
      'opacity' || 'alpha' || 'visualopacity' => <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.opacity),
        ],
      'blur' ||
      'bluramount' ||
      'visualblur' ||
      'visualbluramount' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.blurAmount),
        ],
      'shadowopacity' ||
      'softshadowopacity' ||
      'dropshadowopacity' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.shadowOpacity),
        ],
      'shadowblur' || 'softshadowblur' || 'dropshadowblur' => <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.shadowBlur),
        ],
      'shadowoffsetx' ||
      'softshadowoffsetx' ||
      'dropshadowoffsetx' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.shadowOffsetX),
        ],
      'shadowoffsety' ||
      'softshadowoffsety' ||
      'dropshadowoffsety' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.shadowOffsetY),
        ],
      'shadowspread' ||
      'softshadowspread' ||
      'dropshadowspread' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.shadowSpread),
        ],
      'fontsize' || 'textfontsize' => <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.fontSize),
        ],
      'letterspacing' ||
      'textletterspacing' ||
      'tracking' ||
      'trackingamount' ||
      'texttracking' ||
      'texttrackingamount' ||
      'rangetracking' ||
      'rangetrackingamount' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.letterSpacing),
        ],
      'reveal' ||
      'revealprogress' ||
      'rangeselector' ||
      'rangeselectorstart' ||
      'rangeselectorprogress' ||
      'textrangeselector' ||
      'textrangeselectorstart' ||
      'textrangeselectorprogress' ||
      'wordrangeselector' ||
      'wordrangeselectorstart' ||
      'wordrangeselectorprogress' ||
      'rangeselectorwords' ||
      'rangeselectorbywords' ||
      'letterrangeselector' ||
      'letterrangeselectorstart' ||
      'letterrangeselectorprogress' ||
      'rangeselectorcharacters' ||
      'rangeselectorbycharacters' ||
      'characterrangeselector' ||
      'characterrangeselectorstart' ||
      'characterrangeselectorprogress' ||
      'charrangeselector' ||
      'charrangeselectorstart' ||
      'charrangeselectorprogress' ||
      'typing' ||
      'typingprogress' ||
      'typewriter' ||
      'typewriterprogress' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.revealProgress),
        ],
      'width' || 'shapewidth' => <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.width),
        ],
      'height' || 'shapeheight' => <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.height),
        ],
      'radius' ||
      'borderradius' ||
      'cornerradius' ||
      'shapecornerradius' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.cornerRadius),
        ],
      'trimstart' ||
      'trimpathstart' ||
      'linetrimstart' ||
      'pathtrimstart' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.trimStart),
        ],
      'trimend' ||
      'trimpathend' ||
      'linetrimend' ||
      'pathtrimend' ||
      'linereveal' ||
      'linerevealprogress' ||
      'revealline' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.trimEnd),
        ],
      'trimoffset' ||
      'trimpathoffset' ||
      'linetrimoffset' ||
      'pathtrimoffset' =>
        <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.trimOffset),
        ],
      'crop' || 'croprect' => <_PatchProperty>[
          _PatchProperty(definition: MotionPropertyCatalog.cropRect),
        ],
      _ => _definitionByExactKey(property),
    };
  }

  List<_PatchProperty> _definitionByExactKey(String property) {
    final normalized = property.trim();
    for (final definition in MotionPropertyCatalog.all) {
      if (normalized == definition.id ||
          normalized == definition.path.canonicalKey) {
        return <_PatchProperty>[_PatchProperty(definition: definition)];
      }
    }
    return const <_PatchProperty>[];
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int _readPositiveInt(
    Map<String, dynamic> data,
    List<String> keys, {
    required int fallback,
    required List<ReFusionMotionPatchIssue> issues,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is int && value > 0) {
        return value;
      }
      if (value is num && value > 0) {
        return value.round();
      }
      if (value != null) {
        issues.add(
          ReFusionMotionPatchIssue(
            severity: ReFusionMotionPatchIssueSeverity.error,
            message: '`$key` must be a positive number.',
            path: key,
          ),
        );
      }
    }
    return fallback;
  }

  int _readInt(
    Map<String, dynamic> data,
    String key, {
    required List<ReFusionMotionPatchIssue> issues,
    required String path,
  }) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    issues.add(
      ReFusionMotionPatchIssue(
        severity: ReFusionMotionPatchIssueSeverity.error,
        message: '`$key` must be a number.',
        path: '$path.$key',
      ),
    );
    return 0;
  }

  String _normalizeMentionTarget(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'^@\{?'), '')
        .replaceAll(RegExp(r'\}$'), '')
        .toLowerCase();
  }

  String _normalizeToken(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }
}

class _OperationsReadResult {
  const _OperationsReadResult({
    this.operations = const <ReFusionMotionPatchOperation>[],
    this.resolvedChannels = const <ReFusionMotionPatchResolvedChannel>[],
  });

  final List<ReFusionMotionPatchOperation> operations;
  final List<ReFusionMotionPatchResolvedChannel> resolvedChannels;
}

class _PatchProperty {
  const _PatchProperty({
    required this.definition,
    this.component,
  });

  final MotionPropertyDefinition definition;
  final String? component;
}
