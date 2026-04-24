import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_authoring_service.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_command_history.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  final definition =
      const NormalTransitionCatalog().loadBuiltIns().definitionById(
            'cross_dissolve',
          )!;
  const authoring = NormalTransitionAuthoringService();

  NormalTransitionApplyResult buildApplyResult({
    double softness = 0.5,
    int durationMs = 720,
  }) {
    return authoring.createFromDefinition(
      NormalTransitionApplyRequest(
        definition: definition,
        trackId: 'video-main',
        leftClipId: 'clip-a',
        rightClipId: 'clip-b',
        boundaryTime: TimelineTime.fromMilliseconds(5000),
        leftAvailableTail: TimelineTime.fromMilliseconds(1000),
        rightAvailableHead: TimelineTime.fromMilliseconds(1000),
        duration: TimelineTime.fromMilliseconds(durationMs),
        parameterOverrides: <String, Object>{
          'softness': softness,
        },
      ),
    );
  }

  test('add transition is undoable and redoable', () {
    final apply = buildApplyResult();
    final history = NormalTransitionCommandHistoryController();

    final add = history.addTransition(
      node: apply.node!,
      instance: apply.instance!,
    );

    expect(add.success, isTrue);
    expect(history.state.nodes, hasLength(1));
    expect(history.canUndo, isTrue);
    expect(history.canRedo, isFalse);

    final undo = history.undo();

    expect(undo.success, isTrue);
    expect(history.state.isEmpty, isTrue);
    expect(history.canRedo, isTrue);

    final redo = history.redo();

    expect(redo.success, isTrue);
    expect(history.state.nodes.single.id, apply.node!.id);
    expect(history.state.instances.single.id, apply.instance!.id);
  });

  test('duplicate add is rejected without mutating history', () {
    final apply = buildApplyResult();
    final history = NormalTransitionCommandHistoryController();

    history.addTransition(node: apply.node!, instance: apply.instance!);
    final duplicate = history.addTransition(
      node: apply.node!,
      instance: apply.instance!,
    );

    expect(duplicate.success, isFalse);
    expect(duplicate.issues.single.code,
        NormalTransitionHistoryIssueCode.duplicateNode);
    expect(history.state.nodes, hasLength(1));
    expect(history.canUndo, isTrue);
    expect(history.canRedo, isFalse);
  });

  test('update transition is undoable', () {
    final apply = buildApplyResult();
    final history = NormalTransitionCommandHistoryController();
    history.addTransition(node: apply.node!, instance: apply.instance!);

    final updatedNode = apply.node!.copyWith(
      duration: TimelineTime.fromMilliseconds(900),
      parameterValues: const <String, Object>{'softness': 0.8},
    );
    final updatedInstance = apply.instance!.copyWith(
      parameterValues: const <String, Object>{'softness': 0.8},
    );

    final update = history.updateTransition(
      node: updatedNode,
      instance: updatedInstance,
    );

    expect(update.success, isTrue);
    expect(history.state.nodes.single.duration.inMilliseconds, 900);
    expect(history.state.nodes.single.parameterValues['softness'], 0.8);

    history.undo();

    expect(history.state.nodes.single.duration.inMilliseconds, 720);
    expect(history.state.nodes.single.parameterValues['softness'], 0.5);
  });

  test('remove transition is undoable', () {
    final apply = buildApplyResult();
    final history = NormalTransitionCommandHistoryController();
    history.addTransition(node: apply.node!, instance: apply.instance!);

    final remove = history.removeTransition(apply.node!.id);

    expect(remove.success, isTrue);
    expect(history.state.isEmpty, isTrue);

    history.undo();

    expect(history.state.nodes.single.id, apply.node!.id);
    expect(history.state.instances.single.nodeId, apply.node!.id);
  });

  test('node and instance mismatch is rejected', () {
    final apply = buildApplyResult();
    final history = NormalTransitionCommandHistoryController();
    final mismatchedInstance = apply.instance!.copyWith(
      nodeId: 'another-node',
    );

    final result = history.addTransition(
      node: apply.node!,
      instance: mismatchedInstance,
    );

    expect(result.success, isFalse);
    expect(
      result.issues.single.code,
      NormalTransitionHistoryIssueCode.nodeInstanceMismatch,
    );
    expect(history.state.isEmpty, isTrue);
  });
}
