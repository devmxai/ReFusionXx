import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_runtime_helpers.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_lowerer.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

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
    expect(positionY.activeRange!.start.inMilliseconds, 250);
    expect(positionY.keyframes.first.time.inMilliseconds, 250);
    expect(positionY.keyframes.last.time.inMilliseconds, 750);
    expect(positionY.keyframes.first.value.rawValue, 96);
    expect(
      positionY.keyframes.first.interpolationToNext.kind,
      MotionInterpolationKind.easeOut,
    );
  });

  test('offsets delayed layer keyframes into project time before runtime eval',
      () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Delayed Typewriter Scene",
  "durationMs": 7000,
  "frameRate": 30,
  "layers": [
    {
      "id": "letter-typing-layer",
      "kind": "text",
      "startMs": 2050,
      "durationMs": 2950,
      "elements": [
        {
          "id": "typing-text",
          "kind": "text",
          "text": "Hello World",
          "channels": [
            {
              "property": "typewriterProgress",
              "keyframes": [
                { "timeMs": 780, "value": 0.0 },
                { "timeMs": 2420, "value": 1.0 }
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
    final revealChannel = result.channels.singleWhere(
      (channel) =>
          channel.target.targetId == 'typing-text' &&
          channel.definition.id == MotionPropertyCatalog.revealProgress.id,
    );
    expect(revealChannel.activeRange!.start.inMilliseconds, 2050);
    expect(revealChannel.activeRange!.endExclusive.inMilliseconds, 5000);
    expect(
      revealChannel.keyframes.map((keyframe) => keyframe.time.inMilliseconds),
      <int>[2830, 4470],
    );

    final compileResult = BasicMotionCompositionCompiler().compile(
      MotionCompileRequest(
        project: result.project,
        propertyChannels: result.channels,
        textAnimationBindings: result.textAnimationBindings,
      ),
    );
    expect(compileResult.hasErrors, isFalse);
    final composition = compileResult.composition!;

    double? revealAt(int milliseconds) {
      final snapshot = const BasicMotionRuntimeEvaluator().evaluate(
        MotionEvaluationRequest(
          composition: composition,
          time: TimelineTime.fromMilliseconds(milliseconds),
        ),
      );
      return snapshot.textAnimations.single.revealProgress;
    }

    expect(revealAt(2149), 0.0);
    expect(revealAt(3600), closeTo(0.469, 0.002));
    expect(revealAt(4600), 1.0);
  });

  test('keeps delayed shape elements active for the full layer project range',
      () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Delayed Shape Scene",
  "durationMs": 4000,
  "frameRate": 30,
  "layers": [
    {
      "id": "delayed-shape-layer",
      "kind": "shape",
      "startMs": 2000,
      "durationMs": 1000,
      "elements": [
        {
          "id": "line",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 640,
            "height": 12,
            "backgroundColor": "#FFFFFF"
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
    final compileResult = BasicMotionCompositionCompiler().compile(
      MotionCompileRequest(
        project: result.project,
        propertyChannels: result.channels,
        textAnimationBindings: result.textAnimationBindings,
      ),
    );

    expect(compileResult.hasErrors, isFalse);
    final layer = compileResult.composition!.scenes.single.layers.single;
    expect(layer.projectRange.start.inMilliseconds, 2000);
    expect(layer.projectRange.endExclusive.inMilliseconds, 3000);
    final element = layer.elements.single;
    expect(element.projectRange.start.inMilliseconds, 2000);
    expect(element.projectRange.endExclusive.inMilliseconds, 3000);
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
    expect(
      result.issues.where(
        (issue) => issue.message.contains('shapeKind'),
      ),
      isEmpty,
    );
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

  test('lowers core pack icon elements as editable generated shapes', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Prompt Icon Scene",
  "durationMs": 1200,
  "frameRate": 30,
  "layers": [
    {
      "id": "send-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 1200,
      "elements": [
        {
          "id": "send-icon",
          "kind": "icon",
          "properties": {
            "icon": "submit",
            "width": 96,
            "height": 96,
            "color": "#FFFFFF"
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
    expect(element.kind, MotionElementKind.shape);
    expect(element.shapeKind, MotionShapeKind.customPath);
    expect(element.sourceBinding!.metadata['sceneProgramElementKind'], 'icon');

    final iconAssignment = element.properties.singleWhere(
      (assignment) => assignment.definition.id == 'asset.icon',
    );
    expect(iconAssignment.value.rawValue, 'send');
  });

  test('lowers agent-friendly aliases for typing, size, radius, and background',
      () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Agent Alias Scene",
  "durationMs": 1600,
  "frameRate": 30,
  "layers": [
    {
      "id": "prompt-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 1600,
      "elements": [
        {
          "id": "prompt-shell",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "size": { "width": 760, "height": 132 },
            "radius": 52,
            "backgroundColor": "#22242C",
            "position": { "x": 0, "y": 120 }
          }
        }
      ]
    },
    {
      "id": "typing-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1600,
      "elements": [
        {
          "id": "typing-text",
          "kind": "text",
          "text": "hello world",
          "channels": [
            {
              "property": "typewriterProgress",
              "keyframes": [
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 1200, "value": 1.0 }
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
    final shell = result.project.scenes.single.layers.first.elements.single;
    expect(
      shell.properties.map((assignment) => assignment.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.width.id,
        MotionPropertyCatalog.height.id,
        MotionPropertyCatalog.cornerRadius.id,
        'visual.color',
      ]),
    );
    final revealChannel = result.channels.singleWhere(
      (channel) =>
          channel.target.targetId == 'typing-text' &&
          channel.definition.id == MotionPropertyCatalog.revealProgress.id,
    );
    expect(revealChannel.keyframes.map((keyframe) => keyframe.value.rawValue),
        <double>[0.0, 1.0]);
    expect(result.textAnimationBindings, hasLength(1));
    final binding = result.textAnimationBindings.single;
    expect(binding.elementTarget.targetId, 'typing-text');
    expect(binding.animationBlocks.single.kind,
        MotionTextAnimationKind.typewriter);
    expect(binding.animationBlocks.single.revealSpec!.unit,
        MotionTextRevealUnit.letter);
    expect(
      binding
          .animationBlocks.single.parameters['manualRevealProgress']!.rawValue,
      isTrue,
    );
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

  test('lowers the first generated scene fixture', () {
    final source = File(
      'test/fixtures/refusion_scene_programs/first_generated_scene.json',
    ).readAsStringSync();
    final importResult = importService.validate(source: source);
    expect(importResult.isValid, isTrue);

    final result = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(program: importResult.program!),
    );

    expect(result.hasErrors, isFalse);
    expect(result.project.name, 'First Generated Scene');
    expect(result.project.scenes.single.layers, hasLength(3));
    expect(result.channels, hasLength(8));
    expect(
      result.channels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.opacity.id,
        MotionPropertyCatalog.positionX.id,
        MotionPropertyCatalog.positionY.id,
        MotionPropertyCatalog.scaleX.id,
        MotionPropertyCatalog.scaleY.id,
      ]),
    );

    final background =
        result.project.scenes.single.layers.first.elements.single;
    expect(background.shapeKind, MotionShapeKind.rectangle);
    expect(
      background.properties.map((assignment) => assignment.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.width.id,
        MotionPropertyCatalog.height.id,
        'visual.color',
        MotionPropertyCatalog.opacity.id,
      ]),
    );

    final orb = result.project.scenes.single.layers[1].elements.single;
    expect(orb.shapeKind, MotionShapeKind.circle);
    expect(orb.sourceBinding!.metadata['color'], '#36D1DC');

    final springChannels = result.channels.where(
      (channel) => channel.keyframes.any(
        (keyframe) =>
            keyframe.interpolationToNext.kind == MotionInterpolationKind.spring,
      ),
    );
    expect(springChannels, isNotEmpty);

    final titlePositionY = result.channels.singleWhere(
      (channel) =>
          channel.target.targetId == 'hero-title' &&
          channel.definition.id == MotionPropertyCatalog.positionY.id,
    );
    expect(titlePositionY.keyframes.first.value.rawValue, 120);
    expect(titlePositionY.keyframes.last.value.rawValue, 0);
  });
}
