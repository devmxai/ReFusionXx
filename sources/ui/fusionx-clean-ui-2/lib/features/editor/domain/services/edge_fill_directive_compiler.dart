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
    final baseContentWidth = safeSourceWidth * fitScale;
    final baseContentHeight = safeSourceHeight * fitScale;
    final contentWidth = baseContentWidth * transform.scaleX.abs();
    final contentHeight = baseContentHeight * transform.scaleY.abs();
    final contentLeft = ((safeCanvasWidth - baseContentWidth) / 2.0).clamp(
      0.0,
      safeCanvasWidth,
    );
    final contentTop = ((safeCanvasHeight - baseContentHeight) / 2.0).clamp(
      0.0,
      safeCanvasHeight,
    );
    final contentRight = (contentLeft + baseContentWidth).clamp(
      0.0,
      safeCanvasWidth,
    );
    final contentBottom = (contentTop + baseContentHeight).clamp(
      0.0,
      safeCanvasHeight,
    );
    final sourceRectLeft = (contentLeft / safeCanvasWidth).clamp(0.0, 1.0);
    final sourceRectTop = (contentTop / safeCanvasHeight).clamp(0.0, 1.0);
    final sourceRectRight = (contentRight / safeCanvasWidth).clamp(0.0, 1.0);
    final sourceRectBottom = (contentBottom / safeCanvasHeight).clamp(0.0, 1.0);
    final transformMatrix3x3 = _canvasTransformMatrix3x3(
      canvasWidth: safeCanvasWidth,
      canvasHeight: safeCanvasHeight,
      transform: transform,
    );
    final inverseTransformMatrix3x3 = _inverseAffine3x3(transformMatrix3x3) ??
        const <double>[
          1.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          0.0,
          0.0,
          1.0,
        ];
    final cosTheta = math.cos(transform.rotationRadians).abs();
    final sinTheta = math.sin(transform.rotationRadians).abs();
    final rotatedWidth = (contentWidth * cosTheta) + (contentHeight * sinTheta);
    final rotatedHeight =
        (contentWidth * sinTheta) + (contentHeight * cosTheta);
    final coverageScale = math.max(
      safeCanvasWidth / math.max(1.0, rotatedWidth),
      safeCanvasHeight / math.max(1.0, rotatedHeight),
    );
    final maxOverscanScale = math.max(1.0, policy.maxExpansionPx / 100.0);
    final overscanScale = math.max(
      coverageScale.clamp(1.0, maxOverscanScale).toDouble(),
      policy.overscanScale.clamp(1.0, maxOverscanScale).toDouble(),
    );
    final hasAffectedRotation = policy.affectRotation &&
        _hasMeaningfulRotation(transform.rotationRadians);
    final hasAffectedScale =
        policy.affectScale && _hasMeaningfulScaleGap(transform);
    final hasAffectedPosition =
        policy.affectPosition && _hasMeaningfulPositionGap(transform);
    final hasExplicitExpansion = policy.overscanScale > 1.0001;
    final hasMeaningfulGap = hasAffectedRotation ||
        hasAffectedScale ||
        hasAffectedPosition ||
        hasExplicitExpansion;
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
    final activeOverscanScale = math.max(overscanScale, 1.0002);
    final clampedBlurSigma = policy.blurSigmaPx.clamp(0.0, 40.0);
    final clampedSoftness = policy.softnessPx.clamp(0.0, 64.0);
    return Stage5VisualRuntimeEdgeFillDirective(
      enabled: true,
      mode: policy.mode.name,
      amount: policy.amount.clamp(0.0, 1.0),
      overscanScale: activeOverscanScale,
      softnessPx: clampedSoftness,
      blurSigmaPx: clampedBlurSigma,
      sourceRectLeft: sourceRectLeft,
      sourceRectTop: sourceRectTop,
      sourceRectRight: sourceRectRight,
      sourceRectBottom: sourceRectBottom,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      canvasWidth: safeCanvasWidth,
      canvasHeight: safeCanvasHeight,
      maxExpansionPx: policy.maxExpansionPx,
      quality: quality.name,
      transformMatrix3x3: transformMatrix3x3,
      inverseTransformMatrix3x3: inverseTransformMatrix3x3,
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
      transformMatrix3x3: const <double>[
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ],
      inverseTransformMatrix3x3: const <double>[
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ],
      fallbackReason: fallbackReason,
    );
  }

  bool _hasMeaningfulRotation(double rotationRadians) {
    final tau = math.pi * 2.0;
    final normalized = ((rotationRadians % tau) + tau) % tau;
    final distanceToIdentity = math.min(normalized, (tau - normalized).abs());
    return distanceToIdentity > 0.0005;
  }

  bool _hasMeaningfulScaleGap(LiveScrubSurfaceTransform transform) {
    return transform.scaleX.abs() < 0.999 || transform.scaleY.abs() < 0.999;
  }

  bool _hasMeaningfulPositionGap(LiveScrubSurfaceTransform transform) {
    return transform.positionX.abs() > 0.5 || transform.positionY.abs() > 0.5;
  }

  List<double> _canvasTransformMatrix3x3({
    required double canvasWidth,
    required double canvasHeight,
    required LiveScrubSurfaceTransform transform,
  }) {
    final cx = canvasWidth / 2.0;
    final cy = canvasHeight / 2.0;
    final cosTheta = math.cos(transform.rotationRadians);
    final sinTheta = math.sin(transform.rotationRadians);
    final a = transform.scaleX * cosTheta;
    final b = -transform.scaleY * sinTheta;
    final c = transform.scaleX * sinTheta;
    final d = transform.scaleY * cosTheta;
    final tx = transform.positionX + cx - (a * cx) - (b * cy);
    final ty = transform.positionY + cy - (c * cx) - (d * cy);
    return <double>[
      a,
      b,
      tx,
      c,
      d,
      ty,
      0.0,
      0.0,
      1.0,
    ];
  }

  List<double>? _inverseAffine3x3(List<double> matrix) {
    if (matrix.length < 6) {
      return null;
    }
    final a = matrix[0];
    final b = matrix[1];
    final tx = matrix[2];
    final c = matrix[3];
    final d = matrix[4];
    final ty = matrix[5];
    final det = (a * d) - (b * c);
    if (!det.isFinite || det.abs() < 1e-9) {
      return null;
    }
    final invDet = 1.0 / det;
    final ia = d * invDet;
    final ib = -b * invDet;
    final ic = -c * invDet;
    final id = a * invDet;
    final itx = ((b * ty) - (d * tx)) * invDet;
    final ity = ((c * tx) - (a * ty)) * invDet;
    return <double>[
      ia,
      ib,
      itx,
      ic,
      id,
      ity,
      0.0,
      0.0,
      1.0,
    ];
  }
}
