import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_template_control_contract.dart';

void main() {
  group('PNCLE-11 Template Control Contract', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    const builder = ProfessionalTemplateControlContractBuilder();

    test('builds exposed controls from template definition', () {
      final template = registry
          .listByKind(CreativeLibraryItemKind.template)
          .first as TemplateDefinition;
      final snapshot = builder.build(template);

      expect(snapshot.templateCapabilityId, template.id);
      expect(snapshot.controls, isNotEmpty);
      expect(snapshot.slots, isNotEmpty);
      expect(snapshot.bindings, isNotEmpty);
    });

    test('hides advanced controls in basic edit mode', () {
      final template = _testTemplateWithAdvancedControl();
      final snapshot = builder.build(template);

      final basicVisible = builder.visibleControls(
        snapshot,
        advancedEditModeEnabled: false,
      );
      final advancedVisible = builder.visibleControls(
        snapshot,
        advancedEditModeEnabled: true,
      );

      expect(
        basicVisible.any((control) => control.id == 'debug_internal_curve'),
        isFalse,
      );
      expect(
        advancedVisible.any((control) => control.id == 'debug_internal_curve'),
        isTrue,
      );
    });

    test('validation fails when no visible controls in current mode', () {
      final template = _advancedOnlyTemplate();
      final snapshot = builder.build(template);
      final result = builder.validate(
        snapshot,
        advancedEditModeEnabled: false,
      );

      expect(result.ok, isFalse);
      expect(
        result.rules.any((rule) => rule.id == 'template.controls.none_visible'),
        isTrue,
      );
    });
  });
}

TemplateDefinition _testTemplateWithAdvancedControl() {
  return TemplateDefinition(
    id: '\$template.test.controls',
    version: 'v1',
    title: 'Test Controls',
    description: 'Template for exposed controls test.',
    category: 'template.test',
    tags: const <String>['test'],
    sourceInspiration: 'internal',
    licenseStatus: 'internal',
    supportedNodeFamilies: const <String>['text'],
    parameterSchema: const <String, Object?>{
      'headline': <String, Object?>{'type': 'string'},
      'debug_internal_curve': <String, Object?>{'type': 'number'},
    },
    defaultParams: const <String, Object?>{
      'headline': 'Hello',
      'debug_internal_curve': 0.42,
    },
    requiredAssets: const <String>[],
    supportedAspectRatios: const <String>['9:16'],
    defaultDurationMs: 1200,
    timelineBehavior: 'templateCompiled',
    spatialBehavior: 'absoluteCanvas',
    compileContract: 'template -> scene program',
    loweringContract: 'template -> graph',
    manualUiControls: const <ManualUiControlDefinition>[
      ManualUiControlDefinition(
        id: 'headline',
        label: 'Headline',
        controlType: 'text',
      ),
      ManualUiControlDefinition(
        id: 'debug_internal_curve',
        label: 'Internal Curve',
        controlType: 'number',
      ),
    ],
    mcpExamples: const <McpToolExposureDefinition>[
      McpToolExposureDefinition(
        toolName: 'refusion.update_exposed_control',
        mode: 'mutating',
        notes: 'Update exposed control value.',
      ),
    ],
    pasteScriptExamples: const <String>[],
    templateExamples: const <String>[],
    previewPoster: '',
    previewMotion: '',
    qaRules: const <QaRuleDefinition>[],
    rendererConformance: const RendererConformanceDefinition(
      previewSupported: true,
      exportSupported: true,
      deterministic: true,
      rendererPath: 'stage5.native',
      exportPath: 'stage6.export',
      fallbackMode: 'none',
    ),
    exportConformance: const RendererConformanceDefinition(
      previewSupported: true,
      exportSupported: true,
      deterministic: true,
      rendererPath: 'stage5.native',
      exportPath: 'stage6.export',
      fallbackMode: 'none',
    ),
    capabilityBenchmark: const CapabilityBenchmarkRecord(
      capabilityId: '\$template.test.controls',
      capabilityFamily: 'template',
      benchmarkVersion: '1',
      comparedAgainst: <String>['refusion'],
      visualQuality: 5,
      temporalAccuracy: 5,
      parameterDepth: 5,
      performance: 5,
      previewExportParity: 5,
      editability: 5,
      determinism: 5,
      crossDeviceStability: 5,
      pipelineCoverage: 5,
      agentUsability: 5,
      codeReferences: <String>['test'],
      benchmarkScenes: <String>['test'],
      measurementResults: <String>['test'],
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
      SupportedEntrySurface.template,
      SupportedEntrySurface.manualUi,
    },
    failureMode: 'fail_closed',
  );
}

TemplateDefinition _advancedOnlyTemplate() {
  return _testTemplateWithAdvancedControl().copyWithForAdvancedOnly();
}

extension _TemplateTestCopy on TemplateDefinition {
  TemplateDefinition copyWithForAdvancedOnly() {
    return TemplateDefinition(
      id: id,
      version: version,
      title: title,
      description: description,
      category: category,
      tags: tags,
      sourceInspiration: sourceInspiration,
      licenseStatus: licenseStatus,
      supportedNodeFamilies: supportedNodeFamilies,
      parameterSchema: const <String, Object?>{
        'debug_internal_curve': <String, Object?>{'type': 'number'},
      },
      defaultParams: const <String, Object?>{
        'debug_internal_curve': 0.42,
      },
      requiredAssets: requiredAssets,
      supportedAspectRatios: supportedAspectRatios,
      defaultDurationMs: defaultDurationMs,
      timelineBehavior: timelineBehavior,
      spatialBehavior: spatialBehavior,
      compileContract: compileContract,
      loweringContract: loweringContract,
      manualUiControls: const <ManualUiControlDefinition>[
        ManualUiControlDefinition(
          id: 'debug_internal_curve',
          label: 'Internal Curve',
          controlType: 'number',
        ),
      ],
      mcpExamples: mcpExamples,
      pasteScriptExamples: pasteScriptExamples,
      templateExamples: templateExamples,
      previewPoster: previewPoster,
      previewMotion: previewMotion,
      qaRules: qaRules,
      rendererConformance: rendererConformance,
      exportConformance: exportConformance,
      capabilityBenchmark: capabilityBenchmark,
      benchmarkDecision: benchmarkDecision,
      legacyPathCleanup: legacyPathCleanup,
      supportedEntrySurfaces: supportedEntrySurfaces,
      failureMode: failureMode,
    );
  }
}
