import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/master_time_models.dart';
import '../models/master_value_truth_models.dart';
import '../models/professional_motion_animation_models.dart';
import '../models/professional_motion_interpolation_evaluator.dart';
import '../models/professional_motion_models.dart';
import 'master_value_truth_registry.dart';

enum MasterKeyframeEvaluationStatus {
  resolved,
  defaulted,
  unsupported,
  outOfRange,
  missingPropertyDefinition,
}

@immutable
class MasterKeyframeEvaluationRequest {
  const MasterKeyframeEvaluationRequest({
    required this.channel,
    required this.time,
    required this.domainProjection,
    this.transitionProgress,
  });

  final MotionPropertyChannelModel channel;
  final MasterTimeSnapshot time;
  final MasterTimeProjection domainProjection;
  final double? transitionProgress;
}

@immutable
class MasterKeyframeEvaluationResult {
  const MasterKeyframeEvaluationResult({
    required this.status,
    this.rawValue,
    this.rawVelocity,
    this.rawAcceleration,
    this.mapping,
    this.interpolation,
    required this.reason,
  });

  final MasterKeyframeEvaluationStatus status;
  final MotionPropertyValue? rawValue;
  final double? rawVelocity;
  final double? rawAcceleration;
  final MasterPropertyValueMapping? mapping;
  final MotionInterpolationSpec? interpolation;
  final String reason;
}

class MasterKeyframeValueEvaluator {
  MasterKeyframeValueEvaluator({
    MasterValueTruthRegistry? registry,
  }) : registry = registry ?? MasterValueTruthRegistry();

  final MasterValueTruthRegistry registry;

  MasterKeyframeEvaluationResult evaluate(
    MasterKeyframeEvaluationRequest request,
  ) {
    if (!request.domainProjection.isValid) {
      return const MasterKeyframeEvaluationResult(
        status: MasterKeyframeEvaluationStatus.outOfRange,
        reason: 'invalid_time_projection',
      );
    }

    final definition = registry.definitionForMotionProperty(
      request.channel.definition,
    );
    if (definition == null) {
      return const MasterKeyframeEvaluationResult(
        status: MasterKeyframeEvaluationStatus.missingPropertyDefinition,
        reason: 'missing_property_definition',
      );
    }

    final value = _resolveRawValue(
      channel: request.channel,
      projectedTime: request.domainProjection.outputTime,
      transitionProgress: request.transitionProgress,
    );
    if (value == null) {
      return MasterKeyframeEvaluationResult(
        status: MasterKeyframeEvaluationStatus.defaulted,
        rawValue: request.channel.fallbackValue,
        mapping: registry.mapValue(
          definition: definition,
          value: request.channel.fallbackValue,
        ),
        reason: 'channel_default_used',
      );
    }

    return MasterKeyframeEvaluationResult(
      status: MasterKeyframeEvaluationStatus.resolved,
      rawValue: value.value,
      rawVelocity: value.rawVelocity,
      rawAcceleration: value.rawAcceleration,
      mapping: registry.mapValue(
        definition: definition,
        value: value.value,
      ),
      interpolation: value.interpolation,
      reason: value.reason,
    );
  }

  _SampledMotionValue? _resolveRawValue({
    required MotionPropertyChannelModel channel,
    required TimelineTime projectedTime,
    required double? transitionProgress,
  }) {
    final keyframes = channel.keyframes;
    if (keyframes.isEmpty) {
      return null;
    }
    if (keyframes.length == 1) {
      return _SampledMotionValue(
        value: keyframes.first.value,
        rawVelocity: null,
        rawAcceleration: null,
        interpolation: keyframes.first.interpolationToNext,
        reason: 'single_keyframe_value',
      );
    }

    final activeRange = channel.activeRange;
    if (activeRange != null && !activeRange.contains(projectedTime)) {
      return null;
    }

    for (var i = 0; i < keyframes.length; i += 1) {
      final current = keyframes[i];
      final next = i + 1 < keyframes.length ? keyframes[i + 1] : null;
      if (next == null || projectedTime <= current.time) {
        return _SampledMotionValue(
          value: current.value,
          rawVelocity: null,
          rawAcceleration: null,
          interpolation: current.interpolationToNext,
          reason: 'keyframe_hold_or_before',
        );
      }
      if (projectedTime > next.time) {
        continue;
      }
      if (current.value.kind != MotionPropertyValueKind.scalar ||
          next.value.kind != MotionPropertyValueKind.scalar) {
        return _SampledMotionValue(
          value: current.value,
          rawVelocity: null,
          rawAcceleration: null,
          interpolation: current.interpolationToNext,
          reason: 'non_scalar_interpolation_fallback',
        );
      }

      final duration = (next.time - current.time).inSecondsDouble;
      if (duration <= 0) {
        return _SampledMotionValue(
          value: current.value,
          rawVelocity: null,
          rawAcceleration: null,
          interpolation: current.interpolationToNext,
          reason: 'zero_duration_keyframe_pair',
        );
      }
      final normalized =
          ((projectedTime - current.time).inSecondsDouble / duration)
              .clamp(0.0, 1.0)
              .toDouble();
      final curveProgress = evaluateMotionCurveProgress(
        current.interpolationToNext,
        transitionProgress ?? normalized,
      );
      final from = current.value.rawValue as double;
      final to = next.value.rawValue as double;
      final resolved = from + ((to - from) * curveProgress);
      final curveVelocity = evaluateMotionCurveVelocity(
        current.interpolationToNext,
        transitionProgress ?? normalized,
      );
      final curveAcceleration = evaluateMotionCurveAcceleration(
        current.interpolationToNext,
        transitionProgress ?? normalized,
      );
      final delta = to - from;
      final velocityPerSecond = (delta / duration) * curveVelocity;
      final accelerationPerSecond2 =
          (delta / (duration * duration)) * curveAcceleration;
      return _SampledMotionValue(
        value: MotionPropertyValue.scalar(resolved),
        rawVelocity: velocityPerSecond,
        rawAcceleration: accelerationPerSecond2,
        interpolation: current.interpolationToNext,
        reason: 'interpolated_scalar_value',
      );
    }

    final last = keyframes.last;
    return _SampledMotionValue(
      value: last.value,
      rawVelocity: null,
      rawAcceleration: null,
      interpolation: last.interpolationToNext,
      reason: 'after_last_keyframe_hold',
    );
  }
}

@immutable
class _SampledMotionValue {
  const _SampledMotionValue({
    required this.value,
    required this.rawVelocity,
    required this.rawAcceleration,
    required this.interpolation,
    required this.reason,
  });

  final MotionPropertyValue value;
  final double? rawVelocity;
  final double? rawAcceleration;
  final MotionInterpolationSpec interpolation;
  final String reason;
}
