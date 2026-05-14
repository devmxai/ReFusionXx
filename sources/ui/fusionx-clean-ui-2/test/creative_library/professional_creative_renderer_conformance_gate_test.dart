import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_renderer_conformance_gate.dart';

void main() {
  group('PNCLE-07 Renderer Conformance Gate', () {
    const gate = ProfessionalCreativeRendererConformanceGate();

    test('allows supported deterministic preview capability', () {
      final item = _buildItem(
        id: r'$effect.motionBlur',
        previewSupported: true,
        exportSupported: true,
        deterministic: true,
      );
      final decision = gate.evaluate(
        item: item,
        mode: CreativeExecutionMode.preview,
      );
      expect(decision.allowed, isTrue);
      expect(decision.blockerCode, isNull);
    });

    test('blocks export when capability is not export-supported', () {
      final item = _buildItem(
        id: r'$effect.experimentalX',
        previewSupported: true,
        exportSupported: false,
        deterministic: true,
      );
      final decision = gate.evaluate(
        item: item,
        mode: CreativeExecutionMode.export,
      );
      expect(decision.allowed, isFalse);
      expect(decision.blockerCode, 'EXPORT_NOT_SUPPORTED');
      expect(decision.fallbackMode, 'prerender_only');
    });

    test('blocks non-deterministic capability in strict mode', () {
      final item = _buildItem(
        id: r'$motion.randomizedShake',
        previewSupported: true,
        exportSupported: true,
        deterministic: false,
      );
      final decision = gate.evaluate(
        item: item,
        mode: CreativeExecutionMode.preview,
        requireDeterministic: true,
      );
      expect(decision.allowed, isFalse);
      expect(decision.blockerCode, 'NON_DETERMINISTIC_CAPABILITY');
    });

    test('allows non-deterministic capability when strict mode disabled', () {
      final item = _buildItem(
        id: r'$motion.randomizedShake',
        previewSupported: true,
        exportSupported: true,
        deterministic: false,
      );
      final decision = gate.evaluate(
        item: item,
        mode: CreativeExecutionMode.playback,
        requireDeterministic: false,
      );
      expect(decision.allowed, isTrue);
    });
  });
}

CreativeLibraryItemDefinition _buildItem({
  required String id,
  required bool previewSupported,
  required bool exportSupported,
  required bool deterministic,
}) {
  final conformance = RendererConformanceDefinition(
    previewSupported: previewSupported,
    exportSupported: exportSupported,
    deterministic: deterministic,
    rendererPath: 'stage5.native',
    exportPath: 'stage6.export',
    fallbackMode: exportSupported ? 'none' : 'prerender_only',
  );
  return CreativeLibraryItemDefinition(
    id: id,
    version: '1.0.0',
    kind: CreativeLibraryItemKind.effect,
    title: id,
    description: 'test item',
    category: 'test',
    tags: const <String>['test'],
    sourceInspiration: 'internal',
    licenseStatus: 'internal',
    supportedNodeFamilies: const <String>['video'],
    parameterSchema: const <String, Object?>{},
    defaultParams: const <String, Object?>{},
    requiredAssets: const <String>[],
    supportedAspectRatios: const <String>['9:16'],
    defaultDurationMs: 1000,
    timelineBehavior: 'clip',
    spatialBehavior: 'layer',
    compileContract: 'contract',
    loweringContract: 'contract',
    manualUiControls: const <ManualUiControlDefinition>[],
    mcpExamples: const <McpToolExposureDefinition>[],
    pasteScriptExamples: const <String>[],
    templateExamples: const <String>[],
    previewPoster: '',
    previewMotion: '',
    qaRules: const <QaRuleDefinition>[],
    rendererConformance: conformance,
    exportConformance: conformance,
    capabilityBenchmark: CapabilityBenchmarkRecord(
      capabilityId: id,
      capabilityFamily: 'effect',
      benchmarkVersion: '1',
      comparedAgainst: const <String>['refusion'],
      visualQuality: 5,
      temporalAccuracy: 5,
      parameterDepth: 5,
      performance: 5,
      previewExportParity: 5,
      editability: 5,
      determinism: deterministic ? 5 : 3,
      crossDeviceStability: 5,
      pipelineCoverage: 5,
      agentUsability: 5,
      codeReferences: const <String>['ref'],
      benchmarkScenes: const <String>['scene'],
      measurementResults: const <String>['result'],
    ),
    benchmarkDecision: CapabilityBenchmarkDecision.keep,
    legacyPathCleanup: const <String, LegacyPathCleanupDecision>{
      'mcp': LegacyPathCleanupDecision.canonicalize,
    },
    supportedEntrySurfaces: const <SupportedEntrySurface>{
      SupportedEntrySurface.mcp,
      SupportedEntrySurface.manualUi,
    },
    failureMode: 'fail_closed',
  );
}
