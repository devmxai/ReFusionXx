import '../models/scene_runtime_node.dart';

enum SceneRuntimeLifecycleState {
  active,
  inactiveBeforeStart,
  inactiveAfterEnd,
}

class SceneRuntimeLifecycleRules {
  const SceneRuntimeLifecycleRules();

  SceneRuntimeLifecycleState lifecycleState({
    required SceneRuntimeNode node,
    required int timelineTimeMs,
  }) {
    final startMs = _readInt(node.metadata['startMs']);
    final endMs = _readInt(node.metadata['endMs']);
    if (startMs != null && timelineTimeMs < startMs) {
      return SceneRuntimeLifecycleState.inactiveBeforeStart;
    }
    if (endMs != null && timelineTimeMs > endMs) {
      return SceneRuntimeLifecycleState.inactiveAfterEnd;
    }
    return SceneRuntimeLifecycleState.active;
  }

  bool isActive({
    required SceneRuntimeNode node,
    required int timelineTimeMs,
    required bool parentActive,
  }) {
    if (!parentActive) {
      return false;
    }
    return lifecycleState(node: node, timelineTimeMs: timelineTimeMs) ==
        SceneRuntimeLifecycleState.active;
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
