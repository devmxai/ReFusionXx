import 'dart:convert';

import '../models/refusion_scene_program_models.dart';

class ReFusionSceneProgramImportResult {
  ReFusionSceneProgramImportResult({
    required List<ReFusionSceneProgramIssue> issues,
    this.program,
  }) : issues = List.unmodifiable(issues);

  final ReFusionSceneProgram? program;
  final List<ReFusionSceneProgramIssue> issues;

  bool get isValid =>
      program != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class ReFusionSceneProgramImportService {
  const ReFusionSceneProgramImportService();

  static const String schemaVersion = 'refusion.scene-program/v1';

  static const Set<String> _blockedKeys = <String>{
    'code',
    'script',
    'function',
    'eval',
    'imports',
    'remoteImports',
    'shaderSource',
  };

  static const Set<String> _layerKinds = <String>{
    'text',
    'image',
    'shape',
    'video',
    'group',
  };

  static const Set<String> _elementKinds = <String>{
    'text',
    'image',
    'shape',
    'solid',
    'icon',
  };

  ReFusionSceneProgramImportResult validate({
    required String source,
    String? fileName,
  }) {
    final issues = <ReFusionSceneProgramIssue>[];
    final decoded = _decode(source, fileName: fileName, issues: issues);
    if (decoded == null) {
      return ReFusionSceneProgramImportResult(issues: issues);
    }
    _checkBlockedKeys(decoded, issues: issues);

    final rawSchemaVersion =
        _readString(decoded, const <String>['schemaVersion', 'version']);
    if (rawSchemaVersion == null) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Scene program must declare `schemaVersion`.',
          path: 'schemaVersion',
        ),
      );
    } else if (rawSchemaVersion != schemaVersion) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Unsupported scene program schema `$rawSchemaVersion`. Expected `$schemaVersion`.',
          path: 'schemaVersion',
        ),
      );
    }

    final durationMs = _readPositiveInt(
      decoded,
      'durationMs',
      fallback: 3000,
      issues: issues,
    );
    final frameRate = _readPositiveDouble(
      decoded,
      'frameRate',
      fallback: 30,
      issues: issues,
    );
    final layers = _readLayers(
      decoded['layers'],
      sceneDurationMs: durationMs,
      issues: issues,
    );
    if (layers.isEmpty) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Scene program must include at least one layer.',
          path: 'layers',
        ),
      );
    }

    final program = ReFusionSceneProgram(
      schemaVersion: rawSchemaVersion ?? schemaVersion,
      name: _readString(decoded, const <String>['name', 'title']) ??
          'Untitled Scene Program',
      durationMs: durationMs,
      frameRate: frameRate,
      layers: layers,
    );
    return ReFusionSceneProgramImportResult(
      program: program,
      issues: issues,
    );
  }

  Map<String, dynamic>? _decode(
    String source, {
    required String? fileName,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Scene program JSON root must be an object.',
          path: fileName,
        ),
      );
      return null;
    } on FormatException catch (error) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Invalid JSON: ${error.message}.',
          path: fileName,
        ),
      );
      return null;
    }
  }

  void _checkBlockedKeys(
    Object? value, {
    required List<ReFusionSceneProgramIssue> issues,
    String path = '',
  }) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key;
        final keyPath = path.isEmpty ? '$key' : '$path.$key';
        if (key is String && _blockedKeys.contains(key)) {
          issues.add(
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Scene programs must be declarative JSON; `$key` is not supported.',
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

  List<ReFusionSceneProgramLayer> _readLayers(
    Object? raw, {
    required int sceneDurationMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (raw is! List) {
      issues.add(
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: '`layers` must be a list.',
          path: 'layers',
        ),
      );
      return const <ReFusionSceneProgramLayer>[];
    }
    final layers = <ReFusionSceneProgramLayer>[];
    final ids = <String>{};
    for (var index = 0; index < raw.length; index += 1) {
      final path = 'layers[$index]';
      final entry = raw[index];
      if (entry is! Map<String, dynamic>) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Layer entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final id = _readRequiredString(entry, 'id', issues, path: path);
      final kind = _readRequiredString(entry, 'kind', issues, path: path);
      if (id == null || kind == null) {
        continue;
      }
      if (!ids.add(id)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Duplicate layer id `$id`.',
            path: '$path.id',
          ),
        );
        continue;
      }
      if (!_layerKinds.contains(kind)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Unsupported layer kind `$kind`.',
            path: '$path.kind',
          ),
        );
      }
      final startMs = _readNonNegativeInt(
        entry,
        'startMs',
        fallback: 0,
        issues: issues,
        pathPrefix: path,
      );
      final durationMs = _readPositiveInt(
        entry,
        'durationMs',
        fallback: sceneDurationMs,
        issues: issues,
        pathPrefix: path,
      );
      if (startMs + durationMs > sceneDurationMs) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.warning,
            message:
                'Layer `$id` extends beyond the scene duration and will need clamping during lowering.',
            path: '$path.durationMs',
          ),
        );
      }
      layers.add(
        ReFusionSceneProgramLayer(
          id: id,
          kind: kind,
          name: _readString(entry, const <String>['name', 'label']),
          startMs: startMs,
          durationMs: durationMs,
          elements: _readElements(
            entry['elements'],
            layerPath: path,
            layerDurationMs: durationMs,
            issues: issues,
          ),
          channels: _readChannels(
            entry['channels'],
            ownerPath: path,
            ownerDurationMs: durationMs,
            issues: issues,
          ),
        ),
      );
    }
    return List.unmodifiable(layers);
  }

  List<ReFusionSceneProgramElement> _readElements(
    Object? raw, {
    required String layerPath,
    required int layerDurationMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (raw == null) {
      return const <ReFusionSceneProgramElement>[];
    }
    if (raw is! List) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: '`elements` must be a list.',
          path: '$layerPath.elements',
        ),
      );
      return const <ReFusionSceneProgramElement>[];
    }
    final elements = <ReFusionSceneProgramElement>[];
    final ids = <String>{};
    for (var index = 0; index < raw.length; index += 1) {
      final path = '$layerPath.elements[$index]';
      final entry = raw[index];
      if (entry is! Map<String, dynamic>) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Element entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final id = _readRequiredString(entry, 'id', issues, path: path);
      final kind = _readRequiredString(entry, 'kind', issues, path: path);
      if (id == null || kind == null) {
        continue;
      }
      if (!ids.add(id)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Duplicate element id `$id`.',
            path: '$path.id',
          ),
        );
        continue;
      }
      if (!_elementKinds.contains(kind)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Unsupported element kind `$kind`.',
            path: '$path.kind',
          ),
        );
      }
      elements.add(
        ReFusionSceneProgramElement(
          id: id,
          kind: kind,
          name: _readString(entry, const <String>['name', 'label']),
          text: _readString(entry, const <String>['text']),
          properties: _readProperties(entry['properties'], path, issues),
          channels: _readChannels(
            entry['channels'],
            ownerPath: path,
            ownerDurationMs: layerDurationMs,
            issues: issues,
          ),
        ),
      );
    }
    return List.unmodifiable(elements);
  }

  List<ReFusionSceneProgramChannel> _readChannels(
    Object? raw, {
    required String ownerPath,
    required int ownerDurationMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (raw == null) {
      return const <ReFusionSceneProgramChannel>[];
    }
    if (raw is! List) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: '`channels` must be a list.',
          path: '$ownerPath.channels',
        ),
      );
      return const <ReFusionSceneProgramChannel>[];
    }
    final channels = <ReFusionSceneProgramChannel>[];
    for (var index = 0; index < raw.length; index += 1) {
      final path = '$ownerPath.channels[$index]';
      final entry = raw[index];
      if (entry is! Map<String, dynamic>) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Channel entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final property =
          _readRequiredString(entry, 'property', issues, path: path);
      if (property == null) {
        continue;
      }
      final keyframes = _readKeyframes(
        entry['keyframes'],
        channelPath: path,
        ownerDurationMs: ownerDurationMs,
        issues: issues,
      );
      if (keyframes.isEmpty) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Channel `$property` must include keyframes.',
            path: '$path.keyframes',
          ),
        );
        continue;
      }
      channels.add(
        ReFusionSceneProgramChannel(
          target: _readString(entry, const <String>['target']) ?? 'self',
          property: property,
          keyframes: keyframes,
        ),
      );
    }
    return List.unmodifiable(channels);
  }

  List<ReFusionSceneProgramKeyframe> _readKeyframes(
    Object? raw, {
    required String channelPath,
    required int ownerDurationMs,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    if (raw is! List) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: '`keyframes` must be a list.',
          path: '$channelPath.keyframes',
        ),
      );
      return const <ReFusionSceneProgramKeyframe>[];
    }
    final keyframes = <ReFusionSceneProgramKeyframe>[];
    int? lastTimeMs;
    for (var index = 0; index < raw.length; index += 1) {
      final path = '$channelPath.keyframes[$index]';
      final entry = raw[index];
      if (entry is! Map<String, dynamic>) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Keyframe entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final timeMs = _readNonNegativeInt(
        entry,
        'timeMs',
        fallback: -1,
        issues: issues,
        pathPrefix: path,
      );
      if (timeMs < 0 || timeMs > ownerDurationMs) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message:
                'Keyframe `timeMs` must be inside the owning timeline range.',
            path: '$path.timeMs',
          ),
        );
        continue;
      }
      if (lastTimeMs != null && timeMs < lastTimeMs) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Keyframes must be sorted by `timeMs`.',
            path: path,
          ),
        );
        continue;
      }
      lastTimeMs = timeMs;
      final value = entry['value'];
      if (!_isSupportedJsonValue(value)) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Keyframe must include a JSON-compatible `value`.',
            path: '$path.value',
          ),
        );
        continue;
      }
      keyframes.add(
        ReFusionSceneProgramKeyframe(
          timeMs: timeMs,
          value: value as Object,
          easing: _readString(entry, const <String>['easing']) ?? 'linear',
        ),
      );
    }
    return List.unmodifiable(keyframes);
  }

  Map<String, Object?> _readProperties(
    Object? raw,
    String ownerPath,
    List<ReFusionSceneProgramIssue> issues,
  ) {
    if (raw == null) {
      return const <String, Object?>{};
    }
    if (raw is! Map<String, dynamic>) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: '`properties` must be an object.',
          path: '$ownerPath.properties',
        ),
      );
      return const <String, Object?>{};
    }
    return Map<String, Object?>.unmodifiable(raw);
  }

  String? _readRequiredString(
    Map<String, dynamic> json,
    String key,
    List<ReFusionSceneProgramIssue> issues, {
    required String path,
  }) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message: 'Missing required `$key`.',
        path: '$path.$key',
      ),
    );
    return null;
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int _readPositiveInt(
    Map<String, dynamic> json,
    String key, {
    required int fallback,
    required List<ReFusionSceneProgramIssue> issues,
    String pathPrefix = '',
  }) {
    final value = json[key];
    if (value is int && value > 0) {
      return value;
    }
    if (value is num && value > 0) {
      return value.round();
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message: '`$key` must be a positive number.',
        path: _joinPath(pathPrefix, key),
      ),
    );
    return fallback;
  }

  int _readNonNegativeInt(
    Map<String, dynamic> json,
    String key, {
    required int fallback,
    required List<ReFusionSceneProgramIssue> issues,
    String pathPrefix = '',
  }) {
    final value = json[key];
    if (value is int && value >= 0) {
      return value;
    }
    if (value is num && value >= 0) {
      return value.round();
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message: '`$key` must be a non-negative number.',
        path: _joinPath(pathPrefix, key),
      ),
    );
    return fallback;
  }

  double _readPositiveDouble(
    Map<String, dynamic> json,
    String key, {
    required double fallback,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    if (value is num && value > 0) {
      return value.toDouble();
    }
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message: '`$key` must be a positive number.',
        path: key,
      ),
    );
    return fallback;
  }

  bool _isSupportedJsonValue(Object? value) {
    if (value == null || value is num || value is String || value is bool) {
      return value != null;
    }
    if (value is List) {
      return value.every(_isSupportedJsonValue);
    }
    if (value is Map) {
      return value.keys.every((key) => key is String) &&
          value.values.every(_isSupportedJsonValue);
    }
    return false;
  }

  String _joinPath(String prefix, String key) =>
      prefix.isEmpty ? key : '$prefix.$key';
}
