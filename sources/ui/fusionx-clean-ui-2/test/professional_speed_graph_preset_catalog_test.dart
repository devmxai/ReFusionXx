import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/professional_speed_graph_preset_catalog.dart';

void main() {
  const catalog = ProfessionalSpeedGraphPresetCatalog();

  test('resolves fastSlowFast preset and aliases', () {
    final byId = catalog.findById('fastSlowFast');
    expect(byId, isNotNull);
    expect(byId!.bezier.x1, closeTo(0.12, 0.0001));

    final byAlias = catalog.findByAlias('plateau');
    expect(byAlias, isNotNull);
    expect(byAlias!.id, 'fastSlowFast');
  });

  test('canonicalId resolves f9 and custom aliases', () {
    expect(catalog.canonicalId('f9'), 'easyEase');
    expect(catalog.canonicalId('velocityGraph'), 'customSpeedGraph');
  });
}
