import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
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
    expect(
        result.program!.layers.single.elements.single.channels, hasLength(2));
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

  test('normalizes unsorted keyframes and rejects unsupported schema versions',
      () {
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
      contains('schemaVersion'),
    );
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.warning &&
            issue.message.contains('not sorted'),
      ),
      isNotEmpty,
    );
    final keyframes = result.program!.layers.single.channels.single.keyframes;
    expect(keyframes.map((keyframe) => keyframe.timeMs), <int>[100, 500]);
  });

  test('accepts and sorts agent generated keyframes that arrive out of order',
      () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 2400,
  "layers": [
    {
      "id": "typing-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 2400,
      "elements": [
        {
          "id": "typing",
          "kind": "text",
          "text": "hello world",
          "channels": [
            {
              "property": "typingProgress",
              "keyframes": [
                { "timeMs": 1400, "value": 1.0 },
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 700, "value": 0.55 }
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
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.warning &&
            issue.message.contains('not sorted'),
      ),
      isNotEmpty,
    );
    final keyframes =
        result.program!.layers.single.elements.single.channels.single.keyframes;
    expect(keyframes.map((keyframe) => keyframe.timeMs), <int>[0, 700, 1400]);
  });

  test('accepts explicit project-time keyframes inside delayed layers', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 3000,
  "layers": [
    {
      "id": "delayed-layer",
      "kind": "text",
      "startMs": 1800,
      "durationMs": 800,
      "elements": [
        {
          "id": "delayed-title",
          "kind": "text",
          "text": "Late",
          "channels": [
            {
              "property": "opacity",
              "timeBasis": "project",
              "keyframes": [
                { "timeMs": 1800, "value": 0.0 },
                { "timeMs": 2400, "value": 1.0 }
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
    final keyframes =
        result.program!.layers.single.elements.single.channels.single.keyframes;
    expect(keyframes.first.timeMs, 0);
    expect(keyframes.last.timeMs, 600);
  });

  test('converts likely project-time keyframes with warnings', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 3000,
  "layers": [
    {
      "id": "delayed-layer",
      "kind": "text",
      "startMs": 1800,
      "durationMs": 800,
      "elements": [
        {
          "id": "delayed-title",
          "kind": "text",
          "text": "Late",
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 1800, "value": 0.0 },
                { "timeMs": 2400, "value": 1.0 }
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
    expect(
      result.issues.where(
        (issue) => issue.message.contains('looked like project time'),
      ),
      isNotEmpty,
    );
    final keyframes =
        result.program!.layers.single.elements.single.channels.single.keyframes;
    expect(keyframes.first.timeMs, 0);
    expect(keyframes.last.timeMs, 600);
  });

  test('extends delayed layer duration for project-time element keyframes', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 5000,
  "layers": [
    {
      "id": "late-copy-layer",
      "kind": "text",
      "startMs": 1000,
      "durationMs": 1000,
      "elements": [
        {
          "id": "late-copy",
          "kind": "text",
          "text": "Scene",
          "channels": [
            {
              "property": "opacity",
              "timeBasis": "project",
              "keyframes": [
                { "timeMs": 1000, "value": 0.0 },
                { "timeMs": 4200, "value": 1.0 }
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
    expect(
      result.issues.where(
        (issue) => issue.message.contains('duration was extended'),
      ),
      isNotEmpty,
    );
    final layer = result.program!.layers.single;
    expect(layer.durationMs, 3200);
    final keyframes = layer.elements.single.channels.single.keyframes;
    expect(keyframes.map((keyframe) => keyframe.timeMs), <int>[0, 3200]);
  });

  test('extends local layer duration for local keyframes inside the scene', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 5000,
  "layers": [
    {
      "id": "long-local-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 1000,
      "channels": [
        {
          "property": "opacity",
          "timeBasis": "local",
          "keyframes": [
            { "timeMs": 0, "value": 0.0 },
            { "timeMs": 4200, "value": 1.0 }
          ]
        }
      ]
    }
  ]
}
''',
    );

    expect(result.isValid, isTrue);
    expect(result.program!.layers.single.durationMs, 4200);
    expect(
      result.program!.layers.single.channels.single.keyframes
          .map((keyframe) => keyframe.timeMs),
      <int>[0, 4200],
    );
  });

  test('still rejects keyframes that are outside the scene duration', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 3000,
  "layers": [
    {
      "id": "bad-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 1000,
      "channels": [
        {
          "property": "opacity",
          "timeBasis": "local",
          "keyframes": [
            { "timeMs": 0, "value": 0.0 },
            { "timeMs": 4000, "value": 1.0 }
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
      result.issues.where(
        (issue) => issue.message.contains('inside the owning timeline range'),
      ),
      isNotEmpty,
    );
  });

  test('warns when typewriter progress is authored backwards', () {
    final result = service.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 2000,
  "layers": [
    {
      "id": "typing-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 2000,
      "elements": [
        {
          "id": "typing",
          "kind": "text",
          "text": "hello",
          "channels": [
            {
              "property": "typewriterProgress",
              "keyframes": [
                { "timeMs": 0, "value": 1.0 },
                { "timeMs": 1200, "value": 0.0 }
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
    expect(
      result.issues.where(
        (issue) => issue.message.contains('delete/backspace'),
      ),
      isNotEmpty,
    );
  });
}
