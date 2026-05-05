import 'package:flutter/foundation.dart';

@immutable
class Stage5VisualRuntimeEffectBinding {
  const Stage5VisualRuntimeEffectBinding({
    required this.id,
    required this.rendererValue,
    required this.rendererUnit,
  });

  final String id;
  final double rendererValue;
  final String rendererUnit;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'rendererValue': rendererValue,
      'rendererUnit': rendererUnit,
    };
  }
}

@immutable
class Stage5VisualRuntimeMotionBlurPolicy {
  const Stage5VisualRuntimeMotionBlurPolicy({
    required this.enabled,
    required this.amount,
    required this.shutterAngleDegrees,
    required this.shutterPhaseDegrees,
    required this.samples,
    required this.adaptiveSampleLimit,
    required this.maxTrailPx,
    required this.affectPosition,
    required this.affectScale,
    required this.affectRotation,
  });

  final bool enabled;
  final double amount;
  final double shutterAngleDegrees;
  final double shutterPhaseDegrees;
  final int samples;
  final int adaptiveSampleLimit;
  final double maxTrailPx;
  final bool affectPosition;
  final bool affectScale;
  final bool affectRotation;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'enabled': enabled,
      'amount': amount,
      'shutterAngleDegrees': shutterAngleDegrees,
      'shutterPhaseDegrees': shutterPhaseDegrees,
      'samples': samples,
      'adaptiveSampleLimit': adaptiveSampleLimit,
      'maxTrailPx': maxTrailPx,
      'affectPosition': affectPosition,
      'affectScale': affectScale,
      'affectRotation': affectRotation,
    };
  }
}

@immutable
class Stage5VisualRuntimeMotionBlurSample {
  const Stage5VisualRuntimeMotionBlurSample({
    required this.timelineTimeMs,
    required this.transformMatrix3x3,
    required this.opacity,
  });

  final int timelineTimeMs;
  final List<double> transformMatrix3x3;
  final double opacity;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'timelineTimeMs': timelineTimeMs,
      'transformMatrix3x3': transformMatrix3x3,
      'opacity': opacity,
    };
  }
}

@immutable
class Stage5VisualRuntimeSurfaceState {
  const Stage5VisualRuntimeSurfaceState({
    required this.targetClipId,
    required this.role,
    required this.transformMatrix3x3,
    required this.opacity,
    this.transitionProgress,
    this.effectProgramIds = const <String>[],
    this.effectBindings = const <Stage5VisualRuntimeEffectBinding>[],
    this.motionBlurPolicy,
    this.motionBlurSamples = const <Stage5VisualRuntimeMotionBlurSample>[],
    this.blockers = const <String>[],
  });

  final String targetClipId;
  final String role;
  final List<double> transformMatrix3x3;
  final double opacity;
  final double? transitionProgress;
  final List<String> effectProgramIds;
  final List<Stage5VisualRuntimeEffectBinding> effectBindings;
  final Stage5VisualRuntimeMotionBlurPolicy? motionBlurPolicy;
  final List<Stage5VisualRuntimeMotionBlurSample> motionBlurSamples;
  final List<String> blockers;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'targetClipId': targetClipId,
      'role': role,
      'transformMatrix3x3': transformMatrix3x3,
      'opacity': opacity,
      'transitionProgress': transitionProgress,
      'effectProgramIds': effectProgramIds,
      'effectBindings': effectBindings
          .map((effect) => effect.toMap())
          .toList(growable: false),
      'motionBlurPolicy': motionBlurPolicy?.toMap(),
      'motionBlurSamples': motionBlurSamples
          .map((sample) => sample.toMap())
          .toList(growable: false),
      'blockers': blockers,
    };
  }
}

@immutable
class Stage5VisualRuntimeState {
  const Stage5VisualRuntimeState({
    required this.revision,
    required this.timelineTimeMs,
    required this.mode,
    this.transitionId,
    this.primaryTargetClipId,
    this.transitionProgress,
    this.surfaces = const <Stage5VisualRuntimeSurfaceState>[],
    this.blockers = const <String>[],
    this.diagnostics = const <String>[],
  });

  final int revision;
  final int timelineTimeMs;
  final String mode;
  final String? transitionId;
  final String? primaryTargetClipId;
  final double? transitionProgress;
  final List<Stage5VisualRuntimeSurfaceState> surfaces;
  final List<String> blockers;
  final List<String> diagnostics;

  bool get hasSurfaceState => surfaces.isNotEmpty;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'revision': revision,
      'timelineTimeMs': timelineTimeMs,
      'mode': mode,
      'transitionId': transitionId,
      'primaryTargetClipId': primaryTargetClipId,
      'transitionProgress': transitionProgress,
      'surfaces': surfaces.map((surface) => surface.toMap()).toList(),
      'blockers': blockers,
      'diagnostics': diagnostics,
    };
  }
}
