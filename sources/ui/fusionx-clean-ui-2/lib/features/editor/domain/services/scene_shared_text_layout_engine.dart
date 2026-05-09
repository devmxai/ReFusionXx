import 'dart:math' as math;

import 'scene_shared_text_layout_models.dart';

class SceneSharedTextLayoutEngine {
  const SceneSharedTextLayoutEngine();

  static const String proofTag = 'TF_SCENE_TEXT_LAYOUT_PROOF';

  SceneSharedTextLayoutResult layout(SceneSharedTextLayoutRequest request) {
    final normalizedFitPolicy = _normalize(request.fitPolicy);
    final safeFrameWidth = math.max(1.0, request.frameWidth);
    final safeFrameHeight = math.max(1.0, request.frameHeight);
    final safeLineHeight = math.max(1.0, request.lineHeight);
    final maxLines = math.max(1, request.maxLines);
    final text = request.text.trim();
    final glyphCount = text.runes.length;

    double measuredWidth(double fontSize) =>
        (_glyphWidth(fontSize) * glyphCount) +
        (math.max(0, glyphCount - 1) * request.letterSpacing);

    int estimatedLinesForWidth(double width) =>
        math.max(1, (width / safeFrameWidth).ceil());

    double measuredHeightFor(int lines, double fontSize) =>
        math.max(1, lines) * fontSize * safeLineHeight;

    var effectiveFontSize = request.fontSize;
    var width = measuredWidth(effectiveFontSize);
    var lines = estimatedLinesForWidth(width);
    var height = measuredHeightFor(lines, effectiveFontSize);

    if (normalizedFitPolicy == 'shrinktofit') {
      while ((width > safeFrameWidth || height > safeFrameHeight) &&
          effectiveFontSize > request.minFontSize) {
        effectiveFontSize -= 1.0;
        width = measuredWidth(effectiveFontSize);
        lines = estimatedLinesForWidth(width);
        height = measuredHeightFor(lines, effectiveFontSize);
      }
    } else if (normalizedFitPolicy == 'wraptolines' ||
        normalizedFitPolicy == 'ellipsisaftermaxlines') {
      lines = math.min(maxLines, estimatedLinesForWidth(width));
      height = measuredHeightFor(lines, effectiveFontSize);
    }

    final overflowX = math.max(0.0, width - safeFrameWidth);
    final overflowY = math.max(0.0, height - safeFrameHeight);
    final overflowPx = math.max(overflowX, overflowY);
    final fitsByGeometry = overflowPx <= 1.0;
    final fitsByPolicy = _fitsByPolicy(
      normalizedFitPolicy: normalizedFitPolicy,
      lines: lines,
      maxLines: maxLines,
      overflowPx: overflowPx,
    );
    final policyAllowsOverflow = normalizedFitPolicy == 'cliptoframe' ||
        normalizedFitPolicy == 'shorten' ||
        normalizedFitPolicy == 'scalexfornumericonly';
    return SceneSharedTextLayoutResult(
      effectiveFontSize: effectiveFontSize,
      measuredWidth: width,
      measuredHeight: height,
      estimatedLines: lines,
      fits: fitsByGeometry || fitsByPolicy || policyAllowsOverflow,
      overflowPx: overflowPx,
      policyAllowsOverflow: policyAllowsOverflow,
      normalizedFitPolicy: normalizedFitPolicy,
    );
  }

  bool _fitsByPolicy({
    required String normalizedFitPolicy,
    required int lines,
    required int maxLines,
    required double overflowPx,
  }) {
    if (normalizedFitPolicy == 'wraptolines') {
      return lines <= maxLines && overflowPx <= 1.0;
    }
    if (normalizedFitPolicy == 'ellipsisaftermaxlines') {
      return lines <= maxLines;
    }
    if (normalizedFitPolicy == 'cliptoframe' ||
        normalizedFitPolicy == 'shorten' ||
        normalizedFitPolicy == 'scalexfornumericonly') {
      return true;
    }
    return overflowPx <= 1.0;
  }

  double _glyphWidth(double fontSize) {
    return fontSize * 0.56;
  }

  String _normalize(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();
  }
}
