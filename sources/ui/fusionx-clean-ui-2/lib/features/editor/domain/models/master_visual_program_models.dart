import 'package:flutter/foundation.dart';

import 'master_time_models.dart';
import 'master_value_truth_models.dart';

enum MasterVisualSourceKind {
  video,
  image,
  unknown,
}

enum MasterVisualTransitionRole {
  none,
  outgoing,
  incoming,
  overlay,
  matte,
}

@immutable
class MasterVisualSourceBinding {
  const MasterVisualSourceBinding({
    required this.targetId,
    required this.kind,
    required this.sourceUri,
    this.scrubStoreKey,
    this.sourceWidth,
    this.sourceHeight,
  });

  final String targetId;
  final MasterVisualSourceKind kind;
  final String sourceUri;
  final String? scrubStoreKey;
  final int? sourceWidth;
  final int? sourceHeight;
}

@immutable
class MasterVisualTransform {
  const MasterVisualTransform({
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

  MasterVisualTransform copyWith({
    double? positionX,
    double? positionY,
    double? scaleX,
    double? scaleY,
    double? rotationRadians,
  }) {
    return MasterVisualTransform(
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotationRadians: rotationRadians ?? this.rotationRadians,
    );
  }
}

@immutable
class MasterVisualEffectBinding {
  const MasterVisualEffectBinding({
    required this.id,
    required this.rendererValue,
    required this.rendererUnit,
  });

  final String id;
  final double rendererValue;
  final MasterValueUnit rendererUnit;
}

@immutable
class MasterVisualSurface {
  MasterVisualSurface({
    required this.targetId,
    required this.sourceKind,
    this.source,
    this.transitionRole = MasterVisualTransitionRole.none,
    this.transform = const MasterVisualTransform(),
    this.opacity = 1.0,
    List<MasterVisualEffectBinding> effects =
        const <MasterVisualEffectBinding>[],
    List<String> blockers = const <String>[],
  })  : effects = List.unmodifiable(effects),
        blockers = List.unmodifiable(blockers);

  final String targetId;
  final MasterVisualSourceKind sourceKind;
  final MasterVisualSourceBinding? source;
  final MasterVisualTransitionRole transitionRole;
  final MasterVisualTransform transform;
  final double opacity;
  final List<MasterVisualEffectBinding> effects;
  final List<String> blockers;
}

@immutable
class MasterVisualTransitionState {
  MasterVisualTransitionState({
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
class MasterVisualProgram {
  MasterVisualProgram({
    required this.time,
    List<MasterVisualSurface> surfaces = const <MasterVisualSurface>[],
    List<String> blockers = const <String>[],
    List<String> diagnostics = const <String>[],
    required this.transitionState,
  })  : surfaces = List.unmodifiable(surfaces),
        blockers = List.unmodifiable(blockers),
        diagnostics = List.unmodifiable(diagnostics);

  final MasterTimeSnapshot time;
  final List<MasterVisualSurface> surfaces;
  final List<String> blockers;
  final List<String> diagnostics;
  final MasterVisualTransitionState transitionState;

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
