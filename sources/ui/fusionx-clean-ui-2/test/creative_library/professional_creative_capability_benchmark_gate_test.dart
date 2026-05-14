import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_capability_benchmark_gate.dart';

void main() {
  group('ProfessionalCreativeCapabilityBenchmarkGate', () {
    const gate = ProfessionalCreativeCapabilityBenchmarkGate();

    test('returns zero violations when benchmark scores satisfy thresholds',
        () {
      final result = gate.evaluate(<CreativeLibraryItemDefinition>[
        _item(
          id: 'effect.motionBlur',
          benchmark: const CapabilityBenchmarkRecord(
            capabilityId: 'effect.motionBlur',
            capabilityFamily: 'effect',
            benchmarkVersion: '1',
            comparedAgainst: <String>['refusion', 'remotion', 'hyperframes'],
            visualQuality: 4,
            temporalAccuracy: 4,
            parameterDepth: 4,
            performance: 3,
            previewExportParity: 4,
            editability: 4,
            determinism: 5,
            crossDeviceStability: 4,
            pipelineCoverage: 4,
            agentUsability: 4,
            codeReferences: <String>['lib/effects/motion_blur.dart'],
            benchmarkScenes: <String>['fast_pan'],
            measurementResults: <String>['p95=7.2ms'],
          ),
          decision: CapabilityBenchmarkDecision.keep,
        ),
      ]);

      expect(result.qualityTemporalBelowTargetCount, 0);
      expect(result.performanceBelowTargetCount, 0);
      expect(result.previewExportParityBelowTargetCount, 0);
      expect(result.nativeEditabilityViolationCount, 0);
      expect(result.missingEvidenceCount, 0);
    });

    test('detects threshold violations and missing evidence', () {
      final result = gate.evaluate(<CreativeLibraryItemDefinition>[
        _item(
          id: 'effect.experimental',
          benchmark: const CapabilityBenchmarkRecord(
            capabilityId: 'effect.experimental',
            capabilityFamily: 'effect',
            benchmarkVersion: '1',
            comparedAgainst: <String>['refusion'],
            visualQuality: 3,
            temporalAccuracy: 3,
            parameterDepth: 3,
            performance: 2,
            previewExportParity: 3,
            editability: 3,
            determinism: 3,
            crossDeviceStability: 3,
            pipelineCoverage: 3,
            agentUsability: 3,
            codeReferences: <String>[],
            benchmarkScenes: <String>[],
            measurementResults: <String>[],
          ),
          decision: CapabilityBenchmarkDecision.keep,
        ),
      ]);

      expect(result.qualityTemporalBelowTargetCount, 1);
      expect(result.performanceBelowTargetCount, 1);
      expect(result.previewExportParityBelowTargetCount, 1);
      expect(result.nativeEditabilityViolationCount, 1);
      expect(result.missingEvidenceCount, 1);
    });

    test('does not flag low editability when capability is prerender-only', () {
      final result = gate.evaluate(<CreativeLibraryItemDefinition>[
        _item(
          id: 'effect.prerender',
          benchmark: const CapabilityBenchmarkRecord(
            capabilityId: 'effect.prerender',
            capabilityFamily: 'effect',
            benchmarkVersion: '1',
            comparedAgainst: <String>['refusion'],
            visualQuality: 4,
            temporalAccuracy: 4,
            parameterDepth: 3,
            performance: 3,
            previewExportParity: 4,
            editability: 2,
            determinism: 4,
            crossDeviceStability: 4,
            pipelineCoverage: 3,
            agentUsability: 3,
            codeReferences: <String>['lib/effects/prerender.dart'],
            benchmarkScenes: <String>['glow'],
            measurementResults: <String>['p95=9.1ms'],
          ),
          decision: CapabilityBenchmarkDecision.prerenderOnly,
        ),
      ]);

      expect(result.nativeEditabilityViolationCount, 0);
    });
  });
}

CreativeLibraryItemDefinition _item({
  required String id,
  required CapabilityBenchmarkRecord benchmark,
  required CapabilityBenchmarkDecision decision,
}) {
  return CreativeLibraryItemDefinition(
    id: id,
    version: '1.0.0',
    kind: CreativeLibraryItemKind.effect,
    title: id,
    description: 'test',
    category: 'test',
    tags: const <String>['test'],
    sourceInspiration: 'test',
    licenseStatus: 'internal',
    supportedNodeFamilies: const <String>['video'],
    parameterSchema: const <String, Object?>{},
    defaultParams: const <String, Object?>{},
    requiredAssets: const <String>[],
    supportedAspectRatios: const <String>['9:16'],
    defaultDurationMs: 1000,
    timelineBehavior: 'stack',
    spatialBehavior: 'canvas',
    compileContract: 'none',
    loweringContract: 'none',
    manualUiControls: const <ManualUiControlDefinition>[],
    mcpExamples: const <McpToolExposureDefinition>[],
    pasteScriptExamples: const <String>[],
    templateExamples: const <String>[],
    previewPoster: '',
    previewMotion: '',
    qaRules: const <QaRuleDefinition>[],
    rendererConformance: const RendererConformanceDefinition(
      previewSupported: true,
      exportSupported: true,
      deterministic: true,
      rendererPath: 'stage5',
      exportPath: 'bmf',
      fallbackMode: 'none',
    ),
    exportConformance: const RendererConformanceDefinition(
      previewSupported: true,
      exportSupported: true,
      deterministic: true,
      rendererPath: 'stage5',
      exportPath: 'bmf',
      fallbackMode: 'none',
    ),
    capabilityBenchmark: benchmark,
    benchmarkDecision: decision,
    legacyPathCleanup: const <String, LegacyPathCleanupDecision>{},
    supportedEntrySurfaces: const <SupportedEntrySurface>{
      SupportedEntrySurface.mcp,
    },
    failureMode: 'fail-closed',
  );
}
