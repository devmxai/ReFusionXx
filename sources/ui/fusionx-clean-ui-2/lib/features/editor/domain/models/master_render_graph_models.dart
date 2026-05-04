import 'package:flutter/foundation.dart';

import 'master_time_models.dart';
import 'master_value_truth_models.dart';
import 'master_visual_program_models.dart';

enum MasterRenderGraphNodeFamily {
  sourceSample,
  layerTransform,
  effect,
  transition,
  composite,
  outputSurface,
}

@immutable
class MasterRenderGraphNode {
  MasterRenderGraphNode({
    required this.id,
    required this.family,
    required this.targetId,
    List<String> inputNodeIds = const <String>[],
    required this.cacheKey,
    Map<String, Object?> attributes = const <String, Object?>{},
    List<String> blockers = const <String>[],
    List<String> diagnostics = const <String>[],
  })  : inputNodeIds = List.unmodifiable(inputNodeIds),
        attributes = Map.unmodifiable(attributes),
        blockers = List.unmodifiable(blockers),
        diagnostics = List.unmodifiable(diagnostics);

  final String id;
  final MasterRenderGraphNodeFamily family;
  final String targetId;
  final List<String> inputNodeIds;
  final String cacheKey;
  final Map<String, Object?> attributes;
  final List<String> blockers;
  final List<String> diagnostics;
}

@immutable
class MasterRenderSurfaceBinding {
  MasterRenderSurfaceBinding({
    required this.targetId,
    required this.sourceNodeId,
    required this.transformNodeId,
    required List<String> effectNodeIds,
    this.transitionNodeId,
    required this.compositeNodeId,
    required this.transitionRole,
    List<String> blockers = const <String>[],
  })  : effectNodeIds = List.unmodifiable(effectNodeIds),
        blockers = List.unmodifiable(blockers);

  final String targetId;
  final String? sourceNodeId;
  final String transformNodeId;
  final List<String> effectNodeIds;
  final String? transitionNodeId;
  final String compositeNodeId;
  final MasterVisualTransitionRole transitionRole;
  final List<String> blockers;
}

@immutable
class MasterRenderGraph {
  MasterRenderGraph({
    required this.revision,
    required this.rootTimeMs,
    required this.frameIndex,
    required this.renderMode,
    required this.outputWidth,
    required this.outputHeight,
    required this.colorProfile,
    List<MasterRenderGraphNode> nodes = const <MasterRenderGraphNode>[],
    List<MasterRenderSurfaceBinding> surfaceBindings =
        const <MasterRenderSurfaceBinding>[],
    required this.outputNodeId,
    List<String> blockers = const <String>[],
    List<String> diagnostics = const <String>[],
  })  : nodes = List.unmodifiable(nodes),
        surfaceBindings = List.unmodifiable(surfaceBindings),
        blockers = List.unmodifiable(blockers),
        diagnostics = List.unmodifiable(diagnostics);

  final String revision;
  final int rootTimeMs;
  final int frameIndex;
  final MasterRenderMode renderMode;
  final int outputWidth;
  final int outputHeight;
  final String colorProfile;
  final List<MasterRenderGraphNode> nodes;
  final List<MasterRenderSurfaceBinding> surfaceBindings;
  final String outputNodeId;
  final List<String> blockers;
  final List<String> diagnostics;

  bool get canRenderTruthfully {
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

  MasterRenderSurfaceBinding? bindingForTarget(String targetId) {
    for (final binding in surfaceBindings) {
      if (binding.targetId == targetId) {
        return binding;
      }
    }
    return null;
  }
}

@immutable
class MasterRenderGraphEffectDescriptor {
  const MasterRenderGraphEffectDescriptor({
    required this.id,
    required this.rendererValue,
    required this.rendererUnit,
  });

  final String id;
  final double rendererValue;
  final MasterValueUnit rendererUnit;
}
