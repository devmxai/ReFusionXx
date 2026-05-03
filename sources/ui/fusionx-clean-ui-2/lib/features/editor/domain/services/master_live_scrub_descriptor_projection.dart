import 'dart:math' as math;

import '../models/master_live_scrub_descriptor_models.dart';
import '../models/master_live_scrub_visual_program_models.dart';

class MasterLiveScrubDescriptorProjection {
  const MasterLiveScrubDescriptorProjection();

  LiveScrubDescriptorProjectionResult project({
    required LiveScrubVisualProgram program,
    Map<String, LiveScrubTimelineSourceWindow> sourceWindowsByTargetId =
        const <String, LiveScrubTimelineSourceWindow>{},
    LiveScrubDescriptorCapabilities capabilities =
        const LiveScrubDescriptorCapabilities(),
  }) {
    final timelinePositionMs = program.time.rootTime.inMilliseconds;
    final descriptors = <LiveScrubSurfaceDescriptor>[];
    final blockers = <String>[...program.blockers];
    final diagnostics = <String>[...program.diagnostics];

    for (final surface in program.surfaces) {
      final surfaceBlockers = <String>[...surface.blockers];
      final window = sourceWindowsByTargetId[surface.targetId];
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
            .clamp(0, math.max(0, window.timelineEndMs - window.timelineStartMs))
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
      if (surface.effects.isNotEmpty && !capabilities.supportsEffectProgramIds) {
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
          'native_capabilities:${capabilities.source}',
        ],
      );
      descriptors.add(descriptor);
      blockers.addAll(surfaceBlockers);
    }

    return LiveScrubDescriptorProjectionResult(
      timelinePositionMs: timelinePositionMs,
      descriptors: descriptors,
      blockers: blockers,
      diagnostics: diagnostics,
      canProject: blockers.isEmpty,
    );
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
