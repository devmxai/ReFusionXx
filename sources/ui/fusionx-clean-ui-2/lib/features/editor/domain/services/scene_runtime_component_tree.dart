import 'dart:collection';

import '../models/scene_runtime_node.dart';

class SceneRuntimeComponentTreeIssue {
  const SceneRuntimeComponentTreeIssue({
    required this.code,
    required this.message,
    this.nodeId,
    this.path,
  });

  final String code;
  final String message;
  final String? nodeId;
  final String? path;
}

class SceneRuntimeComponentTreeBuildResult {
  const SceneRuntimeComponentTreeBuildResult({
    required this.issues,
    this.tree,
  });

  final SceneRuntimeComponentTree? tree;
  final List<SceneRuntimeComponentTreeIssue> issues;

  bool get isValid => tree != null && issues.isEmpty;
}

class SceneRuntimeComponentTree {
  SceneRuntimeComponentTree._({
    required this.rootNodeId,
    required Map<String, SceneRuntimeNode> nodeById,
    required Map<String, String?> parentOf,
    required Map<String, List<String>> childrenOf,
  })  : nodeById = UnmodifiableMapView<String, SceneRuntimeNode>(nodeById),
        parentOf = UnmodifiableMapView<String, String?>(parentOf),
        childrenOf = UnmodifiableMapView<String, List<String>>(
          childrenOf.map(
            (key, value) => MapEntry<String, List<String>>(
              key,
              List.unmodifiable(value),
            ),
          ),
        );

  final String rootNodeId;
  final Map<String, SceneRuntimeNode> nodeById;
  final Map<String, String?> parentOf;
  final Map<String, List<String>> childrenOf;

  SceneRuntimeNode get root => nodeById[rootNodeId]!;

  SceneRuntimeNode? node(String nodeId) => nodeById[nodeId];

  List<SceneRuntimeNode> children(String nodeId) =>
      childrenOf[nodeId]
          ?.map((childId) => nodeById[childId])
          .whereType<SceneRuntimeNode>()
          .toList(growable: false) ??
      const <SceneRuntimeNode>[];

  List<SceneRuntimeNode> depthFirstNodes() {
    final ordered = <SceneRuntimeNode>[];
    final visited = <String>{};

    void walk(String nodeId) {
      if (!visited.add(nodeId)) {
        return;
      }
      final current = nodeById[nodeId];
      if (current == null) {
        return;
      }
      ordered.add(current);
      for (final childId in childrenOf[nodeId] ?? const <String>[]) {
        walk(childId);
      }
    }

    walk(rootNodeId);
    return List.unmodifiable(ordered);
  }

  SceneRuntimeComponentTreeBuildResult moveNode({
    required String nodeId,
    required String newParentId,
    int? newZOrder,
  }) {
    final issues = <SceneRuntimeComponentTreeIssue>[];
    final target = nodeById[nodeId];
    final parent = nodeById[newParentId];
    if (target == null) {
      issues.add(
        const SceneRuntimeComponentTreeIssue(
          code: 'missing_node',
          message: 'Cannot move missing node.',
        ),
      );
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }
    if (parent == null) {
      issues.add(
        SceneRuntimeComponentTreeIssue(
          code: 'missing_parent',
          message:
              'Cannot move node `$nodeId` to missing parent `$newParentId`.',
          nodeId: nodeId,
        ),
      );
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }
    if (nodeId == rootNodeId) {
      issues.add(
        SceneRuntimeComponentTreeIssue(
          code: 'root_move_forbidden',
          message: 'Root node `$nodeId` cannot be re-parented.',
          nodeId: nodeId,
        ),
      );
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }

    final rewritten = <SceneRuntimeNode>[
      for (final node in nodeById.values)
        node.id == nodeId
            ? node.copyWith(parentId: newParentId, zOrder: newZOrder)
            : node,
    ];
    return build(rewritten);
  }

  static SceneRuntimeComponentTreeBuildResult build(
    List<SceneRuntimeNode> nodes,
  ) {
    final issues = <SceneRuntimeComponentTreeIssue>[];
    if (nodes.isEmpty) {
      issues.add(
        const SceneRuntimeComponentTreeIssue(
          code: 'empty_tree',
          message: 'Runtime component tree must include at least one node.',
          path: 'nodes',
        ),
      );
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }

    final nodeById = <String, SceneRuntimeNode>{};
    final insertionOrder = <String, int>{};
    for (var index = 0; index < nodes.length; index += 1) {
      final node = nodes[index];
      final id = node.id.trim();
      if (id.isEmpty) {
        issues.add(
          SceneRuntimeComponentTreeIssue(
            code: 'empty_node_id',
            message: 'Runtime node id must be non-empty.',
            path: 'nodes[$index].id',
          ),
        );
        continue;
      }
      if (nodeById.containsKey(id)) {
        issues.add(
          SceneRuntimeComponentTreeIssue(
            code: 'duplicate_node_id',
            message: 'Duplicate runtime node id `$id`.',
            nodeId: id,
            path: 'nodes[$index].id',
          ),
        );
        continue;
      }
      nodeById[id] = node.copyWith(id: id);
      insertionOrder[id] = index;
    }

    if (issues.isNotEmpty) {
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }

    final roots = nodeById.values.where((node) {
      final parent = node.parentId?.trim();
      return parent == null || parent.isEmpty;
    }).toList(growable: false);
    if (roots.length != 1) {
      issues.add(
        SceneRuntimeComponentTreeIssue(
          code: 'invalid_root_count',
          message:
              'Runtime tree requires exactly one root node; found ${roots.length}.',
          path: 'nodes',
        ),
      );
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }
    final rootNodeId = roots.single.id;

    final parentOf = <String, String?>{};
    final childrenOf = <String, List<String>>{
      for (final node in nodeById.values) node.id: <String>[],
    };

    for (final node in nodeById.values) {
      final parentId = node.parentId?.trim();
      if (parentId == null || parentId.isEmpty) {
        parentOf[node.id] = null;
        continue;
      }
      if (parentId == node.id) {
        issues.add(
          SceneRuntimeComponentTreeIssue(
            code: 'self_parent',
            message: 'Node `${node.id}` cannot parent itself.',
            nodeId: node.id,
          ),
        );
        continue;
      }
      if (!nodeById.containsKey(parentId)) {
        issues.add(
          SceneRuntimeComponentTreeIssue(
            code: 'missing_parent',
            message: 'Node `${node.id}` references missing parent `$parentId`.',
            nodeId: node.id,
          ),
        );
        continue;
      }
      parentOf[node.id] = parentId;
      childrenOf[parentId]!.add(node.id);
    }

    if (issues.isNotEmpty) {
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }

    for (final entry in childrenOf.entries) {
      final parentId = entry.key;
      entry.value.sort((left, right) {
        final leftNode = nodeById[left]!;
        final rightNode = nodeById[right]!;
        final byZ = leftNode.zOrder.compareTo(rightNode.zOrder);
        if (byZ != 0) {
          return byZ;
        }
        final leftOrder = insertionOrder[left] ?? 0;
        final rightOrder = insertionOrder[right] ?? 0;
        final byOrder = leftOrder.compareTo(rightOrder);
        if (byOrder != 0) {
          return byOrder;
        }
        return left.compareTo(right);
      });
      if (parentId == rootNodeId) {
        continue;
      }
    }

    final visiting = <String>{};
    final visited = <String>{};

    bool detectCycle(String nodeId) {
      if (visited.contains(nodeId)) {
        return false;
      }
      if (!visiting.add(nodeId)) {
        return true;
      }
      for (final child in childrenOf[nodeId] ?? const <String>[]) {
        if (detectCycle(child)) {
          return true;
        }
      }
      visiting.remove(nodeId);
      visited.add(nodeId);
      return false;
    }

    if (detectCycle(rootNodeId)) {
      issues.add(
        const SceneRuntimeComponentTreeIssue(
          code: 'cycle_detected',
          message: 'Runtime component tree contains a cycle.',
          path: 'nodes',
        ),
      );
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }

    if (visited.length != nodeById.length) {
      final unreachable = nodeById.keys
          .where((nodeId) => !visited.contains(nodeId))
          .toList(growable: false);
      issues.add(
        SceneRuntimeComponentTreeIssue(
          code: 'unreachable_nodes',
          message:
              'Runtime tree has unreachable or disconnected nodes: ${unreachable.join(', ')}.',
          path: 'nodes',
        ),
      );
      return SceneRuntimeComponentTreeBuildResult(issues: issues);
    }

    return SceneRuntimeComponentTreeBuildResult(
      tree: SceneRuntimeComponentTree._(
        rootNodeId: rootNodeId,
        nodeById: nodeById,
        parentOf: parentOf,
        childrenOf: childrenOf,
      ),
      issues: const <SceneRuntimeComponentTreeIssue>[],
    );
  }
}
