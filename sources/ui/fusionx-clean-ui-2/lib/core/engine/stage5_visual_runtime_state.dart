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
class Stage5VisualRuntimeMotionBlurDirective {
  const Stage5VisualRuntimeMotionBlurDirective({
    required this.enabled,
    required this.amount,
    required this.kernelLengthPx,
    required this.directionX,
    required this.directionY,
    required this.radialOmega,
    required this.scaleVelocityX,
    required this.scaleVelocityY,
    required this.anchorXNormalized,
    required this.anchorYNormalized,
    required this.shutterAngleDegrees,
    required this.shutterPhase,
    required this.sampleCount,
    required this.maxTrailPx,
    required this.mode,
    this.fallbackReason,
  });

  final bool enabled;
  final double amount;
  final double kernelLengthPx;
  final double directionX;
  final double directionY;
  final double radialOmega;
  final double scaleVelocityX;
  final double scaleVelocityY;
  final double anchorXNormalized;
  final double anchorYNormalized;
  final double shutterAngleDegrees;
  final double shutterPhase;
  final int sampleCount;
  final double maxTrailPx;
  final String mode;
  final String? fallbackReason;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'enabled': enabled,
      'amount': amount,
      'kernelLengthPx': kernelLengthPx,
      'directionX': directionX,
      'directionY': directionY,
      'radialOmega': radialOmega,
      'scaleVelocityX': scaleVelocityX,
      'scaleVelocityY': scaleVelocityY,
      'anchorXNormalized': anchorXNormalized,
      'anchorYNormalized': anchorYNormalized,
      'shutterAngleDegrees': shutterAngleDegrees,
      'shutterPhase': shutterPhase,
      'sampleCount': sampleCount,
      'maxTrailPx': maxTrailPx,
      'mode': mode,
      'fallbackReason': fallbackReason,
    };
  }
}

@immutable
class Stage5VisualRuntimeEdgeFillDirective {
  const Stage5VisualRuntimeEdgeFillDirective({
    required this.enabled,
    required this.mode,
    required this.amount,
    required this.overscanScale,
    required this.softnessPx,
    required this.blurSigmaPx,
    required this.sourceRectLeft,
    required this.sourceRectTop,
    required this.sourceRectRight,
    required this.sourceRectBottom,
    required this.contentWidth,
    required this.contentHeight,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.maxExpansionPx,
    required this.quality,
    required this.transformMatrix3x3,
    required this.inverseTransformMatrix3x3,
    this.fallbackReason,
  });

  final bool enabled;
  final String mode;
  final double amount;
  final double overscanScale;
  final double softnessPx;
  final double blurSigmaPx;
  final double sourceRectLeft;
  final double sourceRectTop;
  final double sourceRectRight;
  final double sourceRectBottom;
  final double contentWidth;
  final double contentHeight;
  final double canvasWidth;
  final double canvasHeight;
  final double maxExpansionPx;
  final String quality;
  final List<double> transformMatrix3x3;
  final List<double> inverseTransformMatrix3x3;
  final String? fallbackReason;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'enabled': enabled,
      'mode': mode,
      'amount': amount,
      'overscanScale': overscanScale,
      'softnessPx': softnessPx,
      'blurSigmaPx': blurSigmaPx,
      'sourceRectLeft': sourceRectLeft,
      'sourceRectTop': sourceRectTop,
      'sourceRectRight': sourceRectRight,
      'sourceRectBottom': sourceRectBottom,
      'contentWidth': contentWidth,
      'contentHeight': contentHeight,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'maxExpansionPx': maxExpansionPx,
      'quality': quality,
      'transformMatrix3x3': transformMatrix3x3,
      'inverseTransformMatrix3x3': inverseTransformMatrix3x3,
      'fallbackReason': fallbackReason,
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
    this.motionBlurDirective,
    this.edgeFillDirective,
    this.blockers = const <String>[],
  });

  final String targetClipId;
  final String role;
  final List<double> transformMatrix3x3;
  final double opacity;
  final double? transitionProgress;
  final List<String> effectProgramIds;
  final List<Stage5VisualRuntimeEffectBinding> effectBindings;
  final Stage5VisualRuntimeMotionBlurDirective? motionBlurDirective;
  final Stage5VisualRuntimeEdgeFillDirective? edgeFillDirective;
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
      'motionBlurDirective': motionBlurDirective?.toMap(),
      'edgeFillDirective': edgeFillDirective?.toMap(),
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
    this.framePacket,
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
  final Stage5VisualFramePacket? framePacket;
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
      'framePacket': framePacket?.toMap(),
      'transitionId': transitionId,
      'primaryTargetClipId': primaryTargetClipId,
      'transitionProgress': transitionProgress,
      'surfaces': surfaces.map((surface) => surface.toMap()).toList(),
      'blockers': blockers,
      'diagnostics': diagnostics,
    };
  }
}

@immutable
class Stage5VisualFramePacket {
  const Stage5VisualFramePacket({
    required this.timelineTimeMs,
    required this.frameIndex,
    required this.mode,
    required this.revision,
    required this.targetClipId,
    required this.sourceId,
    required this.transformMatrix3x3,
    this.motionBlurDirective,
    this.edgeFillDirective,
    this.gaussianBlurSigmaPx = 0,
    this.effectValuesHash = 0,
  });

  final int timelineTimeMs;
  final int frameIndex;
  final String mode;
  final int revision;
  final String targetClipId;
  final String sourceId;
  final List<double> transformMatrix3x3;
  final Stage5VisualRuntimeMotionBlurDirective? motionBlurDirective;
  final Stage5VisualRuntimeEdgeFillDirective? edgeFillDirective;
  final double gaussianBlurSigmaPx;
  final int effectValuesHash;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'timelineTimeMs': timelineTimeMs,
      'frameIndex': frameIndex,
      'mode': mode,
      'revision': revision,
      'targetClipId': targetClipId,
      'sourceId': sourceId,
      'transformMatrix3x3': transformMatrix3x3,
      'motionBlurDirective': motionBlurDirective?.toMap(),
      'edgeFillDirective': edgeFillDirective?.toMap(),
      'gaussianBlurSigmaPx': gaussianBlurSigmaPx,
      'effectValuesHash': effectValuesHash,
    };
  }
}
