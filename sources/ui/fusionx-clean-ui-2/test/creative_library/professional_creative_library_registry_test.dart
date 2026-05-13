import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_registry.dart';

void main() {
  group('PNCLE-01 Registry Core', () {
    test('registry_schema_validation_pass = 100% for valid wrapped item', () {
      final registry = ProfessionalCreativeLibraryRegistry(
        items: <CreativeLibraryItemDefinition>[
          _sampleMotionRecipeItem(),
        ],
        adapters: <EntrySurfaceAdapterDefinition>[
          const EntrySurfaceAdapterDefinition(
            id: 'adapter.manualUi',
            surface: SupportedEntrySurface.manualUi,
            commandFamilies: <CommandFamilyDefinition>{
              CommandFamilyDefinition.applyMotionRecipe,
            },
            emitsEnvelope: true,
            directMutationCount: 0,
          ),
        ],
      );

      final issues = registry.validateSchema();
      expect(issues, isEmpty);
      expect(registry.hasParallelTruthPaths, isFalse);
      expect(
        registry.capabilityCountsByKind()[
            CreativeLibraryItemKind.motionRecipe.name],
        1,
      );
    });

    test('fails when cleanup decisions and evidence are incomplete', () {
      final badItem = _sampleMotionRecipeItem(
        overrideId: r'$motion.invalid',
        benchmark: const CapabilityBenchmarkRecord(
          capabilityId: r'$motion.invalid',
          capabilityFamily: 'motionRecipe',
          benchmarkVersion: 'v1',
          comparedAgainst: <String>['refusion'],
          visualQuality: 6,
          temporalAccuracy: 4,
          parameterDepth: 4,
          performance: 4,
          previewExportParity: 4,
          editability: 4,
          determinism: 4,
          crossDeviceStability: 4,
          pipelineCoverage: 4,
          agentUsability: 4,
          codeReferences: <String>[],
          benchmarkScenes: <String>[],
          measurementResults: <String>[],
        ),
        cleanup: <String, LegacyPathCleanupDecision>{
          'manualUiPath': LegacyPathCleanupDecision.canonicalize,
        },
      );

      final registry = ProfessionalCreativeLibraryRegistry(
        items: <CreativeLibraryItemDefinition>[badItem],
      );

      final issues = registry.validateSchema();
      expect(issues, isNotEmpty);
      expect(
        issues.any(
          (issue) => issue.message.contains('capabilityBenchmark scores'),
        ),
        isTrue,
      );
      expect(
        issues.any(
          (issue) =>
              issue.message.contains('legacyPathCleanup missing decision'),
        ),
        isTrue,
      );
    });
  });
}

MotionRecipeDefinition _sampleMotionRecipeItem({
  String overrideId = r'$motion.popInSpring',
  CapabilityBenchmarkRecord? benchmark,
  Map<String, LegacyPathCleanupDecision>? cleanup,
}) {
  const cleanupDefault = <String, LegacyPathCleanupDecision>{
    'manualUiPath': LegacyPathCleanupDecision.canonicalize,
    'mcpPath': LegacyPathCleanupDecision.canonicalize,
    'pasteScriptPath': LegacyPathCleanupDecision.adapterOnly,
    'templatePath': LegacyPathCleanupDecision.canonicalize,
    'tapListPath': LegacyPathCleanupDecision.adapterOnly,
    'legacyLocalMutationPath': LegacyPathCleanupDecision.migrate,
    'rendererOnlyPath': LegacyPathCleanupDecision.canonicalize,
    'databaseOnlyPath': LegacyPathCleanupDecision.block,
    'metadataOnlyPath': LegacyPathCleanupDecision.delete,
    'exportOnlyPath': LegacyPathCleanupDecision.canonicalize,
  };

  const renderer = RendererConformanceDefinition(
    previewSupported: true,
    exportSupported: true,
    deterministic: true,
    rendererPath:
        'lib/features/editor/domain/services/master_render_graph_adapter.dart',
    exportPath:
        'lib/features/editor/domain/models/export_composition_models.dart',
    fallbackMode: 'none',
  );

  return MotionRecipeDefinition(
    id: overrideId,
    version: 'v1',
    title: 'Pop In Spring',
    description: 'Spring entrance motion recipe for component reveal.',
    category: 'motion',
    tags: const <String>['spring', 'entrance'],
    sourceInspiration: 'Refusion native motion recipe library',
    licenseStatus: 'internal',
    supportedNodeFamilies: const <String>['component', 'text'],
    parameterSchema: const <String, Object?>{
      'durationMs': <String, Object?>{'type': 'number', 'minimum': 16},
    },
    defaultParams: const <String, Object?>{'durationMs': 680},
    requiredAssets: const <String>[],
    supportedAspectRatios: const <String>['16:9', '9:16', '1:1'],
    defaultDurationMs: 680,
    timelineBehavior: 'keyframeDriven',
    spatialBehavior: '2dTransform',
    compileContract: 'applyMotionRecipe -> applyKeyframes',
    loweringContract: 'SceneProgram channels -> MotionPropertyCatalog',
    manualUiControls: const <ManualUiControlDefinition>[
      ManualUiControlDefinition(
        id: 'durationMs',
        label: 'Duration',
        controlType: 'slider',
        defaultValue: 680,
      ),
    ],
    mcpExamples: const <McpToolExposureDefinition>[
      McpToolExposureDefinition(
        toolName: 'refusion.apply_motion_patch',
        mode: 'mutating',
        notes: 'Compiled through canonical command envelope.',
      ),
    ],
    pasteScriptExamples: const <String>['apply_motion_recipe(popInSpring)'],
    templateExamples: const <String>['template.chat_prompt_entry'],
    previewPoster: 'assets/previews/motion/pop_in_spring.png',
    previewMotion: 'assets/previews/motion/pop_in_spring.mp4',
    qaRules: const <QaRuleDefinition>[
      QaRuleDefinition(
        id: 'qa.motion.no_metadata_only_success',
        description: 'Reject metadata-only motion apply result.',
        severity: 'error',
      ),
    ],
    rendererConformance: renderer,
    exportConformance: renderer,
    capabilityBenchmark: benchmark ??
        const CapabilityBenchmarkRecord(
          capabilityId: r'$motion.popInSpring',
          capabilityFamily: 'motionRecipe',
          benchmarkVersion: 'v1',
          comparedAgainst: <String>['refusion', 'remotion', 'hyperframes'],
          visualQuality: 4,
          temporalAccuracy: 4,
          parameterDepth: 4,
          performance: 4,
          previewExportParity: 4,
          editability: 4,
          determinism: 4,
          crossDeviceStability: 4,
          pipelineCoverage: 4,
          agentUsability: 4,
          codeReferences: <String>[
            'lib/features/editor/domain/services/scene_motion_recipe_library.dart',
            'lib/features/editor/domain/services/refusion_motion_patch_applicator.dart',
          ],
          benchmarkScenes: <String>[
            'fast_linear_motion',
            'kinetic_text_entry',
          ],
          measurementResults: <String>[
            'visual_diff<=0.03',
            'parity_delta_frames=0',
          ],
        ),
    benchmarkDecision: CapabilityBenchmarkDecision.wrap,
    legacyPathCleanup: cleanup ?? cleanupDefault,
    supportedEntrySurfaces: const <SupportedEntrySurface>{
      SupportedEntrySurface.manualUi,
      SupportedEntrySurface.mcp,
      SupportedEntrySurface.pasteScript,
      SupportedEntrySurface.template,
    },
    failureMode: 'blocked',
    speedyGraphPreset: 'slowFastSlow',
  );
}
