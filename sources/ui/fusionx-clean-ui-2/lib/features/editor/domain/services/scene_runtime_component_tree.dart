import 'dart:collection';
import 'dart:convert';

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
        ) {
    final byComponent = <String, List<String>>{};
    final bySourceElement = <String, List<String>>{};
    final bySlot = <String, List<String>>{};
    for (final node in nodeById.values) {
      final componentId = node.sourceComponentId?.trim();
      if (componentId != null && componentId.isNotEmpty) {
        byComponent.putIfAbsent(componentId, () => <String>[]).add(node.id);
      }
      final sourceLayerId = node.sourceLayerId?.trim();
      final sourceElementId = node.sourceElementId?.trim();
      if (sourceLayerId != null &&
          sourceLayerId.isNotEmpty &&
          sourceElementId != null &&
          sourceElementId.isNotEmpty) {
        final sourceKey = '$sourceLayerId::$sourceElementId';
        bySourceElement.putIfAbsent(sourceKey, () => <String>[]).add(node.id);
      }
      final slotId = node.slotId?.trim();
      if (slotId != null && slotId.isNotEmpty) {
        bySlot.putIfAbsent(slotId, () => <String>[]).add(node.id);
      }
    }
    nodeIdsByComponentId = UnmodifiableMapView<String, List<String>>(
      byComponent.map(
        (key, value) => MapEntry<String, List<String>>(
          key,
          List.unmodifiable(_sortedIds(value)),
        ),
      ),
    );
    nodeIdsBySourceElement = UnmodifiableMapView<String, List<String>>(
      bySourceElement.map(
        (key, value) => MapEntry<String, List<String>>(
          key,
          List.unmodifiable(_sortedIds(value)),
        ),
      ),
    );
    nodeIdsBySlotId = UnmodifiableMapView<String, List<String>>(
      bySlot.map(
        (key, value) => MapEntry<String, List<String>>(
          key,
          List.unmodifiable(_sortedIds(value)),
        ),
      ),
    );
    traversalNodeIds = List.unmodifiable(
      depthFirstNodes().map((node) => node.id).toList(growable: false),
    );
    deterministicHash = _computeTreeHash(this);
  }

  final String rootNodeId;
  final Map<String, SceneRuntimeNode> nodeById;
  final Map<String, String?> parentOf;
  final Map<String, List<String>> childrenOf;
  late final Map<String, List<String>> nodeIdsByComponentId;
  late final Map<String, List<String>> nodeIdsBySourceElement;
  late final Map<String, List<String>> nodeIdsBySlotId;
  late final List<String> traversalNodeIds;
  late final String deterministicHash;

  SceneRuntimeNode get root => nodeById[rootNodeId]!;

  SceneRuntimeNode? node(String nodeId) => nodeById[nodeId];

  List<SceneRuntimeNode> children(String nodeId) =>
      childrenOf[nodeId]
          ?.map((childId) => nodeById[childId])
          .whereType<SceneRuntimeNode>()
          .toList(growable: false) ??
      const <SceneRuntimeNode>[];

  List<SceneRuntimeNode> nodesForComponentId(String componentId) =>
      _nodesForIds(nodeIdsByComponentId[componentId] ?? const <String>[]);

  List<SceneRuntimeNode> nodesForSlotId(String slotId) =>
      _nodesForIds(nodeIdsBySlotId[slotId] ?? const <String>[]);

  List<SceneRuntimeNode> nodesForSourceElement({
    required String sourceLayerId,
    required String sourceElementId,
  }) {
    final key = '$sourceLayerId::$sourceElementId';
    return _nodesForIds(nodeIdsBySourceElement[key] ?? const <String>[]);
  }

  List<SceneRuntimeNode> _nodesForIds(List<String> ids) {
    return ids
        .map((id) => nodeById[id])
        .whereType<SceneRuntimeNode>()
        .toList(growable: false);
  }

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

  static List<String> _sortedIds(List<String> ids) {
    final sorted = ids.toList(growable: false)..sort();
    return sorted;
  }

  static String _computeTreeHash(SceneRuntimeComponentTree tree) {
    final lines = <String>[];
    for (final nodeId in tree.traversalNodeIds) {
      final node = tree.nodeById[nodeId]!;
      final metadata = _stableJson(node.metadata);
      lines.add(
        [
          node.id,
          node.nodeType.name,
          node.parentId ?? '',
          node.zOrder.toString(),
          node.sourceComponentId ?? '',
          node.sourceLayerId ?? '',
          node.sourceElementId ?? '',
          node.slotId ?? '',
          metadata,
        ].join('|'),
      );
    }
    final text = lines.join('\n');
    return _fnv1a64Hex(text);
  }

  static String _stableJson(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is num || value is bool || value is String) {
      return jsonEncode(value);
    }
    if (value is List) {
      return '[${value.map(_stableJson).join(',')}]';
    }
    if (value is Map) {
      final normalized = <String, Object?>{};
      for (final entry in value.entries) {
        normalized[entry.key.toString()] = entry.value;
      }
      final keys = normalized.keys.toList(growable: false)..sort();
      final entries = keys
          .map((k) => '${jsonEncode(k)}:${_stableJson(normalized[k])}')
          .join(',');
      return '{$entries}';
    }
    return jsonEncode(value.toString());
  }

  static String _fnv1a64Hex(String text) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xffffffffffffffff;
    var hash = offset;
    final bytes = utf8.encode(text);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
