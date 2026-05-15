import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/services/mcp_coordinate_resolution.dart';

void main() {
  const canvas = MotionSize2D(width: 1080, height: 1920);

  group('McpCoordinateResolution', () {
    test('keeps explicit centerOrigin as center space', () {
      final space = McpCoordinateResolution.resolvePlacementCoordinateSpace(
        coordinateSpace: 'centerOrigin',
        rawX: 120,
        rawY: 180,
        absoluteCenterX: null,
        absoluteCenterY: null,
        canvasSize: canvas,
      );
      expect(space, 'centerorigin');
      expect(
        McpCoordinateResolution.canonicalCoordinateFromRemoteValue(
          120,
          axisExtent: canvas.width,
          coordinateSpace: space,
        ),
        120,
      );
    });

    test('uses top-left semantics when centerX/centerY are present', () {
      final space = McpCoordinateResolution.resolvePlacementCoordinateSpace(
        coordinateSpace: 'unknown',
        rawX: null,
        rawY: null,
        absoluteCenterX: 540,
        absoluteCenterY: 960,
        canvasSize: canvas,
      );
      expect(space, 'topleft');
      expect(
        McpCoordinateResolution.canonicalCoordinateFromRemoteValue(
          540,
          axisExtent: canvas.width,
          coordinateSpace: space,
        ),
        0,
      );
      expect(
        McpCoordinateResolution.canonicalCoordinateFromRemoteValue(
          960,
          axisExtent: canvas.height,
          coordinateSpace: space,
        ),
        0,
      );
    });

    test('infers top-left for ambiguous non-negative in-canvas x/y pairs', () {
      final space = McpCoordinateResolution.resolvePlacementCoordinateSpace(
        coordinateSpace: 'unknown',
        rawX: 540,
        rawY: 960,
        absoluteCenterX: null,
        absoluteCenterY: null,
        canvasSize: canvas,
      );
      expect(space, 'topleft');
      expect(
        McpCoordinateResolution.canonicalCoordinateFromRemoteValue(
          540,
          axisExtent: canvas.width,
          coordinateSpace: space,
        ),
        0,
      );
      expect(
        McpCoordinateResolution.canonicalCoordinateFromRemoteValue(
          960,
          axisExtent: canvas.height,
          coordinateSpace: space,
        ),
        0,
      );
    });

    test('falls back to centerOrigin for negative x/y pairs', () {
      final space = McpCoordinateResolution.resolvePlacementCoordinateSpace(
        coordinateSpace: 'unknown',
        rawX: -120,
        rawY: -180,
        absoluteCenterX: null,
        absoluteCenterY: null,
        canvasSize: canvas,
      );
      expect(space, 'centerorigin');
      expect(
        McpCoordinateResolution.canonicalCoordinateFromRemoteValue(
          -120,
          axisExtent: canvas.width,
          coordinateSpace: space,
        ),
        -120,
      );
      expect(
        McpCoordinateResolution.canonicalCoordinateFromRemoteValue(
          -180,
          axisExtent: canvas.height,
          coordinateSpace: space,
        ),
        -180,
      );
    });
  });
}
