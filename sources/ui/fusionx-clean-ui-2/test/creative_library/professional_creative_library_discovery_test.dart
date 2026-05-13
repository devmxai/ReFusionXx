import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_discovery_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_creative_library_discovery.dart';

void main() {
  group('PNCLE-03 Read-only Discovery', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    final discovery = ProfessionalCreativeLibraryDiscoveryService(
      registry: registry,
    );
    final mcp = RefusionCreativeLibraryDiscoveryToolset(discovery: discovery);

    test('manual_ui_mcp_capability_match = 100%', () {
      final componentInternal =
          discovery.listComponents().items.map((item) => item.id).toSet();
      final effectInternal =
          discovery.listEffects().items.map((item) => item.id).toSet();
      final motionInternal =
          discovery.listMotionRecipes().items.map((item) => item.id).toSet();
      final templateInternal =
          discovery.listTemplates().items.map((item) => item.id).toSet();

      final componentMcp =
          ((mcp.invoke(toolName: 'list_components')['items'] as List)
              .cast<Map<String, Object?>>()
              .map((row) => row['id'] as String)).toSet();
      final effectMcp = ((mcp.invoke(toolName: 'list_effects')['items'] as List)
          .cast<Map<String, Object?>>()
          .map((row) => row['id'] as String)).toSet();
      final motionMcp =
          ((mcp.invoke(toolName: 'list_motion_recipes')['items'] as List)
              .cast<Map<String, Object?>>()
              .map((row) => row['id'] as String)).toSet();
      final templateMcp =
          ((mcp.invoke(toolName: 'list_templates')['items'] as List)
              .cast<Map<String, Object?>>()
              .map((row) => row['id'] as String)).toSet();

      expect(componentMcp, componentInternal);
      expect(effectMcp, effectInternal);
      expect(motionMcp, motionInternal);
      expect(templateMcp, templateInternal);
    });

    test('list_describe_tool_parity = 100%', () {
      final listTargets = <Map<String, String>>[
        <String, String>{
          'listTool': 'list_components',
          'describeTool': 'describe_component',
        },
        <String, String>{
          'listTool': 'list_effects',
          'describeTool': 'describe_effect',
        },
        <String, String>{
          'listTool': 'list_motion_recipes',
          'describeTool': 'describe_motion_recipe',
        },
        <String, String>{
          'listTool': 'list_templates',
          'describeTool': 'describe_template',
        },
      ];

      for (final target in listTargets) {
        final listTool = target['listTool']!;
        final describeTool = target['describeTool']!;
        final listPayload = mcp.invoke(toolName: listTool);
        final items = (listPayload['items'] as List)
            .cast<Map<String, Object?>>()
            .toList(growable: false);
        for (final item in items) {
          final id = item['id'] as String;
          final describePayload = mcp.invoke(
            toolName: describeTool,
            payload: <String, Object?>{'id': id},
          );
          expect(describePayload['id'], id);
          expect(describePayload['title'], isNotNull);
          expect(describePayload['rendererConformance'], isNotNull);
        }
      }
    });

    test('unsupported tool remains read-only and fails closed', () {
      final payload = mcp.invoke(toolName: 'mutate_components_now');
      expect(payload['error'], 'unsupported_discovery_tool');
    });
  });
}
