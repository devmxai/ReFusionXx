import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_native_preset_pack_catalog.dart';

void main() {
  group('PNCLE-10 Native Preset Pack Catalog', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    const catalog = ProfessionalNativePresetPackCatalog();

    test('builds native presets with component/effect/motion references', () {
      final presets = catalog.buildWithRegistry(registry);
      expect(presets, isNotEmpty);
      for (final preset in presets) {
        expect(preset.controls, isNotEmpty);
        expect(preset.componentCapabilityId, isNotEmpty);
        expect(preset.effectCapabilityId, isNotEmpty);
        expect(preset.motionCapabilityId, isNotEmpty);
      }
    });

    test('every preset validates against registry and control contract', () {
      final presets = catalog.buildWithRegistry(registry);
      for (final preset in presets) {
        final validation = catalog.validatePreset(preset, registry);
        expect(
          validation.ok,
          isTrue,
          reason: '${preset.id} failed validation: ${validation.blockerCode}',
        );
      }
    });
  });
}
