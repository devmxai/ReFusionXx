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
  })  : descriptors = List.unmodifiable(descriptors),
        blockers = List.unmodifiable(blockers),
        diagnostics = List.unmodifiable(diagnostics);

  final int timelinePositionMs;
  final List<LiveScrubSurfaceDescriptor> descriptors;
  final List<String> blockers;
  final List<String> diagnostics;
  final bool canProject;
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
