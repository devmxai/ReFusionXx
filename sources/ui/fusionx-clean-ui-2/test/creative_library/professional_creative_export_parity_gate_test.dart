import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_command_lowerer.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_export_parity_gate.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_registry.dart';

void main() {
  group('PNCLE-07B Export Parity Gate', () {
    test('blocks export for preview-only capability', () {
      final registry = ProfessionalCreativeLibraryRegistry(
        items: <CreativeLibraryItemDefinition>[
          _buildItem(
            id: r'$effect.previewOnly',
            previewSupported: true,
            exportSupported: false,
            deterministic: true,
          ),
        ],
      );
      const gate = ProfessionalCreativeExportParityGate();

      final result = gate.evaluate(
        registry: registry,
        capabilityIds: const <String>{r'$effect.previewOnly'},
        projection: _visibleProjection(),
      );

      expect(result.ready, isFalse);
      expect(result.issues.single.code,
          CreativeExportParityIssueCode.exportNotSupported);
    });

    test('blocks when projection truth is missing', () {
      final registry = ProfessionalCreativeLibraryRegistry(
        items: <CreativeLibraryItemDefinition>[
          _buildItem(
            id: r'$effect.motionBlur',
            previewSupported: true,
            exportSupported: true,
            deterministic: true,
          ),
        ],
      );
      const gate = ProfessionalCreativeExportParityGate();

      const projection = CreativeLoweringProjection(ok: true);
      final result = gate.evaluate(
        registry: registry,
        capabilityIds: const <String>{r'$effect.motionBlur'},
        projection: projection,
      );

      expect(result.ready, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.code ==
              CreativeExportParityIssueCode.projectionGraphTruthMissing,
        ),
        isTrue,
      );
      expect(
        result.issues.any(
          (issue) =>
              issue.code ==
              CreativeExportParityIssueCode.projectionTimelineTruthMissing,
        ),
        isTrue,
      );
    });

    test('passes when capability and projection are export-ready', () {
      final registry = ProfessionalCreativeLibraryRegistry(
        items: <CreativeLibraryItemDefinition>[
          _buildItem(
            id: r'$motion.popUpSpring',
            previewSupported: true,
            exportSupported: true,
            deterministic: true,
            kind: CreativeLibraryItemKind.motionRecipe,
          ),
        ],
      );
      const gate = ProfessionalCreativeExportParityGate();

      final result = gate.evaluate(
        registry: registry,
        capabilityIds: const <String>{r'$motion.popUpSpring'},
        projection: _visibleProjection(),
      );

      expect(result.ready, isTrue);
      expect(result.issues, isEmpty);
      expect(result.parityScore, 1.0);
      expect(result.capabilitiesPassed, 1);
    });
  });
}

CreativeLoweringProjection _visibleProjection() {
  return const CreativeLoweringProjection(
    ok: true,
    graphNodes: <Map<String, Object?>>[
      <String, Object?>{'id': 'node.1'},
    ],
    timelineClips: <Map<String, Object?>>[
      <String, Object?>{'id': 'clip.1'},
    ],
  );
}

CreativeLibraryItemDefinition _buildItem({
  required String id,
  required bool previewSupported,
  required bool exportSupported,
  required bool deterministic,
  CreativeLibraryItemKind kind = CreativeLibraryItemKind.effect,
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
    kind: kind,
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
      capabilityFamily: kind.name,
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
      'manualUiPath': LegacyPathCleanupDecision.canonicalize,
      'mcpPath': LegacyPathCleanupDecision.canonicalize,
      'pasteScriptPath': LegacyPathCleanupDecision.canonicalize,
      'templatePath': LegacyPathCleanupDecision.canonicalize,
      'tapListPath': LegacyPathCleanupDecision.canonicalize,
      'legacyLocalMutationPath': LegacyPathCleanupDecision.block,
      'rendererOnlyPath': LegacyPathCleanupDecision.block,
      'databaseOnlyPath': LegacyPathCleanupDecision.block,
      'metadataOnlyPath': LegacyPathCleanupDecision.block,
      'exportOnlyPath': LegacyPathCleanupDecision.block,
    },
    supportedEntrySurfaces: const <SupportedEntrySurface>{
      SupportedEntrySurface.mcp,
      SupportedEntrySurface.manualUi,
    },
    failureMode: 'fail_closed',
  );
}
