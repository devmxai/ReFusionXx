import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_authoring_service.dart';

void main() {
  const service = ReFusionSceneProgramAuthoringService();

  test('validates and lowers a scene program in one authoring pass', () {
    final source = File(
      'test/fixtures/refusion_scene_programs/first_generated_scene.json',
    ).readAsStringSync();

    final result = service.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: source,
        fileName: 'first_generated_scene.json',
        projectId: 'agent-scene-project',
        sceneId: 'agent-scene',
        canvasSize: const MotionSize2D(width: 720, height: 1280),
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.program!.name, 'First Generated Scene');
    expect(result.project!.id, 'agent-scene-project');
    expect(result.project!.scenes.single.id, 'agent-scene');
    expect(result.project!.format.canvasSize.width, 720);
    expect(result.project!.format.canvasSize.height, 1280);
    expect(result.project!.metadata['source'], 'refusion.scene-program');
    expect(result.channels, hasLength(8));
    expect(result.hasWarnings, isFalse);
  });

  test('does not lower invalid JSON or executable scene programs', () {
    final result = service.importSceneProgram(
      const ReFusionSceneProgramAuthoringRequest(
        source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "durationMs": 1000,
  "layers": [
    {
      "id": "layer-1",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1000,
      "elements": [
        {
          "id": "title",
          "kind": "text",
          "text": "Unsafe",
          "properties": {
            "script": "run()"
          }
        }
      ]
    }
  ]
}
''',
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.project, isNull);
    expect(result.channels, isEmpty);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.path == 'layers[0].elements[0].properties.script',
      ),
      isNotEmpty,
    );
  });

  test('returns warnings while keeping a lowerable partial scene valid', () {
    final result = service.importSceneProgram(
      const ReFusionSceneProgramAuthoringRequest(
        source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Warn But Lower",
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
          "text": "Partial",
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 300, "value": 1.0 }
              ]
            },
            {
              "property": "unsupported.magic",
              "keyframes": [
                { "timeMs": 0, "value": 1 },
                { "timeMs": 300, "value": 2 }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''',
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.hasWarnings, isTrue);
    expect(result.project, isNotNull);
    expect(result.channels, hasLength(1));
  });

  test('rejects duplicate target/property channels before lowering', () {
    final result = service.importSceneProgram(
      const ReFusionSceneProgramAuthoringRequest(
        source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Duplicate Channels",
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
          "text": "Duplicate",
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 300, "value": 1.0 }
              ]
            },
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 600, "value": 1.0 },
                { "timeMs": 900, "value": 0.0 }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''',
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.project, isNull);
    expect(result.channels, isEmpty);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('Duplicate Scene Program channel'),
      ),
      isNotEmpty,
    );
  });

  test('returns typewriter bindings for scene-program typing channels', () {
    final result = service.importSceneProgram(
      const ReFusionSceneProgramAuthoringRequest(
        source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Typing Scene",
  "durationMs": 1800,
  "frameRate": 30,
  "layers": [
    {
      "id": "typing-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1800,
      "elements": [
        {
          "id": "typing-text",
          "kind": "text",
          "text": "hello world",
          "channels": [
            {
              "property": "typingProgress",
              "keyframes": [
                { "timeMs": 0, "value": 0.0 },
                { "timeMs": 1400, "value": 1.0 }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''',
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.textAnimationBindings, hasLength(1));
    expect(result.textAnimationBindings.single.elementTarget.targetId,
        'typing-text');
    expect(result.textAnimationBindings.single.animationBlocks.single.kind,
        MotionTextAnimationKind.typewriter);
  });

  test('rejects broken layout parent contracts before lowering', () {
    final result = service.importSceneProgram(
      const ReFusionSceneProgramAuthoringRequest(
        source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Broken Layout",
  "durationMs": 1200,
  "frameRate": 30,
  "layers": [
    {
      "id": "text-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 1200,
      "elements": [
        {
          "id": "prompt-text",
          "kind": "text",
          "text": "Broken",
          "properties": {
            "parentId": "missing-shell"
          }
        }
      ]
    }
  ]
}
''',
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.project, isNull);
    expect(result.channels, isEmpty);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('does not exist'),
      ),
      isNotEmpty,
    );
  });

  test('rejects PromptInputBar scenes that violate component-safe text rules',
      () {
    final result = service.importSceneProgram(
      const ReFusionSceneProgramAuthoringRequest(
        source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Broken Prompt Input",
  "durationMs": 2400,
  "frameRate": 30,
  "layers": [
    {
      "id": "prompt-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 2400,
      "elements": [
        {
          "id": "prompt-shell",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "position": { "x": 0, "y": -40 },
            "width": 860,
            "height": 118
          }
        },
        {
          "id": "prompt-text",
          "kind": "text",
          "text": "generate new offer for my business",
          "properties": {
            "position": { "x": -135, "y": -28 },
            "fontSize": 38,
            "textAlign": "left"
          }
        },
        {
          "id": "send-button",
          "kind": "shape",
          "properties": {
            "position": { "x": 355, "y": -40 },
            "width": 76,
            "height": 76
          }
        }
      ]
    }
  ]
}
''',
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.project, isNull);
    expect(result.channels, isEmpty);
    expect(
      result.issues.where(
        (issue) =>
            issue.severity == ReFusionSceneProgramIssueSeverity.error &&
            issue.message.contains('PromptInputBar'),
      ),
      isNotEmpty,
    );
  });
}
