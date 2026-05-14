import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_inspiration_pack_catalog.dart';
import 'package:refusion_app/features/editor/domain/creative_library/services/professional_creative_library_existing_capability_adapter.dart';

void main() {
  group('PNCLE-08/09 Inspiration Pack Catalog', () {
    final registry =
        ProfessionalCreativeLibraryExistingCapabilityAdapter().buildRegistry();
    const catalog = ProfessionalCreativeInspirationPackCatalog();

    test('every declared pack resolves to native editable capabilities', () {
      final definitions = catalog.listDefinitions();
      expect(definitions, isNotEmpty);
      for (final definition in definitions) {
        final materialization = catalog.materialize(
          registry: registry,
          packId: definition.id,
        );
        expect(
          materialization.missingRequirements,
          isEmpty,
          reason: 'Pack ${definition.id} has missing requirements',
        );
        expect(materialization.items, isNotEmpty);
      }
    });

    test('pack not found fails closed', () {
      final materialization = catalog.materialize(
        registry: registry,
        packId: 'pack.unknown',
      );
      expect(materialization.isReady, isFalse);
      expect(materialization.missingRequirements, contains('PACK_NOT_FOUND'));
    });

    test('materialized capabilities exist in registry with supported kind', () {
      final definitions = catalog.listDefinitions();
      for (final definition in definitions) {
        final materialization = catalog.materialize(
          registry: registry,
          packId: definition.id,
        );
        for (final item in materialization.items) {
          final capability = registry.describe(item.capabilityId);
          expect(capability, isNotNull);
          expect(capability!.kind, item.kind);
          expect(
            definition.requiredKinds.contains(item.kind),
            isTrue,
            reason:
                'Pack ${definition.id} emitted unexpected kind ${item.kind.name}',
          );
        }
      }
    });
  });
}
