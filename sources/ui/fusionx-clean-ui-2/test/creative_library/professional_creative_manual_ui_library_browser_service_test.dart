import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_discovery_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_discovery_service.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_manual_ui_library_browser_service.dart';
import 'package:refusion_app/features/editor/domain/mcp/refusion_creative_library_discovery.dart';

void main() {
  group('PNCLE-04 Manual UI Library Browser', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    final discovery = ProfessionalCreativeLibraryDiscoveryService(
      registry: registry,
    );
    final mcp = RefusionCreativeLibraryDiscoveryToolset(discovery: discovery);
    final browser = ProfessionalCreativeManualUiLibraryBrowserService(
      discovery: discovery,
    );

    test('builds read-only browser families including icons', () {
      final snapshot = browser.browse();
      expect(snapshot.components.family, 'components');
      expect(snapshot.effects.family, 'effects');
      expect(snapshot.motionRecipes.family, 'motion_recipes');
      expect(snapshot.templates.family, 'templates');
      expect(snapshot.icons.family, 'icons');
      expect(snapshot.icons.items, isNotEmpty);
    });

    test('manual UI sees the same ids as MCP/discovery source of truth', () {
      final manual = browser.browse();
      final mcpView = CreativeManualUiLibraryBrowserSnapshot(
        components: _fromMcpFamily(mcp.invoke(toolName: 'list_components')),
        effects: _fromMcpFamily(mcp.invoke(toolName: 'list_effects')),
        motionRecipes:
            _fromMcpFamily(mcp.invoke(toolName: 'list_motion_recipes')),
        templates: _fromMcpFamily(mcp.invoke(toolName: 'list_templates')),
        icons: _fromMcpFamily(mcp.invoke(toolName: 'list_icons')),
      );
      final parity = browser.validateParity(
        manualUiSnapshot: manual,
        mcpSnapshot: mcpView,
      );

      expect(parity.ok, isTrue);
      expect(parity.matchRatio, 1.0);
      expect(parity.missingFamilies, isEmpty);
    });
  });
}

CreativeLibraryDiscoveryListResponse _fromMcpFamily(
    Map<String, Object?> payload) {
  final family = payload['family'] as String? ?? 'unknown';
  final items = (payload['items'] as List? ?? const <Object?>[])
      .cast<Map<String, Object?>>()
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
