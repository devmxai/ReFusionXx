import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_agent_skill_generation_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_launch_readiness_orchestrator.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_discovery_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_manual_ui_library_browser_service.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_creative_launch_readiness.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_creative_library_discovery.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_creative_runtime_adapter.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_mcp_tool_registry.dart';

void main() {
  group('RefusionMcpCreativeRuntimeAdapter', () {
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
    final launchReadiness = RefusionCreativeLaunchReadinessToolset(
      orchestrator: orchestrator,
    );
    final adapter = RefusionMcpCreativeRuntimeAdapter(
      discoveryToolset: mcpDiscovery,
      launchReadinessToolset: launchReadiness,
    );

    test('forwards creative discovery calls through discovery reader', () {
      final payload = adapter.discoveryReader(
        toolName: 'list_components',
      );
      final items = (payload['items'] as List).cast<Map<String, Object?>>();
      expect(items, isNotEmpty);
      expect(payload['family'], 'components');
    });

    test('forwards launch readiness through launch reader', () {
      final markdown = File(
        'docs/refusion_mcp_agent_control_skill.md',
      ).readAsStringSync();
      final payload = adapter.launchReadinessReader(
        <String, Object?>{
          'skillMarkdown': markdown,
          'fullAcceptanceSuitePassRate': 1.0,
          'regressionSuiteGreen': true,
          'registryDiffReviewed': true,
          'skillsSyncPass': true,
          'conformanceSnapshotsApproved': true,
        },
      );
      expect(payload['ok'], isTrue);
      expect(payload.containsKey('ready'), isTrue);
      expect(payload.containsKey('issues'), isTrue);
    });
  });
}
