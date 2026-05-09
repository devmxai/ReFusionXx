import '../models/scene_runtime_node.dart';

/// PMCR compatibility layer:
/// keeps plan naming (`SceneComponentRuntimeNode`) while runtime internals
/// remain on the canonical `SceneRuntimeNode` model.
typedef SceneComponentRuntimeNode = SceneRuntimeNode;
typedef SceneComponentRuntimeNodeType = SceneRuntimeNodeType;
