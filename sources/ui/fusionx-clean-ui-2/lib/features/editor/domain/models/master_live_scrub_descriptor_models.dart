import 'package:flutter/foundation.dart';

import 'master_live_scrub_visual_program_models.dart';
import 'master_value_truth_models.dart';

@immutable
class LiveScrubTimelineSourceWindow {
  const LiveScrubTimelineSourceWindow({
    required this.targetId,
    required this.timelineStartMs,
    required this.timelineEndMs,
    required this.sourceStartMs,
    required this.sourceDurationMs,
    required this.playbackRate,
  });

  final String targetId;
  final int timelineStartMs;
  final int timelineEndMs;
  final int sourceStartMs;
  final int sourceDurationMs;
  final double playbackRate;
}

@immutable
class LiveScrubTransitionTimelineWindow {
  const LiveScrubTransitionTimelineWindow({
    required this.targetId,
    required this.transitionId,
    required this.timelineStartMs,
    required this.timelineEndMs,
  });

  final String targetId;
  final String transitionId;
  final int timelineStartMs;
  final int timelineEndMs;
}

@immutable
class LiveScrubDescriptorCapabilities {
  const LiveScrubDescriptorCapabilities({
    this.supportsSourceDimensions = false,
    this.supportsCanvasPlacement = false,
    this.supportsCrop = false,
    this.supportsTransformMatrix = false,
    this.supportsOpacity = false,
    this.supportsEffectProgramIds = false,
    this.supportsDualSourceTransitionWindow = false,
    this.supportsLatencyMetrics = false,
    this.supportedEffectProgramIds = const <String>[],
    this.source = 'unknown',
  });

  final bool supportsSourceDimensions;
  final bool supportsCanvasPlacement;
  final bool supportsCrop;
  final bool supportsTransformMatrix;
  final bool supportsOpacity;
  final bool supportsEffectProgramIds;
  final bool supportsDualSourceTransitionWindow;
  final bool supportsLatencyMetrics;
  final List<String> supportedEffectProgramIds;
  final String source;
}

enum LiveScrubTransitionParityState {
  notRequired,
  blocked,
  windowReadyNoPixels,
  ready,
}

enum LiveScrubLatencyBudgetState {
  nativeMetricsUnavailable,
  nativeMetricsPending,
  withinBudget,
  overBudget,
}

enum RendererPresentationMatchState {
  pendingNativeAck,
  matched,
  mismatched,
  blocked,
}

@immutable
class RendererPresentationProof {
  const RendererPresentationProof({
    this.requestedRootTimeMs = 0,
    this.requestedFrameIndex = 0,
    this.requestedCommitFrameNumber = 0,
    this.requestedSourceIds = const <String>[],
    this.requestId = 'uninitialized',
    this.sourceRevision = 'unknown',
    this.renderGraphRevision = 'unknown',
    this.rendererMode = 'unknown',
    this.blockers = const <String>[],
    this.presentedRootTimeMs,
    this.presentedFrameIndex,
    this.presentedCommitFrameNumber,
    this.presentedSourceIds = const <String>[],
    this.surfaceId,
    this.presentationTimestampUs,
    this.nativePresentationAck = false,
    this.matchState = RendererPresentationMatchState.pendingNativeAck,
    this.matchReason = 'awaiting_native_ack',
  });

  final int requestedRootTimeMs;
  final int requestedFrameIndex;
  final int requestedCommitFrameNumber;
  final List<String> requestedSourceIds;
  final String requestId;
  final String sourceRevision;
  final String renderGraphRevision;
  final String rendererMode;
  final List<String> blockers;
  final int? presentedRootTimeMs;
  final int? presentedFrameIndex;
  final int? presentedCommitFrameNumber;
  final List<String> presentedSourceIds;
  final String? surfaceId;
  final int? presentationTimestampUs;
  final bool nativePresentationAck;
  final RendererPresentationMatchState matchState;
  final String matchReason;

  RendererPresentationProof copyWith({
    int? requestedRootTimeMs,
    int? requestedFrameIndex,
    int? requestedCommitFrameNumber,
    List<String>? requestedSourceIds,
    String? requestId,
    String? sourceRevision,
    String? renderGraphRevision,
    String? rendererMode,
    List<String>? blockers,
    int? presentedRootTimeMs,
    bool clearPresentedRootTimeMs = false,
    int? presentedFrameIndex,
    bool clearPresentedFrameIndex = false,
    int? presentedCommitFrameNumber,
    bool clearPresentedCommitFrameNumber = false,
    List<String>? presentedSourceIds,
    String? surfaceId,
    bool clearSurfaceId = false,
    int? presentationTimestampUs,
    bool clearPresentationTimestampUs = false,
    bool? nativePresentationAck,
    RendererPresentationMatchState? matchState,
    String? matchReason,
  }) {
    return RendererPresentationProof(
      requestedRootTimeMs: requestedRootTimeMs ?? this.requestedRootTimeMs,
      requestedFrameIndex: requestedFrameIndex ?? this.requestedFrameIndex,
      requestedCommitFrameNumber:
          requestedCommitFrameNumber ?? this.requestedCommitFrameNumber,
      requestedSourceIds: requestedSourceIds ?? this.requestedSourceIds,
      requestId: requestId ?? this.requestId,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      renderGraphRevision: renderGraphRevision ?? this.renderGraphRevision,
      rendererMode: rendererMode ?? this.rendererMode,
      blockers: blockers ?? this.blockers,
      presentedRootTimeMs: clearPresentedRootTimeMs
          ? null
          : (presentedRootTimeMs ?? this.presentedRootTimeMs),
      presentedFrameIndex: clearPresentedFrameIndex
          ? null
          : (presentedFrameIndex ?? this.presentedFrameIndex),
      presentedCommitFrameNumber: clearPresentedCommitFrameNumber
          ? null
          : (presentedCommitFrameNumber ?? this.presentedCommitFrameNumber),
      presentedSourceIds: presentedSourceIds ?? this.presentedSourceIds,
      surfaceId: clearSurfaceId ? null : (surfaceId ?? this.surfaceId),
      presentationTimestampUs: clearPresentationTimestampUs
          ? null
          : (presentationTimestampUs ?? this.presentationTimestampUs),
      nativePresentationAck: nativePresentationAck ?? this.nativePresentationAck,
      matchState: matchState ?? this.matchState,
      matchReason: matchReason ?? this.matchReason,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'requestedRootTimeMs': requestedRootTimeMs,
      'requestedFrameIndex': requestedFrameIndex,
      'requestedCommitFrameNumber': requestedCommitFrameNumber,
      'requestedSourceIds': requestedSourceIds,
      'requestId': requestId,
      'sourceRevision': sourceRevision,
      'renderGraphRevision': renderGraphRevision,
      'rendererMode': rendererMode,
      'blockers': blockers,
      'presentedRootTimeMs': presentedRootTimeMs,
      'presentedFrameIndex': presentedFrameIndex,
      'presentedCommitFrameNumber': presentedCommitFrameNumber,
      'presentedSourceIds': presentedSourceIds,
      'surfaceId': surfaceId,
      'presentationTimestampUs': presentationTimestampUs,
      'nativePresentationAck': nativePresentationAck,
      'matchState': matchState.name,
      'matchReason': matchReason,
    };
  }
}

@immutable
class LiveScrubPerformanceSnapshot {
  const LiveScrubPerformanceSnapshot({
    this.frameRequestRateFps,
    this.nativeDecodeRebindLatencyMs,
    this.descriptorProjectionLatencyUs,
    this.framePresentationLatencyMs,
    this.droppedFrameCount,
    this.crossSourceWarmupReady,
    this.memoryPressureLevel,
  });

  final double? frameRequestRateFps;
  final double? nativeDecodeRebindLatencyMs;
  final int? descriptorProjectionLatencyUs;
  final double? framePresentationLatencyMs;
  final int? droppedFrameCount;
  final bool? crossSourceWarmupReady;
  final String? memoryPressureLevel;

  LiveScrubPerformanceSnapshot copyWith({
    double? frameRequestRateFps,
    double? nativeDecodeRebindLatencyMs,
    int? descriptorProjectionLatencyUs,
    double? framePresentationLatencyMs,
    int? droppedFrameCount,
    bool? crossSourceWarmupReady,
    String? memoryPressureLevel,
  }) {
    return LiveScrubPerformanceSnapshot(
      frameRequestRateFps: frameRequestRateFps ?? this.frameRequestRateFps,
      nativeDecodeRebindLatencyMs:
          nativeDecodeRebindLatencyMs ?? this.nativeDecodeRebindLatencyMs,
      descriptorProjectionLatencyUs:
          descriptorProjectionLatencyUs ?? this.descriptorProjectionLatencyUs,
      framePresentationLatencyMs:
          framePresentationLatencyMs ?? this.framePresentationLatencyMs,
      droppedFrameCount: droppedFrameCount ?? this.droppedFrameCount,
      crossSourceWarmupReady:
          crossSourceWarmupReady ?? this.crossSourceWarmupReady,
      memoryPressureLevel: memoryPressureLevel ?? this.memoryPressureLevel,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'frameRequestRateFps': frameRequestRateFps,
      'nativeDecodeRebindLatencyMs': nativeDecodeRebindLatencyMs,
      'descriptorProjectionLatencyUs': descriptorProjectionLatencyUs,
      'framePresentationLatencyMs': framePresentationLatencyMs,
      'droppedFrameCount': droppedFrameCount,
      'crossSourceWarmupReady': crossSourceWarmupReady,
      'memoryPressureLevel': memoryPressureLevel,
    };
  }
}

@immutable
class LiveScrubLatencyBudgetThresholds {
  const LiveScrubLatencyBudgetThresholds({
    this.minFrameRequestRateFps = 24.0,
    this.maxNativeDecodeRebindLatencyMs = 50.0,
    this.maxDescriptorProjectionLatencyUs = 3000,
    this.maxFramePresentationLatencyMs = 33.0,
    this.maxDroppedFrameCount = 1,
  });

  final double minFrameRequestRateFps;
  final double maxNativeDecodeRebindLatencyMs;
  final int maxDescriptorProjectionLatencyUs;
  final double maxFramePresentationLatencyMs;
  final int maxDroppedFrameCount;
}

@immutable
class LiveScrubParityReport {
  const LiveScrubParityReport({
    required this.canScrubFrame,
    required this.usesMasterClock,
    required this.usesMasterFrameEvaluation,
    required this.usesNativeScrubSurface,
    required this.usesExoPlayerDuringActiveScrub,
    required this.usesStillFallback,
    required this.missingDescriptors,
    required this.unsupportedEffects,
    required this.transitionParityState,
    required this.latencyBudgetState,
    required this.performanceSnapshot,
  });

  final bool canScrubFrame;
  final bool usesMasterClock;
  final bool usesMasterFrameEvaluation;
  final bool usesNativeScrubSurface;
  final bool usesExoPlayerDuringActiveScrub;
  final bool usesStillFallback;
  final List<String> missingDescriptors;
  final List<String> unsupportedEffects;
  final LiveScrubTransitionParityState transitionParityState;
  final LiveScrubLatencyBudgetState latencyBudgetState;
  final LiveScrubPerformanceSnapshot performanceSnapshot;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'canScrubFrame': canScrubFrame,
      'usesMasterClock': usesMasterClock,
      'usesMasterFrameEvaluation': usesMasterFrameEvaluation,
      'usesNativeScrubSurface': usesNativeScrubSurface,
      'usesExoPlayerDuringActiveScrub': usesExoPlayerDuringActiveScrub,
      'usesStillFallback': usesStillFallback,
      'missingDescriptors': missingDescriptors,
      'unsupportedEffects': unsupportedEffects,
      'transitionParityState': transitionParityState.name,
      'latencyBudgetState': latencyBudgetState.name,
      'performanceSnapshot': performanceSnapshot.toMap(),
    };
  }
}

@immutable
class LiveScrubSurfaceDescriptor {
  const LiveScrubSurfaceDescriptor({
    required this.id,
    required this.targetId,
    required this.sourceKind,
    required this.sourceUri,
    this.scrubStoreKey,
    this.sourceWidth,
    this.sourceHeight,
    required this.sourcePositionMs,
    required this.timelinePositionMs,
    required this.timelineStartMs,
    required this.timelineEndMs,
    this.transitionId,
    this.transitionTimelineStartMs,
    this.transitionTimelineEndMs,
    this.transitionProgress,
    required this.transformMatrix3x3,
    required this.opacity,
    required this.effectProgramIds,
    required this.transitionRole,
    required this.isValid,
    required this.blockers,
    required this.debugReasons,
  });

  final String id;
  final String targetId;
  final LiveScrubSourceKind sourceKind;
  final String sourceUri;
  final String? scrubStoreKey;
  final int? sourceWidth;
  final int? sourceHeight;
  final int sourcePositionMs;
  final int timelinePositionMs;
  final int timelineStartMs;
  final int timelineEndMs;
  final String? transitionId;
  final int? transitionTimelineStartMs;
  final int? transitionTimelineEndMs;
  final double? transitionProgress;
  final List<double> transformMatrix3x3;
  final double opacity;
  final List<String> effectProgramIds;
  final LiveScrubTransitionRole transitionRole;
  final bool isValid;
  final List<String> blockers;
  final List<String> debugReasons;

  Map<String, Object?> toNativeMap() {
    return <String, Object?>{
      'id': id,
      'targetId': targetId,
      'sourceKind': sourceKind.name,
      'sourceUri': sourceUri,
      'scrubStoreKey': scrubStoreKey,
      'sourceWidth': sourceWidth,
      'sourceHeight': sourceHeight,
      'sourcePositionMs': sourcePositionMs,
      'timelinePositionMs': timelinePositionMs,
      'timelineStartMs': timelineStartMs,
      'timelineEndMs': timelineEndMs,
      'transitionId': transitionId,
      'transitionTimelineStartMs': transitionTimelineStartMs,
      'transitionTimelineEndMs': transitionTimelineEndMs,
      'transitionProgress': transitionProgress,
      'transformMatrix3x3': transformMatrix3x3,
      'opacity': opacity,
      'effectProgramIds': effectProgramIds,
      'transitionRole': transitionRole.name,
      'isValid': isValid,
      'blockers': blockers,
      'debugReasons': debugReasons,
    };
  }
}

@immutable
class LiveScrubDescriptorProjectionResult {
  LiveScrubDescriptorProjectionResult({
    required this.timelinePositionMs,
    List<LiveScrubSurfaceDescriptor> descriptors =
        const <LiveScrubSurfaceDescriptor>[],
    List<String> blockers = const <String>[],
    List<String> diagnostics = const <String>[],
    required this.canProject,
    required this.parityReport,
    this.rendererPresentationProof = const RendererPresentationProof(),
  })  : descriptors = List.unmodifiable(descriptors),
        blockers = List.unmodifiable(blockers),
        diagnostics = List.unmodifiable(diagnostics);

  final int timelinePositionMs;
  final List<LiveScrubSurfaceDescriptor> descriptors;
  final List<String> blockers;
  final List<String> diagnostics;
  final bool canProject;
  final LiveScrubParityReport parityReport;
  final RendererPresentationProof rendererPresentationProof;

  Map<String, Object?> toRuntimeBridgeNativeMap() {
    return <String, Object?>{
      'timelinePositionMs': timelinePositionMs,
      'descriptors': descriptors.map((entry) => entry.toNativeMap()).toList(
            growable: false,
          ),
      'blockers': blockers,
      'diagnostics': diagnostics,
      'canProject': canProject,
      'parityReport': parityReport.toMap(),
      'rendererPresentationProof': rendererPresentationProof.toMap(),
    };
  }
}

@immutable
class LiveScrubEffectDescriptor {
  const LiveScrubEffectDescriptor({
    required this.id,
    required this.rendererValue,
    required this.rendererUnit,
  });

  final String id;
  final double rendererValue;
  final MasterValueUnit rendererUnit;
}
