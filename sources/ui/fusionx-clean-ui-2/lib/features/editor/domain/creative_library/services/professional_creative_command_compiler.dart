import '../models/professional_creative_library_registry_models.dart';
import 'professional_creative_command_taxonomy_enforcer.dart';
import 'professional_creative_entry_surface_adapters.dart';
import 'professional_creative_library_registry.dart';

class CreativeCommandCompileResult {
  const CreativeCommandCompileResult({
    required this.ok,
    required this.commandName,
    this.envelopes = const <ProfessionalSceneCommandEnvelope>[],
    this.blockerCode,
    this.blockerReason,
    this.capabilityId,
  });

  final bool ok;
  final String commandName;
  final List<ProfessionalSceneCommandEnvelope> envelopes;
  final String? blockerCode;
  final String? blockerReason;
  final String? capabilityId;
}

class ProfessionalCreativeCommandCompiler {
  ProfessionalCreativeCommandCompiler({
    required ProfessionalCreativeLibraryRegistry registry,
    ProfessionalCreativeEntrySurfaceAdapterLayer? adapterLayer,
    ProfessionalCreativeCommandTaxonomyEnforcer? taxonomyEnforcer,
  })  : _registry = registry,
        _adapterLayer = adapterLayer ??
            ProfessionalCreativeEntrySurfaceAdapterLayer(registry: registry),
        _taxonomyEnforcer = taxonomyEnforcer ??
            const ProfessionalCreativeCommandTaxonomyEnforcer();

  final ProfessionalCreativeLibraryRegistry _registry;
  final ProfessionalCreativeEntrySurfaceAdapterLayer _adapterLayer;
  final ProfessionalCreativeCommandTaxonomyEnforcer _taxonomyEnforcer;

  CreativeCommandCompileResult compileInsertComponent({
    required SupportedEntrySurface surface,
    required String capabilityId,
    required String targetId,
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final itemCheck = _resolveItem(
      commandName: 'insert_component',
      capabilityId: capabilityId,
      expectedKind: CreativeLibraryItemKind.component,
      surface: surface,
    );
    if (!itemCheck.ok) {
      return itemCheck;
    }
    return _compileSingleEnvelope(
      commandName: 'insert_component',
      capabilityId: capabilityId,
      surface: surface,
      commandFamily: CommandFamilyDefinition.insertComponent,
      targetId: targetId,
      payload: <String, Object?>{
        'capabilityId': capabilityId,
        ...params,
      },
    );
  }

  CreativeCommandCompileResult compileApplyEffect({
    required SupportedEntrySurface surface,
    required String capabilityId,
    required String targetId,
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final itemCheck = _resolveItem(
      commandName: 'apply_effect',
      capabilityId: capabilityId,
      expectedKind: CreativeLibraryItemKind.effect,
      surface: surface,
    );
    if (!itemCheck.ok) {
      return itemCheck;
    }
    return _compileSingleEnvelope(
      commandName: 'apply_effect',
      capabilityId: capabilityId,
      surface: surface,
      commandFamily: CommandFamilyDefinition.applyEffect,
      targetId: targetId,
      payload: <String, Object?>{
        'capabilityId': capabilityId,
        ...params,
      },
    );
  }

  CreativeCommandCompileResult compileApplyMotionRecipe({
    required SupportedEntrySurface surface,
    required String capabilityId,
    required String targetId,
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final itemCheck = _resolveItem(
      commandName: 'apply_motion_recipe',
      capabilityId: capabilityId,
      expectedKind: CreativeLibraryItemKind.motionRecipe,
      surface: surface,
    );
    if (!itemCheck.ok) {
      return itemCheck;
    }
    return _compileSingleEnvelope(
      commandName: 'apply_motion_recipe',
      capabilityId: capabilityId,
      surface: surface,
      commandFamily: CommandFamilyDefinition.applyMotionRecipe,
      targetId: targetId,
      payload: <String, Object?>{
        'capabilityId': capabilityId,
        ...params,
      },
    );
  }

  CreativeCommandCompileResult compileUpdateComponent({
    required SupportedEntrySurface surface,
    required String capabilityId,
    required String targetId,
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final itemCheck = _resolveItem(
      commandName: 'update_component',
      capabilityId: capabilityId,
      expectedKind: CreativeLibraryItemKind.component,
      surface: surface,
    );
    if (!itemCheck.ok) {
      return itemCheck;
    }
    return _compileSingleEnvelope(
      commandName: 'update_component',
      capabilityId: capabilityId,
      surface: surface,
      commandFamily: CommandFamilyDefinition.updateComponent,
      targetId: targetId,
      payload: <String, Object?>{
        'capabilityId': capabilityId,
        ...params,
      },
    );
  }

  CreativeCommandCompileResult compileTemplate({
    required SupportedEntrySurface surface,
    required String capabilityId,
    required String targetId,
    Map<String, Object?> controls = const <String, Object?>{},
  }) {
    final itemCheck = _resolveItem(
      commandName: 'compile_template',
      capabilityId: capabilityId,
      expectedKind: CreativeLibraryItemKind.template,
      surface: surface,
    );
    if (!itemCheck.ok) {
      return itemCheck;
    }

    final compileDryRun = _adapterLayer.dryRun(
      surface: surface,
      commandFamily: CommandFamilyDefinition.compileTemplate,
      targetId: targetId,
      payload: <String, Object?>{
        'capabilityId': capabilityId,
        'controls': controls,
      },
    );
    if (!compileDryRun.ok || compileDryRun.envelope == null) {
      return _blockedFromDryRun(
        commandName: 'compile_template',
        capabilityId: capabilityId,
        dryRun: compileDryRun,
      );
    }

    final insertDryRun = _adapterLayer.dryRun(
      surface: surface,
      commandFamily: CommandFamilyDefinition.insertTemplate,
      targetId: targetId,
      payload: <String, Object?>{
        'capabilityId': capabilityId,
      },
    );
    if (!insertDryRun.ok || insertDryRun.envelope == null) {
      return _blockedFromDryRun(
        commandName: 'compile_template',
        capabilityId: capabilityId,
        dryRun: insertDryRun,
      );
    }

    return CreativeCommandCompileResult(
      ok: true,
      commandName: 'compile_template',
      capabilityId: capabilityId,
      envelopes: <ProfessionalSceneCommandEnvelope>[
        compileDryRun.envelope!,
        insertDryRun.envelope!,
      ],
    );
  }

  CreativeCommandCompileResult _compileSingleEnvelope({
    required String commandName,
    required String capabilityId,
    required SupportedEntrySurface surface,
    required CommandFamilyDefinition commandFamily,
    required String targetId,
    required Map<String, Object?> payload,
  }) {
    final taxonomy = _taxonomyEnforcer.validate(
      commandName: commandName,
      commandFamily: commandFamily,
      payload: payload,
    );
    if (!taxonomy.ok) {
      return CreativeCommandCompileResult(
        ok: false,
        commandName: commandName,
        capabilityId: capabilityId,
        blockerCode: taxonomy.blockerCode ?? 'COMMAND_TAXONOMY_BLOCKED',
        blockerReason: taxonomy.blockerReason ??
            'Command blocked by taxonomy enforcement.',
      );
    }

    final dryRun = _adapterLayer.dryRun(
      surface: surface,
      commandFamily: commandFamily,
      targetId: targetId,
      payload: payload,
    );
    if (!dryRun.ok || dryRun.envelope == null) {
      return _blockedFromDryRun(
        commandName: commandName,
        capabilityId: capabilityId,
        dryRun: dryRun,
      );
    }
    return CreativeCommandCompileResult(
      ok: true,
      commandName: commandName,
      capabilityId: capabilityId,
      envelopes: <ProfessionalSceneCommandEnvelope>[dryRun.envelope!],
    );
  }

  CreativeCommandCompileResult _resolveItem({
    required String commandName,
    required String capabilityId,
    required CreativeLibraryItemKind expectedKind,
    required SupportedEntrySurface surface,
  }) {
    final item = _registry.describe(capabilityId);
    if (item == null) {
      return CreativeCommandCompileResult(
        ok: false,
        commandName: commandName,
        capabilityId: capabilityId,
        blockerCode: 'CAPABILITY_NOT_FOUND',
        blockerReason: 'Capability `$capabilityId` is not present in registry.',
      );
    }
    if (item.kind != expectedKind) {
      return CreativeCommandCompileResult(
        ok: false,
        commandName: commandName,
        capabilityId: capabilityId,
        blockerCode: 'CAPABILITY_KIND_MISMATCH',
        blockerReason:
            'Capability `$capabilityId` kind `${item.kind.name}` does not match expected `${expectedKind.name}`.',
      );
    }
    if (!item.supportedEntrySurfaces.contains(surface)) {
      return CreativeCommandCompileResult(
        ok: false,
        commandName: commandName,
        capabilityId: capabilityId,
        blockerCode: 'SURFACE_NOT_SUPPORTED_FOR_CAPABILITY',
        blockerReason:
            'Capability `$capabilityId` is not available for `${surface.name}`.',
      );
    }
    return CreativeCommandCompileResult(
      ok: true,
      commandName: commandName,
      capabilityId: capabilityId,
    );
  }

  CreativeCommandCompileResult _blockedFromDryRun({
    required String commandName,
    required String capabilityId,
    required EntrySurfaceDryRunResult dryRun,
  }) {
    return CreativeCommandCompileResult(
      ok: false,
      commandName: commandName,
      capabilityId: capabilityId,
      blockerCode: dryRun.blockerCode ?? 'DRY_RUN_BLOCKED',
      blockerReason: dryRun.blockerReason ??
          'Command was blocked during dry-run validation.',
    );
  }
}
