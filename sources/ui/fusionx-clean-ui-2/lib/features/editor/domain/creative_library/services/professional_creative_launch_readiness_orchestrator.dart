import '../../mcp/refusion_creative_library_discovery.dart';
import '../models/professional_creative_library_discovery_models.dart';
import '../models/professional_creative_library_registry_models.dart';
import 'professional_creative_agent_skill_generation_service.dart';
import 'professional_creative_launch_readiness_gate.dart';
import 'professional_creative_library_discovery_service.dart';
import 'professional_creative_library_registry.dart';
import 'professional_creative_manual_ui_library_browser_service.dart';

class CreativeLaunchReadinessEvaluationContext {
  const CreativeLaunchReadinessEvaluationContext({
    required this.skillMarkdown,
    required this.fullAcceptanceSuitePassRate,
    required this.regressionSuiteGreen,
    required this.registryDiffReviewed,
    required this.skillsSyncPass,
    required this.conformanceSnapshotsApproved,
    this.exportUnsupportedSilentPassCount = 0,
  });

  final String skillMarkdown;
  final double fullAcceptanceSuitePassRate;
  final bool regressionSuiteGreen;
  final bool registryDiffReviewed;
  final bool skillsSyncPass;
  final bool conformanceSnapshotsApproved;
  final int exportUnsupportedSilentPassCount;
}

class CreativeLaunchReadinessOrchestratorReport {
  const CreativeLaunchReadinessOrchestratorReport({
    required this.result,
    required this.input,
    required this.metrics,
  });

  final CreativeLaunchReadinessResult result;
  final CreativeLaunchReadinessInput input;
  final Map<String, Object?> metrics;
}

class ProfessionalCreativeLaunchReadinessOrchestrator {
  const ProfessionalCreativeLaunchReadinessOrchestrator({
    required ProfessionalCreativeLibraryRegistry registry,
    required ProfessionalCreativeLibraryDiscoveryService discovery,
    required ProfessionalCreativeManualUiLibraryBrowserService manualBrowser,
    required RefusionCreativeLibraryDiscoveryToolset mcpDiscoveryTools,
    required ProfessionalCreativeAgentSkillGenerationService skillService,
    ProfessionalCreativeLaunchReadinessGate launchGate =
        const ProfessionalCreativeLaunchReadinessGate(),
  })  : _registry = registry,
        _discovery = discovery,
        _manualBrowser = manualBrowser,
        _mcpDiscoveryTools = mcpDiscoveryTools,
        _skillService = skillService,
        _launchGate = launchGate;

  final ProfessionalCreativeLibraryRegistry _registry;
  final ProfessionalCreativeLibraryDiscoveryService _discovery;
  final ProfessionalCreativeManualUiLibraryBrowserService _manualBrowser;
  final RefusionCreativeLibraryDiscoveryToolset _mcpDiscoveryTools;
  final ProfessionalCreativeAgentSkillGenerationService _skillService;
  final ProfessionalCreativeLaunchReadinessGate _launchGate;

  CreativeLaunchReadinessOrchestratorReport evaluate(
    CreativeLaunchReadinessEvaluationContext context,
  ) {
    final schemaIssues = _registry.validateSchema();
    final skillReport = _skillService.validateMarkdown(context.skillMarkdown);
    final manualSnapshot = _manualBrowser.browse();
    final mcpSnapshot = CreativeManualUiLibraryBrowserSnapshot(
      components: _fromMcpFamily(
        _mcpDiscoveryTools.invoke(toolName: 'list_components'),
      ),
      effects: _fromMcpFamily(
        _mcpDiscoveryTools.invoke(toolName: 'list_effects'),
      ),
      motionRecipes: _fromMcpFamily(
        _mcpDiscoveryTools.invoke(toolName: 'list_motion_recipes'),
      ),
      templates: _fromMcpFamily(
        _mcpDiscoveryTools.invoke(toolName: 'list_templates'),
      ),
      icons: _fromMcpFamily(
        _mcpDiscoveryTools.invoke(toolName: 'list_icons'),
      ),
    );
    final parity = _manualBrowser.validateParity(
      manualUiSnapshot: manualSnapshot,
      mcpSnapshot: mcpSnapshot,
    );

    final adapterDirectMutationCount = _registry.adapters
        .map((adapter) => adapter.directMutationCount)
        .fold<int>(0, (sum, value) => sum + value);
    final rendererConformanceUnknownCount = _registry
        .listAll()
        .where((item) =>
            item.rendererConformance.fallbackMode.trim().toLowerCase() ==
                'unknown' ||
            item.exportConformance.fallbackMode.trim().toLowerCase() ==
                'unknown')
        .length;

    final input = CreativeLaunchReadinessInput(
      fullAcceptanceSuitePassRate: context.fullAcceptanceSuitePassRate,
      staleSkillReferenceCount: skillReport.staleSkillReferenceCount,
      manualUiMcpMatchRatio: parity.matchRatio,
      adapterDirectMutationCount: adapterDirectMutationCount,
      exportUnsupportedSilentPassCount:
          context.exportUnsupportedSilentPassCount,
      registrySchemaIssueCount: schemaIssues.length,
      rendererConformanceUnknownCount: rendererConformanceUnknownCount,
      regressionSuiteGreen: context.regressionSuiteGreen,
      registryDiffReviewed: context.registryDiffReviewed,
      skillsSyncPass: context.skillsSyncPass,
      conformanceSnapshotsApproved: context.conformanceSnapshotsApproved,
    );
    final result = _launchGate.evaluate(input);
    return CreativeLaunchReadinessOrchestratorReport(
      result: result,
      input: input,
      metrics: <String, Object?>{
        'registrySchemaIssueCount': schemaIssues.length,
        'staleSkillReferenceCount': skillReport.staleSkillReferenceCount,
        'manualUiMcpMatchRatio': parity.matchRatio,
        'adapterDirectMutationCount': adapterDirectMutationCount,
        'rendererConformanceUnknownCount': rendererConformanceUnknownCount,
        'discoveryFamilyCount':
            _discovery.listTemplates().items.isNotEmpty ? 5 : 4,
      },
    );
  }

  CreativeLibraryDiscoveryListResponse _fromMcpFamily(
    Map<String, Object?> payload,
  ) {
    final family = payload['family'] as String? ?? 'unknown';
    final rows = (payload['items'] as List? ?? const <Object?>[])
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
    final items = rows
        .map(
          (row) => CreativeLibraryDiscoveryListItem(
            id: row['id'] as String? ?? '',
            title: row['title'] as String? ?? '',
            kind: _parseKind(row['kind'] as String?),
            category: row['category'] as String? ?? '',
            tags: (row['tags'] as List? ?? const <Object?>[])
                .whereType<String>()
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    return CreativeLibraryDiscoveryListResponse(family: family, items: items);
  }

  CreativeLibraryItemKind _parseKind(String? raw) {
    switch (raw) {
      case 'component':
        return CreativeLibraryItemKind.component;
      case 'effect':
        return CreativeLibraryItemKind.effect;
      case 'motionRecipe':
        return CreativeLibraryItemKind.motionRecipe;
      case 'template':
        return CreativeLibraryItemKind.template;
      case 'icon':
        return CreativeLibraryItemKind.icon;
      case 'expression':
        return CreativeLibraryItemKind.expression;
      default:
        return CreativeLibraryItemKind.component;
    }
  }
}
