import '../models/professional_creative_library_registry_models.dart';
import 'professional_creative_library_registry.dart';

class EntrySurfaceDryRunResult {
  const EntrySurfaceDryRunResult({
    required this.ok,
    required this.surface,
    required this.commandFamily,
    this.envelope,
    this.adapterId,
    this.blockerCode,
    this.blockerReason,
  });

  final bool ok;
  final SupportedEntrySurface surface;
  final CommandFamilyDefinition commandFamily;
  final ProfessionalSceneCommandEnvelope? envelope;
  final String? adapterId;
  final String? blockerCode;
  final String? blockerReason;
}

class ProfessionalCreativeEntrySurfaceAdapterLayer {
  const ProfessionalCreativeEntrySurfaceAdapterLayer({
    required ProfessionalCreativeLibraryRegistry registry,
  }) : _registry = registry;

  final ProfessionalCreativeLibraryRegistry _registry;

  EntrySurfaceDryRunResult dryRun({
    required SupportedEntrySurface surface,
    required CommandFamilyDefinition commandFamily,
    required String targetId,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    if (targetId.trim().isEmpty) {
      return EntrySurfaceDryRunResult(
        ok: false,
        surface: surface,
        commandFamily: commandFamily,
        blockerCode: 'TARGET_REQUIRED',
        blockerReason: 'Target id must not be empty.',
      );
    }

    final adapter = _registry.adapters.where((entry) => entry.surface == surface);
    if (adapter.isEmpty) {
      return EntrySurfaceDryRunResult(
        ok: false,
        surface: surface,
        commandFamily: commandFamily,
        blockerCode: 'ADAPTER_NOT_REGISTERED',
        blockerReason: 'No adapter is registered for ${surface.name}.',
      );
    }

    final adapterDef = adapter.first;
    if (!adapterDef.emitsEnvelope) {
      return EntrySurfaceDryRunResult(
        ok: false,
        surface: surface,
        commandFamily: commandFamily,
        adapterId: adapterDef.id,
        blockerCode: 'ADAPTER_NOT_ENVELOPE',
        blockerReason:
            'Adapter `${adapterDef.id}` must emit ProfessionalSceneCommandEnvelope.',
      );
    }
    if (adapterDef.directMutationCount != 0) {
      return EntrySurfaceDryRunResult(
        ok: false,
        surface: surface,
        commandFamily: commandFamily,
        adapterId: adapterDef.id,
        blockerCode: 'ADAPTER_DIRECT_MUTATION_BLOCKED',
        blockerReason:
            'Adapter `${adapterDef.id}` reports direct mutation count ${adapterDef.directMutationCount}.',
      );
    }
    if (!adapterDef.commandFamilies.contains(commandFamily)) {
      return EntrySurfaceDryRunResult(
        ok: false,
        surface: surface,
        commandFamily: commandFamily,
        adapterId: adapterDef.id,
        blockerCode: 'COMMAND_FAMILY_NOT_ALLOWED',
        blockerReason:
            'Command family `${commandFamily.name}` is not allowed for `${surface.name}`.',
      );
    }

    return EntrySurfaceDryRunResult(
      ok: true,
      surface: surface,
      commandFamily: commandFamily,
      adapterId: adapterDef.id,
      envelope: ProfessionalSceneCommandEnvelope(
        commandFamily: commandFamily,
        targetId: targetId,
        payload: Map<String, Object?>.from(payload),
        surface: surface,
        dryRunEligible: true,
      ),
    );
  }

  EntrySurfaceDryRunResult dryRunMcpTool({
    required String toolName,
    required String targetId,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    final normalized = toolName.trim();
    final family = _mcpToolToCommandFamily(normalized);
    if (family == null) {
      return EntrySurfaceDryRunResult(
        ok: false,
        surface: SupportedEntrySurface.mcp,
        commandFamily: CommandFamilyDefinition.updateComponent,
        blockerCode: 'UNSUPPORTED_MCP_TOOL',
        blockerReason: 'Tool `$normalized` is not mapped to a command family.',
      );
    }
    return dryRun(
      surface: SupportedEntrySurface.mcp,
      commandFamily: family,
      targetId: targetId,
      payload: payload,
    );
  }

  CommandFamilyDefinition? _mcpToolToCommandFamily(String toolName) {
    switch (toolName) {
      case 'refusion.insert_layer':
      case 'refusion.insert_component':
        return CommandFamilyDefinition.insertComponent;
      case 'refusion.update_layer':
      case 'refusion.set_text_style':
      case 'refusion.update_component':
        return CommandFamilyDefinition.updateComponent;
      case 'refusion.apply_motion_patch':
      case 'refusion.apply_motion_recipe':
        return CommandFamilyDefinition.applyMotionRecipe;
      case 'refusion.keyframe_edit':
      case 'refusion.set_element_transform':
        return CommandFamilyDefinition.editKeyframe;
      case 'refusion.set_layer_mask':
      case 'refusion.set_border':
      case 'refusion.set_glow':
      case 'refusion.apply_effect':
        return CommandFamilyDefinition.applyEffect;
      case 'refusion.compile_template':
      case 'refusion.insert_template':
        return CommandFamilyDefinition.compileTemplate;
      default:
        return null;
    }
  }
}
