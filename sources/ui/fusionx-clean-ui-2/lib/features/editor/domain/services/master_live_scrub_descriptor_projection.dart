import 'dart:math' as math;

import '../models/master_live_scrub_descriptor_models.dart';
import '../models/master_live_scrub_visual_program_models.dart';

class MasterLiveScrubDescriptorProjection {
  const MasterLiveScrubDescriptorProjection();

  LiveScrubDescriptorProjectionResult project({
    required LiveScrubVisualProgram program,
    Map<String, LiveScrubTimelineSourceWindow> sourceWindowsByTargetId =
        const <String, LiveScrubTimelineSourceWindow>{},
    Map<String, LiveScrubTransitionTimelineWindow> transitionWindowsByTargetId =
        const <String, LiveScrubTransitionTimelineWindow>{},
    LiveScrubDescriptorCapabilities capabilities =
        const LiveScrubDescriptorCapabilities(),
    LiveScrubPerformanceSnapshot performanceSnapshot =
        const LiveScrubPerformanceSnapshot(),
    LiveScrubLatencyBudgetThresholds latencyThresholds =
        const LiveScrubLatencyBudgetThresholds(),
  }) {
    final stopwatch = Stopwatch()..start();
    final timelinePositionMs = program.time.rootTime.inMilliseconds;
    final descriptors = <LiveScrubSurfaceDescriptor>[];
    final blockers = <String>[...program.blockers];
    final diagnostics = <String>[...program.diagnostics];

    for (final surface in program.surfaces) {
      final surfaceBlockers = <String>[...surface.blockers];
      final window = sourceWindowsByTargetId[surface.targetId];
      final transitionWindow = transitionWindowsByTargetId[surface.targetId];
      final source = surface.source;
      if (source == null || source.sourceUri.isEmpty) {
        surfaceBlockers.add('missing_source_binding:${surface.targetId}');
      }
      if (!capabilities.supportsSourceDimensions &&
          (source?.sourceWidth != null || source?.sourceHeight != null)) {
        surfaceBlockers.add('native_missing_source_dimensions_capability');
      }
      if (window == null) {
        surfaceBlockers.add('missing_source_window:${surface.targetId}');
      }

      var sourcePositionMs = 0;
      var timelineStartMs = 0;
      var timelineEndMs = 0;
      if (window != null) {
        timelineStartMs = window.timelineStartMs;
        timelineEndMs = window.timelineEndMs;
        final rate = window.playbackRate.isFinite && window.playbackRate > 0
            ? window.playbackRate
            : 1.0;
        final timelineOffsetMs = (timelinePositionMs - window.timelineStartMs)
            .clamp(
                0, math.max(0, window.timelineEndMs - window.timelineStartMs))
            .toInt();
        final sourceOffsetMs = (timelineOffsetMs * rate).round();
        sourcePositionMs = (window.sourceStartMs + sourceOffsetMs).clamp(
          window.sourceStartMs,
          window.sourceStartMs + math.max(0, window.sourceDurationMs),
        );
        if (timelinePositionMs < window.timelineStartMs ||
            timelinePositionMs > window.timelineEndMs) {
          surfaceBlockers.add(
            'timeline_position_outside_window:${surface.targetId}',
          );
        }
      }
      final requiresPlacement = surface.transform.positionX != 0.0 ||
          surface.transform.positionY != 0.0;
      if (requiresPlacement && !capabilities.supportsCanvasPlacement) {
        surfaceBlockers.add('native_missing_canvas_placement_capability');
      }
      final requiresTransform = surface.transform.scaleX != 1.0 ||
          surface.transform.scaleY != 1.0 ||
          surface.transform.rotationRadians != 0.0;
      if (requiresTransform && !capabilities.supportsTransformMatrix) {
        surfaceBlockers.add('native_missing_transform_matrix_capability');
      }
      if (surface.opacity < 1.0 && !capabilities.supportsOpacity) {
        surfaceBlockers.add('native_missing_opacity_capability');
      }
      if (surface.effects.isNotEmpty &&
          !capabilities.supportsEffectProgramIds) {
        surfaceBlockers.add('native_missing_effect_programs_capability');
      }
      if (surface.effects.isNotEmpty &&
          capabilities.supportsEffectProgramIds &&
          capabilities.supportedEffectProgramIds.isEmpty) {
        surfaceBlockers.add('native_effect_program_catalog_missing');
      }
      if (surface.effects.isNotEmpty &&
          capabilities.supportsEffectProgramIds &&
          capabilities.supportedEffectProgramIds.isNotEmpty) {
        for (final effect in surface.effects) {
          if (!capabilities.supportedEffectProgramIds.contains(effect.id)) {
            surfaceBlockers.add('unsupported_effect_program:${effect.id}');
          }
        }
      }
      final requiresTransitionWindow =
          surface.transitionRole != LiveScrubTransitionRole.none;
      if (requiresTransitionWindow &&
          !capabilities.supportsDualSourceTransitionWindow) {
        surfaceBlockers.add(
          'native_missing_dual_source_transition_window_capability',
        );
      }
      String? transitionId;
      int? transitionTimelineStartMs;
      int? transitionTimelineEndMs;
      double? transitionProgress;
      if (requiresTransitionWindow) {
        if (transitionWindow == null) {
          surfaceBlockers.add('missing_transition_window:${surface.targetId}');
        } else {
          transitionId = transitionWindow.transitionId;
          transitionTimelineStartMs = transitionWindow.timelineStartMs;
          transitionTimelineEndMs = transitionWindow.timelineEndMs;
          final transitionDurationMs = math.max(
            1,
            transitionWindow.timelineEndMs - transitionWindow.timelineStartMs,
          );
          final rawProgress =
              (timelinePositionMs - transitionWindow.timelineStartMs) /
                  transitionDurationMs;
          transitionProgress = rawProgress.clamp(0.0, 1.0);
          if (timelinePositionMs < transitionWindow.timelineStartMs ||
              timelinePositionMs > transitionWindow.timelineEndMs) {
            surfaceBlockers.add(
              'transition_timeline_outside_window:${surface.targetId}',
            );
          }
        }
      }

      final descriptor = LiveScrubSurfaceDescriptor(
        id: _stableDescriptorId(
          targetId: surface.targetId,
          scrubStoreKey: source?.scrubStoreKey,
          sourceUri: source?.sourceUri,
        ),
        targetId: surface.targetId,
        sourceKind: surface.sourceKind,
        sourceUri: source?.sourceUri ?? '',
        scrubStoreKey: source?.scrubStoreKey,
        sourceWidth: source?.sourceWidth,
        sourceHeight: source?.sourceHeight,
        sourcePositionMs: sourcePositionMs,
        timelinePositionMs: timelinePositionMs,
        timelineStartMs: timelineStartMs,
        timelineEndMs: timelineEndMs,
        transitionId: transitionId,
        transitionTimelineStartMs: transitionTimelineStartMs,
        transitionTimelineEndMs: transitionTimelineEndMs,
        transitionProgress: transitionProgress,
        transformMatrix3x3: _transformMatrix3x3(surface.transform),
        opacity: surface.opacity.clamp(0.0, 1.0).toDouble(),
        effectProgramIds: surface.effects.map((effect) => effect.id).toList(
              growable: false,
            ),
        transitionRole: surface.transitionRole,
        isValid: surfaceBlockers.isEmpty,
        blockers: surfaceBlockers,
        debugReasons: <String>[
          if (window != null)
            'source_time_mapped:${window.sourceStartMs}->$sourcePositionMs@${window.playbackRate}',
          if (window == null) 'source_time_unmapped',
          if (transitionWindow != null)
            'transition_window:${transitionWindow.transitionId}:${transitionWindow.timelineStartMs}-${transitionWindow.timelineEndMs}',
          if (transitionProgress != null)
            'transition_progress:${transitionProgress.toStringAsFixed(4)}',
          'native_capabilities:${capabilities.source}',
        ],
      );
      descriptors.add(descriptor);
      blockers.addAll(surfaceBlockers);
    }

    stopwatch.stop();
    final effectivePerformanceSnapshot = performanceSnapshot.copyWith(
      descriptorProjectionLatencyUs: stopwatch.elapsedMicroseconds,
    );
    final missingDescriptors = <String>[
      for (final descriptor in descriptors)
        if (descriptor.blockers
            .any((blocker) => blocker.startsWith('missing_')))
          descriptor.targetId,
    ];
    final unsupportedEffects = <String>[
      for (final blocker in blockers)
        if (blocker.startsWith('unsupported_effect_program:'))
          blocker.substring('unsupported_effect_program:'.length),
    ];
    final hasTransitionBlockers = blockers.any(
      (blocker) =>
          blocker.startsWith('missing_transition_window:') ||
          blocker.startsWith('transition_timeline_outside_window:'),
    );
    final transitionParityState = !program.transitionState.hasTransitionWindow
        ? LiveScrubTransitionParityState.notRequired
        : hasTransitionBlockers
            ? LiveScrubTransitionParityState.blocked
            : program.transitionState.hasRenderableTransitionPixels
                ? LiveScrubTransitionParityState.ready
                : LiveScrubTransitionParityState.windowReadyNoPixels;

    LiveScrubLatencyBudgetState latencyBudgetState;
    if (!capabilities.supportsLatencyMetrics) {
      latencyBudgetState = LiveScrubLatencyBudgetState.nativeMetricsUnavailable;
    } else if (effectivePerformanceSnapshot.frameRequestRateFps == null ||
        effectivePerformanceSnapshot.nativeDecodeRebindLatencyMs == null ||
        effectivePerformanceSnapshot.framePresentationLatencyMs == null ||
        effectivePerformanceSnapshot.droppedFrameCount == null ||
        effectivePerformanceSnapshot.crossSourceWarmupReady == null) {
      latencyBudgetState = LiveScrubLatencyBudgetState.nativeMetricsPending;
    } else {
      final isWithinBudget = (effectivePerformanceSnapshot
                  .frameRequestRateFps! >=
              latencyThresholds.minFrameRequestRateFps) &&
          (effectivePerformanceSnapshot.nativeDecodeRebindLatencyMs! <=
              latencyThresholds.maxNativeDecodeRebindLatencyMs) &&
          (effectivePerformanceSnapshot.descriptorProjectionLatencyUs ?? 0) <=
              latencyThresholds.maxDescriptorProjectionLatencyUs &&
          (effectivePerformanceSnapshot.framePresentationLatencyMs! <=
              latencyThresholds.maxFramePresentationLatencyMs) &&
          (effectivePerformanceSnapshot.droppedFrameCount! <=
              latencyThresholds.maxDroppedFrameCount) &&
          effectivePerformanceSnapshot.crossSourceWarmupReady!;
      latencyBudgetState = isWithinBudget
          ? LiveScrubLatencyBudgetState.withinBudget
          : LiveScrubLatencyBudgetState.overBudget;
    }

    return LiveScrubDescriptorProjectionResult(
      timelinePositionMs: timelinePositionMs,
      descriptors: descriptors,
      blockers: blockers,
      diagnostics: diagnostics,
      canProject: blockers.isEmpty,
      parityReport: LiveScrubParityReport(
        canScrubFrame: blockers.isEmpty,
        usesMasterClock: true,
        usesMasterFrameEvaluation: true,
        usesNativeScrubSurface: true,
        usesExoPlayerDuringActiveScrub: false,
        usesStillFallback: false,
        missingDescriptors: missingDescriptors,
        unsupportedEffects: unsupportedEffects,
        transitionParityState: transitionParityState,
        latencyBudgetState: latencyBudgetState,
        performanceSnapshot: effectivePerformanceSnapshot,
      ),
      rendererPresentationProof: RendererPresentationProof(
        requestedRootTimeMs: timelinePositionMs,
        requestedFrameIndex: program.time.frameIndex,
        requestedCommitFrameNumber: program.time.commitFrameNumber,
        requestedSourceIds: <String>[
          for (final descriptor in descriptors)
            if (descriptor.sourceUri.trim().isNotEmpty) descriptor.targetId,
        ],
        requestId:
            'liveScrub:${program.time.commitFrameNumber}:${program.time.frameIndex}:$timelinePositionMs',
        sourceRevision: _extractDiagnosticValue(
          diagnostics,
          'master_source_revision:',
        ),
        renderGraphRevision: _extractDiagnosticValue(
          diagnostics,
          'master_render_graph_revision:',
        ),
        rendererMode: program.time.renderMode.name,
        blockers: blockers,
        nativePresentationAck: false,
        matchState: blockers.isEmpty
            ? RendererPresentationMatchState.pendingNativeAck
            : RendererPresentationMatchState.blocked,
        matchReason:
            blockers.isEmpty ? 'awaiting_native_ack' : 'projection_blocked',
      ),
    );
  }

  String _extractDiagnosticValue(List<String> diagnostics, String prefix) {
    for (final entry in diagnostics) {
      if (entry.startsWith(prefix)) {
        final value = entry.substring(prefix.length).trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return 'unknown';
  }

  String _stableDescriptorId({
    required String targetId,
    String? scrubStoreKey,
    String? sourceUri,
  }) {
    final key = scrubStoreKey?.trim();
    if (key != null && key.isNotEmpty) {
      return 'lsd:$targetId:$key';
    }
    final uri = sourceUri?.trim();
    if (uri != null && uri.isNotEmpty) {
      return 'lsd:$targetId:${uri.hashCode}';
    }
    return 'lsd:$targetId:unbound';
  }

  List<double> _transformMatrix3x3(LiveScrubSurfaceTransform transform) {
    final cosTheta = math.cos(transform.rotationRadians);
    final sinTheta = math.sin(transform.rotationRadians);
    final m00 = transform.scaleX * cosTheta;
    final m01 = -transform.scaleY * sinTheta;
    final m10 = transform.scaleX * sinTheta;
    final m11 = transform.scaleY * cosTheta;
    return <double>[
      m00,
      m01,
      transform.positionX,
      m10,
      m11,
      transform.positionY,
      0.0,
      0.0,
      1.0,
    ];
  }
}
