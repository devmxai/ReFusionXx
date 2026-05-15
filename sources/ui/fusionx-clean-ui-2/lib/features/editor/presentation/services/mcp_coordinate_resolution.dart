import '../../domain/models/professional_motion_models.dart';

class McpCoordinateResolution {
  const McpCoordinateResolution._();

  static String resolvePlacementCoordinateSpace({
    required String coordinateSpace,
    required double? rawX,
    required double? rawY,
    required double? absoluteCenterX,
    required double? absoluteCenterY,
    required MotionSize2D canvasSize,
  }) {
    final normalized = coordinateSpace.toLowerCase();
    final hasExplicitTopLeft = normalized.contains('topleft') ||
        normalized.contains('absolute') ||
        normalized.contains('css') ||
        normalized.contains('canvaspixel');
    if (hasExplicitTopLeft) {
      return 'topleft';
    }
    if (normalized.contains('center')) {
      return 'centerorigin';
    }
    if (absoluteCenterX != null || absoluteCenterY != null) {
      return 'topleft';
    }
    if (rawX != null &&
        rawY != null &&
        rawX >= 0 &&
        rawY >= 0 &&
        rawX <= canvasSize.width &&
        rawY <= canvasSize.height) {
      // External MCP clients commonly emit top-left canvas pixels with raw
      // `x/y` while omitting coordinateSpace.
      return 'topleft';
    }
    return 'centerorigin';
  }

  static double canonicalCoordinateFromRemoteValue(
    double? value, {
    required double axisExtent,
    required String coordinateSpace,
  }) {
    if (value == null) {
      return 0.0;
    }
    final halfExtent = axisExtent / 2.0;
    final space = coordinateSpace.toLowerCase();
    if (space.contains('topleft') ||
        space.contains('absolute') ||
        space.contains('css') ||
        space.contains('canvaspixel')) {
      return value - halfExtent;
    }
    if (space.contains('center')) {
      return value;
    }
    // Legacy MCP payloads have historically mixed absolute `x/y` with the
    // newer center-origin canvas contract. Ambiguous values strictly inside the
    // center-origin range are treated as canonical; boundary values are treated
    // as absolute canvas pixels so Story center payloads like `x=540,y=960`
    // map to canonical center instead of bottom-right edge.
    if (value.abs() < halfExtent) {
      return value;
    }
    return value - halfExtent;
  }
}
