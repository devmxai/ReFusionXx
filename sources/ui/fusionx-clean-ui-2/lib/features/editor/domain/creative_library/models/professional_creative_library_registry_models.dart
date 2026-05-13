enum CreativeLibraryItemKind {
  component,
  effect,
  motionRecipe,
  template,
  icon,
  expression,
}

enum CapabilityBenchmarkDecision {
  keep,
  wrap,
  upgrade,
  adoptIdea,
  replace,
  prerenderOnly,
  blocked,
  reject,
}

enum LegacyPathCleanupDecision {
  canonicalize,
  adapterOnly,
  featureFlag,
  migrate,
  delete,
  block,
}

enum SupportedEntrySurface {
  manualUi,
  mcp,
  pasteScript,
  template,
  tapList,
  futureTool,
}

enum CommandFamilyDefinition {
  insertComponent,
  updateComponent,
  insertTemplate,
  compileTemplate,
  insertText,
  updateText,
  setTypography,
  insertShape,
  updateShape,
  insertMedia,
  updateMediaBinding,
  setLayout,
  setTransform,
  applyEffect,
  updateEffect,
  removeEffect,
  applyMotionRecipe,
  applyKeyframes,
  editKeyframe,
  applyTransition,
  updateTransition,
  insertAdjustmentLayer,
  updateExposedControl,
  deleteNode,
  groupNodes,
  ungroupNodes,
}

class RendererConformanceDefinition {
  const RendererConformanceDefinition({
    required this.previewSupported,
    required this.exportSupported,
    required this.deterministic,
    required this.rendererPath,
    required this.exportPath,
    required this.fallbackMode,
  });

  final bool previewSupported;
  final bool exportSupported;
  final bool deterministic;
  final String rendererPath;
  final String exportPath;
  final String fallbackMode;
}

class ManualUiControlDefinition {
  const ManualUiControlDefinition({
    required this.id,
    required this.label,
    required this.controlType,
    this.defaultValue,
  });

  final String id;
  final String label;
  final String controlType;
  final Object? defaultValue;
}

class McpToolExposureDefinition {
  const McpToolExposureDefinition({
    required this.toolName,
    required this.mode,
    required this.notes,
  });

  final String toolName;
  final String mode;
  final String notes;
}

class QaRuleDefinition {
  const QaRuleDefinition({
    required this.id,
    required this.description,
    required this.severity,
  });

  final String id;
  final String description;
  final String severity;
}

class CapabilityBenchmarkRecord {
  const CapabilityBenchmarkRecord({
    required this.capabilityId,
    required this.capabilityFamily,
    required this.benchmarkVersion,
    required this.comparedAgainst,
    required this.visualQuality,
    required this.temporalAccuracy,
    required this.parameterDepth,
    required this.performance,
    required this.previewExportParity,
    required this.editability,
    required this.determinism,
    required this.crossDeviceStability,
    required this.pipelineCoverage,
    required this.agentUsability,
    required this.codeReferences,
    required this.benchmarkScenes,
    required this.measurementResults,
    this.strengths = const <String>[],
    this.weaknesses = const <String>[],
    this.requiredUpgrades = const <String>[],
  });

  final String capabilityId;
  final String capabilityFamily;
  final String benchmarkVersion;
  final List<String> comparedAgainst;
  final int visualQuality;
  final int temporalAccuracy;
  final int parameterDepth;
  final int performance;
  final int previewExportParity;
  final int editability;
  final int determinism;
  final int crossDeviceStability;
  final int pipelineCoverage;
  final int agentUsability;
  final List<String> codeReferences;
  final List<String> benchmarkScenes;
  final List<String> measurementResults;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> requiredUpgrades;

  bool get hasCompleteEvidence =>
      codeReferences.isNotEmpty &&
      benchmarkScenes.isNotEmpty &&
      measurementResults.isNotEmpty;

  bool get hasValidScores {
    const minScore = 1;
    const maxScore = 5;
    return <int>[
      visualQuality,
      temporalAccuracy,
      parameterDepth,
      performance,
      previewExportParity,
      editability,
      determinism,
      crossDeviceStability,
      pipelineCoverage,
      agentUsability,
    ].every((score) => score >= minScore && score <= maxScore);
  }
}

class CreativeLibraryItemDefinition {
  const CreativeLibraryItemDefinition({
    required this.id,
    required this.version,
    required this.kind,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.sourceInspiration,
    required this.licenseStatus,
    required this.supportedNodeFamilies,
    required this.parameterSchema,
    required this.defaultParams,
    required this.requiredAssets,
    required this.supportedAspectRatios,
    required this.defaultDurationMs,
    required this.timelineBehavior,
    required this.spatialBehavior,
    required this.compileContract,
    required this.loweringContract,
    required this.manualUiControls,
    required this.mcpExamples,
    required this.pasteScriptExamples,
    required this.templateExamples,
    required this.previewPoster,
    required this.previewMotion,
    required this.qaRules,
    required this.rendererConformance,
    required this.exportConformance,
    required this.capabilityBenchmark,
    required this.benchmarkDecision,
    required this.legacyPathCleanup,
    required this.supportedEntrySurfaces,
    required this.failureMode,
  });

  final String id;
  final String version;
  final CreativeLibraryItemKind kind;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final String sourceInspiration;
  final String licenseStatus;
  final List<String> supportedNodeFamilies;
  final Map<String, Object?> parameterSchema;
  final Map<String, Object?> defaultParams;
  final List<String> requiredAssets;
  final List<String> supportedAspectRatios;
  final int defaultDurationMs;
  final String timelineBehavior;
  final String spatialBehavior;
  final String compileContract;
  final String loweringContract;
  final List<ManualUiControlDefinition> manualUiControls;
  final List<McpToolExposureDefinition> mcpExamples;
  final List<String> pasteScriptExamples;
  final List<String> templateExamples;
  final String previewPoster;
  final String previewMotion;
  final List<QaRuleDefinition> qaRules;
  final RendererConformanceDefinition rendererConformance;
  final RendererConformanceDefinition exportConformance;
  final CapabilityBenchmarkRecord capabilityBenchmark;
  final CapabilityBenchmarkDecision benchmarkDecision;
  final Map<String, LegacyPathCleanupDecision> legacyPathCleanup;
  final Set<SupportedEntrySurface> supportedEntrySurfaces;
  final String failureMode;
}

class ComponentDefinition extends CreativeLibraryItemDefinition {
  const ComponentDefinition({
    required super.id,
    required super.version,
    required super.title,
    required super.description,
    required super.category,
    required super.tags,
    required super.sourceInspiration,
    required super.licenseStatus,
    required super.supportedNodeFamilies,
    required super.parameterSchema,
    required super.defaultParams,
    required super.requiredAssets,
    required super.supportedAspectRatios,
    required super.defaultDurationMs,
    required super.timelineBehavior,
    required super.spatialBehavior,
    required super.compileContract,
    required super.loweringContract,
    required super.manualUiControls,
    required super.mcpExamples,
    required super.pasteScriptExamples,
    required super.templateExamples,
    required super.previewPoster,
    required super.previewMotion,
    required super.qaRules,
    required super.rendererConformance,
    required super.exportConformance,
    required super.capabilityBenchmark,
    required super.benchmarkDecision,
    required super.legacyPathCleanup,
    required super.supportedEntrySurfaces,
    required super.failureMode,
    this.semanticType,
  }) : super(kind: CreativeLibraryItemKind.component);

  final String? semanticType;
}

class EffectDefinition extends CreativeLibraryItemDefinition {
  const EffectDefinition({
    required super.id,
    required super.version,
    required super.title,
    required super.description,
    required super.category,
    required super.tags,
    required super.sourceInspiration,
    required super.licenseStatus,
    required super.supportedNodeFamilies,
    required super.parameterSchema,
    required super.defaultParams,
    required super.requiredAssets,
    required super.supportedAspectRatios,
    required super.defaultDurationMs,
    required super.timelineBehavior,
    required super.spatialBehavior,
    required super.compileContract,
    required super.loweringContract,
    required super.manualUiControls,
    required super.mcpExamples,
    required super.pasteScriptExamples,
    required super.templateExamples,
    required super.previewPoster,
    required super.previewMotion,
    required super.qaRules,
    required super.rendererConformance,
    required super.exportConformance,
    required super.capabilityBenchmark,
    required super.benchmarkDecision,
    required super.legacyPathCleanup,
    required super.supportedEntrySurfaces,
    required super.failureMode,
    this.effectStackStage,
  }) : super(kind: CreativeLibraryItemKind.effect);

  final String? effectStackStage;
}

class MotionRecipeDefinition extends CreativeLibraryItemDefinition {
  const MotionRecipeDefinition({
    required super.id,
    required super.version,
    required super.title,
    required super.description,
    required super.category,
    required super.tags,
    required super.sourceInspiration,
    required super.licenseStatus,
    required super.supportedNodeFamilies,
    required super.parameterSchema,
    required super.defaultParams,
    required super.requiredAssets,
    required super.supportedAspectRatios,
    required super.defaultDurationMs,
    required super.timelineBehavior,
    required super.spatialBehavior,
    required super.compileContract,
    required super.loweringContract,
    required super.manualUiControls,
    required super.mcpExamples,
    required super.pasteScriptExamples,
    required super.templateExamples,
    required super.previewPoster,
    required super.previewMotion,
    required super.qaRules,
    required super.rendererConformance,
    required super.exportConformance,
    required super.capabilityBenchmark,
    required super.benchmarkDecision,
    required super.legacyPathCleanup,
    required super.supportedEntrySurfaces,
    required super.failureMode,
    this.speedyGraphPreset,
  }) : super(kind: CreativeLibraryItemKind.motionRecipe);

  final String? speedyGraphPreset;
}

class TemplateDefinition extends CreativeLibraryItemDefinition {
  const TemplateDefinition({
    required super.id,
    required super.version,
    required super.title,
    required super.description,
    required super.category,
    required super.tags,
    required super.sourceInspiration,
    required super.licenseStatus,
    required super.supportedNodeFamilies,
    required super.parameterSchema,
    required super.defaultParams,
    required super.requiredAssets,
    required super.supportedAspectRatios,
    required super.defaultDurationMs,
    required super.timelineBehavior,
    required super.spatialBehavior,
    required super.compileContract,
    required super.loweringContract,
    required super.manualUiControls,
    required super.mcpExamples,
    required super.pasteScriptExamples,
    required super.templateExamples,
    required super.previewPoster,
    required super.previewMotion,
    required super.qaRules,
    required super.rendererConformance,
    required super.exportConformance,
    required super.capabilityBenchmark,
    required super.benchmarkDecision,
    required super.legacyPathCleanup,
    required super.supportedEntrySurfaces,
    required super.failureMode,
  }) : super(kind: CreativeLibraryItemKind.template);
}

class IconDefinition extends CreativeLibraryItemDefinition {
  const IconDefinition({
    required super.id,
    required super.version,
    required super.title,
    required super.description,
    required super.category,
    required super.tags,
    required super.sourceInspiration,
    required super.licenseStatus,
    required super.supportedNodeFamilies,
    required super.parameterSchema,
    required super.defaultParams,
    required super.requiredAssets,
    required super.supportedAspectRatios,
    required super.defaultDurationMs,
    required super.timelineBehavior,
    required super.spatialBehavior,
    required super.compileContract,
    required super.loweringContract,
    required super.manualUiControls,
    required super.mcpExamples,
    required super.pasteScriptExamples,
    required super.templateExamples,
    required super.previewPoster,
    required super.previewMotion,
    required super.qaRules,
    required super.rendererConformance,
    required super.exportConformance,
    required super.capabilityBenchmark,
    required super.benchmarkDecision,
    required super.legacyPathCleanup,
    required super.supportedEntrySurfaces,
    required super.failureMode,
    this.iconName,
  }) : super(kind: CreativeLibraryItemKind.icon);

  final String? iconName;
}

class ExpressionDefinition extends CreativeLibraryItemDefinition {
  const ExpressionDefinition({
    required super.id,
    required super.version,
    required super.title,
    required super.description,
    required super.category,
    required super.tags,
    required super.sourceInspiration,
    required super.licenseStatus,
    required super.supportedNodeFamilies,
    required super.parameterSchema,
    required super.defaultParams,
    required super.requiredAssets,
    required super.supportedAspectRatios,
    required super.defaultDurationMs,
    required super.timelineBehavior,
    required super.spatialBehavior,
    required super.compileContract,
    required super.loweringContract,
    required super.manualUiControls,
    required super.mcpExamples,
    required super.pasteScriptExamples,
    required super.templateExamples,
    required super.previewPoster,
    required super.previewMotion,
    required super.qaRules,
    required super.rendererConformance,
    required super.exportConformance,
    required super.capabilityBenchmark,
    required super.benchmarkDecision,
    required super.legacyPathCleanup,
    required super.supportedEntrySurfaces,
    required super.failureMode,
  }) : super(kind: CreativeLibraryItemKind.expression);
}

class EntrySurfaceAdapterDefinition {
  const EntrySurfaceAdapterDefinition({
    required this.id,
    required this.surface,
    required this.commandFamilies,
    required this.emitsEnvelope,
    required this.directMutationCount,
  });

  final String id;
  final SupportedEntrySurface surface;
  final Set<CommandFamilyDefinition> commandFamilies;
  final bool emitsEnvelope;
  final int directMutationCount;
}

class ProfessionalSceneCommandEnvelope {
  const ProfessionalSceneCommandEnvelope({
    required this.commandFamily,
    required this.targetId,
    required this.payload,
    required this.surface,
    required this.dryRunEligible,
  });

  final CommandFamilyDefinition commandFamily;
  final String targetId;
  final Map<String, Object?> payload;
  final SupportedEntrySurface surface;
  final bool dryRunEligible;
}

class CreativeLibrarySchemaIssue {
  const CreativeLibrarySchemaIssue({
    required this.itemId,
    required this.message,
  });

  final String itemId;
  final String message;
}
