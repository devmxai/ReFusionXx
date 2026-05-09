class SceneSharedTextLayoutRequest {
  const SceneSharedTextLayoutRequest({
    required this.text,
    required this.frameWidth,
    required this.frameHeight,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.maxLines,
    required this.fitPolicy,
    this.minFontSize = 12.0,
  });

  final String text;
  final double frameWidth;
  final double frameHeight;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final int maxLines;
  final String fitPolicy;
  final double minFontSize;
}

class SceneSharedTextLayoutResult {
  const SceneSharedTextLayoutResult({
    required this.effectiveFontSize,
    required this.measuredWidth,
    required this.measuredHeight,
    required this.estimatedLines,
    required this.fits,
    required this.overflowPx,
    required this.policyAllowsOverflow,
    required this.normalizedFitPolicy,
  });

  final double effectiveFontSize;
  final double measuredWidth;
  final double measuredHeight;
  final int estimatedLines;
  final bool fits;
  final double overflowPx;
  final bool policyAllowsOverflow;
  final String normalizedFitPolicy;
}
