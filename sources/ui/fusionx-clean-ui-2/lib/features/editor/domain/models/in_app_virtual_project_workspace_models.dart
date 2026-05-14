import 'creative_transaction_contract_models.dart';

class CompositionSpecSnapshot {
  const CompositionSpecSnapshot({
    required this.spec,
  });

  final CreativeCompositionSpec spec;
}

class LayerGraphNodeSnapshot {
  const LayerGraphNodeSnapshot({
    required this.layer,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  final CreativeLayerIdentity layer;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double scaleX;
  final double scaleY;
}

class LayerGraphSnapshot {
  const LayerGraphSnapshot({
    this.nodes = const <LayerGraphNodeSnapshot>[],
  });

  final List<LayerGraphNodeSnapshot> nodes;
}

class TimelineClipSnapshot {
  const TimelineClipSnapshot({
    required this.clipId,
    required this.layerId,
    required this.trackId,
    required this.startMs,
    required this.durationMs,
  });

  final String clipId;
  final String layerId;
  final String trackId;
  final int startMs;
  final int durationMs;
}

class TimelineGraphSnapshot {
  const TimelineGraphSnapshot({
    this.clips = const <TimelineClipSnapshot>[],
  });

  final List<TimelineClipSnapshot> clips;
}

class SelectionSnapshot {
  const SelectionSnapshot({
    this.selectedLayerIds = const <String>[],
    this.selectionOrigin = '',
  });

  final List<String> selectedLayerIds;
  final String selectionOrigin;
}

class FrameSnapshotSummary {
  const FrameSnapshotSummary({
    required this.currentFrame,
    required this.currentTimeMs,
    this.visibleLayerIds = const <String>[],
  });

  final int currentFrame;
  final int currentTimeMs;
  final List<String> visibleLayerIds;
}

class RendererCapabilitySnapshot {
  const RendererCapabilitySnapshot({
    this.rendererName = '',
    this.effectCapabilities = const <String>[],
  });

  final String rendererName;
  final List<String> effectCapabilities;
}

class InAppVirtualProjectWorkspaceSnapshot {
  const InAppVirtualProjectWorkspaceSnapshot({
    required this.workspace,
    required this.composition,
    required this.layerGraph,
    required this.timeline,
    required this.selection,
    required this.frame,
    required this.renderer,
  });

  final CreativeWorkspaceSnapshot workspace;
  final CompositionSpecSnapshot composition;
  final LayerGraphSnapshot layerGraph;
  final TimelineGraphSnapshot timeline;
  final SelectionSnapshot selection;
  final FrameSnapshotSummary frame;
  final RendererCapabilitySnapshot renderer;
}
