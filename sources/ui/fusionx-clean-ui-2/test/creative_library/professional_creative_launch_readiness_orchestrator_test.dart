import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_agent_skill_generation_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_launch_readiness_orchestrator.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_discovery_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_manual_ui_library_browser_service.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_creative_library_discovery.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';

void main() {
  group('Launch Readiness Orchestrator', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    final discovery = ProfessionalCreativeLibraryDiscoveryService(
      registry: registry,
    );
    final manualBrowser = ProfessionalCreativeManualUiLibraryBrowserService(
      discovery: discovery,
    );
    final mcpToolset = RefusionCreativeLibraryDiscoveryToolset(
      discovery: discovery,
    );
    final skillService = ProfessionalCreativeAgentSkillGenerationService(
      registry: registry,
      toolRegistry: RefusionMcpToolRegistry(),
    );
    final orchestrator = ProfessionalCreativeLaunchReadinessOrchestrator(
      registry: registry,
      discovery: discovery,
      manualBrowser: manualBrowser,
      mcpDiscoveryTools: mcpToolset,
      skillService: skillService,
    );

    test('evaluates ready when canonical checks and governance pass', () {
      final markdown = File(
        'docs/refusion_mcp_agent_control_skill.md',
      ).readAsStringSync();
      final report = orchestrator.evaluate(
        CreativeLaunchReadinessEvaluationContext(
          skillMarkdown: markdown,
          fullAcceptanceSuitePassRate: 1.0,
          regressionSuiteGreen: true,
          registryDiffReviewed: true,
          skillsSyncPass: true,
          conformanceSnapshotsApproved: true,
        ),
      );

      expect(report.result.ready, isTrue);
      expect(report.input.staleSkillReferenceCount, 0);
      expect(report.input.manualUiMcpMatchRatio, 1.0);
      expect(report.input.adapterDirectMutationCount, 0);
    });

    test('blocks when stale skill references exist', () {
      const badMarkdown = '''
Use `refusion.tool_that_does_not_exist`.
''';
      final report = orchestrator.evaluate(
        const CreativeLaunchReadinessEvaluationContext(
          skillMarkdown: badMarkdown,
          fullAcceptanceSuitePassRate: 1.0,
          regressionSuiteGreen: true,
          registryDiffReviewed: true,
          skillsSyncPass: true,
          conformanceSnapshotsApproved: true,
        ),
      );

      expect(report.result.ready, isFalse);
      expect(report.input.staleSkillReferenceCount, greaterThan(0));
      expect(
        report.result.issues.any(
          (issue) => issue.code == 'STALE_SKILL_REFERENCES_PRESENT',
        ),
        isTrue,
      );
    });
  });
}
