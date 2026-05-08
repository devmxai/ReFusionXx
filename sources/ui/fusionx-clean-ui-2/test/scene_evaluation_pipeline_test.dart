import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_coordinate_system.dart';
import 'package:refusion_app/features/editor/domain/services/scene_evaluation_diagnostics.dart';
import 'package:refusion_app/features/editor/domain/services/scene_evaluation_pipeline.dart';

void main() {
  const pipeline = SceneEvaluationPipeline();
  const canvas = SceneCanvasMetrics(width: 1080, height: 1920);

  ReFusionSceneProgram _groupedProgram() {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Grouped Program',
      durationMs: 1000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'layer-1',
          kind: 'shape',
          startMs: 0,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'card',
              kind: 'shape',
              properties: const <String, Object?>{
                'position': <String, Object?>{'x': 100.0, 'y': 50.0},
                'width': 200.0,
                'height': 100.0,
                'opacity': 1.0,
              },
            ),
            ReFusionSceneProgramElement(
              id: 'card-text',
              kind: 'text',
              text: 'hello',
              properties: const <String, Object?>{
                'parentId': 'card',
                'position': <String, Object?>{'x': 20.0, 'y': 10.0},
                'width': 100.0,
                'height': 20.0,
                'fontSize': 22.0,
              },
            ),
          ],
        ),
      ],
    );
  }

  test('evaluates parent-child world bounds in one shared frame truth', () {
    final result = pipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: _groupedProgram(),
        globalTimeMs: 0,
        canvas: canvas,
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.truth.coordinateSystem, SceneCoordinateSystem.canonical);

    final child =
        result.truth.nodesById['__layer__layer-1__element__card-text']!;
    expect(child.worldBoundsCenter.centerX, closeTo(120, 1e-6));
    expect(child.worldBoundsCenter.centerY, closeTo(60, 1e-6));
    expect(child.viewportBounds.left, closeTo(610, 1e-6));
    expect(child.viewportBounds.top, closeTo(1010, 1e-6));
  });

  test('center-origin sample position maps to expected viewport bounds', () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Center Mapping',
      durationMs: 1000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'layer-1',
          kind: 'shape',
          startMs: 0,
          durationMs: 1000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'node',
              kind: 'shape',
              properties: const <String, Object?>{
                'position': <String, Object?>{'x': 452.0, 'y': 640.0},
                'width': 176.0,
                'height': 176.0,
              },
            ),
          ],
        ),
      ],
    );

    final result = pipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: program,
        globalTimeMs: 0,
        canvas: canvas,
      ),
    );
    final node = result.truth.nodesById['__layer__layer-1__element__node']!;
    expect(node.viewportBounds.left, closeTo(904, 1e-6));
    expect(node.viewportBounds.top, closeTo(1512, 1e-6));
  });

  test('lifecycle marks nodes inactive outside layer duration', () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Lifecycle Program',
      durationMs: 1200,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'layer-1',
          kind: 'shape',
          startMs: 0,
          durationMs: 300,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'node',
              kind: 'shape',
              properties: const <String, Object?>{
                'position': <String, Object?>{'x': 0.0, 'y': 0.0},
                'width': 200.0,
                'height': 100.0,
              },
            ),
          ],
        ),
      ],
    );

    final result = pipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: program,
        globalTimeMs: 900,
        canvas: canvas,
      ),
    );
    final node = result.truth.nodesById['__layer__layer-1__element__node']!;
    expect(node.active, isFalse);
    expect(node.visible, isFalse);
  });

  test('emits evaluated frame proof diagnostics', () {
    final result = pipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: _groupedProgram(),
        globalTimeMs: 0,
        canvas: canvas,
      ),
    );
    expect(
      result.diagnostics.events.any(
        (event) => event.tag == SceneEvaluationDiagnostics.frameTruthProofTag,
      ),
      isTrue,
    );
  });
}
