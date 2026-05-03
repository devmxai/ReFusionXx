import 'package:flutter/foundation.dart';

@immutable
class Stage5VisualRuntimeSurfaceState {
  const Stage5VisualRuntimeSurfaceState({
    required this.targetClipId,
    required this.role,
    required this.transformMatrix3x3,
    required this.opacity,
    this.transitionProgress,
    this.effectProgramIds = const <String>[],
    this.blockers = const <String>[],
  });

  final String targetClipId;
  final String role;
  final List<double> transformMatrix3x3;
  final double opacity;
  final double? transitionProgress;
  final List<String> effectProgramIds;
  final List<String> blockers;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'targetClipId': targetClipId,
      'role': role,
      'transformMatrix3x3': transformMatrix3x3,
      'opacity': opacity,
      'transitionProgress': transitionProgress,
      'effectProgramIds': effectProgramIds,
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
