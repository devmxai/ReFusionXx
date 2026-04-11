import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/editor/domain/models/export_composition_models.dart';

enum ExportJobStatus {
  idle,
  queued,
  started,
  progress,
  completed,
  failed,
  cancelled,
}

@immutable
class ExportOutputValidation {
  const ExportOutputValidation({
    required this.fileSizeBytes,
    required this.durationMs,
    required this.expectedDurationMs,
    required this.timelineDurationMs,
    required this.durationDeltaMs,
    required this.hasVideo,
    required this.isDurationWithinTolerance,
    required this.expectedHasAudio,
    this.isFrameRateWithinTolerance,
    this.expectedWidth,
    this.expectedHeight,
    this.expectedFrameRate,
    this.expectedVideoTrackMime,
    this.expectedAudioTrackMime,
    this.videoTrackCount = 0,
    this.audioTrackCount = 0,
    this.actualVideoTrackMime,
    this.actualAudioTrackMime,
    this.actualFrameRate,
    this.trackMimeTypes = const <String>[],
    this.width,
    this.height,
    this.videoRotationDegrees,
    this.mimeType,
    this.hasAudio,
  });

  final int fileSizeBytes;
  final int durationMs;
  final int expectedDurationMs;
  final int timelineDurationMs;
  final int durationDeltaMs;
  final bool hasVideo;
  final bool isDurationWithinTolerance;
  final bool expectedHasAudio;
  final bool? isFrameRateWithinTolerance;
  final int? expectedWidth;
  final int? expectedHeight;
  final int? expectedFrameRate;
  final String? expectedVideoTrackMime;
  final String? expectedAudioTrackMime;
  final int videoTrackCount;
  final int audioTrackCount;
  final String? actualVideoTrackMime;
  final String? actualAudioTrackMime;
  final int? actualFrameRate;
  final List<String> trackMimeTypes;
  final int? width;
  final int? height;
  final int? videoRotationDegrees;
  final String? mimeType;
  final bool? hasAudio;
}

@immutable
class ExportMotionTextParityDiagnostics {
  const ExportMotionTextParityDiagnostics({
    required this.status,
    required this.referencePathKind,
    required this.runtimePathKind,
    required this.blurExecutionMode,
    required this.glBlurSigmaPx,
    required this.glBlurDecisionCode,
    required this.glBlurDecisionDetail,
    required this.sampleCount,
    required this.sampledNodeCount,
    required this.comparedNodeCount,
    required this.missingRuntimeNodeCount,
    required this.unexpectedRuntimeNodeCount,
    required this.driftNodeCount,
    required this.textMismatchCount,
    required this.revealUnitMismatchCount,
    required this.anchorMismatchCount,
    required this.alignmentMismatchCount,
    required this.blendModeMismatchCount,
    required this.maxPositionDeltaPx,
    required this.maxScaleDelta,
    required this.maxRotationDelta,
    required this.maxOpacityDelta,
    required this.maxBlurDelta,
    required this.maxFontSizeDelta,
    required this.maxLetterSpacingDelta,
    required this.maxRevealProgressDelta,
    this.worstNodeId,
    this.worstTimeMs,
  });

  final String status;
  final String referencePathKind;
  final String runtimePathKind;
  final String blurExecutionMode;
  final double? glBlurSigmaPx;
  final String glBlurDecisionCode;
  final String? glBlurDecisionDetail;
  final int sampleCount;
  final int sampledNodeCount;
  final int comparedNodeCount;
  final int missingRuntimeNodeCount;
  final int unexpectedRuntimeNodeCount;
  final int driftNodeCount;
  final int textMismatchCount;
  final int revealUnitMismatchCount;
  final int anchorMismatchCount;
  final int alignmentMismatchCount;
  final int blendModeMismatchCount;
  final double maxPositionDeltaPx;
  final double maxScaleDelta;
  final double maxRotationDelta;
  final double maxOpacityDelta;
  final double maxBlurDelta;
  final double maxFontSizeDelta;
  final double maxLetterSpacingDelta;
  final double maxRevealProgressDelta;
  final String? worstNodeId;
  final int? worstTimeMs;
}

@immutable
class ExportCanonicalEffectsDiagnostics {
  const ExportCanonicalEffectsDiagnostics({
    required this.currentBackendId,
    required this.nodeCount,
    required this.operationCount,
    required this.relevantNodeCount,
    required this.relevantOperationCount,
    required this.supportedNodeCount,
    required this.baselineOnlyNodeCount,
    required this.approximationNodeCount,
    required this.blockedNodeCount,
    required this.supportedOperationCount,
    required this.baselineOnlyOperationCount,
    required this.approximationOperationCount,
    required this.blockedOperationCount,
    required this.nodeKinds,
    required this.operationKinds,
    this.firstBlockedNodeId,
    this.firstBlockedOperationId,
    this.firstBlockedDetail,
  });

  final String currentBackendId;
  final int nodeCount;
  final int operationCount;
  final int relevantNodeCount;
  final int relevantOperationCount;
  final int supportedNodeCount;
  final int baselineOnlyNodeCount;
  final int approximationNodeCount;
  final int blockedNodeCount;
  final int supportedOperationCount;
  final int baselineOnlyOperationCount;
  final int approximationOperationCount;
  final int blockedOperationCount;
  final String? firstBlockedNodeId;
  final String? firstBlockedOperationId;
  final String? firstBlockedDetail;
  final List<String> nodeKinds;
  final List<String> operationKinds;
}

@immutable
class ExportAuthoredVisualSurfaceDiagnostics {
  const ExportAuthoredVisualSurfaceDiagnostics({
    required this.status,
    required this.runtimePathKind,
    required this.nodeCount,
    required this.imageNodeCount,
    required this.shapeNodeCount,
    required this.maskNodeCount,
    required this.videoNodeCount,
    required this.animatedNodeCount,
    required this.blurCapableNodeCount,
    required this.compositorOwnedSegmentCount,
    required this.programBackedSegmentCount,
    required this.missingProgramNodeCount,
    required this.sampleCount,
    required this.activeNodeCount,
    required this.activeAnimatedNodeCount,
    required this.activeBlurNodeCount,
    required this.normalBlendNodeCount,
    required this.surfaceEffectEligibleNodeCount,
    required this.maxConcurrentActiveNodeCount,
    required this.maxResolvedBlurAmount,
    required this.sourceKinds,
    this.firstMissingProgramNodeId,
    this.firstResolvedNodeId,
    this.detail,
  });

  final String status;
  final String runtimePathKind;
  final int nodeCount;
  final int imageNodeCount;
  final int shapeNodeCount;
  final int maskNodeCount;
  final int videoNodeCount;
  final int animatedNodeCount;
  final int blurCapableNodeCount;
  final int compositorOwnedSegmentCount;
  final int programBackedSegmentCount;
  final int missingProgramNodeCount;
  final int sampleCount;
  final int activeNodeCount;
  final int activeAnimatedNodeCount;
  final int activeBlurNodeCount;
  final int normalBlendNodeCount;
  final int surfaceEffectEligibleNodeCount;
  final int maxConcurrentActiveNodeCount;
  final double maxResolvedBlurAmount;
  final String? firstMissingProgramNodeId;
  final String? firstResolvedNodeId;
  final List<String> sourceKinds;
  final String? detail;
}

@immutable
class ExportVisualAssemblyRouteDiagnostics {
  const ExportVisualAssemblyRouteDiagnostics({
    required this.clipId,
    required this.coveredWindowIds,
    required this.route,
    required this.timelineStartMs,
    required this.timelineEndExclusiveMs,
    required this.activeLayerIds,
    required this.activeSegmentIds,
    this.graphSegmentId,
    this.graphLayerId,
    this.graphWindowId,
    this.graphZOrder,
    this.graphAssemblyOrder,
  });

  final String clipId;
  final String? graphSegmentId;
  final String? graphLayerId;
  final String? graphWindowId;
  final List<String> coveredWindowIds;
  final int? graphZOrder;
  final int? graphAssemblyOrder;
  final String route;
  final int timelineStartMs;
  final int timelineEndExclusiveMs;
  final List<String> activeLayerIds;
  final List<String> activeSegmentIds;
}

@immutable
class ExportVisualCompositorRouteDiagnostics {
  const ExportVisualCompositorRouteDiagnostics({
    required this.windowId,
    required this.executionOwner,
    required this.result,
    required this.detail,
    required this.overlayClipIds,
    required this.orderedLayerIds,
    required this.orderedSegmentIds,
    required this.mediaSegmentIds,
    required this.authoredSegmentIds,
    required this.authoredNodeIds,
    required this.isExecutable,
    this.baseClipId,
  });

  final String windowId;
  final String executionOwner;
  final String result;
  final String detail;
  final String? baseClipId;
  final List<String> overlayClipIds;
  final List<String> orderedLayerIds;
  final List<String> orderedSegmentIds;
  final List<String> mediaSegmentIds;
  final List<String> authoredSegmentIds;
  final List<String> authoredNodeIds;
  final bool isExecutable;
}

@immutable
class ExportVisualAssemblyDiagnostics {
  const ExportVisualAssemblyDiagnostics({
    required this.status,
    required this.routeCount,
    required this.mediaOnlyRouteCount,
    required this.overlayRouteCount,
    required this.blockedRouteCount,
    required this.compositorWindowCount,
    required this.executableCompositorWindowCount,
    required this.blockedCompositorWindowCount,
    required this.routes,
    required this.compositorRoutes,
    this.firstBlockedWindowId,
    this.firstBlockedClipId,
    this.firstBlockedDetail,
  });

  final String status;
  final int routeCount;
  final int mediaOnlyRouteCount;
  final int overlayRouteCount;
  final int blockedRouteCount;
  final int compositorWindowCount;
  final int executableCompositorWindowCount;
  final int blockedCompositorWindowCount;
  final String? firstBlockedWindowId;
  final String? firstBlockedClipId;
  final String? firstBlockedDetail;
  final List<ExportVisualAssemblyRouteDiagnostics> routes;
  final List<ExportVisualCompositorRouteDiagnostics> compositorRoutes;
}

@immutable
class ExportJobState {
  const ExportJobState({
    this.jobId,
    this.status = ExportJobStatus.idle,
    this.progress = 0,
    this.phase,
    this.outputPath,
    this.error,
    this.validation,
    this.motionTextParity,
    this.canonicalEffectsDiagnostics,
    this.authoredVisualSurfaceDiagnostics,
    this.visualAssemblyDiagnostics,
    this.cleanupPerformed = false,
    this.preset,
    this.requestedFrameRate,
    this.requestedVideoBitrate,
    this.requestedAudioBitrate,
    this.selectedEncoderName,
    this.clipCount,
    this.requestedDurationMs,
    this.timelineDurationMs,
    this.startedAtMillis,
    this.estimatedRemainingMs,
  });

  final String? jobId;
  final ExportJobStatus status;
  final double progress;
  final String? phase;
  final String? outputPath;
  final String? error;
  final ExportOutputValidation? validation;
  final ExportMotionTextParityDiagnostics? motionTextParity;
  final ExportCanonicalEffectsDiagnostics? canonicalEffectsDiagnostics;
  final ExportAuthoredVisualSurfaceDiagnostics?
      authoredVisualSurfaceDiagnostics;
  final ExportVisualAssemblyDiagnostics? visualAssemblyDiagnostics;
  final bool cleanupPerformed;
  final String? preset;
  final int? requestedFrameRate;
  final int? requestedVideoBitrate;
  final int? requestedAudioBitrate;
  final String? selectedEncoderName;
  final int? clipCount;
  final int? requestedDurationMs;
  final int? timelineDurationMs;
  final int? startedAtMillis;
  final int? estimatedRemainingMs;

  bool get isActive =>
      status == ExportJobStatus.queued ||
      status == ExportJobStatus.started ||
      status == ExportJobStatus.progress;

  ExportJobState copyWith({
    Object? jobId = _noChange,
    ExportJobStatus? status,
    double? progress,
    Object? phase = _noChange,
    Object? outputPath = _noChange,
    Object? error = _noChange,
    Object? validation = _noChange,
    Object? motionTextParity = _noChange,
    Object? canonicalEffectsDiagnostics = _noChange,
    Object? authoredVisualSurfaceDiagnostics = _noChange,
    Object? visualAssemblyDiagnostics = _noChange,
    bool? cleanupPerformed,
    Object? preset = _noChange,
    Object? requestedFrameRate = _noChange,
    Object? requestedVideoBitrate = _noChange,
    Object? requestedAudioBitrate = _noChange,
    Object? selectedEncoderName = _noChange,
    Object? clipCount = _noChange,
    Object? requestedDurationMs = _noChange,
    Object? timelineDurationMs = _noChange,
    Object? startedAtMillis = _noChange,
    Object? estimatedRemainingMs = _noChange,
  }) {
    return ExportJobState(
      jobId: identical(jobId, _noChange) ? this.jobId : jobId as String?,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      phase: identical(phase, _noChange) ? this.phase : phase as String?,
      outputPath: identical(outputPath, _noChange)
          ? this.outputPath
          : outputPath as String?,
      error: identical(error, _noChange) ? this.error : error as String?,
      validation: identical(validation, _noChange)
          ? this.validation
          : validation as ExportOutputValidation?,
      motionTextParity: identical(motionTextParity, _noChange)
          ? this.motionTextParity
          : motionTextParity as ExportMotionTextParityDiagnostics?,
      canonicalEffectsDiagnostics: identical(
              canonicalEffectsDiagnostics, _noChange)
          ? this.canonicalEffectsDiagnostics
          : canonicalEffectsDiagnostics as ExportCanonicalEffectsDiagnostics?,
      authoredVisualSurfaceDiagnostics:
          identical(authoredVisualSurfaceDiagnostics, _noChange)
              ? this.authoredVisualSurfaceDiagnostics
              : authoredVisualSurfaceDiagnostics
                  as ExportAuthoredVisualSurfaceDiagnostics?,
      visualAssemblyDiagnostics: identical(visualAssemblyDiagnostics, _noChange)
          ? this.visualAssemblyDiagnostics
          : visualAssemblyDiagnostics as ExportVisualAssemblyDiagnostics?,
      cleanupPerformed: cleanupPerformed ?? this.cleanupPerformed,
      preset: identical(preset, _noChange) ? this.preset : preset as String?,
      requestedFrameRate: identical(requestedFrameRate, _noChange)
          ? this.requestedFrameRate
          : requestedFrameRate as int?,
      requestedVideoBitrate: identical(requestedVideoBitrate, _noChange)
          ? this.requestedVideoBitrate
          : requestedVideoBitrate as int?,
      requestedAudioBitrate: identical(requestedAudioBitrate, _noChange)
          ? this.requestedAudioBitrate
          : requestedAudioBitrate as int?,
      selectedEncoderName: identical(selectedEncoderName, _noChange)
          ? this.selectedEncoderName
          : selectedEncoderName as String?,
      clipCount:
          identical(clipCount, _noChange) ? this.clipCount : clipCount as int?,
      requestedDurationMs: identical(requestedDurationMs, _noChange)
          ? this.requestedDurationMs
          : requestedDurationMs as int?,
      timelineDurationMs: identical(timelineDurationMs, _noChange)
          ? this.timelineDurationMs
          : timelineDurationMs as int?,
      startedAtMillis: identical(startedAtMillis, _noChange)
          ? this.startedAtMillis
          : startedAtMillis as int?,
      estimatedRemainingMs: identical(estimatedRemainingMs, _noChange)
          ? this.estimatedRemainingMs
          : estimatedRemainingMs as int?,
    );
  }
}

enum ExportQualityPreset {
  draft720p,
  fullHd1080p,
  originalSize,
}

enum ExportFrameRatePreset {
  fps30(30),
  fps60(60),
  fps90(90),
  fps120(120);

  const ExportFrameRatePreset(this.framesPerSecond);

  final int framesPerSecond;

  static ExportFrameRatePreset closestTo(double framesPerSecond) {
    return ExportFrameRatePreset.values.reduce(
      (currentBest, candidate) {
        final currentDelta =
            (currentBest.framesPerSecond - framesPerSecond).abs();
        final candidateDelta =
            (candidate.framesPerSecond - framesPerSecond).abs();
        return candidateDelta < currentDelta ? candidate : currentBest;
      },
    );
  }
}

class Stage6ExportController extends ChangeNotifier {
  Stage6ExportController();

  static const String methodChannelName = 'com.refusion.app/stage6_export';
  static const String eventChannelName =
      'com.refusion.app/stage6_export_events';

  static const MethodChannel _methodChannel = MethodChannel(methodChannelName);
  static const EventChannel _eventChannel = EventChannel(eventChannelName);

  ExportJobState _state = const ExportJobState();
  StreamSubscription<dynamic>? _eventsSubscription;
  int? _activeJobStartMillis;

  ExportJobState get state => _state;

  bool get isPlatformSupported => !kIsWeb && Platform.isAndroid;

  Future<void> ensureInitialized() async {
    if (!isPlatformSupported) {
      return;
    }
    _eventsSubscription ??= _eventChannel.receiveBroadcastStream().listen(
          _handleEvent,
          onError: _handleError,
        );
  }

  Future<String?> startExport({
    required ExportComposition composition,
    ExportQualityPreset preset = ExportQualityPreset.fullHd1080p,
    ExportFrameRatePreset frameRate = ExportFrameRatePreset.fps30,
    String? requestedFileName,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    await ensureInitialized();
    dynamic result;
    try {
      result = await _methodChannel.invokeMethod<dynamic>(
        'exportTimeline',
        <String, dynamic>{
          'composition': composition.toBridgeMap(),
          'preset': preset.name,
          'requestedFrameRate': frameRate.framesPerSecond,
          if (requestedFileName != null && requestedFileName.isNotEmpty)
            'requestedFileName': requestedFileName,
        },
      );
    } on PlatformException catch (error) {
      _activeJobStartMillis = null;
      _state = _state.copyWith(
        status: ExportJobStatus.failed,
        phase: 'bridge_failed',
        error: error.message ?? 'Unable to start export right now.',
        estimatedRemainingMs: null,
      );
      notifyListeners();
      return null;
    }
    final normalized = _normalizeMap(result);
    final jobId = normalized['jobId']?.toString();
    final incomingStatus = _parseStatus(normalized['status']?.toString());
    final status = _resolvePreferredStatus(jobId, incomingStatus);
    final progress = _readProgress(normalized['progress']);
    _updateStartClock(status, jobId);
    final resolvedProgress =
        status == incomingStatus ? progress : _state.progress;
    _state = _state.copyWith(
      jobId: jobId,
      status: status,
      phase: _preferCurrentValue(
        jobId: jobId,
        incomingValue: normalized['phase']?.toString(),
        currentValue: _state.phase,
        incomingStatus: incomingStatus,
      ),
      progress: resolvedProgress,
      outputPath: _preferCurrentValue(
        jobId: jobId,
        incomingValue: normalized['outputPath']?.toString(),
        currentValue: _state.outputPath,
        incomingStatus: incomingStatus,
      ),
      error: _preferCurrentValue(
        jobId: jobId,
        incomingValue: normalized['error']?.toString(),
        currentValue: _state.error,
        incomingStatus: incomingStatus,
      ),
      validation: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readValidation(normalized['validation']),
        currentValue: _state.validation,
        incomingStatus: incomingStatus,
      ),
      motionTextParity: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readMotionTextParity(normalized['motionTextParity']),
        currentValue: _state.motionTextParity,
        incomingStatus: incomingStatus,
      ),
      canonicalEffectsDiagnostics: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readCanonicalEffectsDiagnostics(
          normalized['canonicalEffectsDiagnostics'],
        ),
        currentValue: _state.canonicalEffectsDiagnostics,
        incomingStatus: incomingStatus,
      ),
      authoredVisualSurfaceDiagnostics: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readAuthoredVisualSurfaceDiagnostics(
          normalized['authoredVisualSurfaceDiagnostics'],
        ),
        currentValue: _state.authoredVisualSurfaceDiagnostics,
        incomingStatus: incomingStatus,
      ),
      visualAssemblyDiagnostics: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readVisualAssemblyDiagnostics(
          normalized['visualAssemblyDiagnostics'],
        ),
        currentValue: _state.visualAssemblyDiagnostics,
        incomingStatus: incomingStatus,
      ),
      cleanupPerformed: _preferCurrentCleanup(
        jobId: jobId,
        incomingCleanup: _readBool(normalized['cleanupPerformed']),
        incomingStatus: incomingStatus,
      ),
      preset: _preferCurrentValue(
        jobId: jobId,
        incomingValue: normalized['preset']?.toString(),
        currentValue: _state.preset,
        incomingStatus: incomingStatus,
      ),
      requestedFrameRate: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readNullableInt(normalized['requestedFrameRate']),
        currentValue: _state.requestedFrameRate,
        incomingStatus: incomingStatus,
      ),
      requestedVideoBitrate: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readNullableInt(normalized['requestedVideoBitrate']),
        currentValue: _state.requestedVideoBitrate,
        incomingStatus: incomingStatus,
      ),
      requestedAudioBitrate: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readNullableInt(normalized['requestedAudioBitrate']),
        currentValue: _state.requestedAudioBitrate,
        incomingStatus: incomingStatus,
      ),
      selectedEncoderName: _preferCurrentValue(
        jobId: jobId,
        incomingValue: normalized['selectedEncoderName']?.toString(),
        currentValue: _state.selectedEncoderName,
        incomingStatus: incomingStatus,
      ),
      clipCount: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readNullableInt(normalized['clipCount']),
        currentValue: _state.clipCount,
        incomingStatus: incomingStatus,
      ),
      requestedDurationMs: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readNullableInt(normalized['durationMs']),
        currentValue: _state.requestedDurationMs,
        incomingStatus: incomingStatus,
      ),
      timelineDurationMs: _preferCurrentValue(
        jobId: jobId,
        incomingValue: _readNullableInt(normalized['timelineDurationMs']),
        currentValue: _state.timelineDurationMs,
        incomingStatus: incomingStatus,
      ),
      startedAtMillis: _activeJobStartMillis,
      estimatedRemainingMs: _estimateRemainingMs(resolvedProgress),
    );
    notifyListeners();
    return jobId;
  }

  Future<void> cancelExport([String? jobId]) async {
    if (!isPlatformSupported) {
      return;
    }
    final resolvedJobId = jobId ?? _state.jobId;
    if (resolvedJobId == null || resolvedJobId.isEmpty) {
      return;
    }
    await ensureInitialized();
    await _methodChannel.invokeMethod<void>(
      'cancelExport',
      <String, dynamic>{'jobId': resolvedJobId},
    );
  }

  Future<bool> openExportOutput({
    required String outputPath,
    String? mimeType,
  }) async {
    if (!isPlatformSupported) {
      return false;
    }
    await ensureInitialized();
    final result = await _methodChannel.invokeMethod<dynamic>(
      'openExportOutput',
      <String, dynamic>{
        'outputPath': outputPath,
        if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
      },
    );
    final normalized = _normalizeMap(result);
    final status = normalized['status']?.toString();
    return status == 'opened';
  }

  Future<bool> shareExportOutput({
    required String outputPath,
    String? mimeType,
  }) async {
    if (!isPlatformSupported) {
      return false;
    }
    await ensureInitialized();
    final result = await _methodChannel.invokeMethod<dynamic>(
      'shareExportOutput',
      <String, dynamic>{
        'outputPath': outputPath,
        if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
      },
    );
    final normalized = _normalizeMap(result);
    final status = normalized['status']?.toString();
    return status == 'shared';
  }

  Future<String?> saveExportOutputToGallery({
    required String outputPath,
    String? mimeType,
  }) async {
    if (!isPlatformSupported) {
      return null;
    }
    await ensureInitialized();
    final result = await _methodChannel.invokeMethod<dynamic>(
      'saveExportOutputToGallery',
      <String, dynamic>{
        'outputPath': outputPath,
        if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
      },
    );
    final normalized = _normalizeMap(result);
    final status = normalized['status']?.toString();
    if (status != 'saved') {
      return null;
    }
    return normalized['savedUri']?.toString();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    super.dispose();
  }

  void _handleEvent(dynamic event) {
    final data = _normalizeMap(event);
    if (data.isEmpty) {
      return;
    }
    final status = _parseStatus(data['status']?.toString());
    final jobId = data['jobId']?.toString();
    final progress = _readProgress(data['progress']);
    _updateStartClock(status, jobId);
    _state = _state.copyWith(
      jobId: jobId,
      status: status,
      progress: progress,
      phase: data.containsKey('phase') ? data['phase']?.toString() : _noChange,
      outputPath: data.containsKey('outputPath')
          ? data['outputPath']?.toString()
          : _noChange,
      error: data.containsKey('error') ? data['error']?.toString() : _noChange,
      validation: data.containsKey('validation')
          ? _readValidation(data['validation'])
          : _noChange,
      motionTextParity: data.containsKey('motionTextParity')
          ? _readMotionTextParity(data['motionTextParity'])
          : _noChange,
      canonicalEffectsDiagnostics:
          data.containsKey('canonicalEffectsDiagnostics')
              ? _readCanonicalEffectsDiagnostics(
                  data['canonicalEffectsDiagnostics'])
              : _noChange,
      authoredVisualSurfaceDiagnostics:
          data.containsKey('authoredVisualSurfaceDiagnostics')
              ? _readAuthoredVisualSurfaceDiagnostics(
                  data['authoredVisualSurfaceDiagnostics'],
                )
              : _noChange,
      visualAssemblyDiagnostics: data.containsKey('visualAssemblyDiagnostics')
          ? _readVisualAssemblyDiagnostics(data['visualAssemblyDiagnostics'])
          : _noChange,
      cleanupPerformed: _readBool(data['cleanupPerformed']),
      preset:
          data.containsKey('preset') ? data['preset']?.toString() : _noChange,
      requestedFrameRate: data.containsKey('requestedFrameRate')
          ? _readNullableInt(data['requestedFrameRate'])
          : _noChange,
      requestedVideoBitrate: data.containsKey('requestedVideoBitrate')
          ? _readNullableInt(data['requestedVideoBitrate'])
          : _noChange,
      requestedAudioBitrate: data.containsKey('requestedAudioBitrate')
          ? _readNullableInt(data['requestedAudioBitrate'])
          : _noChange,
      selectedEncoderName: data.containsKey('selectedEncoderName')
          ? data['selectedEncoderName']?.toString()
          : _noChange,
      clipCount: data.containsKey('clipCount')
          ? _readNullableInt(data['clipCount'])
          : _noChange,
      requestedDurationMs: data.containsKey('durationMs')
          ? _readNullableInt(data['durationMs'])
          : _noChange,
      timelineDurationMs: data.containsKey('timelineDurationMs')
          ? _readNullableInt(data['timelineDurationMs'])
          : _noChange,
      startedAtMillis: _activeJobStartMillis,
      estimatedRemainingMs: _estimateRemainingMs(progress),
    );
    notifyListeners();
  }

  void _handleError(Object error) {
    _activeJobStartMillis = null;
    _state = _state.copyWith(
      status: ExportJobStatus.failed,
      error: error.toString(),
      estimatedRemainingMs: null,
    );
    notifyListeners();
  }

  ExportJobStatus _parseStatus(String? rawStatus) {
    return switch (rawStatus) {
      'queued' => ExportJobStatus.queued,
      'started' => ExportJobStatus.started,
      'progress' => ExportJobStatus.progress,
      'completed' => ExportJobStatus.completed,
      'failed' => ExportJobStatus.failed,
      'cancelled' => ExportJobStatus.cancelled,
      _ => ExportJobStatus.idle,
    };
  }

  ExportJobStatus _resolvePreferredStatus(
    String? jobId,
    ExportJobStatus incomingStatus,
  ) {
    if (jobId == null || jobId.isEmpty || _state.jobId != jobId) {
      return incomingStatus;
    }
    return _statusRank(_state.status) > _statusRank(incomingStatus)
        ? _state.status
        : incomingStatus;
  }

  T? _preferCurrentValue<T>({
    required String? jobId,
    required T? incomingValue,
    required T? currentValue,
    required ExportJobStatus incomingStatus,
  }) {
    if (jobId == null || jobId.isEmpty || _state.jobId != jobId) {
      return incomingValue;
    }
    if (_statusRank(_state.status) > _statusRank(incomingStatus)) {
      return currentValue;
    }
    return incomingValue;
  }

  bool _preferCurrentCleanup({
    required String? jobId,
    required bool incomingCleanup,
    required ExportJobStatus incomingStatus,
  }) {
    if (jobId == null || jobId.isEmpty || _state.jobId != jobId) {
      return incomingCleanup;
    }
    if (_statusRank(_state.status) > _statusRank(incomingStatus)) {
      return _state.cleanupPerformed;
    }
    return incomingCleanup;
  }

  int _statusRank(ExportJobStatus status) {
    return switch (status) {
      ExportJobStatus.idle => 0,
      ExportJobStatus.queued => 1,
      ExportJobStatus.started => 2,
      ExportJobStatus.progress => 3,
      ExportJobStatus.completed => 4,
      ExportJobStatus.failed => 4,
      ExportJobStatus.cancelled => 4,
    };
  }

  double _readProgress(Object? rawProgress) {
    final value = switch (rawProgress) {
      int number => number.toDouble(),
      double number => number,
      _ => 0.0,
    };
    if (!value.isFinite) {
      return 0.0;
    }
    return value.clamp(0.0, 1.0);
  }

  ExportOutputValidation? _readValidation(Object? rawValidation) {
    final validation = _normalizeMap(rawValidation);
    if (validation.isEmpty) {
      return null;
    }
    return ExportOutputValidation(
      fileSizeBytes: _readInt(validation['fileSizeBytes']),
      durationMs: _readInt(validation['durationMs']),
      expectedDurationMs: _readInt(validation['expectedDurationMs']),
      timelineDurationMs: _readInt(validation['timelineDurationMs']),
      durationDeltaMs: _readInt(validation['durationDeltaMs']),
      hasVideo: _readBool(validation['hasVideo']),
      isDurationWithinTolerance:
          _readBool(validation['isDurationWithinTolerance']),
      expectedHasAudio: _readBool(validation['expectedHasAudio']),
      isFrameRateWithinTolerance:
          _readNullableBool(validation['isFrameRateWithinTolerance']),
      expectedWidth: _readNullableInt(validation['expectedWidth']),
      expectedHeight: _readNullableInt(validation['expectedHeight']),
      expectedFrameRate: _readNullableInt(validation['expectedFrameRate']),
      expectedVideoTrackMime: validation['expectedVideoTrackMime']?.toString(),
      expectedAudioTrackMime: validation['expectedAudioTrackMime']?.toString(),
      videoTrackCount: _readInt(validation['videoTrackCount']),
      audioTrackCount: _readInt(validation['audioTrackCount']),
      actualVideoTrackMime: validation['actualVideoTrackMime']?.toString(),
      actualAudioTrackMime: validation['actualAudioTrackMime']?.toString(),
      actualFrameRate: _readNullableInt(validation['actualFrameRate']),
      trackMimeTypes:
          (validation['trackMimeTypes'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString())
              .toList(growable: false),
      width: _readNullableInt(validation['width']),
      height: _readNullableInt(validation['height']),
      videoRotationDegrees:
          _readNullableInt(validation['videoRotationDegrees']),
      mimeType: validation['mimeType']?.toString(),
      hasAudio: _readNullableBool(validation['hasAudio']),
    );
  }

  ExportMotionTextParityDiagnostics? _readMotionTextParity(Object? rawParity) {
    final parity = _normalizeMap(rawParity);
    if (parity.isEmpty) {
      return null;
    }
    return ExportMotionTextParityDiagnostics(
      status: parity['status']?.toString() ?? 'unknown',
      referencePathKind:
          parity['referencePathKind']?.toString() ?? 'sampled_track',
      runtimePathKind: parity['runtimePathKind']?.toString() ?? 'program',
      blurExecutionMode:
          parity['blurExecutionMode']?.toString() ?? 'software_local',
      glBlurSigmaPx: _readNullableDouble(parity['glBlurSigmaPx']),
      glBlurDecisionCode:
          parity['glBlurDecisionCode']?.toString() ?? 'software_local_default',
      glBlurDecisionDetail: parity['glBlurDecisionDetail']?.toString(),
      sampleCount: _readInt(parity['sampleCount']),
      sampledNodeCount: _readInt(parity['sampledNodeCount']),
      comparedNodeCount: _readInt(parity['comparedNodeCount']),
      missingRuntimeNodeCount: _readInt(
        parity['missingRuntimeNodeCount'] ?? parity['missingProgramNodeCount'],
      ),
      unexpectedRuntimeNodeCount: _readInt(
        parity['unexpectedRuntimeNodeCount'] ??
            parity['unexpectedProgramNodeCount'],
      ),
      driftNodeCount: _readInt(parity['driftNodeCount']),
      textMismatchCount: _readInt(parity['textMismatchCount']),
      revealUnitMismatchCount: _readInt(parity['revealUnitMismatchCount']),
      anchorMismatchCount: _readInt(parity['anchorMismatchCount']),
      alignmentMismatchCount: _readInt(parity['alignmentMismatchCount']),
      blendModeMismatchCount: _readInt(parity['blendModeMismatchCount']),
      maxPositionDeltaPx: _readDouble(parity['maxPositionDeltaPx']),
      maxScaleDelta: _readDouble(parity['maxScaleDelta']),
      maxRotationDelta: _readDouble(parity['maxRotationDelta']),
      maxOpacityDelta: _readDouble(parity['maxOpacityDelta']),
      maxBlurDelta: _readDouble(parity['maxBlurDelta']),
      maxFontSizeDelta: _readDouble(parity['maxFontSizeDelta']),
      maxLetterSpacingDelta: _readDouble(parity['maxLetterSpacingDelta']),
      maxRevealProgressDelta: _readDouble(parity['maxRevealProgressDelta']),
      worstNodeId: parity['worstNodeId']?.toString(),
      worstTimeMs: _readNullableInt(parity['worstTimeMs']),
    );
  }

  ExportCanonicalEffectsDiagnostics? _readCanonicalEffectsDiagnostics(
    Object? rawDiagnostics,
  ) {
    final diagnostics = _normalizeMap(rawDiagnostics);
    if (diagnostics.isEmpty) {
      return null;
    }
    return ExportCanonicalEffectsDiagnostics(
      currentBackendId: diagnostics['currentBackendId']?.toString() ??
          'media3CanvasOverlayRenderer',
      nodeCount: _readInt(diagnostics['nodeCount']),
      operationCount: _readInt(diagnostics['operationCount']),
      relevantNodeCount: _readInt(diagnostics['relevantNodeCount']),
      relevantOperationCount: _readInt(diagnostics['relevantOperationCount']),
      supportedNodeCount: _readInt(diagnostics['supportedNodeCount']),
      baselineOnlyNodeCount: _readInt(diagnostics['baselineOnlyNodeCount']),
      approximationNodeCount: _readInt(diagnostics['approximationNodeCount']),
      blockedNodeCount: _readInt(diagnostics['blockedNodeCount']),
      supportedOperationCount: _readInt(diagnostics['supportedOperationCount']),
      baselineOnlyOperationCount: _readInt(
        diagnostics['baselineOnlyOperationCount'],
      ),
      approximationOperationCount: _readInt(
        diagnostics['approximationOperationCount'],
      ),
      blockedOperationCount: _readInt(diagnostics['blockedOperationCount']),
      firstBlockedNodeId: diagnostics['firstBlockedNodeId']?.toString(),
      firstBlockedOperationId:
          diagnostics['firstBlockedOperationId']?.toString(),
      firstBlockedDetail: diagnostics['firstBlockedDetail']?.toString(),
      nodeKinds:
          (diagnostics['nodeKinds'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .toList(growable: false),
      operationKinds:
          (diagnostics['operationKinds'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .toList(growable: false),
    );
  }

  ExportAuthoredVisualSurfaceDiagnostics? _readAuthoredVisualSurfaceDiagnostics(
    Object? rawDiagnostics,
  ) {
    final diagnostics = _normalizeMap(rawDiagnostics);
    if (diagnostics.isEmpty) {
      return null;
    }
    return ExportAuthoredVisualSurfaceDiagnostics(
      status: diagnostics['status']?.toString() ?? 'unknown',
      runtimePathKind: diagnostics['runtimePathKind']?.toString() ?? 'unknown',
      nodeCount: _readInt(diagnostics['nodeCount']),
      imageNodeCount: _readInt(diagnostics['imageNodeCount']),
      shapeNodeCount: _readInt(diagnostics['shapeNodeCount']),
      maskNodeCount: _readInt(diagnostics['maskNodeCount']),
      videoNodeCount: _readInt(diagnostics['videoNodeCount']),
      animatedNodeCount: _readInt(diagnostics['animatedNodeCount']),
      blurCapableNodeCount: _readInt(diagnostics['blurCapableNodeCount']),
      compositorOwnedSegmentCount: _readInt(
        diagnostics['compositorOwnedSegmentCount'],
      ),
      programBackedSegmentCount:
          _readInt(diagnostics['programBackedSegmentCount']),
      missingProgramNodeCount: _readInt(diagnostics['missingProgramNodeCount']),
      sampleCount: _readInt(diagnostics['sampleCount']),
      activeNodeCount: _readInt(diagnostics['activeNodeCount']),
      activeAnimatedNodeCount: _readInt(diagnostics['activeAnimatedNodeCount']),
      activeBlurNodeCount: _readInt(diagnostics['activeBlurNodeCount']),
      normalBlendNodeCount: _readInt(diagnostics['normalBlendNodeCount']),
      surfaceEffectEligibleNodeCount: _readInt(
        diagnostics['surfaceEffectEligibleNodeCount'],
      ),
      maxConcurrentActiveNodeCount: _readInt(
        diagnostics['maxConcurrentActiveNodeCount'],
      ),
      maxResolvedBlurAmount: _readDouble(diagnostics['maxResolvedBlurAmount']),
      firstMissingProgramNodeId:
          diagnostics['firstMissingProgramNodeId']?.toString(),
      firstResolvedNodeId: diagnostics['firstResolvedNodeId']?.toString(),
      sourceKinds:
          (diagnostics['sourceKinds'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .toList(growable: false),
      detail: diagnostics['detail']?.toString(),
    );
  }

  ExportVisualAssemblyDiagnostics? _readVisualAssemblyDiagnostics(
    Object? rawDiagnostics,
  ) {
    final diagnostics = _normalizeMap(rawDiagnostics);
    if (diagnostics.isEmpty) {
      return null;
    }
    final routes = (diagnostics['routes'] as List<dynamic>? ??
            const <dynamic>[])
        .map((entry) => _normalizeMap(entry))
        .where((entry) => entry.isNotEmpty)
        .map(
          (entry) => ExportVisualAssemblyRouteDiagnostics(
            clipId: entry['clipId']?.toString() ?? '',
            graphSegmentId: entry['graphSegmentId']?.toString(),
            graphLayerId: entry['graphLayerId']?.toString(),
            graphWindowId: entry['graphWindowId']?.toString(),
            coveredWindowIds: (entry['coveredWindowIds'] as List<dynamic>? ??
                    const <dynamic>[])
                .map((value) => value.toString())
                .toList(growable: false),
            graphZOrder: _readNullableInt(entry['graphZOrder']),
            graphAssemblyOrder: _readNullableInt(entry['graphAssemblyOrder']),
            route: entry['route']?.toString() ?? 'unknown',
            timelineStartMs: _readInt(entry['timelineStartMs']),
            timelineEndExclusiveMs: _readInt(entry['timelineEndExclusiveMs']),
            activeLayerIds:
                (entry['activeLayerIds'] as List<dynamic>? ?? const <dynamic>[])
                    .map((value) => value.toString())
                    .toList(growable: false),
            activeSegmentIds: (entry['activeSegmentIds'] as List<dynamic>? ??
                    const <dynamic>[])
                .map((value) => value.toString())
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    final compositorRoutes =
        (diagnostics['compositorRoutes'] as List<dynamic>? ?? const <dynamic>[])
            .map((entry) => _normalizeMap(entry))
            .where((entry) => entry.isNotEmpty)
            .map(
              (entry) => ExportVisualCompositorRouteDiagnostics(
                windowId: entry['windowId']?.toString() ?? '',
                executionOwner:
                    entry['executionOwner']?.toString() ?? 'unknown',
                result: entry['result']?.toString() ?? 'unknown',
                detail: entry['detail']?.toString() ?? '-',
                baseClipId: entry['baseClipId']?.toString(),
                overlayClipIds: (entry['overlayClipIds'] as List<dynamic>? ??
                        const <dynamic>[])
                    .map((value) => value.toString())
                    .toList(growable: false),
                orderedLayerIds: (entry['orderedLayerIds'] as List<dynamic>? ??
                        const <dynamic>[])
                    .map((value) => value.toString())
                    .toList(growable: false),
                orderedSegmentIds:
                    (entry['orderedSegmentIds'] as List<dynamic>? ??
                            const <dynamic>[])
                        .map((value) => value.toString())
                        .toList(growable: false),
                mediaSegmentIds: (entry['mediaSegmentIds'] as List<dynamic>? ??
                        const <dynamic>[])
                    .map((value) => value.toString())
                    .toList(growable: false),
                authoredSegmentIds:
                    (entry['authoredSegmentIds'] as List<dynamic>? ??
                            const <dynamic>[])
                        .map((value) => value.toString())
                        .toList(growable: false),
                authoredNodeIds: (entry['authoredNodeIds'] as List<dynamic>? ??
                        const <dynamic>[])
                    .map((value) => value.toString())
                    .toList(growable: false),
                isExecutable: _readBool(entry['isExecutable']),
              ),
            )
            .toList(growable: false);
    return ExportVisualAssemblyDiagnostics(
      status: diagnostics['status']?.toString() ?? 'unknown',
      routeCount: _readInt(diagnostics['routeCount']),
      mediaOnlyRouteCount: _readInt(diagnostics['mediaOnlyRouteCount']),
      overlayRouteCount: _readInt(diagnostics['overlayRouteCount']),
      blockedRouteCount: _readInt(diagnostics['blockedRouteCount']),
      compositorWindowCount: _readInt(diagnostics['compositorWindowCount']),
      executableCompositorWindowCount:
          _readInt(diagnostics['executableCompositorWindowCount']),
      blockedCompositorWindowCount:
          _readInt(diagnostics['blockedCompositorWindowCount']),
      firstBlockedWindowId: diagnostics['firstBlockedWindowId']?.toString(),
      firstBlockedClipId: diagnostics['firstBlockedClipId']?.toString(),
      firstBlockedDetail: diagnostics['firstBlockedDetail']?.toString(),
      routes: routes,
      compositorRoutes: compositorRoutes,
    );
  }

  int _readInt(Object? rawValue) {
    return switch (rawValue) {
      int number => number,
      double number => number.round(),
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };
  }

  int? _readNullableInt(Object? rawValue) {
    final value = _readInt(rawValue);
    return value > 0 ? value : null;
  }

  double _readDouble(Object? rawValue) {
    return switch (rawValue) {
      int number => number.toDouble(),
      double number => number,
      String text => double.tryParse(text) ?? 0.0,
      _ => 0.0,
    };
  }

  double? _readNullableDouble(Object? rawValue) {
    return switch (rawValue) {
      null => null,
      _ => _readDouble(rawValue),
    };
  }

  bool _readBool(Object? rawValue) {
    return switch (rawValue) {
      bool value => value,
      int value => value != 0,
      double value => value != 0,
      String text => text == 'true' || text == '1' || text == 'yes',
      _ => false,
    };
  }

  bool? _readNullableBool(Object? rawValue) {
    return switch (rawValue) {
      null => null,
      _ => _readBool(rawValue),
    };
  }

  void _updateStartClock(ExportJobStatus status, String? jobId) {
    final isRunning = status == ExportJobStatus.queued ||
        status == ExportJobStatus.started ||
        status == ExportJobStatus.progress;
    if (isRunning && jobId != null && jobId.isNotEmpty) {
      _activeJobStartMillis ??= DateTime.now().millisecondsSinceEpoch;
      return;
    }
    if (status == ExportJobStatus.completed ||
        status == ExportJobStatus.failed ||
        status == ExportJobStatus.cancelled ||
        status == ExportJobStatus.idle) {
      _activeJobStartMillis = null;
    }
  }

  int? _estimateRemainingMs(double progress) {
    final startedAtMillis = _activeJobStartMillis;
    if (startedAtMillis == null || progress <= 0.01 || progress >= 1.0) {
      return null;
    }
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAtMillis;
    if (elapsedMs <= 0) {
      return null;
    }
    final estimatedTotalMs = (elapsedMs / progress).round();
    final remainingMs = estimatedTotalMs - elapsedMs;
    return remainingMs > 0 ? remainingMs : 0;
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return const <String, dynamic>{};
  }
}

const Object _noChange = Object();
