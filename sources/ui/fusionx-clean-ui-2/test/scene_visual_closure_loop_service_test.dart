import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_visual_closure_loop_service.dart';

void main() {
  const service = SceneVisualClosureLoopService();

  test('buildRepairActions extracts structured fields from probe issue', () {
    final issues = <ReFusionSceneProgramIssue>[
      const ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message: 'TF_SCENE_VISUAL_FRAME_QA_PROOF '
            'frameIndex=5 '
            'timelineTimeMs=1200 '
            'nodeId=prompt::slot::primaryText::leaf '
            'componentId=prompt '
            'slotId=primaryText '
            'worldBounds=120.00,320.00,560.00,64.00 '
            'slotBounds=120.00,320.00,520.00,64.00 '
            'textOverflow=true '
            'overflowPx=40.00 '
            'clippingPx=0.00 '
            'overlapDetected=false '
            'safeAreaViolation=false '
            'parentChildDesync=false '
            'passed=false '
            'failureReason=text_overflow '
            'severity=error '
            'fallbackReason=none',
        path: 'layers[0].elements[0].probe[4]',
      ),
    ];

    final actions = service.buildRepairActions(issues);
    expect(actions.length, 1);
    expect(actions.first.errorCode, 'TEXT_OVERFLOW_RIGHT');
    expect(actions.first.suggestedAction, 'enable_shrink_to_fit');
    expect(actions.first.nodeId, 'prompt::slot::primaryText::leaf');
    expect(actions.first.slotId, 'primaryText');
    expect(actions.first.frameTimeMs, 1200);
    expect(actions.first.measuredBounds, '120.00,320.00,560.00,64.00');
    expect(actions.first.expectedBounds, '120.00,320.00,520.00,64.00');
  });

  test('runLoop converges and emits closure proof', () {
    final initial = <ReFusionSceneProgramIssue>[
      const ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message: 'bounded frame overflow detected estimatedWidth=580 '
            'frameWidth=520',
        path: 'components.prompt.slots.primaryText',
      ),
    ];

    final result = service.runLoop(
      initialIssues: initial,
      evaluateIssues: (attempt, actions, current) {
        if (attempt == 1) {
          return <ReFusionSceneProgramIssue>[
            const ReFusionSceneProgramIssue(
              severity: ReFusionSceneProgramIssueSeverity.error,
              message: 'safe area violation persists',
              path: 'components.prompt',
            ),
          ];
        }
        return const <ReFusionSceneProgramIssue>[];
      },
    );

    expect(result.approved, isTrue);
    expect(result.escalated, isFalse);
    expect(result.attempts.length, 2);
    expect(
      result.attempts.last.proofIssues.any(
        (issue) =>
            issue.message.contains(kSceneVisualClosureLoopProofTag) &&
            issue.message.contains('approved=true'),
      ),
      isTrue,
    );
  });

  test('runLoop escalates after max attempts', () {
    final initial = <ReFusionSceneProgramIssue>[
      const ReFusionSceneProgramIssue(
        severity: ReFusionSceneProgramIssueSeverity.error,
        message: 'parent child desync detected',
        path: 'components.card',
      ),
    ];

    final result = service.runLoop(
      initialIssues: initial,
      maxAttemptsOverride: 3,
      evaluateIssues: (attempt, actions, current) => current,
    );

    expect(result.approved, isFalse);
    expect(result.escalated, isTrue);
    expect(result.attempts.length, 3);
    expect(result.attempts.last.escalated, isTrue);
    expect(
      result.attempts.last.proofIssues.first.message.contains('escalated=true'),
      isTrue,
    );
  });
}
