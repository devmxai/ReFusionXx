import 'professional_creative_command_lowerer.dart';
import 'professional_creative_library_registry.dart';
import 'professional_creative_renderer_conformance_gate.dart';

enum CreativeExportParityIssueCode {
  capabilityNotFound,
  previewNotSupported,
  exportNotSupported,
  nonDeterministicCapability,
  projectionGraphTruthMissing,
  projectionTimelineTruthMissing,
}

class CreativeExportParityIssue {
  const CreativeExportParityIssue({
    required this.code,
    required this.capabilityId,
    required this.message,
    this.detail,
  });

  final CreativeExportParityIssueCode code;
  final String capabilityId;
  final String message;
  final String? detail;
}

class CreativeExportParityResult {
  const CreativeExportParityResult({
    required this.ready,
    required this.capabilitiesChecked,
    required this.capabilitiesPassed,
    required this.parityScore,
    required this.issues,
  });

  final bool ready;
  final int capabilitiesChecked;
  final int capabilitiesPassed;
  final double parityScore;
  final List<CreativeExportParityIssue> issues;

  bool get hasBlockers => issues.isNotEmpty;
}

class ProfessionalCreativeExportParityGate {
  const ProfessionalCreativeExportParityGate({
    ProfessionalCreativeRendererConformanceGate conformanceGate =
        const ProfessionalCreativeRendererConformanceGate(),
  }) : _conformanceGate = conformanceGate;

  final ProfessionalCreativeRendererConformanceGate _conformanceGate;

  CreativeExportParityResult evaluate({
    required ProfessionalCreativeLibraryRegistry registry,
    required Set<String> capabilityIds,
    required CreativeLoweringProjection projection,
    bool requireDeterministic = true,
  }) {
    final issues = <CreativeExportParityIssue>[];
    var passed = 0;

    if (!projection.graphVisible) {
      issues.add(
        const CreativeExportParityIssue(
          code: CreativeExportParityIssueCode.projectionGraphTruthMissing,
          capabilityId: '*projection*',
          message: 'Lowering projection must include graph nodes.',
        ),
      );
    }
    if (!projection.timelineVisible) {
      issues.add(
        const CreativeExportParityIssue(
          code: CreativeExportParityIssueCode.projectionTimelineTruthMissing,
          capabilityId: '*projection*',
          message: 'Lowering projection must include timeline clips.',
        ),
      );
    }

    for (final capabilityId in capabilityIds) {
      final item = registry.describe(capabilityId);
      if (item == null) {
        issues.add(
          CreativeExportParityIssue(
            code: CreativeExportParityIssueCode.capabilityNotFound,
            capabilityId: capabilityId,
            message: 'Capability is not present in creative registry.',
          ),
        );
        continue;
      }

      final previewDecision = _conformanceGate.evaluate(
        item: item,
        mode: CreativeExecutionMode.preview,
        requireDeterministic: requireDeterministic,
      );
      if (!previewDecision.allowed) {
        issues.add(
          CreativeExportParityIssue(
            code: previewDecision.blockerCode == 'NON_DETERMINISTIC_CAPABILITY'
                ? CreativeExportParityIssueCode.nonDeterministicCapability
                : CreativeExportParityIssueCode.previewNotSupported,
            capabilityId: capabilityId,
            message: previewDecision.blockerReason ?? 'Preview not supported.',
            detail: previewDecision.blockerCode,
          ),
        );
        continue;
      }

      final exportDecision = _conformanceGate.evaluate(
        item: item,
        mode: CreativeExecutionMode.export,
        requireDeterministic: requireDeterministic,
      );
      if (!exportDecision.allowed) {
        issues.add(
          CreativeExportParityIssue(
            code: exportDecision.blockerCode == 'NON_DETERMINISTIC_CAPABILITY'
                ? CreativeExportParityIssueCode.nonDeterministicCapability
                : CreativeExportParityIssueCode.exportNotSupported,
            capabilityId: capabilityId,
            message: exportDecision.blockerReason ?? 'Export not supported.',
            detail: exportDecision.blockerCode,
          ),
        );
        continue;
      }
      passed += 1;
    }

    final checked = capabilityIds.length;
    final score = checked == 0 ? 0.0 : passed / checked;
    return CreativeExportParityResult(
      ready: issues.isEmpty && passed == checked && checked > 0,
      capabilitiesChecked: checked,
      capabilitiesPassed: passed,
      parityScore: score,
      issues: List<CreativeExportParityIssue>.unmodifiable(issues),
    );
  }
}
