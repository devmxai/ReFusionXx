import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_coordinate_system.dart';

void main() {
  test('canonical coordinate space is center-origin v1', () {
    expect(
      SceneCoordinateSystem.canonical,
      SceneCoordinateSpace.centerOriginV1,
    );
  });

  test('1080x1920 center-origin to viewport conversion', () {
    const canvas = SceneCanvasMetrics(width: 1080, height: 1920);

    final center = SceneCoordinateSystem.centerToViewportPoint(
      point: const ScenePoint(x: 0, y: 0),
      canvas: canvas,
    );
    expect(center.left, 540);
    expect(center.top, 960);

    final topLeft = SceneCoordinateSystem.centerToViewportPoint(
      point: const ScenePoint(x: -540, y: -960),
      canvas: canvas,
    );
    expect(topLeft.left, 0);
    expect(topLeft.top, 0);

    final sample = SceneCoordinateSystem.centerToViewportPoint(
      point: const ScenePoint(x: 452, y: 640),
      canvas: canvas,
    );
    expect(sample.left, 992);
    expect(sample.top, 1600);
  });

  test('1920x1080 center-origin to viewport conversion', () {
    const canvas = SceneCanvasMetrics(width: 1920, height: 1080);
    final center = SceneCoordinateSystem.centerToViewportPoint(
      point: const ScenePoint(x: 0, y: 0),
      canvas: canvas,
    );
    expect(center.left, 960);
    expect(center.top, 540);
  });

  test('1080x1080 center-origin to viewport conversion', () {
    const canvas = SceneCanvasMetrics(width: 1080, height: 1080);
    final center = SceneCoordinateSystem.centerToViewportPoint(
      point: const ScenePoint(x: 0, y: 0),
      canvas: canvas,
    );
    expect(center.left, 540);
    expect(center.top, 540);
  });

  test('1080x1350 center-origin to viewport conversion', () {
    const canvas = SceneCanvasMetrics(width: 1080, height: 1350);
    final center = SceneCoordinateSystem.centerToViewportPoint(
      point: const ScenePoint(x: 0, y: 0),
      canvas: canvas,
    );
    expect(center.left, 540);
    expect(center.top, 675);
  });

  test('viewport to center-origin is reversible', () {
    const canvas = SceneCanvasMetrics(width: 1080, height: 1920);
    final centerPoint = SceneCoordinateSystem.viewportToCenterPoint(
      point: const SceneViewportPoint(left: 992, top: 1600),
      canvas: canvas,
    );
    expect(centerPoint.x, 452);
    expect(centerPoint.y, 640);
  });

  test('rect conversion center-origin <-> viewport is reversible', () {
    const canvas = SceneCanvasMetrics(width: 1080, height: 1920);
    const rectCenter = SceneRectCenter(
      centerX: 452,
      centerY: 640,
      width: 176,
      height: 176,
    );

    final viewportRect = SceneCoordinateSystem.centerRectToViewportRect(
      rect: rectCenter,
      canvas: canvas,
    );
    expect(viewportRect.left, 904);
    expect(viewportRect.top, 1512);
    expect(viewportRect.width, 176);
    expect(viewportRect.height, 176);

    final centerRect = SceneCoordinateSystem.viewportRectToCenterRect(
      rect: viewportRect,
      canvas: canvas,
    );
    expect(centerRect.centerX, 452);
    expect(centerRect.centerY, 640);
    expect(centerRect.width, 176);
    expect(centerRect.height, 176);
  });

  test('containment works in center-origin and viewport spaces', () {
    const parentCenter = SceneRectCenter(
      centerX: 0,
      centerY: 0,
      width: 600,
      height: 300,
    );
    const childCenter = SceneRectCenter(
      centerX: 0,
      centerY: 0,
      width: 200,
      height: 100,
    );
    expect(
      SceneCoordinateSystem.containsRectCenter(
        parent: parentCenter,
        child: childCenter,
      ),
      isTrue,
    );

    const parentViewport = SceneViewportRect(
      left: 100,
      top: 100,
      width: 600,
      height: 300,
    );
    const childViewport = SceneViewportRect(
      left: 180,
      top: 160,
      width: 200,
      height: 100,
    );
    expect(
      SceneCoordinateSystem.containsRectViewport(
        parent: parentViewport,
        child: childViewport,
      ),
      isTrue,
    );
  });

  test('visual QA source has no implicit top-left layer roots', () {
    final source = File(
      'lib/features/editor/domain/services/scene_visual_frame_qa_validator.dart',
    ).readAsStringSync();
    expect(source.contains("'localLeft': 0.0"), isFalse);
    expect(source.contains("'localTop': 0.0"), isFalse);
  });
}
