import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_runtime_node.dart';
import 'package:refusion_app/features/editor/domain/services/scene_runtime_component_tree.dart';
import 'package:refusion_app/features/editor/domain/services/scene_runtime_transform_composer.dart';
import 'package:refusion_app/features/editor/domain/services/scene_slot_layout_solver.dart';

void main() {
  const solver = SceneSlotLayoutSolver();
  const composer = SceneRuntimeTransformComposer();

  SceneRuntimeCompositionResult compose(List<SceneRuntimeNode> nodes) {
    final built = SceneRuntimeComponentTree.build(nodes);
    expect(built.isValid, isTrue,
        reason: built.issues.map((i) => i.message).join('\n'));
    return composer.compose(tree: built.tree!, timelineTimeMs: 600);
  }

  SceneRuntimeComponentTree tree(List<SceneRuntimeNode> nodes) {
    final built = SceneRuntimeComponentTree.build(nodes);
    expect(built.isValid, isTrue,
        reason: built.issues.map((i) => i.message).join('\n'));
    return built.tree!;
  }

  test('PromptInputBar computes primary/trailing slot bounds from shell size',
      () {
    final nodes = <SceneRuntimeNode>[
      SceneRuntimeNode(id: 'root', nodeType: SceneRuntimeNodeType.sceneRoot),
      SceneRuntimeNode(
        id: 'prompt',
        nodeType: SceneRuntimeNodeType.component,
        parentId: 'root',
        metadata: const <String, Object?>{
          'componentType': 'PromptInputBar',
          'width': 860.0,
          'height': 118.0,
          'x': 0.0,
          'y': 0.0,
          'localLeft': -430.0,
          'localTop': -59.0,
        },
      ),
      SceneRuntimeNode(
        id: 'prompt::slot::primaryText',
        nodeType: SceneRuntimeNodeType.slot,
        parentId: 'prompt',
        slotId: 'primaryText',
      ),
      SceneRuntimeNode(
        id: 'prompt::slot::trailingAccessory',
        nodeType: SceneRuntimeNodeType.slot,
        parentId: 'prompt',
        slotId: 'trailingAccessory',
      ),
      SceneRuntimeNode(
        id: 'prompt::slot::leadingAccessory',
        nodeType: SceneRuntimeNodeType.slot,
        parentId: 'prompt',
        slotId: 'leadingAccessory',
      ),
    ];
    final builtTree = tree(nodes);
    final result = solver.solve(
      tree: builtTree,
      composition: compose(nodes),
    );

    final text = result.slotBoundsByNodeId['prompt::slot::primaryText']!;
    final trailing =
        result.slotBoundsByNodeId['prompt::slot::trailingAccessory']!;
    final leading =
        result.slotBoundsByNodeId['prompt::slot::leadingAccessory']!;
    expect(text.width, greaterThan(0));
    expect(trailing.width, lessThanOrEqualTo(124.0));
    expect(leading.width, lessThanOrEqualTo(92.0));
    expect(text.left, greaterThanOrEqualTo(leading.right));
    expect(text.right, lessThanOrEqualTo(trailing.left));
  });

  test('FeatureCard computes icon/title/body slots with non-overlapping layout',
      () {
    final nodes = <SceneRuntimeNode>[
      SceneRuntimeNode(id: 'root', nodeType: SceneRuntimeNodeType.sceneRoot),
      SceneRuntimeNode(
        id: 'feature',
        nodeType: SceneRuntimeNodeType.component,
        parentId: 'root',
        metadata: const <String, Object?>{
          'componentType': 'FeatureCard',
          'width': 620.0,
          'height': 220.0,
          'x': 0.0,
          'y': 0.0,
          'localLeft': -310.0,
          'localTop': -110.0,
        },
      ),
      SceneRuntimeNode(
        id: 'feature::slot::leadingIcon',
        nodeType: SceneRuntimeNodeType.slot,
        parentId: 'feature',
        slotId: 'leadingIcon',
      ),
      SceneRuntimeNode(
        id: 'feature::slot::title',
        nodeType: SceneRuntimeNodeType.slot,
        parentId: 'feature',
        slotId: 'title',
      ),
      SceneRuntimeNode(
        id: 'feature::slot::body',
        nodeType: SceneRuntimeNodeType.slot,
        parentId: 'feature',
        slotId: 'body',
      ),
    ];
    final result = solver.solve(
      tree: tree(nodes),
      composition: compose(nodes),
    );

    final icon = result.slotBoundsByNodeId['feature::slot::leadingIcon']!;
    final title = result.slotBoundsByNodeId['feature::slot::title']!;
    final body = result.slotBoundsByNodeId['feature::slot::body']!;
    expect(icon.width, greaterThan(0));
    expect(title.height, greaterThan(0));
    expect(body.height, greaterThan(0));
    expect(title.bottom, lessThanOrEqualTo(body.top + 0.001));
    expect(title.left, greaterThanOrEqualTo(icon.right));
  });

  test('changing component width recomputes primaryText slot width safely', () {
    List<SceneRuntimeNode> promptNodes(double width) {
      return <SceneRuntimeNode>[
        SceneRuntimeNode(id: 'root', nodeType: SceneRuntimeNodeType.sceneRoot),
        SceneRuntimeNode(
          id: 'prompt',
          nodeType: SceneRuntimeNodeType.component,
          parentId: 'root',
          metadata: <String, Object?>{
            'componentType': 'PromptInputBar',
            'width': width,
            'height': 118.0,
            'x': 0.0,
            'y': 0.0,
            'localLeft': -(width / 2),
            'localTop': -59.0,
          },
        ),
        SceneRuntimeNode(
          id: 'prompt::slot::primaryText',
          nodeType: SceneRuntimeNodeType.slot,
          parentId: 'prompt',
          slotId: 'primaryText',
        ),
        SceneRuntimeNode(
          id: 'prompt::slot::trailingAccessory',
          nodeType: SceneRuntimeNodeType.slot,
          parentId: 'prompt',
          slotId: 'trailingAccessory',
        ),
      ];
    }

    final wideNodes = promptNodes(860);
    final narrowNodes = promptNodes(640);

    final wide = solver.solve(
      tree: tree(wideNodes),
      composition: compose(wideNodes),
    );
    final narrow = solver.solve(
      tree: tree(narrowNodes),
      composition: compose(narrowNodes),
    );
    final wideText = wide.slotBoundsByNodeId['prompt::slot::primaryText']!;
    final narrowText = narrow.slotBoundsByNodeId['prompt::slot::primaryText']!;

    expect(wideText.width, greaterThan(narrowText.width));
    expect(narrowText.width, greaterThan(100));
  });
}
