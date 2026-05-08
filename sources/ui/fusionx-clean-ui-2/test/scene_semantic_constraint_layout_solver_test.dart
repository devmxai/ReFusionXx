import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/scene_semantic_blueprint_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_constraint_layout_solver.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_token_registry.dart';

void main() {
  const solver = SceneSemanticConstraintLayoutSolver();
  final tokenRegistry = SceneSemanticTokenRegistry();

  test('produces deterministic layout hash for the same input', () {
    final components = <SemanticSceneBlueprintComponent>[
      SemanticSceneBlueprintComponent(
        id: 'card-a',
        type: 'FeatureCard',
        properties: const <String, Object?>{
          'width': 320,
          'height': 180,
          'anchor': <String, Object?>{'x': -220, 'y': -120},
        },
      ),
      SemanticSceneBlueprintComponent(
        id: 'card-b',
        type: 'FeatureCard',
        properties: const <String, Object?>{
          'width': 320,
          'height': 180,
          'anchor': <String, Object?>{'x': 220, 'y': -120},
        },
      ),
    ];

    final first = solver.solve(
      components: components,
      tokenRegistry: tokenRegistry,
      profile: SceneSemanticCanvasProfile.story916,
    );
    final second = solver.solve(
      components: components,
      tokenRegistry: tokenRegistry,
      profile: SceneSemanticCanvasProfile.story916,
    );

    expect(
        first.deterministicLayoutHash, equals(second.deterministicLayoutHash));
  });

  test('fails closed when components overlap in safe area', () {
    final result = solver.solve(
      components: <SemanticSceneBlueprintComponent>[
        SemanticSceneBlueprintComponent(
          id: 'one',
          type: 'FeatureCard',
          properties: const <String, Object?>{
            'width': 400,
            'height': 240,
            'anchor': <String, Object?>{'x': 0, 'y': 0},
          },
        ),
        SemanticSceneBlueprintComponent(
          id: 'two',
          type: 'FeatureCard',
          properties: const <String, Object?>{
            'width': 400,
            'height': 240,
            'anchor': <String, Object?>{'x': 0, 'y': 0},
          },
        ),
      ],
      tokenRegistry: tokenRegistry,
      profile: SceneSemanticCanvasProfile.story916,
    );

    expect(
      result.issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('overlap detected'),
      ),
      isTrue,
    );
  });

  test('fails closed when component exceeds safe area', () {
    final result = solver.solve(
      components: <SemanticSceneBlueprintComponent>[
        SemanticSceneBlueprintComponent(
          id: 'outside',
          type: 'FeatureCard',
          properties: const <String, Object?>{
            'width': 500,
            'height': 220,
            'anchor': <String, Object?>{'x': 520, 'y': 860},
          },
        ),
      ],
      tokenRegistry: tokenRegistry,
      profile: SceneSemanticCanvasProfile.story916,
    );

    expect(
      result.issues.any(
        (issue) =>
            issue.severity.name == 'error' &&
            issue.message.contains('exceeds safe area'),
      ),
      isTrue,
    );
  });

  test('emits solver proof diagnostics', () {
    final result = solver.solve(
      components: <SemanticSceneBlueprintComponent>[
        SemanticSceneBlueprintComponent(
          id: 'stack-1',
          type: 'FeatureCard',
          properties: const <String, Object?>{
            'width': 220,
            'height': 120,
            'anchor': <String, Object?>{'x': -320, 'y': -200},
            'layout': <String, Object?>{
              'type': 'horizontalStack',
              'gap': 24,
            },
          },
        ),
      ],
      tokenRegistry: tokenRegistry,
      profile: SceneSemanticCanvasProfile.story916,
    );

    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneLayoutSolverProofTag),
      ),
      isTrue,
    );
  });
}
