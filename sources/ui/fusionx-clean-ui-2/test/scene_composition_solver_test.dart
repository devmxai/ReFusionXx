import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_composition_solver.dart';

void main() {
  const solver = SceneCompositionSolver();

  test('adapts a 2x2 feature grid to core aspect ratios without overflow', () {
    const canvases = <(double, double)>[
      (1080, 1920),
      (1920, 1080),
      (1080, 1080),
      (1080, 1350),
    ];

    for (final canvas in canvases) {
      final result = solver.solve(
        canvasWidth: canvas.$1,
        canvasHeight: canvas.$2,
        featureCardCount: 4,
      );
      expect(result.featureCards, hasLength(4));
      for (var index = 0; index < result.featureCards.length; index += 1) {
        final card = result.featureCards[index];
        final left = (card.centerX + (canvas.$1 / 2)) - (card.width / 2);
        final top = (card.centerY + (canvas.$2 / 2)) - (card.height / 2);
        final right = left + card.width;
        final bottom = top + card.height;
        const epsilon = 0.75;
        expect(left >= (result.safeArea.left - epsilon), isTrue);
        expect(right <= (result.safeArea.right + epsilon), isTrue);
        expect(top >= (result.safeArea.top - epsilon), isTrue);
        expect(bottom <= (result.safeArea.bottom + epsilon), isTrue);
      }

      for (var leftIndex = 0;
          leftIndex < result.featureCards.length;
          leftIndex += 1) {
        for (var rightIndex = leftIndex + 1;
            rightIndex < result.featureCards.length;
            rightIndex += 1) {
          final leftCard = result.featureCards[leftIndex];
          final rightCard = result.featureCards[rightIndex];
          final leftRect = _rectForCard(leftCard, canvas.$1, canvas.$2);
          final rightRect = _rectForCard(rightCard, canvas.$1, canvas.$2);
          final overlap = !(leftRect.$3 <= rightRect.$1 ||
              rightRect.$3 <= leftRect.$1 ||
              leftRect.$4 <= rightRect.$2 ||
              rightRect.$4 <= leftRect.$2);
          expect(overlap, isFalse);
        }
      }
    }
  });

  test('maintains professional text and icon ratios for cards', () {
    final result = solver.solve(
      canvasWidth: 1080,
      canvasHeight: 1920,
      featureCardCount: 4,
    );
    final card = result.featureCards.first;
    expect(card.iconSize / card.width, inInclusiveRange(0.08, 0.14));
    expect(card.labelFontSize / card.width, inInclusiveRange(0.05, 0.09));
    expect(card.bodyFontSize / card.width, inInclusiveRange(0.035, 0.07));
    expect(card.bodyFrameHeight, greaterThan(80));
    expect(card.bodyFrameWidth, greaterThan(180));
  });

  test('emits composition proof diagnostics', () {
    final result = solver.solve(
      canvasWidth: 1080,
      canvasHeight: 1920,
      featureCardCount: 4,
    );
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneCompositionSolverProofTag),
      ),
      isTrue,
    );
  });
}

(double, double, double, double) _rectForCard(
  SceneCompositionCardFrame card,
  double canvasWidth,
  double canvasHeight,
) {
  final left = (card.centerX + (canvasWidth / 2)) - (card.width / 2);
  final top = (card.centerY + (canvasHeight / 2)) - (card.height / 2);
  return (left, top, left + card.width, top + card.height);
}
