import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_agent_skill_generation_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_launch_readiness_orchestrator.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_discovery_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_manual_ui_library_browser_service.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_creative_launch_readiness.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_creative_library_discovery.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';

void main() {
  group('RefusionCreativeLaunchReadinessToolset', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    final discovery = ProfessionalCreativeLibraryDiscoveryService(
      registry: registry,
    );
    final manualBrowser = ProfessionalCreativeManualUiLibraryBrowserService(
      discovery: discovery,
    );
    final mcpDiscovery = RefusionCreativeLibraryDiscoveryToolset(
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
      mcpDiscoveryTools: mcpDiscovery,
      skillService: skillService,
    );
    final toolset = RefusionCreativeLaunchReadinessToolset(
      orchestrator: orchestrator,
    );

    test('returns ready report when contracts pass', () {
      final markdown = File(
        'docs/refusion_mcp_agent_control_skill.md',
      ).readAsStringSync();
      final response = toolset.invoke(
        toolName: 'get_launch_readiness',
        payload: <String, Object?>{
          'skillMarkdown': markdown,
          'fullAcceptanceSuitePassRate': 1.0,
          'regressionSuiteGreen': true,
          'registryDiffReviewed': true,
          'skillsSyncPass': true,
          'conformanceSnapshotsApproved': true,
        },
      );

      expect(response['ok'], isTrue);
      expect(response['ready'], isTrue);
      expect(response['issues'], isA<List>());
      expect(response['metrics'], isA<Map>());
    });

    test('fails closed when skill markdown is missing', () {
      final response = toolset.invoke(
        toolName: 'get_launch_readiness',
      );

      expect(response['error'], 'skill_markdown_required');
    });

    test('unsupported tool returns deterministic error payload', () {
      final response = toolset.invoke(
        toolName: 'launch_now',
      );

      expect(response['error'], 'unsupported_launch_readiness_tool');
    });
  });
}
