import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/export_composition_builder.dart';
import 'package:refusion_app/features/editor/domain/models/export_composition_models.dart';
import 'package:refusion_app/features/editor/domain/models/export_motion_text_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_compilation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/scene_export_parity_gate.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  const builder = ExportCompositionBuilder();
  const gate = SceneExportParityGate();

  TimelineTimeRange range(double startSeconds, double endSeconds) {
    return TimelineTimeRange(
      start: TimelineTime.fromSecondsDouble(startSeconds),
      endExclusive: TimelineTime.fromSecondsDouble(endSeconds),
    );
  }

  ExportProjectFormatDescriptor format({double durationSeconds = 3}) {
    return ExportProjectFormatDescriptor(
      canvasWidth: 1080,
      canvasHeight: 1920,
      pixelAspectRatio: 1.0,
      frameRateNumerator: 30,
      frameRateDenominator: 1,
      durationTime: TimelineTime.fromSecondsDouble(durationSeconds),
    );
  }

  List<ExportAssetDescriptor> baselineAssets() {
    return const <ExportAssetDescriptor>[
      ExportAssetDescriptor(
        assetId: 'asset-video',
        kind: ExportAssetKind.video,
        label: 'Video',
        sourceUri: '/tmp/video.mp4',
      ),
    ];
  }

  List<ExportTrackSeed> baselineVideoTrack({double durationSeconds = 3}) {
    return <ExportTrackSeed>[
      ExportTrackSeed(
        kind: ExportTrackKind.video,
        clips: <ExportClipSeed>[
          ExportClipSeed(
            clipId: 'clip-video',
            assetId: 'asset-video',
            timelineStartTime: TimelineTime.zero,
            timelineDurationTime:
                TimelineTime.fromSecondsDouble(durationSeconds),
            sourceStartTime: TimelineTime.zero,
            sourceDurationTime: TimelineTime.fromSecondsDouble(durationSeconds),
            playbackRate: 1.0,
            speedMode: ExportClipSpeedMode.normal,
          ),
        ],
      ),
    ];
  }

  MotionResolvedPropertyChannel opacityChannel({
    required String id,
    required MotionPropertyTarget target,
  }) {
    return MotionResolvedPropertyChannel(
      channel: MotionPropertyChannelModel(
        id: id,
        target: target,
        definition: MotionPropertyCatalog.opacity,
        activeRange: range(0, 3),
        baseValue: const MotionPropertyValue.scalar(1.0),
        keyframes: <MotionKeyframeModel>[
          MotionKeyframeModel(
            id: '$id.0',
            channelId: id,
            time: TimelineTime.zero,
            value: const MotionPropertyValue.scalar(0.0),
            interpolationToNext: const MotionInterpolationSpec.easeOut(),
          ),
          MotionKeyframeModel(
            id: '$id.1',
            channelId: id,
            time: TimelineTime.fromSecondsDouble(1),
            value: const MotionPropertyValue.scalar(1.0),
            interpolationToNext: const MotionInterpolationSpec.linear(),
          ),
        ],
      ),
      projectRange: range(0, 3),
      targetAddress: target.canonicalAddress,
    );
  }

  MotionNormalizedComposition textComposition() {
    const elementTarget = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'text-1',
      sceneId: 'scene-1',
      layerId: 'layer-text',
      elementId: 'text-1',
    );
    final element = MotionResolvedElementModel(
      id: 'text-1',
      sourceElementId: 'source-text-1',
      sceneId: 'scene-1',
      layerId: 'layer-text',
      kind: MotionElementKind.text,
      projectRange: range(0, 3),
      localRange: range(0, 3),
      name: 'Hero Text',
      sourceBinding: MotionElementSourceBinding(
        kind: MotionSourceKind.generatedText,
        sourceId: 'text-source-1',
        label: 'Hero Text',
        sourceRange: range(0, 3),
        metadata: const <String, String>{'text': 'ReFusion'},
      ),
      staticProperties: const <MotionPropertyAssignment>[],
      propertyChannels: <MotionResolvedPropertyChannel>[
        opacityChannel(id: 'text-opacity', target: elementTarget),
      ],
    );
    return MotionNormalizedComposition(
      projectId: 'project-text-scene',
      projectRange: range(0, 3),
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionResolvedSceneModel>[
        MotionResolvedSceneModel(
          id: 'scene-1',
          sourceSceneId: 'source-scene-1',
          projectRange: range(0, 3),
          layers: <MotionResolvedLayerModel>[
            MotionResolvedLayerModel(
              id: 'layer-text',
              sourceLayerId: 'source-layer-text',
              sceneId: 'scene-1',
              kind: MotionLayerKind.text,
              projectRange: range(0, 3),
              zIndex: 2,
              elements: <MotionResolvedElementModel>[element],
              staticProperties: const <MotionPropertyAssignment>[],
              propertyChannels: const <MotionResolvedPropertyChannel>[],
            ),
          ],
          staticProperties: const <MotionPropertyAssignment>[],
          propertyChannels: const <MotionResolvedPropertyChannel>[],
        ),
      ],
      globalChannels: const <MotionResolvedPropertyChannel>[],
      effects: const <MotionResolvedEffectModel>[],
      transitions: const <MotionResolvedTransitionModel>[],
      cameras: const <MotionResolvedCameraModel>[],
      textAnimations: const <MotionResolvedTextAnimationModel>[],
    );
  }

  MotionNormalizedComposition shapeComposition() {
    const elementTarget = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'shape-1',
      sceneId: 'scene-1',
      layerId: 'layer-shape',
      elementId: 'shape-1',
    );
    final element = MotionResolvedElementModel(
      id: 'shape-1',
      sourceElementId: 'source-shape-1',
      sceneId: 'scene-1',
      layerId: 'layer-shape',
      kind: MotionElementKind.shape,
      projectRange: range(0, 3),
      localRange: range(0, 3),
      name: 'Accent Line',
      shapeKind: MotionShapeKind.rectangle,
      sourceBinding: MotionElementSourceBinding(
        kind: MotionSourceKind.generatedShape,
        sourceId: 'shape-source-1',
        sourceRange: range(0, 3),
      ),
      staticProperties: const <MotionPropertyAssignment>[],
      propertyChannels: <MotionResolvedPropertyChannel>[
        opacityChannel(id: 'shape-opacity', target: elementTarget),
      ],
    );
    return MotionNormalizedComposition(
      projectId: 'project-shape-scene',
      projectRange: range(0, 3),
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionResolvedSceneModel>[
        MotionResolvedSceneModel(
          id: 'scene-1',
          sourceSceneId: 'source-scene-1',
          projectRange: range(0, 3),
          layers: <MotionResolvedLayerModel>[
            MotionResolvedLayerModel(
              id: 'layer-shape',
              sourceLayerId: 'source-layer-shape',
              sceneId: 'scene-1',
              kind: MotionLayerKind.shape,
              projectRange: range(0, 3),
              zIndex: 1,
              elements: <MotionResolvedElementModel>[element],
              staticProperties: const <MotionPropertyAssignment>[],
              propertyChannels: const <MotionResolvedPropertyChannel>[],
            ),
          ],
          staticProperties: const <MotionPropertyAssignment>[],
          propertyChannels: const <MotionResolvedPropertyChannel>[],
        ),
      ],
      globalChannels: const <MotionResolvedPropertyChannel>[],
      effects: const <MotionResolvedEffectModel>[],
      transitions: const <MotionResolvedTransitionModel>[],
      cameras: const <MotionResolvedCameraModel>[],
      textAnimations: const <MotionResolvedTextAnimationModel>[],
    );
  }

  MotionNormalizedComposition videoComposition() {
    const elementTarget = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: 'video-1',
      sceneId: 'scene-1',
      layerId: 'layer-video',
      elementId: 'video-1',
    );
    final element = MotionResolvedElementModel(
      id: 'video-1',
      sourceElementId: 'source-video-1',
      sceneId: 'scene-1',
      layerId: 'layer-video',
      kind: MotionElementKind.videoClip,
      projectRange: range(0, 3),
      localRange: range(0, 3),
      name: 'Scene Video',
      sourceBinding: MotionElementSourceBinding(
        kind: MotionSourceKind.video,
        sourceId: 'video-source-1',
        assetId: 'asset-video',
        sourceRange: range(0, 3),
      ),
      staticProperties: const <MotionPropertyAssignment>[],
      propertyChannels: <MotionResolvedPropertyChannel>[
        opacityChannel(id: 'video-opacity', target: elementTarget),
      ],
    );
    return MotionNormalizedComposition(
      projectId: 'project-video-scene',
      projectRange: range(0, 3),
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionResolvedSceneModel>[
        MotionResolvedSceneModel(
          id: 'scene-1',
          sourceSceneId: 'source-scene-1',
          projectRange: range(0, 3),
          layers: <MotionResolvedLayerModel>[
            MotionResolvedLayerModel(
              id: 'layer-video',
              sourceLayerId: 'source-layer-video',
              sceneId: 'scene-1',
              kind: MotionLayerKind.video,
              projectRange: range(0, 3),
              zIndex: 1,
              elements: <MotionResolvedElementModel>[element],
              staticProperties: const <MotionPropertyAssignment>[],
              propertyChannels: const <MotionResolvedPropertyChannel>[],
            ),
          ],
          staticProperties: const <MotionPropertyAssignment>[],
          propertyChannels: const <MotionResolvedPropertyChannel>[],
        ),
      ],
      globalChannels: const <MotionResolvedPropertyChannel>[],
      effects: const <MotionResolvedEffectModel>[],
      transitions: const <MotionResolvedTransitionModel>[],
      cameras: const <MotionResolvedCameraModel>[],
      textAnimations: const <MotionResolvedTextAnimationModel>[],
    );
  }

  test('accepts generated text motion when a media baseline track exists', () {
    final motion = textComposition();
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-text-export-ready',
        projectFormat: format(),
        assets: baselineAssets(),
        timelineTracks: baselineVideoTrack(),
        motionComposition: motion,
        motionTextProgram: buildExportMotionTextProgram(motion),
      ),
    );

    final result = gate.evaluate(composition);

    expect(result.hasSceneMotion, isTrue);
    expect(result.hasBaselineVisualTrack, isTrue);
    expect(result.motionTextElementCount, 1);
    expect(result.motionNonTextElementCount, 0);
    expect(result.motionTextProgramNodeCount, 1);
    expect(result.hasBlockers, isFalse);
    expect(result.isProductionExportReady, isTrue);
  });

  test('blocks scene-only export until native canvas rendering exists', () {
    final motion = textComposition();
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-scene-only',
        projectFormat: format(),
        assets: const <ExportAssetDescriptor>[],
        timelineTracks: const <ExportTrackSeed>[],
        motionComposition: motion,
        motionTextProgram: buildExportMotionTextProgram(motion),
      ),
    );

    final result = gate.evaluate(composition);

    expect(result.hasSceneMotion, isTrue);
    expect(result.hasBaselineVisualTrack, isFalse);
    expect(
      result.blockerCodes,
      contains(SceneExportParityIssueCode.sceneOnlyCanvasRendererMissing),
    );
    expect(result.isProductionExportReady, isFalse);
  });

  test('accepts non-text authored visuals when compositor path is supported',
      () {
    final motion = shapeComposition();
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-shape-export-blocked',
        projectFormat: format(),
        assets: baselineAssets(),
        timelineTracks: baselineVideoTrack(),
        motionComposition: motion,
      ),
    );

    final result = gate.evaluate(composition);

    expect(result.hasSceneMotion, isTrue);
    expect(result.hasBaselineVisualTrack, isTrue);
    expect(result.motionTextElementCount, 0);
    expect(result.motionNonTextElementCount, 1);
    expect(result.authoredVisualSurfaceNodeCount, 1);
    expect(
      result.blockerCodes,
      isNot(
        contains(
          SceneExportParityIssueCode.nonTextAuthoredVisualRendererMissing,
        ),
      ),
    );
    expect(result.isProductionExportReady, isTrue);
  });

  test('keeps authored video kinds visible without forcing a renderer blocker',
      () {
    final motion = videoComposition();
    final composition = builder.build(
      ExportCompositionBuildInput(
        contractVersion: 'v1alpha1',
        projectId: 'project-video-export-blocked',
        projectFormat: format(),
        assets: baselineAssets(),
        timelineTracks: baselineVideoTrack(),
        motionComposition: motion,
      ),
    );

    final result = gate.evaluate(composition);

    expect(result.hasSceneMotion, isTrue);
    expect(result.motionNonTextElementCount, 1);
    expect(result.authoredVisualSurfaceNodeCount, 1);
    expect(result.authoredVisualSurfaceKinds, contains('videoClip'));
    expect(
      result.blockerCodes,
      isNot(
        contains(
          SceneExportParityIssueCode.nonTextAuthoredVisualRendererMissing,
        ),
      ),
    );
    expect(result.isProductionExportReady, isTrue);
    expect(
      result.toBridgeMap()['authoredVisualSurfaceKinds'],
      contains('videoClip'),
    );
  });
}
