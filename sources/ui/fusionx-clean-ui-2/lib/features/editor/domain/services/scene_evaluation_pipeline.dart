import 'dart:math' as math;

import '../models/refusion_scene_program_models.dart';
import '../models/scene_runtime_node.dart';
import 'evaluated_frame_truth.dart';
import 'scene_coordinate_system.dart';
import 'scene_evaluation_diagnostics.dart';
import 'scene_global_parent_graph.dart';
import 'scene_runtime_component_tree.dart';
import 'scene_slot_layout_models.dart';
import 'scene_slot_layout_solver.dart';
import 'scene_runtime_transform_composer.dart';

class SceneEvaluationPipelineRequest {
  const SceneEvaluationPipelineRequest({
    required this.program,
    required this.globalTimeMs,
    this.canvas = const SceneCanvasMetrics(width: 1080, height: 1920),
  });

  final ReFusionSceneProgram program;
  final int globalTimeMs;
  final SceneCanvasMetrics canvas;
}

class SceneEvaluationPipelineResult {
  const SceneEvaluationPipelineResult({
    required this.truth,
    required this.issues,
    required this.diagnostics,
  });

  final EvaluatedFrameTruth truth;
  final List<ReFusionSceneProgramIssue> issues;
  final SceneEvaluationDiagnostics diagnostics;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
      );
}

class SceneEvaluationPipeline {
  const SceneEvaluationPipeline({
    SceneRuntimeTransformComposer? transformComposer,
    SceneGlobalParentGraph? globalParentGraph,
    SceneSlotLayoutSolver? slotLayoutSolver,
  })  : _transformComposer =
            transformComposer ?? const SceneRuntimeTransformComposer(),
        _globalParentGraph =
            globalParentGraph ?? const SceneGlobalParentGraph(),
        _slotLayoutSolver = slotLayoutSolver ?? const SceneSlotLayoutSolver();

  final SceneRuntimeTransformComposer _transformComposer;
  final SceneGlobalParentGraph _globalParentGraph;
  final SceneSlotLayoutSolver _slotLayoutSolver;
  static const String _parentGraphProofTag = 'TF_SCENE_PARENT_GRAPH_PROOF';
  static const String _slotLayoutProofTag = 'TF_SCENE_SLOT_LAYOUT_PROOF';
  static const String _componentHierarchyProofTag =
      'TF_SCENE_COMPONENT_HIERARCHY_PROOF';
  static const String _componentLifecycleProofTag =
      'TF_SCENE_COMPONENT_LIFECYCLE_PROOF';

  SceneEvaluationPipelineResult evaluate(
      SceneEvaluationPipelineRequest request) {
    final issues = <ReFusionSceneProgramIssue>[];
    final safeTime = request.globalTimeMs.clamp(0, request.program.durationMs);
    final nodes = <SceneRuntimeNode>[
      SceneRuntimeNode(
        id: _sceneRootId,
        nodeType: SceneRuntimeNodeType.sceneRoot,
        metadata: <String, Object?>{
          'x': 0.0,
          'y': 0.0,
          'width': request.canvas.width,
          'height': request.canvas.height,
          'localLeft': -(request.canvas.width / 2.0),
          'localTop': -(request.canvas.height / 2.0),
          'startMs': 0,
          'endMs': request.program.durationMs,
          'opacity': 1.0,
        },
      ),
    ];
    final runtimeNodeById = <String, SceneRuntimeNode>{};
    final sourceMaps = <String, Object?>{};
    final stateByNodeId = <String, _ElementEvaluationState>{};
    final componentIdByRuntimeNodeId = <String, String>{};
    final componentTypeByRuntimeNodeId = <String, String>{};
    final slotIdByRuntimeNodeId = <String, String>{};
    final layoutRoleByRuntimeNodeId = <String, String>{};
    final parentGraph = _globalParentGraph.build(request.program);
    for (final graphIssue in parentGraph.issues) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.warning,
          message: 'Scene global parent graph: ${graphIssue.message}',
          path: graphIssue.path,
        ),
      );
    }

    for (var layerIndex = 0;
        layerIndex < request.program.layers.length;
        layerIndex += 1) {
      final layer = request.program.layers[layerIndex];
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        final element = layer.elements[elementIndex];
        final runtimeNodeId = _runtimeNodeId(
          layerId: layer.id,
          elementId: element.id,
        );
        stateByNodeId[runtimeNodeId] = _evaluateElementState(
          layer: layer,
          element: element,
          timelineTimeMs: safeTime,
        );
      }
    }

    for (var layerIndex = 0;
        layerIndex < request.program.layers.length;
        layerIndex += 1) {
      final layer = request.program.layers[layerIndex];
      final layerStart = layer.startMs;
      final layerEnd = layer.startMs + layer.durationMs;
      for (var elementIndex = 0;
          elementIndex < layer.elements.length;
          elementIndex += 1) {
        final element = layer.elements[elementIndex];
        final runtimeNodeId = _runtimeNodeId(
          layerId: layer.id,
          elementId: element.id,
        );
        final componentId = _componentIdFor(element);
        final componentType = _componentTypeFor(element);
        final slotId = _slotIdFor(element);
        final layoutRole = _layoutRoleFor(element);
        if (componentId != null && componentId.trim().isNotEmpty) {
          componentIdByRuntimeNodeId[runtimeNodeId] = componentId;
        }
        if (componentType != null && componentType.trim().isNotEmpty) {
          componentTypeByRuntimeNodeId[runtimeNodeId] = componentType;
        }
        if (slotId != null && slotId.trim().isNotEmpty) {
          slotIdByRuntimeNodeId[runtimeNodeId] = slotId;
        }
        if (layoutRole != null && layoutRole.trim().isNotEmpty) {
          layoutRoleByRuntimeNodeId[runtimeNodeId] = layoutRole;
        }
        final parentNodeId = parentGraph.parentByRuntimeNodeId[runtimeNodeId] ??
            SceneGlobalParentGraph.sceneRootNodeId;
        final baseState = stateByNodeId[runtimeNodeId]!;
        final parentState =
            parentNodeId == _sceneRootId ? null : stateByNodeId[parentNodeId];
        final normalizedState = _normalizeLegacyAbsoluteChildState(
          childState: baseState,
          parentState: parentState,
          crossLayerParent: parentNodeId != _sceneRootId &&
              !parentNodeId.startsWith('__layer__${layer.id}__element__'),
        );

        final runtimeNode = SceneRuntimeNode(
          id: runtimeNodeId,
          nodeType: _runtimeTypeForElementKind(element.kind),
          parentId: parentNodeId,
          zOrder: (layerIndex * 1000) + elementIndex,
          sourceComponentId: _componentIdFor(element),
          sourceLayerId: layer.id,
          sourceElementId: element.id,
          slotId: _slotIdFor(element),
          metadata: <String, Object?>{
            'x': normalizedState.x,
            'y': normalizedState.y,
            'scaleX': normalizedState.scaleX,
            'scaleY': normalizedState.scaleY,
            'rotationDeg': normalizedState.rotationDeg,
            'opacity': normalizedState.opacity,
            'width': normalizedState.width,
            'height': normalizedState.height,
            // Center-origin truth: x/y represent element center.
            'localLeft': -(normalizedState.width / 2.0),
            'localTop': -(normalizedState.height / 2.0),
            'startMs': layerStart,
            'endMs': layerEnd,
          },
        );
        nodes.add(runtimeNode);
        runtimeNodeById[runtimeNodeId] = runtimeNode;
        sourceMaps[runtimeNodeId] = <String, Object?>{
          'layerId': layer.id,
          'elementId': element.id,
          'parentNodeId': parentNodeId,
          'componentId': componentId,
          'componentType': componentType,
          'slotId': slotId,
          'layoutRole': layoutRole,
        };
      }
    }

    final componentBinding = _buildComponentRuntimeBinding(
      runtimeNodeById: runtimeNodeById,
      componentIdByRuntimeNodeId: componentIdByRuntimeNodeId,
      componentTypeByRuntimeNodeId: componentTypeByRuntimeNodeId,
      slotIdByRuntimeNodeId: slotIdByRuntimeNodeId,
      layoutRoleByRuntimeNodeId: layoutRoleByRuntimeNodeId,
      rootNodeId: _sceneRootId,
    );
    for (final entry in runtimeNodeById.entries.toList(growable: false)) {
      final nodeId = entry.key;
      final node = entry.value;
      final parentOverride =
          componentBinding.parentOverrideByRuntimeNodeId[nodeId];
      final componentId = componentIdByRuntimeNodeId[nodeId];
      final slotId = slotIdByRuntimeNodeId[nodeId];
      runtimeNodeById[nodeId] = node.copyWith(
        parentId: parentOverride ?? node.parentId,
        sourceComponentId: componentId ?? node.sourceComponentId,
        slotId: slotId ?? node.slotId,
      );
      final sourceMapRaw = sourceMaps[nodeId];
      if (sourceMapRaw is Map<String, Object?>) {
        final merged = <String, Object?>{...sourceMapRaw};
        merged['parentNodeId'] = parentOverride ?? node.parentId;
        if (componentId != null && componentId.trim().isNotEmpty) {
          merged['componentId'] = componentId;
        }
        final componentType = componentTypeByRuntimeNodeId[nodeId];
        if (componentType != null && componentType.trim().isNotEmpty) {
          merged['componentType'] = componentType;
        }
        if (slotId != null && slotId.trim().isNotEmpty) {
          merged['slotId'] = slotId;
        }
        sourceMaps[nodeId] = merged;
      }
    }
    for (final node in componentBinding.syntheticNodes) {
      nodes.add(node);
      runtimeNodeById[node.id] = node;
      sourceMaps[node.id] = <String, Object?>{
        'synthetic': true,
        'nodeType': node.nodeType.name,
        'componentId': node.sourceComponentId,
        'slotId': node.slotId,
        'parentNodeId': node.parentId,
      };
    }
    for (final node in runtimeNodeById.values) {
      if (node.id == _sceneRootId) {
        continue;
      }
      if (nodes.any((entry) => entry.id == node.id)) {
        continue;
      }
      nodes.add(node);
    }

    final treeResult = SceneRuntimeComponentTree.build(nodes);
    if (!treeResult.isValid || treeResult.tree == null) {
      for (final issue in treeResult.issues) {
        issues.add(
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Scene evaluation tree invalid: ${issue.message}',
            path: issue.path ?? 'sceneEvaluationPipeline.nodes',
          ),
        );
      }
      final emptyTruth = EvaluatedFrameTruth(
        coordinateSystem: SceneCoordinateSystem.canonical,
        canvas: request.canvas,
        globalTimeMs: safeTime,
        sceneId: request.program.name,
        nodesById: const <String, EvaluatedSceneNode>{},
        sourceMaps: sourceMaps,
      );
      return SceneEvaluationPipelineResult(
        truth: emptyTruth,
        issues: List.unmodifiable(issues),
        diagnostics: SceneEvaluationDiagnostics(events: const []),
      );
    }

    final composition = _transformComposer.compose(
      tree: treeResult.tree!,
      timelineTimeMs: safeTime,
    );
    final slotLayout = _slotLayoutSolver.solve(
      tree: treeResult.tree!,
      composition: composition,
    );
    for (final issue in slotLayout.issues) {
      issues.add(
        ReFusionSceneProgramIssue(
          severity: issue.severity,
          message: issue.message,
          path: issue.path ?? 'sceneSlotLayout',
        ),
      );
    }

    final evaluatedNodes = <String, EvaluatedSceneNode>{};
    for (final entry in composition.recordsByNodeId.entries) {
      final nodeId = entry.key;
      if (nodeId == _sceneRootId) {
        continue;
      }
      final runtimeNode = runtimeNodeById[nodeId];
      if (runtimeNode == null) {
        continue;
      }
      final record = entry.value;
      final resolvedBounds = slotLayout.slotBoundsByNodeId[nodeId] ??
          _sceneRuntimeRectToSlotRect(record.worldBounds);
      final worldCenterX = resolvedBounds.left + (resolvedBounds.width / 2);
      final worldCenterY = resolvedBounds.top + (resolvedBounds.height / 2);
      final worldRectCenter = SceneRectCenter(
        centerX: worldCenterX,
        centerY: worldCenterY,
        width: resolvedBounds.width,
        height: resolvedBounds.height,
      );
      final viewportRect = SceneCoordinateSystem.centerRectToViewportRect(
        rect: worldRectCenter,
        canvas: request.canvas,
      );
      final state = stateByNodeId[nodeId];
      final slotBoundsCenter = _slotBoundsCenterFor(
        nodeId: nodeId,
        runtimeNode: runtimeNode,
        tree: treeResult.tree!,
        slotLayout: slotLayout,
      );
      final contentBoundsCenter = _contentBoundsCenterFor(
        runtimeNode: runtimeNode,
        tree: treeResult.tree!,
        slotLayout: slotLayout,
      );
      evaluatedNodes[nodeId] = EvaluatedSceneNode(
        nodeId: nodeId,
        sourceLayerId: runtimeNode.sourceLayerId,
        sourceElementId: runtimeNode.sourceElementId ??
            _sourceElementIdFromRuntimeNodeId(nodeId),
        sourceComponentId: runtimeNode.sourceComponentId,
        parentNodeId: runtimeNode.parentId,
        nodeType: runtimeNode.nodeType.name,
        slotId: runtimeNode.slotId,
        localTransform: EvaluatedTransform2D(
          m00: SceneRuntimeTransform.fromNode(runtimeNode).m00,
          m01: SceneRuntimeTransform.fromNode(runtimeNode).m01,
          m02: SceneRuntimeTransform.fromNode(runtimeNode).m02,
          m10: SceneRuntimeTransform.fromNode(runtimeNode).m10,
          m11: SceneRuntimeTransform.fromNode(runtimeNode).m11,
          m12: SceneRuntimeTransform.fromNode(runtimeNode).m12,
        ),
        worldTransform: EvaluatedTransform2D(
          m00: record.worldTransform.m00,
          m01: record.worldTransform.m01,
          m02: record.worldTransform.m02,
          m10: record.worldTransform.m10,
          m11: record.worldTransform.m11,
          m12: record.worldTransform.m12,
        ),
        localBoundsCenter: SceneRectCenter(
          centerX: 0,
          centerY: 0,
          width: record.worldBounds.width,
          height: record.worldBounds.height,
        ),
        worldBoundsCenter: worldRectCenter,
        viewportBounds: viewportRect,
        slotBoundsCenter: slotBoundsCenter,
        contentBoundsCenter: contentBoundsCenter,
        effectiveOpacity: record.effectiveOpacity,
        active: record.active,
        visible: record.active && record.effectiveOpacity > 0.001,
        textMetrics: _textMetricsFor(state),
        zOrder: runtimeNode.zOrder,
      );
    }

    final truth = EvaluatedFrameTruth(
      coordinateSystem: SceneCoordinateSystem.canonical,
      canvas: request.canvas,
      globalTimeMs: safeTime,
      sceneId: request.program.name,
      nodesById: evaluatedNodes,
      sourceMaps: sourceMaps,
    );
    final hierarchyStats = _hierarchyStats(evaluatedNodes);
    final lifecycleStats = _lifecycleStats(evaluatedNodes);
    final diagnostics = SceneEvaluationDiagnostics(events: const []).append(
      tag: _parentGraphProofTag,
      fields: <String, Object?>{
        'sceneId': request.program.name,
        'globalTimeMs': safeTime,
        'issueCount': parentGraph.issues.length,
        'missingParentCount': parentGraph.issues
            .where((issue) => issue.code == 'missing_parent')
            .length,
        'ambiguousParentCount': parentGraph.issues
            .where((issue) => issue.code == 'ambiguous_parent')
            .length,
        'fallbackReason':
            parentGraph.issues.isEmpty ? 'none' : parentGraph.issues.first.code,
      },
    ).append(
      tag: _slotLayoutProofTag,
      fields: <String, Object?>{
        'sceneId': request.program.name,
        'globalTimeMs': safeTime,
        'slotNodeCount': treeResult.tree!.nodeById.values
            .where((node) => node.nodeType == SceneRuntimeNodeType.slot)
            .length,
        'componentNodeCount': treeResult.tree!.nodeById.values
            .where((node) => node.nodeType == SceneRuntimeNodeType.component)
            .length,
        'nodesWithSlotId': treeResult.tree!.nodeById.values
            .where(
              (node) => (node.slotId?.trim().isNotEmpty ?? false),
            )
            .length,
        'runtimeTreeHash': treeResult.tree!.deterministicHash,
        'slotLayoutHash': slotLayout.deterministicLayoutHash,
        'fallbackReason': 'none',
      },
    ).append(
      tag: SceneEvaluationDiagnostics.frameTruthProofTag,
      fields: <String, Object?>{
        'sceneId': request.program.name,
        'globalTimeMs': safeTime,
        'coordinateSystem': SceneCoordinateSystem.canonical.name,
        'nodeCount': truth.nodesById.length,
        'geometryHash': truth.geometryHash,
        'frameHash': truth.frameHash,
        'hctApplied': true,
        'usedCanonicalCoordinates': true,
        'fallbackReason': 'none',
      },
    ).append(
      tag: _componentHierarchyProofTag,
      fields: <String, Object?>{
        'sceneId': request.program.name,
        'globalTimeMs': safeTime,
        'nodesWithComponentId': hierarchyStats.nodesWithComponentId,
        'nodesWithSlotId': hierarchyStats.nodesWithSlotId,
        'nodesWithParent': hierarchyStats.nodesWithParent,
        'orphanParentRefs': hierarchyStats.orphanParentRefs,
        'fallbackReason':
            hierarchyStats.orphanParentRefs == 0 ? 'none' : 'orphan_parent_ref',
      },
    ).append(
      tag: _componentLifecycleProofTag,
      fields: <String, Object?>{
        'sceneId': request.program.name,
        'globalTimeMs': safeTime,
        'activeNodes': lifecycleStats.activeNodes,
        'inactiveNodes': lifecycleStats.inactiveNodes,
        'visibleNodes': lifecycleStats.visibleNodes,
        'hiddenNodes': lifecycleStats.hiddenNodes,
        'childActiveWhileParentInactive':
            lifecycleStats.childActiveWhileParentInactive,
        'childVisibleWhileParentHidden':
            lifecycleStats.childVisibleWhileParentHidden,
        'fallbackReason': (lifecycleStats.childActiveWhileParentInactive == 0 &&
                lifecycleStats.childVisibleWhileParentHidden == 0)
            ? 'none'
            : 'lifecycle_mismatch',
      },
    );

    return SceneEvaluationPipelineResult(
      truth: truth,
      issues: List.unmodifiable(issues),
      diagnostics: diagnostics,
    );
  }

  String _runtimeNodeId({
    required String layerId,
    required String elementId,
  }) {
    return '__layer__${layerId}__element__${elementId}';
  }

  SceneRuntimeNodeType _runtimeTypeForElementKind(String kind) {
    switch (_normalizeToken(kind)) {
      case 'text':
        return SceneRuntimeNodeType.text;
      case 'icon':
        return SceneRuntimeNodeType.icon;
      case 'image':
        return SceneRuntimeNodeType.image;
      case 'video':
        return SceneRuntimeNodeType.video;
      default:
        return SceneRuntimeNodeType.shape;
    }
  }

  EvaluatedTextMetrics? _textMetricsFor(_ElementEvaluationState? state) {
    if (state == null) {
      return null;
    }
    return EvaluatedTextMetrics(
      fontSize: state.fontSize,
      lineHeight: state.lineHeight,
      letterSpacing: state.letterSpacing,
      maxLines: state.maxLines,
      typewriterProgress: state.typewriterProgress,
    );
  }

  _ElementEvaluationState _evaluateElementState({
    required ReFusionSceneProgramLayer layer,
    required ReFusionSceneProgramElement element,
    required int timelineTimeMs,
  }) {
    var x = _readPosition(element.properties, axis: 'x') ?? 0.0;
    var y = _readPosition(element.properties, axis: 'y') ?? 0.0;
    var width = _readScalar(element.properties, const <String>['width', 'w']);
    var height = _readScalar(element.properties, const <String>['height', 'h']);
    final textFrame =
        _mapFromProperties(element.properties, const <String>['textFrame']);
    width ??=
        _readDouble(textFrame?['width']) ?? _readDouble(textFrame?['maxWidth']);
    height ??= _readDouble(textFrame?['height']) ??
        _readDouble(textFrame?['maxHeight']);
    var scaleX = _readScalar(element.properties, const <String>['scaleX']) ??
        _readScalar(element.properties, const <String>['scale']) ??
        1.0;
    var scaleY = _readScalar(element.properties, const <String>['scaleY']) ??
        _readScalar(element.properties, const <String>['scale']) ??
        1.0;
    var rotationDeg = _readScalar(
            element.properties, const <String>['rotationDeg', 'rotation']) ??
        0.0;
    var opacity =
        _readScalar(element.properties, const <String>['opacity', 'alpha']) ??
            1.0;
    var fontSize =
        _readScalar(element.properties, const <String>['fontSize']) ?? 16.0;
    var lineHeight =
        _readScalar(element.properties, const <String>['lineHeight']) ?? 1.0;
    var letterSpacing =
        _readScalar(element.properties, const <String>['letterSpacing']) ?? 0.0;
    var maxLines =
        (_readScalar(element.properties, const <String>['maxLines']) ??
                _readDouble(textFrame?['maxLines']) ??
                1.0)
            .round();
    var typewriterProgress =
        _readScalar(element.properties, const <String>['typewriterProgress']) ??
            1.0;

    final allChannels = <ReFusionSceneProgramChannel>[
      ...layer.channels.where(
        (channel) =>
            _normalizeToken(channel.target) == _normalizeToken(element.id),
      ),
      ...element.channels,
    ];
    for (final channel in allChannels) {
      final property = _normalizeToken(channel.property);
      final value = _evaluateChannel(channel, timelineTimeMs);
      if (value == null) {
        continue;
      }
      if (property == 'x' ||
          property == 'positionx' ||
          property == 'position.x') {
        x = value;
      } else if (property == 'y' ||
          property == 'positiony' ||
          property == 'position.y') {
        y = value;
      } else if (property == 'width' || property == 'w') {
        width = value;
      } else if (property == 'height' || property == 'h') {
        height = value;
      } else if (property == 'scale' || property == 'scalex') {
        scaleX = value;
      } else if (property == 'scaley') {
        scaleY = value;
      } else if (property == 'rotation' || property == 'rotationdeg') {
        rotationDeg = value;
      } else if (property == 'opacity' || property == 'alpha') {
        opacity = value;
      } else if (property == 'fontsize') {
        fontSize = value;
      } else if (property == 'lineheight') {
        lineHeight = value;
      } else if (property == 'letterspacing') {
        letterSpacing = value;
      } else if (property == 'maxlines') {
        maxLines = value.round();
      } else if (property == 'typewriterprogress') {
        typewriterProgress = value.clamp(0.0, 1.0);
      }
    }

    width ??= _estimateTextWidth(
      element.text ?? '',
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      typewriterProgress: 1.0,
    );
    height ??= _estimateTextHeight(
      fontSize: fontSize,
      lineHeight: lineHeight,
      maxLines: maxLines,
    );

    return _ElementEvaluationState(
      x: x,
      y: y,
      width: math.max(1.0, width ?? 1.0),
      height: math.max(1.0, height ?? 1.0),
      scaleX: scaleX,
      scaleY: scaleY,
      rotationDeg: rotationDeg,
      opacity: opacity.clamp(0.0, 1.0),
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      maxLines: math.max(1, maxLines),
      typewriterProgress: typewriterProgress.clamp(0.0, 1.0),
    );
  }

  _ElementEvaluationState _normalizeLegacyAbsoluteChildState({
    required _ElementEvaluationState childState,
    required _ElementEvaluationState? parentState,
    required bool crossLayerParent,
  }) {
    if (!crossLayerParent || parentState == null) {
      return childState;
    }
    final parentWidth =
        math.max(1.0, parentState.width * parentState.scaleX.abs());
    final parentHeight =
        math.max(1.0, parentState.height * parentState.scaleY.abs());
    final childLooksGlobalX = childState.x.abs() > parentWidth;
    final childLooksGlobalY = childState.y.abs() > parentHeight;
    final canResolveAsLocalX =
        (childState.x - parentState.x).abs() <= parentWidth;
    final canResolveAsLocalY =
        (childState.y - parentState.y).abs() <= parentHeight;
    final shouldNormalize = (childLooksGlobalX || childLooksGlobalY) &&
        canResolveAsLocalX &&
        canResolveAsLocalY;
    if (!shouldNormalize) {
      return childState;
    }
    return childState.withPosition(
      x: childState.x - parentState.x,
      y: childState.y - parentState.y,
    );
  }

  double? _evaluateChannel(
    ReFusionSceneProgramChannel channel,
    int timelineTimeMs,
  ) {
    if (channel.keyframes.isEmpty) {
      return null;
    }
    final keyframes = channel.keyframes.toList(growable: false)
      ..sort((left, right) => left.timeMs.compareTo(right.timeMs));
    if (timelineTimeMs <= keyframes.first.timeMs) {
      return _asDouble(keyframes.first.value);
    }
    if (timelineTimeMs >= keyframes.last.timeMs) {
      return _asDouble(keyframes.last.value);
    }
    for (var index = 1; index < keyframes.length; index += 1) {
      final left = keyframes[index - 1];
      final right = keyframes[index];
      if (timelineTimeMs < left.timeMs || timelineTimeMs > right.timeMs) {
        continue;
      }
      final leftValue = _asDouble(left.value);
      final rightValue = _asDouble(right.value);
      if (leftValue == null || rightValue == null) {
        return leftValue ?? rightValue;
      }
      final span = right.timeMs - left.timeMs;
      if (span <= 0) {
        return rightValue;
      }
      final rawT = (timelineTimeMs - left.timeMs) / span;
      final easedT = _applyEasing(
        easing: right.easing ?? left.easing ?? 'linear',
        t: rawT.clamp(0.0, 1.0),
      );
      return leftValue + ((rightValue - leftValue) * easedT);
    }
    return null;
  }

  double _applyEasing({
    required String easing,
    required double t,
  }) {
    final normalized = _normalizeToken(easing);
    if (normalized == 'linear') {
      return t;
    }
    if (normalized == 'easein' || normalized == 'slowfast') {
      return t * t;
    }
    if (normalized == 'easeout' || normalized == 'fastslow') {
      final inv = 1.0 - t;
      return 1.0 - (inv * inv);
    }
    if (normalized == 'easeinout' ||
        normalized == 'easyease' ||
        normalized == 'cinematicease' ||
        normalized == 'slowfastslow') {
      return t * t * (3 - (2 * t));
    }
    if (normalized == 'fastslowfast') {
      return 0.5 - (math.cos(math.pi * t) / 2.0);
    }
    return t;
  }

  double? _readPosition(
    Map<String, Object?> map, {
    required String axis,
  }) {
    final scalar =
        _readScalar(map, <String>[axis, axis == 'x' ? 'left' : 'top']);
    if (scalar != null) {
      return scalar;
    }
    final positionRaw = map['position'];
    if (positionRaw is Map<String, Object?>) {
      final key = axis == 'x' ? 'x' : 'y';
      return _readDouble(positionRaw[key]);
    }
    if (positionRaw is List && positionRaw.length >= 2) {
      final index = axis == 'x' ? 0 : 1;
      return _readDouble(positionRaw[index]);
    }
    return null;
  }

  Map<String, Object?>? _mapFromProperties(
    Map<String, Object?> properties,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = properties[key];
      if (value is Map<String, Object?>) {
        return value;
      }
    }
    return null;
  }

  double? _readScalar(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      final scalar = _readDouble(value);
      if (scalar != null) {
        return scalar;
      }
    }
    return null;
  }

  double? _readDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
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
    if (value is Map<String, Object?>) {
      final x = _readDouble(value['x']);
      final y = _readDouble(value['y']);
      if (x != null && y == null) {
        return x;
      }
      if (y != null && x == null) {
        return y;
      }
    }
    return null;
  }

  String _sourceElementIdFromRuntimeNodeId(String runtimeId) {
    final marker = '__element__';
    final index = runtimeId.indexOf(marker);
    if (index < 0) {
      return runtimeId;
    }
    return runtimeId.substring(index + marker.length);
  }

  SceneSlotLayoutRect _sceneRuntimeRectToSlotRect(SceneRuntimeRect rect) {
    return SceneSlotLayoutRect(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
    );
  }

  SceneRectCenter? _slotBoundsCenterFor({
    required String nodeId,
    required SceneRuntimeNode runtimeNode,
    required SceneRuntimeComponentTree tree,
    required SceneSlotLayoutSolveResult slotLayout,
  }) {
    SceneSlotLayoutRect? rect = slotLayout.slotBoundsByNodeId[nodeId];
    if (rect == null && runtimeNode.parentId != null) {
      final parent = tree.node(runtimeNode.parentId!);
      if (parent != null && parent.nodeType == SceneRuntimeNodeType.slot) {
        rect = slotLayout.slotBoundsByNodeId[parent.id];
      }
    }
    if (rect == null) {
      return null;
    }
    return SceneRectCenter(
      centerX: rect.left + (rect.width / 2),
      centerY: rect.top + (rect.height / 2),
      width: rect.width,
      height: rect.height,
    );
  }

  SceneRectCenter? _contentBoundsCenterFor({
    required SceneRuntimeNode runtimeNode,
    required SceneRuntimeComponentTree tree,
    required SceneSlotLayoutSolveResult slotLayout,
  }) {
    final componentNodeId = _componentNodeIdFor(runtimeNode, tree);
    if (componentNodeId == null) {
      return null;
    }
    final rect = slotLayout.contentBoundsByComponentNodeId[componentNodeId];
    if (rect == null) {
      return null;
    }
    return SceneRectCenter(
      centerX: rect.left + (rect.width / 2),
      centerY: rect.top + (rect.height / 2),
      width: rect.width,
      height: rect.height,
    );
  }

  String? _componentNodeIdFor(
    SceneRuntimeNode runtimeNode,
    SceneRuntimeComponentTree tree,
  ) {
    if (runtimeNode.nodeType == SceneRuntimeNodeType.component) {
      return runtimeNode.id;
    }
    var parentId = runtimeNode.parentId;
    while (parentId != null) {
      final parent = tree.node(parentId);
      if (parent == null) {
        return null;
      }
      if (parent.nodeType == SceneRuntimeNodeType.component) {
        return parent.id;
      }
      parentId = parent.parentId;
    }
    return null;
  }

  String _normalizeToken(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();
  }

  String? _componentTypeFor(ReFusionSceneProgramElement element) {
    return _readStringProperty(
      element.properties,
      const <String>['componentType', 'component', 'semanticType'],
      layoutKeys: const <String>['componentType', 'component', 'semanticType'],
    );
  }

  String? _componentIdFor(ReFusionSceneProgramElement element) {
    return _readStringProperty(
          element.properties,
          const <String>['componentId', 'componentRef', 'componentKey'],
          layoutKeys: const <String>[
            'componentId',
            'componentRef',
            'componentKey'
          ],
        ) ??
        _componentTypeFor(element);
  }

  String? _slotIdFor(ReFusionSceneProgramElement element) {
    return _readStringProperty(
      element.properties,
      const <String>['slotId', 'slot', 'slotKey'],
      layoutKeys: const <String>['slotId', 'slot', 'slotKey'],
    );
  }

  String? _layoutRoleFor(ReFusionSceneProgramElement element) {
    return _readStringProperty(
      element.properties,
      const <String>['layoutRole', 'role'],
      layoutKeys: const <String>['layoutRole', 'role'],
    );
  }

  String? _readStringProperty(
    Map<String, Object?> properties,
    List<String> keys, {
    List<String> layoutKeys = const <String>[],
  }) {
    for (final key in keys) {
      final value = properties[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    if (layoutKeys.isEmpty) {
      return null;
    }
    final layout = _mapFromProperties(properties, const <String>['layout']);
    if (layout == null) {
      return null;
    }
    for (final key in layoutKeys) {
      final value = layout[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  _ComponentRuntimeBinding _buildComponentRuntimeBinding({
    required Map<String, SceneRuntimeNode> runtimeNodeById,
    required Map<String, String> componentIdByRuntimeNodeId,
    required Map<String, String> componentTypeByRuntimeNodeId,
    required Map<String, String> slotIdByRuntimeNodeId,
    required Map<String, String> layoutRoleByRuntimeNodeId,
    required String rootNodeId,
  }) {
    final parentOverrideByRuntimeNodeId = <String, String>{};
    final syntheticNodes = <SceneRuntimeNode>[];

    final membersByComponent = <String, List<String>>{};
    for (final entry in componentIdByRuntimeNodeId.entries) {
      membersByComponent
          .putIfAbsent(entry.value, () => <String>[])
          .add(entry.key);
    }
    final sortedComponentIds = membersByComponent.keys.toList(growable: false)
      ..sort((a, b) => a.compareTo(b));

    final componentNodeIdByComponentId = <String, String>{};
    final slotNodeIdByComponentAndSlot = <String, String>{};

    for (final componentId in sortedComponentIds) {
      final memberNodeIds = membersByComponent[componentId]!;
      final sortedMembers = memberNodeIds.toList(growable: false)
        ..sort((a, b) => a.compareTo(b));
      var anchorId = sortedMembers.first;
      for (final memberId in sortedMembers) {
        final role = _normalizeToken(layoutRoleByRuntimeNodeId[memberId] ?? '');
        if (role == 'container') {
          anchorId = memberId;
          break;
        }
      }
      final anchorNode = runtimeNodeById[anchorId];
      if (anchorNode == null) {
        continue;
      }
      final anchorComponentType =
          componentTypeByRuntimeNodeId[anchorId] ?? 'Component';
      final bounds = _boundsForNode(anchorNode);
      final lifecycle = _lifecycleForNode(anchorNode);
      final minZ = sortedMembers
          .map((id) => runtimeNodeById[id]?.zOrder ?? anchorNode.zOrder)
          .fold<int>(anchorNode.zOrder, math.min);
      final componentNodeId = '__component__${_sanitizeRuntimeId(componentId)}';
      componentNodeIdByComponentId[componentId] = componentNodeId;
      syntheticNodes.add(
        SceneRuntimeNode(
          id: componentNodeId,
          nodeType: SceneRuntimeNodeType.component,
          parentId: rootNodeId,
          zOrder: minZ - 10,
          sourceComponentId: componentId,
          metadata: <String, Object?>{
            'x': bounds.centerX,
            'y': bounds.centerY,
            'width': bounds.width,
            'height': bounds.height,
            'localLeft': -(bounds.width / 2.0),
            'localTop': -(bounds.height / 2.0),
            'startMs': lifecycle.startMs,
            'endMs': lifecycle.endMs,
            'opacity': 1.0,
            'componentType': anchorComponentType,
          },
        ),
      );

      final slotIds = <String>{
        for (final memberId in sortedMembers)
          if ((slotIdByRuntimeNodeId[memberId] ?? '').trim().isNotEmpty)
            slotIdByRuntimeNodeId[memberId]!.trim(),
      }.toList(growable: false)
        ..sort((a, b) => a.compareTo(b));
      for (final slotId in slotIds) {
        final slotNodeId =
            '$componentNodeId::slot::${_sanitizeRuntimeId(slotId)}';
        slotNodeIdByComponentAndSlot['$componentId::$slotId'] = slotNodeId;
        syntheticNodes.add(
          SceneRuntimeNode(
            id: slotNodeId,
            nodeType: SceneRuntimeNodeType.slot,
            parentId: componentNodeId,
            zOrder: minZ - 5,
            sourceComponentId: componentId,
            slotId: slotId,
            metadata: <String, Object?>{
              'x': bounds.centerX,
              'y': bounds.centerY,
              'width': bounds.width,
              'height': bounds.height,
              'localLeft': -(bounds.width / 2.0),
              'localTop': -(bounds.height / 2.0),
              'startMs': lifecycle.startMs,
              'endMs': lifecycle.endMs,
              'opacity': 1.0,
              'componentType': anchorComponentType,
            },
          ),
        );
      }
    }

    for (final entry in slotIdByRuntimeNodeId.entries) {
      final runtimeNodeId = entry.key;
      final slotId = entry.value.trim();
      final componentId = componentIdByRuntimeNodeId[runtimeNodeId];
      if (componentId == null || slotId.isEmpty) {
        continue;
      }
      final slotNodeId = slotNodeIdByComponentAndSlot['$componentId::$slotId'];
      if (slotNodeId == null) {
        continue;
      }
      parentOverrideByRuntimeNodeId[runtimeNodeId] = slotNodeId;
    }

    return _ComponentRuntimeBinding(
      syntheticNodes: syntheticNodes,
      parentOverrideByRuntimeNodeId: parentOverrideByRuntimeNodeId,
    );
  }

  ({double centerX, double centerY, double width, double height})
      _boundsForNode(
    SceneRuntimeNode node,
  ) {
    final metadata = node.metadata;
    final centerX = _readDouble(metadata['x']) ?? 0.0;
    final centerY = _readDouble(metadata['y']) ?? 0.0;
    final width = (_readDouble(metadata['width']) ?? 1.0).clamp(1.0, 1000000.0);
    final height =
        (_readDouble(metadata['height']) ?? 1.0).clamp(1.0, 1000000.0);
    return (
      centerX: centerX,
      centerY: centerY,
      width: width,
      height: height,
    );
  }

  ({int startMs, int endMs}) _lifecycleForNode(SceneRuntimeNode node) {
    final metadata = node.metadata;
    final startMs = (_readDouble(metadata['startMs']) ?? 0.0).round();
    final rawEnd = (_readDouble(metadata['endMs']) ?? (startMs + 1.0)).round();
    final endMs = rawEnd <= startMs ? startMs + 1 : rawEnd;
    return (startMs: startMs, endMs: endMs);
  }

  _HierarchyStats _hierarchyStats(Map<String, EvaluatedSceneNode> nodes) {
    var nodesWithComponentId = 0;
    var nodesWithSlotId = 0;
    var nodesWithParent = 0;
    var orphanParentRefs = 0;
    for (final node in nodes.values) {
      if ((node.sourceComponentId ?? '').trim().isNotEmpty) {
        nodesWithComponentId += 1;
      }
      if ((node.slotId ?? '').trim().isNotEmpty) {
        nodesWithSlotId += 1;
      }
      final parentId = node.parentNodeId;
      if (parentId == null) {
        continue;
      }
      nodesWithParent += 1;
      if (!nodes.containsKey(parentId)) {
        orphanParentRefs += 1;
      }
    }
    return _HierarchyStats(
      nodesWithComponentId: nodesWithComponentId,
      nodesWithSlotId: nodesWithSlotId,
      nodesWithParent: nodesWithParent,
      orphanParentRefs: orphanParentRefs,
    );
  }

  _LifecycleStats _lifecycleStats(Map<String, EvaluatedSceneNode> nodes) {
    var activeNodes = 0;
    var visibleNodes = 0;
    var childActiveWhileParentInactive = 0;
    var childVisibleWhileParentHidden = 0;
    for (final node in nodes.values) {
      if (node.active) {
        activeNodes += 1;
      }
      if (node.visible) {
        visibleNodes += 1;
      }
      final parentId = node.parentNodeId;
      if (parentId == null) {
        continue;
      }
      final parent = nodes[parentId];
      if (parent == null) {
        continue;
      }
      if (node.active && !parent.active) {
        childActiveWhileParentInactive += 1;
      }
      if (node.visible && !parent.visible) {
        childVisibleWhileParentHidden += 1;
      }
    }
    return _LifecycleStats(
      activeNodes: activeNodes,
      inactiveNodes: nodes.length - activeNodes,
      visibleNodes: visibleNodes,
      hiddenNodes: nodes.length - visibleNodes,
      childActiveWhileParentInactive: childActiveWhileParentInactive,
      childVisibleWhileParentHidden: childVisibleWhileParentHidden,
    );
  }

  String _sanitizeRuntimeId(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]+'), '_');
    return sanitized.isEmpty ? 'component' : sanitized;
  }

  double _estimateTextWidth(
    String text, {
    required double fontSize,
    required double letterSpacing,
    required double typewriterProgress,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final visibleCount =
        (trimmed.runes.length * typewriterProgress.clamp(0.0, 1.0)).ceil();
    final glyphWidth = fontSize * 0.56;
    final widthFromChars = visibleCount * glyphWidth;
    final widthFromSpacing = math.max(0, visibleCount - 1) * letterSpacing;
    return widthFromChars + widthFromSpacing;
  }

  double _estimateTextHeight({
    required double fontSize,
    required double lineHeight,
    required int maxLines,
  }) {
    return fontSize * math.max(1.0, lineHeight) * math.max(1, maxLines);
  }

  static const String _sceneRootId = '__scene__root';
}

class _ElementEvaluationState {
  const _ElementEvaluationState({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDeg,
    required this.opacity,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.maxLines,
    required this.typewriterProgress,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;
  final double rotationDeg;
  final double opacity;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final int maxLines;
  final double typewriterProgress;

  _ElementEvaluationState withPosition({
    required double x,
    required double y,
  }) {
    return _ElementEvaluationState(
      x: x,
      y: y,
      width: width,
      height: height,
      scaleX: scaleX,
      scaleY: scaleY,
      rotationDeg: rotationDeg,
      opacity: opacity,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      maxLines: maxLines,
      typewriterProgress: typewriterProgress,
    );
  }
}

class _HierarchyStats {
  const _HierarchyStats({
    required this.nodesWithComponentId,
    required this.nodesWithSlotId,
    required this.nodesWithParent,
    required this.orphanParentRefs,
  });

  final int nodesWithComponentId;
  final int nodesWithSlotId;
  final int nodesWithParent;
  final int orphanParentRefs;
}

class _LifecycleStats {
  const _LifecycleStats({
    required this.activeNodes,
    required this.inactiveNodes,
    required this.visibleNodes,
    required this.hiddenNodes,
    required this.childActiveWhileParentInactive,
    required this.childVisibleWhileParentHidden,
  });

  final int activeNodes;
  final int inactiveNodes;
  final int visibleNodes;
  final int hiddenNodes;
  final int childActiveWhileParentInactive;
  final int childVisibleWhileParentHidden;
}

class _ComponentRuntimeBinding {
  const _ComponentRuntimeBinding({
    required this.syntheticNodes,
    required this.parentOverrideByRuntimeNodeId,
  });

  final List<SceneRuntimeNode> syntheticNodes;
  final Map<String, String> parentOverrideByRuntimeNodeId;
}
