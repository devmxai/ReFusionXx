import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_launch_readiness_gate.dart';

void main() {
  group('Launch Readiness Gate', () {
    const gate = ProfessionalCreativeLaunchReadinessGate();

    test('ready when all hard KPIs and governance checks pass', () {
      final evaluation = gate.evaluate(
        const CreativeLaunchReadinessInput(
          fullAcceptanceSuitePassRate: 1.0,
          staleSkillReferenceCount: 0,
          manualUiMcpMatchRatio: 1.0,
          adapterDirectMutationCount: 0,
          exportUnsupportedSilentPassCount: 0,
          registrySchemaIssueCount: 0,
          rendererConformanceUnknownCount: 0,
          regressionSuiteGreen: true,
          registryDiffReviewed: true,
          skillsSyncPass: true,
          conformanceSnapshotsApproved: true,
        ),
      );

      expect(evaluation.ready, isTrue);
      expect(evaluation.issues, isEmpty);
    });

    test('blocked when mandatory KPIs fail', () {
      final evaluation = gate.evaluate(
        const CreativeLaunchReadinessInput(
          fullAcceptanceSuitePassRate: 0.95,
          staleSkillReferenceCount: 2,
          manualUiMcpMatchRatio: 0.9,
          adapterDirectMutationCount: 1,
          exportUnsupportedSilentPassCount: 1,
          registrySchemaIssueCount: 3,
          rendererConformanceUnknownCount: 1,
          regressionSuiteGreen: false,
          registryDiffReviewed: true,
          skillsSyncPass: true,
          conformanceSnapshotsApproved: true,
        ),
      );

      expect(evaluation.ready, isFalse);
      expect(
        evaluation.issues.any(
          (issue) => issue.code == 'FULL_ACCEPTANCE_NOT_GREEN',
        ),
        isTrue,
      );
      expect(
        evaluation.issues.any(
          (issue) => issue.code == 'DIRECT_MUTATION_PATH_DETECTED',
        ),
        isTrue,
      );
      expect(
        evaluation.issues.any(
          (issue) => issue.code == 'REGRESSION_SUITE_NOT_GREEN',
        ),
        isTrue,
      );
    });

    test('governance misses are warnings, not blockers', () {
      final evaluation = gate.evaluate(
        const CreativeLaunchReadinessInput(
          fullAcceptanceSuitePassRate: 1.0,
          staleSkillReferenceCount: 0,
          manualUiMcpMatchRatio: 1.0,
          adapterDirectMutationCount: 0,
          exportUnsupportedSilentPassCount: 0,
          registrySchemaIssueCount: 0,
          rendererConformanceUnknownCount: 0,
          regressionSuiteGreen: true,
          registryDiffReviewed: false,
          skillsSyncPass: false,
          conformanceSnapshotsApproved: false,
        ),
      );

      expect(evaluation.ready, isTrue);
      expect(
        evaluation.issues.where(
          (issue) => issue.severity == CreativeLaunchReadinessSeverity.warning,
        ),
        isNotEmpty,
      );
      expect(
        evaluation.issues.any(
          (issue) => issue.code == 'REGISTRY_DIFF_NOT_REVIEWED',
        ),
        isTrue,
      );
    });
  });
}
