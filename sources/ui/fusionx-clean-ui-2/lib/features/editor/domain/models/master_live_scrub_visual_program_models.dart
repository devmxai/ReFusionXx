import 'package:flutter/foundation.dart';

import 'master_time_models.dart';
import 'master_value_truth_models.dart';
import 'master_visual_program_models.dart';

enum LiveScrubSourceKind {
  video,
  image,
  unknown,
}

enum LiveScrubTransitionRole {
  none,
  outgoing,
  incoming,
  overlay,
  matte,
}

@immutable
class LiveScrubSurfaceSource {
  const LiveScrubSurfaceSource({
    required this.targetId,
    required this.kind,
    required this.sourceUri,
    this.scrubStoreKey,
    this.sourceWidth,
    this.sourceHeight,
  });

  final String targetId;
  final LiveScrubSourceKind kind;
  final String sourceUri;
  final String? scrubStoreKey;
  final int? sourceWidth;
  final int? sourceHeight;
}

@immutable
class LiveScrubSurfaceTransform {
  const LiveScrubSurfaceTransform({
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotationRadians = 0.0,
  });

  final double positionX;
  final double positionY;
  final double scaleX;
  final double scaleY;
  final double rotationRadians;

  LiveScrubSurfaceTransform copyWith({
    double? positionX,
    double? positionY,
    double? scaleX,
    double? scaleY,
    double? rotationRadians,
  }) {
    return LiveScrubSurfaceTransform(
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotationRadians: rotationRadians ?? this.rotationRadians,
    );
  }
}

@immutable
class LiveScrubEffectBinding {
  const LiveScrubEffectBinding({
    required this.id,
    required this.rendererValue,
    required this.rendererUnit,
  });

  final String id;
  final double rendererValue;
  final MasterValueUnit rendererUnit;
}

@immutable
class LiveScrubVisualSurface {
  LiveScrubVisualSurface({
    required this.targetId,
    required this.sourceKind,
    this.source,
    this.transitionRole = LiveScrubTransitionRole.none,
    this.transform = const LiveScrubSurfaceTransform(),
    this.opacity = 1.0,
    this.motionBlur = const MasterMotionBlurPolicy(),
    List<LiveScrubEffectBinding> effects = const <LiveScrubEffectBinding>[],
    List<String> blockers = const <String>[],
  })  : effects = List.unmodifiable(effects),
        blockers = List.unmodifiable(blockers);

  final String targetId;
  final LiveScrubSourceKind sourceKind;
  final LiveScrubSurfaceSource? source;
  final LiveScrubTransitionRole transitionRole;
  final LiveScrubSurfaceTransform transform;
  final double opacity;
  final MasterMotionBlurPolicy motionBlur;
  final List<LiveScrubEffectBinding> effects;
  final List<String> blockers;
}

@immutable
class LiveScrubTransitionState {
  LiveScrubTransitionState({
    List<String> activeTransitionIds = const <String>[],
    required this.hasRenderableTransitionPixels,
    required this.reason,
  }) : activeTransitionIds = List.unmodifiable(activeTransitionIds);

  final List<String> activeTransitionIds;
  final bool hasRenderableTransitionPixels;
  final String reason;

  bool get hasTransitionWindow => activeTransitionIds.isNotEmpty;
}

@immutable
class LiveScrubVisualProgram {
  LiveScrubVisualProgram({
    required this.time,
    List<LiveScrubVisualSurface> surfaces = const <LiveScrubVisualSurface>[],
    List<String> blockers = const <String>[],
    List<String> diagnostics = const <String>[],
    required this.sourceRevision,
    required this.renderGraphRevision,
    required this.transitionState,
  })  : surfaces = List.unmodifiable(surfaces),
        blockers = List.unmodifiable(blockers),
        diagnostics = List.unmodifiable(diagnostics);

  final MasterTimeSnapshot time;
  final List<LiveScrubVisualSurface> surfaces;
  final List<String> blockers;
  final List<String> diagnostics;
  final String sourceRevision;
  final String renderGraphRevision;
  final LiveScrubTransitionState transitionState;

  bool get canRenderTruthfully {
    if (blockers.isNotEmpty) {
      return false;
    }
    for (final surface in surfaces) {
      if (surface.blockers.isNotEmpty) {
        return false;
      }
    }
    return true;
  }
}
