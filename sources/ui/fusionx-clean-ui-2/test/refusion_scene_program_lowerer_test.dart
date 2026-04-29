import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_runtime_helpers.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_preview_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_render_models.dart';
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

  test('preserves scene-program text color into preview render nodes', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Dark Text On White",
  "durationMs": 1200,
  "frameRate": 30,
  "layers": [
    {
      "id": "title-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1200,
      "elements": [
        {
          "id": "title",
          "kind": "text",
          "text": "Welcome",
          "properties": {
            "fontSize": 64,
            "fontWeight": 900,
            "fontFamily": "Inter",
            "fontStyle": "italic",
            "lineHeight": 1.12,
            "textAlign": "left",
            "color": "#050505",
            "opacity": 1
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

    final compileResult = BasicMotionCompositionCompiler().compile(
      MotionCompileRequest(
        project: result.project,
        propertyChannels: result.channels,
        textAnimationBindings: result.textAnimationBindings,
      ),
    );
    expect(compileResult.hasErrors, isFalse);

    final composition = compileResult.composition!;
    final evaluation = const BasicMotionRuntimeEvaluator().evaluate(
      MotionEvaluationRequest(
        composition: composition,
        time: TimelineTime.zero,
      ),
    );
    final preview = BasicMotionTextPreviewBinder().bind(
      composition: composition,
      evaluation: evaluation,
    );
    final render = const BasicMotionTextRenderAdapter().adapt(
      composition: composition,
      preview: preview,
    );

    expect(render.nodes.single.colorArgb, 0xFF050505);
    expect(render.nodes.single.fontWeight, 900);
    expect(render.nodes.single.fontFamily, 'Inter');
    expect(render.nodes.single.fontStyle, 'italic');
    expect(render.nodes.single.lineHeight, closeTo(1.12, 0.001));
    expect(render.nodes.single.textAlignment, 'left');
  });

  test('lowers soft shadow controls as editable shape properties', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Soft Shadow Card",
  "durationMs": 1800,
  "frameRate": 30,
  "layers": [
    {
      "id": "card-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 1800,
      "elements": [
        {
          "id": "card",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 720,
            "height": 180,
            "cornerRadius": 48,
            "color": "#FFFFFF",
            "shadowOpacity": 0.24,
            "shadowBlur": 42,
            "shadowOffset": { "x": 0, "y": 26 },
            "shadowSpread": 4,
            "shadowColor": "#55111111"
          },
          "channels": [
            {
              "property": "shadowOpacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 420, "value": 0.24, "easing": "easeOutCubic" }
              ]
            },
            {
              "property": "shadowOffsetY",
              "keyframes": [
                { "timeMs": 0, "value": 8, "easing": "linear" },
                { "timeMs": 420, "value": 26, "easing": "easeOutCubic" }
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

    final card = result.project.scenes.single.layers.single.elements.single;
    expect(
      card.properties.map((assignment) => assignment.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.shadowOpacity.id,
        MotionPropertyCatalog.shadowBlur.id,
        MotionPropertyCatalog.shadowOffsetX.id,
        MotionPropertyCatalog.shadowOffsetY.id,
        MotionPropertyCatalog.shadowSpread.id,
        MotionPropertyCatalog.shadowColor.id,
      ]),
    );
    expect(
      result.channels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.shadowOpacity.id,
        MotionPropertyCatalog.shadowOffsetY.id,
      ]),
    );
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

  test('lowers After Effects-style text range selector aliases', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Range Selector Title",
  "durationMs": 1800,
  "frameRate": 30,
  "layers": [
    {
      "id": "title-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1800,
      "elements": [
        {
          "id": "title",
          "kind": "text",
          "text": "Modern Motion Title",
          "properties": {
            "fontSize": 96,
            "trackingAmount": -120
          },
          "channels": [
            {
              "property": "wordRangeSelectorProgress",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 700, "value": 1.0, "easing": "easeOutCubic" }
              ]
            },
            {
              "property": "trackingAmount",
              "keyframes": [
                { "timeMs": 0, "value": -120, "easing": "easeOutCubic" },
                { "timeMs": 700, "value": 0, "easing": "easeOutCubic" }
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
    final title = result.project.scenes.single.layers.single.elements.single;
    expect(
      title.properties
          .singleWhere(
            (assignment) =>
                assignment.definition.id ==
                MotionPropertyCatalog.letterSpacing.id,
          )
          .value
          .rawValue,
      -120,
    );

    final revealChannel = result.channels.singleWhere(
      (channel) =>
          channel.definition.id == MotionPropertyCatalog.revealProgress.id,
    );
    expect(
      revealChannel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[0.0, 1.0],
    );
    final trackingChannel = result.channels.singleWhere(
      (channel) =>
          channel.definition.id == MotionPropertyCatalog.letterSpacing.id,
    );
    expect(
      trackingChannel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[-120, 0],
    );

    expect(result.textAnimationBindings, hasLength(1));
    final binding = result.textAnimationBindings.single;
    expect(binding.animationBlocks.single.kind,
        MotionTextAnimationKind.wordReveal);
    expect(binding.animationBlocks.single.revealSpec!.unit,
        MotionTextRevealUnit.word);
  });

  test('lowers mask reveal elements into editable mask channels', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Moving Mask Reveal Scene",
  "durationMs": 2400,
  "frameRate": 30,
  "layers": [
    {
      "id": "title-mask-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 2400,
      "elements": [
        {
          "id": "title-mask",
          "kind": "mask",
          "properties": {
            "maskTarget": "title",
            "maskMode": "alpha",
            "revealDirection": "leftToRight",
            "position": { "x": -340, "y": 0 },
            "width": 80,
            "height": 180,
            "color": "#FFFFFF"
          },
          "channels": [
            {
              "property": "movingMaskReveal",
              "keyframes": [
                { "timeMs": 900, "value": 0.0, "easing": "linear" },
                { "timeMs": 1500, "value": 1.0, "easing": "easeOutCubic" }
              ]
            },
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 900, "value": { "x": -340, "y": 0 }, "easing": "easeOutCubic" },
                { "timeMs": 1500, "value": { "x": 340, "y": 0 }, "easing": "easeOutCubic" }
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
    final element = result.project.scenes.single.layers.single.elements.single;
    expect(element.kind, MotionElementKind.mask);
    expect(element.shapeKind, MotionShapeKind.mask);
    expect(element.sourceBinding!.metadata['maskTarget'], 'title');
    expect(element.sourceBinding!.metadata['maskMode'], 'alpha');
    expect(element.sourceBinding!.metadata['revealDirection'], 'leftToRight');
    expect(
      element.properties.map((assignment) => assignment.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.positionX.id,
        MotionPropertyCatalog.positionY.id,
        MotionPropertyCatalog.width.id,
        MotionPropertyCatalog.height.id,
        'visual.color',
      ]),
    );
    final revealChannel = result.channels.singleWhere(
      (channel) => channel.definition.id == 'mask.revealProgress',
    );
    expect(revealChannel.target.targetId, 'title-mask');
    expect(
      revealChannel.keyframes.map((keyframe) => keyframe.time.inMilliseconds),
      <int>[900, 1500],
    );
    expect(
      revealChannel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[0.0, 1.0],
    );
    expect(
      result.channels.map((channel) => channel.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.positionX.id,
        MotionPropertyCatalog.positionY.id,
      ]),
    );
  });

  test('lowers shape morph aliases for size and roundness animation', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Circle To Bar Morph",
  "durationMs": 2200,
  "frameRate": 30,
  "layers": [
    {
      "id": "morph-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 2200,
      "elements": [
        {
          "id": "wipe-shape",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "morphSize": { "width": 96, "height": 96 },
            "roundness": 48,
            "backgroundColor": "#FFFFFF"
          },
          "channels": [
            {
              "property": "morphSize",
              "keyframes": [
                { "timeMs": 600, "value": { "width": 96, "height": 96 }, "easing": "easeOutCubic" },
                { "timeMs": 1200, "value": { "width": 680, "height": 28 }, "easing": "easeOutCubic" }
              ]
            },
            {
              "property": "roundness",
              "keyframes": [
                { "timeMs": 600, "value": 48, "easing": "easeOutCubic" },
                { "timeMs": 1200, "value": 14, "easing": "easeOutCubic" }
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
    final element = result.project.scenes.single.layers.single.elements.single;
    expect(element.shapeKind, MotionShapeKind.roundedRectangle);
    expect(
      element.properties.map((assignment) => assignment.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.width.id,
        MotionPropertyCatalog.height.id,
        MotionPropertyCatalog.cornerRadius.id,
        'visual.color',
      ]),
    );
    final widthChannel = result.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.width.id,
    );
    final heightChannel = result.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.height.id,
    );
    final roundnessChannel = result.channels.singleWhere(
      (channel) =>
          channel.definition.id == MotionPropertyCatalog.cornerRadius.id,
    );
    expect(
      widthChannel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[96, 680],
    );
    expect(
      heightChannel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[96, 28],
    );
    expect(
      roundnessChannel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[48, 14],
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

  test('lowers line trim path controls into editable shape channels', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Line Trim Reveal",
  "durationMs": 1600,
  "frameRate": 30,
  "layers": [
    {
      "id": "line-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 1600,
      "elements": [
        {
          "id": "line",
          "kind": "shape",
          "properties": {
            "shapeKind": "line",
            "width": 640,
            "height": 10,
            "trimStart": 0,
            "trimEnd": 0
          },
          "channels": [
            {
              "property": "lineReveal",
              "keyframes": [
                { "timeMs": 200, "value": 0, "easing": "linear" },
                { "timeMs": 900, "value": 100, "easing": "easeOutCubic" }
              ]
            },
            {
              "property": "trimOffset",
              "keyframes": [
                { "timeMs": 900, "value": 0, "easing": "linear" },
                { "timeMs": 1200, "value": 0.1, "easing": "linear" }
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
    final line = result.project.scenes.single.layers.single.elements.single;
    expect(line.shapeKind, MotionShapeKind.line);
    expect(
      line.properties.map((assignment) => assignment.definition.id),
      containsAll(<String>[
        MotionPropertyCatalog.trimStart.id,
        MotionPropertyCatalog.trimEnd.id,
      ]),
    );

    final trimEndChannel = result.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.trimEnd.id,
    );
    expect(
      trimEndChannel.keyframes.map((keyframe) => keyframe.value.rawValue),
      <double>[0, 100],
    );

    final trimOffsetChannel = result.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.trimOffset.id,
    );
    expect(trimOffsetChannel.keyframes.last.value.rawValue, 0.1);
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
