import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../presentation/models/timeline_time.dart';

enum ProfessionalVideoTransitionCompositorKind {
  crossDissolve,
  fadeBlack,
  zoomInCamera,
}

@immutable
class ProfessionalVideoTransitionCompositorCapabilities {
  const ProfessionalVideoTransitionCompositorCapabilities({
    required this.dualVideoSampling,
    required this.temporalMotionBlur,
    required this.mirrorEdgeTiling,
    required this.previewParity,
    required this.liveScrubParity,
    required this.playbackParity,
    required this.exportParity,
    this.registeredDefinitions = const <String>[],
  });

  static const unavailable = ProfessionalVideoTransitionCompositorCapabilities(
    dualVideoSampling: false,
    temporalMotionBlur: false,
    mirrorEdgeTiling: false,
    previewParity: false,
    liveScrubParity: false,
    playbackParity: false,
    exportParity: false,
    registeredDefinitions: <String>[],
  );

  final bool dualVideoSampling;
  final bool temporalMotionBlur;
  final bool mirrorEdgeTiling;
  final bool previewParity;
  final bool liveScrubParity;
  final bool playbackParity;
  final bool exportParity;
  final List<String> registeredDefinitions;

  bool get canExposeProfessionalZoomInCamera =>
      canExposeProfessionalVideoTransitions;

  /// Strict interactive gate for creating any new professional video transition.
  ///
  /// This intentionally requires the complete preview/scrub/playback
  /// compositor stack, even for simpler transition definitions, so unsupported
  /// presets cannot slip back into frozen-frame, Flutter-overlay, or
  /// single-surface fallback rendering. Export parity is tracked separately so
  /// interactive transition authoring can ship before the export renderer.
  bool get canExposeProfessionalVideoTransitions =>
      dualVideoSampling &&
      temporalMotionBlur &&
      mirrorEdgeTiling &&
      previewParity &&
      liveScrubParity &&
      playbackParity;

  bool get canExportProfessionalVideoTransitions =>
      canExposeProfessionalVideoTransitions && exportParity;

  List<String> get missingForProfessionalZoomInCamera {
    return missingForProfessionalVideoTransitions;
  }

  List<String> get missingForProfessionalVideoTransitions {
    final missing = <String>[];
    if (!dualVideoSampling) {
      missing.add('dualVideoSampling');
    }
    if (!temporalMotionBlur) {
      missing.add('temporalMotionBlur');
    }
    if (!mirrorEdgeTiling) {
      missing.add('mirrorEdgeTiling');
    }
    if (!previewParity) {
      missing.add('previewParity');
    }
    if (!liveScrubParity) {
      missing.add('liveScrubParity');
    }
    if (!playbackParity) {
      missing.add('playbackParity');
    }
    return List.unmodifiable(missing);
  }

  List<String> get missingForProfessionalVideoTransitionExport {
    final missing = <String>[...missingForProfessionalVideoTransitions];
    if (!exportParity) {
      missing.add('exportParity');
    }
    return List.unmodifiable(missing);
  }
}

const ProfessionalVideoTransitionCompositorCapabilities
    kCurrentProfessionalVideoTransitionCompositorCapabilities =
    ProfessionalVideoTransitionCompositorCapabilities.unavailable;

abstract class ProfessionalVideoTransitionCompositorCapabilityProvider {
  const ProfessionalVideoTransitionCompositorCapabilityProvider();

  Future<ProfessionalVideoTransitionCompositorCapabilities> loadCapabilities();
}

abstract class ProfessionalVideoTransitionCompositorClient
    extends ProfessionalVideoTransitionCompositorCapabilityProvider {
  const ProfessionalVideoTransitionCompositorClient();

  Future<ProfessionalVideoTransitionCompositorPrepareResult> prepareRenderPlan(
    ProfessionalVideoTransitionRenderPlan plan,
  );

  Future<ProfessionalVideoTransitionSourceBindingPlanResult>
      planVideoSourceBindings({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionSourceProbePlanResult>
      planVideoSourceProbe({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionFrameSamplePlanResult> planFrameSamples({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionFrameDecodePlanResult>
      planFrameDecodeRequests({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionDecoderSessionPlanResult>
      planDualVideoDecoderSession({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionTemporalAccumulatorPlanResult>
      planTemporalSampleAccumulator({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionMirrorEdgeTilingPlanResult>
      planMirrorEdgeTiling({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionRenderPassGraphPlanResult>
      planRenderPassGraph({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionRenderGraphExecutionPlanResult>
      planRenderGraphExecution({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionSurfaceRendererPlanResult>
      planSurfaceRenderer({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionFrameRenderCommandPlanResult>
      planFrameRenderCommands({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionRendererBackendPlanResult>
      planRendererBackend({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionRendererDrawLoopPlanResult>
      planRendererDrawLoop({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionOutputSurfacePlanResult> planOutputSurface({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionParityPlanResult> planParityOutputs({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  });

  Future<ProfessionalVideoTransitionCompositorPrepareResult>
      prepareZoomInCameraRenderPlan(
    ProfessionalZoomCameraRenderPlan plan,
  );
}

class MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider
    extends ProfessionalVideoTransitionCompositorClient {
  const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : _channel = channel;

  static const String _channelName =
      'com.refusion.app/professional_video_transition_compositor';

  final MethodChannel _channel;

  @override
  Future<ProfessionalVideoTransitionCompositorCapabilities>
      loadCapabilities() async {
    try {
      final rawCapabilities =
          await _channel.invokeMapMethod<String, Object?>('getCapabilities');
      return ProfessionalVideoTransitionCompositorCapabilitiesMapper.fromMap(
        rawCapabilities,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionCompositorCapabilities.unavailable;
    } on PlatformException {
      return ProfessionalVideoTransitionCompositorCapabilities.unavailable;
    }
  }

  @override
  Future<ProfessionalVideoTransitionCompositorPrepareResult> prepareRenderPlan(
    ProfessionalVideoTransitionRenderPlan plan,
  ) async {
    try {
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'prepareRenderPlan',
        plan.toPlatformMap(),
      );
      return ProfessionalVideoTransitionCompositorPrepareResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionCompositorPrepareResult.unsupported(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionCompositorPrepareResult.invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionSourceBindingPlanResult>
      planVideoSourceBindings({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planVideoSourceBindings',
        payload,
      );
      return ProfessionalVideoTransitionSourceBindingPlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionSourceBindingPlanResult.invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionSourceBindingPlanResult.invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionSourceProbePlanResult>
      planVideoSourceProbe({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planVideoSourceProbe',
        payload,
      );
      return ProfessionalVideoTransitionSourceProbePlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionSourceProbePlanResult.invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionSourceProbePlanResult.invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionFrameSamplePlanResult> planFrameSamples({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planFrameSamples',
        payload,
      );
      return ProfessionalVideoTransitionFrameSamplePlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionFrameSamplePlanResult.invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionFrameSamplePlanResult.invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionFrameDecodePlanResult>
      planFrameDecodeRequests({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planFrameDecodeRequests',
        payload,
      );
      return ProfessionalVideoTransitionFrameDecodePlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionFrameDecodePlanResult.invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionFrameDecodePlanResult.invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionDecoderSessionPlanResult>
      planDualVideoDecoderSession({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planDualVideoDecoderSession',
        payload,
      );
      return ProfessionalVideoTransitionDecoderSessionPlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionDecoderSessionPlanResult.invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionDecoderSessionPlanResult.invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionTemporalAccumulatorPlanResult>
      planTemporalSampleAccumulator({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planTemporalSampleAccumulator',
        payload,
      );
      return ProfessionalVideoTransitionTemporalAccumulatorPlanResultMapper
          .fromMap(rawResult);
    } on MissingPluginException {
      return ProfessionalVideoTransitionTemporalAccumulatorPlanResult
          .invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionTemporalAccumulatorPlanResult
          .invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionMirrorEdgeTilingPlanResult>
      planMirrorEdgeTiling({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planMirrorEdgeTiling',
        payload,
      );
      return ProfessionalVideoTransitionMirrorEdgeTilingPlanResultMapper
          .fromMap(rawResult);
    } on MissingPluginException {
      return ProfessionalVideoTransitionMirrorEdgeTilingPlanResult
          .invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionMirrorEdgeTilingPlanResult
          .invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionRenderPassGraphPlanResult>
      planRenderPassGraph({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planRenderPassGraph',
        payload,
      );
      return ProfessionalVideoTransitionRenderPassGraphPlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionRenderPassGraphPlanResult
          .invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionRenderPassGraphPlanResult
          .invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionOutputSurfacePlanResult> planOutputSurface({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planOutputSurface',
        payload,
      );
      return ProfessionalVideoTransitionOutputSurfacePlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionOutputSurfacePlanResult.invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionOutputSurfacePlanResult.invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionRenderGraphExecutionPlanResult>
      planRenderGraphExecution({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planRenderGraphExecution',
        payload,
      );
      return ProfessionalVideoTransitionRenderGraphExecutionPlanResultMapper
          .fromMap(rawResult);
    } on MissingPluginException {
      return ProfessionalVideoTransitionRenderGraphExecutionPlanResult
          .invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionRenderGraphExecutionPlanResult
          .invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionSurfaceRendererPlanResult>
      planSurfaceRenderer({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planSurfaceRenderer',
        payload,
      );
      return ProfessionalVideoTransitionSurfaceRendererPlanResultMapper.fromMap(
          rawResult);
    } on MissingPluginException {
      return ProfessionalVideoTransitionSurfaceRendererPlanResult
          .invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionSurfaceRendererPlanResult
          .invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionFrameRenderCommandPlanResult>
      planFrameRenderCommands({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planFrameRenderCommands',
        payload,
      );
      return ProfessionalVideoTransitionFrameRenderCommandPlanResultMapper
          .fromMap(rawResult);
    } on MissingPluginException {
      return ProfessionalVideoTransitionFrameRenderCommandPlanResult
          .invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionFrameRenderCommandPlanResult
          .invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionRendererBackendPlanResult>
      planRendererBackend({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planRendererBackend',
        payload,
      );
      return ProfessionalVideoTransitionRendererBackendPlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionRendererBackendPlanResult
          .invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionRendererBackendPlanResult
          .invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionRendererDrawLoopPlanResult>
      planRendererDrawLoop({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planRendererDrawLoop',
        payload,
      );
      return ProfessionalVideoTransitionRendererDrawLoopPlanResultMapper
          .fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionRendererDrawLoopPlanResult
          .invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionRendererDrawLoopPlanResult
          .invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionParityPlanResult> planParityOutputs({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    try {
      final payload = plan.toPlatformMap();
      payload['timelineTimeMs'] = timelineTime.inMilliseconds;
      final rawResult = await _channel.invokeMapMethod<String, Object?>(
        'planParityOutputs',
        payload,
      );
      return ProfessionalVideoTransitionParityPlanResultMapper.fromMap(
        rawResult,
      );
    } on MissingPluginException {
      return ProfessionalVideoTransitionParityPlanResult.invalidRequest(
        reason: 'native_compositor_channel_missing',
      );
    } on PlatformException catch (error) {
      return ProfessionalVideoTransitionParityPlanResult.invalidRequest(
        reason: error.message ?? error.code,
      );
    }
  }

  @override
  Future<ProfessionalVideoTransitionCompositorPrepareResult>
      prepareZoomInCameraRenderPlan(
    ProfessionalZoomCameraRenderPlan plan,
  ) {
    return prepareRenderPlan(plan.toGenericRenderPlan());
  }
}

enum ProfessionalVideoTransitionSourceBindingPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionSourceBinding {
  const ProfessionalVideoTransitionSourceBinding({
    required this.role,
    required this.clipId,
    required this.assetId,
    required this.sourceUri,
    required this.sourceUriBound,
    required this.timelineStartTime,
    required this.timelineEndTime,
    required this.sourceStartTime,
    required this.sourceDuration,
    required this.requiresConcreteSourceUri,
    required this.allowAssetIdOnlyDecode,
    required this.allowGeneratedProxyDecode,
  });

  final String role;
  final String clipId;
  final String assetId;
  final String sourceUri;
  final bool sourceUriBound;
  final TimelineTime timelineStartTime;
  final TimelineTime timelineEndTime;
  final TimelineTime sourceStartTime;
  final TimelineTime sourceDuration;
  final bool requiresConcreteSourceUri;
  final bool allowAssetIdOnlyDecode;
  final bool allowGeneratedProxyDecode;
}

@immutable
class ProfessionalVideoTransitionSourceBindingPlanResult {
  const ProfessionalVideoTransitionSourceBindingPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.requiresConcreteSourceUri,
    required this.allSourcesBound,
    required this.allowAssetIdOnlyDecode,
    required this.allowGeneratedProxyDecode,
    required this.bindings,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionSourceBindingPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionSourceBindingPlanResult(
      status: ProfessionalVideoTransitionSourceBindingPlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      requiresConcreteSourceUri: true,
      allSourcesBound: false,
      allowAssetIdOnlyDecode: false,
      allowGeneratedProxyDecode: false,
      bindings: const <ProfessionalVideoTransitionSourceBinding>[],
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionSourceBindingPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final bool requiresConcreteSourceUri;
  final bool allSourcesBound;
  final bool allowAssetIdOnlyDecode;
  final bool allowGeneratedProxyDecode;
  final List<ProfessionalVideoTransitionSourceBinding> bindings;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionSourceBindingPlanStatus.planned;

  bool get canBind =>
      canPlan &&
      requiresConcreteSourceUri &&
      allSourcesBound &&
      !allowAssetIdOnlyDecode &&
      !allowGeneratedProxyDecode &&
      bindings.length == 2 &&
      bindings.every((binding) {
        return binding.sourceUriBound &&
            binding.requiresConcreteSourceUri &&
            !binding.allowAssetIdOnlyDecode &&
            !binding.allowGeneratedProxyDecode;
      }) &&
      blockedReasons.isEmpty;
}

class ProfessionalVideoTransitionSourceBindingPlanResultMapper {
  const ProfessionalVideoTransitionSourceBindingPlanResultMapper._();

  static ProfessionalVideoTransitionSourceBindingPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionSourceBindingPlanResult.invalidRequest(
        reason: 'native_compositor_empty_source_binding_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionSourceBindingPlanStatus.planned,
      _ => ProfessionalVideoTransitionSourceBindingPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionSourceBindingPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      requiresConcreteSourceUri: _readBool(
        map['requiresConcreteSourceUri'],
        defaultValue: true,
      ),
      allSourcesBound: _readBool(map['allSourcesBound']),
      allowAssetIdOnlyDecode: _readBool(map['allowAssetIdOnlyDecode']),
      allowGeneratedProxyDecode: _readBool(map['allowGeneratedProxyDecode']),
      bindings: _readBindings(map['bindings']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionSourceBinding> _readBindings(
    Object? value,
  ) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionSourceBinding>[];
    }
    return List<ProfessionalVideoTransitionSourceBinding>.unmodifiable(
      value.whereType<Map>().map((binding) {
        return ProfessionalVideoTransitionSourceBinding(
          role: binding['role']?.toString() ?? '',
          clipId: binding['clipId']?.toString() ?? '',
          assetId: binding['assetId']?.toString() ?? '',
          sourceUri: binding['sourceUri']?.toString() ?? '',
          sourceUriBound: _readBool(binding['sourceUriBound']),
          timelineStartTime: _readTimelineTime(binding['timelineStartMs']) ??
              TimelineTime.zero,
          timelineEndTime:
              _readTimelineTime(binding['timelineEndMs']) ?? TimelineTime.zero,
          sourceStartTime:
              _readTimelineTime(binding['sourceStartMs']) ?? TimelineTime.zero,
          sourceDuration: _readTimelineTime(binding['sourceDurationMs']) ??
              TimelineTime.zero,
          requiresConcreteSourceUri: _readBool(
            binding['requiresConcreteSourceUri'],
            defaultValue: true,
          ),
          allowAssetIdOnlyDecode: _readBool(binding['allowAssetIdOnlyDecode']),
          allowGeneratedProxyDecode:
              _readBool(binding['allowGeneratedProxyDecode']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionSourceProbePlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionSourceProbe {
  const ProfessionalVideoTransitionSourceProbe({
    required this.role,
    required this.clipId,
    required this.assetId,
    required this.sourceUri,
    required this.uriScheme,
    required this.sourceUriBound,
    required this.requiresRealVideoSource,
    required this.probeImplemented,
    required this.canOpenSource,
    required this.hasVideoTrack,
    required this.videoMimeType,
    required this.videoWidth,
    required this.videoHeight,
    required this.videoDuration,
    required this.videoFrameRate,
    required this.allowSyntheticSource,
    required this.blockedReasons,
  });

  final String role;
  final String clipId;
  final String assetId;
  final String sourceUri;
  final String uriScheme;
  final bool sourceUriBound;
  final bool requiresRealVideoSource;
  final bool probeImplemented;
  final bool canOpenSource;
  final bool hasVideoTrack;
  final String videoMimeType;
  final int videoWidth;
  final int videoHeight;
  final TimelineTime videoDuration;
  final int videoFrameRate;
  final bool allowSyntheticSource;
  final List<String> blockedReasons;

  bool get canProbe =>
      sourceUriBound &&
      requiresRealVideoSource &&
      probeImplemented &&
      canOpenSource &&
      hasVideoTrack &&
      !allowSyntheticSource &&
      blockedReasons.isEmpty;
}

@immutable
class ProfessionalVideoTransitionSourceProbePlanResult {
  const ProfessionalVideoTransitionSourceProbePlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.requiresRealVideoSource,
    required this.probeImplemented,
    required this.allSourcesProbeable,
    required this.allowSyntheticSource,
    required this.probes,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionSourceProbePlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionSourceProbePlanResult(
      status: ProfessionalVideoTransitionSourceProbePlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      requiresRealVideoSource: true,
      probeImplemented: false,
      allSourcesProbeable: false,
      allowSyntheticSource: false,
      probes: const <ProfessionalVideoTransitionSourceProbe>[],
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionSourceProbePlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final bool requiresRealVideoSource;
  final bool probeImplemented;
  final bool allSourcesProbeable;
  final bool allowSyntheticSource;
  final List<ProfessionalVideoTransitionSourceProbe> probes;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionSourceProbePlanStatus.planned;

  bool get canProbe =>
      canPlan &&
      requiresRealVideoSource &&
      probeImplemented &&
      allSourcesProbeable &&
      !allowSyntheticSource &&
      probes.length == 2 &&
      probes.every((probe) => probe.canProbe) &&
      blockedReasons.isEmpty;
}

class ProfessionalVideoTransitionSourceProbePlanResultMapper {
  const ProfessionalVideoTransitionSourceProbePlanResultMapper._();

  static ProfessionalVideoTransitionSourceProbePlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionSourceProbePlanResult.invalidRequest(
        reason: 'native_compositor_empty_source_probe_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionSourceProbePlanStatus.planned,
      _ => ProfessionalVideoTransitionSourceProbePlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionSourceProbePlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      requiresRealVideoSource: _readBool(
        map['requiresRealVideoSource'],
        defaultValue: true,
      ),
      probeImplemented: _readBool(map['probeImplemented']),
      allSourcesProbeable: _readBool(map['allSourcesProbeable']),
      allowSyntheticSource: _readBool(map['allowSyntheticSource']),
      probes: _readProbes(map['probes']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionSourceProbe> _readProbes(
    Object? value,
  ) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionSourceProbe>[];
    }
    return List<ProfessionalVideoTransitionSourceProbe>.unmodifiable(
      value.whereType<Map>().map((probe) {
        return ProfessionalVideoTransitionSourceProbe(
          role: probe['role']?.toString() ?? '',
          clipId: probe['clipId']?.toString() ?? '',
          assetId: probe['assetId']?.toString() ?? '',
          sourceUri: probe['sourceUri']?.toString() ?? '',
          uriScheme: probe['uriScheme']?.toString() ?? '',
          sourceUriBound: _readBool(probe['sourceUriBound']),
          requiresRealVideoSource: _readBool(
            probe['requiresRealVideoSource'],
            defaultValue: true,
          ),
          probeImplemented: _readBool(probe['probeImplemented']),
          canOpenSource: _readBool(probe['canOpenSource']),
          hasVideoTrack: _readBool(probe['hasVideoTrack']),
          videoMimeType: probe['videoMimeType']?.toString() ?? '',
          videoWidth: _readInt(probe['videoWidth']),
          videoHeight: _readInt(probe['videoHeight']),
          videoDuration: TimelineTime.fromMilliseconds(
            (_readInt(probe['videoDurationUs']) / 1000).round(),
          ),
          videoFrameRate: _readInt(probe['videoFrameRate']),
          allowSyntheticSource: _readBool(probe['allowSyntheticSource']),
          blockedReasons: _readStringList(probe['blockedReasons']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionFrameSamplePlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionFrameSamplePlanResult {
  const ProfessionalVideoTransitionFrameSamplePlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.progress,
    required this.sourceRoles,
    required this.outgoingSourceTime,
    required this.incomingSourceTime,
    required this.temporalSampleTimelineTimes,
    required this.outgoingTemporalSourceTimes,
    required this.incomingTemporalSourceTimes,
    required this.motionBlurMode,
    required this.shutterAngleDegrees,
    required this.frameRate,
    required this.shutterSampleCount,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionFrameSamplePlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionFrameSamplePlanResult(
      status: ProfessionalVideoTransitionFrameSamplePlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      progress: 0,
      sourceRoles: const <String>[],
      outgoingSourceTime: null,
      incomingSourceTime: null,
      temporalSampleTimelineTimes: const <TimelineTime>[],
      outgoingTemporalSourceTimes: const <TimelineTime>[],
      incomingTemporalSourceTimes: const <TimelineTime>[],
      motionBlurMode: '',
      shutterAngleDegrees: 0,
      frameRate: 0,
      shutterSampleCount: 0,
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionFrameSamplePlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final double progress;
  final List<String> sourceRoles;
  final TimelineTime? outgoingSourceTime;
  final TimelineTime? incomingSourceTime;
  final List<TimelineTime> temporalSampleTimelineTimes;
  final List<TimelineTime> outgoingTemporalSourceTimes;
  final List<TimelineTime> incomingTemporalSourceTimes;
  final String motionBlurMode;
  final double shutterAngleDegrees;
  final double frameRate;
  final int shutterSampleCount;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionFrameSamplePlanStatus.planned;
}

class ProfessionalVideoTransitionFrameSamplePlanResultMapper {
  const ProfessionalVideoTransitionFrameSamplePlanResultMapper._();

  static ProfessionalVideoTransitionFrameSamplePlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionFrameSamplePlanResult.invalidRequest(
        reason: 'native_compositor_empty_sample_plan_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionFrameSamplePlanStatus.planned,
      _ => ProfessionalVideoTransitionFrameSamplePlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionFrameSamplePlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      progress: _readDouble(map['progress']),
      sourceRoles: _readStringList(map['sourceRoles']),
      outgoingSourceTime: _readTimelineTime(map['outgoingSourceTimeMs']),
      incomingSourceTime: _readTimelineTime(map['incomingSourceTimeMs']),
      temporalSampleTimelineTimes:
          _readTimelineTimes(map['temporalSampleTimelineTimesMs']),
      outgoingTemporalSourceTimes:
          _readTimelineTimes(map['outgoingTemporalSourceTimesMs']),
      incomingTemporalSourceTimes:
          _readTimelineTimes(map['incomingTemporalSourceTimesMs']),
      motionBlurMode: map['motionBlurMode']?.toString() ?? '',
      shutterAngleDegrees: _readDouble(map['shutterAngleDegrees']),
      frameRate: _readDouble(map['frameRate']),
      shutterSampleCount: _readInt(map['shutterSampleCount']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }

  static List<TimelineTime> _readTimelineTimes(Object? value) {
    if (value is! List) {
      return const <TimelineTime>[];
    }
    return List<TimelineTime>.unmodifiable(
      value.map(_readTimelineTime).whereType<TimelineTime>(),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum ProfessionalVideoTransitionFrameDecodePlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionFrameDecodeRequest {
  const ProfessionalVideoTransitionFrameDecodeRequest({
    required this.decodeRequestId,
    required this.role,
    required this.clipId,
    required this.assetId,
    required this.sourceUri,
    required this.sampleIndex,
    required this.timelineTime,
    required this.sourceTime,
    required this.decodeMode,
    required this.temporalSample,
    required this.centerSample,
    required this.allowThumbnailFallback,
    required this.allowBoundaryFreeze,
  });

  final String decodeRequestId;
  final String role;
  final String clipId;
  final String assetId;
  final String sourceUri;
  final int sampleIndex;
  final TimelineTime timelineTime;
  final TimelineTime sourceTime;
  final String decodeMode;
  final bool temporalSample;
  final bool centerSample;
  final bool allowThumbnailFallback;
  final bool allowBoundaryFreeze;
}

@immutable
class ProfessionalVideoTransitionFrameDecodePlanResult {
  const ProfessionalVideoTransitionFrameDecodePlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.progress,
    required this.decodeMode,
    required this.allowThumbnailFallback,
    required this.allowBoundaryFreeze,
    required this.requiresRealVideoFrame,
    required this.decodeRequests,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionFrameDecodePlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionFrameDecodePlanResult(
      status: ProfessionalVideoTransitionFrameDecodePlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      progress: 0,
      decodeMode: '',
      allowThumbnailFallback: false,
      allowBoundaryFreeze: false,
      requiresRealVideoFrame: true,
      decodeRequests: const <ProfessionalVideoTransitionFrameDecodeRequest>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionFrameDecodePlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final double progress;
  final String decodeMode;
  final bool allowThumbnailFallback;
  final bool allowBoundaryFreeze;
  final bool requiresRealVideoFrame;
  final List<ProfessionalVideoTransitionFrameDecodeRequest> decodeRequests;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionFrameDecodePlanStatus.planned;
}

class ProfessionalVideoTransitionFrameDecodePlanResultMapper {
  const ProfessionalVideoTransitionFrameDecodePlanResultMapper._();

  static ProfessionalVideoTransitionFrameDecodePlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionFrameDecodePlanResult.invalidRequest(
        reason: 'native_compositor_empty_decode_plan_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionFrameDecodePlanStatus.planned,
      _ => ProfessionalVideoTransitionFrameDecodePlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionFrameDecodePlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      progress: _readDouble(map['progress']),
      decodeMode: map['decodeMode']?.toString() ?? '',
      allowThumbnailFallback: _readBool(map['allowThumbnailFallback']),
      allowBoundaryFreeze: _readBool(map['allowBoundaryFreeze']),
      requiresRealVideoFrame: _readBool(
        map['requiresRealVideoFrame'],
        defaultValue: true,
      ),
      decodeRequests: _readDecodeRequests(map['decodeRequests']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionFrameDecodeRequest>
      _readDecodeRequests(Object? value) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionFrameDecodeRequest>[];
    }
    return List<ProfessionalVideoTransitionFrameDecodeRequest>.unmodifiable(
      value.whereType<Map>().map((request) {
        final timelineTime = _readTimelineTime(request['timelineTimeMs']);
        final sourceTime = _readTimelineTime(request['sourceTimeMs']);
        return ProfessionalVideoTransitionFrameDecodeRequest(
          decodeRequestId: request['decodeRequestId']?.toString() ?? '',
          role: request['role']?.toString() ?? '',
          clipId: request['clipId']?.toString() ?? '',
          assetId: request['assetId']?.toString() ?? '',
          sourceUri: request['sourceUri']?.toString() ?? '',
          sampleIndex: _readInt(request['sampleIndex']),
          timelineTime: timelineTime ?? TimelineTime.zero,
          sourceTime: sourceTime ?? TimelineTime.zero,
          decodeMode: request['decodeMode']?.toString() ?? '',
          temporalSample: _readBool(request['temporalSample']),
          centerSample: _readBool(request['centerSample']),
          allowThumbnailFallback: _readBool(request['allowThumbnailFallback']),
          allowBoundaryFreeze: _readBool(request['allowBoundaryFreeze']),
        );
      }),
    );
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum ProfessionalVideoTransitionDecoderSessionPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionDecoderTrack {
  const ProfessionalVideoTransitionDecoderTrack({
    required this.role,
    required this.clipId,
    required this.assetId,
    required this.sourceUri,
    required this.decodeRequestIds,
    required this.sampleCount,
    required this.requiresExactFrameDecode,
    required this.allowThumbnailFallback,
    required this.allowBoundaryFreeze,
    this.sourceProbeReady = true,
    this.videoMimeType = '',
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.videoDurationUs = 0,
    this.videoFrameRate = 0,
    this.requiresContinuousFrameStream = true,
    this.liveDecodeWindowTimelineStartTime,
    this.liveDecodeWindowTimelineEndTime,
    this.liveDecodeWindowSourceStartTime,
    this.liveDecodeWindowSourceEndTime,
    this.liveDecodeWindowDuration = TimelineTime.zero,
    this.liveDecodeSourceWindowDuration = TimelineTime.zero,
    this.liveDecodeCoverageDecodeProbeImplemented = false,
    this.liveDecodeCoverageSourceTimes = const <TimelineTime>[],
    this.liveDecodeCoverageRequestedSampleCount = 0,
    this.liveDecodeCoverageDecodedSampleCount = 0,
    this.liveDecodeCoverageDecodedBufferCount = 0,
    this.liveDecodeWindowReady = false,
    this.liveDecodeStreamProbeImplemented = false,
    this.liveDecodeStreamDecodedFrameCount = 0,
    this.liveDecodeStreamReadableBufferCount = 0,
    this.liveDecodeStreamFirstFrameTime,
    this.liveDecodeStreamLastFrameTime,
    this.liveDecodeStreamMinRequiredFrameCount = 0,
    this.liveDecodeStreamCoverageReady = false,
    this.liveDecodeStreamProbeReason = '',
    this.continuousSampleCoverageReady = false,
    this.liveDecodeCoverageProbeReason = '',
    this.centerSampleSourceTimeMs = 0,
    this.exactFrameDecodeProbeImplemented = true,
    this.sampleDecodeProbeImplemented = true,
    this.requestedSampleCount = 0,
    this.decodedSampleCount = 0,
    this.decodedBufferProbeImplemented = true,
    this.decodedBufferCount = 0,
    this.allSamplesDecodable = true,
    this.allDecodedBuffersReadable = true,
    this.canDecodeCenterFrame = true,
    this.decodedCenterFrameTimeMs = 0,
    this.decodedCenterBufferByteCount = 0,
    this.decodedCenterBufferChecksum = 0,
    this.decodeProbeReason = '',
    this.decodedOutputMimeType = '',
    this.decodedOutputWidth = 0,
    this.decodedOutputHeight = 0,
  });

  final String role;
  final String clipId;
  final String assetId;
  final String sourceUri;
  final List<String> decodeRequestIds;
  final int sampleCount;
  final bool requiresExactFrameDecode;
  final bool allowThumbnailFallback;
  final bool allowBoundaryFreeze;
  final bool sourceProbeReady;
  final String videoMimeType;
  final int videoWidth;
  final int videoHeight;
  final int videoDurationUs;
  final int videoFrameRate;
  final bool requiresContinuousFrameStream;
  final TimelineTime? liveDecodeWindowTimelineStartTime;
  final TimelineTime? liveDecodeWindowTimelineEndTime;
  final TimelineTime? liveDecodeWindowSourceStartTime;
  final TimelineTime? liveDecodeWindowSourceEndTime;
  final TimelineTime liveDecodeWindowDuration;
  final TimelineTime liveDecodeSourceWindowDuration;
  final bool liveDecodeCoverageDecodeProbeImplemented;
  final List<TimelineTime> liveDecodeCoverageSourceTimes;
  final int liveDecodeCoverageRequestedSampleCount;
  final int liveDecodeCoverageDecodedSampleCount;
  final int liveDecodeCoverageDecodedBufferCount;
  final bool liveDecodeWindowReady;
  final bool liveDecodeStreamProbeImplemented;
  final int liveDecodeStreamDecodedFrameCount;
  final int liveDecodeStreamReadableBufferCount;
  final TimelineTime? liveDecodeStreamFirstFrameTime;
  final TimelineTime? liveDecodeStreamLastFrameTime;
  final int liveDecodeStreamMinRequiredFrameCount;
  final bool liveDecodeStreamCoverageReady;
  final String liveDecodeStreamProbeReason;
  final bool continuousSampleCoverageReady;
  final String liveDecodeCoverageProbeReason;
  final int centerSampleSourceTimeMs;
  final bool exactFrameDecodeProbeImplemented;
  final bool sampleDecodeProbeImplemented;
  final int requestedSampleCount;
  final int decodedSampleCount;
  final bool decodedBufferProbeImplemented;
  final int decodedBufferCount;
  final bool allSamplesDecodable;
  final bool allDecodedBuffersReadable;
  final bool canDecodeCenterFrame;
  final int decodedCenterFrameTimeMs;
  final int decodedCenterBufferByteCount;
  final int decodedCenterBufferChecksum;
  final String decodeProbeReason;
  final String decodedOutputMimeType;
  final int decodedOutputWidth;
  final int decodedOutputHeight;
}

@immutable
class ProfessionalVideoTransitionDecoderSessionPlanResult {
  const ProfessionalVideoTransitionDecoderSessionPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.decoderSessionId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.requiresDualVideoDecoder,
    required this.requiresExactFrameDecode,
    required this.requiresContinuousFrameStream,
    required this.allowThumbnailFallback,
    required this.allowBoundaryFreeze,
    required this.decoderImplemented,
    required this.tracks,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionDecoderSessionPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionDecoderSessionPlanResult(
      status:
          ProfessionalVideoTransitionDecoderSessionPlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      decoderSessionId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      requiresDualVideoDecoder: true,
      requiresExactFrameDecode: true,
      requiresContinuousFrameStream: true,
      allowThumbnailFallback: false,
      allowBoundaryFreeze: false,
      decoderImplemented: false,
      tracks: const <ProfessionalVideoTransitionDecoderTrack>[],
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionDecoderSessionPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String decoderSessionId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final bool requiresDualVideoDecoder;
  final bool requiresExactFrameDecode;
  final bool requiresContinuousFrameStream;
  final bool allowThumbnailFallback;
  final bool allowBoundaryFreeze;
  final bool decoderImplemented;
  final List<ProfessionalVideoTransitionDecoderTrack> tracks;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionDecoderSessionPlanStatus.planned;

  bool get canDecode =>
      canPlan &&
      requiresDualVideoDecoder &&
      requiresExactFrameDecode &&
      requiresContinuousFrameStream &&
      !allowThumbnailFallback &&
      !allowBoundaryFreeze &&
      decoderImplemented &&
      tracks.length == 2 &&
      tracks.every((track) {
        return track.sourceProbeReady &&
            track.requiresContinuousFrameStream &&
            track.liveDecodeCoverageDecodeProbeImplemented &&
            track.liveDecodeWindowReady &&
            track.liveDecodeStreamProbeImplemented &&
            track.liveDecodeStreamCoverageReady &&
            track.continuousSampleCoverageReady &&
            track.exactFrameDecodeProbeImplemented &&
            track.sampleDecodeProbeImplemented &&
            track.decodedBufferProbeImplemented &&
            track.canDecodeCenterFrame &&
            track.allSamplesDecodable &&
            track.allDecodedBuffersReadable;
      }) &&
      blockedReasons.isEmpty;
}

class ProfessionalVideoTransitionDecoderSessionPlanResultMapper {
  const ProfessionalVideoTransitionDecoderSessionPlanResultMapper._();

  static ProfessionalVideoTransitionDecoderSessionPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionDecoderSessionPlanResult.invalidRequest(
        reason: 'native_compositor_empty_decoder_session_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionDecoderSessionPlanStatus.planned,
      _ => ProfessionalVideoTransitionDecoderSessionPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionDecoderSessionPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      decoderSessionId: map['decoderSessionId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      requiresDualVideoDecoder: _readBool(
        map['requiresDualVideoDecoder'],
        defaultValue: true,
      ),
      requiresExactFrameDecode: _readBool(
        map['requiresExactFrameDecode'],
        defaultValue: true,
      ),
      requiresContinuousFrameStream: _readBool(
        map['requiresContinuousFrameStream'],
        defaultValue: true,
      ),
      allowThumbnailFallback: _readBool(map['allowThumbnailFallback']),
      allowBoundaryFreeze: _readBool(map['allowBoundaryFreeze']),
      decoderImplemented: _readBool(map['decoderImplemented']),
      tracks: _readTracks(map['tracks']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionDecoderTrack> _readTracks(
    Object? value,
  ) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionDecoderTrack>[];
    }
    return List<ProfessionalVideoTransitionDecoderTrack>.unmodifiable(
      value.whereType<Map>().map((track) {
        return ProfessionalVideoTransitionDecoderTrack(
          role: track['role']?.toString() ?? '',
          clipId: track['clipId']?.toString() ?? '',
          assetId: track['assetId']?.toString() ?? '',
          sourceUri: track['sourceUri']?.toString() ?? '',
          decodeRequestIds: _readStringList(track['decodeRequestIds']),
          sampleCount: _readInt(track['sampleCount']),
          requiresExactFrameDecode: _readBool(
            track['requiresExactFrameDecode'],
            defaultValue: true,
          ),
          allowThumbnailFallback: _readBool(track['allowThumbnailFallback']),
          allowBoundaryFreeze: _readBool(track['allowBoundaryFreeze']),
          sourceProbeReady: _readBool(
            track['sourceProbeReady'],
            defaultValue: true,
          ),
          videoMimeType: track['videoMimeType']?.toString() ?? '',
          videoWidth: _readInt(track['videoWidth']),
          videoHeight: _readInt(track['videoHeight']),
          videoDurationUs: _readInt(track['videoDurationUs']),
          videoFrameRate: _readInt(track['videoFrameRate']),
          requiresContinuousFrameStream: _readBool(
            track['requiresContinuousFrameStream'],
            defaultValue: true,
          ),
          liveDecodeWindowTimelineStartTime:
              _readTimelineTime(track['liveDecodeWindowTimelineStartMs']),
          liveDecodeWindowTimelineEndTime:
              _readTimelineTime(track['liveDecodeWindowTimelineEndMs']),
          liveDecodeWindowSourceStartTime:
              _readTimelineTime(track['liveDecodeWindowSourceStartMs']),
          liveDecodeWindowSourceEndTime:
              _readTimelineTime(track['liveDecodeWindowSourceEndMs']),
          liveDecodeWindowDuration:
              _readTimelineTime(track['liveDecodeWindowDurationMs']) ??
                  TimelineTime.zero,
          liveDecodeSourceWindowDuration:
              _readTimelineTime(track['liveDecodeSourceWindowDurationMs']) ??
                  TimelineTime.zero,
          liveDecodeCoverageDecodeProbeImplemented:
              _readBool(track['liveDecodeCoverageDecodeProbeImplemented']),
          liveDecodeCoverageSourceTimes:
              _readTimelineTimeList(track['liveDecodeCoverageSourceTimesMs']),
          liveDecodeCoverageRequestedSampleCount:
              _readInt(track['liveDecodeCoverageRequestedSampleCount']),
          liveDecodeCoverageDecodedSampleCount:
              _readInt(track['liveDecodeCoverageDecodedSampleCount']),
          liveDecodeCoverageDecodedBufferCount:
              _readInt(track['liveDecodeCoverageDecodedBufferCount']),
          liveDecodeWindowReady: _readBool(track['liveDecodeWindowReady']),
          liveDecodeStreamProbeImplemented:
              _readBool(track['liveDecodeStreamProbeImplemented']),
          liveDecodeStreamDecodedFrameCount:
              _readInt(track['liveDecodeStreamDecodedFrameCount']),
          liveDecodeStreamReadableBufferCount:
              _readInt(track['liveDecodeStreamReadableBufferCount']),
          liveDecodeStreamFirstFrameTime:
              _readTimelineTime(track['liveDecodeStreamFirstFrameTimeMs']),
          liveDecodeStreamLastFrameTime:
              _readTimelineTime(track['liveDecodeStreamLastFrameTimeMs']),
          liveDecodeStreamMinRequiredFrameCount:
              _readInt(track['liveDecodeStreamMinRequiredFrameCount']),
          liveDecodeStreamCoverageReady:
              _readBool(track['liveDecodeStreamCoverageReady']),
          liveDecodeStreamProbeReason:
              track['liveDecodeStreamProbeReason']?.toString() ?? '',
          continuousSampleCoverageReady:
              _readBool(track['continuousSampleCoverageReady']),
          liveDecodeCoverageProbeReason:
              track['liveDecodeCoverageProbeReason']?.toString() ?? '',
          centerSampleSourceTimeMs: _readInt(track['centerSampleSourceTimeMs']),
          exactFrameDecodeProbeImplemented: _readBool(
            track['exactFrameDecodeProbeImplemented'],
            defaultValue: true,
          ),
          sampleDecodeProbeImplemented: _readBool(
            track['sampleDecodeProbeImplemented'],
            defaultValue: true,
          ),
          requestedSampleCount: _readInt(track['requestedSampleCount']),
          decodedSampleCount: _readInt(track['decodedSampleCount']),
          decodedBufferProbeImplemented: _readBool(
            track['decodedBufferProbeImplemented'],
            defaultValue: true,
          ),
          decodedBufferCount: _readInt(
            track['decodedBufferCount'],
            fallback: _readInt(track['decodedSampleCount']),
          ),
          allSamplesDecodable: _readBool(
            track['allSamplesDecodable'],
            defaultValue: true,
          ),
          allDecodedBuffersReadable: _readBool(
            track['allDecodedBuffersReadable'],
            defaultValue: _readBool(
              track['allSamplesDecodable'],
              defaultValue: true,
            ),
          ),
          canDecodeCenterFrame: _readBool(
            track['canDecodeCenterFrame'],
            defaultValue: true,
          ),
          decodedCenterFrameTimeMs: _readInt(track['decodedCenterFrameTimeMs']),
          decodedCenterBufferByteCount:
              _readInt(track['decodedCenterBufferByteCount']),
          decodedCenterBufferChecksum:
              _readInt(track['decodedCenterBufferChecksum']),
          decodeProbeReason: track['decodeProbeReason']?.toString() ?? '',
          decodedOutputMimeType:
              track['decodedOutputMimeType']?.toString() ?? '',
          decodedOutputWidth: _readInt(track['decodedOutputWidth']),
          decodedOutputHeight: _readInt(track['decodedOutputHeight']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static List<TimelineTime> _readTimelineTimeList(Object? value) {
    if (value is! List) {
      return const <TimelineTime>[];
    }
    return List<TimelineTime>.unmodifiable(
      value.map((entry) {
        if (entry is num) {
          return TimelineTime.fromMilliseconds(entry.round());
        }
        return TimelineTime.fromMilliseconds(
          int.tryParse(entry.toString()) ?? 0,
        );
      }),
    );
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionTemporalAccumulatorPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionTemporalAccumulator {
  const ProfessionalVideoTransitionTemporalAccumulator({
    required this.accumulatorId,
    required this.role,
    required this.inputTrackRole,
    required this.sampleCount,
    this.decodedSampleCount = 0,
    this.decodedBufferCount = 0,
    this.inputSamplesDecodable = true,
    this.inputDecodedBuffersReadable = true,
    this.liveDecodeWindowReady = true,
    this.liveDecodeStreamProbeImplemented = true,
    this.liveDecodeStreamDecodedFrameCount = 0,
    this.liveDecodeStreamReadableBufferCount = 0,
    this.liveDecodeStreamCoverageReady = true,
    this.continuousSampleCoverageReady = true,
    required this.sampleWeights,
    required this.normalization,
    required this.requiresTemporalShutter,
    required this.requiresExactFrameDecode,
    required this.allowGaussianFallback,
    required this.allowDecorativeSpeedLines,
  });

  final String accumulatorId;
  final String role;
  final String inputTrackRole;
  final int sampleCount;
  final int decodedSampleCount;
  final int decodedBufferCount;
  final bool inputSamplesDecodable;
  final bool inputDecodedBuffersReadable;
  final bool liveDecodeWindowReady;
  final bool liveDecodeStreamProbeImplemented;
  final int liveDecodeStreamDecodedFrameCount;
  final int liveDecodeStreamReadableBufferCount;
  final bool liveDecodeStreamCoverageReady;
  final bool continuousSampleCoverageReady;
  final List<double> sampleWeights;
  final String normalization;
  final bool requiresTemporalShutter;
  final bool requiresExactFrameDecode;
  final bool allowGaussianFallback;
  final bool allowDecorativeSpeedLines;
}

@immutable
class ProfessionalVideoTransitionTemporalAccumulatorPlanResult {
  const ProfessionalVideoTransitionTemporalAccumulatorPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.decoderSessionId,
    required this.temporalAccumulatorSessionId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.motionBlurMode,
    required this.shutterSampleCount,
    required this.requiresTemporalAccumulation,
    required this.requiresExactFrameDecode,
    required this.allowGaussianFallback,
    required this.allowDecorativeSpeedLines,
    required this.accumulatorImplemented,
    required this.accumulators,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionTemporalAccumulatorPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionTemporalAccumulatorPlanResult(
      status: ProfessionalVideoTransitionTemporalAccumulatorPlanStatus
          .invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      decoderSessionId: '',
      temporalAccumulatorSessionId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      motionBlurMode: '',
      shutterSampleCount: 0,
      requiresTemporalAccumulation: false,
      requiresExactFrameDecode: true,
      allowGaussianFallback: false,
      allowDecorativeSpeedLines: false,
      accumulatorImplemented: false,
      accumulators: const <ProfessionalVideoTransitionTemporalAccumulator>[],
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionTemporalAccumulatorPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String decoderSessionId;
  final String temporalAccumulatorSessionId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final String motionBlurMode;
  final int shutterSampleCount;
  final bool requiresTemporalAccumulation;
  final bool requiresExactFrameDecode;
  final bool allowGaussianFallback;
  final bool allowDecorativeSpeedLines;
  final bool accumulatorImplemented;
  final List<ProfessionalVideoTransitionTemporalAccumulator> accumulators;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status ==
      ProfessionalVideoTransitionTemporalAccumulatorPlanStatus.planned;

  bool get canAccumulate =>
      canPlan &&
      requiresExactFrameDecode &&
      !allowGaussianFallback &&
      !allowDecorativeSpeedLines &&
      accumulatorImplemented &&
      accumulators.length == 2 &&
      accumulators.every((accumulator) {
        return accumulator.requiresExactFrameDecode &&
            accumulator.inputSamplesDecodable &&
            accumulator.inputDecodedBuffersReadable &&
            accumulator.liveDecodeWindowReady &&
            accumulator.liveDecodeStreamProbeImplemented &&
            accumulator.liveDecodeStreamCoverageReady &&
            accumulator.continuousSampleCoverageReady &&
            !accumulator.allowGaussianFallback &&
            !accumulator.allowDecorativeSpeedLines;
      }) &&
      blockedReasons.isEmpty;
}

class ProfessionalVideoTransitionTemporalAccumulatorPlanResultMapper {
  const ProfessionalVideoTransitionTemporalAccumulatorPlanResultMapper._();

  static ProfessionalVideoTransitionTemporalAccumulatorPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionTemporalAccumulatorPlanResult
          .invalidRequest(
        reason: 'native_compositor_empty_temporal_accumulator_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' =>
        ProfessionalVideoTransitionTemporalAccumulatorPlanStatus.planned,
      _ =>
        ProfessionalVideoTransitionTemporalAccumulatorPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionTemporalAccumulatorPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      decoderSessionId: map['decoderSessionId']?.toString() ?? '',
      temporalAccumulatorSessionId:
          map['temporalAccumulatorSessionId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      motionBlurMode: map['motionBlurMode']?.toString() ?? '',
      shutterSampleCount: _readInt(map['shutterSampleCount']),
      requiresTemporalAccumulation:
          _readBool(map['requiresTemporalAccumulation']),
      requiresExactFrameDecode: _readBool(
        map['requiresExactFrameDecode'],
        defaultValue: true,
      ),
      allowGaussianFallback: _readBool(map['allowGaussianFallback']),
      allowDecorativeSpeedLines: _readBool(map['allowDecorativeSpeedLines']),
      accumulatorImplemented: _readBool(map['accumulatorImplemented']),
      accumulators: _readAccumulators(map['accumulators']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionTemporalAccumulator> _readAccumulators(
      Object? value) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionTemporalAccumulator>[];
    }
    return List<ProfessionalVideoTransitionTemporalAccumulator>.unmodifiable(
      value.whereType<Map>().map((accumulator) {
        return ProfessionalVideoTransitionTemporalAccumulator(
          accumulatorId: accumulator['accumulatorId']?.toString() ?? '',
          role: accumulator['role']?.toString() ?? '',
          inputTrackRole: accumulator['inputTrackRole']?.toString() ?? '',
          sampleCount: _readInt(accumulator['sampleCount']),
          decodedSampleCount: _readInt(accumulator['decodedSampleCount']),
          inputSamplesDecodable: _readBool(
            accumulator['inputSamplesDecodable'],
            defaultValue: true,
          ),
          decodedBufferCount: _readInt(
            accumulator['decodedBufferCount'],
            fallback: _readInt(accumulator['decodedSampleCount']),
          ),
          inputDecodedBuffersReadable: _readBool(
            accumulator['inputDecodedBuffersReadable'],
            defaultValue: _readBool(
              accumulator['inputSamplesDecodable'],
              defaultValue: true,
            ),
          ),
          liveDecodeWindowReady: _readBool(
            accumulator['liveDecodeWindowReady'],
            defaultValue: true,
          ),
          liveDecodeStreamProbeImplemented: _readBool(
            accumulator['liveDecodeStreamProbeImplemented'],
            defaultValue: true,
          ),
          liveDecodeStreamDecodedFrameCount:
              _readInt(accumulator['liveDecodeStreamDecodedFrameCount']),
          liveDecodeStreamReadableBufferCount:
              _readInt(accumulator['liveDecodeStreamReadableBufferCount']),
          liveDecodeStreamCoverageReady: _readBool(
            accumulator['liveDecodeStreamCoverageReady'],
            defaultValue: true,
          ),
          continuousSampleCoverageReady: _readBool(
            accumulator['continuousSampleCoverageReady'],
            defaultValue: true,
          ),
          sampleWeights: _readDoubleList(accumulator['sampleWeights']),
          normalization: accumulator['normalization']?.toString() ?? '',
          requiresTemporalShutter:
              _readBool(accumulator['requiresTemporalShutter']),
          requiresExactFrameDecode: _readBool(
            accumulator['requiresExactFrameDecode'],
            defaultValue: true,
          ),
          allowGaussianFallback:
              _readBool(accumulator['allowGaussianFallback']),
          allowDecorativeSpeedLines:
              _readBool(accumulator['allowDecorativeSpeedLines']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<double> _readDoubleList(Object? value) {
    if (value is! List) {
      return const <double>[];
    }
    return List<double>.unmodifiable(
      value.map((entry) {
        if (entry is num) {
          return entry.toDouble();
        }
        return double.tryParse(entry.toString()) ?? 0;
      }),
    );
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionMirrorEdgeTilingPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionMirrorEdgeTile {
  const ProfessionalVideoTransitionMirrorEdgeTile({
    required this.tileId,
    required this.role,
    required this.inputAccumulatorId,
    this.sampleCount = 0,
    this.decodedSampleCount = 0,
    this.inputSamplesDecodable = true,
    this.liveDecodeStreamCoverageReady = true,
    this.continuousSampleCoverageReady = true,
    required this.edgeMode,
    required this.outputScaleX,
    required this.outputScaleY,
    required this.mirrorEdges,
    required this.clipToCanvas,
    required this.allowBlackBorders,
  });

  final String tileId;
  final String role;
  final String inputAccumulatorId;
  final int sampleCount;
  final int decodedSampleCount;
  final bool inputSamplesDecodable;
  final bool liveDecodeStreamCoverageReady;
  final bool continuousSampleCoverageReady;
  final String edgeMode;
  final double outputScaleX;
  final double outputScaleY;
  final bool mirrorEdges;
  final bool clipToCanvas;
  final bool allowBlackBorders;
}

@immutable
class ProfessionalVideoTransitionMirrorEdgeTilingPlanResult {
  const ProfessionalVideoTransitionMirrorEdgeTilingPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.temporalAccumulatorSessionId,
    required this.mirrorEdgeTilingSessionId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.edgeMode,
    required this.outputScaleX,
    required this.outputScaleY,
    required this.requiresMirrorEdgeTiling,
    required this.requiresTemporalAccumulator,
    required this.allowBlackBorders,
    required this.allowFlutterOverlay,
    required this.allowTimelineOverlay,
    required this.tilerImplemented,
    required this.tiles,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionMirrorEdgeTilingPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionMirrorEdgeTilingPlanResult(
      status:
          ProfessionalVideoTransitionMirrorEdgeTilingPlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      temporalAccumulatorSessionId: '',
      mirrorEdgeTilingSessionId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      edgeMode: '',
      outputScaleX: 1,
      outputScaleY: 1,
      requiresMirrorEdgeTiling: false,
      requiresTemporalAccumulator: true,
      allowBlackBorders: false,
      allowFlutterOverlay: false,
      allowTimelineOverlay: false,
      tilerImplemented: false,
      tiles: const <ProfessionalVideoTransitionMirrorEdgeTile>[],
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionMirrorEdgeTilingPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String temporalAccumulatorSessionId;
  final String mirrorEdgeTilingSessionId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final String edgeMode;
  final double outputScaleX;
  final double outputScaleY;
  final bool requiresMirrorEdgeTiling;
  final bool requiresTemporalAccumulator;
  final bool allowBlackBorders;
  final bool allowFlutterOverlay;
  final bool allowTimelineOverlay;
  final bool tilerImplemented;
  final List<ProfessionalVideoTransitionMirrorEdgeTile> tiles;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionMirrorEdgeTilingPlanStatus.planned;

  bool get canTile =>
      canPlan &&
      requiresTemporalAccumulator &&
      !allowBlackBorders &&
      !allowFlutterOverlay &&
      !allowTimelineOverlay &&
      tilerImplemented &&
      tiles.length == 2 &&
      tiles.every((tile) {
        return tile.inputSamplesDecodable &&
            tile.liveDecodeStreamCoverageReady &&
            tile.continuousSampleCoverageReady &&
            !tile.allowBlackBorders &&
            tile.clipToCanvas;
      }) &&
      blockedReasons.isEmpty;
}

class ProfessionalVideoTransitionMirrorEdgeTilingPlanResultMapper {
  const ProfessionalVideoTransitionMirrorEdgeTilingPlanResultMapper._();

  static ProfessionalVideoTransitionMirrorEdgeTilingPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionMirrorEdgeTilingPlanResult
          .invalidRequest(
        reason: 'native_compositor_empty_mirror_edge_tiling_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' =>
        ProfessionalVideoTransitionMirrorEdgeTilingPlanStatus.planned,
      _ => ProfessionalVideoTransitionMirrorEdgeTilingPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionMirrorEdgeTilingPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      temporalAccumulatorSessionId:
          map['temporalAccumulatorSessionId']?.toString() ?? '',
      mirrorEdgeTilingSessionId:
          map['mirrorEdgeTilingSessionId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      edgeMode: map['edgeMode']?.toString() ?? '',
      outputScaleX: _readDouble(map['outputScaleX'], defaultValue: 1),
      outputScaleY: _readDouble(map['outputScaleY'], defaultValue: 1),
      requiresMirrorEdgeTiling: _readBool(map['requiresMirrorEdgeTiling']),
      requiresTemporalAccumulator: _readBool(
        map['requiresTemporalAccumulator'],
        defaultValue: true,
      ),
      allowBlackBorders: _readBool(map['allowBlackBorders']),
      allowFlutterOverlay: _readBool(map['allowFlutterOverlay']),
      allowTimelineOverlay: _readBool(map['allowTimelineOverlay']),
      tilerImplemented: _readBool(map['tilerImplemented']),
      tiles: _readTiles(map['tiles']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionMirrorEdgeTile> _readTiles(
    Object? value,
  ) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionMirrorEdgeTile>[];
    }
    return List<ProfessionalVideoTransitionMirrorEdgeTile>.unmodifiable(
      value.whereType<Map>().map((tile) {
        return ProfessionalVideoTransitionMirrorEdgeTile(
          tileId: tile['tileId']?.toString() ?? '',
          role: tile['role']?.toString() ?? '',
          inputAccumulatorId: tile['inputAccumulatorId']?.toString() ?? '',
          sampleCount: _readInt(tile['sampleCount']),
          decodedSampleCount: _readInt(tile['decodedSampleCount']),
          inputSamplesDecodable: _readBool(
            tile['inputSamplesDecodable'],
            defaultValue: true,
          ),
          liveDecodeStreamCoverageReady: _readBool(
            tile['liveDecodeStreamCoverageReady'],
            defaultValue: true,
          ),
          continuousSampleCoverageReady: _readBool(
            tile['continuousSampleCoverageReady'],
            defaultValue: true,
          ),
          edgeMode: tile['edgeMode']?.toString() ?? '',
          outputScaleX: _readDouble(tile['outputScaleX'], defaultValue: 1),
          outputScaleY: _readDouble(tile['outputScaleY'], defaultValue: 1),
          mirrorEdges: _readBool(tile['mirrorEdges']),
          clipToCanvas: _readBool(tile['clipToCanvas'], defaultValue: true),
          allowBlackBorders: _readBool(tile['allowBlackBorders']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static double _readDouble(Object? value, {double defaultValue = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionRenderPassGraphPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionRenderPassNode {
  const ProfessionalVideoTransitionRenderPassNode({
    required this.passId,
    required this.type,
    required this.role,
    required this.inputs,
    required this.parameters,
  });

  final String passId;
  final String type;
  final String role;
  final List<String> inputs;
  final Map<String, Object?> parameters;
}

@immutable
class ProfessionalVideoTransitionRenderPassGraphPlanResult {
  const ProfessionalVideoTransitionRenderPassGraphPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.renderPassGraphId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.progress,
    required this.requiresExactVideoDecode,
    required this.requiresTemporalAccumulation,
    required this.requiresMirrorEdgeTiling,
    required this.requiresGpuComposition,
    required this.rendererInputsReady,
    required this.rendererImplemented,
    required this.passes,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionRenderPassGraphPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionRenderPassGraphPlanResult(
      status:
          ProfessionalVideoTransitionRenderPassGraphPlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      renderPassGraphId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      progress: 0,
      requiresExactVideoDecode: true,
      requiresTemporalAccumulation: false,
      requiresMirrorEdgeTiling: false,
      requiresGpuComposition: true,
      rendererInputsReady: false,
      rendererImplemented: false,
      passes: const <ProfessionalVideoTransitionRenderPassNode>[],
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionRenderPassGraphPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String renderPassGraphId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final double progress;
  final bool requiresExactVideoDecode;
  final bool requiresTemporalAccumulation;
  final bool requiresMirrorEdgeTiling;
  final bool requiresGpuComposition;
  final bool rendererInputsReady;
  final bool rendererImplemented;
  final List<ProfessionalVideoTransitionRenderPassNode> passes;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionRenderPassGraphPlanStatus.planned;

  bool get canRender =>
      canPlan &&
      rendererInputsReady &&
      rendererImplemented &&
      blockedReasons.isEmpty;
}

class ProfessionalVideoTransitionRenderPassGraphPlanResultMapper {
  const ProfessionalVideoTransitionRenderPassGraphPlanResultMapper._();

  static ProfessionalVideoTransitionRenderPassGraphPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionRenderPassGraphPlanResult
          .invalidRequest(
        reason: 'native_compositor_empty_render_pass_graph_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionRenderPassGraphPlanStatus.planned,
      _ => ProfessionalVideoTransitionRenderPassGraphPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionRenderPassGraphPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      renderPassGraphId: map['renderPassGraphId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      progress: _readDouble(map['progress']),
      requiresExactVideoDecode: _readBool(
        map['requiresExactVideoDecode'],
        defaultValue: true,
      ),
      requiresTemporalAccumulation:
          _readBool(map['requiresTemporalAccumulation']),
      requiresMirrorEdgeTiling: _readBool(map['requiresMirrorEdgeTiling']),
      requiresGpuComposition: _readBool(
        map['requiresGpuComposition'],
        defaultValue: true,
      ),
      rendererInputsReady: _readBool(map['rendererInputsReady']),
      rendererImplemented: _readBool(map['rendererImplemented']),
      passes: _readPasses(map['passes']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionRenderPassNode> _readPasses(
    Object? value,
  ) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionRenderPassNode>[];
    }
    return List<ProfessionalVideoTransitionRenderPassNode>.unmodifiable(
      value.whereType<Map>().map((pass) {
        return ProfessionalVideoTransitionRenderPassNode(
          passId: pass['passId']?.toString() ?? '',
          type: pass['type']?.toString() ?? '',
          role: pass['role']?.toString() ?? '',
          inputs: _readStringList(pass['inputs']),
          parameters: _readObjectMap(pass['parameters']),
        );
      }),
    );
  }

  static Map<String, Object?> _readObjectMap(Object? value) {
    if (value is! Map) {
      return const <String, Object?>{};
    }
    return Map<String, Object?>.unmodifiable(
      <String, Object?>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      },
    );
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum ProfessionalVideoTransitionOutputSurfacePlanStatus {
  planned,
  invalidRequest,
}

enum ProfessionalVideoTransitionRenderGraphExecutionPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionRenderGraphPassExecutionState {
  const ProfessionalVideoTransitionRenderGraphPassExecutionState({
    required this.passId,
    required this.type,
    required this.role,
    required this.index,
    required this.inputs,
    required this.readyForExecutor,
    required this.blockedReasons,
  });

  final String passId;
  final String type;
  final String role;
  final int index;
  final List<String> inputs;
  final bool readyForExecutor;
  final List<String> blockedReasons;
}

@immutable
class ProfessionalVideoTransitionRenderGraphExecutionPlanResult {
  const ProfessionalVideoTransitionRenderGraphExecutionPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.renderPassGraphId,
    required this.renderGraphExecutorId,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.requiredPassTypes,
    required this.executionOrder,
    required this.passExecutionStates,
    required this.graphExecutorImplemented,
    required this.rendererImplemented,
    required this.graphOrderValid,
    required this.graphDependenciesValid,
    required this.graphOwnershipReady,
    required this.canExecuteGraph,
    required this.drawsPixels,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionRenderGraphExecutionPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionRenderGraphExecutionPlanResult(
      status: ProfessionalVideoTransitionRenderGraphExecutionPlanStatus
          .invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      renderPassGraphId: '',
      renderGraphExecutorId: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      requiredPassTypes: const <String>[],
      executionOrder: const <String>[],
      passExecutionStates: const <ProfessionalVideoTransitionRenderGraphPassExecutionState>[],
      graphExecutorImplemented: false,
      rendererImplemented: false,
      graphOrderValid: false,
      graphDependenciesValid: false,
      graphOwnershipReady: false,
      canExecuteGraph: false,
      drawsPixels: false,
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionRenderGraphExecutionPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String renderPassGraphId;
  final String renderGraphExecutorId;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final List<String> requiredPassTypes;
  final List<String> executionOrder;
  final List<ProfessionalVideoTransitionRenderGraphPassExecutionState>
      passExecutionStates;
  final bool graphExecutorImplemented;
  final bool rendererImplemented;
  final bool graphOrderValid;
  final bool graphDependenciesValid;
  final bool graphOwnershipReady;
  final bool canExecuteGraph;
  final bool drawsPixels;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status ==
      ProfessionalVideoTransitionRenderGraphExecutionPlanStatus.planned;

  bool get canOwnGraph =>
      canPlan &&
      graphExecutorImplemented &&
      graphOrderValid &&
      graphDependenciesValid &&
      graphOwnershipReady;
}

class ProfessionalVideoTransitionRenderGraphExecutionPlanResultMapper {
  const ProfessionalVideoTransitionRenderGraphExecutionPlanResultMapper._();

  static ProfessionalVideoTransitionRenderGraphExecutionPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionRenderGraphExecutionPlanResult
          .invalidRequest(
        reason: 'native_compositor_empty_render_graph_execution_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' =>
        ProfessionalVideoTransitionRenderGraphExecutionPlanStatus.planned,
      _ => ProfessionalVideoTransitionRenderGraphExecutionPlanStatus
          .invalidRequest,
    };
    return ProfessionalVideoTransitionRenderGraphExecutionPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      renderPassGraphId: map['renderPassGraphId']?.toString() ?? '',
      renderGraphExecutorId: map['renderGraphExecutorId']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      requiredPassTypes: _readStringList(map['requiredPassTypes']),
      executionOrder: _readStringList(map['executionOrder']),
      passExecutionStates: _readPassExecutionStates(
        map['passExecutionStates'],
      ),
      graphExecutorImplemented: _readBool(map['graphExecutorImplemented']),
      rendererImplemented: _readBool(map['rendererImplemented']),
      graphOrderValid: _readBool(map['graphOrderValid']),
      graphDependenciesValid: _readBool(map['graphDependenciesValid']),
      graphOwnershipReady: _readBool(map['graphOwnershipReady']),
      canExecuteGraph: _readBool(map['canExecuteGraph']),
      drawsPixels: _readBool(map['drawsPixels']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionRenderGraphPassExecutionState>
      _readPassExecutionStates(Object? value) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionRenderGraphPassExecutionState>[];
    }
    return List<
        ProfessionalVideoTransitionRenderGraphPassExecutionState>.unmodifiable(
      value.whereType<Map>().map((state) {
        return ProfessionalVideoTransitionRenderGraphPassExecutionState(
          passId: state['passId']?.toString() ?? '',
          type: state['type']?.toString() ?? '',
          role: state['role']?.toString() ?? '',
          index: _readInt(state['index']),
          inputs: _readStringList(state['inputs']),
          readyForExecutor: _readBool(state['readyForExecutor']),
          blockedReasons: _readStringList(state['blockedReasons']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

@immutable
class ProfessionalVideoTransitionOutputSurfacePlanResult {
  const ProfessionalVideoTransitionOutputSurfacePlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.renderPassGraphId,
    required this.outputSurfaceId,
    required this.outputTarget,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.clipToCanvas,
    required this.requiresNativeTexture,
    required this.allowFlutterOverlay,
    required this.allowTimelineOverlay,
    required this.allowPlatformViewTransform,
    required this.renderPassCount,
    required this.outputPassId,
    required this.outputPassType,
    required this.outputPassInputs,
    required this.outputPassBound,
    required this.renderGraphOutputReady,
    required this.rendererImplemented,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionOutputSurfacePlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionOutputSurfacePlanResult(
      status: ProfessionalVideoTransitionOutputSurfacePlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      renderPassGraphId: '',
      outputSurfaceId: '',
      outputTarget: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      canvasWidth: 0,
      canvasHeight: 0,
      clipToCanvas: true,
      requiresNativeTexture: true,
      allowFlutterOverlay: false,
      allowTimelineOverlay: false,
      allowPlatformViewTransform: false,
      renderPassCount: 0,
      outputPassId: '',
      outputPassType: '',
      outputPassInputs: const <String>[],
      outputPassBound: false,
      renderGraphOutputReady: false,
      rendererImplemented: false,
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionOutputSurfacePlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String renderPassGraphId;
  final String outputSurfaceId;
  final String outputTarget;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final int canvasWidth;
  final int canvasHeight;
  final bool clipToCanvas;
  final bool requiresNativeTexture;
  final bool allowFlutterOverlay;
  final bool allowTimelineOverlay;
  final bool allowPlatformViewTransform;
  final int renderPassCount;
  final String outputPassId;
  final String outputPassType;
  final List<String> outputPassInputs;
  final bool outputPassBound;
  final bool renderGraphOutputReady;
  final bool rendererImplemented;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionOutputSurfacePlanStatus.planned;

  bool get canRender =>
      canPlan &&
      rendererImplemented &&
      clipToCanvas &&
      requiresNativeTexture &&
      !allowFlutterOverlay &&
      !allowTimelineOverlay &&
      !allowPlatformViewTransform &&
      outputPassBound &&
      renderGraphOutputReady &&
      blockedReasons.isEmpty;
}

class ProfessionalVideoTransitionOutputSurfacePlanResultMapper {
  const ProfessionalVideoTransitionOutputSurfacePlanResultMapper._();

  static ProfessionalVideoTransitionOutputSurfacePlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionOutputSurfacePlanResult.invalidRequest(
        reason: 'native_compositor_empty_output_surface_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionOutputSurfacePlanStatus.planned,
      _ => ProfessionalVideoTransitionOutputSurfacePlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionOutputSurfacePlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      renderPassGraphId: map['renderPassGraphId']?.toString() ?? '',
      outputSurfaceId: map['outputSurfaceId']?.toString() ?? '',
      outputTarget: map['outputTarget']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      canvasWidth: _readInt(map['canvasWidth']),
      canvasHeight: _readInt(map['canvasHeight']),
      clipToCanvas: _readBool(map['clipToCanvas'], defaultValue: true),
      requiresNativeTexture:
          _readBool(map['requiresNativeTexture'], defaultValue: true),
      allowFlutterOverlay: _readBool(map['allowFlutterOverlay']),
      allowTimelineOverlay: _readBool(map['allowTimelineOverlay']),
      allowPlatformViewTransform: _readBool(map['allowPlatformViewTransform']),
      renderPassCount: _readInt(map['renderPassCount']),
      outputPassId: map['outputPassId']?.toString() ?? '',
      outputPassType: map['outputPassType']?.toString() ?? '',
      outputPassInputs: _readStringList(map['outputPassInputs']),
      outputPassBound: _readBool(map['outputPassBound']),
      renderGraphOutputReady: _readBool(map['renderGraphOutputReady']),
      rendererImplemented: _readBool(map['rendererImplemented']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionSurfaceRendererPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionSurfaceRendererPlanResult {
  const ProfessionalVideoTransitionSurfaceRendererPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.renderPassGraphId,
    required this.renderGraphExecutorId,
    required this.surfaceRendererId,
    required this.outputSurfaceId,
    required this.outputTarget,
    required this.outputPassId,
    required this.outputPassType,
    required this.outputPassInputs,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.clipToCanvas,
    required this.requiresNativeTexture,
    required this.graphExecutorImplemented,
    required this.graphOwnershipReady,
    required this.surfaceRendererImplemented,
    required this.rendererImplemented,
    required this.outputSurfaceAttached,
    required this.outputPassBound,
    required this.renderGraphOutputReady,
    required this.rendersRealPixels,
    required this.drawsPixels,
    required this.canRenderSurface,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionSurfaceRendererPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionSurfaceRendererPlanResult(
      status:
          ProfessionalVideoTransitionSurfaceRendererPlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      renderPassGraphId: '',
      renderGraphExecutorId: '',
      surfaceRendererId: '',
      outputSurfaceId: '',
      outputTarget: '',
      outputPassId: '',
      outputPassType: '',
      outputPassInputs: const <String>[],
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      canvasWidth: 0,
      canvasHeight: 0,
      clipToCanvas: true,
      requiresNativeTexture: true,
      graphExecutorImplemented: false,
      graphOwnershipReady: false,
      surfaceRendererImplemented: false,
      rendererImplemented: false,
      outputSurfaceAttached: false,
      outputPassBound: false,
      renderGraphOutputReady: false,
      rendersRealPixels: false,
      drawsPixels: false,
      canRenderSurface: false,
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionSurfaceRendererPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String renderPassGraphId;
  final String renderGraphExecutorId;
  final String surfaceRendererId;
  final String outputSurfaceId;
  final String outputTarget;
  final String outputPassId;
  final String outputPassType;
  final List<String> outputPassInputs;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final int canvasWidth;
  final int canvasHeight;
  final bool clipToCanvas;
  final bool requiresNativeTexture;
  final bool graphExecutorImplemented;
  final bool graphOwnershipReady;
  final bool surfaceRendererImplemented;
  final bool rendererImplemented;
  final bool outputSurfaceAttached;
  final bool outputPassBound;
  final bool renderGraphOutputReady;
  final bool rendersRealPixels;
  final bool drawsPixels;
  final bool canRenderSurface;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionSurfaceRendererPlanStatus.planned;

  bool get canAttachSurface =>
      canPlan &&
      graphExecutorImplemented &&
      graphOwnershipReady &&
      surfaceRendererImplemented &&
      outputSurfaceAttached &&
      outputPassBound;
}

class ProfessionalVideoTransitionSurfaceRendererPlanResultMapper {
  const ProfessionalVideoTransitionSurfaceRendererPlanResultMapper._();

  static ProfessionalVideoTransitionSurfaceRendererPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionSurfaceRendererPlanResult
          .invalidRequest(
        reason: 'native_compositor_empty_surface_renderer_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionSurfaceRendererPlanStatus.planned,
      _ => ProfessionalVideoTransitionSurfaceRendererPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionSurfaceRendererPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      renderPassGraphId: map['renderPassGraphId']?.toString() ?? '',
      renderGraphExecutorId: map['renderGraphExecutorId']?.toString() ?? '',
      surfaceRendererId: map['surfaceRendererId']?.toString() ?? '',
      outputSurfaceId: map['outputSurfaceId']?.toString() ?? '',
      outputTarget: map['outputTarget']?.toString() ?? '',
      outputPassId: map['outputPassId']?.toString() ?? '',
      outputPassType: map['outputPassType']?.toString() ?? '',
      outputPassInputs: _readStringList(map['outputPassInputs']),
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      canvasWidth: _readInt(map['canvasWidth']),
      canvasHeight: _readInt(map['canvasHeight']),
      clipToCanvas: _readBool(map['clipToCanvas'], defaultValue: true),
      requiresNativeTexture:
          _readBool(map['requiresNativeTexture'], defaultValue: true),
      graphExecutorImplemented: _readBool(map['graphExecutorImplemented']),
      graphOwnershipReady: _readBool(map['graphOwnershipReady']),
      surfaceRendererImplemented: _readBool(map['surfaceRendererImplemented']),
      rendererImplemented: _readBool(map['rendererImplemented']),
      outputSurfaceAttached: _readBool(map['outputSurfaceAttached']),
      outputPassBound: _readBool(map['outputPassBound']),
      renderGraphOutputReady: _readBool(map['renderGraphOutputReady']),
      rendersRealPixels: _readBool(map['rendersRealPixels']),
      drawsPixels: _readBool(map['drawsPixels']),
      canRenderSurface: _readBool(map['canRenderSurface']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionFrameRenderCommandPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionFrameRenderCommand {
  const ProfessionalVideoTransitionFrameRenderCommand({
    required this.commandId,
    required this.passId,
    required this.passType,
    required this.role,
    required this.index,
    required this.inputPassIds,
    required this.outputTarget,
    required this.writesToOutputSurface,
    required this.requiresRealPixels,
    required this.readyForRenderer,
    required this.blockedReasons,
  });

  final String commandId;
  final String passId;
  final String passType;
  final String role;
  final int index;
  final List<String> inputPassIds;
  final String outputTarget;
  final bool writesToOutputSurface;
  final bool requiresRealPixels;
  final bool readyForRenderer;
  final List<String> blockedReasons;
}

@immutable
class ProfessionalVideoTransitionFrameRenderCommandPlanResult {
  const ProfessionalVideoTransitionFrameRenderCommandPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.renderPassGraphId,
    required this.renderGraphExecutorId,
    required this.surfaceRendererId,
    required this.frameRenderCommandBufferId,
    required this.outputSurfaceId,
    required this.outputTarget,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.surfaceRendererImplemented,
    required this.rendererCommandBufferImplemented,
    required this.rendererImplemented,
    required this.graphOwnershipReady,
    required this.outputSurfaceAttached,
    required this.outputPassBound,
    required this.renderGraphOutputReady,
    required this.commandGraphComplete,
    required this.commandBufferReady,
    required this.commandCount,
    required this.commands,
    required this.rendersRealPixels,
    required this.drawsPixels,
    required this.canSubmitCommands,
    required this.canRenderFrame,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionFrameRenderCommandPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionFrameRenderCommandPlanResult(
      status: ProfessionalVideoTransitionFrameRenderCommandPlanStatus
          .invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      renderPassGraphId: '',
      renderGraphExecutorId: '',
      surfaceRendererId: '',
      frameRenderCommandBufferId: '',
      outputSurfaceId: '',
      outputTarget: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      canvasWidth: 0,
      canvasHeight: 0,
      surfaceRendererImplemented: false,
      rendererCommandBufferImplemented: false,
      rendererImplemented: false,
      graphOwnershipReady: false,
      outputSurfaceAttached: false,
      outputPassBound: false,
      renderGraphOutputReady: false,
      commandGraphComplete: false,
      commandBufferReady: false,
      commandCount: 0,
      commands: const <ProfessionalVideoTransitionFrameRenderCommand>[],
      rendersRealPixels: false,
      drawsPixels: false,
      canSubmitCommands: false,
      canRenderFrame: false,
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionFrameRenderCommandPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String renderPassGraphId;
  final String renderGraphExecutorId;
  final String surfaceRendererId;
  final String frameRenderCommandBufferId;
  final String outputSurfaceId;
  final String outputTarget;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final int canvasWidth;
  final int canvasHeight;
  final bool surfaceRendererImplemented;
  final bool rendererCommandBufferImplemented;
  final bool rendererImplemented;
  final bool graphOwnershipReady;
  final bool outputSurfaceAttached;
  final bool outputPassBound;
  final bool renderGraphOutputReady;
  final bool commandGraphComplete;
  final bool commandBufferReady;
  final int commandCount;
  final List<ProfessionalVideoTransitionFrameRenderCommand> commands;
  final bool rendersRealPixels;
  final bool drawsPixels;
  final bool canSubmitCommands;
  final bool canRenderFrame;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionFrameRenderCommandPlanStatus.planned;
}

class ProfessionalVideoTransitionFrameRenderCommandPlanResultMapper {
  const ProfessionalVideoTransitionFrameRenderCommandPlanResultMapper._();

  static ProfessionalVideoTransitionFrameRenderCommandPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionFrameRenderCommandPlanResult
          .invalidRequest(
        reason: 'native_compositor_empty_frame_render_command_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' =>
        ProfessionalVideoTransitionFrameRenderCommandPlanStatus.planned,
      _ =>
        ProfessionalVideoTransitionFrameRenderCommandPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionFrameRenderCommandPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      renderPassGraphId: map['renderPassGraphId']?.toString() ?? '',
      renderGraphExecutorId: map['renderGraphExecutorId']?.toString() ?? '',
      surfaceRendererId: map['surfaceRendererId']?.toString() ?? '',
      frameRenderCommandBufferId:
          map['frameRenderCommandBufferId']?.toString() ?? '',
      outputSurfaceId: map['outputSurfaceId']?.toString() ?? '',
      outputTarget: map['outputTarget']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      canvasWidth: _readInt(map['canvasWidth']),
      canvasHeight: _readInt(map['canvasHeight']),
      surfaceRendererImplemented: _readBool(map['surfaceRendererImplemented']),
      rendererCommandBufferImplemented:
          _readBool(map['rendererCommandBufferImplemented']),
      rendererImplemented: _readBool(map['rendererImplemented']),
      graphOwnershipReady: _readBool(map['graphOwnershipReady']),
      outputSurfaceAttached: _readBool(map['outputSurfaceAttached']),
      outputPassBound: _readBool(map['outputPassBound']),
      renderGraphOutputReady: _readBool(map['renderGraphOutputReady']),
      commandGraphComplete: _readBool(map['commandGraphComplete']),
      commandBufferReady: _readBool(map['commandBufferReady']),
      commandCount: _readInt(map['commandCount']),
      commands: _readCommands(map['commands']),
      rendersRealPixels: _readBool(map['rendersRealPixels']),
      drawsPixels: _readBool(map['drawsPixels']),
      canSubmitCommands: _readBool(map['canSubmitCommands']),
      canRenderFrame: _readBool(map['canRenderFrame']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionFrameRenderCommand> _readCommands(
    Object? value,
  ) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionFrameRenderCommand>[];
    }
    return List<ProfessionalVideoTransitionFrameRenderCommand>.unmodifiable(
      value.whereType<Map>().map((command) {
        return ProfessionalVideoTransitionFrameRenderCommand(
          commandId: command['commandId']?.toString() ?? '',
          passId: command['passId']?.toString() ?? '',
          passType: command['passType']?.toString() ?? '',
          role: command['role']?.toString() ?? '',
          index: _readInt(command['index']),
          inputPassIds: _readStringList(command['inputPassIds']),
          outputTarget: command['outputTarget']?.toString() ?? '',
          writesToOutputSurface: _readBool(command['writesToOutputSurface']),
          requiresRealPixels: _readBool(command['requiresRealPixels']),
          readyForRenderer: _readBool(command['readyForRenderer']),
          blockedReasons: _readStringList(command['blockedReasons']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionRendererBackendPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionRendererBackendPlanResult {
  const ProfessionalVideoTransitionRendererBackendPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.renderPassGraphId,
    required this.renderGraphExecutorId,
    required this.surfaceRendererId,
    required this.frameRenderCommandBufferId,
    required this.rendererBackendId,
    required this.outputSurfaceId,
    required this.outputTarget,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.rendererBackendImplemented,
    required this.gpuContextAvailable,
    required this.nativeSurfaceRequired,
    required this.commandBufferReady,
    required this.outputSurfaceAttached,
    required this.backendReady,
    required this.drawLoopImplemented,
    required this.rendererImplemented,
    required this.rendersRealPixels,
    required this.drawsPixels,
    required this.canSubmitCommands,
    required this.canRenderFrame,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionRendererBackendPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionRendererBackendPlanResult(
      status:
          ProfessionalVideoTransitionRendererBackendPlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      renderPassGraphId: '',
      renderGraphExecutorId: '',
      surfaceRendererId: '',
      frameRenderCommandBufferId: '',
      rendererBackendId: '',
      outputSurfaceId: '',
      outputTarget: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      canvasWidth: 0,
      canvasHeight: 0,
      rendererBackendImplemented: false,
      gpuContextAvailable: false,
      nativeSurfaceRequired: true,
      commandBufferReady: false,
      outputSurfaceAttached: false,
      backendReady: false,
      drawLoopImplemented: false,
      rendererImplemented: false,
      rendersRealPixels: false,
      drawsPixels: false,
      canSubmitCommands: false,
      canRenderFrame: false,
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionRendererBackendPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String renderPassGraphId;
  final String renderGraphExecutorId;
  final String surfaceRendererId;
  final String frameRenderCommandBufferId;
  final String rendererBackendId;
  final String outputSurfaceId;
  final String outputTarget;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final int canvasWidth;
  final int canvasHeight;
  final bool rendererBackendImplemented;
  final bool gpuContextAvailable;
  final bool nativeSurfaceRequired;
  final bool commandBufferReady;
  final bool outputSurfaceAttached;
  final bool backendReady;
  final bool drawLoopImplemented;
  final bool rendererImplemented;
  final bool rendersRealPixels;
  final bool drawsPixels;
  final bool canSubmitCommands;
  final bool canRenderFrame;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionRendererBackendPlanStatus.planned;
}

class ProfessionalVideoTransitionRendererBackendPlanResultMapper {
  const ProfessionalVideoTransitionRendererBackendPlanResultMapper._();

  static ProfessionalVideoTransitionRendererBackendPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionRendererBackendPlanResult
          .invalidRequest(
        reason: 'native_compositor_empty_renderer_backend_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionRendererBackendPlanStatus.planned,
      _ => ProfessionalVideoTransitionRendererBackendPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionRendererBackendPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      renderPassGraphId: map['renderPassGraphId']?.toString() ?? '',
      renderGraphExecutorId: map['renderGraphExecutorId']?.toString() ?? '',
      surfaceRendererId: map['surfaceRendererId']?.toString() ?? '',
      frameRenderCommandBufferId:
          map['frameRenderCommandBufferId']?.toString() ?? '',
      rendererBackendId: map['rendererBackendId']?.toString() ?? '',
      outputSurfaceId: map['outputSurfaceId']?.toString() ?? '',
      outputTarget: map['outputTarget']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      canvasWidth: _readInt(map['canvasWidth']),
      canvasHeight: _readInt(map['canvasHeight']),
      rendererBackendImplemented: _readBool(map['rendererBackendImplemented']),
      gpuContextAvailable: _readBool(map['gpuContextAvailable']),
      nativeSurfaceRequired:
          _readBool(map['nativeSurfaceRequired'], defaultValue: true),
      commandBufferReady: _readBool(map['commandBufferReady']),
      outputSurfaceAttached: _readBool(map['outputSurfaceAttached']),
      backendReady: _readBool(map['backendReady']),
      drawLoopImplemented: _readBool(map['drawLoopImplemented']),
      rendererImplemented: _readBool(map['rendererImplemented']),
      rendersRealPixels: _readBool(map['rendersRealPixels']),
      drawsPixels: _readBool(map['drawsPixels']),
      canSubmitCommands: _readBool(map['canSubmitCommands']),
      canRenderFrame: _readBool(map['canRenderFrame']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionRendererDrawLoopPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionDrawSubmission {
  const ProfessionalVideoTransitionDrawSubmission({
    required this.submissionId,
    required this.commandId,
    required this.passId,
    required this.passType,
    required this.index,
    required this.outputTarget,
    required this.writesToOutputSurface,
    required this.requiresRealPixels,
    required this.submitted,
    required this.blockedReasons,
  });

  final String submissionId;
  final String commandId;
  final String passId;
  final String passType;
  final int index;
  final String outputTarget;
  final bool writesToOutputSurface;
  final bool requiresRealPixels;
  final bool submitted;
  final List<String> blockedReasons;
}

@immutable
class ProfessionalVideoTransitionRendererDrawLoopPlanResult {
  const ProfessionalVideoTransitionRendererDrawLoopPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.renderPassGraphId,
    required this.renderGraphExecutorId,
    required this.surfaceRendererId,
    required this.frameRenderCommandBufferId,
    required this.rendererBackendId,
    required this.rendererDrawLoopId,
    required this.outputSurfaceId,
    required this.outputTarget,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.rendererBackendImplemented,
    required this.gpuContextAvailable,
    required this.nativeSurfaceRequired,
    required this.commandBufferReady,
    required this.outputSurfaceAttached,
    required this.backendReady,
    required this.drawLoopImplemented,
    required this.shaderEvaluatorImplemented,
    required this.pixelRendererImplemented,
    required this.rendererImplemented,
    required this.drawSubmissionCount,
    required this.drawSubmissions,
    required this.drawLoopReady,
    required this.rendersRealPixels,
    required this.drawsPixels,
    required this.canSubmitCommands,
    required this.canRenderFrame,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionRendererDrawLoopPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionRendererDrawLoopPlanResult(
      status:
          ProfessionalVideoTransitionRendererDrawLoopPlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      renderPassGraphId: '',
      renderGraphExecutorId: '',
      surfaceRendererId: '',
      frameRenderCommandBufferId: '',
      rendererBackendId: '',
      rendererDrawLoopId: '',
      outputSurfaceId: '',
      outputTarget: '',
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      canvasWidth: 0,
      canvasHeight: 0,
      rendererBackendImplemented: false,
      gpuContextAvailable: false,
      nativeSurfaceRequired: true,
      commandBufferReady: false,
      outputSurfaceAttached: false,
      backendReady: false,
      drawLoopImplemented: false,
      shaderEvaluatorImplemented: false,
      pixelRendererImplemented: false,
      rendererImplemented: false,
      drawSubmissionCount: 0,
      drawSubmissions: const <ProfessionalVideoTransitionDrawSubmission>[],
      drawLoopReady: false,
      rendersRealPixels: false,
      drawsPixels: false,
      canSubmitCommands: false,
      canRenderFrame: false,
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionRendererDrawLoopPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String renderPassGraphId;
  final String renderGraphExecutorId;
  final String surfaceRendererId;
  final String frameRenderCommandBufferId;
  final String rendererBackendId;
  final String rendererDrawLoopId;
  final String outputSurfaceId;
  final String outputTarget;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final int canvasWidth;
  final int canvasHeight;
  final bool rendererBackendImplemented;
  final bool gpuContextAvailable;
  final bool nativeSurfaceRequired;
  final bool commandBufferReady;
  final bool outputSurfaceAttached;
  final bool backendReady;
  final bool drawLoopImplemented;
  final bool shaderEvaluatorImplemented;
  final bool pixelRendererImplemented;
  final bool rendererImplemented;
  final int drawSubmissionCount;
  final List<ProfessionalVideoTransitionDrawSubmission> drawSubmissions;
  final bool drawLoopReady;
  final bool rendersRealPixels;
  final bool drawsPixels;
  final bool canSubmitCommands;
  final bool canRenderFrame;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionRendererDrawLoopPlanStatus.planned;
}

class ProfessionalVideoTransitionRendererDrawLoopPlanResultMapper {
  const ProfessionalVideoTransitionRendererDrawLoopPlanResultMapper._();

  static ProfessionalVideoTransitionRendererDrawLoopPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionRendererDrawLoopPlanResult
          .invalidRequest(
        reason: 'native_compositor_empty_renderer_draw_loop_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' =>
        ProfessionalVideoTransitionRendererDrawLoopPlanStatus.planned,
      _ => ProfessionalVideoTransitionRendererDrawLoopPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionRendererDrawLoopPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      renderPassGraphId: map['renderPassGraphId']?.toString() ?? '',
      renderGraphExecutorId: map['renderGraphExecutorId']?.toString() ?? '',
      surfaceRendererId: map['surfaceRendererId']?.toString() ?? '',
      frameRenderCommandBufferId:
          map['frameRenderCommandBufferId']?.toString() ?? '',
      rendererBackendId: map['rendererBackendId']?.toString() ?? '',
      rendererDrawLoopId: map['rendererDrawLoopId']?.toString() ?? '',
      outputSurfaceId: map['outputSurfaceId']?.toString() ?? '',
      outputTarget: map['outputTarget']?.toString() ?? '',
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      canvasWidth: _readInt(map['canvasWidth']),
      canvasHeight: _readInt(map['canvasHeight']),
      rendererBackendImplemented: _readBool(map['rendererBackendImplemented']),
      gpuContextAvailable: _readBool(map['gpuContextAvailable']),
      nativeSurfaceRequired:
          _readBool(map['nativeSurfaceRequired'], defaultValue: true),
      commandBufferReady: _readBool(map['commandBufferReady']),
      outputSurfaceAttached: _readBool(map['outputSurfaceAttached']),
      backendReady: _readBool(map['backendReady']),
      drawLoopImplemented: _readBool(map['drawLoopImplemented']),
      shaderEvaluatorImplemented: _readBool(map['shaderEvaluatorImplemented']),
      pixelRendererImplemented: _readBool(map['pixelRendererImplemented']),
      rendererImplemented: _readBool(map['rendererImplemented']),
      drawSubmissionCount: _readInt(map['drawSubmissionCount']),
      drawSubmissions: _readDrawSubmissions(map['drawSubmissions']),
      drawLoopReady: _readBool(map['drawLoopReady']),
      rendersRealPixels: _readBool(map['rendersRealPixels']),
      drawsPixels: _readBool(map['drawsPixels']),
      canSubmitCommands: _readBool(map['canSubmitCommands']),
      canRenderFrame: _readBool(map['canRenderFrame']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionDrawSubmission> _readDrawSubmissions(
    Object? value,
  ) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionDrawSubmission>[];
    }
    return List<ProfessionalVideoTransitionDrawSubmission>.unmodifiable(
      value.whereType<Map>().map((submission) {
        return ProfessionalVideoTransitionDrawSubmission(
          submissionId: submission['submissionId']?.toString() ?? '',
          commandId: submission['commandId']?.toString() ?? '',
          passId: submission['passId']?.toString() ?? '',
          passType: submission['passType']?.toString() ?? '',
          index: _readInt(submission['index']),
          outputTarget: submission['outputTarget']?.toString() ?? '',
          writesToOutputSurface: _readBool(submission['writesToOutputSurface']),
          requiresRealPixels: _readBool(submission['requiresRealPixels']),
          submitted: _readBool(submission['submitted']),
          blockedReasons: _readStringList(submission['blockedReasons']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

enum ProfessionalVideoTransitionParityPlanStatus {
  planned,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionParityOutput {
  const ProfessionalVideoTransitionParityOutput({
    required this.mode,
    required this.outputSurfaceId,
    required this.outputTarget,
    required this.outputPassId,
    required this.outputPassType,
    required this.outputPassInputs,
    required this.outputPassBound,
    required this.renderGraphOutputReady,
    required this.rendererImplemented,
    required this.canRender,
    required this.blockedReasons,
  });

  final String mode;
  final String outputSurfaceId;
  final String outputTarget;
  final String outputPassId;
  final String outputPassType;
  final List<String> outputPassInputs;
  final bool outputPassBound;
  final bool renderGraphOutputReady;
  final bool rendererImplemented;
  final bool canRender;
  final List<String> blockedReasons;
}

@immutable
class ProfessionalVideoTransitionParityPlanResult {
  const ProfessionalVideoTransitionParityPlanResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.definitionId,
    required this.renderSessionId,
    required this.renderPassGraphId,
    required this.outputSurfaceId,
    required this.renderPassCount,
    required this.outputPassId,
    required this.outputPassType,
    required this.outputPassInputs,
    required this.outputPassBound,
    required this.renderGraphOutputReady,
    required this.timelineTime,
    required this.transitionStartTime,
    required this.transitionEndTime,
    required this.rendererImplemented,
    required this.sameOutputContractForAllModes,
    required this.allModesRenderable,
    required this.outputs,
    required this.blockedReasons,
    this.issues = const <Map<String, Object?>>[],
  });

  factory ProfessionalVideoTransitionParityPlanResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
  }) {
    return ProfessionalVideoTransitionParityPlanResult(
      status: ProfessionalVideoTransitionParityPlanStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      definitionId: '',
      renderSessionId: '',
      renderPassGraphId: '',
      outputSurfaceId: '',
      renderPassCount: 0,
      outputPassId: '',
      outputPassType: '',
      outputPassInputs: const <String>[],
      outputPassBound: false,
      renderGraphOutputReady: false,
      timelineTime: null,
      transitionStartTime: null,
      transitionEndTime: null,
      rendererImplemented: false,
      sameOutputContractForAllModes: false,
      allModesRenderable: false,
      outputs: const <ProfessionalVideoTransitionParityOutput>[],
      blockedReasons: const <String>[],
      issues: issues,
    );
  }

  final ProfessionalVideoTransitionParityPlanStatus status;
  final String reason;
  final String rendererVersion;
  final String definitionId;
  final String renderSessionId;
  final String renderPassGraphId;
  final String outputSurfaceId;
  final int renderPassCount;
  final String outputPassId;
  final String outputPassType;
  final List<String> outputPassInputs;
  final bool outputPassBound;
  final bool renderGraphOutputReady;
  final TimelineTime? timelineTime;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final bool rendererImplemented;
  final bool sameOutputContractForAllModes;
  final bool allModesRenderable;
  final List<ProfessionalVideoTransitionParityOutput> outputs;
  final List<String> blockedReasons;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionParityPlanStatus.planned;

  bool get canRender =>
      canPlan &&
      rendererImplemented &&
      sameOutputContractForAllModes &&
      allModesRenderable &&
      outputPassBound &&
      renderGraphOutputReady &&
      blockedReasons.isEmpty;
}

class ProfessionalVideoTransitionParityPlanResultMapper {
  const ProfessionalVideoTransitionParityPlanResultMapper._();

  static ProfessionalVideoTransitionParityPlanResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionParityPlanResult.invalidRequest(
        reason: 'native_compositor_empty_parity_response',
      );
    }
    final status = switch (map['status']?.toString()) {
      'planned' => ProfessionalVideoTransitionParityPlanStatus.planned,
      _ => ProfessionalVideoTransitionParityPlanStatus.invalidRequest,
    };
    return ProfessionalVideoTransitionParityPlanResult(
      status: status,
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      renderPassGraphId: map['renderPassGraphId']?.toString() ?? '',
      outputSurfaceId: map['outputSurfaceId']?.toString() ?? '',
      renderPassCount: _readInt(map['renderPassCount']),
      outputPassId: map['outputPassId']?.toString() ?? '',
      outputPassType: map['outputPassType']?.toString() ?? '',
      outputPassInputs: _readStringList(map['outputPassInputs']),
      outputPassBound: _readBool(map['outputPassBound']),
      renderGraphOutputReady: _readBool(map['renderGraphOutputReady']),
      timelineTime: _readTimelineTime(map['timelineTimeMs']),
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      rendererImplemented: _readBool(map['rendererImplemented']),
      sameOutputContractForAllModes: _readBool(
        map['sameOutputContractForAllModes'],
      ),
      allModesRenderable: _readBool(map['allModesRenderable']),
      outputs: _readOutputs(map['outputs']),
      blockedReasons: _readStringList(map['blockedReasons']),
      issues: _readIssues(map['issues']),
    );
  }

  static List<ProfessionalVideoTransitionParityOutput> _readOutputs(
    Object? value,
  ) {
    if (value is! List) {
      return const <ProfessionalVideoTransitionParityOutput>[];
    }
    return List<ProfessionalVideoTransitionParityOutput>.unmodifiable(
      value.whereType<Map>().map((output) {
        return ProfessionalVideoTransitionParityOutput(
          mode: output['mode']?.toString() ?? '',
          outputSurfaceId: output['outputSurfaceId']?.toString() ?? '',
          outputTarget: output['outputTarget']?.toString() ?? '',
          outputPassId: output['outputPassId']?.toString() ?? '',
          outputPassType: output['outputPassType']?.toString() ?? '',
          outputPassInputs: _readStringList(output['outputPassInputs']),
          outputPassBound: _readBool(output['outputPassBound']),
          renderGraphOutputReady: _readBool(output['renderGraphOutputReady']),
          rendererImplemented: _readBool(output['rendererImplemented']),
          canRender: _readBool(output['canRender']),
          blockedReasons: _readStringList(output['blockedReasons']),
        );
      }),
    );
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }

  static bool _readBool(Object? value) => value is bool && value;

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static List<Map<String, Object?>> _readIssues(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map((issue) {
        return <String, Object?>{
          for (final entry in issue.entries) entry.key.toString(): entry.value,
        };
      }),
    );
  }
}

class ProfessionalVideoTransitionCompositorCapabilitiesMapper {
  const ProfessionalVideoTransitionCompositorCapabilitiesMapper._();

  static ProfessionalVideoTransitionCompositorCapabilities fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionCompositorCapabilities.unavailable;
    }
    return ProfessionalVideoTransitionCompositorCapabilities(
      dualVideoSampling: _readBool(map['dualVideoSampling']),
      temporalMotionBlur: _readBool(map['temporalMotionBlur']),
      mirrorEdgeTiling: _readBool(map['mirrorEdgeTiling']),
      previewParity: _readBool(map['previewParity']),
      liveScrubParity: _readBool(map['liveScrubParity']),
      playbackParity: _readBool(map['playbackParity']),
      exportParity: _readBool(map['exportParity']),
      registeredDefinitions: _readStringList(map['registeredDefinitions']),
    );
  }

  static bool _readBool(Object? value) => value is bool && value;

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }
}

enum ProfessionalVideoTransitionCompositorPrepareStatus {
  ready,
  unsupported,
  invalidRequest,
}

@immutable
class ProfessionalVideoTransitionCompositorPrepareResult {
  const ProfessionalVideoTransitionCompositorPrepareResult({
    required this.status,
    required this.reason,
    required this.rendererVersion,
    required this.missingCapabilities,
    required this.definitionId,
    this.renderSessionId = '',
    this.transitionStartTime,
    this.transitionEndTime,
    this.sourceRoles = const <String>[],
  });

  factory ProfessionalVideoTransitionCompositorPrepareResult.unsupported({
    required String reason,
    String rendererVersion = 'unknown',
    List<String> missingCapabilities = const <String>[],
  }) {
    return ProfessionalVideoTransitionCompositorPrepareResult(
      status: ProfessionalVideoTransitionCompositorPrepareStatus.unsupported,
      reason: reason,
      rendererVersion: rendererVersion,
      missingCapabilities: List<String>.unmodifiable(missingCapabilities),
      definitionId: '',
      sourceRoles: const <String>[],
    );
  }

  factory ProfessionalVideoTransitionCompositorPrepareResult.invalidRequest({
    required String reason,
    String rendererVersion = 'unknown',
  }) {
    return ProfessionalVideoTransitionCompositorPrepareResult(
      status: ProfessionalVideoTransitionCompositorPrepareStatus.invalidRequest,
      reason: reason,
      rendererVersion: rendererVersion,
      missingCapabilities: const <String>[],
      definitionId: '',
      sourceRoles: const <String>[],
    );
  }

  final ProfessionalVideoTransitionCompositorPrepareStatus status;
  final String reason;
  final String rendererVersion;
  final List<String> missingCapabilities;
  final String definitionId;
  final String renderSessionId;
  final TimelineTime? transitionStartTime;
  final TimelineTime? transitionEndTime;
  final List<String> sourceRoles;

  bool get canRender =>
      status == ProfessionalVideoTransitionCompositorPrepareStatus.ready;
}

class ProfessionalVideoTransitionCompositorPrepareResultMapper {
  const ProfessionalVideoTransitionCompositorPrepareResultMapper._();

  static ProfessionalVideoTransitionCompositorPrepareResult fromMap(
    Map<String, Object?>? map,
  ) {
    if (map == null) {
      return ProfessionalVideoTransitionCompositorPrepareResult.unsupported(
        reason: 'native_compositor_empty_response',
      );
    }
    return ProfessionalVideoTransitionCompositorPrepareResult(
      status: _readStatus(map['status']),
      reason: map['reason']?.toString() ?? '',
      rendererVersion: map['rendererVersion']?.toString() ?? 'unknown',
      missingCapabilities: _readStringList(map['missingCapabilities']),
      definitionId: map['definitionId']?.toString() ?? '',
      renderSessionId: map['renderSessionId']?.toString() ?? '',
      transitionStartTime: _readTimelineTime(map['transitionStartMs']),
      transitionEndTime: _readTimelineTime(map['transitionEndMs']),
      sourceRoles: _readStringList(map['sourceRoles']),
    );
  }

  static ProfessionalVideoTransitionCompositorPrepareStatus _readStatus(
    Object? value,
  ) {
    return switch (value?.toString()) {
      'ready' => ProfessionalVideoTransitionCompositorPrepareStatus.ready,
      'invalidRequest' =>
        ProfessionalVideoTransitionCompositorPrepareStatus.invalidRequest,
      _ => ProfessionalVideoTransitionCompositorPrepareStatus.unsupported,
    };
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(value.map((entry) => entry.toString()));
  }

  static TimelineTime? _readTimelineTime(Object? value) {
    if (value is num) {
      return TimelineTime.fromMilliseconds(value.round());
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return TimelineTime.fromMilliseconds(parsed);
  }
}

@immutable
class ProfessionalVideoTransitionRenderPlan {
  const ProfessionalVideoTransitionRenderPlan({
    required this.definitionId,
    required this.transitionId,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.boundaryTime,
    required this.leadingDuration,
    required this.trailingDuration,
    required this.sources,
    required this.requiredCapabilities,
    this.parameters = const <String, Object?>{},
    this.samplingPolicy = const <String, Object?>{},
    this.edgePolicy = const <String, Object?>{},
    this.motionBlurPolicy = const <String, Object?>{},
  });

  final String definitionId;
  final String transitionId;
  final int canvasWidth;
  final int canvasHeight;
  final TimelineTime boundaryTime;
  final TimelineTime leadingDuration;
  final TimelineTime trailingDuration;
  final List<ProfessionalVideoTransitionCompositorSource> sources;
  final List<String> requiredCapabilities;
  final Map<String, Object?> parameters;
  final Map<String, Object?> samplingPolicy;
  final Map<String, Object?> edgePolicy;
  final Map<String, Object?> motionBlurPolicy;

  Map<String, Object?> toPlatformMap() {
    return <String, Object?>{
      'definitionId': definitionId,
      'transitionId': transitionId,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'boundaryTimeMs': boundaryTime.inMilliseconds,
      'leadingDurationMs': leadingDuration.inMilliseconds,
      'trailingDurationMs': trailingDuration.inMilliseconds,
      'sources': sources.map(_sourceToPlatformMap).toList(growable: false),
      'requiredCapabilities': List<String>.unmodifiable(requiredCapabilities),
      'parameters': Map<String, Object?>.unmodifiable(parameters),
      'samplingPolicy': Map<String, Object?>.unmodifiable(samplingPolicy),
      'edgePolicy': Map<String, Object?>.unmodifiable(edgePolicy),
      'motionBlurPolicy': Map<String, Object?>.unmodifiable(motionBlurPolicy),
    };
  }

  static Map<String, Object?> _sourceToPlatformMap(
    ProfessionalVideoTransitionCompositorSource source,
  ) {
    final sourceUri = source.sourceUri?.trim();
    return <String, Object?>{
      'clipId': source.clipId,
      'assetId': source.assetId,
      if (sourceUri != null && sourceUri.isNotEmpty) 'sourceUri': sourceUri,
      'timelineStartMs': source.timelineRange.start.inMilliseconds,
      'timelineEndMs': source.timelineRange.endExclusive.inMilliseconds,
      'sourceStartMs': source.sourceStartTime.inMilliseconds,
      'sourceDurationMs': source.sourceDuration.inMilliseconds,
    };
  }
}

@immutable
class ProfessionalVideoTransitionCompositorSource {
  const ProfessionalVideoTransitionCompositorSource({
    required this.clipId,
    required this.assetId,
    required this.timelineRange,
    required this.sourceStartTime,
    required this.sourceDuration,
    this.sourceUri,
  });

  final String clipId;
  final String assetId;
  final String? sourceUri;
  final TimelineTimeRange timelineRange;
  final TimelineTime sourceStartTime;
  final TimelineTime sourceDuration;

  TimelineTime get sourceEndExclusive => sourceStartTime + sourceDuration;

  TimelineTime sourceTimeForTimelineTime(TimelineTime timelineTime) {
    final localTime = timelineTime - timelineRange.start;
    final unclamped = sourceStartTime + localTime;
    return unclamped.clamp(sourceStartTime, sourceEndExclusive);
  }
}

@immutable
class ProfessionalCrossDissolveFramePlan {
  const ProfessionalCrossDissolveFramePlan({
    required this.transitionId,
    required this.progress,
    required this.outgoingOpacity,
    required this.incomingOpacity,
    required this.outgoingSourceTime,
    required this.incomingSourceTime,
    required this.hasFullSourceCoverage,
  });

  final String transitionId;
  final double progress;
  final double outgoingOpacity;
  final double incomingOpacity;
  final TimelineTime outgoingSourceTime;
  final TimelineTime incomingSourceTime;

  /// True only when both real video sources cover the whole transition window.
  ///
  /// A professional renderer must not enable a cross dissolve from this plan
  /// when coverage is false, because doing so would force one side to freeze at
  /// a clamped source boundary instead of sampling live frames.
  final bool hasFullSourceCoverage;
}

class ProfessionalCrossDissolveCompositorPlanner {
  const ProfessionalCrossDissolveCompositorPlanner();

  ProfessionalCrossDissolveFramePlan planFrame({
    required ProfessionalVideoTransitionRenderPlan renderPlan,
    required TimelineTime timelineTime,
  }) {
    if (renderPlan.sources.length < 2) {
      throw ArgumentError.value(
        renderPlan.sources.length,
        'renderPlan.sources.length',
        'Cross dissolve requires outgoing and incoming video sources.',
      );
    }

    final start = renderPlan.boundaryTime - renderPlan.leadingDuration;
    final end = renderPlan.boundaryTime + renderPlan.trailingDuration;
    final total = end - start;
    final progress = total <= TimelineTime.zero
        ? 0.0
        : ((timelineTime - start).inProjectTicks / total.inProjectTicks)
            .clamp(0.0, 1.0)
            .toDouble();
    final outgoing = renderPlan.sources[0];
    final incoming = renderPlan.sources[1];

    return ProfessionalCrossDissolveFramePlan(
      transitionId: renderPlan.transitionId,
      progress: progress,
      outgoingOpacity: 1.0 - progress,
      incomingOpacity: progress,
      outgoingSourceTime: outgoing.sourceTimeForTimelineTime(timelineTime),
      incomingSourceTime: incoming.sourceTimeForTimelineTime(timelineTime),
      hasFullSourceCoverage: _coversTransitionWindow(outgoing, start, end) &&
          _coversTransitionWindow(incoming, start, end),
    );
  }

  static bool _coversTransitionWindow(
    ProfessionalVideoTransitionCompositorSource source,
    TimelineTime start,
    TimelineTime end,
  ) {
    return source.timelineRange.start <= start &&
        source.timelineRange.endExclusive >= end;
  }
}

@immutable
class ProfessionalVideoTransitionMotionTilePlan {
  const ProfessionalVideoTransitionMotionTilePlan({
    required this.enabled,
    required this.mirrorEdges,
    required this.outputScaleX,
    required this.outputScaleY,
  });

  final bool enabled;
  final bool mirrorEdges;
  final double outputScaleX;
  final double outputScaleY;
}

@immutable
class ProfessionalVideoTransitionShutterPlan {
  const ProfessionalVideoTransitionShutterPlan({
    required this.shutterAngleDegrees,
    required this.frameRate,
    required this.sampleCount,
    required this.sampleTimes,
  });

  final double shutterAngleDegrees;
  final double frameRate;
  final int sampleCount;
  final List<TimelineTime> sampleTimes;
}

@immutable
class ProfessionalZoomCameraFramePlan {
  const ProfessionalZoomCameraFramePlan({
    required this.transitionId,
    required this.progress,
    required this.seamProgress,
    required this.outgoingSourceTime,
    required this.incomingSourceTime,
    required this.outgoingScale,
    required this.incomingScale,
    required this.motionTile,
    required this.shutter,
  });

  final String transitionId;
  final double progress;
  final double seamProgress;
  final TimelineTime outgoingSourceTime;
  final TimelineTime incomingSourceTime;
  final double outgoingScale;
  final double incomingScale;
  final ProfessionalVideoTransitionMotionTilePlan motionTile;
  final ProfessionalVideoTransitionShutterPlan shutter;
}

@immutable
class ProfessionalZoomCameraPlanRequest {
  const ProfessionalZoomCameraPlanRequest({
    required this.transitionId,
    required this.timelineTime,
    required this.boundaryTime,
    required this.leadingDuration,
    required this.trailingDuration,
    required this.outgoing,
    required this.incoming,
    this.outgoingBoostScale = 3.0,
    this.incomingStartScale = 0.28,
    this.shutterAngleDegrees = 360.0,
    this.frameRate = 30.0,
    this.shutterSampleCount = 8,
    this.motionTileOutputScaleX = 4.0,
    this.motionTileOutputScaleY = 3.5,
  });

  final String transitionId;
  final TimelineTime timelineTime;
  final TimelineTime boundaryTime;
  final TimelineTime leadingDuration;
  final TimelineTime trailingDuration;
  final ProfessionalVideoTransitionCompositorSource outgoing;
  final ProfessionalVideoTransitionCompositorSource incoming;
  final double outgoingBoostScale;
  final double incomingStartScale;
  final double shutterAngleDegrees;
  final double frameRate;
  final int shutterSampleCount;
  final double motionTileOutputScaleX;
  final double motionTileOutputScaleY;
}

@immutable
class ProfessionalZoomCameraRenderPlan {
  const ProfessionalZoomCameraRenderPlan({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.request,
  });

  final int canvasWidth;
  final int canvasHeight;
  final ProfessionalZoomCameraPlanRequest request;

  ProfessionalVideoTransitionRenderPlan toGenericRenderPlan() {
    return ProfessionalVideoTransitionRenderPlan(
      definitionId: ProfessionalVideoTransitionCompositorKind.zoomInCamera.name,
      transitionId: request.transitionId,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      boundaryTime: request.boundaryTime,
      leadingDuration: request.leadingDuration,
      trailingDuration: request.trailingDuration,
      sources: <ProfessionalVideoTransitionCompositorSource>[
        request.outgoing,
        request.incoming,
      ],
      requiredCapabilities: const <String>[
        'dualVideoSampling',
        'temporalMotionBlur',
        'mirrorEdgeTiling',
        'previewParity',
        'liveScrubParity',
        'playbackParity',
      ],
      parameters: <String, Object?>{
        'outgoingBoostScale': request.outgoingBoostScale,
        'incomingStartScale': request.incomingStartScale,
      },
      samplingPolicy: const <String, Object?>{
        'sourceCount': 2,
        'sourceRoles': <String>['outgoing', 'incoming'],
      },
      edgePolicy: <String, Object?>{
        'mode': 'mirrorTile',
        'outputScaleX': request.motionTileOutputScaleX,
        'outputScaleY': request.motionTileOutputScaleY,
      },
      motionBlurPolicy: <String, Object?>{
        'mode': 'temporalShutter',
        'shutterAngleDegrees': request.shutterAngleDegrees,
        'frameRate': request.frameRate,
        'sampleCount': request.shutterSampleCount,
      },
    );
  }

  Map<String, Object?> toPlatformMap() => toGenericRenderPlan().toPlatformMap();
}

class ProfessionalZoomCameraCompositorPlanner {
  const ProfessionalZoomCameraCompositorPlanner();

  ProfessionalZoomCameraFramePlan planFrame(
    ProfessionalZoomCameraPlanRequest request,
  ) {
    final start = request.boundaryTime - request.leadingDuration;
    final end = request.boundaryTime + request.trailingDuration;
    final total = end - start;
    final progress = total <= TimelineTime.zero
        ? 0.0
        : ((request.timelineTime - start).inProjectTicks / total.inProjectTicks)
            .clamp(0.0, 1.0)
            .toDouble();
    final seamProgress = total <= TimelineTime.zero
        ? 0.5
        : (request.leadingDuration.inProjectTicks / total.inProjectTicks)
            .clamp(0.0, 1.0)
            .toDouble();
    final outgoingPhase =
        (progress / _safePositive(seamProgress)).clamp(0.0, 1.0).toDouble();
    final incomingPhase =
        ((progress - seamProgress) / _safePositive(1 - seamProgress))
            .clamp(0.0, 1.0)
            .toDouble();

    return ProfessionalZoomCameraFramePlan(
      transitionId: request.transitionId,
      progress: progress,
      seamProgress: seamProgress,
      outgoingSourceTime:
          request.outgoing.sourceTimeForTimelineTime(request.timelineTime),
      incomingSourceTime:
          request.incoming.sourceTimeForTimelineTime(request.timelineTime),
      outgoingScale: _lerp(
        1.0,
        request.outgoingBoostScale,
        _easeInCubic(outgoingPhase),
      ),
      incomingScale: _lerp(
        request.incomingStartScale,
        1.0,
        _easeOutCubic(incomingPhase),
      ),
      motionTile: ProfessionalVideoTransitionMotionTilePlan(
        enabled: true,
        mirrorEdges: true,
        outputScaleX: request.motionTileOutputScaleX,
        outputScaleY: request.motionTileOutputScaleY,
      ),
      shutter: ProfessionalVideoTransitionShutterPlan(
        shutterAngleDegrees: request.shutterAngleDegrees,
        frameRate: request.frameRate,
        sampleCount: request.shutterSampleCount,
        sampleTimes: _shutterSampleTimes(
          timelineTime: request.timelineTime,
          transitionStart: start,
          transitionEnd: end,
          shutterAngleDegrees: request.shutterAngleDegrees,
          frameRate: request.frameRate,
          sampleCount: request.shutterSampleCount,
        ),
      ),
    );
  }

  static List<TimelineTime> _shutterSampleTimes({
    required TimelineTime timelineTime,
    required TimelineTime transitionStart,
    required TimelineTime transitionEnd,
    required double shutterAngleDegrees,
    required double frameRate,
    required int sampleCount,
  }) {
    final safeFrameRate =
        frameRate.isFinite && frameRate > 0 ? frameRate : 30.0;
    final safeSampleCount = sampleCount.clamp(1, 32);
    final exposureSeconds =
        shutterAngleDegrees.clamp(0.0, 720.0) / (360.0 * safeFrameRate);
    if (safeSampleCount == 1 || exposureSeconds <= 0) {
      return <TimelineTime>[
        timelineTime.clamp(transitionStart, transitionEnd),
      ];
    }
    final firstOffsetSeconds = -exposureSeconds / 2;
    final stepSeconds = exposureSeconds / (safeSampleCount - 1);
    return List<TimelineTime>.unmodifiable(
      List<TimelineTime>.generate(safeSampleCount, (index) {
        final sampleTime = timelineTime +
            TimelineTime.fromSecondsDouble(
              firstOffsetSeconds + (stepSeconds * index),
            );
        return sampleTime.clamp(transitionStart, transitionEnd);
      }),
    );
  }

  static double _safePositive(double value) {
    return value.abs() < 0.0001 ? 0.0001 : value;
  }

  static double _lerp(double start, double end, double t) {
    return start + ((end - start) * t.clamp(0.0, 1.0));
  }

  static double _easeInCubic(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return clamped * clamped * clamped;
  }

  static double _easeOutCubic(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final inverse = 1 - clamped;
    return 1 - (inverse * inverse * inverse);
  }
}
