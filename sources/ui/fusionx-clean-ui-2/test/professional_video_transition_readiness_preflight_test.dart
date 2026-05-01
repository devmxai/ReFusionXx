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
        ProfessionalVideoTransitionReadinessStageId.outputSurface,
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
