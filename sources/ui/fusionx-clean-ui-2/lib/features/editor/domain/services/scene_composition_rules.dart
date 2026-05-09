import 'dart:math' as math;

class SceneCompositionRules {
  const SceneCompositionRules({
    required this.safeInsetHorizontalFactor,
    required this.safeInsetTopFactor,
    required this.safeInsetBottomFactor,
    required this.featureAreaTopFactor,
    required this.featureAreaBottomFactor,
    required this.baseSpacing,
    required this.cardCornerRadius,
    required this.maxGridColumns,
  });

  final double safeInsetHorizontalFactor;
  final double safeInsetTopFactor;
  final double safeInsetBottomFactor;
  final double featureAreaTopFactor;
  final double featureAreaBottomFactor;
  final double baseSpacing;
  final double cardCornerRadius;
  final int maxGridColumns;

  double spacingForCanvas({
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final minSide = math.min(canvasWidth, canvasHeight);
    return (minSide * baseSpacing).clamp(20.0, 44.0);
  }

  static SceneCompositionRules forCanvas({
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final ratio = canvasWidth / canvasHeight;
    if (ratio >= 1.65) {
      return const SceneCompositionRules(
        safeInsetHorizontalFactor: 0.06,
        safeInsetTopFactor: 0.09,
        safeInsetBottomFactor: 0.08,
        featureAreaTopFactor: 0.35,
        featureAreaBottomFactor: 0.90,
        baseSpacing: 0.023,
        cardCornerRadius: 30.0,
        maxGridColumns: 2,
      );
    }
    if (ratio >= 0.95 && ratio <= 1.05) {
      return const SceneCompositionRules(
        safeInsetHorizontalFactor: 0.08,
        safeInsetTopFactor: 0.09,
        safeInsetBottomFactor: 0.08,
        featureAreaTopFactor: 0.34,
        featureAreaBottomFactor: 0.90,
        baseSpacing: 0.024,
        cardCornerRadius: 32.0,
        maxGridColumns: 2,
      );
    }
    if (ratio >= 0.78 && ratio <= 0.82) {
      return const SceneCompositionRules(
        safeInsetHorizontalFactor: 0.075,
        safeInsetTopFactor: 0.08,
        safeInsetBottomFactor: 0.08,
        featureAreaTopFactor: 0.33,
        featureAreaBottomFactor: 0.90,
        baseSpacing: 0.023,
        cardCornerRadius: 34.0,
        maxGridColumns: 2,
      );
    }
    return const SceneCompositionRules(
      safeInsetHorizontalFactor: 0.08,
      safeInsetTopFactor: 0.07,
      safeInsetBottomFactor: 0.07,
      featureAreaTopFactor: 0.33,
      featureAreaBottomFactor: 0.90,
      baseSpacing: 0.024,
      cardCornerRadius: 36.0,
      maxGridColumns: 2,
    );
  }
}
