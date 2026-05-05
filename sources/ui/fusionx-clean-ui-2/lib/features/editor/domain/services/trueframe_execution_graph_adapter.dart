import '../models/master_render_graph_models.dart';
import '../models/trueframe_execution_graph_models.dart';

class TrueFrameExecutionGraphProjectionResult {
  const TrueFrameExecutionGraphProjectionResult({
    required this.graph,
    required this.blockers,
    required this.diagnostics,
  });

  final TrueFrameExecutionGraph graph;
  final List<String> blockers;
  final List<String> diagnostics;
}

class TrueFrameExecutionGraphAdapter {
  const TrueFrameExecutionGraphAdapter();

  TrueFrameExecutionGraphProjectionResult project(
    TrueFrameExecutionGraphProjectionRequest request,
  ) {
    final masterGraph = request.masterGraph;
    final nodes = <TrueFrameExecutionNode>[
      for (final node in masterGraph.nodes)
        TrueFrameExecutionNode(
          id: node.id,
          family: _mapFamily(node.family),
          targetId: node.targetId,
          inputNodeIds: List<String>.unmodifiable(node.inputNodeIds),
          cacheKey: node.cacheKey,
          attributes: Map<String, Object?>.unmodifiable(node.attributes),
          blockers: List<String>.unmodifiable(node.blockers),
          diagnostics: List<String>.unmodifiable(node.diagnostics),
        ),
    ];
    nodes.addAll(
      _phaseIExpandedNodes(
        masterGraph: masterGraph,
        projectedNodes: nodes,
      ),
    );
    final bindings = masterGraph.surfaceBindings
        .map(
          (binding) => TrueFrameExecutionSurfaceBinding(
            targetId: binding.targetId,
            sourceNodeId: binding.sourceNodeId,
            transformNodeId: binding.transformNodeId,
            cropNodeId: binding.cropNodeId,
            maskNodeId: binding.maskNodeId,
            styleNodeId: binding.styleNodeId,
            effectNodeIds: List<String>.unmodifiable(binding.effectNodeIds),
            motionBlurNodeId: binding.motionBlurNodeId,
            transitionNodeId: binding.transitionNodeId,
            compositeNodeId: binding.compositeNodeId,
            drawOrder: binding.drawOrder,
            transitionRole: binding.transitionRole.name,
            blockers: List<String>.unmodifiable(binding.blockers),
          ),
        )
        .toList(growable: false);

    final blockers = <String>[...masterGraph.blockers];
    final diagnostics = <String>[
      ...masterGraph.diagnostics,
      'trueframe_projection_source_revision:${masterGraph.revision}',
      'trueframe_projection_node_count:${nodes.length}',
      'trueframe_projection_surface_binding_count:${bindings.length}',
    ];

    _addCoreGraphPresenceBlockers(nodes: nodes, blockers: blockers);
    _addManualTransitionSliceBlockers(
      request: request,
      masterGraph: masterGraph,
      bindings: bindings,
      blockers: blockers,
      diagnostics: diagnostics,
    );

    final graph = TrueFrameExecutionGraph(
      sourceGraphRevision: masterGraph.revision,
      revision: _buildRevision(masterGraph: masterGraph, blockers: blockers),
      rootTimeMs: masterGraph.rootTimeMs,
      frameIndex: masterGraph.frameIndex,
      renderMode: masterGraph.renderMode,
      outputWidth: masterGraph.outputWidth,
      outputHeight: masterGraph.outputHeight,
      colorProfile: masterGraph.colorProfile,
      nodes: List<TrueFrameExecutionNode>.unmodifiable(nodes),
      surfaceBindings: List<TrueFrameExecutionSurfaceBinding>.unmodifiable(
        bindings,
      ),
      outputNodeId: masterGraph.outputNodeId,
      blockers: List<String>.unmodifiable(blockers),
      diagnostics: List<String>.unmodifiable(diagnostics),
    );
    return TrueFrameExecutionGraphProjectionResult(
      graph: graph,
      blockers: graph.blockers,
      diagnostics: graph.diagnostics,
    );
  }

  List<TrueFrameExecutionNode> _phaseIExpandedNodes({
    required MasterRenderGraph masterGraph,
    required List<TrueFrameExecutionNode> projectedNodes,
  }) {
    final nodesById = <String, TrueFrameExecutionNode>{
      for (final node in projectedNodes) node.id: node,
    };
    final expanded = <TrueFrameExecutionNode>[];
    final expandedNodeIds = <String>{};
    for (final node in masterGraph.nodes) {
      if (node.family == MasterRenderGraphNodeFamily.sourceSample) {
        final hintedFamily =
            _phaseIFamilyFromHint(node.attributes['coreLayerFamilyHint']);
        final sourceKind = node.attributes['sourceKind']?.toString() ?? '';
        final layerFamily = switch (hintedFamily) {
          TrueFrameExecutionNodeFamily.videoLayer ||
          TrueFrameExecutionNodeFamily.imageLayer =>
            hintedFamily,
          _ => switch (sourceKind) {
              'video' => TrueFrameExecutionNodeFamily.videoLayer,
              'image' => TrueFrameExecutionNodeFamily.imageLayer,
              _ => null,
            },
        };
        if (layerFamily != null) {
          final layerNodeId = 'layer:$sourceKind:${node.targetId}';
          if (expandedNodeIds.add(layerNodeId)) {
            expanded.add(
              _phaseINodeFrom(
                baseNode: nodesById[node.id]!,
                id: layerNodeId,
                family: layerFamily,
                inputNodeIds: <String>[node.id],
                attributes: <String, Object?>{
                  ...node.attributes,
                  'phase': 'phase_i_layer_slice',
                },
                diagnostics: <String>[
                  ...node.diagnostics,
                  'trueframe_phase_i_${sourceKind}_layer_from_source_sample',
                ],
              ),
            );
          }
        }
      }
      if (node.family == MasterRenderGraphNodeFamily.style) {
        final hintedFamily =
            _phaseIFamilyFromHint(node.attributes['coreLayerFamilyHint']);
        final hasTextStyle = node.attributes['hasTextStyle'] == true;
        if (hasTextStyle ||
            hintedFamily == TrueFrameExecutionNodeFamily.textLayer) {
          final textNodeId = 'layer:text:${node.targetId}';
          if (expandedNodeIds.add(textNodeId)) {
            expanded.add(
              _phaseINodeFrom(
                baseNode: nodesById[node.id]!,
                id: textNodeId,
                family: TrueFrameExecutionNodeFamily.textLayer,
                inputNodeIds: <String>[node.id],
                attributes: <String, Object?>{
                  ...node.attributes,
                  'phase': 'phase_i_layer_slice',
                },
                diagnostics: <String>[
                  ...node.diagnostics,
                  'trueframe_phase_i_text_layer_from_style',
                ],
              ),
            );
          }
        }
        final hasShapeStyle = node.attributes['hasShapeStyle'] == true;
        if (hasShapeStyle ||
            hintedFamily == TrueFrameExecutionNodeFamily.shapeLayer) {
          final shapeNodeId = 'layer:shape:${node.targetId}';
          if (expandedNodeIds.add(shapeNodeId)) {
            expanded.add(
              _phaseINodeFrom(
                baseNode: nodesById[node.id]!,
                id: shapeNodeId,
                family: TrueFrameExecutionNodeFamily.shapeLayer,
                inputNodeIds: <String>[node.id],
                attributes: <String, Object?>{
                  ...node.attributes,
                  'phase': 'phase_i_layer_slice',
                },
                diagnostics: <String>[
                  ...node.diagnostics,
                  'trueframe_phase_i_shape_layer_from_style',
                ],
              ),
            );
          }
        }
      }
      if (node.family == MasterRenderGraphNodeFamily.layerTransform ||
          node.family == MasterRenderGraphNodeFamily.transition) {
        final hintedFamily =
            _phaseIFamilyFromHint(node.attributes['coreLayerFamilyHint']);
        if (hintedFamily == TrueFrameExecutionNodeFamily.groupPrecomp ||
            hintedFamily == TrueFrameExecutionNodeFamily.sceneClipInstance ||
            hintedFamily == TrueFrameExecutionNodeFamily.adjustmentControl) {
          final resolvedHintedFamily = hintedFamily!;
          final explicitNodeId = _phaseICompatibilityNodeIdForFamily(
            family: resolvedHintedFamily,
            targetId: node.targetId,
          );
          if (expandedNodeIds.add(explicitNodeId)) {
            expanded.add(
              _phaseINodeFrom(
                baseNode: nodesById[node.id]!,
                id: explicitNodeId,
                family: resolvedHintedFamily,
                inputNodeIds: <String>[node.id],
                attributes: const <String, Object?>{'phase': 'phase_i_slice'},
                diagnostics: <String>[
                  ...node.diagnostics,
                  'trueframe_phase_i_family_from_core_hint:${resolvedHintedFamily.name}',
                ],
              ),
            );
          }
          continue;
        }
        final target = node.targetId.toLowerCase();
        if (target.contains('group')) {
          final groupNodeId = 'group:${node.targetId}';
          if (expandedNodeIds.add(groupNodeId)) {
            expanded.add(
              _phaseINodeFrom(
                baseNode: nodesById[node.id]!,
                id: groupNodeId,
                family: TrueFrameExecutionNodeFamily.groupPrecomp,
                inputNodeIds: <String>[node.id],
                attributes: const <String, Object?>{'phase': 'phase_i_slice'},
                diagnostics: <String>[
                  ...node.diagnostics,
                  'trueframe_phase_i_group_precomp_node',
                  'trueframe_phase_i_family_legacy_target_fallback',
                ],
              ),
            );
          }
        }
        if (target.contains('scene-clip') || target.contains('scene_clip')) {
          final sceneNodeId = 'scene-clip:${node.targetId}';
          if (expandedNodeIds.add(sceneNodeId)) {
            expanded.add(
              _phaseINodeFrom(
                baseNode: nodesById[node.id]!,
                id: sceneNodeId,
                family: TrueFrameExecutionNodeFamily.sceneClipInstance,
                inputNodeIds: <String>[node.id],
                attributes: const <String, Object?>{'phase': 'phase_i_slice'},
                diagnostics: <String>[
                  ...node.diagnostics,
                  'trueframe_phase_i_scene_clip_instance_node',
                  'trueframe_phase_i_family_legacy_target_fallback',
                ],
              ),
            );
          }
        }
        if (target.contains('adjustment') || target.contains('effectcontrol')) {
          final adjustmentNodeId = 'adjustment:${node.targetId}';
          if (expandedNodeIds.add(adjustmentNodeId)) {
            expanded.add(
              _phaseINodeFrom(
                baseNode: nodesById[node.id]!,
                id: adjustmentNodeId,
                family: TrueFrameExecutionNodeFamily.adjustmentControl,
                inputNodeIds: <String>[node.id],
                attributes: const <String, Object?>{'phase': 'phase_i_slice'},
                diagnostics: <String>[
                  ...node.diagnostics,
                  'trueframe_phase_i_adjustment_control_node',
                  'trueframe_phase_i_family_legacy_target_fallback',
                ],
              ),
            );
          }
        }
      }
    }
    return List<TrueFrameExecutionNode>.unmodifiable(expanded);
  }

  String _phaseICompatibilityNodeIdForFamily({
    required TrueFrameExecutionNodeFamily family,
    required String targetId,
  }) {
    return switch (family) {
      TrueFrameExecutionNodeFamily.groupPrecomp => 'group:$targetId',
      TrueFrameExecutionNodeFamily.sceneClipInstance => 'scene-clip:$targetId',
      TrueFrameExecutionNodeFamily.adjustmentControl => 'adjustment:$targetId',
      _ => 'phase-i:${family.name}:$targetId',
    };
  }

  TrueFrameExecutionNodeFamily? _phaseIFamilyFromHint(Object? rawValue) {
    final value = rawValue?.toString();
    return switch (value) {
      'videoLayer' => TrueFrameExecutionNodeFamily.videoLayer,
      'imageLayer' => TrueFrameExecutionNodeFamily.imageLayer,
      'textLayer' => TrueFrameExecutionNodeFamily.textLayer,
      'shapeLayer' => TrueFrameExecutionNodeFamily.shapeLayer,
      'groupPrecomp' => TrueFrameExecutionNodeFamily.groupPrecomp,
      'sceneClipInstance' => TrueFrameExecutionNodeFamily.sceneClipInstance,
      'adjustmentControl' => TrueFrameExecutionNodeFamily.adjustmentControl,
      _ => null,
    };
  }

  TrueFrameExecutionNode _phaseINodeFrom({
    required TrueFrameExecutionNode baseNode,
    required String id,
    required TrueFrameExecutionNodeFamily family,
    required List<String> inputNodeIds,
    required Map<String, Object?> attributes,
    required List<String> diagnostics,
  }) {
    return TrueFrameExecutionNode(
      id: id,
      family: family,
      targetId: baseNode.targetId,
      inputNodeIds: List<String>.unmodifiable(inputNodeIds),
      cacheKey: '${baseNode.cacheKey}:$id',
      attributes: Map<String, Object?>.unmodifiable(attributes),
      blockers: List<String>.unmodifiable(baseNode.blockers),
      diagnostics: List<String>.unmodifiable(diagnostics),
    );
  }

  void _addCoreGraphPresenceBlockers({
    required List<TrueFrameExecutionNode> nodes,
    required List<String> blockers,
  }) {
    final families = nodes.map((node) => node.family).toSet();
    if (!families.contains(TrueFrameExecutionNodeFamily.sourceSample)) {
      blockers.add('trueframe_missing_source_sample_node');
    }
    if (!families.contains(TrueFrameExecutionNodeFamily.layerTransform)) {
      blockers.add('trueframe_missing_transform_node');
    }
    if (!families.contains(TrueFrameExecutionNodeFamily.blendComposite)) {
      blockers.add('trueframe_missing_blend_composite_node');
    }
    if (!families.contains(TrueFrameExecutionNodeFamily.outputSurface)) {
      blockers.add('trueframe_missing_output_surface_node');
    }
  }

  void _addManualTransitionSliceBlockers({
    required TrueFrameExecutionGraphProjectionRequest request,
    required MasterRenderGraph masterGraph,
    required List<TrueFrameExecutionSurfaceBinding> bindings,
    required List<String> blockers,
    required List<String> diagnostics,
  }) {
    final outgoingTargetId = request.outgoingTargetId?.trim();
    if (outgoingTargetId != null && outgoingTargetId.isNotEmpty) {
      final hasOutgoing = bindings.any(
        (binding) => binding.targetId == outgoingTargetId,
      );
      if (!hasOutgoing) {
        blockers.add(
          'trueframe_missing_outgoing_target_binding:$outgoingTargetId',
        );
      }
    }
    final incomingTargetId = request.incomingTargetId?.trim();
    if (incomingTargetId != null && incomingTargetId.isNotEmpty) {
      final hasIncoming = bindings.any(
        (binding) => binding.targetId == incomingTargetId,
      );
      if (!hasIncoming) {
        blockers.add(
          'trueframe_missing_incoming_target_binding:$incomingTargetId',
        );
      }
    }
    final transitionId = request.transitionId?.trim();
    if (transitionId == null || transitionId.isEmpty) {
      return;
    }
    var hasTransitionNode = false;
    for (final node in masterGraph.nodes) {
      if (node.family != MasterRenderGraphNodeFamily.transition) {
        continue;
      }
      final activeTransitionIds = node.attributes['activeTransitionIds'];
      if (activeTransitionIds is! List) {
        continue;
      }
      if (activeTransitionIds.contains(transitionId)) {
        hasTransitionNode = true;
        break;
      }
    }
    if (!hasTransitionNode) {
      blockers.add('trueframe_missing_transition_node:$transitionId');
    } else {
      diagnostics.add('trueframe_transition_node_resolved:$transitionId');
    }
  }

  TrueFrameExecutionNodeFamily _mapFamily(MasterRenderGraphNodeFamily family) {
    return switch (family) {
      MasterRenderGraphNodeFamily.sourceSample =>
        TrueFrameExecutionNodeFamily.sourceSample,
      MasterRenderGraphNodeFamily.layerTransform =>
        TrueFrameExecutionNodeFamily.layerTransform,
      MasterRenderGraphNodeFamily.crop => TrueFrameExecutionNodeFamily.crop,
      MasterRenderGraphNodeFamily.mask => TrueFrameExecutionNodeFamily.mask,
      MasterRenderGraphNodeFamily.style => TrueFrameExecutionNodeFamily.style,
      MasterRenderGraphNodeFamily.effect => TrueFrameExecutionNodeFamily.effect,
      MasterRenderGraphNodeFamily.temporalMotionBlur =>
        TrueFrameExecutionNodeFamily.temporalMotionBlur,
      MasterRenderGraphNodeFamily.transition =>
        TrueFrameExecutionNodeFamily.transition,
      MasterRenderGraphNodeFamily.composite =>
        TrueFrameExecutionNodeFamily.blendComposite,
      MasterRenderGraphNodeFamily.outputSurface =>
        TrueFrameExecutionNodeFamily.outputSurface,
    };
  }

  String _buildRevision({
    required MasterRenderGraph masterGraph,
    required List<String> blockers,
  }) {
    final signature = Object.hashAll(<Object?>[
      masterGraph.revision,
      masterGraph.nodes.length,
      masterGraph.surfaceBindings.length,
      blockers.join(','),
    ]);
    return 'trueframe:${masterGraph.revision}:$signature';
  }
}
