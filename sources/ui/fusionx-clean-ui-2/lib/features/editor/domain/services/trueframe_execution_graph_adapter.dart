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
    final nodes = masterGraph.nodes
        .map(
          (node) => TrueFrameExecutionNode(
            id: node.id,
            family: _mapFamily(node.family),
            targetId: node.targetId,
            inputNodeIds: List<String>.unmodifiable(node.inputNodeIds),
            cacheKey: node.cacheKey,
            attributes: Map<String, Object?>.unmodifiable(node.attributes),
            blockers: List<String>.unmodifiable(node.blockers),
            diagnostics: List<String>.unmodifiable(node.diagnostics),
          ),
        )
        .toList(growable: false);
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
