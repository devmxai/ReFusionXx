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
      dualVideoSampling &&
      temporalMotionBlur &&
      mirrorEdgeTiling &&
      previewParity &&
      liveScrubParity &&
      playbackParity &&
      exportParity;

  List<String> get missingForProfessionalZoomInCamera {
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
  Future<ProfessionalVideoTransitionCompositorPrepareResult>
      prepareZoomInCameraRenderPlan(
    ProfessionalZoomCameraRenderPlan plan,
  ) {
    return prepareRenderPlan(plan.toGenericRenderPlan());
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
    );
  }

  final ProfessionalVideoTransitionCompositorPrepareStatus status;
  final String reason;
  final String rendererVersion;
  final List<String> missingCapabilities;
  final String definitionId;

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
