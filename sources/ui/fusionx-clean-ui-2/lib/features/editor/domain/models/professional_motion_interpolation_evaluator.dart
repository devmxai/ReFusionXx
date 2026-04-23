import 'dart:math' as math;

import 'professional_motion_animation_models.dart';

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
        ((dampingRatio * naturalFrequency) - initialVelocity) /
        dampedFrequency;
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
  final oscillation =
      bounce.amplitude *
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
  final raw =
      base +
      (elastic.amplitude *
          math.sin((2 * math.pi / period) * progress) *
          math.exp(-elastic.decay * progress));
  final endRaw =
      1 +
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
