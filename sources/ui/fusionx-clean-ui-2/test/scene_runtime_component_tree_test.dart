import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_runtime_node.dart';
import 'package:refusion_app/features/editor/domain/services/scene_runtime_component_tree.dart';

void main() {
  test('builds a deterministic single-root tree with ordered traversal', () {
    final result = SceneRuntimeComponentTree.build(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
      SceneRuntimeNode(
        id: 'card',
        nodeType: SceneRuntimeNodeType.component,
        parentId: 'root',
        zOrder: 10,
      ),
      SceneRuntimeNode(
        id: 'title',
        nodeType: SceneRuntimeNodeType.text,
        parentId: 'card',
        zOrder: 10,
      ),
      SceneRuntimeNode(
        id: 'icon',
        nodeType: SceneRuntimeNodeType.icon,
        parentId: 'card',
        zOrder: 5,
      ),
    ]);

    expect(result.isValid, isTrue, reason: _messages(result));
    final tree = result.tree!;
    expect(tree.rootNodeId, 'root');
    expect(tree.node('card'), isNotNull);
    expect(
      tree.children('card').map((node) => node.id).toList(growable: false),
      <String>['icon', 'title'],
    );
    expect(
      tree.depthFirstNodes().map((node) => node.id).toList(growable: false),
      <String>['root', 'card', 'icon', 'title'],
    );
  });

  test('fails for multiple roots', () {
    final result = SceneRuntimeComponentTree.build(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'rootA',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
      SceneRuntimeNode(
        id: 'rootB',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
    ]);

    expect(result.isValid, isFalse);
    expect(
      result.issues.any((issue) => issue.code == 'invalid_root_count'),
      isTrue,
    );
  });

  test('fails when node references missing parent', () {
    final result = SceneRuntimeComponentTree.build(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
      SceneRuntimeNode(
        id: 'child',
        nodeType: SceneRuntimeNodeType.component,
        parentId: 'missing',
      ),
    ]);

    expect(result.isValid, isFalse);
    expect(
      result.issues.any((issue) => issue.code == 'missing_parent'),
      isTrue,
    );
  });

  test('fails when cycle makes part of tree unreachable from root', () {
    final result = SceneRuntimeComponentTree.build(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
      SceneRuntimeNode(
        id: 'a',
        nodeType: SceneRuntimeNodeType.group,
        parentId: 'b',
      ),
      SceneRuntimeNode(
        id: 'b',
        nodeType: SceneRuntimeNodeType.group,
        parentId: 'a',
      ),
    ]);

    expect(result.isValid, isFalse);
    expect(
      result.issues.any((issue) => issue.code == 'unreachable_nodes'),
      isTrue,
    );
  });

  test('moveNode re-parents node and keeps tree valid', () {
    final built = SceneRuntimeComponentTree.build(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
      SceneRuntimeNode(
        id: 'left',
        nodeType: SceneRuntimeNodeType.group,
        parentId: 'root',
      ),
      SceneRuntimeNode(
        id: 'right',
        nodeType: SceneRuntimeNodeType.group,
        parentId: 'root',
      ),
      SceneRuntimeNode(
        id: 'label',
        nodeType: SceneRuntimeNodeType.text,
        parentId: 'left',
      ),
    ]);
    expect(built.isValid, isTrue, reason: _messages(built));

    final moved = built.tree!.moveNode(
      nodeId: 'label',
      newParentId: 'right',
      newZOrder: 30,
    );
    expect(moved.isValid, isTrue, reason: _messages(moved));
    expect(moved.tree!.parentOf['label'], 'right');
    expect(moved.tree!.node('label')!.zOrder, 30);
  });
}

String _messages(SceneRuntimeComponentTreeBuildResult result) =>
    result.issues.map((issue) => '${issue.code}:${issue.message}').join('\n');
