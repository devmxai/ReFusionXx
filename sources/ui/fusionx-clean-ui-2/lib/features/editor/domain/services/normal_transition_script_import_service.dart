import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/professional_normal_transition_models.dart';

@immutable
class NormalTransitionScriptImportResult {
  const NormalTransitionScriptImportResult({
    required this.issues,
    this.definition,
  });

  final NormalTransitionDefinition? definition;
  final List<NormalTransitionIssue> issues;

  bool get canImport =>
      definition != null &&
      !issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      );
}

class NormalTransitionScriptImportService {
  const NormalTransitionScriptImportService();

  NormalTransitionScriptImportResult validate({
    required String source,
    String? fileName,
  }) {
    final issues = <NormalTransitionIssue>[];
    final trimmed = _normalizeSourceString(source);
    if (trimmed.isEmpty) {
      return const NormalTransitionScriptImportResult(
        issues: <NormalTransitionIssue>[
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Paste or upload a transition JSON script first.',
            path: 'source',
          ),
        ],
      );
    }
    if (fileName != null && !fileName.trim().toLowerCase().endsWith('.json')) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Only .json transition scripts are supported.',
          path: 'fileName',
        ),
      );
      return NormalTransitionScriptImportResult(
        issues: List.unmodifiable(issues),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Transition script must be valid JSON: ${error.message}.',
          path: 'source',
        ),
      );
      return NormalTransitionScriptImportResult(
        issues: List.unmodifiable(issues),
      );
    }

    if (decoded is! Map<String, dynamic>) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Transition script root must be a JSON object.',
          path: 'source',
        ),
      );
      return NormalTransitionScriptImportResult(
        issues: List.unmodifiable(issues),
      );
    }

    _rejectExecutableFields(decoded, issues);
    final definition = _readDefinition(decoded, issues);
    return NormalTransitionScriptImportResult(
      definition: issues.any(
        (issue) => issue.severity == NormalTransitionIssueSeverity.error,
      )
          ? null
          : definition,
      issues: List.unmodifiable(issues),
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

  void _rejectExecutableFields(
    Map<String, dynamic> json,
    List<NormalTransitionIssue> issues,
  ) {
    const blockedKeys = <String>{
      'code',
      'script',
      'function',
      'eval',
      'imports',
      'remoteImports',
      'shaderSource',
    };
    for (final key in json.keys) {
      if (blockedKeys.contains(key)) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Transition scripts must be declarative JSON; `$key` is not supported.',
            path: key,
          ),
        );
      }
    }
  }

  NormalTransitionDefinition _readDefinition(
    Map<String, dynamic> json,
    List<NormalTransitionIssue> issues,
  ) {
    final kind = _readString(json, 'kind');
    if (kind != null && kind != 'refusion.transition') {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: 'Transition script kind must be `refusion.transition`.',
          path: 'kind',
        ),
      );
    }
    final schemaVersion = _readString(json, 'schemaVersion') ??
        _readString(json, 'version') ??
        kNormalTransitionSchemaVersion;
    if (schemaVersion != kNormalTransitionSchemaVersion) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message:
              'Unsupported transition schema `$schemaVersion`. Expected `$kNormalTransitionSchemaVersion`.',
          path: 'schemaVersion',
        ),
      );
    }

    final id = _requiredString(json, 'id', issues) ?? 'invalid-transition';
    final label = _readString(json, 'name') ??
        _readString(json, 'label') ??
        _readString(json, 'title') ??
        id;
    final rendererTier = _readRendererTier(json, issues);
    final category = _readCategory(json);
    final defaultDuration = _readDuration(
      json,
      'defaultDurationMs',
      fallback: TimelineTime.fromMilliseconds(600),
      issues: issues,
    );
    final minDuration = _readDuration(
      json,
      'minDurationMs',
      fallback: kNormalTransitionMinimumDuration,
      issues: issues,
    );
    final maxDuration = _readDuration(
      json,
      'maxDurationMs',
      fallback: kNormalTransitionMaximumDuration,
      issues: issues,
    );
    final capabilities = _readStringList(json, 'requires', issues);
    final parameters = _readParameters(json, issues);
    final channels = _readChannels(json, issues);

    if (channels.isEmpty) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.warning,
          message: 'No channels were declared for this transition.',
          path: 'channels',
        ),
      );
    }

    return NormalTransitionDefinition(
      definitionId: id,
      schemaVersion: schemaVersion,
      label: label,
      category: category,
      rendererTier: rendererTier,
      defaultDuration: defaultDuration,
      minDuration: minDuration,
      maxDuration: maxDuration,
      capabilities: capabilities,
      parameters: parameters,
      channels: channels,
      shaderAssetPath: _readString(json, 'shaderAssetPath'),
      thumbnailPath: _readString(json, 'thumbnailPath'),
    );
  }

  List<NormalTransitionParameterSchema> _readParameters(
    Map<String, dynamic> json,
    List<NormalTransitionIssue> issues,
  ) {
    final raw = json['parameters'];
    if (raw == null) {
      return const <NormalTransitionParameterSchema>[];
    }
    if (raw is! List) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: '`parameters` must be a list.',
          path: 'parameters',
        ),
      );
      return const <NormalTransitionParameterSchema>[];
    }
    final parameters = <NormalTransitionParameterSchema>[];
    for (var index = 0; index < raw.length; index += 1) {
      final entry = raw[index];
      final path = 'parameters[$index]';
      if (entry is! Map<String, dynamic>) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Parameter entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final name = _requiredString(entry, 'name', issues, path: path);
      if (name == null) {
        continue;
      }
      final type = _readParameterType(entry, issues, path);
      final defaultValue = entry['default'];
      if (defaultValue == null) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Parameter `$name` must declare a default value.',
            path: '$path.default',
          ),
        );
        continue;
      }
      final range = _readRange(entry, issues, path);
      final values = _readStringList(entry, 'values', issues, path: path);
      final parameter = NormalTransitionParameterSchema(
        name: name,
        type: type,
        defaultValue: defaultValue,
        range: range,
        values: values,
        uiControl: _readString(entry, 'ui'),
      );
      if (!parameter.accepts(defaultValue)) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Default value for parameter `$name` does not match its schema.',
            path: '$path.default',
          ),
        );
        continue;
      }
      parameters.add(parameter);
    }
    return List.unmodifiable(parameters);
  }

  List<NormalTransitionChannelSpec> _readChannels(
    Map<String, dynamic> json,
    List<NormalTransitionIssue> issues,
  ) {
    final raw = json['channels'];
    if (raw == null) {
      return const <NormalTransitionChannelSpec>[];
    }
    if (raw is! List) {
      issues.add(
        const NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: '`channels` must be a list.',
          path: 'channels',
        ),
      );
      return const <NormalTransitionChannelSpec>[];
    }
    final channels = <NormalTransitionChannelSpec>[];
    for (var index = 0; index < raw.length; index += 1) {
      final entry = raw[index];
      final path = 'channels[$index]';
      if (entry is! Map<String, dynamic>) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Channel entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final target = _requiredString(entry, 'target', issues, path: path);
      final property = _requiredString(entry, 'property', issues, path: path);
      if (target == null || property == null) {
        continue;
      }
      if (!const <String>{'from', 'to', 'transition'}.contains(target) &&
          !target.startsWith('transition.')) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message:
                'Channel target `$target` is not supported. Use `from`, `to`, or `transition`.',
            path: '$path.target',
          ),
        );
        continue;
      }
      final keyframes = _readKeyframes(entry, issues, path);
      if (keyframes.isEmpty) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Channel `$target.$property` must include keyframes.',
            path: '$path.keyframes',
          ),
        );
        continue;
      }
      channels.add(
        NormalTransitionChannelSpec(
          target: target,
          property: property,
          keyframes: keyframes,
        ),
      );
    }
    return List.unmodifiable(channels);
  }

  List<NormalTransitionKeyframeSpec> _readKeyframes(
    Map<String, dynamic> channel,
    List<NormalTransitionIssue> issues,
    String channelPath,
  ) {
    final raw = channel['keyframes'];
    if (raw is! List) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: '`keyframes` must be a list.',
          path: '$channelPath.keyframes',
        ),
      );
      return const <NormalTransitionKeyframeSpec>[];
    }
    final keyframes = <NormalTransitionKeyframeSpec>[];
    double? lastTime;
    for (var index = 0; index < raw.length; index += 1) {
      final entry = raw[index];
      final path = '$channelPath.keyframes[$index]';
      if (entry is! Map<String, dynamic>) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Keyframe entry must be an object.',
            path: path,
          ),
        );
        continue;
      }
      final time = _readNumber(entry, 't');
      if (time == null || time < 0 || time > 1) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Keyframe `t` must be a number in [0, 1].',
            path: '$path.t',
          ),
        );
        continue;
      }
      if (lastTime != null && time < lastTime) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Keyframes must be sorted by normalized time.',
            path: path,
          ),
        );
        continue;
      }
      lastTime = time.toDouble();
      if (!entry.containsKey('value')) {
        issues.add(
          NormalTransitionIssue(
            severity: NormalTransitionIssueSeverity.error,
            message: 'Keyframe must include `value`.',
            path: '$path.value',
          ),
        );
        continue;
      }
      keyframes.add(
        NormalTransitionKeyframeSpec(
          normalizedTime: time.toDouble(),
          value: entry['value'] as Object,
          easing: _readString(entry, 'easing') ?? 'linear',
        ),
      );
    }
    return List.unmodifiable(keyframes);
  }

  NormalTransitionRendererTier _readRendererTier(
    Map<String, dynamic> json,
    List<NormalTransitionIssue> issues,
  ) {
    final value = _readString(json, 'rendererType') ?? 'primitive';
    return switch (value) {
      'primitive' => NormalTransitionRendererTier.primitive,
      'glsl' => NormalTransitionRendererTier.glsl,
      'multiPassDeferred' => NormalTransitionRendererTier.multiPassDeferred,
      _ => () {
          issues.add(
            NormalTransitionIssue(
              severity: NormalTransitionIssueSeverity.error,
              message: 'Unsupported rendererType `$value`.',
              path: 'rendererType',
            ),
          );
          return NormalTransitionRendererTier.primitive;
        }(),
    };
  }

  NormalTransitionCategory _readCategory(Map<String, dynamic> json) {
    final value = _readString(json, 'category') ?? 'custom';
    return switch (value) {
      'basic' || 'Basic' => NormalTransitionCategory.basic,
      'motion' || 'Motion' => NormalTransitionCategory.motion,
      'blur' || 'Blur' => NormalTransitionCategory.blur,
      'wipe' || 'Wipe' => NormalTransitionCategory.wipe,
      'light' || 'Light' => NormalTransitionCategory.light,
      'distort' || 'Distort' => NormalTransitionCategory.distort,
      _ => NormalTransitionCategory.custom,
    };
  }

  NormalTransitionParameterType _readParameterType(
    Map<String, dynamic> json,
    List<NormalTransitionIssue> issues,
    String path,
  ) {
    final value = _readString(json, 'type') ?? 'number';
    return switch (value) {
      'number' => NormalTransitionParameterType.number,
      'boolean' => NormalTransitionParameterType.boolean,
      'enum' || 'enumeration' => NormalTransitionParameterType.enumeration,
      _ => () {
          issues.add(
            NormalTransitionIssue(
              severity: NormalTransitionIssueSeverity.error,
              message: 'Unsupported parameter type `$value`.',
              path: '$path.type',
            ),
          );
          return NormalTransitionParameterType.number;
        }(),
    };
  }

  NormalTransitionNumberRange? _readRange(
    Map<String, dynamic> json,
    List<NormalTransitionIssue> issues,
    String path,
  ) {
    final raw = json['range'];
    if (raw == null) {
      return null;
    }
    if (raw is! List || raw.length != 2 || raw[0] is! num || raw[1] is! num) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: '`range` must be a two-number list.',
          path: '$path.range',
        ),
      );
      return null;
    }
    final min = (raw[0] as num).toDouble();
    final max = (raw[1] as num).toDouble();
    if (min > max) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: '`range` min must be <= max.',
          path: '$path.range',
        ),
      );
      return null;
    }
    return NormalTransitionNumberRange(min: min, max: max);
  }

  TimelineTime _readDuration(
    Map<String, dynamic> json,
    String key, {
    required TimelineTime fallback,
    required List<NormalTransitionIssue> issues,
  }) {
    final raw = json[key];
    if (raw == null) {
      return fallback;
    }
    if (raw is! num || raw <= 0) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: '`$key` must be a positive number of milliseconds.',
          path: key,
        ),
      );
      return fallback;
    }
    return TimelineTime.fromMilliseconds(raw.round());
  }

  List<String> _readStringList(
    Map<String, dynamic> json,
    String key,
    List<NormalTransitionIssue> issues, {
    String? path,
  }) {
    final raw = json[key];
    if (raw == null) {
      return const <String>[];
    }
    if (raw is! List || raw.any((entry) => entry is! String)) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: '`$key` must be a list of strings.',
          path: path == null ? key : '$path.$key',
        ),
      );
      return const <String>[];
    }
    return List<String>.unmodifiable(raw.cast<String>());
  }

  String? _requiredString(
    Map<String, dynamic> json,
    String key,
    List<NormalTransitionIssue> issues, {
    String? path,
  }) {
    final value = _readString(json, key);
    if (value == null || value.trim().isEmpty) {
      issues.add(
        NormalTransitionIssue(
          severity: NormalTransitionIssueSeverity.error,
          message: '`$key` is required.',
          path: path == null ? key : '$path.$key',
        ),
      );
      return null;
    }
    return value;
  }

  String? _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String ? value : null;
  }

  num? _readNumber(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is num ? value : null;
  }
}
