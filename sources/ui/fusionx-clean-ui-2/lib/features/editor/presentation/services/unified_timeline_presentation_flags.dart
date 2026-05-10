enum UnifiedTimelinePresentationRolloutMode {
  off,
  internal,
  beta,
  stable,
}

class UnifiedTimelinePresentationFlags {
  const UnifiedTimelinePresentationFlags._();

  // Rollout remains disabled by default for safety.
  static const UnifiedTimelinePresentationRolloutMode rolloutMode =
      UnifiedTimelinePresentationRolloutMode.off;

  // Backward-compatible flag used by existing wiring.
  static const bool unifiedTimelinePresentationLayer =
      rolloutMode != UnifiedTimelinePresentationRolloutMode.off;

  static const bool unifiedTimelineInternalBuild =
      rolloutMode == UnifiedTimelinePresentationRolloutMode.internal;
  static const bool unifiedTimelineBetaBuild =
      rolloutMode == UnifiedTimelinePresentationRolloutMode.beta;
  static const bool unifiedTimelineStableBuild =
      rolloutMode == UnifiedTimelinePresentationRolloutMode.stable;
}
