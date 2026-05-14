import '../models/professional_creative_library_registry_models.dart';

class CreativeCapabilityBenchmarkGateResult {
  const CreativeCapabilityBenchmarkGateResult({
    required this.qualityTemporalBelowTargetCount,
    required this.performanceBelowTargetCount,
    required this.previewExportParityBelowTargetCount,
    required this.nativeEditabilityViolationCount,
    required this.missingEvidenceCount,
  });

  final int qualityTemporalBelowTargetCount;
  final int performanceBelowTargetCount;
  final int previewExportParityBelowTargetCount;
  final int nativeEditabilityViolationCount;
  final int missingEvidenceCount;
}

class ProfessionalCreativeCapabilityBenchmarkGate {
  const ProfessionalCreativeCapabilityBenchmarkGate();

  CreativeCapabilityBenchmarkGateResult evaluate(
    List<CreativeLibraryItemDefinition> items,
  ) {
    var qualityTemporalBelowTargetCount = 0;
    var performanceBelowTargetCount = 0;
    var previewExportParityBelowTargetCount = 0;
    var nativeEditabilityViolationCount = 0;
    var missingEvidenceCount = 0;

    for (final item in items) {
      final benchmark = item.capabilityBenchmark;
      if (!benchmark.hasCompleteEvidence) {
        missingEvidenceCount += 1;
      }
      if (benchmark.visualQuality < 4 || benchmark.temporalAccuracy < 4) {
        qualityTemporalBelowTargetCount += 1;
      }
      if (benchmark.performance < 3) {
        performanceBelowTargetCount += 1;
      }
      if (benchmark.previewExportParity < 4) {
        previewExportParityBelowTargetCount += 1;
      }
      if (benchmark.editability < 4 &&
          item.benchmarkDecision != CapabilityBenchmarkDecision.prerenderOnly) {
        nativeEditabilityViolationCount += 1;
      }
    }

    return CreativeCapabilityBenchmarkGateResult(
      qualityTemporalBelowTargetCount: qualityTemporalBelowTargetCount,
      performanceBelowTargetCount: performanceBelowTargetCount,
      previewExportParityBelowTargetCount: previewExportParityBelowTargetCount,
      nativeEditabilityViolationCount: nativeEditabilityViolationCount,
      missingEvidenceCount: missingEvidenceCount,
    );
  }
}
