import 'dart:math' as math;
import 'dart:developer' as developer;

import '../models/professional_motion_animation_models.dart';

enum MotionPropertyOvershootPolicy {
  disallow,
  allowBezierOvershoot,
  allowSpringOnly,
}

class MotionBezierVelocityBridge {
  const MotionBezierVelocityBridge();

  static const double _kEpsilon = 0.0001;
  static const double _kSpeedScale = 220.0;

  MotionBezierControlPoints velocityToBezier({
    required MotionKeyframeVelocity velocity,
    bool allowOvershoot = false,
  }) {
    final incomingInfluence = (velocity.incomingInfluence ?? 33.333).abs();
    final outgoingInfluence = (velocity.outgoingInfluence ?? 33.333).abs();

    final clampedOutgoingInfluence = allowOvershoot
        ? outgoingInfluence.clamp(0.0, 200.0)
        : outgoingInfluence.clamp(0.0, 100.0);
    final clampedIncomingInfluence = allowOvershoot
        ? incomingInfluence.clamp(0.0, 200.0)
        : incomingInfluence.clamp(0.0, 100.0);

    final x1 =
        (clampedOutgoingInfluence / 100.0).clamp(_kEpsilon, 1.0 - _kEpsilon);
    final x2 = (1.0 - (clampedIncomingInfluence / 100.0))
        .clamp(_kEpsilon, 1.0 - _kEpsilon);

    final outgoingSpeedNorm =
        ((velocity.outgoingSpeed ?? 0.0) / _kSpeedScale).clamp(-2.0, 2.0);
    final incomingSpeedNorm =
        ((velocity.incomingSpeed ?? 0.0) / _kSpeedScale).clamp(-2.0, 2.0);

    final y1 = (outgoingSpeedNorm * x1).clamp(-2.0, 2.0).toDouble();
    final y2 =
        (1.0 - (incomingSpeedNorm * (1.0 - x2))).clamp(-2.0, 3.0).toDouble();

    final bezier = MotionBezierControlPoints(
      x1: x1.toDouble(),
      y1: y1,
      x2: x2.toDouble(),
      y2: y2,
    );
    _emitBridgeProof(
      inputMode: 'velocityNumbers',
      velocity: velocity,
      bezier: bezier,
      overshootPolicy:
          allowOvershoot ? 'allowBezierOvershoot' : 'disallowOvershoot',
      normalizedFallbackUsed: false,
      fallbackReason: 'none',
    );
    return bezier;
  }

  MotionKeyframeVelocity bezierToVelocity({
    required MotionBezierControlPoints bezier,
    String? presetId,
    bool continuous = false,
  }) {
    final x1 = bezier.x1.clamp(_kEpsilon, 1.0 - _kEpsilon).toDouble();
    final x2 = bezier.x2.clamp(_kEpsilon, 1.0 - _kEpsilon).toDouble();

    final outgoingInfluence = (x1 * 100.0).clamp(0.0, 100.0).toDouble();
    final incomingInfluence = ((1.0 - x2) * 100.0).clamp(0.0, 100.0).toDouble();

    final outgoingSpeedNorm = (bezier.y1 / math.max(x1, _kEpsilon));
    final incomingSpeedNorm =
        ((1.0 - bezier.y2) / math.max(1.0 - x2, _kEpsilon));

    final outgoingSpeed =
        (outgoingSpeedNorm * _kSpeedScale).clamp(-440.0, 440.0);
    final incomingSpeed =
        (incomingSpeedNorm * _kSpeedScale).clamp(-440.0, 440.0);

    final velocity = MotionKeyframeVelocity(
      incomingSpeed: incomingSpeed.toDouble(),
      outgoingSpeed: outgoingSpeed.toDouble(),
      incomingInfluence: incomingInfluence,
      outgoingInfluence: outgoingInfluence,
      incomingHandleLocked: continuous,
      outgoingHandleLocked: continuous,
      continuous: continuous,
      presetId: presetId,
    );
    _emitBridgeProof(
      inputMode: 'directBezier',
      velocity: velocity,
      bezier: bezier,
      overshootPolicy: 'bezierDerived',
      normalizedFallbackUsed: false,
      fallbackReason: 'none',
    );
    return velocity;
  }

  void _emitBridgeProof({
    required String inputMode,
    required MotionKeyframeVelocity velocity,
    required MotionBezierControlPoints bezier,
    required String overshootPolicy,
    required bool normalizedFallbackUsed,
    required String fallbackReason,
  }) {
    developer.log(
      'TF_SPEED_GRAPH_BRIDGE_PROOF '
      'inputMode=$inputMode '
      'segmentDurationSeconds=normalized '
      'valueDelta=normalized '
      'incomingSpeed=${velocity.incomingSpeed ?? 0.0} '
      'outgoingSpeed=${velocity.outgoingSpeed ?? 0.0} '
      'incomingInfluence=${velocity.incomingInfluence ?? 0.0} '
      'outgoingInfluence=${velocity.outgoingInfluence ?? 0.0} '
      'bezier='
      '${bezier.x1.toStringAsFixed(4)},'
      '${bezier.y1.toStringAsFixed(4)},'
      '${bezier.x2.toStringAsFixed(4)},'
      '${bezier.y2.toStringAsFixed(4)} '
      'overshootPolicy=$overshootPolicy '
      'normalizedFallbackUsed=$normalizedFallbackUsed '
      'fallbackReason=$fallbackReason',
      name: 'ReFusionXx.SpeedGraph',
    );
  }
}
