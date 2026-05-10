import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
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

  test('emits proportional proof diagnostics for feature card components', () {
    final nodes = <SceneRuntimeNode>[
      SceneRuntimeNode(
        id: 'root',
        nodeType: SceneRuntimeNodeType.sceneRoot,
        metadata: const <String, Object?>{
          'width': 1080.0,
          'height': 1920.0,
          'localLeft': -540.0,
          'localTop': -960.0,
        },
      ),
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

    expect(
      result.issues.any(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.info &&
            issue.message.contains('TF_SCENE_PROPORTIONAL_RULES_PROOF') &&
            issue.message.contains('componentType=featurecard'),
      ),
      isTrue,
    );
  });

  test(
      'fallback slot flow follows aspect policy (portrait vertical, landscape horizontal)',
      () {
    List<SceneRuntimeNode> nodesFor({
      required double canvasWidth,
      required double canvasHeight,
    }) {
      return <SceneRuntimeNode>[
        SceneRuntimeNode(
          id: '__scene_root__',
          nodeType: SceneRuntimeNodeType.sceneRoot,
          metadata: <String, Object?>{
            'width': canvasWidth,
            'height': canvasHeight,
            'localLeft': -(canvasWidth / 2),
            'localTop': -(canvasHeight / 2),
          },
        ),
        SceneRuntimeNode(
          id: 'grid',
          nodeType: SceneRuntimeNodeType.component,
          parentId: '__scene_root__',
          metadata: const <String, Object?>{
            'componentType': 'DashboardPanel',
            'width': 640.0,
            'height': 240.0,
            'x': 0.0,
            'y': 0.0,
            'localLeft': -320.0,
            'localTop': -120.0,
          },
        ),
        SceneRuntimeNode(
          id: 'grid::slot::one',
          nodeType: SceneRuntimeNodeType.slot,
          parentId: 'grid',
          slotId: 'one',
        ),
        SceneRuntimeNode(
          id: 'grid::slot::two',
          nodeType: SceneRuntimeNodeType.slot,
          parentId: 'grid',
          slotId: 'two',
        ),
        SceneRuntimeNode(
          id: 'grid::slot::three',
          nodeType: SceneRuntimeNodeType.slot,
          parentId: 'grid',
          slotId: 'three',
        ),
        SceneRuntimeNode(
          id: 'grid::slot::four',
          nodeType: SceneRuntimeNodeType.slot,
          parentId: 'grid',
          slotId: 'four',
        ),
      ];
    }

    final portraitNodes = nodesFor(canvasWidth: 1080, canvasHeight: 1920);
    final portraitResult = solver.solve(
      tree: tree(portraitNodes),
      composition: compose(portraitNodes),
    );
    final p1 = portraitResult.slotBoundsByNodeId['grid::slot::one']!;
    final p2 = portraitResult.slotBoundsByNodeId['grid::slot::two']!;
    expect(p1.left, closeTo(p2.left, 0.01));
    expect(p2.top, greaterThan(p1.top));

    final landscapeNodes = nodesFor(canvasWidth: 1920, canvasHeight: 1080);
    final landscapeResult = solver.solve(
      tree: tree(landscapeNodes),
      composition: compose(landscapeNodes),
    );
    final l1 = landscapeResult.slotBoundsByNodeId['grid::slot::one']!;
    final l2 = landscapeResult.slotBoundsByNodeId['grid::slot::two']!;
    expect(l1.top, closeTo(l2.top, 0.01));
    expect(l2.left, greaterThan(l1.left));
  });
}
