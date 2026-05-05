import 'package:flutter/foundation.dart';

@immutable
class TemporalMotionBlurSamplePlan {
  const TemporalMotionBlurSamplePlan({
    required this.targetId,
    required this.rootTimeMs,
    required this.sampleTimesMs,
    required this.sampleOffsetsMs,
    required this.sampleTransforms,
    required this.sourceIdsBySample,
    required this.sampleOpacities,
    required this.amount,
    required this.shutterAngle,
    required this.shutterPhase,
    required this.samples,
    required this.affectPosition,
    required this.affectScale,
    required this.affectRotation,
  });

  final String targetId;
  final int rootTimeMs;
  final List<int> sampleTimesMs;
  final List<double> sampleOffsetsMs;
  final List<List<double>> sampleTransforms;
  final List<String> sourceIdsBySample;
  final List<double> sampleOpacities;
  final double amount;
  final double shutterAngle;
  final double shutterPhase;
  final int samples;
  final bool affectPosition;
  final bool affectScale;
  final bool affectRotation;

  Map<String, Object?> toPlatformMap() {
    return <String, Object?>{
      'targetId': targetId,
      'rootTimeMs': rootTimeMs,
      'sampleTimesMs': List<int>.unmodifiable(sampleTimesMs),
      'sampleOffsetsMs': List<double>.unmodifiable(sampleOffsetsMs),
      'sampleTransforms': sampleTransforms
          .map((entry) => List<double>.unmodifiable(entry))
          .toList(growable: false),
      'sourceIdsBySample': List<String>.unmodifiable(sourceIdsBySample),
      'sampleOpacities': List<double>.unmodifiable(sampleOpacities),
      'amount': amount,
      'shutterAngle': shutterAngle,
      'shutterPhase': shutterPhase,
      'samples': samples,
      'affectPosition': affectPosition,
      'affectScale': affectScale,
      'affectRotation': affectRotation,
    };
  }
}
