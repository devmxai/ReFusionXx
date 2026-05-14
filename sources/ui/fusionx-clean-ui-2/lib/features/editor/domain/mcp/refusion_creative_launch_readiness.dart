import '../creative_library/services/professional_creative_launch_readiness_orchestrator.dart';

class RefusionCreativeLaunchReadinessToolset {
  const RefusionCreativeLaunchReadinessToolset({
    required ProfessionalCreativeLaunchReadinessOrchestrator orchestrator,
  }) : _orchestrator = orchestrator;

  final ProfessionalCreativeLaunchReadinessOrchestrator _orchestrator;

  Map<String, Object?> invoke({
    required String toolName,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    switch (toolName) {
      case 'get_launch_readiness':
      case 'refusion.get_launch_readiness':
        return _evaluate(payload);
      default:
        return <String, Object?>{
          'error': 'unsupported_launch_readiness_tool',
          'toolName': toolName,
        };
    }
  }

  Map<String, Object?> _evaluate(Map<String, Object?> payload) {
    final skillMarkdown = payload['skillMarkdown'] as String? ?? '';
    if (skillMarkdown.trim().isEmpty) {
      return <String, Object?>{
        'error': 'skill_markdown_required',
        'message':
            'payload.skillMarkdown is required for launch readiness evaluation.',
      };
    }
    final report = _orchestrator.evaluate(
      CreativeLaunchReadinessEvaluationContext(
        skillMarkdown: skillMarkdown,
        fullAcceptanceSuitePassRate:
            _asDouble(payload['fullAcceptanceSuitePassRate']) ?? 1.0,
        regressionSuiteGreen: _asBool(payload['regressionSuiteGreen']) ?? true,
        registryDiffReviewed: _asBool(payload['registryDiffReviewed']) ?? true,
        skillsSyncPass: _asBool(payload['skillsSyncPass']) ?? true,
        conformanceSnapshotsApproved:
            _asBool(payload['conformanceSnapshotsApproved']) ?? true,
        exportUnsupportedSilentPassCount:
            _asInt(payload['exportUnsupportedSilentPassCount']) ?? 0,
      ),
    );

    return <String, Object?>{
      'ok': true,
      'ready': report.result.ready,
      'issues': report.result.issues
          .map(
            (issue) => <String, Object?>{
              'code': issue.code,
              'message': issue.message,
              'severity': issue.severity.name,
            },
          )
          .toList(growable: false),
      'input': <String, Object?>{
        'fullAcceptanceSuitePassRate': report.input.fullAcceptanceSuitePassRate,
        'staleSkillReferenceCount': report.input.staleSkillReferenceCount,
        'manualUiMcpMatchRatio': report.input.manualUiMcpMatchRatio,
        'adapterDirectMutationCount': report.input.adapterDirectMutationCount,
        'exportUnsupportedSilentPassCount':
            report.input.exportUnsupportedSilentPassCount,
        'registrySchemaIssueCount': report.input.registrySchemaIssueCount,
        'rendererConformanceUnknownCount':
            report.input.rendererConformanceUnknownCount,
        'regressionSuiteGreen': report.input.regressionSuiteGreen,
        'registryDiffReviewed': report.input.registryDiffReviewed,
        'skillsSyncPass': report.input.skillsSyncPass,
        'conformanceSnapshotsApproved':
            report.input.conformanceSnapshotsApproved,
        'benchmarkQualityTemporalBelowTargetCount':
            report.input.benchmarkQualityTemporalBelowTargetCount,
        'benchmarkPerformanceBelowTargetCount':
            report.input.benchmarkPerformanceBelowTargetCount,
        'benchmarkPreviewExportParityBelowTargetCount':
            report.input.benchmarkPreviewExportParityBelowTargetCount,
        'benchmarkNativeEditabilityViolationCount':
            report.input.benchmarkNativeEditabilityViolationCount,
        'benchmarkMissingEvidenceCount':
            report.input.benchmarkMissingEvidenceCount,
      },
      'metrics': report.metrics,
    };
  }

  double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
