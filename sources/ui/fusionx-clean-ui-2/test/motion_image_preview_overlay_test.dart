import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_runtime_helpers.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/widgets/motion_image_preview_overlay.dart';

void main() {
  TimelineTime at(int milliseconds) =>
      TimelineTime.fromMilliseconds(milliseconds);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: at(startMs),
      endExclusive: at(endMs),
    );
  }

  MotionPropertyTarget imageTarget() {
    return const MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'image-element',
      projectId: 'project',
      sceneId: 'scene',
      layerId: 'image-layer',
      elementId: 'image-element',
    );
  }

  MotionPropertyAssignment assignment(
    MotionPropertyDefinition definition,
    MotionPropertyValue value,
  ) {
    return MotionPropertyAssignment(
      target: imageTarget(),
      definition: definition,
      value: value,
    );
  }

  MotionProjectModel project() {
    final element = MotionElementModel(
      id: 'image-element',
      layerId: 'image-layer',
      kind: MotionElementKind.image,
      localRange: range(0, 1000),
      sourceBinding: MotionElementSourceBinding(
        kind: MotionSourceKind.image,
        sourceId: 'asset-1',
        assetId: 'asset-1',
        label: 'Image',
      ),
      properties: <MotionPropertyAssignment>[
        assignment(
          MotionPropertyCatalog.positionX,
          const MotionPropertyValue.scalar(120),
        ),
        assignment(
          MotionPropertyCatalog.positionY,
          const MotionPropertyValue.scalar(-40),
        ),
        assignment(
          MotionPropertyCatalog.opacity,
          const MotionPropertyValue.scalar(1),
        ),
      ],
    );
    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: range(0, 1000),
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'image-layer',
              sceneId: 'scene',
              kind: MotionLayerKind.image,
              visibleRange: range(0, 1000),
              elements: <MotionElementModel>[element],
            ),
          ],
        ),
      ],
    );
  }

  ({
    MotionNormalizedComposition composition,
    MotionEvaluationSnapshot snapshot,
  }) evaluatedImageComposition() {
    final compileResult = BasicMotionCompositionCompiler().compile(
      MotionCompileRequest(project: project()),
    );
    final composition = compileResult.composition!;
    final snapshot = const BasicMotionRuntimeEvaluator().evaluate(
      MotionEvaluationRequest(
        composition: composition,
        time: at(500),
      ),
    );
    return (composition: composition, snapshot: snapshot);
  }

  testWidgets('renders graph-evaluated image nodes', (tester) async {
    final evaluated = evaluatedImageComposition();
    final bytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
      ),
    );

    expect(
      MotionImagePreviewOverlay.hasVisibleImages(
        composition: evaluated.composition,
        snapshot: evaluated.snapshot,
        assetResolver: (assetId) => MotionImagePreviewAsset(
          assetId: assetId,
          thumbnailBytes: bytes,
          width: 200,
          height: 100,
        ),
      ),
      isTrue,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 360,
          height: 640,
          child: MotionImagePreviewOverlay(
            composition: evaluated.composition,
            snapshot: evaluated.snapshot,
            canvasSize: evaluated.composition.format.canvasSize,
            assetResolver: (assetId) => MotionImagePreviewAsset(
              assetId: assetId,
              thumbnailBytes: bytes,
              width: 200,
              height: 100,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });
}
