import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_lowerer.dart';

void main() {
  const importService = ReFusionSceneProgramImportService();
  const lowerer = ReFusionSceneProgramLowerer();

  test('lowers text and shape layers into editable motion graph channels', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Agent Promo Intro",
  "durationMs": 3000,
  "frameRate": 30,
  "layers": [
    {
      "id": "bg-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3000,
      "elements": [
        {
          "id": "bg-solid",
          "kind": "solid",
          "properties": {
            "width": 1080,
            "height": 1920
          }
        }
      ]
    },
    {
      "id": "title-layer",
      "kind": "text",
      "startMs": 250,
      "durationMs": 1750,
      "elements": [
        {
          "id": "title",
          "kind": "text",
          "text": "ReFusion",
          "properties": {
            "fontSize": 96
          },
          "channels": [
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 0, "value": { "x": 0, "y": 96 }, "easing": "easeOut" },
                { "timeMs": 500, "value": { "x": 0, "y": 0 }, "easing": "linear" }
              ]
            },
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 500, "value": 1.0 }
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
    expect(importResult.isValid, isTrue);

    final result = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(program: importResult.program!),
    );

    expect(result.hasErrors, isFalse);
    expect(result.project.name, 'Agent Promo Intro');
    expect(result.project.format.canvasSize.width, 1080);
    expect(result.project.frameRate.framesPerSecond, 30);
    expect(result.project.scenes.single.projectRange.duration.inMilliseconds,
        3000);
    expect(result.project.scenes.single.layers, hasLength(2));

    final textLayer = result.project.scenes.single.layers.last;
    expect(textLayer.kind, MotionLayerKind.text);
    expect(textLayer.visibleRange.start.inMilliseconds, 250);
    expect(textLayer.elements.single.sourceBinding!.kind,
        MotionSourceKind.generatedText);
    expect(
        textLayer.elements.single.sourceBinding!.metadata['text'], 'ReFusion');

    final staticFontSize = textLayer.elements.single.properties.singleWhere(
      (assignment) =>
          assignment.definition.id == MotionPropertyCatalog.fontSize.id,
    );
    expect(staticFontSize.value.rawValue, 96);

    expect(
      result.channels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.positionX.id,
        MotionPropertyCatalog.positionY.id,
        MotionPropertyCatalog.opacity.id,
      ]),
    );

    final positionY = result.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.positionY.id,
    );
    expect(positionY.keyframes, hasLength(2));
    expect(positionY.keyframes.first.time.inMilliseconds, 0);
    expect(positionY.keyframes.first.value.rawValue, 96);
    expect(
      positionY.keyframes.first.interpolationToNext.kind,
      MotionInterpolationKind.easeOut,
    );
  });

  test('routes layer channels to the first editable element when required', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Layer Channel Scene",
  "durationMs": 1000,
  "frameRate": 60,
  "layers": [
    {
      "id": "shape-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 1000,
      "channels": [
        {
          "property": "scale",
          "keyframes": [
            { "timeMs": 0, "value": 0.4 },
            { "timeMs": 400, "value": 1.0 }
          ]
        }
      ],
      "elements": [
        {
          "id": "box",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 320,
            "height": 160,
            "cornerRadius": 24
          }
        }
      ]
    }
  ]
}
''',
    );
    expect(importResult.isValid, isTrue);

    final result = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(program: importResult.program!),
    );

    expect(result.hasErrors, isFalse);
    final element = result.project.scenes.single.layers.single.elements.single;
    expect(element.shapeKind, MotionShapeKind.roundedRectangle);
    expect(
      element.properties.map((assignment) => assignment.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.width.id,
        MotionPropertyCatalog.height.id,
        MotionPropertyCatalog.cornerRadius.id,
      ]),
    );
    expect(result.channels, hasLength(2));
    expect(
      result.channels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.scaleX.id,
        MotionPropertyCatalog.scaleY.id,
      ]),
    );
    expect(
      result.channels.every(
        (channel) => channel.target.kind == MotionTargetKind.element,
      ),
      isTrue,
    );
    expect(result.project.frameRate.framesPerSecond, 60);
  });

  test('keeps supported channels when unsupported properties are present', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Partial Scene",
  "durationMs": 1000,
  "frameRate": 30,
  "layers": [
    {
      "id": "title-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1000,
      "elements": [
        {
          "id": "title",
          "kind": "text",
          "text": "Safe",
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 200, "value": 1.0 }
              ]
            },
            {
              "property": "unsupported.magic",
              "keyframes": [
                { "timeMs": 0, "value": 10 },
                { "timeMs": 200, "value": 20 }
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
    expect(importResult.isValid, isTrue);

    final result = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(program: importResult.program!),
    );

    expect(result.hasErrors, isFalse);
    expect(result.channels, hasLength(1));
    expect(
        result.channels.single.definition.id, MotionPropertyCatalog.opacity.id);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.warning &&
            issue.message.contains('unsupported.magic'),
      ),
      isNotEmpty,
    );
  });
}
