import 'dart:math' as math;

import '../models/refusion_motion_director_models.dart';
import 'scene_composition_rules.dart';
import 'scene_visual_density_budget.dart';

const String kSceneCompositionSolverProofTag =
    'TF_SCENE_COMPOSITION_SOLVER_PROOF';

class SceneCompositionRect {
  const SceneCompositionRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + (width / 2);
  double get centerY => top + (height / 2);
}

class SceneCompositionCardFrame {
  const SceneCompositionCardFrame({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.cornerRadius,
    required this.iconSize,
    required this.labelFontSize,
    required this.bodyFontSize,
    required this.labelFrameWidth,
    required this.bodyFrameWidth,
    required this.bodyFrameHeight,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final double cornerRadius;
  final double iconSize;
  final double labelFontSize;
  final double bodyFontSize;
  final double labelFrameWidth;
  final double bodyFrameWidth;
  final double bodyFrameHeight;
}

class SceneCompositionSolution {
  const SceneCompositionSolution({
    required this.safeArea,
    required this.titleY,
    required this.subtitleY,
    required this.promptCenterY,
    required this.featureCards,
    required this.spacing,
    required this.issues,
  });

  final SceneCompositionRect safeArea;
  final double titleY;
  final double subtitleY;
  final double promptCenterY;
  final List<SceneCompositionCardFrame> featureCards;
  final double spacing;
  final List<ReFusionMotionDirectorIssue> issues;
}

class SceneCompositionSolver {
  const SceneCompositionSolver({
    SceneVisualDensityBudget densityBudget = const SceneVisualDensityBudget(),
  }) : _densityBudget = densityBudget;

  final SceneVisualDensityBudget _densityBudget;

  SceneCompositionSolution solve({
    required double canvasWidth,
    required double canvasHeight,
    required int featureCardCount,
  }) {
    final rules = SceneCompositionRules.forCanvas(
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
    final spacing = rules.spacingForCanvas(
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
    final safeArea = SceneCompositionRect(
      left: canvasWidth * rules.safeInsetHorizontalFactor,
      top: canvasHeight * rules.safeInsetTopFactor,
      width: canvasWidth * (1.0 - (rules.safeInsetHorizontalFactor * 2.0)),
      height: canvasHeight *
          (1.0 - rules.safeInsetTopFactor - rules.safeInsetBottomFactor),
    );
    final titleY = -(canvasHeight * 0.31);
    final subtitleY = -(canvasHeight * 0.22);
    final promptCenterY = -(canvasHeight * 0.03);
    final featureAreaTop = canvasHeight * rules.featureAreaTopFactor;
    final featureAreaBottom = canvasHeight * rules.featureAreaBottomFactor;
    final featureAreaHeight =
        math.max(180.0, featureAreaBottom - featureAreaTop);

    final cardCount = featureCardCount.clamp(0, 12);
    final cards = <SceneCompositionCardFrame>[];
    final issues = <ReFusionMotionDirectorIssue>[];
    if (cardCount > 0) {
      final columns = cardCount >= 4 ? math.min(rules.maxGridColumns, 2) : 1;
      final rows = (cardCount / columns).ceil();

      final horizontalGap = spacing;
      final verticalGap = spacing;
      final availableWidth = safeArea.width - ((columns - 1) * horizontalGap);
      final availableHeight = featureAreaHeight - ((rows - 1) * verticalGap);
      final cardWidth = (availableWidth / columns).clamp(
        canvasWidth * 0.23,
        canvasWidth * 0.44,
      );
      final cardHeight = (availableHeight / rows).clamp(
        canvasHeight * 0.11,
        canvasHeight * 0.22,
      );
      final contentLeft = safeArea.left +
          math.max(
            0.0,
            (safeArea.width -
                    ((columns * cardWidth) + ((columns - 1) * horizontalGap))) /
                2,
          );
      final contentTop = featureAreaTop +
          math.max(
            0.0,
            (featureAreaHeight -
                    ((rows * cardHeight) + ((rows - 1) * verticalGap))) /
                2,
          );

      for (var index = 0; index < cardCount; index += 1) {
        final col = index % columns;
        final row = index ~/ columns;
        final left = contentLeft + (col * (cardWidth + horizontalGap));
        final top = contentTop + (row * (cardHeight + verticalGap));
        final centerX = (left + (cardWidth / 2)) - (canvasWidth / 2);
        final centerY = (top + (cardHeight / 2)) - (canvasHeight / 2);
        final iconSize = (cardWidth * 0.11).clamp(34.0, 56.0);
        final labelFontSize = (cardWidth * 0.072).clamp(26.0, 40.0);
        final bodyFontSize = (cardWidth * 0.051).clamp(19.0, 27.0);
        final labelFrameWidth =
            (cardWidth - (iconSize + 72)).clamp(120.0, cardWidth);
        final bodyFrameWidth = (cardWidth - 72).clamp(180.0, cardWidth);
        final bodyFrameHeight = (cardHeight - 112).clamp(88.0, 170.0);
        cards.add(
          SceneCompositionCardFrame(
            centerX: centerX,
            centerY: centerY,
            width: cardWidth,
            height: cardHeight,
            cornerRadius: rules.cardCornerRadius,
            iconSize: iconSize,
            labelFontSize: labelFontSize,
            bodyFontSize: bodyFontSize,
            labelFrameWidth: labelFrameWidth,
            bodyFrameWidth: bodyFrameWidth,
            bodyFrameHeight: bodyFrameHeight,
          ),
        );
      }
    }

    final density = _evaluateDensity(
      safeArea: safeArea,
      cards: cards,
    );
    if (!density.withinHardRange) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.error,
          message:
              'Scene composition density `${density.coverageRatio.toStringAsFixed(3)}` exceeds hard limits.',
          path: 'composition.density',
        ),
      );
    } else if (!density.withinRecommendedRange) {
      issues.add(
        ReFusionMotionDirectorIssue(
          severity: ReFusionMotionDirectorIssueSeverity.warning,
          message:
              'Scene composition density `${density.coverageRatio.toStringAsFixed(3)}` is outside recommended range.',
          path: 'composition.density',
        ),
      );
    }

    for (var index = 0; index < cards.length; index += 1) {
      final card = cards[index];
      final rect = SceneCompositionRect(
        left: (card.centerX + (canvasWidth / 2)) - (card.width / 2),
        top: (card.centerY + (canvasHeight / 2)) - (card.height / 2),
        width: card.width,
        height: card.height,
      );
      const epsilon = 0.75;
      final inside = rect.left >= (safeArea.left - epsilon) &&
          rect.right <= (safeArea.right + epsilon) &&
          rect.top >= (safeArea.top - epsilon) &&
          rect.bottom <= (safeArea.bottom + epsilon);
      if (!inside) {
        issues.add(
          ReFusionMotionDirectorIssue(
            severity: ReFusionMotionDirectorIssueSeverity.error,
            message:
                'Feature card #${index + 1} exceeds safe composition area.',
            path: 'composition.cards[$index]',
          ),
        );
      }
    }

    issues.add(
      ReFusionMotionDirectorIssue(
        severity: issues.any(
          (issue) =>
              issue.severity == ReFusionMotionDirectorIssueSeverity.error,
        )
            ? ReFusionMotionDirectorIssueSeverity.error
            : ReFusionMotionDirectorIssueSeverity.info,
        message: '$kSceneCompositionSolverProofTag '
            'canvas=${canvasWidth.toStringAsFixed(0)}x${canvasHeight.toStringAsFixed(0)} '
            'safeArea=${safeArea.left.toStringAsFixed(1)},${safeArea.top.toStringAsFixed(1)},'
            '${safeArea.right.toStringAsFixed(1)},${safeArea.bottom.toStringAsFixed(1)} '
            'cardCount=$cardCount '
            'density=${density.coverageRatio.toStringAsFixed(3)} '
            'spacing=${spacing.toStringAsFixed(1)}',
        path: 'composition',
      ),
    );

    return SceneCompositionSolution(
      safeArea: safeArea,
      titleY: titleY,
      subtitleY: subtitleY,
      promptCenterY: promptCenterY,
      featureCards: List<SceneCompositionCardFrame>.unmodifiable(cards),
      spacing: spacing,
      issues: List<ReFusionMotionDirectorIssue>.unmodifiable(issues),
    );
  }

  SceneVisualDensityEvaluation _evaluateDensity({
    required SceneCompositionRect safeArea,
    required List<SceneCompositionCardFrame> cards,
  }) {
    if (cards.isEmpty || safeArea.width <= 0 || safeArea.height <= 0) {
      return const SceneVisualDensityEvaluation(
        coverageRatio: 0.0,
        withinRecommendedRange: true,
        withinHardRange: true,
      );
    }
    final cardArea = cards.fold<double>(
      0.0,
      (sum, card) => sum + (card.width * card.height),
    );
    final safeAreaSize = safeArea.width * safeArea.height;
    final ratio = safeAreaSize <= 0 ? 0.0 : cardArea / safeAreaSize;
    if (cards.length <= 1) {
      return SceneVisualDensityEvaluation(
        coverageRatio: ratio,
        withinRecommendedRange: true,
        withinHardRange: true,
      );
    }
    return SceneVisualDensityEvaluation(
      coverageRatio: ratio,
      withinRecommendedRange: ratio >= _densityBudget.minCoverage &&
          ratio <= _densityBudget.maxCoverage,
      withinHardRange: ratio >= _densityBudget.hardMinCoverage &&
          ratio <= _densityBudget.hardMaxCoverage,
    );
  }
}
