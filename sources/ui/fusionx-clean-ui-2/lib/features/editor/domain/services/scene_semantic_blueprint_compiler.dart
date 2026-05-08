import 'dart:convert';

import '../models/refusion_scene_program_models.dart';
import '../models/scene_semantic_blueprint_models.dart';
import '../models/scene_runtime_node.dart';
import 'scene_semantic_blueprint_service.dart';
import 'scene_semantic_component_registry.dart';
import 'scene_semantic_constraint_layout_solver.dart';
import 'scene_semantic_token_registry.dart';
import 'scene_runtime_component_tree.dart';

const String kSceneDeterminismProofTag = 'TF_SCENE_DETERMINISM_PROOF';
const String kSceneHctBlueprintCompilerProofTag =
    'TF_SCENE_HCT_BLUEPRINT_COMPILER_PROOF';

class SceneSemanticBlueprintRuntimeSourceMaps {
  SceneSemanticBlueprintRuntimeSourceMaps({
    required Map<String, List<String>> runtimeNodeIdsByComponentId,
    required Map<String, String> runtimeNodeToComponentId,
    required Map<String, String> runtimeNodeToLayerId,
  })  : runtimeNodeIdsByComponentId = Map.unmodifiable(
          runtimeNodeIdsByComponentId.map(
            (key, value) => MapEntry<String, List<String>>(
              key,
              List<String>.unmodifiable(value),
            ),
          ),
        ),
        runtimeNodeToComponentId = Map.unmodifiable(runtimeNodeToComponentId),
        runtimeNodeToLayerId = Map.unmodifiable(runtimeNodeToLayerId);

  final Map<String, List<String>> runtimeNodeIdsByComponentId;
  final Map<String, String> runtimeNodeToComponentId;
  final Map<String, String> runtimeNodeToLayerId;
}

class SceneSemanticBlueprintCompileResult {
  SceneSemanticBlueprintCompileResult({
    required List<ReFusionSceneProgramIssue> issues,
    this.blueprint,
    this.program,
    this.runtimeTree,
    this.sourceMaps,
    this.blueprintHash,
    this.hctHash,
    this.sceneProgramHash,
  }) : issues = List.unmodifiable(issues);

  final List<ReFusionSceneProgramIssue> issues;
  final SemanticSceneBlueprint? blueprint;
  final ReFusionSceneProgram? program;
  final SceneRuntimeComponentTree? runtimeTree;
  final SceneSemanticBlueprintRuntimeSourceMaps? sourceMaps;
  final String? blueprintHash;
  final String? hctHash;
  final String? sceneProgramHash;

  bool get isValid =>
      blueprint != null &&
      program != null &&
      runtimeTree != null &&
      sourceMaps != null &&
      !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneSemanticBlueprintCompiler {
  SceneSemanticBlueprintCompiler({
    SceneSemanticBlueprintService? service,
    SceneSemanticTokenRegistry? tokenRegistry,
    SceneSemanticComponentRegistry? componentRegistry,
    SceneSemanticConstraintLayoutSolver? layoutSolver,
  })  : _service = service ?? SceneSemanticBlueprintService(),
        _tokenRegistry = tokenRegistry ?? SceneSemanticTokenRegistry(),
        _componentRegistry =
            componentRegistry ?? SceneSemanticComponentRegistry(),
        _layoutSolver =
            layoutSolver ?? const SceneSemanticConstraintLayoutSolver();

  final SceneSemanticBlueprintService _service;
  final SceneSemanticTokenRegistry _tokenRegistry;
  final SceneSemanticComponentRegistry _componentRegistry;
  final SceneSemanticConstraintLayoutSolver _layoutSolver;

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

    final runtimeArtifacts = _buildRuntimeArtifacts(
      blueprint: validation.blueprint!,
      issues: issues,
    );
    if (runtimeArtifacts == null) {
      return SceneSemanticBlueprintCompileResult(
        issues: issues,
        blueprint: validation.blueprint,
      );
    }

    final lowered = _service.lowerToSceneProgram(validation.blueprint!);
    issues.addAll(lowered.issues);
    if (!lowered.isValid || lowered.program == null) {
      return SceneSemanticBlueprintCompileResult(
        issues: issues,
        blueprint: validation.blueprint,
        runtimeTree: runtimeArtifacts.tree,
        sourceMaps: runtimeArtifacts.sourceMaps,
        hctHash: runtimeArtifacts.hctHash,
      );
    }

    final blueprintHash = _hashCanonical(_blueprintToCanonicalMap(payload));
    final firstProgramHash =
        _hashCanonical(_programToCanonicalMap(lowered.program!));
    final firstHctHash = runtimeArtifacts.hctHash;
    final sourceMaps = _withLayerSourceMap(
      runtimeArtifacts.sourceMaps,
      _buildLayerMap(lowered.program!),
    );

    var deterministic = true;
    var failureReason = 'none';
    for (var iteration = 0; iteration < determinismIterations; iteration += 1) {
      final replayValidation = _service.validate(payload);
      if (!replayValidation.isValid || replayValidation.blueprint == null) {
        deterministic = false;
        failureReason = 'validation_failed';
        break;
      }
      final replayRuntime = _buildRuntimeArtifacts(
        blueprint: replayValidation.blueprint!,
        issues: <ReFusionSceneProgramIssue>[],
      );
      if (replayRuntime == null) {
        deterministic = false;
        failureReason = 'hct_build_failed';
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
      final replayProgramHash =
          _hashCanonical(_programToCanonicalMap(replayLowered.program!));
      if (replayProgramHash != firstProgramHash) {
        deterministic = false;
        failureReason = 'program_hash_mismatch:$replayProgramHash';
        break;
      }
      if (replayRuntime.hctHash != firstHctHash) {
        deterministic = false;
        failureReason = 'hct_hash_mismatch:${replayRuntime.hctHash}';
        break;
      }
    }
    if (rawScan.rawValuesDetected && !allowRawValueOverride) {
      deterministic = false;
      failureReason = 'raw_values_detected_without_override';
    }
    final passed =
        deterministic && (!rawScan.rawValuesDetected || allowRawValueOverride);

    issues.add(
      ReFusionSceneProgramIssue(
        severity: passed
            ? ReFusionSceneProgramIssueSeverity.info
            : ReFusionSceneProgramIssueSeverity.error,
        message: '$kSceneDeterminismProofTag '
            'blueprintHash=$blueprintHash '
            'hctHash=$firstHctHash '
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
    issues.add(
      ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.info,
        message: '$kSceneHctBlueprintCompilerProofTag '
            'components=${validation.blueprint!.components.length} '
            'runtimeNodes=${runtimeArtifacts.tree.nodeById.length} '
            'beats=${validation.blueprint!.beats.length} '
            'sourceMapComponents=${sourceMaps.runtimeNodeIdsByComponentId.length} '
            'sourceMapRuntimeNodes=${sourceMaps.runtimeNodeToComponentId.length} '
            'hctHash=$firstHctHash '
            'sceneProgramHash=$firstProgramHash '
            'passed=${passed.toString()}',
        path: r'$',
      ),
    );

    return SceneSemanticBlueprintCompileResult(
      issues: issues,
      blueprint: validation.blueprint,
      program: lowered.program,
      runtimeTree: runtimeArtifacts.tree,
      sourceMaps: sourceMaps,
      blueprintHash: blueprintHash,
      hctHash: firstHctHash,
      sceneProgramHash: firstProgramHash,
    );
  }

  _RuntimeCompileArtifacts? _buildRuntimeArtifacts({
    required SemanticSceneBlueprint blueprint,
    required List<ReFusionSceneProgramIssue> issues,
  }) {
    final profile = _canvasProfileFromBlueprint(blueprint);
    final layoutResult = _layoutSolver.solve(
      components: blueprint.components,
      tokenRegistry: _tokenRegistry,
      componentRegistry: _componentRegistry,
      profile: profile,
    );
    issues.addAll(layoutResult.issues);
    if (layoutResult.issues.any(
      (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
    )) {
      return null;
    }

    final runtimeNodes = <SceneRuntimeNode>[
      SceneRuntimeNode(
        id: '__scene_root__',
        nodeType: SceneRuntimeNodeType.sceneRoot,
        metadata: <String, Object?>{
          'name': blueprint.name,
          'width': _profileWidth(profile),
          'height': _profileHeight(profile),
          'localLeft': 0.0,
          'localTop': 0.0,
          'startMs': 0,
          'endMs': blueprint.durationMs,
        },
      ),
    ];

    final sortedBeats = blueprint.beats.toList(growable: false)
      ..sort((left, right) => left.startMs.compareTo(right.startMs));
    for (var i = 0; i < sortedBeats.length; i += 1) {
      final beat = sortedBeats[i];
      runtimeNodes.add(
        SceneRuntimeNode(
          id: _beatNodeId(beat.id),
          parentId: '__scene_root__',
          nodeType: SceneRuntimeNodeType.beatScope,
          zOrder: i,
          metadata: <String, Object?>{
            'beatId': beat.id,
            'intent': beat.intent,
            'startMs': beat.startMs,
            'endMs': beat.endMs,
            'componentRefs': beat.componentRefs,
          },
        ),
      );
    }

    final beatScopeByComponentId = _beatScopeByComponent(blueprint);
    final runtimeNodeIdsByComponentId = <String, List<String>>{};
    final runtimeNodeToComponentId = <String, String>{};

    for (var index = 0; index < blueprint.components.length; index += 1) {
      final component = blueprint.components[index];
      final template = _componentRegistry.instantiateRuntimeTemplate(
        component: component,
        index: index,
      );
      issues.addAll(template.issues);
      if (!template.isValid || template.nodes == null) {
        continue;
      }
      final componentParent =
          beatScopeByComponentId[component.id] ?? '__scene_root__';
      final componentBounds = layoutResult.boundsByComponent[component.id];
      final componentNodeIds = <String>[];

      for (final templateNode in template.nodes!) {
        final isComponentRoot = templateNode.id == component.id;
        final slotBounds = templateNode.slotId == null
            ? null
            : layoutResult
                .boundsBySlot['${component.id}::${templateNode.slotId}'];
        final node = templateNode.copyWith(
          parentId: isComponentRoot ? componentParent : templateNode.parentId,
          metadata: _withRuntimeGeometry(
            templateNode.metadata,
            componentBounds: componentBounds,
            slotBounds: slotBounds,
            componentId: component.id,
            slotId: templateNode.slotId,
            durationMs: blueprint.durationMs,
          ),
        );
        runtimeNodes.add(node);
        componentNodeIds.add(node.id);
        runtimeNodeToComponentId[node.id] = component.id;
      }

      final slotIds = component.slots.keys.toList(growable: false)..sort();
      for (var slotIndex = 0; slotIndex < slotIds.length; slotIndex += 1) {
        final slotId = slotIds[slotIndex];
        final slotNodeId = '${component.id}::slot::$slotId';
        if (!runtimeNodeToComponentId.containsKey(slotNodeId)) {
          continue;
        }
        final slotBounds =
            layoutResult.boundsBySlot['${component.id}::$slotId'];
        final leafId = '$slotNodeId::leaf';
        final slotValue = component.slots[slotId];
        final leafMetadata = <String, Object?>{
          'componentId': component.id,
          'slotId': slotId,
          'slotValue': slotValue,
          'startMs': 0,
          'endMs': blueprint.durationMs,
          'x': 0.0,
          'y': 0.0,
          'localLeft': 0.0,
          'localTop': 0.0,
          'width': slotBounds?.width ?? 0.0,
          'height': slotBounds?.height ?? 0.0,
        };
        runtimeNodes.add(
          SceneRuntimeNode(
            id: leafId,
            parentId: slotNodeId,
            nodeType: _runtimeNodeTypeForSlotValue(
              slotValue: slotValue,
              slotId: slotId,
            ),
            sourceComponentId: component.id,
            slotId: slotId,
            zOrder: slotIndex,
            metadata: leafMetadata,
          ),
        );
        componentNodeIds.add(leafId);
        runtimeNodeToComponentId[leafId] = component.id;
      }

      runtimeNodeIdsByComponentId[component.id] =
          List<String>.unmodifiable(componentNodeIds);
    }

    final treeResult = SceneRuntimeComponentTree.build(runtimeNodes);
    if (!treeResult.isValid || treeResult.tree == null) {
      for (final issue in treeResult.issues) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'HCT build failure `${issue.code}`: ${issue.message}',
            path: issue.path ?? 'runtimeTree',
          ),
        );
      }
      return null;
    }

    final sourceMaps = SceneSemanticBlueprintRuntimeSourceMaps(
      runtimeNodeIdsByComponentId: runtimeNodeIdsByComponentId,
      runtimeNodeToComponentId: runtimeNodeToComponentId,
      runtimeNodeToLayerId: const <String, String>{},
    );
    final tree = treeResult.tree!;
    final hctHash = _hashCanonical(_runtimeTreeToCanonicalMap(tree));
    return _RuntimeCompileArtifacts(
      tree: tree,
      sourceMaps: sourceMaps,
      hctHash: hctHash,
    );
  }

  Map<String, Object?> _runtimeTreeToCanonicalMap(
    SceneRuntimeComponentTree tree,
  ) {
    final sortedIds = tree.nodeById.keys.toList(growable: false)..sort();
    final nodes = <Object?>[];
    for (final id in sortedIds) {
      final node = tree.nodeById[id]!;
      nodes.add(
        <String, Object?>{
          'id': node.id,
          'nodeType': node.nodeType.name,
          'parentId': node.parentId,
          'zOrder': node.zOrder,
          'sourceComponentId': node.sourceComponentId,
          'sourceLayerId': node.sourceLayerId,
          'slotId': node.slotId,
          'metadata': _canonicalizeValue(node.metadata),
        },
      );
    }
    return _canonicalizeMap(
      <String, Object?>{
        'rootNodeId': tree.rootNodeId,
        'nodes': nodes,
      },
    );
  }

  Map<String, String> _beatScopeByComponent(SemanticSceneBlueprint blueprint) {
    final mapping = <String, String>{};
    final beats = blueprint.beats.toList(growable: false)
      ..sort((left, right) => left.startMs.compareTo(right.startMs));
    for (final beat in beats) {
      final beatNodeId = _beatNodeId(beat.id);
      for (final componentId in beat.componentRefs) {
        mapping.putIfAbsent(componentId, () => beatNodeId);
      }
    }
    return mapping;
  }

  String _beatNodeId(String beatId) => '__beat__$beatId';

  SceneRuntimeNodeType _runtimeNodeTypeForSlotValue({
    required Object? slotValue,
    required String slotId,
  }) {
    final normalizedSlot = _normalize(slotId);
    if (slotValue is Map<String, Object?>) {
      final nodeType = slotValue['nodeType'];
      if (nodeType is String) {
        final parsed = _parseRuntimeNodeType(nodeType);
        if (parsed != null) {
          return parsed;
        }
      }
      final text = slotValue['text'];
      if (text is String && text.trim().isNotEmpty) {
        return SceneRuntimeNodeType.text;
      }
      final icon = slotValue['icon'];
      if (icon is String && icon.trim().isNotEmpty) {
        return SceneRuntimeNodeType.icon;
      }
    }
    if (normalizedSlot.contains('text') ||
        normalizedSlot.contains('title') ||
        normalizedSlot.contains('body') ||
        normalizedSlot.contains('label') ||
        normalizedSlot.contains('placeholder')) {
      return SceneRuntimeNodeType.text;
    }
    if (slotValue is String) {
      return SceneRuntimeNodeType.icon;
    }
    return SceneRuntimeNodeType.shape;
  }

  SceneRuntimeNodeType? _parseRuntimeNodeType(String raw) {
    final normalized = _normalize(raw);
    for (final value in SceneRuntimeNodeType.values) {
      if (_normalize(value.name) == normalized) {
        return value;
      }
    }
    return null;
  }

  Map<String, String> _buildLayerMap(ReFusionSceneProgram program) {
    final output = <String, String>{};
    for (final layer in program.layers) {
      final layerId = layer.id.trim();
      final componentId = layerId.endsWith('-layer')
          ? layerId.substring(0, layerId.length - 6)
          : layerId;
      output[componentId] = layer.id;
    }
    return output;
  }

  SceneSemanticBlueprintRuntimeSourceMaps _withLayerSourceMap(
    SceneSemanticBlueprintRuntimeSourceMaps sourceMaps,
    Map<String, String> layerMap,
  ) {
    final runtimeNodeToLayerId = <String, String>{};
    for (final entry in sourceMaps.runtimeNodeToComponentId.entries) {
      final layerId = layerMap[entry.value];
      if (layerId == null) {
        continue;
      }
      runtimeNodeToLayerId[entry.key] = layerId;
    }
    return SceneSemanticBlueprintRuntimeSourceMaps(
      runtimeNodeIdsByComponentId: sourceMaps.runtimeNodeIdsByComponentId,
      runtimeNodeToComponentId: sourceMaps.runtimeNodeToComponentId,
      runtimeNodeToLayerId: runtimeNodeToLayerId,
    );
  }

  Map<String, Object?> _withRuntimeGeometry(
    Map<String, Object?> original, {
    required SceneSemanticLayoutBounds? componentBounds,
    required SceneSemanticLayoutBounds? slotBounds,
    required String componentId,
    required String? slotId,
    required int durationMs,
  }) {
    final output = <String, Object?>{
      ...original,
      'componentId': componentId,
      'startMs': 0,
      'endMs': durationMs,
    };
    final bounds = slotBounds ?? componentBounds;
    if (bounds != null) {
      final localLeft = (slotBounds != null && componentBounds != null)
          ? slotBounds.left - componentBounds.left
          : bounds.left;
      final localTop = (slotBounds != null && componentBounds != null)
          ? slotBounds.top - componentBounds.top
          : bounds.top;
      output['x'] = localLeft;
      output['y'] = localTop;
      output['localLeft'] = 0.0;
      output['localTop'] = 0.0;
      output['width'] = bounds.width;
      output['height'] = bounds.height;
    }
    if (slotId != null) {
      output['slotId'] = slotId;
    }
    return output;
  }

  SceneSemanticCanvasProfile _canvasProfileFromBlueprint(
    SemanticSceneBlueprint blueprint,
  ) {
    final raw = blueprint.metadata['canvasProfile'];
    final normalized = _normalize(raw is String ? raw : 'story_9_16');
    switch (normalized) {
      case 'landscape169':
      case 'landscape16x9':
        return SceneSemanticCanvasProfile.landscape169;
      case 'square11':
      case 'square1x1':
        return SceneSemanticCanvasProfile.square11;
      case 'portrait45':
      case 'portrait4x5':
        return SceneSemanticCanvasProfile.portrait45;
      default:
        return SceneSemanticCanvasProfile.story916;
    }
  }

  double _profileWidth(SceneSemanticCanvasProfile profile) {
    switch (profile) {
      case SceneSemanticCanvasProfile.story916:
        return 1080;
      case SceneSemanticCanvasProfile.landscape169:
        return 1920;
      case SceneSemanticCanvasProfile.square11:
        return 1080;
      case SceneSemanticCanvasProfile.portrait45:
        return 1080;
    }
  }

  double _profileHeight(SceneSemanticCanvasProfile profile) {
    switch (profile) {
      case SceneSemanticCanvasProfile.story916:
        return 1920;
      case SceneSemanticCanvasProfile.landscape169:
        return 1080;
      case SceneSemanticCanvasProfile.square11:
        return 1080;
      case SceneSemanticCanvasProfile.portrait45:
        return 1350;
    }
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

class _RuntimeCompileArtifacts {
  const _RuntimeCompileArtifacts({
    required this.tree,
    required this.sourceMaps,
    required this.hctHash,
  });

  final SceneRuntimeComponentTree tree;
  final SceneSemanticBlueprintRuntimeSourceMaps sourceMaps;
  final String hctHash;
}
