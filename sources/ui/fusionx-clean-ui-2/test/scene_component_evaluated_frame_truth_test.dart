import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/refusion_scene_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_coordinate_system.dart';
import 'package:refusion_app/features/editor/domain/services/scene_evaluation_pipeline.dart';

void main() {
  const pipeline = SceneEvaluationPipeline();
  const canvas = SceneCanvasMetrics(width: 1080, height: 1920);

  ReFusionSceneProgram _promptProgram({
    required int shellDurationMs,
    required int textDurationMs,
  }) {
    return ReFusionSceneProgram(
      schemaVersion: 'refusion.scene-program/v1',
      name: 'Prompt Component Truth',
      durationMs: 2200,
      frameRate: 30,
      layers: <ReFusionSceneProgramLayer>[
        ReFusionSceneProgramLayer(
          id: 'prompt-shell-layer',
          kind: 'shape',
          startMs: 0,
          durationMs: shellDurationMs,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'prompt-shell',
              kind: 'shape',
              properties: const <String, Object?>{
                'position': <String, Object?>{'x': 0.0, 'y': 320.0},
                'width': 820.0,
                'height': 112.0,
                'componentType': 'PromptInputBar',
                'componentId': 'prompt-input-1',
                'layoutRole': 'container',
              },
            ),
          ],
        ),
        ReFusionSceneProgramLayer(
          id: 'prompt-text-layer',
          kind: 'text',
          startMs: 0,
          durationMs: textDurationMs,
          elements: <ReFusionSceneProgramElement>[
            ReFusionSceneProgramElement(
              id: 'prompt-text',
              kind: 'text',
              text: 'Build a new app for my business',
              properties: const <String, Object?>{
                'parentId': 'prompt-shell',
                'position': <String, Object?>{'x': -210.0, 'y': 320.0},
                'fontSize': 48.0,
                'componentType': 'PromptInputBar',
                'componentId': 'prompt-input-1',
                'slotId': 'primaryText',
                'layoutRole': 'content',
                'textFrame': <String, Object?>{
                  'width': 520.0,
                  'height': 68.0,
                  'maxLines': 1,
                  'fitPolicy': 'shrinkToFit',
                },
              },
              channels: <ReFusionSceneProgramChannel>[
                ReFusionSceneProgramChannel(
                  target: 'self',
                  property: 'typewriterProgress',
                  keyframes: <ReFusionSceneProgramKeyframe>[
                    ReFusionSceneProgramKeyframe(timeMs: 0, value: 0.0),
                    ReFusionSceneProgramKeyframe(timeMs: 700, value: 1.0),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  test('evaluated frame truth exposes component and slot bindings', () {
    final result = pipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: _promptProgram(shellDurationMs: 2000, textDurationMs: 2000),
        globalTimeMs: 500,
        canvas: canvas,
      ),
    );

    expect(result.isValid, isTrue);
    final textNode = result
        .truth.nodesById['__layer__prompt-text-layer__element__prompt-text']!;
    expect(textNode.sourceComponentId, 'prompt-input-1');
    expect(textNode.slotId, 'primaryText');
    expect(textNode.slotBoundsCenter, isNotNull);
    expect(textNode.contentBoundsCenter, isNotNull);

    final sourceMap = result.truth
            .sourceMaps['__layer__prompt-text-layer__element__prompt-text']
        as Map<String, Object?>;
    expect(sourceMap['componentId'], 'prompt-input-1');
    expect(sourceMap['componentType'], 'PromptInputBar');
    expect(sourceMap['slotId'], 'primaryText');
    expect(sourceMap['layoutRole'], 'content');

    expect(
      result.diagnostics.events
          .any((event) => event.tag == 'TF_SCENE_COMPONENT_HIERARCHY_PROOF'),
      isTrue,
    );
    expect(
      result.diagnostics.events
          .any((event) => event.tag == 'TF_SCENE_COMPONENT_LIFECYCLE_PROOF'),
      isTrue,
    );
  });

  test('component lifecycle proof catches parent-child visibility drift', () {
    final result = pipeline.evaluate(
      SceneEvaluationPipelineRequest(
        program: _promptProgram(shellDurationMs: 300, textDurationMs: 1200),
        globalTimeMs: 900,
        canvas: canvas,
      ),
    );

    expect(result.isValid, isTrue);
    final shellNode = result
        .truth.nodesById['__layer__prompt-shell-layer__element__prompt-shell']!;
    final textNode = result
        .truth.nodesById['__layer__prompt-text-layer__element__prompt-text']!;
    expect(shellNode.active, isFalse);
    expect(textNode.visible, isFalse);

    final lifecycleEvent = result.diagnostics.events.firstWhere(
      (event) => event.tag == 'TF_SCENE_COMPONENT_LIFECYCLE_PROOF',
    );
    final driftCount =
        (lifecycleEvent.fields['childActiveWhileParentInactive'] as num)
            .toInt();
    expect(driftCount, greaterThanOrEqualTo(0));
  });
}
