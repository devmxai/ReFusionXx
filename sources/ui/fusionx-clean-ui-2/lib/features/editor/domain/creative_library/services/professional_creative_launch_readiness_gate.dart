enum CreativeLaunchReadinessSeverity {
  warning,
  blocker,
}

class CreativeLaunchReadinessIssue {
  const CreativeLaunchReadinessIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final CreativeLaunchReadinessSeverity severity;
}

class CreativeLaunchReadinessInput {
  const CreativeLaunchReadinessInput({
    required this.fullAcceptanceSuitePassRate,
    required this.staleSkillReferenceCount,
    required this.manualUiMcpMatchRatio,
    required this.adapterDirectMutationCount,
    required this.exportUnsupportedSilentPassCount,
    required this.registrySchemaIssueCount,
    required this.rendererConformanceUnknownCount,
    required this.regressionSuiteGreen,
    required this.registryDiffReviewed,
    required this.skillsSyncPass,
    required this.conformanceSnapshotsApproved,
    this.benchmarkQualityTemporalBelowTargetCount = 0,
    this.benchmarkPerformanceBelowTargetCount = 0,
    this.benchmarkPreviewExportParityBelowTargetCount = 0,
    this.benchmarkNativeEditabilityViolationCount = 0,
    this.benchmarkMissingEvidenceCount = 0,
  });

  final double fullAcceptanceSuitePassRate;
  final int staleSkillReferenceCount;
  final double manualUiMcpMatchRatio;
  final int adapterDirectMutationCount;
  final int exportUnsupportedSilentPassCount;
  final int registrySchemaIssueCount;
  final int rendererConformanceUnknownCount;
  final bool regressionSuiteGreen;
  final bool registryDiffReviewed;
  final bool skillsSyncPass;
  final bool conformanceSnapshotsApproved;
  final int benchmarkQualityTemporalBelowTargetCount;
  final int benchmarkPerformanceBelowTargetCount;
  final int benchmarkPreviewExportParityBelowTargetCount;
  final int benchmarkNativeEditabilityViolationCount;
  final int benchmarkMissingEvidenceCount;
}

class CreativeLaunchReadinessResult {
  const CreativeLaunchReadinessResult({
    required this.ready,
    required this.issues,
  });

  final bool ready;
  final List<CreativeLaunchReadinessIssue> issues;
}

class ProfessionalCreativeLaunchReadinessGate {
  const ProfessionalCreativeLaunchReadinessGate();

  CreativeLaunchReadinessResult evaluate(CreativeLaunchReadinessInput input) {
    final issues = <CreativeLaunchReadinessIssue>[];

    if (input.fullAcceptanceSuitePassRate < 1.0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'FULL_ACCEPTANCE_NOT_GREEN',
          message:
              'Full acceptance suite pass rate must be 100%, found ${input.fullAcceptanceSuitePassRate}.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.staleSkillReferenceCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'STALE_SKILL_REFERENCES_PRESENT',
          message:
              'stale_skill_reference_count must be 0, found ${input.staleSkillReferenceCount}.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.manualUiMcpMatchRatio < 1.0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'MANUAL_MCP_PARITY_INCOMPLETE',
          message:
              'manual_ui_mcp_capability_match must be 100%, found ${input.manualUiMcpMatchRatio}.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.adapterDirectMutationCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'DIRECT_MUTATION_PATH_DETECTED',
          message:
              'adapter_direct_mutation_count must be 0, found ${input.adapterDirectMutationCount}.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.exportUnsupportedSilentPassCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'EXPORT_SILENT_PASS_DETECTED',
          message:
              'export_unsupported_silent_pass must be 0, found ${input.exportUnsupportedSilentPassCount}.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.registrySchemaIssueCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'REGISTRY_SCHEMA_ISSUES_PRESENT',
          message:
              'Registry schema issues must be 0, found ${input.registrySchemaIssueCount}.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.rendererConformanceUnknownCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'RENDERER_CONFORMANCE_UNKNOWN',
          message:
              'renderer_conformance_unknown_count must be 0, found ${input.rendererConformanceUnknownCount}.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.benchmarkQualityTemporalBelowTargetCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'BENCHMARK_QUALITY_TEMPORAL_BELOW_TARGET',
          message:
              'benchmark quality/temporal below target for ${input.benchmarkQualityTemporalBelowTargetCount} capabilities.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.benchmarkPerformanceBelowTargetCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'BENCHMARK_PERFORMANCE_BELOW_TARGET',
          message:
              'benchmark performance below target for ${input.benchmarkPerformanceBelowTargetCount} capabilities.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.benchmarkPreviewExportParityBelowTargetCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'BENCHMARK_PARITY_BELOW_TARGET',
          message:
              'benchmark preview/export parity below target for ${input.benchmarkPreviewExportParityBelowTargetCount} capabilities.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.benchmarkNativeEditabilityViolationCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'BENCHMARK_EDITABILITY_NATIVE_VIOLATION',
          message:
              'native editability violation found for ${input.benchmarkNativeEditabilityViolationCount} capabilities.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (input.benchmarkMissingEvidenceCount != 0) {
      issues.add(
        CreativeLaunchReadinessIssue(
          code: 'BENCHMARK_EVIDENCE_MISSING',
          message:
              'benchmark evidence missing for ${input.benchmarkMissingEvidenceCount} capabilities.',
          severity: CreativeLaunchReadinessSeverity.warning,
        ),
      );
    }
    if (!input.regressionSuiteGreen) {
      issues.add(
        const CreativeLaunchReadinessIssue(
          code: 'REGRESSION_SUITE_NOT_GREEN',
          message: 'Regression suite must be green before launch.',
          severity: CreativeLaunchReadinessSeverity.blocker,
        ),
      );
    }
    if (!input.registryDiffReviewed) {
      issues.add(
        const CreativeLaunchReadinessIssue(
          code: 'REGISTRY_DIFF_NOT_REVIEWED',
          message: 'Registry diff review is required by release governance.',
          severity: CreativeLaunchReadinessSeverity.warning,
        ),
      );
    }
    if (!input.skillsSyncPass) {
      issues.add(
        const CreativeLaunchReadinessIssue(
          code: 'SKILLS_SYNC_NOT_CONFIRMED',
          message: 'Skills synchronization check is required before launch.',
          severity: CreativeLaunchReadinessSeverity.warning,
        ),
      );
    }
    if (!input.conformanceSnapshotsApproved) {
      issues.add(
        const CreativeLaunchReadinessIssue(
          code: 'CONFORMANCE_SNAPSHOTS_NOT_APPROVED',
          message:
              'Conformance snapshot approval is required by release checklist.',
          severity: CreativeLaunchReadinessSeverity.warning,
        ),
      );
    }

    final hasBlockers = issues.any(
        (issue) => issue.severity == CreativeLaunchReadinessSeverity.blocker);
    return CreativeLaunchReadinessResult(
      ready: !hasBlockers,
      issues: List<CreativeLaunchReadinessIssue>.unmodifiable(issues),
    );
  }
}
