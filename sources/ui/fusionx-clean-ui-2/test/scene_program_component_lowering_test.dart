import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_import_service.dart';
import 'package:refusion_app/features/editor/domain/services/refusion_scene_program_lowerer.dart';

void main() {
  const lowerer = ReFusionSceneProgramLowerer();
  const importService = ReFusionSceneProgramImportService();

  test('preserves component, slot, and parent metadata through lowering', () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Component Lowering Proof',
      durationMs: 3000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'prompt-layer',
          kind: 'shape',
          startMs: 1000,
          durationMs: 1400,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'prompt-shell',
              kind: 'shape',
              properties: const <String, Object?>{
                'componentType': 'PromptInputBar',
                'layoutRole': 'container',
                'width': 820,
                'height': 104,
              },
            ),
            ReFusionSceneProgramElement(
              id: 'prompt-text',
              kind: 'text',
              text: 'Build an app',
              properties: const <String, Object?>{
                'componentType': 'PromptInputBar',
                'slotId': 'primaryText',
                'parentId': 'prompt-shell',
                'layoutRole': 'content',
                'textFrame': <String, Object?>{
                  'width': 620,
                  'height': 64,
                  'maxLines': 1,
                  'fitPolicy': 'shrinkToFit',
                },
              },
              channels: <ReFusionSceneProgramChannel>[
                ReFusionSceneProgramChannel(
                  target: 'self',
                  property: 'opacity',
                  keyframes: <ReFusionSceneProgramKeyframe>[
                    ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
                    ReFusionSceneProgramKeyframe(timeMs: 400, value: 1.0),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final result = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(program: program),
    );

    expect(result.hasErrors, isFalse);
    final text = result.project.scenes.single.layers.single.elements
        .singleWhere((element) => element.id == 'prompt-text');
    final metadata = text.sourceBinding!.metadata;
    expect(metadata['layout.parentId'], 'prompt-shell');
    expect(metadata['layout.componentType'], 'PromptInputBar');
    expect(metadata['layout.slotId'], 'primaryText');
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains(kSceneProgramComponentLowererProofTag),
      ),
      isTrue,
    );

    final opacity = result.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.opacity.id,
    );
    expect(opacity.keyframes.first.time.inMilliseconds, 1000);
    expect(opacity.keyframes.last.time.inMilliseconds, 1400);
  });

  test('does not double-offset explicit project time keyframes', () {
    final importResult = importService.validate(
      source: '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Project Time Basis",
  "durationMs": 3600,
  "frameRate": 30,
  "layers": [
    {
      "id": "delayed-layer",
      "kind": "shape",
      "startMs": 1200,
      "durationMs": 1600,
      "elements": [
        {
          "id": "cta-shell",
          "kind": "shape",
          "properties": { "width": 520, "height": 120 },
          "channels": [
            {
              "target": "self",
              "property": "opacity",
              "timeBasis": "project",
              "keyframes": [
                { "timeMs": 1250, "value": 0.0, "easing": "linear" },
                { "timeMs": 1800, "value": 1.0, "easing": "linear" }
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

    final opacity = result.channels.singleWhere(
      (channel) => channel.definition.id == MotionPropertyCatalog.opacity.id,
    );
    expect(opacity.keyframes.first.time.inMilliseconds, 1250);
    expect(opacity.keyframes.last.time.inMilliseconds, 1800);
    expect(
      result.issues.any(
        (issue) =>
            issue.message.contains(kSceneProgramComponentLowererProofTag),
      ),
      isTrue,
    );
  });

  test('lowers border color and border width shape properties', () {
    final program = ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Border Proof',
      durationMs: 2000,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'shell-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: 2000,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'shell',
              kind: 'shape',
              properties: const <String, Object?>{
                'width': 820,
                'height': 112,
                'color': '#FFFFFF',
                'borderWidth': 1.8,
                'borderColor': '#D1D5DB',
              },
            ),
          ],
        ),
      ],
    );

    final result = lowerer.lower(
      ReFusionSceneProgramLoweringRequest(program: program),
    );
    expect(result.hasErrors, isFalse);
    final element = result.project.scenes.single.layers.single.elements.single;
    final definitions = element.properties
        .map((assignment) => assignment.definition.id)
        .toSet();
    expect(definitions.contains('visual.borderWidth'), isTrue);
    expect(definitions.contains('visual.borderColor'), isTrue);
  });
}
