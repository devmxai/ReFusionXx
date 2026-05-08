import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_semantic_repair_loop_service.dart';

void main() {
  const service = SceneSemanticRepairLoopService();

  test('maps bounded text overflow to structured repair payload', () {
    final payloads = service.buildPayloads(
      const <ReFusionSceneProgramIssue>[
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Text element `feedback-body` static bounded frame overflow detected. '
              'estimatedWidth=480.0 estimatedHeight=52.0 frameWidth=320.0 frameHeight=64.0',
          path: 'layers[0].elements[0].properties.textFrame',
        ),
      ],
    );

    expect(payloads, hasLength(1));
    expect(payloads.first.errorCode, equals('TEXT_OVERFLOW_RIGHT'));
    expect(payloads.first.elementId, equals('feedback-body'));
    expect(payloads.first.suggestedAction, contains('textFrame'));
  });

  test('maps failed determinism proof to NON_DETERMINISTIC_COMPILATION', () {
    final payloads = service.buildPayloads(
      const <ReFusionSceneProgramIssue>[
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'TF_SCENE_DETERMINISM_PROOF blueprintHash=a sceneProgramHash=b '
              'deterministic=false passed=false failureReason=hash_mismatch',
          path: r'$',
        ),
      ],
    );

    expect(payloads, hasLength(1));
    expect(
      payloads.first.errorCode,
      equals('NON_DETERMINISTIC_COMPILATION'),
    );
  });

  test('repair loop converges within max attempts and emits proof', () {
    final result = service.runLoop(
      evaluateIssues: (attempt) {
        if (attempt == 1) {
          return const <ReFusionSceneProgramIssue>[
            ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message:
                  'Text element `prompt-text` reveal bounded frame overflow detected. '
                  'estimatedWidth=700.0 estimatedHeight=40.0 frameWidth=520.0 frameHeight=56.0',
              path: 'layers[0].elements[0].properties.textFrame',
            ),
          ];
        }
        return const <ReFusionSceneProgramIssue>[];
      },
      maxAttemptsOverride: 3,
    );

    expect(result.converged, isTrue);
    expect(result.exhausted, isFalse);
    expect(result.attempts.length, equals(2));
    expect(
      result.attempts.first.proofIssues.any(
        (issue) => issue.message.contains(kSceneRepairLoopProofTag),
      ),
      isTrue,
    );
  });

  test('repair loop stops after max attempts when still failing', () {
    final result = service.runLoop(
      evaluateIssues: (attempt) => const <ReFusionSceneProgramIssue>[
        ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message: 'Unsupported semantic component `LegacyCard` in lowerer.',
          path: 'components.legacyCard.type',
        ),
      ],
      maxAttemptsOverride: 3,
    );

    expect(result.converged, isFalse);
    expect(result.exhausted, isTrue);
    expect(result.attempts.length, equals(3));
    expect(result.attempts.last.remainingErrors, greaterThan(0));
  });
}
