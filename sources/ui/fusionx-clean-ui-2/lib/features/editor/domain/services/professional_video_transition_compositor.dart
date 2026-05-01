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

  /// Strict gate for creating any new professional video transition.
  ///
  /// This intentionally requires the complete compositor stack, even for
  /// simpler transition definitions, so unsupported presets cannot slip back
  /// into frozen-frame, Flutter-overlay, or single-surface fallback rendering.
  bool get canExposeProfessionalVideoTransitions =>
      dualVideoSampling &&
      temporalMotionBlur &&
      mirrorEdgeTiling &&
      previewParity &&
      liveScrubParity &&
      playbackParity &&
      exportParity;

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

  Future<ProfessionalVideoTransitionRenderPassGraphPlanResult>
      planRenderPassGraph({
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
    required this.decodeRequestIds,
    required this.sampleCount,
    required this.requiresExactFrameDecode,
    required this.allowThumbnailFallback,
    required this.allowBoundaryFreeze,
  });

  final String role;
  final String clipId;
  final String assetId;
  final List<String> decodeRequestIds;
  final int sampleCount;
  final bool requiresExactFrameDecode;
  final bool allowThumbnailFallback;
  final bool allowBoundaryFreeze;
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
      !allowThumbnailFallback &&
      !allowBoundaryFreeze &&
      decoderImplemented &&
      tracks.length == 2 &&
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
          decodeRequestIds: _readStringList(track['decodeRequestIds']),
          sampleCount: _readInt(track['sampleCount']),
          requiresExactFrameDecode: _readBool(
            track['requiresExactFrameDecode'],
            defaultValue: true,
          ),
          allowThumbnailFallback: _readBool(track['allowThumbnailFallback']),
          allowBoundaryFreeze: _readBool(track['allowBoundaryFreeze']),
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
    required this.rendererImplemented,
    required this.passes,
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
      rendererImplemented: false,
      passes: const <ProfessionalVideoTransitionRenderPassNode>[],
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
  final bool rendererImplemented;
  final List<ProfessionalVideoTransitionRenderPassNode> passes;
  final List<Map<String, Object?>> issues;

  bool get canPlan =>
      status == ProfessionalVideoTransitionRenderPassGraphPlanStatus.planned;

  bool get canRender => canPlan && rendererImplemented;
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
      rendererImplemented: _readBool(map['rendererImplemented']),
      passes: _readPasses(map['passes']),
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
    required this.rendererImplemented,
    required this.canRender,
    required this.blockedReasons,
  });

  final String mode;
  final String outputSurfaceId;
  final String outputTarget;
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
    return <String, Object?>{
      'clipId': source.clipId,
      'assetId': source.assetId,
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
  });

  final String clipId;
  final String assetId;
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
        'exportParity',
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
