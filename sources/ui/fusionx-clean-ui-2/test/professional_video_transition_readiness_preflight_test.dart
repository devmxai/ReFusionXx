import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/professional_video_transition_compositor.dart';
import 'package:refusion_app/features/editor/domain/services/professional_video_transition_readiness_preflight.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  test(
      'preflight reports the blocked compositor stages without enabling output',
      () async {
    final report = await const ProfessionalVideoTransitionReadinessPreflight(
      client: _FakeProfessionalVideoTransitionCompositorClient.ready(
        rendererReady: false,
      ),
    ).run(
      plan: _renderPlan(),
      timelineTime: TimelineTime.fromMilliseconds(10000),
    );

    expect(report.canExposeTransition, isFalse);
    expect(report.firstBlockingStage?.id,
        ProfessionalVideoTransitionReadinessStageId.capabilityGate);
    expect(
      report.stages.map((stage) => stage.id),
      <ProfessionalVideoTransitionReadinessStageId>[
        ProfessionalVideoTransitionReadinessStageId.capabilityGate,
        ProfessionalVideoTransitionReadinessStageId.renderSession,
        ProfessionalVideoTransitionReadinessStageId.sourceBinding,
        ProfessionalVideoTransitionReadinessStageId.sourceMediaProbe,
        ProfessionalVideoTransitionReadinessStageId.frameSamples,
        ProfessionalVideoTransitionReadinessStageId.frameDecode,
        ProfessionalVideoTransitionReadinessStageId.dualVideoDecoder,
        ProfessionalVideoTransitionReadinessStageId.temporalAccumulator,
        ProfessionalVideoTransitionReadinessStageId.mirrorEdgeTiling,
        ProfessionalVideoTransitionReadinessStageId.renderPassGraph,
        ProfessionalVideoTransitionReadinessStageId.renderGraphExecution,
        ProfessionalVideoTransitionReadinessStageId.outputSurface,
        ProfessionalVideoTransitionReadinessStageId.surfaceRenderer,
        ProfessionalVideoTransitionReadinessStageId.frameRenderCommands,
        ProfessionalVideoTransitionReadinessStageId.rendererBackend,
        ProfessionalVideoTransitionReadinessStageId.rendererDrawLoop,
        ProfessionalVideoTransitionReadinessStageId.transitionShaderEvaluation,
        ProfessionalVideoTransitionReadinessStageId.transitionPixelRenderer,
        ProfessionalVideoTransitionReadinessStageId.transitionPixelFrameBuffer,
        ProfessionalVideoTransitionReadinessStageId
            .transitionPixelFrameBufferWriter,
        ProfessionalVideoTransitionReadinessStageId
            .transitionPixelRenderExecution,
        ProfessionalVideoTransitionReadinessStageId.transitionPixelOutputProof,
        ProfessionalVideoTransitionReadinessStageId.transitionSurfaceEndpoint,
        ProfessionalVideoTransitionReadinessStageId.parityOutputs,
      ],
    );

    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.sourceBinding)
          .canAdvance,
      isTrue,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.sourceMediaProbe)
          .canAdvance,
      isFalse,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.sourceMediaProbe)
          .blockers,
      contains('native_video_source_probe_not_implemented'),
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.frameDecode)
          .canAdvance,
      isTrue,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.dualVideoDecoder)
          .blockers,
      contains('native_dual_video_decoder_not_implemented'),
    );
    expect(
      report
          .stage(
              ProfessionalVideoTransitionReadinessStageId.temporalAccumulator)
          .blockers,
      contains('native_temporal_accumulator_not_implemented'),
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.outputSurface)
          .canAdvance,
      isFalse,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.surfaceRenderer)
          .blockers,
      contains('native_transition_surface_renderer_pixels_missing'),
    );
    expect(
      report
          .stage(
              ProfessionalVideoTransitionReadinessStageId.frameRenderCommands)
          .blockers,
      contains('native_transition_frame_command_renderer_missing'),
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.rendererBackend)
          .canAdvance,
      isTrue,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId.rendererDrawLoop)
          .canAdvance,
      isTrue,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionShaderEvaluation)
          .canAdvance,
      isTrue,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionShaderEvaluation)
          .blockers,
      isEmpty,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelRenderer)
          .canAdvance,
      isTrue,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelRenderer)
          .blockers,
      isEmpty,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelFrameBuffer)
          .canAdvance,
      isFalse,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelFrameBuffer)
          .blockers,
      contains('native_transition_pixel_frame_buffer_missing'),
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelFrameBufferWriter)
          .canAdvance,
      isFalse,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelFrameBufferWriter)
          .blockers,
      contains('native_transition_pixel_frame_buffer_writer_missing'),
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelRenderExecution)
          .canAdvance,
      isFalse,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelRenderExecution)
          .blockers,
      contains('native_transition_pixel_renderer_missing'),
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelRenderExecution)
          .blockers,
      contains('native_transition_renderer_pixels_missing'),
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelOutputProof)
          .canAdvance,
      isFalse,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionPixelOutputProof)
          .blockers,
      contains('native_transition_pixel_output_proof_missing'),
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionSurfaceEndpoint)
          .canAdvance,
      isFalse,
    );
    expect(
      report
          .stage(ProfessionalVideoTransitionReadinessStageId
              .transitionSurfaceEndpoint)
          .blockers,
      contains('native_transition_surface_endpoint_missing'),
    );
  });

  test('preflight allows exposure only when every stage can advance', () async {
    final report = await const ProfessionalVideoTransitionReadinessPreflight(
      client: _FakeProfessionalVideoTransitionCompositorClient.ready(
        rendererReady: true,
      ),
    ).run(
      plan: _renderPlan(),
      timelineTime: TimelineTime.fromMilliseconds(10000),
    );

    expect(report.canExposeTransition, isTrue);
    expect(report.blockingStages, isEmpty);
    expect(
      report.stages.every((stage) => stage.canPlan && stage.canAdvance),
      isTrue,
    );
  });
}

extension on ProfessionalVideoTransitionReadinessReport {
  ProfessionalVideoTransitionReadinessStage stage(
    ProfessionalVideoTransitionReadinessStageId id,
  ) {
    return stages.singleWhere((stage) => stage.id == id);
  }
}

ProfessionalVideoTransitionRenderPlan _renderPlan() {
  return ProfessionalVideoTransitionRenderPlan(
    definitionId: ProfessionalVideoTransitionCompositorKind.zoomInCamera.name,
    transitionId: 'transition-a-b',
    canvasWidth: 1080,
    canvasHeight: 1920,
    boundaryTime: TimelineTime.fromMilliseconds(10000),
    leadingDuration: TimelineTime.fromMilliseconds(2000),
    trailingDuration: TimelineTime.fromMilliseconds(2000),
    sources: <ProfessionalVideoTransitionCompositorSource>[
      ProfessionalVideoTransitionCompositorSource(
        clipId: 'clip-a',
        assetId: 'asset-a',
        sourceUri: 'file:///asset-a.mp4',
        timelineRange: TimelineTimeRange(
          start: TimelineTime.fromMilliseconds(8000),
          endExclusive: TimelineTime.fromMilliseconds(10000),
        ),
        sourceStartTime: TimelineTime.fromMilliseconds(20000),
        sourceDuration: TimelineTime.fromMilliseconds(2000),
      ),
      ProfessionalVideoTransitionCompositorSource(
        clipId: 'clip-b',
        assetId: 'asset-b',
        sourceUri: 'file:///asset-b.mp4',
        timelineRange: TimelineTimeRange(
          start: TimelineTime.fromMilliseconds(10000),
          endExclusive: TimelineTime.fromMilliseconds(12000),
        ),
        sourceStartTime: TimelineTime.fromMilliseconds(30000),
        sourceDuration: TimelineTime.fromMilliseconds(2000),
      ),
    ],
    requiredCapabilities: const <String>[
      'dualVideoSampling',
      'temporalMotionBlur',
      'mirrorEdgeTiling',
      'previewParity',
      'liveScrubParity',
      'playbackParity',
    ],
    samplingPolicy: const <String, Object?>{
      'sourceCount': 2,
      'sourceRoles': <String>['outgoing', 'incoming'],
    },
    edgePolicy: const <String, Object?>{
      'mode': 'mirrorTile',
      'outputScaleX': 4.0,
      'outputScaleY': 3.5,
    },
    motionBlurPolicy: const <String, Object?>{
      'mode': 'temporalShutter',
      'sampleCount': 8,
      'shutterAngleDegrees': 360.0,
      'frameRate': 30.0,
    },
  );
}

class _FakeProfessionalVideoTransitionCompositorClient
    extends ProfessionalVideoTransitionCompositorClient {
  const _FakeProfessionalVideoTransitionCompositorClient.ready({
    required bool rendererReady,
  }) : _rendererReady = rendererReady;

  final bool _rendererReady;

  bool get _planningOnly => !_rendererReady;

  @override
  Future<ProfessionalVideoTransitionCompositorCapabilities>
      loadCapabilities() async {
    if (_rendererReady) {
      return const ProfessionalVideoTransitionCompositorCapabilities(
        dualVideoSampling: true,
        temporalMotionBlur: true,
        mirrorEdgeTiling: true,
        previewParity: true,
        liveScrubParity: true,
        playbackParity: true,
        exportParity: false,
      );
    }
    return ProfessionalVideoTransitionCompositorCapabilities.unavailable;
  }

  @override
  Future<ProfessionalVideoTransitionCompositorPrepareResult> prepareRenderPlan(
    ProfessionalVideoTransitionRenderPlan plan,
  ) async {
    return ProfessionalVideoTransitionCompositorPrepareResult(
      status: _rendererReady
          ? ProfessionalVideoTransitionCompositorPrepareStatus.ready
          : ProfessionalVideoTransitionCompositorPrepareStatus.unsupported,
      reason:
          _rendererReady ? '' : 'native_transition_renderer_not_implemented',
      rendererVersion: 'fake',
      missingCapabilities: _rendererReady
          ? const <String>[]
          : const <String>['rendererImplemented'],
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      sourceRoles: const <String>['outgoing', 'incoming'],
    );
  }

  @override
  Future<ProfessionalVideoTransitionSourceBindingPlanResult>
      planVideoSourceBindings({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionSourceBindingPlanResult(
      status: ProfessionalVideoTransitionSourceBindingPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      requiresConcreteSourceUri: true,
      allSourcesBound: true,
      allowAssetIdOnlyDecode: false,
      allowGeneratedProxyDecode: false,
      bindings: plan.sources.map(_sourceBinding).toList(growable: false),
      blockedReasons: const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionSourceProbePlanResult>
      planVideoSourceProbe({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionSourceProbePlanResult(
      status: ProfessionalVideoTransitionSourceProbePlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      requiresRealVideoSource: true,
      probeImplemented: _rendererReady,
      allSourcesProbeable: _rendererReady,
      allowSyntheticSource: false,
      probes: <ProfessionalVideoTransitionSourceProbe>[
        _sourceProbe(plan.sources[0], 'outgoing'),
        _sourceProbe(plan.sources[1], 'incoming'),
      ],
      blockedReasons: _planningOnly
          ? const <String>['native_video_source_probe_not_implemented']
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionFrameSamplePlanResult> planFrameSamples({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionFrameSamplePlanResult(
      status: ProfessionalVideoTransitionFrameSamplePlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      progress: 0.5,
      sourceRoles: const <String>['outgoing', 'incoming'],
      outgoingSourceTime: TimelineTime.fromMilliseconds(22000),
      incomingSourceTime: TimelineTime.fromMilliseconds(30000),
      temporalSampleTimelineTimes: <TimelineTime>[
        timelineTime,
      ],
      outgoingTemporalSourceTimes: <TimelineTime>[
        TimelineTime.fromMilliseconds(22000),
      ],
      incomingTemporalSourceTimes: <TimelineTime>[
        TimelineTime.fromMilliseconds(30000),
      ],
      motionBlurMode: 'temporalShutter',
      shutterAngleDegrees: 360,
      frameRate: 30,
      shutterSampleCount: 1,
    );
  }

  @override
  Future<ProfessionalVideoTransitionFrameDecodePlanResult>
      planFrameDecodeRequests({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionFrameDecodePlanResult(
      status: ProfessionalVideoTransitionFrameDecodePlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      progress: 0.5,
      decodeMode: 'exactVideoFrame',
      allowThumbnailFallback: false,
      allowBoundaryFreeze: false,
      requiresRealVideoFrame: true,
      decodeRequests: <ProfessionalVideoTransitionFrameDecodeRequest>[
        _decodeRequest(plan.sources[0], 'outgoing', 0),
        _decodeRequest(plan.sources[1], 'incoming', 1),
      ],
    );
  }

  @override
  Future<ProfessionalVideoTransitionDecoderSessionPlanResult>
      planDualVideoDecoderSession({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionDecoderSessionPlanResult(
      status: ProfessionalVideoTransitionDecoderSessionPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      decoderSessionId: 'decoder:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      requiresDualVideoDecoder: true,
      requiresExactFrameDecode: true,
      requiresContinuousFrameStream: true,
      allowThumbnailFallback: false,
      allowBoundaryFreeze: false,
      decoderImplemented: _rendererReady,
      tracks: <ProfessionalVideoTransitionDecoderTrack>[
        _decoderTrack(plan.sources[0], 'outgoing'),
        _decoderTrack(plan.sources[1], 'incoming'),
      ],
      blockedReasons: _planningOnly
          ? const <String>['native_dual_video_decoder_not_implemented']
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionTemporalAccumulatorPlanResult>
      planTemporalSampleAccumulator({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionTemporalAccumulatorPlanResult(
      status: ProfessionalVideoTransitionTemporalAccumulatorPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      decoderSessionId: 'decoder:${plan.transitionId}',
      temporalAccumulatorSessionId: 'accumulator:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      motionBlurMode: 'temporalShutter',
      shutterSampleCount: 1,
      requiresTemporalAccumulation: true,
      requiresExactFrameDecode: true,
      allowGaussianFallback: false,
      allowDecorativeSpeedLines: false,
      accumulatorImplemented: _rendererReady,
      accumulators: const <ProfessionalVideoTransitionTemporalAccumulator>[
        ProfessionalVideoTransitionTemporalAccumulator(
          accumulatorId: 'accumulator:outgoing',
          role: 'outgoing',
          inputTrackRole: 'outgoing',
          sampleCount: 1,
          sampleWeights: <double>[1],
          normalization: 'sum',
          requiresTemporalShutter: true,
          requiresExactFrameDecode: true,
          allowGaussianFallback: false,
          allowDecorativeSpeedLines: false,
        ),
        ProfessionalVideoTransitionTemporalAccumulator(
          accumulatorId: 'accumulator:incoming',
          role: 'incoming',
          inputTrackRole: 'incoming',
          sampleCount: 1,
          sampleWeights: <double>[1],
          normalization: 'sum',
          requiresTemporalShutter: true,
          requiresExactFrameDecode: true,
          allowGaussianFallback: false,
          allowDecorativeSpeedLines: false,
        ),
      ],
      blockedReasons: _planningOnly
          ? const <String>['native_temporal_accumulator_not_implemented']
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionMirrorEdgeTilingPlanResult>
      planMirrorEdgeTiling({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionMirrorEdgeTilingPlanResult(
      status: ProfessionalVideoTransitionMirrorEdgeTilingPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      temporalAccumulatorSessionId: 'accumulator:${plan.transitionId}',
      mirrorEdgeTilingSessionId: 'tiler:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      edgeMode: 'mirrorTile',
      outputScaleX: 4,
      outputScaleY: 3.5,
      requiresMirrorEdgeTiling: true,
      requiresTemporalAccumulator: true,
      allowBlackBorders: false,
      allowFlutterOverlay: false,
      allowTimelineOverlay: false,
      tilerImplemented: _rendererReady,
      tiles: const <ProfessionalVideoTransitionMirrorEdgeTile>[
        ProfessionalVideoTransitionMirrorEdgeTile(
          tileId: 'tile:outgoing',
          role: 'outgoing',
          inputAccumulatorId: 'accumulator:outgoing',
          edgeMode: 'mirrorTile',
          outputScaleX: 4,
          outputScaleY: 3.5,
          mirrorEdges: true,
          clipToCanvas: true,
          allowBlackBorders: false,
        ),
        ProfessionalVideoTransitionMirrorEdgeTile(
          tileId: 'tile:incoming',
          role: 'incoming',
          inputAccumulatorId: 'accumulator:incoming',
          edgeMode: 'mirrorTile',
          outputScaleX: 4,
          outputScaleY: 3.5,
          mirrorEdges: true,
          clipToCanvas: true,
          allowBlackBorders: false,
        ),
      ],
      blockedReasons: _planningOnly
          ? const <String>['native_mirror_edge_tiler_not_implemented']
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionRenderPassGraphPlanResult>
      planRenderPassGraph({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionRenderPassGraphPlanResult(
      status: ProfessionalVideoTransitionRenderPassGraphPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      progress: 0.5,
      requiresExactVideoDecode: true,
      requiresTemporalAccumulation: true,
      requiresMirrorEdgeTiling: true,
      requiresGpuComposition: true,
      rendererInputsReady: _rendererReady,
      rendererImplemented: _rendererReady,
      passes: const <ProfessionalVideoTransitionRenderPassNode>[
        ProfessionalVideoTransitionRenderPassNode(
          passId: 'pass:compose',
          type: 'transitionShader',
          role: 'compositor',
          inputs: <String>['tile:outgoing', 'tile:incoming'],
          parameters: <String, Object?>{},
        ),
      ],
      blockedReasons: _planningOnly
          ? const <String>['native_transition_renderer_missing']
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionOutputSurfacePlanResult> planOutputSurface({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionOutputSurfacePlanResult(
      status: ProfessionalVideoTransitionOutputSurfacePlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      clipToCanvas: true,
      requiresNativeTexture: true,
      allowFlutterOverlay: false,
      allowTimelineOverlay: false,
      allowPlatformViewTransform: false,
      renderPassCount: 2,
      outputPassId: 'pass:output:${plan.transitionId}',
      outputPassType: 'composeToTransitionSurface',
      outputPassInputs: const <String>['pass:transition'],
      outputPassBound: true,
      renderGraphOutputReady: !_planningOnly,
      rendererImplemented: _rendererReady,
      blockedReasons: _planningOnly
          ? const <String>['native_transition_renderer_not_implemented']
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionRenderGraphExecutionPlanResult>
      planRenderGraphExecution({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionRenderGraphExecutionPlanResult(
      status: ProfessionalVideoTransitionRenderGraphExecutionPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      renderGraphExecutorId: 'executor:${plan.transitionId}',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      requiredPassTypes: const <String>[
        'decodeLiveVideoStreams',
        'decodeExactVideoFrames',
        'temporalSampleAccumulator',
        'temporalSampleAccumulator',
        'mirrorEdgeTile',
        'transitionShaderEvaluation',
        'composeToTransitionSurface',
      ],
      executionOrder: const <String>[
        'pass:live',
        'pass:decode',
        'pass:temporal:out',
        'pass:temporal:in',
        'pass:edge',
        'pass:transition',
        'pass:output',
      ],
      passExecutionStates: const <ProfessionalVideoTransitionRenderGraphPassExecutionState>[
        ProfessionalVideoTransitionRenderGraphPassExecutionState(
          passId: 'pass:output',
          type: 'composeToTransitionSurface',
          role: 'output',
          index: 6,
          inputs: <String>['pass:transition'],
          readyForExecutor: true,
          blockedReasons: <String>[],
        ),
      ],
      graphExecutorImplemented: true,
      rendererImplemented: _rendererReady,
      graphOrderValid: true,
      graphDependenciesValid: true,
      graphOwnershipReady: true,
      canExecuteGraph: _rendererReady,
      drawsPixels: false,
      blockedReasons: _planningOnly
          ? const <String>[
              'native_transition_render_graph_executor_renderer_missing',
            ]
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionSurfaceRendererPlanResult>
      planSurfaceRenderer({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionSurfaceRendererPlanResult(
      status: ProfessionalVideoTransitionSurfaceRendererPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      renderGraphExecutorId: 'executor:${plan.transitionId}',
      surfaceRendererId: 'surface-renderer:${plan.transitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionSurface',
      outputPassId: 'pass:output:${plan.transitionId}',
      outputPassType: 'composeToTransitionSurface',
      outputPassInputs: const <String>['pass:transition'],
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      clipToCanvas: true,
      requiresNativeTexture: true,
      graphExecutorImplemented: true,
      graphOwnershipReady: true,
      surfaceRendererImplemented: true,
      rendererImplemented: _rendererReady,
      outputSurfaceAttached: true,
      outputPassBound: true,
      renderGraphOutputReady: !_planningOnly,
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canRenderSurface: _rendererReady,
      blockedReasons: _planningOnly
          ? const <String>[
              'native_transition_surface_renderer_pixels_missing',
            ]
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionFrameRenderCommandPlanResult>
      planFrameRenderCommands({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionFrameRenderCommandPlanResult(
      status: ProfessionalVideoTransitionFrameRenderCommandPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      renderGraphExecutorId: 'executor:${plan.transitionId}',
      surfaceRendererId: 'surface-renderer:${plan.transitionId}',
      frameRenderCommandBufferId: 'frame-command-buffer:${plan.transitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      surfaceRendererImplemented: true,
      rendererCommandBufferImplemented: true,
      rendererImplemented: _rendererReady,
      graphOwnershipReady: true,
      outputSurfaceAttached: true,
      outputPassBound: true,
      renderGraphOutputReady: !_planningOnly,
      commandGraphComplete: true,
      commandBufferReady: true,
      commandCount: 1,
      commands: <ProfessionalVideoTransitionFrameRenderCommand>[
        ProfessionalVideoTransitionFrameRenderCommand(
          commandId: 'command:output:${plan.transitionId}',
          passId: 'pass:output:${plan.transitionId}',
          passType: 'composeToTransitionSurface',
          role: 'output',
          index: 0,
          inputPassIds: const <String>['pass:transition'],
          outputTarget: 'nativeTransitionSurface',
          writesToOutputSurface: true,
          requiresRealPixels: true,
          readyForRenderer: true,
          blockedReasons: _planningOnly
              ? const <String>[
                  'native_transition_frame_command_renderer_missing'
                ]
              : const <String>[],
        ),
      ],
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canSubmitCommands: _rendererReady,
      canRenderFrame: _rendererReady,
      blockedReasons: _planningOnly
          ? const <String>['native_transition_frame_command_renderer_missing']
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionRendererBackendPlanResult>
      planRendererBackend({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionRendererBackendPlanResult(
      status: ProfessionalVideoTransitionRendererBackendPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      renderGraphExecutorId: 'executor:${plan.transitionId}',
      surfaceRendererId: 'surface-renderer:${plan.transitionId}',
      frameRenderCommandBufferId: 'frame-command-buffer:${plan.transitionId}',
      rendererBackendId: 'renderer-backend:${plan.transitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionCanvasSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      rendererBackendImplemented: true,
      gpuContextAvailable: true,
      nativeSurfaceRequired: true,
      commandBufferReady: true,
      outputSurfaceAttached: true,
      backendReady: true,
      drawLoopImplemented: _rendererReady,
      rendererImplemented: _rendererReady,
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canSubmitCommands: _rendererReady,
      canRenderFrame: _rendererReady,
      blockedReasons: const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionRendererDrawLoopPlanResult>
      planRendererDrawLoop({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionRendererDrawLoopPlanResult(
      status: ProfessionalVideoTransitionRendererDrawLoopPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      renderGraphExecutorId: 'executor:${plan.transitionId}',
      surfaceRendererId: 'surface-renderer:${plan.transitionId}',
      frameRenderCommandBufferId: 'frame-command-buffer:${plan.transitionId}',
      rendererBackendId: 'renderer-backend:${plan.transitionId}',
      rendererDrawLoopId: 'draw-loop:${plan.transitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionCanvasSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      rendererBackendImplemented: true,
      gpuContextAvailable: true,
      nativeSurfaceRequired: true,
      commandBufferReady: true,
      outputSurfaceAttached: true,
      backendReady: true,
      drawLoopImplemented: true,
      rendererImplemented: _rendererReady,
      drawSubmissionCount: 1,
      drawSubmissions: <ProfessionalVideoTransitionDrawSubmission>[
        ProfessionalVideoTransitionDrawSubmission(
          submissionId: 'draw-submission:${plan.transitionId}:0',
          commandId: 'command:output:${plan.transitionId}',
          passId: 'pass:output:${plan.transitionId}',
          passType: 'composeToTransitionSurface',
          index: 0,
          outputTarget: 'nativeTransitionCanvasSurface',
          writesToOutputSurface: true,
          requiresRealPixels: true,
          submitted: true,
          blockedReasons: const <String>[],
        ),
      ],
      shaderEvaluatorImplemented: false,
      pixelRendererImplemented: false,
      drawLoopReady: true,
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canSubmitCommands: true,
      canRenderFrame: _rendererReady,
      blockedReasons: const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionShaderEvaluationPlanResult>
      planTransitionShaderEvaluation({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionShaderEvaluationPlanResult(
      status: ProfessionalVideoTransitionShaderEvaluationPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      renderGraphExecutorId: 'executor:${plan.transitionId}',
      surfaceRendererId: 'surface-renderer:${plan.transitionId}',
      frameRenderCommandBufferId: 'frame-command-buffer:${plan.transitionId}',
      rendererBackendId: 'renderer-backend:${plan.transitionId}',
      rendererDrawLoopId: 'draw-loop:${plan.transitionId}',
      transitionShaderEvaluationId: 'shader-evaluation:${plan.transitionId}',
      transitionShaderProgramId: 'shader-program:${plan.definitionId}',
      shaderFamily: plan.definitionId,
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionCanvasSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      drawLoopImplemented: true,
      drawLoopReady: true,
      shaderEvaluatorImplemented: true,
      shaderProgramReady: true,
      shaderInputsBound: true,
      shaderInputCount: 1,
      shaderInputs: <ProfessionalVideoTransitionShaderInput>[
        ProfessionalVideoTransitionShaderInput(
          shaderInputId: 'shader-input:${plan.transitionId}:0',
          submissionId: 'draw-submission:${plan.transitionId}:0',
          commandId: 'command:output:${plan.transitionId}',
          passId: 'pass:output:${plan.transitionId}',
          passType: 'composeToTransitionSurface',
          outputTarget: 'nativeTransitionCanvasSurface',
          requiresRealPixels: true,
          inputBound: true,
        ),
      ],
      requiresTemporalSamples: true,
      requiresMirrorEdgeTiling: true,
      pixelRendererImplemented: _rendererReady,
      rendererImplemented: _rendererReady,
      canEvaluateShader: true,
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canRenderFrame: _rendererReady,
      blockedReasons: const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionPixelRendererPlanResult>
      planTransitionPixelRenderer({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionPixelRendererPlanResult(
      status: ProfessionalVideoTransitionPixelRendererPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      renderGraphExecutorId: 'executor:${plan.transitionId}',
      surfaceRendererId: 'surface-renderer:${plan.transitionId}',
      frameRenderCommandBufferId: 'frame-command-buffer:${plan.transitionId}',
      rendererBackendId: 'renderer-backend:${plan.transitionId}',
      rendererDrawLoopId: 'draw-loop:${plan.transitionId}',
      transitionShaderEvaluationId: 'shader-evaluation:${plan.transitionId}',
      transitionShaderProgramId: 'shader-program:${plan.definitionId}',
      transitionPixelRendererId: 'pixel-renderer:${plan.transitionId}',
      pixelProgramId: 'pixel-program:${plan.definitionId}',
      shaderFamily: plan.definitionId,
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionCanvasSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      shaderEvaluatorImplemented: true,
      shaderProgramReady: true,
      shaderInputsBound: true,
      pixelWorkloadBound: true,
      pixelInputCount: 1,
      pixelInputs: <ProfessionalVideoTransitionPixelInput>[
        ProfessionalVideoTransitionPixelInput(
          pixelInputId: 'pixel-input:${plan.transitionId}:0',
          shaderInputId: 'shader-input:${plan.transitionId}:0',
          submissionId: 'draw-submission:${plan.transitionId}:0',
          commandId: 'command:output:${plan.transitionId}',
          passId: 'pass:output:${plan.transitionId}',
          passType: 'composeToTransitionSurface',
          outputTarget: 'nativeTransitionCanvasSurface',
          requiresRealPixels: true,
          inputBound: true,
        ),
      ],
      requiresTemporalSamples: true,
      requiresMirrorEdgeTiling: true,
      pixelRendererImplemented: _rendererReady,
      pixelRendererReady: _rendererReady,
      rendererImplemented: _rendererReady,
      canRenderPixels: false,
      rendersRealPixels: false,
      drawsPixels: false,
      canRenderFrame: false,
      blockedReasons: const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionPixelFrameBufferPlanResult>
      planTransitionPixelFrameBuffer({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionPixelFrameBufferPlanResult(
      status: ProfessionalVideoTransitionPixelFrameBufferPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      transitionPixelRendererId: 'pixel-renderer:${plan.transitionId}',
      transitionPixelFrameBufferId: 'pixel-frame-buffer:${plan.transitionId}',
      pixelProgramId: 'pixel-program:${plan.definitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionCanvasSurface',
      outputFramebufferTarget: 'nativeTransitionCanvasSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      frameBufferWidth: plan.canvasWidth,
      frameBufferHeight: plan.canvasHeight,
      frameBufferFormat: 'rgba8888',
      frameBufferByteCount: plan.canvasWidth * plan.canvasHeight * 4,
      frameBufferMemoryClass: _rendererReady ? 'directByteBuffer' : 'none',
      frameBufferAllocationReason:
          _rendererReady ? '' : 'native_transition_pixel_frame_buffer_missing',
      pixelWorkloadBound: true,
      outputFramebufferBound: true,
      pixelRendererImplemented: _rendererReady,
      pixelRendererReady: _rendererReady,
      frameBufferAllocated: _rendererReady,
      frameBufferReady: _rendererReady,
      frameBufferContainsRealPixels: _rendererReady,
      allowsSyntheticPixels: false,
      allowsPosterFrame: false,
      allowsThumbnailFallback: false,
      allowsBoundaryFreeze: false,
      rendererImplemented: _rendererReady,
      canRenderPixels: _rendererReady,
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canRenderFrame: _rendererReady,
      blockedReasons: _planningOnly
          ? const <String>[
              'native_transition_pixel_frame_buffer_missing',
              'native_transition_pixel_frame_buffer_pixels_missing',
              'native_transition_pixel_frame_buffer_renderer_missing',
            ]
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionPixelFrameBufferWriterPlanResult>
      planTransitionPixelFrameBufferWriter({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionPixelFrameBufferWriterPlanResult(
      status:
          ProfessionalVideoTransitionPixelFrameBufferWriterPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      transitionPixelRendererId: 'pixel-renderer:${plan.transitionId}',
      transitionPixelFrameBufferId: 'pixel-frame-buffer:${plan.transitionId}',
      transitionPixelFrameBufferWriterId:
          'pixel-frame-buffer-writer:${plan.transitionId}',
      pixelProgramId: 'pixel-program:${plan.definitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionCanvasSurface',
      outputFramebufferTarget: 'nativeTransitionCanvasSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      frameBufferWidth: plan.canvasWidth,
      frameBufferHeight: plan.canvasHeight,
      frameBufferFormat: 'rgba8888',
      frameBufferByteCount: plan.canvasWidth * plan.canvasHeight * 4,
      frameBufferMemoryClass: _rendererReady ? 'directByteBuffer' : 'none',
      pixelWorkloadBound: true,
      outputFramebufferBound: true,
      frameBufferAllocated: _rendererReady,
      frameBufferReady: _rendererReady,
      writerBoundToFrameBuffer: _rendererReady,
      requiresTemporalSamples: true,
      requiresDualSourceSamples: true,
      allowsStillFrameWrite: false,
      allowsSyntheticPixels: false,
      allowsPosterFrame: false,
      allowsThumbnailFallback: false,
      allowsBoundaryFreeze: false,
      writerImplemented: _rendererReady,
      writerReady: _rendererReady,
      canWriteTemporalPixels: _rendererReady,
      wroteTemporalPixels: _rendererReady,
      frameBufferContainsRealPixels: _rendererReady,
      writerTemporalSampleCount: _rendererReady ? 4 : 0,
      writerExtractedFrameCount: _rendererReady ? 8 : 0,
      writerFrameBufferWriteByteCount:
          _rendererReady ? plan.canvasWidth * plan.canvasHeight * 4 : 0,
      writerFrameBufferChecksum: _rendererReady ? 123456 : 0,
      writerSourceFrameExtractor:
          _rendererReady ? 'MediaMetadataRetriever.getFrameAtTime' : '',
      writerCanvasFillMode: _rendererReady ? 'centerCropFill' : '',
      writerReason: _rendererReady
          ? ''
          : 'native_transition_pixel_frame_buffer_writer_missing',
      pixelRendererImplemented: _rendererReady,
      pixelRendererReady: _rendererReady,
      rendererImplemented: _rendererReady,
      canRenderPixels: _rendererReady,
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canRenderFrame: _rendererReady,
      blockedReasons: _planningOnly
          ? const <String>[
              'native_transition_pixel_frame_buffer_writer_missing',
              'native_transition_pixel_frame_buffer_temporal_pixels_missing',
              'native_transition_pixel_frame_buffer_pixels_missing',
            ]
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionPixelRenderExecutionPlanResult>
      planTransitionPixelRenderExecution({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionPixelRenderExecutionPlanResult(
      status: ProfessionalVideoTransitionPixelRenderExecutionPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      transitionPixelRendererId: 'pixel-renderer:${plan.transitionId}',
      transitionPixelRenderExecutionId:
          'pixel-render-execution:${plan.transitionId}',
      pixelOutputFrameId: 'pixel-output-frame:${plan.transitionId}',
      pixelProgramId: 'pixel-program:${plan.definitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionCanvasSurface',
      outputFramebufferTarget: 'nativeTransitionCanvasSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      pixelWorkloadBound: true,
      outputFramebufferBound: true,
      pixelRendererImplemented: _rendererReady,
      pixelRendererReady: _rendererReady,
      pixelRenderExecutionReady: _rendererReady,
      pixelOutputWritten: _rendererReady,
      pixelOutputReady: _rendererReady,
      pixelOutputSourceFrameBufferId: 'pixel-frame-buffer:${plan.transitionId}',
      pixelOutputWriteMode:
          _rendererReady ? 'offscreenTemporalFrameBuffer' : '',
      pixelOutputByteCount:
          _rendererReady ? plan.canvasWidth * plan.canvasHeight * 4 : 0,
      pixelOutputChecksum: _rendererReady ? 654321 : 0,
      pixelOutputReason:
          _rendererReady ? '' : 'native_transition_pixel_output_missing',
      rendererImplemented: _rendererReady,
      canRenderPixels: _rendererReady,
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canRenderFrame: _rendererReady,
      blockedReasons: _planningOnly
          ? const <String>[
              'native_transition_pixel_renderer_missing',
              'native_transition_pixel_output_missing',
              'native_transition_renderer_pixels_missing',
            ]
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionPixelOutputProofPlanResult>
      planTransitionPixelOutputProof({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionPixelOutputProofPlanResult(
      status: ProfessionalVideoTransitionPixelOutputProofPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      transitionPixelRenderExecutionId:
          'pixel-render-execution:${plan.transitionId}',
      transitionPixelOutputProofId: 'pixel-output-proof:${plan.transitionId}',
      pixelOutputFrameId: 'pixel-output-frame:${plan.transitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      outputTarget: 'nativeTransitionCanvasSurface',
      outputFramebufferTarget: 'nativeTransitionCanvasSurface',
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      canvasWidth: plan.canvasWidth,
      canvasHeight: plan.canvasHeight,
      pixelWorkloadBound: true,
      outputFramebufferBound: true,
      pixelRenderExecutionReady: _rendererReady,
      pixelOutputWritten: _rendererReady,
      pixelOutputReady: _rendererReady,
      outputSurfaceIsNative: true,
      writesOnlyToNativeSurface: true,
      forbidsFlutterOverlay: true,
      forbidsTimelineOverlay: true,
      forbidsPlatformViewTransform: true,
      outputSurfaceUploadPacketId:
          _rendererReady ? 'surface-upload-packet:${plan.transitionId}' : '',
      outputSurfaceUploadPacketReady: _rendererReady,
      outputSurfaceUploadSourceFrameBufferId:
          'pixel-frame-buffer:${plan.transitionId}',
      outputSurfaceUploadByteCount:
          _rendererReady ? plan.canvasWidth * plan.canvasHeight * 4 : 0,
      outputSurfaceUploadChecksum: _rendererReady ? 777777 : 0,
      surfaceUploadRendererImplemented: _rendererReady,
      surfaceUploadRendererReady: _rendererReady,
      outputSurfaceEndpointAttached: _rendererReady,
      outputSurfaceEndpointId:
          _rendererReady ? 'native-surface:${plan.transitionId}' : '',
      outputSurfaceEndpointKind: _rendererReady
          ? 'nativeTransitionCanvasSurface'
          : 'unboundNativeSurface',
      outputSurfaceUploadReason: _rendererReady
          ? ''
          : 'native_transition_surface_upload_packet_missing',
      outputProofReady: _rendererReady,
      rendererImplemented: _rendererReady,
      canRenderPixels: _rendererReady,
      rendersRealPixels: _rendererReady,
      drawsPixels: _rendererReady,
      canRenderFrame: _rendererReady,
      blockedReasons: _planningOnly
          ? const <String>[
              'native_transition_pixel_render_execution_not_ready',
              'native_transition_pixel_output_missing',
              'native_transition_pixel_output_not_ready',
              'native_transition_surface_upload_packet_missing',
              'native_transition_surface_upload_renderer_missing',
              'native_transition_pixel_output_proof_missing',
            ]
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionParityPlanResult> planParityOutputs({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    return ProfessionalVideoTransitionParityPlanResult(
      status: ProfessionalVideoTransitionParityPlanStatus.planned,
      reason: '',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      renderPassGraphId: 'graph:${plan.transitionId}',
      outputSurfaceId: 'surface:${plan.transitionId}',
      renderPassCount: 2,
      outputPassId: 'pass:output:${plan.transitionId}',
      outputPassType: 'composeToTransitionSurface',
      outputPassInputs: const <String>['pass:transition'],
      outputPassBound: true,
      renderGraphOutputReady: !_planningOnly,
      transitionPixelOutputProofId: 'pixel-output-proof:${plan.transitionId}',
      outputProofReady: _rendererReady,
      outputSurfaceUploadPacketReady: _rendererReady,
      surfaceUploadRendererReady: _rendererReady,
      outputSurfaceEndpointAttached: _rendererReady,
      outputSurfaceEndpointId:
          _rendererReady ? 'native-surface:${plan.transitionId}' : '',
      outputSurfaceEndpointKind: _rendererReady
          ? 'nativeTransitionCanvasSurface'
          : 'unboundNativeSurface',
      interactiveSurfaceContractReady: _rendererReady,
      interactiveSurfaceFrameDeliveryReady: _rendererReady,
      interactiveSurfaceFrameDeliveryCount: _rendererReady ? 3 : 0,
      interactiveSurfacePresentationReady: _rendererReady,
      interactiveSurfacePresentationCount: _rendererReady ? 3 : 0,
      interactiveProductionSurfaceReady: _rendererReady,
      interactiveProductionSurfaceCount: _rendererReady ? 3 : 0,
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      rendererImplemented: _rendererReady,
      sameOutputContractForAllModes: true,
      allModesRenderable: _rendererReady,
      outputs: <ProfessionalVideoTransitionParityOutput>[
        for (final mode in <String>['preview', 'liveScrub', 'playback'])
          ProfessionalVideoTransitionParityOutput(
            mode: mode,
            outputSurfaceId: 'surface:${plan.transitionId}',
            outputTarget: 'nativeTransitionSurface',
            outputPassId: 'pass:output:${plan.transitionId}',
            outputPassType: 'composeToTransitionSurface',
            outputPassInputs: const <String>['pass:transition'],
            outputPassBound: true,
            renderGraphOutputReady: !_planningOnly,
            transitionPixelOutputProofId:
                'pixel-output-proof:${plan.transitionId}',
            outputProofReady: _rendererReady,
            outputSurfaceUploadPacketReady: _rendererReady,
            surfaceUploadRendererReady: _rendererReady,
            outputSurfaceEndpointAttached: _rendererReady,
            outputSurfaceEndpointId:
                _rendererReady ? 'native-surface:${plan.transitionId}' : '',
            outputSurfaceEndpointKind: _rendererReady
                ? 'nativeTransitionCanvasSurface'
                : 'unboundNativeSurface',
            interactiveSurfaceId:
                _rendererReady ? 'interactive-$mode:${plan.transitionId}' : '',
            interactiveSurfaceKind: _rendererReady
                ? 'interactiveNativeTransitionSurface'
                : 'unboundInteractiveSurface',
            interactiveSurfaceBound: _rendererReady,
            interactiveSurfaceFrameDelivered: _rendererReady,
            interactiveSurfaceFrameByteCount: _rendererReady ? 8294400 : 0,
            interactiveSurfaceFrameChecksum: _rendererReady ? 777777 : 0,
            interactiveSurfaceFrameReason: _rendererReady
                ? ''
                : 'native_transition_${mode}_interactive_surface_frame_missing',
            interactiveSurfaceFramePresented: _rendererReady,
            interactiveSurfacePresentedImageCount: _rendererReady ? 1 : 0,
            interactiveSurfacePresentedByteCount: _rendererReady ? 8294400 : 0,
            interactiveSurfacePresentedChecksum: _rendererReady ? 888888 : 0,
            interactiveSurfacePresentationReason: _rendererReady
                ? ''
                : 'native_transition_${mode}_interactive_surface_presentation_missing',
            interactiveSurfaceProductionBound: _rendererReady,
            interactiveSurfaceProductionReady: _rendererReady,
            interactiveSurfaceProductionReason: _rendererReady
                ? ''
                : 'native_transition_${mode}_production_surface_missing',
            rendererImplemented: _rendererReady,
            canRender: _rendererReady && !_planningOnly,
            blockedReasons: _planningOnly
                ? const <String>['native_transition_renderer_not_implemented']
                : const <String>[],
          ),
      ],
      blockedReasons: _planningOnly
          ? const <String>['native_transition_renderer_not_implemented']
          : const <String>[],
    );
  }

  @override
  Future<ProfessionalVideoTransitionInteractiveFrameRenderResult>
      renderInteractiveFrame({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
    required String mode,
    required String surfaceId,
  }) async {
    return ProfessionalVideoTransitionInteractiveFrameRenderResult(
      status: _rendererReady
          ? ProfessionalVideoTransitionInteractiveFrameRenderStatus.planned
          : ProfessionalVideoTransitionInteractiveFrameRenderStatus
              .invalidRequest,
      reason: _rendererReady ? '' : 'native_transition_renderer_not_ready',
      rendererVersion: 'fake',
      definitionId: plan.definitionId,
      renderSessionId: 'transition-session:${plan.transitionId}',
      mode: mode,
      surfaceId: surfaceId,
      timelineTime: timelineTime,
      transitionStartTime: plan.boundaryTime - plan.leadingDuration,
      transitionEndTime: plan.boundaryTime + plan.trailingDuration,
      pixelOutputReady: _rendererReady,
      frameDelivered: _rendererReady,
      framePresented: _rendererReady,
      frameByteCount: _rendererReady ? 4096 : 0,
      frameChecksum: _rendererReady ? 7 : 0,
      surfaceAttached: _rendererReady,
      surfaceKind: _rendererReady ? 'interactiveNativeTransitionSurface' : '',
      renderOwner: _rendererReady ? 'professionalCompositor' : '',
      motionBlurEnabled: false,
      sampleCount: 0,
      outgoingContributionCount: 0,
      incomingContributionCount: 0,
      centerContributionCount: 0,
      trailContributionCount: 0,
      motionBlurAmount: 0,
      forcedVisualTestPattern: false,
      forcedSyntheticMotionBlur: false,
      sampleTransformDelta: 0,
      rendererConsumedSamples: false,
      renderPassIncludesTemporalMotionBlur: false,
      fallbackUsed: false,
      checksumBefore: 0,
      checksumAfter: _rendererReady ? 7 : 0,
      checksumDelta: _rendererReady,
      canRenderFrame: _rendererReady,
      blockedReasons: _rendererReady
          ? const <String>[]
          : const <String>['native_transition_renderer_not_ready'],
    );
  }

  @override
  Future<ProfessionalVideoTransitionCompositorPrepareResult>
      prepareZoomInCameraRenderPlan(
    ProfessionalZoomCameraRenderPlan plan,
  ) {
    return prepareRenderPlan(plan.toGenericRenderPlan());
  }

  static ProfessionalVideoTransitionSourceBinding _sourceBinding(
    ProfessionalVideoTransitionCompositorSource source,
  ) {
    return ProfessionalVideoTransitionSourceBinding(
      role: source.clipId == 'clip-a' ? 'outgoing' : 'incoming',
      clipId: source.clipId,
      assetId: source.assetId,
      sourceUri: source.sourceUri ?? '',
      sourceUriBound: true,
      timelineStartTime: source.timelineRange.start,
      timelineEndTime: source.timelineRange.endExclusive,
      sourceStartTime: source.sourceStartTime,
      sourceDuration: source.sourceDuration,
      requiresConcreteSourceUri: true,
      allowAssetIdOnlyDecode: false,
      allowGeneratedProxyDecode: false,
    );
  }

  static ProfessionalVideoTransitionFrameDecodeRequest _decodeRequest(
    ProfessionalVideoTransitionCompositorSource source,
    String role,
    int sampleIndex,
  ) {
    return ProfessionalVideoTransitionFrameDecodeRequest(
      decodeRequestId: 'decode:$role:$sampleIndex',
      role: role,
      clipId: source.clipId,
      assetId: source.assetId,
      sourceUri: source.sourceUri ?? '',
      sampleIndex: sampleIndex,
      timelineTime: source.timelineRange.start,
      sourceTime: source.sourceStartTime,
      decodeMode: 'exactVideoFrame',
      temporalSample: true,
      centerSample: sampleIndex == 0,
      allowThumbnailFallback: false,
      allowBoundaryFreeze: false,
    );
  }

  static ProfessionalVideoTransitionSourceProbe _sourceProbe(
    ProfessionalVideoTransitionCompositorSource source,
    String role,
  ) {
    return ProfessionalVideoTransitionSourceProbe(
      role: role,
      clipId: source.clipId,
      assetId: source.assetId,
      sourceUri: source.sourceUri ?? '',
      uriScheme: 'file',
      sourceUriBound: true,
      requiresRealVideoSource: true,
      probeImplemented: true,
      canOpenSource: true,
      hasVideoTrack: true,
      videoMimeType: 'video/avc',
      videoWidth: 1080,
      videoHeight: 1920,
      videoDuration: source.sourceDuration,
      videoFrameRate: 30,
      allowSyntheticSource: false,
      blockedReasons: const <String>[],
    );
  }

  static ProfessionalVideoTransitionDecoderTrack _decoderTrack(
    ProfessionalVideoTransitionCompositorSource source,
    String role,
  ) {
    return ProfessionalVideoTransitionDecoderTrack(
      role: role,
      clipId: source.clipId,
      assetId: source.assetId,
      sourceUri: source.sourceUri ?? '',
      decodeRequestIds: <String>['decode:$role:0'],
      sampleCount: 1,
      requiresExactFrameDecode: true,
      allowThumbnailFallback: false,
      allowBoundaryFreeze: false,
      liveDecodeWindowTimelineStartTime: source.timelineRange.start,
      liveDecodeWindowTimelineEndTime: source.timelineRange.endExclusive,
      liveDecodeWindowSourceStartTime: source.sourceStartTime,
      liveDecodeWindowSourceEndTime:
          source.sourceStartTime + source.sourceDuration,
      liveDecodeWindowDuration:
          source.timelineRange.endExclusive - source.timelineRange.start,
      liveDecodeSourceWindowDuration: source.sourceDuration,
      liveDecodeCoverageDecodeProbeImplemented: true,
      liveDecodeCoverageSourceTimes: <TimelineTime>[
        source.sourceStartTime,
        source.sourceStartTime +
            TimelineTime.fromMilliseconds(
              source.sourceDuration.inMilliseconds ~/ 2,
            ),
        source.sourceStartTime + source.sourceDuration,
      ],
      liveDecodeCoverageRequestedSampleCount: 3,
      liveDecodeCoverageDecodedSampleCount: 3,
      liveDecodeCoverageDecodedBufferCount: 3,
      liveDecodeWindowReady: true,
      liveDecodeStreamProbeImplemented: true,
      liveDecodeStreamDecodedFrameCount: 61,
      liveDecodeStreamReadableBufferCount: 61,
      liveDecodeStreamFirstFrameTime: source.sourceStartTime,
      liveDecodeStreamLastFrameTime: source.sourceStartTime +
          source.sourceDuration -
          TimelineTime.fromMilliseconds(33),
      liveDecodeStreamMinRequiredFrameCount: 18,
      liveDecodeStreamCoverageReady: true,
      continuousSampleCoverageReady: true,
    );
  }
}
