import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';

void main() {
  const service = ReFusionSceneProgramImportService();

  test('validates declarative scene program v1', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Agent Promo Intro",
  "durationMs": 3000,
  "frameRate": 60,
  "layers": [
    {
      "id": "headline-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 3000,
      "elements": [
        {
          "id": "headline",
          "kind": "text",
          "text": "ReFusion",
          "properties": {
            "fontSize": 96,
            "color": "#FFFFFF"
          },
          "channels": [
            {
              "property": "transform.scale.x",
              "keyframes": [
                { "timeMs": 0, "value": 0.82, "easing": "easeOut" },
                { "timeMs": 600, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "visual.opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 600, "value": 1.0 }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
    expect(result.program!.schemaVersion, 'refusion.scene-program/v1');
    expect(result.program!.durationMs, 3000);
    expect(result.program!.frameRate, 60);
    expect(result.program!.layers.single.id, 'headline-layer');
    expect(result.program!.layers.single.elements.single.channels, hasLength(2));
  });

  test('rejects executable or remote script keys anywhere in the document', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 1000,
  "layers": [
    {
      "id": "layer-1",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 1000,
      "elements": [
        {
          "id": "shape-1",
          "kind": "shape",
          "properties": {
            "code": "animate()"
          }
        }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.where(
        (issue) => issue.path == 'layers[0].elements[0].properties.code',
      ),
      isNotEmpty,
    );
  });

  test('rejects unsorted keyframes and unsupported schema versions', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v9",
  "durationMs": 1000,
  "layers": [
    {
      "id": "layer-1",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1000,
      "channels": [
        {
          "property": "visual.opacity",
          "keyframes": [
            { "timeMs": 500, "value": 1.0 },
            { "timeMs": 100, "value": 0.0 }
          ]
        }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.path),
      containsAll(<String>[
        'schemaVersion',
        'layers[0].channels[0].keyframes[1]',
      ]),
    );
  });
}
