import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/models/professional_creative_library_registry_models.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_command_compiler.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';

void main() {
  group('PNCLE-05 Command Compilation', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    final compiler = ProfessionalCreativeCommandCompiler(registry: registry);

    test('insert_component compiles to canonical command envelope', () {
      final componentId =
          registry.listByKind(CreativeLibraryItemKind.component).first.id;
      final result = compiler.compileInsertComponent(
        surface: SupportedEntrySurface.manualUi,
        capabilityId: componentId,
        targetId: 'scene.root',
        params: const <String, Object?>{
          'variant': 'default',
        },
      );

      expect(result.ok, isTrue);
      expect(result.envelopes.length, 1);
      expect(
        result.envelopes.single.commandFamily,
        CommandFamilyDefinition.insertComponent,
      );
      expect(result.envelopes.single.surface, SupportedEntrySurface.manualUi);
    });

    test('apply_effect compiles with effect capability and mcp surface', () {
      final effectId =
          registry.listByKind(CreativeLibraryItemKind.effect).first.id;
      final result = compiler.compileApplyEffect(
        surface: SupportedEntrySurface.mcp,
        capabilityId: effectId,
        targetId: 'layer.video',
        params: const <String, Object?>{
          'amount': 0.8,
        },
      );

      expect(result.ok, isTrue);
      expect(result.envelopes.length, 1);
      expect(
        result.envelopes.single.commandFamily,
        CommandFamilyDefinition.applyEffect,
      );
    });

    test('apply_motion_recipe compiles to canonical motion command', () {
      final motionId =
          registry.listByKind(CreativeLibraryItemKind.motionRecipe).first.id;
      final result = compiler.compileApplyMotionRecipe(
        surface: SupportedEntrySurface.mcp,
        capabilityId: motionId,
        targetId: 'text.title',
        params: const <String, Object?>{
          'durationMs': 720,
        },
      );

      expect(result.ok, isTrue);
      expect(result.envelopes.length, 1);
      expect(
        result.envelopes.single.commandFamily,
        CommandFamilyDefinition.applyMotionRecipe,
      );
    });

    test('compile_template emits compile + insert canonical commands', () {
      final templateId =
          registry.listByKind(CreativeLibraryItemKind.template).first.id;
      final result = compiler.compileTemplate(
        surface: SupportedEntrySurface.template,
        capabilityId: templateId,
        targetId: 'scene.templateRoot',
        controls: const <String, Object?>{
          'headline': 'Hello',
        },
      );

      expect(result.ok, isTrue);
      expect(result.envelopes.length, 2);
      expect(
        result.envelopes.first.commandFamily,
        CommandFamilyDefinition.compileTemplate,
      );
      expect(
        result.envelopes.last.commandFamily,
        CommandFamilyDefinition.insertTemplate,
      );
    });

    test('kind mismatch fails closed', () {
      final componentId =
          registry.listByKind(CreativeLibraryItemKind.component).first.id;
      final result = compiler.compileApplyEffect(
        surface: SupportedEntrySurface.mcp,
        capabilityId: componentId,
        targetId: 'layer.mismatch',
      );

      expect(result.ok, isFalse);
      expect(result.blockerCode, 'CAPABILITY_KIND_MISMATCH');
      expect(result.envelopes, isEmpty);
    });

    test('command family not allowed by surface adapter fails closed', () {
      final componentId =
          registry.listByKind(CreativeLibraryItemKind.component).first.id;
      final result = compiler.compileInsertComponent(
        surface: SupportedEntrySurface.template,
        capabilityId: componentId,
        targetId: 'scene.blocked',
      );

      expect(result.ok, isFalse);
      expect(result.blockerCode, 'COMMAND_FAMILY_NOT_ALLOWED');
      expect(result.envelopes, isEmpty);
    });

    test('PNCLE-05B insert_component blocks update intent payload', () {
      final componentId =
          registry.listByKind(CreativeLibraryItemKind.component).first.id;
      final result = compiler.compileInsertComponent(
        surface: SupportedEntrySurface.mcp,
        capabilityId: componentId,
        targetId: 'scene.root',
        params: const <String, Object?>{
          'targetLayerId': 'layer.text.1',
          'operation': 'update_layer',
        },
      );

      expect(result.ok, isFalse);
      expect(result.blockerCode, 'INSERT_USED_FOR_UPDATE');
      expect(result.envelopes, isEmpty);
    });

    test('PNCLE-05B compileUpdateComponent uses update command family', () {
      final componentId =
          registry.listByKind(CreativeLibraryItemKind.component).first.id;
      final result = compiler.compileUpdateComponent(
        surface: SupportedEntrySurface.mcp,
        capabilityId: componentId,
        targetId: 'layer.text.1',
        params: const <String, Object?>{
          'text': 'TEST',
          'fontSize': 96,
        },
      );

      expect(result.ok, isTrue);
      expect(result.envelopes.length, 1);
      expect(
        result.envelopes.single.commandFamily,
        CommandFamilyDefinition.updateComponent,
      );
    });

    test('PNCLE-05B apply_effect blocks motion metadata payload', () {
      final effectId =
          registry.listByKind(CreativeLibraryItemKind.effect).first.id;
      final result = compiler.compileApplyEffect(
        surface: SupportedEntrySurface.mcp,
        capabilityId: effectId,
        targetId: 'layer.video',
        params: const <String, Object?>{
          'motion': <String, Object?>{
            'preset': 'pop_up',
          },
        },
      );

      expect(result.ok, isFalse);
      expect(
          result.blockerCode, 'MOTION_METADATA_NOT_ALLOWED_IN_EFFECT_COMMAND');
      expect(result.envelopes, isEmpty);
    });

    test('PNCLE-05B apply_motion_recipe blocks effect metadata payload', () {
      final motionId =
          registry.listByKind(CreativeLibraryItemKind.motionRecipe).first.id;
      final result = compiler.compileApplyMotionRecipe(
        surface: SupportedEntrySurface.mcp,
        capabilityId: motionId,
        targetId: 'layer.video',
        params: const <String, Object?>{
          'shadow': <String, Object?>{
            'blur': 24,
          },
        },
      );

      expect(result.ok, isFalse);
      expect(
          result.blockerCode, 'EFFECT_METADATA_NOT_ALLOWED_IN_MOTION_COMMAND');
      expect(result.envelopes, isEmpty);
    });
  });
}
