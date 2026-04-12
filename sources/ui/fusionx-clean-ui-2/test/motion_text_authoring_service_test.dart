import 'package:flutter_test/flutter_test.dart';

import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_text_authoring_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  test('authoring service inserts plain text without preset metadata', () {
    final project = MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: TimelineTime.fromSecondsDouble(10),
          ),
          layers: const <MotionLayerModel>[],
        ),
      ],
    );
    final insertionRange = TimelineTimeRange(
      start: TimelineTime.fromSecondsDouble(2),
      endExclusive: TimelineTime.fromSecondsDouble(5),
    );
    final service = BasicMotionTextElementAuthoringService(
      idFactory: (prefix) => '$prefix-fixed',
    );

    final result = service.insertTextPreset(
      MotionTextElementInsertionRequest(
        project: project,
        sceneId: 'scene',
        projectRange: insertionRange,
        text: 'Text',
        elementName: 'Text',
      ),
    );

    expect(result.didApply, isTrue);
    expect(result.createdLayer, isTrue);
    expect(result.generatedBindings, hasLength(1));

    final binding = result.generatedBindings.single;
    expect(binding.presetId, isNull);
    expect(binding.animationBlocks, isEmpty);
    expect(binding.activeRange.start.inMilliseconds, 2000);
    expect(binding.activeRange.endExclusive.inMilliseconds, 5000);

    final scene = result.project.scenes.single;
    final layer = scene.layers.single;
    final element = layer.elements.single;

    expect(layer.kind, MotionLayerKind.text);
    expect(element.kind, MotionElementKind.text);
    expect(element.name, 'Text');
    expect(element.sourceBinding?.metadata['text'], 'Text');
    expect(element.sourceBinding?.metadata.containsKey('presetId'), isFalse);
  });
}
