import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_runtime_node.dart';
import 'package:refusion_app/features/editor/domain/services/scene_runtime_component_tree.dart';
import 'package:refusion_app/features/editor/domain/services/scene_runtime_transform_composer.dart';

void main() {
  test('child world transform inherits parent translation', () {
    final tree = _buildTree(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
      SceneRuntimeNode(
        id: 'parent',
        nodeType: SceneRuntimeNodeType.component,
        parentId: 'root',
        metadata: const <String, Object?>{
          'x': 100.0,
          'y': 30.0,
          'width': 200.0,
          'height': 80.0,
        },
      ),
      SceneRuntimeNode(
        id: 'child',
        nodeType: SceneRuntimeNodeType.text,
        parentId: 'parent',
        metadata: const <String, Object?>{
          'x': 12.0,
          'y': 8.0,
          'width': 60.0,
          'height': 20.0,
        },
      ),
    ]);
    final composer = SceneRuntimeTransformComposer();
    final result = composer.compose(tree: tree, timelineTimeMs: 500);

    final child = result.recordsByNodeId['child']!;
    expect(child.worldTransform.m02, closeTo(112.0, 1e-6));
    expect(child.worldTransform.m12, closeTo(38.0, 1e-6));
  });

  test('effective opacity cascades from parent to descendants', () {
    final tree = _buildTree(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
        metadata: const <String, Object?>{'opacity': 0.8},
      ),
      SceneRuntimeNode(
        id: 'parent',
        nodeType: SceneRuntimeNodeType.group,
        parentId: 'root',
        metadata: const <String, Object?>{'opacity': 0.5},
      ),
      SceneRuntimeNode(
        id: 'child',
        nodeType: SceneRuntimeNodeType.text,
        parentId: 'parent',
        metadata: const <String, Object?>{'opacity': 0.5},
      ),
    ]);
    final composer = SceneRuntimeTransformComposer();
    final result = composer.compose(tree: tree, timelineTimeMs: 300);

    expect(
        result.recordsByNodeId['child']!.effectiveOpacity, closeTo(0.2, 1e-6));
  });

  test('inactive parent hides child after lifecycle end', () {
    final tree = _buildTree(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
      SceneRuntimeNode(
        id: 'parent',
        nodeType: SceneRuntimeNodeType.component,
        parentId: 'root',
        metadata: const <String, Object?>{
          'startMs': 100,
          'endMs': 500,
        },
      ),
      SceneRuntimeNode(
        id: 'child',
        nodeType: SceneRuntimeNodeType.text,
        parentId: 'parent',
        metadata: const <String, Object?>{
          'startMs': 0,
          'endMs': 9999,
        },
      ),
    ]);
    final composer = SceneRuntimeTransformComposer();
    final result = composer.compose(tree: tree, timelineTimeMs: 700);

    expect(result.recordsByNodeId['parent']!.active, isFalse);
    expect(result.recordsByNodeId['child']!.active, isFalse);
  });

  test('parent scale expands child world bounds', () {
    final tree = _buildTree(<SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
      ),
      SceneRuntimeNode(
        id: 'parent',
        nodeType: SceneRuntimeNodeType.component,
        parentId: 'root',
        metadata: const <String, Object?>{
          'scaleX': 2.0,
          'scaleY': 2.0,
        },
      ),
      SceneRuntimeNode(
        id: 'child',
        nodeType: SceneRuntimeNodeType.shape,
        parentId: 'parent',
        metadata: const <String, Object?>{
          'width': 50.0,
          'height': 40.0,
        },
      ),
    ]);
    final composer = SceneRuntimeTransformComposer();
    final result = composer.compose(tree: tree, timelineTimeMs: 0);
    final childBounds = result.recordsByNodeId['child']!.worldBounds;

    expect(childBounds.width, closeTo(100.0, 1e-6));
    expect(childBounds.height, closeTo(80.0, 1e-6));
  });
}

SceneRuntimeComponentTree _buildTree(List<SceneRuntimeNode> nodes) {
  final built = SceneRuntimeComponentTree.build(nodes);
  expect(built.isValid, isTrue, reason: _issues(built));
  return built.tree!;
}

String _issues(SceneRuntimeComponentTreeBuildResult result) =>
    result.issues.map((issue) => issue.message).join('\n');
