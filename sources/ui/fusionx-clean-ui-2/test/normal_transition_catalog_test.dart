import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_normal_transition_models.dart';
import 'package:refusion_app/features/editor/domain/services/normal_transition_catalog.dart';

void main() {
  test('built-in catalog loads phase-one presets through JSON DSL path', () {
    const catalog = NormalTransitionCatalog();

    final result = catalog.loadBuiltIns();

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
    expect(result.definitions, hasLength(13));
    expect(
      result.definitions.map((definition) => definition.definitionId),
      containsAll(<String>[
        'cross_dissolve',
        'fade_black',
        'white_flash',
        'zoom_in_camera',
        'blur_dissolve',
        'push_left',
        'push_right',
        'zoom_out_camera',
        'whip_pan_left',
        'whip_pan_right',
        'slide_blur_left',
        'slide_blur_right',
        'flash_zoom',
      ]),
    );

    final definition = result.definitionById('cross_dissolve');
    expect(definition, isNotNull);
    expect(definition!.category, NormalTransitionCategory.basic);
    expect(definition.rendererTier, NormalTransitionRendererTier.primitive);
    expect(definition.defaultDuration.inMilliseconds, 720);
    expect(definition.minDuration.inMilliseconds, 120);
    expect(definition.maxDuration.inMilliseconds, 3000);
    expect(definition.capabilities, contains('dual-texture'));
    expect(definition.defaultParameterValues['softness'], 0.5);
    expect(definition.channels.map((channel) => channel.target), <String>[
      'from',
      'to',
    ]);

    final zoom = result.definitionById('zoom_in_camera');
    expect(zoom, isNotNull);
    expect(zoom!.category, NormalTransitionCategory.motion);
    expect(zoom.capabilities, contains('scale'));

    final blur = result.definitionById('blur_dissolve');
    expect(blur, isNotNull);
    expect(blur!.category, NormalTransitionCategory.blur);
    expect(blur.capabilities, contains('blur'));
  });

  test('catalog rejects definitions whose internal id differs from key', () {
    const catalog = NormalTransitionCatalog(
      sourcesById: <String, String>{
        'expected_id': '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "actual_id",
  "name": "Bad",
  "rendererType": "primitive",
  "defaultDurationMs": 400,
  "channels": [
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0 },
        { "t": 1.0, "value": 0.0 }
      ]
    }
  ]
}
''',
      },
    );

    final result = catalog.loadBuiltIns();

    expect(result.isValid, isFalse);
    expect(result.definitions, isEmpty);
    expect(result.issues.single.path, 'expected_id');
  });
}
