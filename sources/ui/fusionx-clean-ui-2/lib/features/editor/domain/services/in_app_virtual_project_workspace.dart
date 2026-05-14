import '../models/creative_transaction_contract_models.dart';
import '../models/in_app_virtual_project_workspace_models.dart';

class CreativeWorkspaceSnapshotBuildRequest {
  const CreativeWorkspaceSnapshotBuildRequest({
    required this.projectId,
    required this.compositionId,
    required this.revision,
    required this.compositionSpec,
    required this.layerGraph,
    required this.timeline,
    required this.selection,
    required this.frame,
    required this.renderer,
  });

  final String projectId;
  final String compositionId;
  final int revision;
  final CompositionSpecSnapshot compositionSpec;
  final LayerGraphSnapshot layerGraph;
  final TimelineGraphSnapshot timeline;
  final SelectionSnapshot selection;
  final FrameSnapshotSummary frame;
  final RendererCapabilitySnapshot renderer;
}

class InAppVirtualProjectWorkspace {
  const InAppVirtualProjectWorkspace({
    this.schemaVersion = 'refusion.workspace.snapshot/v1',
  });

  final String schemaVersion;
}

class CreativeWorkspaceSnapshotBuilder {
  const CreativeWorkspaceSnapshotBuilder();

  InAppVirtualProjectWorkspaceSnapshot build(
    InAppVirtualProjectWorkspace workspace,
    CreativeWorkspaceSnapshotBuildRequest request,
  ) {
    final diagnostics = <String>[];
    final nodeByLayerId = <String, LayerGraphNodeSnapshot>{};
    for (final node in request.layerGraph.nodes) {
      nodeByLayerId[node.layer.layerId] = node;
    }
    for (final clip in request.timeline.clips) {
      if (!nodeByLayerId.containsKey(clip.layerId)) {
        diagnostics.add('orphan_timeline_clip:${clip.clipId}');
      }
    }

    final selectedLayerIds = request.selection.selectedLayerIds
        .where((layerId) => nodeByLayerId.containsKey(layerId))
        .toList(growable: false);

    final snapshot = CreativeWorkspaceSnapshot(
      projectId: request.projectId,
      compositionId: request.compositionId,
      revision: request.revision,
      compositionSpec: request.compositionSpec.spec,
      layers: request.layerGraph.nodes
          .map((node) => node.layer)
          .toList(growable: false),
      selection: selectedLayerIds,
      diagnostics: diagnostics,
    );

    return InAppVirtualProjectWorkspaceSnapshot(
      workspace: snapshot,
      composition: request.compositionSpec,
      layerGraph: request.layerGraph,
      timeline: request.timeline,
      selection: request.selection,
      frame: request.frame,
      renderer: request.renderer,
    );
  }
}
