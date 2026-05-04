import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/composition_scene_clip_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_frame_evaluation_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_render_graph_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_adapter_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_contract_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_render_graph_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/master_renderer_frame_adapters.dart';
import 'package:refusion_app/features/editor/domain/services/master_visual_program_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/master_frame_evaluation_read_adapter.dart';
import 'package:refusion_app/features/editor/presentation/services/universal_master_frame_evaluation_service.dart';
import 'package:refusion_app/features/editor/presentation/services/universal_motion_channel_collector.dart';

class _ChainResult {
  const _ChainResult({
    required this.universal,
    required this.program,
    required this.graph,
    required this.renderer,
  });

  final UniversalMasterFrameEvaluationResult universal;
  final MasterVisualProgram program;
  final MasterRenderGraph graph;
  final MasterRendererFrameResult renderer;
}

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MotionPropertyDefinition visualColorDefinition() => MotionPropertyDefinition(
        id: 'visual.color',
        path: const MotionPropertyPath(
          group: MotionPropertyGroup.visual,
          name: 'color',
        ),
        valueKind: MotionPropertyValueKind.colorArgb,
        supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
        defaultValue: const MotionPropertyValue.colorArgb(0xFFFFFFFF),
      );

  MotionPropertyDefinition maskRevealDefinition() => MotionPropertyDefinition(
        id: 'shape.maskRevealProgress',
        path: const MotionPropertyPath(
          group: MotionPropertyGroup.shape,
          name: 'maskRevealProgress',
        ),
        valueKind: MotionPropertyValueKind.scalar,
        supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
        defaultValue: const MotionPropertyValue.scalar(1.0),
      );

  MotionProjectModel buildProject() {
    final sceneRange = TimelineTimeRange(
      start: TimelineTime.zero,
      endExclusive: ms(10000),
    );
    return MotionProjectModel(
      id: 'project-1',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: 'scene-1',
          projectRange: sceneRange,
          layers: <MotionLayerModel>[
            MotionLayerModel(
              id: 'element-video-a',
              sceneId: 'scene-1',
              kind: MotionLayerKind.video,
              visibleRange: sceneRange,
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'element-video-a',
                  layerId: 'element-video-a',
                  kind: MotionElementKind.videoClip,
                  localRange: sceneRange,
                ),
              ],
            ),
            MotionLayerModel(
              id: 'element-video-b',
              sceneId: 'scene-1',
              kind: MotionLayerKind.video,
              visibleRange: sceneRange,
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'element-video-b',
                  layerId: 'element-video-b',
                  kind: MotionElementKind.videoClip,
                  localRange: sceneRange,
                ),
              ],
            ),
            MotionLayerModel(
              id: 'element-image',
              sceneId: 'scene-1',
              kind: MotionLayerKind.image,
              visibleRange: sceneRange,
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'element-image',
                  layerId: 'element-image',
                  kind: MotionElementKind.image,
                  localRange: sceneRange,
                ),
              ],
            ),
            MotionLayerModel(
              id: 'element-text',
              sceneId: 'scene-1',
              kind: MotionLayerKind.text,
              visibleRange: sceneRange,
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'element-text',
                  layerId: 'element-text',
                  kind: MotionElementKind.text,
                  localRange: sceneRange,
                ),
              ],
            ),
            MotionLayerModel(
              id: 'element-shape',
              sceneId: 'scene-1',
              kind: MotionLayerKind.shape,
              visibleRange: sceneRange,
              elements: <MotionElementModel>[
                MotionElementModel(
                  id: 'element-shape',
                  layerId: 'element-shape',
                  kind: MotionElementKind.shape,
                  localRange: sceneRange,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<CompositionSceneClipModel> buildSceneClips() {
    return <CompositionSceneClipModel>[
      CompositionSceneClipModel(
        id: 'clip-scene-1',
        sourceSceneId: 'scene-1',
        startTime: TimelineTime.zero,
        durationTime: ms(10000),
        sourceInTime: TimelineTime.zero,
        sourceOutTime: ms(10000),
        instanceVisualStyle: CompositionSceneClipInstanceVisualStyle(
          transform: CompositionSceneClipInstanceTransform.identity,
        ),
      ),
    ];
  }

  MotionPropertyTarget target(String id) => MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: id,
        projectId: 'project-1',
        sceneId: 'scene-1',
        layerId: id,
        elementId: id,
      );

  MotionPropertyChannelModel channel({
    required String id,
    required String targetId,
    required MotionPropertyDefinition definition,
    required MotionPropertyValue start,
    required MotionPropertyValue end,
  }) {
    return MotionPropertyChannelModel(
      id: id,
      target: target(targetId),
      definition: definition,
      keyframes: <MotionKeyframeModel>[
        MotionKeyframeModel(
          id: '$id.k0',
          channelId: id,
          time: TimelineTime.zero,
          value: start,
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
        MotionKeyframeModel(
          id: '$id.k1',
          channelId: id,
          time: ms(5000),
          value: end,
          interpolationToNext: const MotionInterpolationSpec.linear(),
        ),
      ],
    );
  }

  Map<String, MasterVisualSourceBinding> buildSources() =>
      const <String, MasterVisualSourceBinding>{
        'element-video-a': MasterVisualSourceBinding(
          targetId: 'element-video-a',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/a.mp4',
          scrubStoreKey: 'clip-a',
        ),
        'element-video-b': MasterVisualSourceBinding(
          targetId: 'element-video-b',
          kind: MasterVisualSourceKind.video,
          sourceUri: '/media/b.mp4',
          scrubStoreKey: 'clip-b',
        ),
        'element-image': MasterVisualSourceBinding(
          targetId: 'element-image',
          kind: MasterVisualSourceKind.image,
          sourceUri: '/media/image.png',
          scrubStoreKey: 'img-1',
        ),
        'element-text': MasterVisualSourceBinding(
          targetId: 'element-text',
          kind: MasterVisualSourceKind.image,
          sourceUri: '/media/text.png',
          scrubStoreKey: 'txt-1',
        ),
        'element-shape': MasterVisualSourceBinding(
          targetId: 'element-shape',
          kind: MasterVisualSourceKind.image,
          sourceUri: '/media/shape.png',
          scrubStoreKey: 'shape-1',
        ),
      };

  MasterRendererAdapterMode adapterMode(MasterRenderMode mode) {
    return switch (mode) {
      MasterRenderMode.preview => MasterRendererAdapterMode.preview,
      MasterRenderMode.playback => MasterRendererAdapterMode.playback,
      MasterRenderMode.liveScrub ||
      MasterRenderMode.settle ||
      MasterRenderMode.test =>
        MasterRendererAdapterMode.liveScrub,
      MasterRenderMode.export => MasterRendererAdapterMode.export,
    };
  }

  _ChainResult runProductionPath({
    required MasterRenderMode mode,
    required int rootTimeMs,
    required List<MotionPropertyChannelModel> channels,
  }) {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(10000),
      initialTime: ms(rootTimeMs),
    );
    final universalService = UniversalMasterFrameEvaluationService(
      readAdapter: MasterFrameEvaluationReadAdapter(),
      channelCollector: const UniversalMotionChannelCollector(),
    );
    final universal = universalService.evaluate(
      UniversalMasterFrameEvaluationRequest(
        clock: clock.snapshot,
        frameRate: 30,
        project: buildProject(),
        sceneClips: buildSceneClips(),
        channelSources: <UniversalMotionChannelCollectionSource>[
          UniversalMotionChannelCollectionSource(
            id: 'authored',
            channels: channels,
          ),
        ],
        renderMode: mode,
      ),
    );
    clock.dispose();

    const visualAdapter = MasterVisualProgramAdapter();
    const graphAdapter = MasterRenderGraphAdapter();
    const frameAdapters = MasterRendererFrameAdapters();

    final program = visualAdapter.build(
      frame: universal.frame,
      sourcesByTargetId: buildSources(),
      channels: universal.channels,
    );
    final graph = graphAdapter.build(program: program);
    final activeSources = <String>[
      for (final surface in program.surfaces)
        if (surface.source != null) surface.targetId,
    ];
    final requestId =
        'phase7-production:${mode.name}:${program.time.commitFrameNumber}:${program.time.frameIndex}';
    final sourceRevision = 'phase7-production:${Object.hashAll(activeSources)}';

    final renderer = switch (mode) {
      MasterRenderMode.preview => frameAdapters.projectPreview(
          program: program,
          renderGraph: graph,
          requestId: requestId,
          sourceRevision: sourceRevision,
          surfaceId: MasterRendererContracts.runtimeBridgeSurfaceIdForMode(
            adapterMode(mode),
          ),
          nativePresentationAck: true,
          presentedRootTimeMs: program.time.rootTime.inMilliseconds,
          presentedFrameIndex: program.time.frameIndex,
          presentedCommitFrameNumber: program.time.commitFrameNumber,
          presentedSourceIds: activeSources,
        ),
      MasterRenderMode.liveScrub ||
      MasterRenderMode.settle ||
      MasterRenderMode.test =>
        frameAdapters.projectLiveScrub(
          program: program,
          renderGraph: graph,
          requestId: requestId,
          sourceRevision: sourceRevision,
          surfaceId: MasterRendererContracts.runtimeBridgeSurfaceIdForMode(
            adapterMode(mode),
          ),
          nativePresentationAck: true,
          presentedRootTimeMs: program.time.rootTime.inMilliseconds,
          presentedFrameIndex: program.time.frameIndex,
          presentedCommitFrameNumber: program.time.commitFrameNumber,
          presentedSourceIds: activeSources,
        ),
      MasterRenderMode.playback => frameAdapters.projectPlayback(
          program: program,
          renderGraph: graph,
          requestId: requestId,
          sourceRevision: sourceRevision,
          surfaceId: MasterRendererContracts.runtimeBridgeSurfaceIdForMode(
            adapterMode(mode),
          ),
          nativePresentationAck: true,
          presentedRootTimeMs: program.time.rootTime.inMilliseconds,
          presentedFrameIndex: program.time.frameIndex,
          presentedCommitFrameNumber: program.time.commitFrameNumber,
          presentedSourceIds: activeSources,
        ),
      MasterRenderMode.export => frameAdapters.projectExport(
          program: program,
          renderGraph: graph,
          requestId: requestId,
          sourceRevision: sourceRevision,
          surfaceId: MasterRendererContracts.runtimeBridgeSurfaceIdForMode(
            adapterMode(mode),
          ),
          nativePresentationAck: true,
          presentedRootTimeMs: program.time.rootTime.inMilliseconds,
          presentedFrameIndex: program.time.frameIndex,
          presentedCommitFrameNumber: program.time.commitFrameNumber,
          presentedSourceIds: activeSources,
        ),
    };

    return _ChainResult(
      universal: universal,
      program: program,
      graph: graph,
      renderer: renderer,
    );
  }

  void expectUniversalParity(_ChainResult chain, MasterRenderMode mode) {
    final frame = chain.universal.frame;
    final graph = chain.graph;
    final proof = chain.renderer.proof;

    expect(chain.universal.blockers, isEmpty);
    expect(chain.program.blockers, isEmpty);
    expect(graph.blockers, isEmpty);
    expect(chain.renderer.blockers, isEmpty);
    expect(frame.evaluatedChannels, isNotEmpty);
    expect(frame.projections, isNotEmpty);
    expect(frame.time.rootTime.inMilliseconds, proof.requestedRootTimeMs);
    expect(frame.time.frameIndex, proof.requestedFrameIndex);
    expect(frame.time.commitFrameNumber, proof.requestedCommitFrameNumber);
    expect(graph.rootTimeMs, frame.time.rootTime.inMilliseconds);
    expect(graph.frameIndex, frame.time.frameIndex);
    expect(proof.matchState, RendererPresentationMatchState.matched);
    expect(proof.rendererMode, adapterMode(mode).name);
    expect(
      proof.surfaceId,
      MasterRendererContracts.runtimeBridgeSurfaceIdForMode(adapterMode(mode)),
    );
  }

  test('phase7 production path: video scale and rotation use universal service',
      () {
    final result = runProductionPath(
      mode: MasterRenderMode.preview,
      rootTimeMs: 2200,
      channels: <MotionPropertyChannelModel>[
        channel(
          id: 'ch.scale.a',
          targetId: 'element-video-a',
          definition: MotionPropertyCatalog.scaleX,
          start: const MotionPropertyValue.scalar(1.0),
          end: const MotionPropertyValue.scalar(1.6),
        ),
        channel(
          id: 'ch.rotate.b',
          targetId: 'element-video-b',
          definition: MotionPropertyCatalog.rotationDegrees,
          start: const MotionPropertyValue.scalar(0),
          end: const MotionPropertyValue.scalar(90),
        ),
      ],
    );

    expectUniversalParity(result, MasterRenderMode.preview);
    final surfaceA = result.program.surfaces.firstWhere(
      (surface) => surface.targetId == 'element-video-a',
    );
    final surfaceB = result.program.surfaces.firstWhere(
      (surface) => surface.targetId == 'element-video-b',
    );
    expect(surfaceA.transform.scaleX, greaterThan(1.0));
    expect(surfaceB.transform.rotationRadians, greaterThan(0.0));
  });

  test(
      'phase7 production path: text shape crop mask and effects survive full chain',
      () {
    final result = runProductionPath(
      mode: MasterRenderMode.liveScrub,
      rootTimeMs: 2800,
      channels: <MotionPropertyChannelModel>[
        channel(
          id: 'ch.text.size',
          targetId: 'element-text',
          definition: MotionPropertyCatalog.fontSize,
          start: const MotionPropertyValue.scalar(24),
          end: const MotionPropertyValue.scalar(48),
        ),
        channel(
          id: 'ch.shape.width',
          targetId: 'element-shape',
          definition: MotionPropertyCatalog.width,
          start: const MotionPropertyValue.scalar(100),
          end: const MotionPropertyValue.scalar(400),
        ),
        channel(
          id: 'ch.shape.mask',
          targetId: 'element-shape',
          definition: maskRevealDefinition(),
          start: const MotionPropertyValue.scalar(0.1),
          end: const MotionPropertyValue.scalar(0.8),
        ),
        channel(
          id: 'ch.image.crop',
          targetId: 'element-image',
          definition: MotionPropertyCatalog.cropRect,
          start: const MotionPropertyValue.rect(
            MotionRect(left: 0.0, top: 0.0, width: 1.0, height: 1.0),
          ),
          end: const MotionPropertyValue.rect(
            MotionRect(left: 0.2, top: 0.1, width: 0.6, height: 0.7),
          ),
        ),
        channel(
          id: 'ch.video.color',
          targetId: 'element-video-a',
          definition: visualColorDefinition(),
          start: const MotionPropertyValue.colorArgb(0xFFFFFFFF),
          end: const MotionPropertyValue.colorArgb(0xFF8844FF),
        ),
        channel(
          id: 'ch.video.blur',
          targetId: 'element-video-a',
          definition: MotionPropertyCatalog.blurAmount,
          start: const MotionPropertyValue.scalar(0),
          end: const MotionPropertyValue.scalar(14),
        ),
      ],
    );

    expectUniversalParity(result, MasterRenderMode.liveScrub);
    final textSurface = result.program.surfaces.firstWhere(
      (surface) => surface.targetId == 'element-text',
    );
    final shapeSurface = result.program.surfaces.firstWhere(
      (surface) => surface.targetId == 'element-shape',
    );
    final imageSurface = result.program.surfaces.firstWhere(
      (surface) => surface.targetId == 'element-image',
    );
    final videoSurface = result.program.surfaces.firstWhere(
      (surface) => surface.targetId == 'element-video-a',
    );
    expect(textSurface.textStyle.hasTextStyle, isTrue);
    expect(shapeSurface.shapeStyle.hasShapeStyle, isTrue);
    expect(shapeSurface.mask.hasMask, isTrue);
    expect(imageSurface.crop.hasCrop, isTrue);
    expect(videoSurface.colors.hasColorStyle, isTrue);
    expect(videoSurface.effects.any((effect) => effect.id == 'gaussianBlur'),
        isTrue);
  });

  test('phase7 production path: playback and export follow renderer contracts',
      () {
    final playback = runProductionPath(
      mode: MasterRenderMode.playback,
      rootTimeMs: 3100,
      channels: <MotionPropertyChannelModel>[
        channel(
          id: 'ch.play.opacity',
          targetId: 'element-video-a',
          definition: MotionPropertyCatalog.opacity,
          start: const MotionPropertyValue.scalar(100),
          end: const MotionPropertyValue.scalar(65),
        ),
      ],
    );
    final export = runProductionPath(
      mode: MasterRenderMode.export,
      rootTimeMs: 3100,
      channels: <MotionPropertyChannelModel>[
        channel(
          id: 'ch.export.opacity',
          targetId: 'element-video-a',
          definition: MotionPropertyCatalog.opacity,
          start: const MotionPropertyValue.scalar(100),
          end: const MotionPropertyValue.scalar(65),
        ),
      ],
    );

    expectUniversalParity(playback, MasterRenderMode.playback);
    expectUniversalParity(export, MasterRenderMode.export);
    expect(playback.renderer.proof.requestedRootTimeMs,
        export.renderer.proof.requestedRootTimeMs);
    expect(playback.renderer.proof.requestedFrameIndex,
        export.renderer.proof.requestedFrameIndex);
  });
}
