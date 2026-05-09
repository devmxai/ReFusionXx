import 'scene_runtime_component_tree.dart';

/// PMCR compatibility layer:
/// keeps plan naming (`SceneComponentRuntimeTree`) while runtime internals
/// remain on the canonical `SceneRuntimeComponentTree` service.
typedef SceneComponentRuntimeTree = SceneRuntimeComponentTree;
typedef SceneComponentRuntimeTreeBuildResult
    = SceneRuntimeComponentTreeBuildResult;
typedef SceneComponentRuntimeTreeIssue = SceneRuntimeComponentTreeIssue;
