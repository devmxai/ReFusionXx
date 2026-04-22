import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_motion_animation_models.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_evaluation_models.dart';
import 'professional_motion_models.dart';
import 'professional_motion_text_models.dart';
import 'professional_motion_text_preview_models.dart';

const int kMotionTextCanonicalColorArgb = 0xFFF3F3F3;
const String kMotionTextCanonicalFontStyle = 'normal';
const int kMotionTextCanonicalFontWeight = 700;
const double kMotionTextCanonicalLineHeight = 1.0;
const String kMotionTextCanonicalTextAlignment = 'center';
const String kMotionTextCanonicalAnchor = 'center';
const String? kMotionTextCanonicalFontFamily = null;

@immutable
class MotionTextRenderNode {
  MotionTextRenderNode({
    required this.id,
    required this.targetElementId,
    required this.sceneId,
    required this.layerId,
    required this.projectRange,
    required this.isActive,
    required this.text,
    required this.fullText,
    required this.revealUnit,
    required this.revealProgress,
    required this.hasRevealAnimation,
    required List<MotionTextAnimationKind> animationKinds,
    required Map<MotionTextAnimationKind, double> animationProgressByKind,
    required this.canvasOffset,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDegrees,
    required this.opacity,
    required this.blurAmount,
    this.blurHorizontal = 100,
    this.blurVertical = 100,
    this.blurMix = 100,
    this.blurEdgeMode = 0,
    this.blurCrop = 0,
    required this.fontSize,
    required this.letterSpacing,
    required this.colorArgb,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
    required this.lineHeight,
    required this.textAlignment,
    required this.anchor,
    required this.blendMode,
    required this.zIndex,
    this.name,
    this.presetId,
  })  : animationKinds = List.unmodifiable(animationKinds),
        animationProgressByKind = Map.unmodifiable(animationProgressByKind);

  final String id;
  final String targetElementId;
  final String sceneId;
  final String layerId;
  final TimelineTimeRange projectRange;
  final bool isActive;
  final String text;
  final String fullText;
  final MotionTextRevealUnit revealUnit;
  final double? revealProgress;
  final bool hasRevealAnimation;
  final List<MotionTextAnimationKind> animationKinds;
  final Map<MotionTextAnimationKind, double> animationProgressByKind;
  final MotionPoint2D canvasOffset;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;
  final double opacity;
  final double blurAmount;
  final double blurHorizontal;
  final double blurVertical;
  final double blurMix;
  final double blurEdgeMode;
  final double blurCrop;
  final double fontSize;
  final double letterSpacing;
  final int colorArgb;
  final String? fontFamily;
  final int fontWeight;
  final String fontStyle;
  final double lineHeight;
  final String textAlignment;
  final String anchor;
  final MotionBlendMode blendMode;
  final int zIndex;
  final String? name;
  final String? presetId;
}

@immutable
class MotionTextRenderSnapshot {
  MotionTextRenderSnapshot({
    required this.projectId,
    required this.time,
    required this.canvasSize,
    required List<MotionTextRenderNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final String projectId;
  final TimelineTime time;
  final MotionSize2D canvasSize;
  final List<MotionTextRenderNode> nodes;
}

abstract class MotionTextRenderAdapter {
  const MotionTextRenderAdapter();

  MotionTextRenderSnapshot adapt({
    required MotionNormalizedComposition composition,
    required MotionTextPreviewSnapshot preview,
  });
}

class BasicMotionTextRenderAdapter implements MotionTextRenderAdapter {
  const BasicMotionTextRenderAdapter({
    this.defaultTextColorArgb = kMotionTextCanonicalColorArgb,
  });

  final int defaultTextColorArgb;

  @override
  MotionTextRenderSnapshot adapt({
    required MotionNormalizedComposition composition,
    required MotionTextPreviewSnapshot preview,
  }) {
    final presetCatalog = <String, MotionTextPresetDefinition>{
      for (final preset in MotionBuiltInTextPresets.all) preset.id: preset,
    };
    final textAnimationsById = <String, MotionResolvedTextAnimationModel>{
      for (final animation in composition.textAnimations)
        animation.id: animation,
    };
    final nodes = preview.nodes
        .map(
          (node) => MotionTextRenderNode(
            id: node.id,
            targetElementId: node.targetElementId,
            sceneId: node.sceneId,
            layerId: node.layerId,
            projectRange: node.projectRange,
            isActive: node.activationState == MotionActivationState.active,
            text: node.visibleText,
            fullText: node.fullText,
            revealUnit: node.revealUnit,
            revealProgress: node.revealProgress,
            hasRevealAnimation: node.animationKinds.any(
              (kind) =>
                  kind == MotionTextAnimationKind.wordReveal ||
                  kind == MotionTextAnimationKind.letterReveal ||
                  kind == MotionTextAnimationKind.typewriter,
            ),
            animationKinds: node.animationKinds,
            animationProgressByKind: _resolveAnimationProgressByKind(
              textAnimation: node.textAnimationId == null
                  ? null
                  : textAnimationsById[node.textAnimationId!],
              time: preview.time,
              presetCatalog: presetCatalog,
            ),
            canvasOffset: MotionPoint2D(
              x: node.transform.positionX,
              y: node.transform.positionY,
            ),
            scaleX: node.transform.scaleX,
            scaleY: node.transform.scaleY,
            rotationDegrees: node.transform.rotationDegrees,
            opacity: node.style.opacity.clamp(0.0, 1.0),
            blurAmount: node.style.blurAmount < 0 ? 0 : node.style.blurAmount,
            blurHorizontal: node.style.blurHorizontal.clamp(0.0, 100.0),
            blurVertical: node.style.blurVertical.clamp(0.0, 100.0),
            blurMix: node.style.blurMix.clamp(0.0, 100.0),
            blurEdgeMode: node.style.blurEdgeMode.clamp(0.0, 2.0),
            blurCrop: node.style.blurCrop.clamp(0.0, 1.0),
            fontSize: node.style.fontSize <= 0 ? 16 : node.style.fontSize,
            letterSpacing: node.style.letterSpacing,
            colorArgb: defaultTextColorArgb,
            fontFamily: kMotionTextCanonicalFontFamily,
            fontWeight: kMotionTextCanonicalFontWeight,
            fontStyle: kMotionTextCanonicalFontStyle,
            lineHeight: kMotionTextCanonicalLineHeight,
            textAlignment: kMotionTextCanonicalTextAlignment,
            anchor: kMotionTextCanonicalAnchor,
            blendMode: node.blendMode,
            zIndex: node.zIndex,
            name: node.name,
            presetId: node.presetId,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) {
        final zOrder = left.zIndex.compareTo(right.zIndex);
        if (zOrder != 0) {
          return zOrder;
        }
        return left.targetElementId.compareTo(right.targetElementId);
      });

    return MotionTextRenderSnapshot(
      projectId: preview.projectId,
      time: preview.time,
      canvasSize: composition.format.canvasSize,
      nodes: nodes,
    );
  }

  Map<MotionTextAnimationKind, double> _resolveAnimationProgressByKind({
    required MotionResolvedTextAnimationModel? textAnimation,
    required TimelineTime time,
    required Map<String, MotionTextPresetDefinition> presetCatalog,
  }) {
    if (textAnimation == null) {
      return const <MotionTextAnimationKind, double>{};
    }
    final preset = textAnimation.presetId == null
        ? null
        : presetCatalog[textAnimation.presetId!];
    final blocks = textAnimation.animationBlocks.isNotEmpty
        ? textAnimation.animationBlocks
        : <MotionResolvedTextAnimationBlockModel>[
            if (preset != null)
              ...preset.animationBlocks.map(
                (block) => MotionResolvedTextAnimationBlockModel(
                  id: block.id,
                  kind: block.kind,
                  projectRange: TimelineTimeRange(
                    start: textAnimation.projectRange.start +
                        block.relativeRange.start,
                    endExclusive: textAnimation.projectRange.start +
                        block.relativeRange.endExclusive,
                  ),
                  interpolation: block.interpolation,
                  revealSpec: block.revealSpec,
                  parameters: block.parameters,
                ),
              ),
          ];
    final progressByKind = <MotionTextAnimationKind, double>{};
    for (final block in blocks) {
      if (!block.projectRange.contains(time)) {
        continue;
      }
      final rawProgress = _normalizedProgress(
        block.projectRange.start,
        block.projectRange.endExclusive,
        time,
      );
      final curvedProgress =
          _curveProgress(block.interpolation, rawProgress).clamp(0.0, 1.0);
      final previousProgress = progressByKind[block.kind];
      if (previousProgress == null || curvedProgress > previousProgress) {
        progressByKind[block.kind] = curvedProgress;
      }
    }
    return progressByKind;
  }

  double _normalizedProgress(
    TimelineTime start,
    TimelineTime end,
    TimelineTime current,
  ) {
    final durationTicks = (end - start).inProjectTicks;
    if (durationTicks <= 0) {
      return 0;
    }
    final elapsedTicks = (current - start).inProjectTicks;
    return elapsedTicks / durationTicks;
  }

  double _curveProgress(
    MotionInterpolationSpec interpolation,
    double progress,
  ) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    switch (interpolation.kind) {
      case MotionInterpolationKind.hold:
        return 0;
      case MotionInterpolationKind.linear:
      case MotionInterpolationKind.spring:
      case MotionInterpolationKind.bounce:
      case MotionInterpolationKind.elastic:
        return clampedProgress;
      case MotionInterpolationKind.cubicBezier:
        final bezier = interpolation.bezier;
        if (bezier == null) {
          return clampedProgress;
        }
        return _solveCubicBezierProgress(bezier, clampedProgress);
      case MotionInterpolationKind.easeIn:
        return clampedProgress * clampedProgress;
      case MotionInterpolationKind.easeOut:
        final inverse = 1 - clampedProgress;
        return 1 - (inverse * inverse);
      case MotionInterpolationKind.easeInOut:
        if (clampedProgress < 0.5) {
          return 2 * clampedProgress * clampedProgress;
        }
        final inverse = -2 * clampedProgress + 2;
        return 1 - ((inverse * inverse) / 2);
    }
  }

  double _solveCubicBezierProgress(
    MotionBezierControlPoints bezier,
    double x,
  ) {
    final clampedX = x.clamp(0.0, 1.0).toDouble();
    if (clampedX <= 0.0 || clampedX >= 1.0) {
      return clampedX;
    }
    var t = clampedX;
    for (var iteration = 0; iteration < 8; iteration += 1) {
      final estimate = _cubicCoordinate(t, 0.0, bezier.x1, bezier.x2, 1.0);
      final derivative = _cubicDerivative(t, 0.0, bezier.x1, bezier.x2, 1.0);
      final delta = estimate - clampedX;
      if (delta.abs() <= 0.000001 || derivative.abs() <= 0.000001) {
        break;
      }
      t = (t - (delta / derivative)).clamp(0.0, 1.0).toDouble();
    }
    var lower = 0.0;
    var upper = 1.0;
    for (var iteration = 0; iteration < 12; iteration += 1) {
      final estimate = _cubicCoordinate(t, 0.0, bezier.x1, bezier.x2, 1.0);
      if ((estimate - clampedX).abs() <= 0.000001) {
        break;
      }
      if (estimate < clampedX) {
        lower = t;
      } else {
        upper = t;
      }
      t = ((lower + upper) * 0.5).clamp(0.0, 1.0).toDouble();
    }
    return _cubicCoordinate(t, 0.0, bezier.y1, bezier.y2, 1.0)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _cubicCoordinate(
    double t,
    double p0,
    double p1,
    double p2,
    double p3,
  ) {
    final inverse = 1.0 - t;
    return (inverse * inverse * inverse * p0) +
        (3.0 * inverse * inverse * t * p1) +
        (3.0 * inverse * t * t * p2) +
        (t * t * t * p3);
  }

  double _cubicDerivative(
    double t,
    double p0,
    double p1,
    double p2,
    double p3,
  ) {
    final inverse = 1.0 - t;
    return (3.0 * inverse * inverse * (p1 - p0)) +
        (6.0 * inverse * t * (p2 - p1)) +
        (3.0 * t * t * (p3 - p2));
  }
}
