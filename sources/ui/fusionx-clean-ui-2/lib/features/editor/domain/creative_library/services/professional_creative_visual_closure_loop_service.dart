enum CreativeVisualClosureSeverity {
  info,
  warning,
  blocker,
}

class CreativeVisualClosureIssue {
  const CreativeVisualClosureIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final CreativeVisualClosureSeverity severity;
}

class CreativeVisualClosureReport {
  const CreativeVisualClosureReport({
    required this.ok,
    required this.beforeFrameUri,
    required this.afterFrameUri,
    required this.issues,
    required this.summary,
  });

  final bool ok;
  final String? beforeFrameUri;
  final String? afterFrameUri;
  final List<CreativeVisualClosureIssue> issues;
  final String summary;
}

class ProfessionalCreativeVisualClosureLoopService {
  const ProfessionalCreativeVisualClosureLoopService();

  static const List<String> _requiredProofFlags = <String>[
    'dataApplied',
    'localGraphApplied',
    'timelineVisible',
    'frameEvaluated',
    'visualProgramEmitted',
    'rendererApplied',
  ];

  CreativeVisualClosureReport buildReport({
    required Map<String, Object?> applyProof,
    required List<String> overlapDiagnostics,
    required List<String> safeZoneDiagnostics,
    String? beforeFrameUri,
    String? afterFrameUri,
  }) {
    final issues = <CreativeVisualClosureIssue>[];
    for (final flag in _requiredProofFlags) {
      final flagValue = applyProof[flag] == true;
      if (!flagValue) {
        issues.add(
          CreativeVisualClosureIssue(
            code: 'PROOF_FLAG_MISSING_$flag',
            message: 'Required apply proof flag `$flag` is missing or false.',
            severity: CreativeVisualClosureSeverity.blocker,
          ),
        );
      }
    }

    for (final item in overlapDiagnostics) {
      issues.add(
        CreativeVisualClosureIssue(
          code: 'LAYOUT_OVERLAP_DETECTED',
          message: item,
          severity: CreativeVisualClosureSeverity.warning,
        ),
      );
    }
    for (final item in safeZoneDiagnostics) {
      issues.add(
        CreativeVisualClosureIssue(
          code: 'SAFE_ZONE_VIOLATION',
          message: item,
          severity: CreativeVisualClosureSeverity.warning,
        ),
      );
    }

    if (beforeFrameUri == null || beforeFrameUri.trim().isEmpty) {
      issues.add(
        const CreativeVisualClosureIssue(
          code: 'BEFORE_FRAME_MISSING',
          message: 'Before-frame proof was not captured.',
          severity: CreativeVisualClosureSeverity.warning,
        ),
      );
    }
    if (afterFrameUri == null || afterFrameUri.trim().isEmpty) {
      issues.add(
        const CreativeVisualClosureIssue(
          code: 'AFTER_FRAME_MISSING',
          message: 'After-frame proof was not captured.',
          severity: CreativeVisualClosureSeverity.warning,
        ),
      );
    }

    final blockers = issues
        .where(
            (issue) => issue.severity == CreativeVisualClosureSeverity.blocker)
        .length;
    final warnings = issues
        .where(
            (issue) => issue.severity == CreativeVisualClosureSeverity.warning)
        .length;
    final ok = blockers == 0;
    final summary = ok
        ? 'Visual closure ready: apply proof passed with $warnings warning(s).'
        : 'Visual closure blocked: $blockers blocker(s), $warnings warning(s).';
    return CreativeVisualClosureReport(
      ok: ok,
      beforeFrameUri: beforeFrameUri,
      afterFrameUri: afterFrameUri,
      issues: List<CreativeVisualClosureIssue>.unmodifiable(issues),
      summary: summary,
    );
  }

  String buildAgentRepairPrompt(CreativeVisualClosureReport report) {
    if (report.ok) {
      return 'Visual closure passed. Continue with next command sequence.';
    }
    final blockers = report.issues
        .where(
            (issue) => issue.severity == CreativeVisualClosureSeverity.blocker)
        .map((issue) => '- ${issue.code}: ${issue.message}')
        .toList(growable: false);
    final warnings = report.issues
        .where(
            (issue) => issue.severity == CreativeVisualClosureSeverity.warning)
        .map((issue) => '- ${issue.code}: ${issue.message}')
        .toList(growable: false);

    final buffer = StringBuffer()
      ..writeln('Visual closure failed. Repair required before commit.')
      ..writeln('Blockers:')
      ..writeln(blockers.isEmpty ? '- none' : blockers.join('\n'))
      ..writeln('Warnings:')
      ..writeln(warnings.isEmpty ? '- none' : warnings.join('\n'))
      ..writeln('Required next action:')
      ..writeln(
          '- Re-run layout/overlap checks, capture before/after frames, then re-apply command with proof flags all true.');
    return buffer.toString().trimRight();
  }
}
