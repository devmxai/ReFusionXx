import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_runtime_helpers.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/widgets/motion_video_preview_transform.dart';

void main() {
  const resolver = MotionVideoPreviewTransformResolver();

  TimelineTime at(int milliseconds) =>
      TimelineTime.fromMilliseconds(milliseconds);

  TimelineTimeRange range(int startMs, int endMs) {
    return TimelineTimeRange(
      start: at(startMs),
      endExclusive: at(endMs),
    );
  }

  MotionPropertyTarget videoTarget(String elementId, String layerId) {
    return MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: elementId,
      projectId: 'project',
      sceneId: 'scene',
      layerId: layerId,
      elementId: elementId,
    );
  }

  MotionPropertyAssignment assignment({
    required String elementId,
    required String layerId,
    required MotionPropertyDefinition definition,
    required MotionPropertyValue value,
  }) {
    return MotionPropertyAssignment(
      target: videoTarget(elementId, layerId),
      definition: definition,
      value: value,
    );
  }

  MotionElementModel videoElement({
    required String id,
    required String layerId,
    required String assetId,
    double positionX = 0,
    double positionY = 0,
    double scaleX = 1,
    double scaleY = 1,
    double rotation = 0,
    double opacity = 1,
    double blur = 0,
  }) {
    return MotionElementModel(
      id: id,
      layerId: layerId,
      kind: MotionElementKind.videoClip,
      localRange: range(0, 3000),
      sourceBinding: MotionElementSourceBinding(
        kind: MotionSourceKind.video,
        sourceId: assetId,
        assetId: assetId,
        label: 'Video',
      ),
      properties: <MotionPropertyAssignment>[
        assignment(
          elementId: id,
          layerId: layerId,
          definition: MotionPropertyCatalog.positionX,
          value: MotionPropertyValue.scalar(positionX),
        ),
        assignment(
          elementId: id,
          layerId: layerId,
          definition: MotionPropertyCatalog.positionY,
          value: MotionPropertyValue.scalar(positionY),
        ),
        assignment(
          elementId: id,
          layerId: layerId,
          definition: MotionPropertyCatalog.scaleX,
          value: MotionPropertyValue.scalar(scaleX),
        ),
        assignment(
          elementId: id,
          layerId: layerId,
          definition: MotionPropertyCatalog.scaleY,
          value: MotionPropertyValue.scalar(scaleY),
        ),
        assignment(
          elementId: id,
          layerId: layerId,
          definition: MotionPropertyCatalog.rotationDegrees,
          value: MotionPropertyValue.scalar(rotation),
        ),
        assignment(
          elementId: id,
          layerId: layerId,
          definition: MotionPropertyCatalog.opacity,
          value: MotionPropertyValue.scalar(opacity),
        ),
        assignment(
          elementId: id,
          layerId: layerId,
          definition: MotionPropertyCatalog.blurAmount,
          value: MotionPropertyValue.scalar(blur),
        ),
      ],
    );
  }

  ({
    MotionNormalizedComposition composition,
    MotionEvaluationSnapshot snapshot,
  }) evaluate(MotionProjectModel project) {
    final compileResult = BasicMotionCompositionCompiler().compile(
      MotionCompileRequest(project: project),
    );
    final composition = compileResult.composition!;
    final snapshot = const BasicMotionRuntimeEvaluator().evaluate(
      MotionEvaluationRequest(
        composition: composition,
        time: at(1000),
      ),
    );
    return (composition: composition, snapshot: snapshot);
  }

  MotionProjectModel project({
    List<MotionLayerModel>? layers,
  }) {
    return MotionProjectModel(
      id: 'project',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene',
          projectRange: range(0, 3000),
          layers: layers ?? const <MotionLayerModel>[],
        ),
      ],
    );
  }

  test('resolves graph-evaluated video transform values', () {
    final element = videoElement(
      id: 'video-element',
      layerId: 'video-layer',
      assetId: 'asset-video',
      positionX: 120,
      positionY: -48,
      scaleX: 1.25,
      scaleY: 0.82,
      rotation: 9,
      opacity: 0.6,
      blur: 8,
    );
    final evaluated = evaluate(
      project(
        layers: <MotionLayerModel>[
          MotionLayerModel(
            id: 'video-layer',
            sceneId: 'scene',
            kind: MotionLayerKind.video,
            visibleRange: range(0, 3000),
            elements: <MotionElementModel>[element],
          ),
        ],
      ),
    );

    final transform = resolver.resolve(
      composition: evaluated.composition,
      snapshot: evaluated.snapshot,
      preferredAssetId: 'asset-video',
    );

    expect(transform, isNotNull);
    expect(transform!.elementId, 'video-element');
    expect(transform.assetId, 'asset-video');
    expect(transform.positionX, 120);
    expect(transform.positionY, -48);
    expect(transform.scaleX, 1.25);
    expect(transform.scaleY, 0.82);
    expect(transform.rotationDegrees, 9);
    expect(transform.opacity, 0.6);
    expect(transform.blurAmount, 8);
  });

  test('selects the preferred video asset when several videos are active', () {
    final first = videoElement(
      id: 'first-video',
      layerId: 'first-layer',
      assetId: 'asset-first',
      positionX: -100,
    );
    final second = videoElement(
      id: 'second-video',
      layerId: 'second-layer',
      assetId: 'asset-second',
      positionX: 220,
    );
    final evaluated = evaluate(
      project(
        layers: <MotionLayerModel>[
          MotionLayerModel(
            id: 'first-layer',
            sceneId: 'scene',
            kind: MotionLayerKind.video,
            visibleRange: range(0, 3000),
            elements: <MotionElementModel>[first],
            zIndex: 5,
          ),
          MotionLayerModel(
            id: 'second-layer',
            sceneId: 'scene',
            kind: MotionLayerKind.video,
            visibleRange: range(0, 3000),
            elements: <MotionElementModel>[second],
            zIndex: 1,
          ),
        ],
      ),
    );

    final transform = resolver.resolve(
      composition: evaluated.composition,
      snapshot: evaluated.snapshot,
      preferredAssetId: 'asset-second',
    );

    expect(transform, isNotNull);
    expect(transform!.elementId, 'second-video');
    expect(transform.positionX, 220);
  });

  testWidgets('applies a transition surface transform without graph transform',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 540,
          height: 960,
          child: MotionVideoPreviewTransformSurface(
            transform: null,
            surfaceTransform: MotionVideoPreviewSurfaceTransform(
              scaleX: 2,
              scaleY: 2,
              blurAmount: 12,
            ),
            canvasSize: MotionSize2D(width: 1080, height: 1920),
            child: SizedBox(key: ValueKey<String>('native-video')),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('native-video')), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(Transform), findsWidgets);
    expect(find.byType(ClipRect), findsOneWidget);
  });
}
