import 'dart:math' as math;

import '../../../../core/engine/stage5_visual_runtime_state.dart';
import '../models/master_live_scrub_visual_program_models.dart';
import '../models/master_visual_program_models.dart';

enum EdgeFillDirectiveQuality {
  liveScrub,
  playback,
  preview,
  export,
}

class EdgeFillDirectiveCompiler {
  const EdgeFillDirectiveCompiler();

  Stage5VisualRuntimeEdgeFillDirective compile({
    required MasterEdgeFillPolicy policy,
    required LiveScrubSurfaceTransform transform,
    required EdgeFillDirectiveQuality quality,
    required double canvasWidth,
    required double canvasHeight,
    required double? sourceWidth,
    required double? sourceHeight,
    required bool requiresFullCanvasCoverage,
  }) {
    if (!policy.enabled || !requiresFullCanvasCoverage) {
      return _disabledDirective(
        policy: policy,
        quality: quality,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        fallbackReason: !requiresFullCanvasCoverage
            ? 'edge_fill_context_not_full_canvas'
            : 'edge_fill_disabled',
      );
    }
    final safeSourceWidth = sourceWidth ?? 0.0;
    final safeSourceHeight = sourceHeight ?? 0.0;
    if (safeSourceWidth <= 1.0 || safeSourceHeight <= 1.0) {
      return _disabledDirective(
        policy: policy,
        quality: quality,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        fallbackReason: 'edge_fill_source_dimensions_missing',
      );
    }
    final safeCanvasWidth = canvasWidth.clamp(1.0, 32768.0);
    final safeCanvasHeight = canvasHeight.clamp(1.0, 32768.0);
    final fitScale = math.min(
      safeCanvasWidth / safeSourceWidth,
      safeCanvasHeight / safeSourceHeight,
    );
    final contentWidth = safeSourceWidth * fitScale * transform.scaleX.abs();
    final contentHeight = safeSourceHeight * fitScale * transform.scaleY.abs();
    final cosTheta = math.cos(transform.rotationRadians).abs();
    final sinTheta = math.sin(transform.rotationRadians).abs();
    final rotatedWidth = (contentWidth * cosTheta) + (contentHeight * sinTheta);
    final rotatedHeight =
        (contentWidth * sinTheta) + (contentHeight * cosTheta);
    final coverageScale = math.max(
      safeCanvasWidth / math.max(1.0, rotatedWidth),
      safeCanvasHeight / math.max(1.0, rotatedHeight),
    );
    final overscanScale =
        coverageScale.clamp(1.0, math.max(1.0, policy.maxExpansionPx / 100.0));
    final hasMeaningfulGap = overscanScale > 1.01;
    if (!hasMeaningfulGap) {
      return _disabledDirective(
        policy: policy,
        quality: quality,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        fallbackReason: 'edge_fill_bounds_already_covered',
      );
    }
    final clampedBlurSigma = policy.blurSigmaPx.clamp(0.0, 40.0);
    final clampedSoftness = policy.softnessPx.clamp(0.0, 64.0);
    return Stage5VisualRuntimeEdgeFillDirective(
      enabled: true,
      mode: policy.mode.name,
      amount: policy.amount.clamp(0.0, 1.0),
      overscanScale: math.max(
        overscanScale.toDouble(),
        policy.overscanScale.toDouble(),
      ),
      softnessPx: clampedSoftness,
      blurSigmaPx: clampedBlurSigma,
      sourceRectLeft: 0.0,
      sourceRectTop: 0.0,
      sourceRectRight: 1.0,
      sourceRectBottom: 1.0,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      canvasWidth: safeCanvasWidth,
      canvasHeight: safeCanvasHeight,
      maxExpansionPx: policy.maxExpansionPx,
      quality: quality.name,
      fallbackReason: null,
    );
  }

  Stage5VisualRuntimeEdgeFillDirective _disabledDirective({
    required MasterEdgeFillPolicy policy,
    required EdgeFillDirectiveQuality quality,
    required double canvasWidth,
    required double canvasHeight,
    required double? sourceWidth,
    required double? sourceHeight,
    required String fallbackReason,
  }) {
    return Stage5VisualRuntimeEdgeFillDirective(
      enabled: false,
      mode: policy.mode.name,
      amount: policy.amount.clamp(0.0, 1.0),
      overscanScale: 1.0,
      softnessPx: 0.0,
      blurSigmaPx: 0.0,
      sourceRectLeft: 0.0,
      sourceRectTop: 0.0,
      sourceRectRight: 1.0,
      sourceRectBottom: 1.0,
      contentWidth: (sourceWidth ?? 0.0).clamp(0.0, 32768.0),
      contentHeight: (sourceHeight ?? 0.0).clamp(0.0, 32768.0),
      canvasWidth: canvasWidth.clamp(1.0, 32768.0),
      canvasHeight: canvasHeight.clamp(1.0, 32768.0),
      maxExpansionPx: policy.maxExpansionPx,
      quality: quality.name,
      fallbackReason: fallbackReason,
    );
  }
}
