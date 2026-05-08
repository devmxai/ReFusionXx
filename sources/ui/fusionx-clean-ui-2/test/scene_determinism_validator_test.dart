import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/scene_runtime_node.dart';
import 'package:refusion_app/features/editor/domain/services/scene_determinism_validator.dart';
import 'package:refusion_app/features/editor/domain/services/scene_runtime_component_tree.dart';

void main() {
  const validator = SceneDeterminismValidator();

  test('hashTokenReferences is stable regardless of traversal order', () {
    final first = <String, Object?>{
      'schemaVersion': 'refusion.semantic-blueprint/v1',
      'components': <Object?>[
        <String, Object?>{
          'properties': <String, Object?>{
            'anchor': r'$anchor.center',
            'width': r'$spacing.2xl',
          },
          'slots': <String, Object?>{
            'primaryText': <String, Object?>{
              'textFrame': <String, Object?>{
                'width': r'$spacing.3xl',
              },
            },
          },
        },
      ],
    };
    final second = <String, Object?>{
      'components': <Object?>[
        <String, Object?>{
          'slots': <String, Object?>{
            'primaryText': <String, Object?>{
              'textFrame': <String, Object?>{
                'width': r'$spacing.3xl',
              },
            },
          },
          'properties': <String, Object?>{
            'width': r'$spacing.2xl',
            'anchor': r'$anchor.center',
          },
        },
      ],
      'schemaVersion': 'refusion.semantic-blueprint/v1',
    };

    expect(
      validator.hashTokenReferences(first),
      equals(validator.hashTokenReferences(second)),
    );
  });

  test('hashRuntimeTree and traversal hash are deterministic', () {
    final treeResult = SceneRuntimeComponentTree.build(<SceneRuntimeNode>[
      SceneRuntimeNode(id: 'root', nodeType: SceneRuntimeNodeType.sceneRoot),
      SceneRuntimeNode(
        id: 'component',
        nodeType: SceneRuntimeNodeType.component,
        parentId: 'root',
        zOrder: 0,
      ),
      SceneRuntimeNode(
        id: 'slot',
        nodeType: SceneRuntimeNodeType.slot,
        parentId: 'component',
        zOrder: 0,
      ),
      SceneRuntimeNode(
        id: 'leaf',
        nodeType: SceneRuntimeNodeType.text,
        parentId: 'slot',
        zOrder: 0,
      ),
    ]);
    expect(treeResult.isValid, isTrue);

    final tree = treeResult.tree!;
    final firstTreeHash = validator.hashRuntimeTree(tree);
    final secondTreeHash = validator.hashRuntimeTree(tree);
    expect(firstTreeHash, equals(secondTreeHash));
    expect(
      validator.hashTraversalOrder(tree),
      equals(validator.hashTraversalOrder(tree)),
    );
  });

  test('geometry snapshots remain stable for the same scene program', () {
    final program = _buildProgram(textX: 120);
    final first = validator.geometrySnapshot(program);
    final second = validator.geometrySnapshot(program);

    expect(first.samples, isNotEmpty);
    expect(first.probeHashes, equals(second.probeHashes));
    expect(
      validator.normalizedDrift(baseline: first, candidate: second),
      0.0,
    );
  });

  test('normalizedDrift increases when geometry actually changes', () {
    final baseline = validator.geometrySnapshot(_buildProgram(textX: 120));
    final changed = validator.geometrySnapshot(_buildProgram(textX: 280));

    expect(
      validator.normalizedDrift(
        baseline: baseline,
        candidate: changed,
      ),
      greaterThan(0.0),
    );
  });
}

ReFusionSceneProgram _buildProgram({required double textX}) {
  return ReFusionSceneProgram(
    schemaVersion: 'refusion.scene-program/v1',
    name: 'Determinism program',
    durationMs: 2400,
    frameRate: 30,
    layers: <ReFusionSceneProgramLayer>[
      ReFusionSceneProgramLayer(
        id: 'prompt-layer',
        kind: 'text',
        startMs: 0,
        durationMs: 2400,
        elements: <ReFusionSceneProgramElement>[
          ReFusionSceneProgramElement(
            id: 'prompt-text',
            kind: 'text',
            text: 'generate new offer for my business',
            properties: <String, Object?>{
              'x': textX,
              'y': 320,
              'fontSize': 28,
              'textFrame': const <String, Object?>{
                'width': 480,
                'height': 56,
                'maxLines': 1,
                'overflow': 'ellipsis',
                'fitPolicy': 'shrinkToFit',
              },
            },
          ),
        ],
        channels: <ReFusionSceneProgramChannel>[
          ReFusionSceneProgramChannel(
            target: 'prompt-text',
            property: 'typewriterProgress',
            keyframes: const <ReFusionSceneProgramKeyframe>[
              ReFusionSceneProgramKeyframe(timeMs: 160, value: 0.0),
              ReFusionSceneProgramKeyframe(timeMs: 1180, value: 1.0),
            ],
          ),
        ],
      ),
    ],
  );
}
