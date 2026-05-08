import 'dart:convert';

import '../models/refusion_scene_program_models.dart';
import '../models/scene_semantic_blueprint_models.dart';
import 'scene_semantic_blueprint_service.dart';

const String kSceneDeterminismProofTag = 'TF_SCENE_DETERMINISM_PROOF';

class SceneSemanticBlueprintCompileResult {
  SceneSemanticBlueprintCompileResult({
    required List<ReFusionSceneProgramIssue> issues,
    this.blueprint,
    this.program,
    this.blueprintHash,
    this.sceneProgramHash,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;
  final SemanticSceneBlueprint? blueprint;
  final ReFusionSceneProgram? program;
  final String? blueprintHash;
  final String? sceneProgramHash;

  bool get isValid =>
      blueprint != null &&
      program != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneSemanticBlueprintCompiler {
  SceneSemanticBlueprintCompiler({
    SceneSemanticBlueprintService? service,
  }) : _service = service ?? SceneSemanticBlueprintService();

  final SceneSemanticBlueprintService _service;

  SceneSemanticBlueprintCompileResult compile({
    required Map<String, Object?> payload,
    bool allowRawValueOverride = false,
    int determinismIterations = 3,
  }) {
    final issues = <ReFusionSceneProgramIssue>[];
    final validation = _service.validate(payload);
    issues.addAll(validation.issues);
    if (!validation.isValid || validation.blueprint == null) {
      return SceneSemanticBlueprintCompileResult(issues: issues);
    }

    final rawScan = _scanRawValues(payload);
    final tokenResolutionHash = _hashTokenReferences(payload);
    if (rawScan.rawValuesDetected && !allowRawValueOverride) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Raw numeric values detected in semantic blueprint. Use tokens or enable `rawValueOverride`.',
          path: rawScan.firstPath,
        ),
      );
    }

    final lowered = _service.lowerToSceneProgram(validation.blueprint!);
    issues.addAll(lowered.issues);
    if (!lowered.isValid || lowered.program == null) {
      return SceneSemanticBlueprintCompileResult(
        issues: issues,
        blueprint: validation.blueprint,
      );
    }

    final blueprintHash = _hashCanonical(_blueprintToCanonicalMap(payload));
    final firstProgramHash =
        _hashCanonical(_programToCanonicalMap(lowered.program!));

    var deterministic = true;
    var failureReason = 'none';
    for (var iteration = 0; iteration < determinismIterations; iteration += 1) {
      final replayValidation = _service.validate(payload);
      if (!replayValidation.isValid || replayValidation.blueprint == null) {
        deterministic = false;
        failureReason = 'validation_failed';
        break;
      }
      final replayLowered = _service.lowerToSceneProgram(
        replayValidation.blueprint!,
      );
      if (!replayLowered.isValid || replayLowered.program == null) {
        deterministic = false;
        failureReason = 'lowering_failed';
        break;
      }
      final replayHash = _hashCanonical(_programToCanonicalMap(replayLowered.program!));
      if (replayHash != firstProgramHash) {
        deterministic = false;
        failureReason = 'hash_mismatch:$replayHash';
        break;
      }
    }
    if (rawScan.rawValuesDetected && !allowRawValueOverride) {
      deterministic = false;
      failureReason = 'raw_values_detected_without_override';
    }
    final passed = deterministic && (!rawScan.rawValuesDetected || allowRawValueOverride);

    issues.add(
      ReFusionSceneProgramIssue(
        severity: passed
            ? ReFusionSceneProgramIssueSeverity.info
            : ReFusionSceneProgramIssueSeverity.error,
        message: '$kSceneDeterminismProofTag '
            'blueprintHash=$blueprintHash '
            'sceneProgramHash=$firstProgramHash '
            'compileIteration=$determinismIterations '
            'rawValuesDetected=${rawScan.rawValuesDetected} '
            'rawValueOverrides=${allowRawValueOverride.toString()} '
            'tokenResolutionHash=$tokenResolutionHash '
            'deterministic=${deterministic.toString()} '
            'passed=${passed.toString()} '
            'failureReason=$failureReason',
        path: r'$',
      ),
    );

    return SceneSemanticBlueprintCompileResult(
      issues: issues,
      blueprint: validation.blueprint,
      program: lowered.program,
      blueprintHash: blueprintHash,
      sceneProgramHash: firstProgramHash,
    );
  }

  _RawScanResult _scanRawValues(Map<String, Object?> payload) {
    bool rawDetected = false;
    String? firstPath;

    void walk(Object? node, String path, {required bool scanNumbers}) {
      if (node is num && scanNumbers) {
        rawDetected = true;
        firstPath ??= path;
        return;
      }
      if (node is List) {
        for (var index = 0; index < node.length; index += 1) {
          walk(node[index], '$path[$index]', scanNumbers: scanNumbers);
        }
        return;
      }
      if (node is Map) {
        for (final entry in node.entries) {
          if (entry.key is! String) {
            continue;
          }
          final key = entry.key as String;
          final childPath = '$path.$key';
          final normalized = _normalize(key);
          final childScanNumbers = scanNumbers ||
              normalized == 'properties' ||
              normalized == 'slots' ||
              normalized == 'motionintents' ||
              normalized == 'beats' ||
              normalized == 'components';
          walk(
            entry.value,
            childPath,
            scanNumbers: childScanNumbers,
          );
        }
      }
    }

    walk(payload, r'$', scanNumbers: false);
    return _RawScanResult(
      rawValuesDetected: rawDetected,
      firstPath: firstPath ?? r'$',
    );
  }

  Map<String, Object?> _blueprintToCanonicalMap(Map<String, Object?> payload) {
    return _canonicalizeMap(payload);
  }

  Map<String, Object?> _programToCanonicalMap(ReFusionSceneProgram program) {
    return _canonicalizeMap(
      <String, Object?>{
        'schemaVersion': program.schemaVersion,
        'name': program.name,
        'durationMs': program.durationMs,
        'frameRate': program.frameRate,
        'layers': program.layers
            .map(
              (layer) => <String, Object?>{
                'id': layer.id,
                'kind': layer.kind,
                'name': layer.name,
                'startMs': layer.startMs,
                'durationMs': layer.durationMs,
                'channels': layer.channels
                    .map(
                      (channel) => <String, Object?>{
                        'target': channel.target,
                        'property': channel.property,
                        'keyframes': channel.keyframes
                            .map(
                              (keyframe) => <String, Object?>{
                                'timeMs': keyframe.timeMs,
                                'value': keyframe.value,
                                'easing': keyframe.easing,
                              },
                            )
                            .toList(growable: false),
                      },
                    )
                    .toList(growable: false),
                'elements': layer.elements
                    .map(
                      (element) => <String, Object?>{
                        'id': element.id,
                        'kind': element.kind,
                        'name': element.name,
                        'text': element.text,
                        'properties': element.properties,
                        'channels': element.channels
                            .map(
                              (channel) => <String, Object?>{
                                'target': channel.target,
                                'property': channel.property,
                                'keyframes': channel.keyframes
                                    .map(
                                      (keyframe) => <String, Object?>{
                                        'timeMs': keyframe.timeMs,
                                        'value': keyframe.value,
                                        'easing': keyframe.easing,
                                      },
                                    )
                                    .toList(growable: false),
                              },
                            )
                            .toList(growable: false),
                      },
                    )
                    .toList(growable: false),
              },
            )
            .toList(growable: false),
      },
    );
  }

  Map<String, Object?> _canonicalizeMap(Map<String, Object?> map) {
    final sortedKeys = map.keys.toList(growable: false)..sort();
    final normalized = <String, Object?>{};
    for (final key in sortedKeys) {
      normalized[key] = _canonicalizeValue(map[key]);
    }
    return normalized;
  }

  Object? _canonicalizeValue(Object? value) {
    if (value is Map<String, Object?>) {
      return _canonicalizeMap(value);
    }
    if (value is Map) {
      final converted = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is String) {
          converted[entry.key as String] = entry.value;
        }
      }
      return _canonicalizeMap(converted);
    }
    if (value is List) {
      return value.map(_canonicalizeValue).toList(growable: false);
    }
    return value;
  }

  String _hashCanonical(Map<String, Object?> value) {
    final encoded = jsonEncode(value);
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in encoded.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    if (hash < 0) {
      hash = hash & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  String _hashTokenReferences(Map<String, Object?> payload) {
    final tokens = <String>[];

    void walk(Object? node) {
      if (node is String) {
        if (node.startsWith(r'$')) {
          tokens.add(node);
        }
        return;
      }
      if (node is List) {
        for (final item in node) {
          walk(item);
        }
        return;
      }
      if (node is Map) {
        for (final entry in node.entries) {
          walk(entry.value);
        }
      }
    }

    walk(payload);
    tokens.sort();
    final canonical = <String, Object?>{'tokens': tokens};
    return _hashCanonical(canonical);
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _RawScanResult {
  const _RawScanResult({
    required this.rawValuesDetected,
    required this.firstPath,
  });

  final bool rawValuesDetected;
  final String firstPath;
}
