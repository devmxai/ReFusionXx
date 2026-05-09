import 'dart:math' as math;

import 'scene_optical_bounds.dart';

class SceneIconAlignmentMeasurement {
  const SceneIconAlignmentMeasurement({
    required this.expectedCenterX,
    required this.expectedCenterY,
    required this.actualCenterX,
    required this.actualCenterY,
    required this.centerDeltaX,
    required this.centerDeltaY,
    required this.centerDeltaDistance,
    required this.minMarginX,
    required this.minMarginY,
    required this.requiredSafeMarginX,
    required this.requiredSafeMarginY,
    required this.safeZoneSatisfied,
  });

  final double expectedCenterX;
  final double expectedCenterY;
  final double actualCenterX;
  final double actualCenterY;
  final double centerDeltaX;
  final double centerDeltaY;
  final double centerDeltaDistance;
  final double minMarginX;
  final double minMarginY;
  final double requiredSafeMarginX;
  final double requiredSafeMarginY;
  final bool safeZoneSatisfied;
}

class SceneIconAlignmentEngine {
  const SceneIconAlignmentEngine();

  SceneIconAlignmentMeasurement measure({
    required SceneOpticalRect parentRect,
    required SceneOpticalRect iconRect,
    required SceneOpticalBoundsProfile profile,
  }) {
    final opticalScalar = parentRect.minDimension;
    final expectedCenterX =
        parentRect.centerX + (profile.offsetXRatio * opticalScalar);
    final expectedCenterY =
        parentRect.centerY + (profile.offsetYRatio * opticalScalar);
    final deltaX = iconRect.centerX - expectedCenterX;
    final deltaY = iconRect.centerY - expectedCenterY;
    final centerDeltaDistance =
        math.sqrt((deltaX * deltaX) + (deltaY * deltaY));

    final leftMargin = iconRect.left - parentRect.left;
    final rightMargin = parentRect.right - iconRect.right;
    final topMargin = iconRect.top - parentRect.top;
    final bottomMargin = parentRect.bottom - iconRect.bottom;
    final minMarginX = leftMargin < rightMargin ? leftMargin : rightMargin;
    final minMarginY = topMargin < bottomMargin ? topMargin : bottomMargin;

    final requiredSafeMarginX = parentRect.width * profile.safeZoneRatio;
    final requiredSafeMarginY = parentRect.height * profile.safeZoneRatio;
    final safeZoneSatisfied =
        minMarginX >= requiredSafeMarginX && minMarginY >= requiredSafeMarginY;

    return SceneIconAlignmentMeasurement(
      expectedCenterX: expectedCenterX,
      expectedCenterY: expectedCenterY,
      actualCenterX: iconRect.centerX,
      actualCenterY: iconRect.centerY,
      centerDeltaX: deltaX,
      centerDeltaY: deltaY,
      centerDeltaDistance: centerDeltaDistance,
      minMarginX: minMarginX,
      minMarginY: minMarginY,
      requiredSafeMarginX: requiredSafeMarginX,
      requiredSafeMarginY: requiredSafeMarginY,
      safeZoneSatisfied: safeZoneSatisfied,
    );
  }
}
