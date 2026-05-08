import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/evaluated_frame_truth.dart';
import 'package:refusion_app/features/editor/domain/services/scene_coordinate_system.dart';

void main() {
  const canvas = SceneCanvasMetrics(width: 1080, height: 1920);

  EvaluatedSceneNode _node({
    required String id,
    required double centerX,
    required double centerY,
    required double left,
    required double top,
    required int zOrder,
    double opacity = 1,
  }) {
    return EvaluatedSceneNode(
      nodeId: id,
      nodeType: 'shape',
      localTransform: EvaluatedTransform2D.identity,
      worldTransform: EvaluatedTransform2D.identity,
      localBoundsCenter: const SceneRectCenter(
        centerX: 0,
        centerY: 0,
        width: 100,
        height: 100,
      ),
      worldBoundsCenter: SceneRectCenter(
        centerX: centerX,
        centerY: centerY,
        width: 100,
        height: 100,
      ),
      viewportBounds: SceneViewportRect(
        left: left,
        top: top,
        width: 100,
        height: 100,
      ),
      effectiveOpacity: opacity,
      active: true,
      visible: true,
      zOrder: zOrder,
    );
  }

  test('hashes are deterministic regardless of map insertion order', () {
    final first = EvaluatedFrameTruth(
      coordinateSystem: SceneCoordinateSystem.canonical,
      canvas: canvas,
      globalTimeMs: 1200,
      sceneId: 'scene-a',
      nodesById: <String, EvaluatedSceneNode>{
        'node-b': _node(
          id: 'node-b',
          centerX: 100,
          centerY: 200,
          left: 590,
          top: 1110,
          zOrder: 2,
        ),
        'node-a': _node(
          id: 'node-a',
          centerX: -220,
          centerY: -180,
          left: 270,
          top: 730,
          zOrder: 1,
        ),
      },
    );

    final second = EvaluatedFrameTruth(
      coordinateSystem: SceneCoordinateSystem.canonical,
      canvas: canvas,
      globalTimeMs: 1200,
      sceneId: 'scene-a',
      nodesById: <String, EvaluatedSceneNode>{
        'node-a': _node(
          id: 'node-a',
          centerX: -220,
          centerY: -180,
          left: 270,
          top: 730,
          zOrder: 1,
        ),
        'node-b': _node(
          id: 'node-b',
          centerX: 100,
          centerY: 200,
          left: 590,
          top: 1110,
          zOrder: 2,
        ),
      },
    );

    expect(first.geometryHash, second.geometryHash);
    expect(first.frameHash, second.frameHash);
  });

  test('frame hash changes when frame-relevant node values change', () {
    final base = EvaluatedFrameTruth(
      coordinateSystem: SceneCoordinateSystem.canonical,
      canvas: canvas,
      globalTimeMs: 1200,
      sceneId: 'scene-a',
      nodesById: <String, EvaluatedSceneNode>{
        'node-a': _node(
          id: 'node-a',
          centerX: 10,
          centerY: 20,
          left: 500,
          top: 930,
          zOrder: 1,
          opacity: 1,
        ),
      },
    );

    final changed = EvaluatedFrameTruth(
      coordinateSystem: SceneCoordinateSystem.canonical,
      canvas: canvas,
      globalTimeMs: 1200,
      sceneId: 'scene-a',
      nodesById: <String, EvaluatedSceneNode>{
        'node-a': _node(
          id: 'node-a',
          centerX: 10,
          centerY: 20,
          left: 500,
          top: 930,
          zOrder: 1,
          opacity: 0.75,
        ),
      },
    );

    expect(base.geometryHash, changed.geometryHash);
    expect(base.frameHash, isNot(changed.frameHash));
  });

  test('diagnostic map includes coordinate metadata and hashes', () {
    final truth = EvaluatedFrameTruth(
      coordinateSystem: SceneCoordinateSystem.canonical,
      canvas: canvas,
      globalTimeMs: 600,
      sceneId: 'scene-diagnostic',
      nodesById: <String, EvaluatedSceneNode>{
        'node-a': _node(
          id: 'node-a',
          centerX: 0,
          centerY: 0,
          left: 490,
          top: 910,
          zOrder: 1,
        ),
      },
      sourceMaps: const <String, Object?>{
        'node-a': <String, Object?>{'layerId': 'layer-1'},
      },
      diagnostics: const <String, Object?>{
        'pipeline': 'v4-mvp',
      },
    );

    final map = truth.toDiagnosticMap();
    expect(map['coordinateSystem'], SceneCoordinateSystem.canonical.name);
    expect(map['sceneId'], 'scene-diagnostic');
    expect((map['frameHash'] as String).isNotEmpty, isTrue);
    expect((map['geometryHash'] as String).isNotEmpty, isTrue);
    expect(map['nodeCount'], 1);
  });
}
