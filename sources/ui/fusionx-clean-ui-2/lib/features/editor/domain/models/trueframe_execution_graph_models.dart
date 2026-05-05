import 'package:flutter/foundation.dart';

import 'master_render_graph_models.dart';
import 'master_time_models.dart';

enum TrueFrameExecutionNodeFamily {
  sourceSample,
  videoLayer,
  imageLayer,
  textLayer,
  shapeLayer,
  groupPrecomp,
  sceneClipInstance,
  adjustmentControl,
  layerTransform,
  crop,
  mask,
  style,
  effect,
  temporalMotionBlur,
  transition,
  blendComposite,
  outputSurface,
}

@immutable
class TrueFrameExecutionNode {
  const TrueFrameExecutionNode({
    required this.id,
    required this.family,
    required this.targetId,
    required this.inputNodeIds,
    required this.cacheKey,
    required this.attributes,
    required this.blockers,
    required this.diagnostics,
  });

  final String id;
  final TrueFrameExecutionNodeFamily family;
  final String targetId;
  final List<String> inputNodeIds;
  final String cacheKey;
  final Map<String, Object?> attributes;
  final List<String> blockers;
  final List<String> diagnostics;
}

@immutable
class TrueFrameExecutionSurfaceBinding {
  const TrueFrameExecutionSurfaceBinding({
    required this.targetId,
    required this.sourceNodeId,
    required this.transformNodeId,
    required this.cropNodeId,
    required this.maskNodeId,
    required this.styleNodeId,
    required this.effectNodeIds,
    required this.motionBlurNodeId,
    required this.transitionNodeId,
    required this.compositeNodeId,
    required this.drawOrder,
    required this.transitionRole,
    required this.blockers,
  });

  final String targetId;
  final String? sourceNodeId;
  final String transformNodeId;
  final String? cropNodeId;
  final String? maskNodeId;
  final String? styleNodeId;
  final List<String> effectNodeIds;
  final String? motionBlurNodeId;
  final String? transitionNodeId;
  final String compositeNodeId;
  final int drawOrder;
  final String transitionRole;
  final List<String> blockers;
}

@immutable
class TrueFrameExecutionGraph {
  const TrueFrameExecutionGraph({
    required this.sourceGraphRevision,
    required this.revision,
    required this.rootTimeMs,
    required this.frameIndex,
    required this.renderMode,
    required this.outputWidth,
    required this.outputHeight,
    required this.colorProfile,
    required this.nodes,
    required this.surfaceBindings,
    required this.outputNodeId,
    required this.blockers,
    required this.diagnostics,
  });

  final String sourceGraphRevision;
  final String revision;
  final int rootTimeMs;
  final int frameIndex;
  final MasterRenderMode renderMode;
  final int outputWidth;
  final int outputHeight;
  final String colorProfile;
  final List<TrueFrameExecutionNode> nodes;
  final List<TrueFrameExecutionSurfaceBinding> surfaceBindings;
  final String outputNodeId;
  final List<String> blockers;
  final List<String> diagnostics;

  bool get canExecuteTruthfully {
    if (blockers.isNotEmpty) {
      return false;
    }
    for (final node in nodes) {
      if (node.blockers.isNotEmpty) {
        return false;
      }
    }
    return true;
  }
}

@immutable
class TrueFrameExecutionGraphProjectionRequest {
  const TrueFrameExecutionGraphProjectionRequest({
    required this.masterGraph,
    this.transitionId,
    this.outgoingTargetId,
    this.incomingTargetId,
  });

  final MasterRenderGraph masterGraph;
  final String? transitionId;
  final String? outgoingTargetId;
  final String? incomingTargetId;
}
