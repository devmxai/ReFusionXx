import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_global_parent_graph.dart';

void main() {
  const graph = SceneGlobalParentGraph();

  ReFusionSceneProgram _programWithCrossLayerParent() {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Cross Layer Parent',
      durationMs: 1000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'shell-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'shell',
              kind: 'shape',
              properties: const <String, Object?>{},
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'text-layer',
          kind: 'text',
          startMs: 0,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'shell-text',
              kind: 'text',
              text: 'hello',
              properties: const <String, Object?>{
                'parentId': 'shell',
              },
            ),
          ],
        ),
      ],
    );
  }

  test('resolves parent across layers when id is unique in program', () {
    final result = graph.build(_programWithCrossLayerParent());
    expect(result.issues, isEmpty);
    expect(
      result.parentByRuntimeNodeId['__layer__text-layer__element__shell-text'],
      '__layer__shell-layer__element__shell',
    );
  });

  test('falls back to scene root and emits issue for missing parent', () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Missing Parent',
      durationMs: 1000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'text-layer',
          kind: 'text',
          startMs: 0,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'shell-text',
              kind: 'text',
              text: 'hello',
              properties: const <String, Object?>{
                'parentId': 'missing-shell',
              },
            ),
          ],
        ),
      ],
    );

    final result = graph.build(program);
    expect(
      result.parentByRuntimeNodeId['__layer__text-layer__element__shell-text'],
      SceneGlobalParentGraph.sceneRootNodeId,
    );
    expect(
      result.issues.any((issue) => issue.code == 'missing_parent'),
      isTrue,
    );
  });

  test('falls back to scene root and emits issue for ambiguous parent', () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Ambiguous Parent',
      durationMs: 1000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'left-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'shell',
              kind: 'shape',
              properties: const <String, Object?>{},
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'right-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'shell',
              kind: 'shape',
              properties: const <String, Object?>{},
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'text-layer',
          kind: 'text',
          startMs: 0,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'shell-text',
              kind: 'text',
              text: 'hello',
              properties: const <String, Object?>{
                'parentId': 'shell',
              },
            ),
          ],
        ),
      ],
    );

    final result = graph.build(program);
    expect(
      result.parentByRuntimeNodeId['__layer__text-layer__element__shell-text'],
      SceneGlobalParentGraph.sceneRootNodeId,
    );
    expect(
      result.issues.any((issue) => issue.code == 'ambiguous_parent'),
      isTrue,
    );
  });
}
