import 'dart:math' as math;

import 'professional_motion_animation_models.dart';

class MotionCurveSample {
  const MotionCurveSample({
    required this.progress,
    required this.value,
    required this.velocity,
    required this.acceleration,
  });

  final double progress;
  final double value;
  final double velocity;
  final double acceleration;
}

MotionCurveSample evaluateMotionCurveSample(
  MotionInterpolationSpec interpolation,
  double progress,
) {
  final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
  return MotionCurveSample(
    progress: clampedProgress,
    value: evaluateMotionCurveProgress(interpolation, clampedProgress),
    velocity: evaluateMotionCurveVelocity(interpolation, clampedProgress),
    acceleration:
        evaluateMotionCurveAcceleration(interpolation, clampedProgress),
  );
}

List<MotionCurveSample> sampleMotionCurve(
  MotionInterpolationSpec interpolation, {
  int sampleCount = 30,
}) {
  final count = sampleCount < 2 ? 2 : sampleCount;
  return List<MotionCurveSample>.unmodifiable(
    List<MotionCurveSample>.generate(count, (index) {
      final progress = index / (count - 1);
      return evaluateMotionCurveSample(interpolation, progress);
    }),
  );
}

double evaluateMotionCurveProgress(
  MotionInterpolationSpec interpolation,
  double progress,
) {
  final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
  switch (interpolation.kind) {
    case MotionInterpolationKind.hold:
      return 0.0;
    case MotionInterpolationKind.linear:
      return clampedProgress;
    case MotionInterpolationKind.cubicBezier:
      final bezier = interpolation.bezier;
      if (bezier == null) {
        return clampedProgress;
      }
      return solveMotionCubicBezierProgress(bezier, clampedProgress);
    case MotionInterpolationKind.easeIn:
      return clampedProgress * clampedProgress;
    case MotionInterpolationKind.easeOut:
      final inverse = 1 - clampedProgress;
      return 1 - (inverse * inverse);
    case MotionInterpolationKind.easeInOut:
      if (clampedProgress < 0.5) {
        return 2 * clampedProgress * clampedProgress;
      }
      final inverse = -2 * clampedProgress + 2;
      return 1 - ((inverse * inverse) / 2);
    case MotionInterpolationKind.spring:
      return _evaluateSpringProgress(
        interpolation.spring ?? kDefaultMotionSpringSpec,
        clampedProgress,
      );
    case MotionInterpolationKind.bounce:
      return _evaluateBounceProgress(
        interpolation.bounce ?? kDefaultMotionBounceSpec,
        clampedProgress,
      );
    case MotionInterpolationKind.elastic:
      return _evaluateElasticProgress(
        interpolation.elastic ?? kDefaultMotionElasticSpec,
        clampedProgress,
      );
  }
}

double evaluateMotionCurveVelocity(
  MotionInterpolationSpec interpolation,
  double progress,
) {
  final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
  switch (interpolation.kind) {
    case MotionInterpolationKind.hold:
      return 0.0;
    case MotionInterpolationKind.linear:
      return 1.0;
    case MotionInterpolationKind.easeIn:
      return 2.0 * clampedProgress;
    case MotionInterpolationKind.easeOut:
      return 2.0 - (2.0 * clampedProgress);
    case MotionInterpolationKind.easeInOut:
      if (clampedProgress < 0.5) {
        return 4.0 * clampedProgress;
      }
      return 4.0 - (4.0 * clampedProgress);
    case MotionInterpolationKind.cubicBezier:
    case MotionInterpolationKind.spring:
    case MotionInterpolationKind.bounce:
    case MotionInterpolationKind.elastic:
      return _finiteDifferenceVelocity(
        interpolation: interpolation,
        progress: clampedProgress,
      );
  }
}

double evaluateMotionCurveAcceleration(
  MotionInterpolationSpec interpolation,
  double progress,
) {
  final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
  switch (interpolation.kind) {
    case MotionInterpolationKind.hold:
    case MotionInterpolationKind.linear:
      return 0.0;
    case MotionInterpolationKind.easeIn:
      return 2.0;
    case MotionInterpolationKind.easeOut:
      return -2.0;
    case MotionInterpolationKind.easeInOut:
      return clampedProgress < 0.5 ? 4.0 : -4.0;
    case MotionInterpolationKind.cubicBezier:
    case MotionInterpolationKind.spring:
    case MotionInterpolationKind.bounce:
    case MotionInterpolationKind.elastic:
      return _finiteDifferenceAcceleration(
        interpolation: interpolation,
        progress: clampedProgress,
      );
  }
}

double solveMotionCubicBezierProgress(
  MotionBezierControlPoints bezier,
  double x,
) {
  final clampedX = x.clamp(0.0, 1.0).toDouble();
  if (clampedX <= 0.0 || clampedX >= 1.0) {
    return clampedX;
  }
  var t = clampedX;
  for (var iteration = 0; iteration < 8; iteration += 1) {
    final estimate = _cubicCoordinate(t, 0.0, bezier.x1, bezier.x2, 1.0);
    final derivative = _cubicDerivative(t, 0.0, bezier.x1, bezier.x2, 1.0);
    final delta = estimate - clampedX;
    if (delta.abs() <= 0.000001 || derivative.abs() <= 0.000001) {
      break;
    }
    t = (t - (delta / derivative)).clamp(0.0, 1.0).toDouble();
  }
  var lower = 0.0;
  var upper = 1.0;
  for (var iteration = 0; iteration < 12; iteration += 1) {
    final estimate = _cubicCoordinate(t, 0.0, bezier.x1, bezier.x2, 1.0);
    if ((estimate - clampedX).abs() <= 0.000001) {
      break;
    }
    if (estimate < clampedX) {
      lower = t;
    } else {
      upper = t;
    }
    t = ((lower + upper) * 0.5).clamp(0.0, 1.0).toDouble();
  }
  return _cubicCoordinate(t, 0.0, bezier.y1, bezier.y2, 1.0)
      .clamp(-4.0, 4.0)
      .toDouble();
}

double _evaluateSpringProgress(
  MotionSpringSpec spring,
  double progress,
) {
  if (progress <= 0.0) {
    return 0.0;
  }
  if (progress >= 1.0) {
    return 1.0;
  }
  final naturalFrequency = math.sqrt(spring.stiffness / spring.mass);
  if (!naturalFrequency.isFinite || naturalFrequency <= 0) {
    return progress;
  }
  final dampingRatio =
      spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));
  final initialVelocity = spring.initialVelocity;
  if (dampingRatio < 1.0 - 0.0001) {
    final dampedFrequency =
        naturalFrequency * math.sqrt(1 - (dampingRatio * dampingRatio));
    final c =
        ((dampingRatio * naturalFrequency) - initialVelocity) / dampedFrequency;
    final envelope = math.exp(-dampingRatio * naturalFrequency * progress);
    return 1 -
        (envelope *
            (math.cos(dampedFrequency * progress) +
                (c * math.sin(dampedFrequency * progress))));
  }
  if ((dampingRatio - 1.0).abs() <= 0.0001) {
    final envelope = math.exp(-naturalFrequency * progress);
    return 1 -
        ((1 + ((naturalFrequency - initialVelocity) * progress)) * envelope);
  }
  final sqrtTerm = math.sqrt((dampingRatio * dampingRatio) - 1);
  final rootOne = -naturalFrequency * (dampingRatio - sqrtTerm);
  final rootTwo = -naturalFrequency * (dampingRatio + sqrtTerm);
  final coefficientOne = (-initialVelocity - rootTwo) / (rootOne - rootTwo);
  final coefficientTwo = 1 - coefficientOne;
  return 1 -
      ((coefficientOne * math.exp(rootOne * progress)) +
          (coefficientTwo * math.exp(rootTwo * progress)));
}

double _evaluateBounceProgress(
  MotionBounceSpec bounce,
  double progress,
) {
  final base = _easeOutQuadratic(progress);
  if (progress <= 0.0 || progress >= 1.0) {
    return progress;
  }
  if (bounce.amplitude <= 0 || bounce.bounces <= 0) {
    return base;
  }
  final oscillation = bounce.amplitude *
      math.pow(1 - progress, 0.65).toDouble() *
      math.exp(-bounce.decay * progress) *
      math.sin(math.pi * bounce.bounces * progress).abs();
  return base + oscillation;
}

double _evaluateElasticProgress(
  MotionElasticSpec elastic,
  double progress,
) {
  final base = _easeOutQuadratic(progress);
  if (progress <= 0.0 || progress >= 1.0) {
    return progress;
  }
  if (elastic.amplitude <= 0) {
    return base;
  }
  final period = elastic.period <= 0 ? 0.0001 : elastic.period;
  final raw = base +
      (elastic.amplitude *
          math.sin((2 * math.pi / period) * progress) *
          math.exp(-elastic.decay * progress));
  final endRaw = 1 +
      (elastic.amplitude *
          math.sin((2 * math.pi / period)) *
          math.exp(-elastic.decay));
  return raw - (progress * (endRaw - 1));
}

double _easeOutQuadratic(double t) {
  final inverse = 1 - t;
  return 1 - (inverse * inverse);
}

double _cubicCoordinate(
  double t,
  double p0,
  double p1,
  double p2,
  double p3,
) {
  final inverse = 1.0 - t;
  return (inverse * inverse * inverse * p0) +
      (3.0 * inverse * inverse * t * p1) +
      (3.0 * inverse * t * t * p2) +
      (t * t * t * p3);
}

double _cubicDerivative(
  double t,
  double p0,
  double p1,
  double p2,
  double p3,
) {
  final inverse = 1.0 - t;
  return (3.0 * inverse * inverse * (p1 - p0)) +
      (6.0 * inverse * t * (p2 - p1)) +
      (3.0 * t * t * (p3 - p2));
}

double _finiteDifferenceVelocity({
  required MotionInterpolationSpec interpolation,
  required double progress,
}) {
  final epsilon = _finiteDifferenceEpsilon(progress);
  final left = (progress - epsilon).clamp(0.0, 1.0).toDouble();
  final right = (progress + epsilon).clamp(0.0, 1.0).toDouble();
  if ((right - left).abs() <= 0.0000001) {
    return 0.0;
  }
  final leftProgress = evaluateMotionCurveProgress(interpolation, left);
  final rightProgress = evaluateMotionCurveProgress(interpolation, right);
  return (rightProgress - leftProgress) / (right - left);
}

double _finiteDifferenceAcceleration({
  required MotionInterpolationSpec interpolation,
  required double progress,
}) {
  final epsilon = _finiteDifferenceEpsilon(progress);
  final left = (progress - epsilon).clamp(0.0, 1.0).toDouble();
  final right = (progress + epsilon).clamp(0.0, 1.0).toDouble();
  if ((right - left).abs() <= 0.0000001) {
    return 0.0;
  }
  final leftVelocity = evaluateMotionCurveVelocity(interpolation, left);
  final rightVelocity = evaluateMotionCurveVelocity(interpolation, right);
  return (rightVelocity - leftVelocity) / (right - left);
}

double _finiteDifferenceEpsilon(double progress) {
  if (progress <= 0.02 || progress >= 0.98) {
    return 0.001;
  }
  return 0.0005;
}
