import 'package:flutter/foundation.dart';

enum SceneCoordinateSpace {
  centerOriginV1,
  viewportTopLeftV1,
}

@immutable
class SceneCanvasMetrics {
  const SceneCanvasMetrics({
    required this.width,
    required this.height,
  })  : assert(width > 0),
        assert(height > 0);

  final double width;
  final double height;

  double get centerX => width / 2.0;
  double get centerY => height / 2.0;
}

@immutable
class ScenePoint {
  const ScenePoint({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
}

@immutable
class SceneRectCenter {
  const SceneRectCenter({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  })  : assert(width >= 0),
        assert(height >= 0);

  final double centerX;
  final double centerY;
  final double width;
  final double height;

  double get left => centerX - (width / 2.0);
  double get top => centerY - (height / 2.0);
  double get right => left + width;
  double get bottom => top + height;

  bool contains(SceneRectCenter child) {
    return child.left >= left &&
        child.top >= top &&
        child.right <= right &&
        child.bottom <= bottom;
  }
}

@immutable
class SceneViewportPoint {
  const SceneViewportPoint({
    required this.left,
    required this.top,
  });

  final double left;
  final double top;
}

@immutable
class SceneViewportRect {
  const SceneViewportRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  })  : assert(width >= 0),
        assert(height >= 0);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool contains(SceneViewportRect child) {
    return child.left >= left &&
        child.top >= top &&
        child.right <= right &&
        child.bottom <= bottom;
  }
}

class SceneCoordinateSystem {
  const SceneCoordinateSystem._();

  static const SceneCoordinateSpace canonical =
      SceneCoordinateSpace.centerOriginV1;

  static SceneViewportPoint centerToViewportPoint({
    required ScenePoint point,
    required SceneCanvasMetrics canvas,
  }) {
    return SceneViewportPoint(
      left: canvas.centerX + point.x,
      top: canvas.centerY + point.y,
    );
  }

  static ScenePoint viewportToCenterPoint({
    required SceneViewportPoint point,
    required SceneCanvasMetrics canvas,
  }) {
    return ScenePoint(
      x: point.left - canvas.centerX,
      y: point.top - canvas.centerY,
    );
  }

  static SceneRectCenter rectFromCenter({
    required ScenePoint center,
    required double width,
    required double height,
  }) {
    return SceneRectCenter(
      centerX: center.x,
      centerY: center.y,
      width: width,
      height: height,
    );
  }

  static SceneViewportRect centerRectToViewportRect({
    required SceneRectCenter rect,
    required SceneCanvasMetrics canvas,
  }) {
    final centerPoint = centerToViewportPoint(
      point: ScenePoint(
        x: rect.centerX,
        y: rect.centerY,
      ),
      canvas: canvas,
    );
    return SceneViewportRect(
      left: centerPoint.left - (rect.width / 2.0),
      top: centerPoint.top - (rect.height / 2.0),
      width: rect.width,
      height: rect.height,
    );
  }

  static SceneRectCenter viewportRectToCenterRect({
    required SceneViewportRect rect,
    required SceneCanvasMetrics canvas,
  }) {
    final center = viewportToCenterPoint(
      point: SceneViewportPoint(
        left: rect.left + (rect.width / 2.0),
        top: rect.top + (rect.height / 2.0),
      ),
      canvas: canvas,
    );
    return SceneRectCenter(
      centerX: center.x,
      centerY: center.y,
      width: rect.width,
      height: rect.height,
    );
  }

  static bool containsRectCenter({
    required SceneRectCenter parent,
    required SceneRectCenter child,
  }) {
    return parent.contains(child);
  }

  static bool containsRectViewport({
    required SceneViewportRect parent,
    required SceneViewportRect child,
  }) {
    return parent.contains(child);
  }
}
