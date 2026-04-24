import 'package:flutter/foundation.dart';

import '../models/professional_normal_transition_models.dart';

enum NormalTransitionHistoryIssueCode {
  duplicateNode,
  missingNode,
  missingInstance,
  nodeInstanceMismatch,
  emptyUndoStack,
  emptyRedoStack,
}

@immutable
class NormalTransitionHistoryIssue {
  const NormalTransitionHistoryIssue({
    required this.code,
    required this.message,
    this.nodeId,
    this.instanceId,
  });

  final NormalTransitionHistoryIssueCode code;
  final String message;
  final String? nodeId;
  final String? instanceId;
}

@immutable
class NormalTransitionTimelineState {
  const NormalTransitionTimelineState({
    this.nodes = const <NormalTransitionNode>[],
    this.instances = const <NormalTransitionInstance>[],
  });

  final List<NormalTransitionNode> nodes;
  final List<NormalTransitionInstance> instances;

  bool get isEmpty => nodes.isEmpty && instances.isEmpty;

  NormalTransitionNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  NormalTransitionInstance? instanceById(String id) {
    for (final instance in instances) {
      if (instance.id == id) {
        return instance;
      }
    }
    return null;
  }

  NormalTransitionInstance? instanceForNode(String nodeId) {
    for (final instance in instances) {
      if (instance.nodeId == nodeId) {
        return instance;
      }
    }
    return null;
  }

  NormalTransitionTimelineState upsert({
    required NormalTransitionNode node,
    required NormalTransitionInstance instance,
  }) {
    final nextNodes = <NormalTransitionNode>[
      for (final existing in nodes)
        if (existing.id != node.id) existing,
      node,
    ];
    final nextInstances = <NormalTransitionInstance>[
      for (final existing in instances)
        if (existing.id != instance.id && existing.nodeId != node.id) existing,
      instance,
    ];
    return NormalTransitionTimelineState(
      nodes: List.unmodifiable(nextNodes),
      instances: List.unmodifiable(nextInstances),
    );
  }

  NormalTransitionTimelineState removeNode(String nodeId) {
    return NormalTransitionTimelineState(
      nodes: List.unmodifiable(
        nodes.where((node) => node.id != nodeId),
      ),
      instances: List.unmodifiable(
        instances.where((instance) => instance.nodeId != nodeId),
      ),
    );
  }
}

@immutable
class NormalTransitionHistoryResult {
  const NormalTransitionHistoryResult({
    required this.state,
    this.issues = const <NormalTransitionHistoryIssue>[],
  });

  final NormalTransitionTimelineState state;
  final List<NormalTransitionHistoryIssue> issues;

  bool get success => issues.isEmpty;
}

class NormalTransitionCommandHistoryController {
  NormalTransitionCommandHistoryController({
    NormalTransitionTimelineState initialState =
        const NormalTransitionTimelineState(),
  }) : _state = initialState;

  NormalTransitionTimelineState _state;
  final List<NormalTransitionTimelineState> _undoStack =
      <NormalTransitionTimelineState>[];
  final List<NormalTransitionTimelineState> _redoStack =
      <NormalTransitionTimelineState>[];

  NormalTransitionTimelineState get state => _state;

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  NormalTransitionHistoryResult addTransition({
    required NormalTransitionNode node,
    required NormalTransitionInstance instance,
  }) {
    final issue = _validateNodeInstancePair(node: node, instance: instance);
    if (issue != null) {
      return NormalTransitionHistoryResult(
        state: _state,
        issues: <NormalTransitionHistoryIssue>[issue],
      );
    }
    if (_state.nodeById(node.id) != null) {
      return NormalTransitionHistoryResult(
        state: _state,
        issues: <NormalTransitionHistoryIssue>[
          NormalTransitionHistoryIssue(
            code: NormalTransitionHistoryIssueCode.duplicateNode,
            message: 'Transition node `${node.id}` already exists.',
            nodeId: node.id,
          ),
        ],
      );
    }
    return _commit(_state.upsert(node: node, instance: instance));
  }

  NormalTransitionHistoryResult updateTransition({
    required NormalTransitionNode node,
    NormalTransitionInstance? instance,
  }) {
    final existingNode = _state.nodeById(node.id);
    if (existingNode == null) {
      return NormalTransitionHistoryResult(
        state: _state,
        issues: <NormalTransitionHistoryIssue>[
          NormalTransitionHistoryIssue(
            code: NormalTransitionHistoryIssueCode.missingNode,
            message: 'Transition node `${node.id}` does not exist.',
            nodeId: node.id,
          ),
        ],
      );
    }
    final resolvedInstance = instance ?? _state.instanceForNode(node.id);
    if (resolvedInstance == null) {
      return NormalTransitionHistoryResult(
        state: _state,
        issues: <NormalTransitionHistoryIssue>[
          NormalTransitionHistoryIssue(
            code: NormalTransitionHistoryIssueCode.missingInstance,
            message: 'Transition node `${node.id}` has no instance.',
            nodeId: node.id,
          ),
        ],
      );
    }
    final issue = _validateNodeInstancePair(
      node: node,
      instance: resolvedInstance,
    );
    if (issue != null) {
      return NormalTransitionHistoryResult(
        state: _state,
        issues: <NormalTransitionHistoryIssue>[issue],
      );
    }
    return _commit(_state.upsert(node: node, instance: resolvedInstance));
  }

  NormalTransitionHistoryResult removeTransition(String nodeId) {
    if (_state.nodeById(nodeId) == null) {
      return NormalTransitionHistoryResult(
        state: _state,
        issues: <NormalTransitionHistoryIssue>[
          NormalTransitionHistoryIssue(
            code: NormalTransitionHistoryIssueCode.missingNode,
            message: 'Transition node `$nodeId` does not exist.',
            nodeId: nodeId,
          ),
        ],
      );
    }
    return _commit(_state.removeNode(nodeId));
  }

  NormalTransitionHistoryResult undo() {
    if (_undoStack.isEmpty) {
      return NormalTransitionHistoryResult(
        state: _state,
        issues: const <NormalTransitionHistoryIssue>[
          NormalTransitionHistoryIssue(
            code: NormalTransitionHistoryIssueCode.emptyUndoStack,
            message: 'There is no transition edit to undo.',
          ),
        ],
      );
    }
    _redoStack.add(_state);
    _state = _undoStack.removeLast();
    return NormalTransitionHistoryResult(state: _state);
  }

  NormalTransitionHistoryResult redo() {
    if (_redoStack.isEmpty) {
      return NormalTransitionHistoryResult(
        state: _state,
        issues: const <NormalTransitionHistoryIssue>[
          NormalTransitionHistoryIssue(
            code: NormalTransitionHistoryIssueCode.emptyRedoStack,
            message: 'There is no transition edit to redo.',
          ),
        ],
      );
    }
    _undoStack.add(_state);
    _state = _redoStack.removeLast();
    return NormalTransitionHistoryResult(state: _state);
  }

  NormalTransitionHistoryResult _commit(NormalTransitionTimelineState next) {
    _undoStack.add(_state);
    _state = next;
    _redoStack.clear();
    return NormalTransitionHistoryResult(state: _state);
  }

  NormalTransitionHistoryIssue? _validateNodeInstancePair({
    required NormalTransitionNode node,
    required NormalTransitionInstance instance,
  }) {
    if (instance.nodeId != node.id) {
      return NormalTransitionHistoryIssue(
        code: NormalTransitionHistoryIssueCode.nodeInstanceMismatch,
        message:
            'Transition instance `${instance.id}` does not belong to node `${node.id}`.',
        nodeId: node.id,
        instanceId: instance.id,
      );
    }
    if (node.instanceId != null && node.instanceId != instance.id) {
      return NormalTransitionHistoryIssue(
        code: NormalTransitionHistoryIssueCode.nodeInstanceMismatch,
        message:
            'Transition node `${node.id}` points at a different instance id.',
        nodeId: node.id,
        instanceId: instance.id,
      );
    }
    return null;
  }
}
