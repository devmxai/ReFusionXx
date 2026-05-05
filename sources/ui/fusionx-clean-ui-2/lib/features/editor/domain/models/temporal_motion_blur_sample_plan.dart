import 'package:flutter/foundation.dart';

@immutable
class TemporalMotionBlurSampleContribution {
  const TemporalMotionBlurSampleContribution({
    required this.sampleIndex,
    required this.timelineTimeMs,
    required this.sourceRole,
    required this.sourceClipId,
    required this.sourcePositionMs,
    required this.transformMatrix3x3,
    required this.opacity,
    required this.transitionProgress,
  });

  final int sampleIndex;
  final int timelineTimeMs;
  final String sourceRole;
  final String sourceClipId;
  final int sourcePositionMs;
  final List<double> transformMatrix3x3;
  final double opacity;
  final double transitionProgress;

  Map<String, Object?> toPlatformMap() {
    return <String, Object?>{
      'sampleIndex': sampleIndex,
      'timelineTimeMs': timelineTimeMs,
      'sourceRole': sourceRole,
      'sourceClipId': sourceClipId,
      'sourcePositionMs': sourcePositionMs,
      'transformMatrix3x3': List<double>.unmodifiable(transformMatrix3x3),
      'opacity': opacity,
      'transitionProgress': transitionProgress,
    };
  }
}

@immutable
class TemporalMotionBlurSamplePlan {
  const TemporalMotionBlurSamplePlan({
    required this.transitionId,
    required this.targetId,
    required this.rootTimeMs,
    required this.sampleTimesMs,
    required this.sampleOffsetsMs,
    required this.sampleWeights,
    required this.sampleTransforms,
    required this.sourceIdsBySample,
    required this.sampleOpacities,
    required this.sampleContributions,
    required this.amount,
    required this.shutterAngle,
    required this.shutterPhase,
    required this.samples,
    required this.affectPosition,
    required this.affectScale,
    required this.affectRotation,
    required this.graphRevision,
    required this.policyRevision,
  });

  final String transitionId;
  final String targetId;
  final int rootTimeMs;
  final List<int> sampleTimesMs;
  final List<double> sampleOffsetsMs;
  final List<double> sampleWeights;
  final List<List<double>> sampleTransforms;
  final List<String> sourceIdsBySample;
  final List<double> sampleOpacities;
  final List<TemporalMotionBlurSampleContribution> sampleContributions;
  final double amount;
  final double shutterAngle;
  final double shutterPhase;
  final int samples;
  final bool affectPosition;
  final bool affectScale;
  final bool affectRotation;
  final String graphRevision;
  final int policyRevision;

  Map<String, Object?> toPlatformMap() {
    return <String, Object?>{
      'transitionId': transitionId,
      'targetId': targetId,
      'rootTimeMs': rootTimeMs,
      'sampleTimesMs': List<int>.unmodifiable(sampleTimesMs),
      'sampleOffsetsMs': List<double>.unmodifiable(sampleOffsetsMs),
      'sampleWeights': List<double>.unmodifiable(sampleWeights),
      'sampleTransforms': sampleTransforms
          .map((entry) => List<double>.unmodifiable(entry))
          .toList(growable: false),
      'sourceIdsBySample': List<String>.unmodifiable(sourceIdsBySample),
      'sampleOpacities': List<double>.unmodifiable(sampleOpacities),
      'sampleContributions': sampleContributions
          .map((entry) => entry.toPlatformMap())
          .toList(growable: false),
      'amount': amount,
      'shutterAngle': shutterAngle,
      'shutterPhase': shutterPhase,
      'samples': samples,
      'affectPosition': affectPosition,
      'affectScale': affectScale,
      'affectRotation': affectRotation,
      'graphRevision': graphRevision,
      'policyRevision': policyRevision,
    };
  }
}
