import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_entry_surface_adapters.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';

void main() {
  group('PNCLE-03B Entry Surface Adapter Layer', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    final adapterLayer = ProfessionalCreativeEntrySurfaceAdapterLayer(
      registry: registry,
    );

    test('registers all entry surfaces with direct mutation count = 0', () {
      final surfaces = registry.adapters.map((entry) => entry.surface).toSet();
      expect(
        surfaces,
        equals(<SupportedEntrySurface>{
          SupportedEntrySurface.manualUi,
          SupportedEntrySurface.mcp,
          SupportedEntrySurface.pasteScript,
          SupportedEntrySurface.template,
          SupportedEntrySurface.tapList,
          SupportedEntrySurface.futureTool,
        }),
      );
      expect(
        registry.adapters.every((entry) => entry.directMutationCount == 0),
        isTrue,
      );
      expect(registry.hasParallelTruthPaths, isFalse);
    });

    test('every adapter emits ProfessionalSceneCommandEnvelope', () {
      for (final entry in registry.adapters) {
        final commandFamily = entry.commandFamilies.first;
        final dryRun = adapterLayer.dryRun(
          surface: entry.surface,
          commandFamily: commandFamily,
          targetId: 'node-${entry.surface.name}',
          payload: <String, Object?>{
            'source': entry.id,
          },
        );

        expect(dryRun.ok, isTrue, reason: 'failed for ${entry.surface.name}');
        expect(dryRun.adapterId, entry.id);
        expect(dryRun.envelope, isNotNull);
        expect(dryRun.envelope!.commandFamily, commandFamily);
        expect(dryRun.envelope!.surface, entry.surface);
        expect(dryRun.envelope!.targetId, 'node-${entry.surface.name}');
        expect(dryRun.envelope!.dryRunEligible, isTrue);
      }
    });

    test('blocks command family that is not allowed by adapter', () {
      final dryRun = adapterLayer.dryRun(
        surface: SupportedEntrySurface.template,
        commandFamily: CommandFamilyDefinition.deleteNode,
        targetId: 'template-node',
      );

      expect(dryRun.ok, isFalse);
      expect(dryRun.blockerCode, 'COMMAND_FAMILY_NOT_ALLOWED');
      expect(dryRun.envelope, isNull);
    });

    test('supports MCP tool mapping to canonical command families', () {
      final dryRun = adapterLayer.dryRunMcpTool(
        toolName: 'refusion.apply_motion_patch',
        targetId: 'motion-node',
        payload: const <String, Object?>{'preset': 'popInSpring'},
      );

      expect(dryRun.ok, isTrue);
      expect(dryRun.commandFamily, CommandFamilyDefinition.applyMotionRecipe);
      expect(dryRun.envelope, isNotNull);
    });

    test('rejects unsupported MCP tool in dry-run mode', () {
      final dryRun = adapterLayer.dryRunMcpTool(
        toolName: 'refusion.mutate_in_private_path',
        targetId: 'node-1',
      );

      expect(dryRun.ok, isFalse);
      expect(dryRun.blockerCode, 'UNSUPPORTED_MCP_TOOL');
      expect(dryRun.envelope, isNull);
    });
  });
}
