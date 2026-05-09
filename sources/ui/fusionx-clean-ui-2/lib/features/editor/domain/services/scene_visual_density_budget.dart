class SceneVisualDensityBudget {
  const SceneVisualDensityBudget({
    this.minCoverage = 0.24,
    this.maxCoverage = 0.74,
    this.hardMinCoverage = 0.16,
    this.hardMaxCoverage = 0.86,
  });

  final double minCoverage;
  final double maxCoverage;
  final double hardMinCoverage;
  final double hardMaxCoverage;
}

class SceneVisualDensityEvaluation {
  const SceneVisualDensityEvaluation({
    required this.coverageRatio,
    required this.withinRecommendedRange,
    required this.withinHardRange,
  });

  final double coverageRatio;
  final bool withinRecommendedRange;
  final bool withinHardRange;
}
