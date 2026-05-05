import 'package:flutter/foundation.dart';

enum TrueFrameSamplingQualityMode {
  preview,
  liveScrub,
  playback,
  export,
}

@immutable
class TrueFrameNodeMotionBlurSampleState {
  const TrueFrameNodeMotionBlurSampleState({
    required this.sampleTimeMs,
    required this.transformMatrix3x3,
    required this.opacity,
    required this.sourceId,
  });

  final int sampleTimeMs;
  final List<double> transformMatrix3x3;
  final double opacity;
  final String sourceId;
}

@immutable
class CoreMotionBlurSamplingPlan {
  const CoreMotionBlurSamplingPlan({
    required this.enabled,
    required this.nodeId,
    required this.rootTimeMs,
    required this.shutterOpenTimeMs,
    required this.shutterCloseTimeMs,
    required this.sampleTimesMs,
    required this.sampleWeights,
    required this.sampleTransforms,
    required this.sampleNodeStates,
    required this.amount,
    required this.shutterAngleDegrees,
    required this.shutterPhaseDegrees,
    required this.sampleCount,
    required this.adaptiveSampleLimit,
    required this.qualityMode,
    required this.diagnostics,
    required this.blockers,
  });

  final bool enabled;
  final String nodeId;
  final int rootTimeMs;
  final int shutterOpenTimeMs;
  final int shutterCloseTimeMs;
  final List<int> sampleTimesMs;
  final List<double> sampleWeights;
  final List<List<double>> sampleTransforms;
  final List<TrueFrameNodeMotionBlurSampleState> sampleNodeStates;
  final double amount;
  final double shutterAngleDegrees;
  final double shutterPhaseDegrees;
  final int sampleCount;
  final int adaptiveSampleLimit;
  final TrueFrameSamplingQualityMode qualityMode;
  final List<String> diagnostics;
  final List<String> blockers;
}

@immutable
class EffectStackFrameState {
  const EffectStackFrameState({
    required this.nodeId,
    required this.effectDescriptors,
    required this.diagnostics,
    required this.blockers,
  });

  final String nodeId;
  final List<Map<String, Object?>> effectDescriptors;
  final List<String> diagnostics;
  final List<String> blockers;
}

@immutable
class NodeFrameState {
  const NodeFrameState({
    required this.rootTimeMs,
    required this.localTimeMs,
    required this.sourceTimeMs,
    required this.nodeId,
    required this.targetId,
    required this.sourceId,
    required this.resolvedLayerFamilies,
    required this.visibility,
    required this.transformMatrix3x3,
    required this.positionX,
    required this.positionY,
    required this.scaleX,
    required this.scaleY,
    required this.rotationRadians,
    required this.opacity,
    required this.crop,
    required this.maskRevealProgress,
    required this.gaussianBlurSigmaPx,
    required this.motionBlurSamplingPlan,
    required this.effectValues,
    required this.bounds,
    required this.blendMode,
    required this.zOrder,
    required this.diagnostics,
    required this.blockers,
  });

  final int rootTimeMs;
  final int localTimeMs;
  final int sourceTimeMs;
  final String nodeId;
  final String targetId;
  final String sourceId;
  final List<String> resolvedLayerFamilies;
  final bool visibility;
  final List<double> transformMatrix3x3;
  final double positionX;
  final double positionY;
  final double scaleX;
  final double scaleY;
  final double rotationRadians;
  final double opacity;
  final MotionCropFrameState? crop;
  final double? maskRevealProgress;
  final double? gaussianBlurSigmaPx;
  final CoreMotionBlurSamplingPlan? motionBlurSamplingPlan;
  final Map<String, Object?> effectValues;
  final MotionBoundsFrameState? bounds;
  final String blendMode;
  final int zOrder;
  final List<String> diagnostics;
  final List<String> blockers;
}

@immutable
class MotionCropFrameState {
  const MotionCropFrameState({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

@immutable
class MotionBoundsFrameState {
  const MotionBoundsFrameState({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

@immutable
class CompositionFrameState {
  const CompositionFrameState({
    required this.rootTimeMs,
    required this.nodeStatesByNodeId,
    required this.diagnostics,
    required this.blockers,
  });

  final int rootTimeMs;
  final Map<String, NodeFrameState> nodeStatesByNodeId;
  final List<String> diagnostics;
  final List<String> blockers;
}
