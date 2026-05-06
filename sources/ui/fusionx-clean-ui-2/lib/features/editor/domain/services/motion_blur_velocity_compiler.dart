import 'dart:math' as math;

import '../../../../core/engine/stage5_visual_runtime_state.dart';
import '../models/master_live_scrub_visual_program_models.dart';
import '../models/master_visual_program_models.dart';

enum MotionBlurDirectiveQuality {
  liveScrub,
  playback,
  preview,
  export,
}

class MotionBlurVelocityCompiler {
  const MotionBlurVelocityCompiler();

  Stage5VisualRuntimeMotionBlurDirective compile({
    required MasterMotionBlurPolicy policy,
    required LiveScrubSurfaceTransform current,
    required LiveScrubSurfaceTransform previous,
    required MotionBlurDirectiveQuality quality,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    if (!policy.enabled || policy.amount <= 0.001) {
      return _disabledDirective(policy,
          fallbackReason: 'motion_blur_amount_zero');
    }
    final clampedAmount = policy.amount.clamp(0.0, 1.0);
    final shutterScale = (policy.shutterAngleDegrees / 180.0).clamp(0.0, 4.0);
    final dx =
        policy.affectPosition ? (current.positionX - previous.positionX) : 0.0;
    final dy =
        policy.affectPosition ? (current.positionY - previous.positionY) : 0.0;
    final motionMagnitude = math.sqrt((dx * dx) + (dy * dy));
    final directionX = motionMagnitude > 0.00001 ? (dx / motionMagnitude) : 0.0;
    final directionY = motionMagnitude > 0.00001 ? (dy / motionMagnitude) : 0.0;
    final rotationDelta = policy.affectRotation
        ? (current.rotationRadians - previous.rotationRadians)
        : 0.0;
    final scaleDeltaX =
        policy.affectScale ? (current.scaleX - previous.scaleX) : 0.0;
    final scaleDeltaY =
        policy.affectScale ? (current.scaleY - previous.scaleY) : 0.0;
    final radialOmega = rotationDelta * shutterScale;
    final scaleVelocityX = scaleDeltaX * shutterScale;
    final scaleVelocityY = scaleDeltaY * shutterScale;
    final minCanvas = math.max(1.0, math.min(canvasWidth, canvasHeight));
    final linearTrail = (motionMagnitude * shutterScale) * clampedAmount;
    final rotationTrail = radialOmega.abs() * minCanvas * 0.35 * clampedAmount;
    final scaleTrail = math.max(scaleVelocityX.abs(), scaleVelocityY.abs()) *
        minCanvas *
        0.25 *
        clampedAmount;
    final kernelLengthPx = linearTrail.clamp(0.0, policy.maxTrailPx);
    final hasMeaningfulVelocity =
        kernelLengthPx > 0.5 || rotationTrail > 0.5 || scaleTrail > 0.5;
    final sampleCount = _sampleCountFor(
      quality: quality,
      requested: policy.samples,
      adaptiveLimit: policy.adaptiveSampleLimit,
      hasMeaningfulVelocity: hasMeaningfulVelocity,
      kernelLengthPx: kernelLengthPx,
      maxTrailPx: policy.maxTrailPx,
    );
    final fallbackReason =
        hasMeaningfulVelocity ? null : 'motion_blur_velocity_zero';
    return Stage5VisualRuntimeMotionBlurDirective(
      enabled: hasMeaningfulVelocity,
      amount: clampedAmount,
      kernelLengthPx: kernelLengthPx,
      directionX: directionX,
      directionY: directionY,
      radialOmega: radialOmega,
      scaleVelocityX: scaleVelocityX,
      scaleVelocityY: scaleVelocityY,
      anchorXNormalized: 0.5,
      anchorYNormalized: 0.5,
      shutterAngleDegrees: policy.shutterAngleDegrees,
      shutterPhase: (policy.shutterPhaseDegrees / 180.0).clamp(-1.0, 1.0),
      sampleCount: sampleCount,
      maxTrailPx: policy.maxTrailPx,
      mode: 'transformVelocity',
      fallbackReason: fallbackReason,
    );
  }

  Stage5VisualRuntimeMotionBlurDirective _disabledDirective(
    MasterMotionBlurPolicy policy, {
    required String fallbackReason,
  }) {
    return Stage5VisualRuntimeMotionBlurDirective(
      enabled: false,
      amount: policy.amount.clamp(0.0, 1.0),
      kernelLengthPx: 0.0,
      directionX: 0.0,
      directionY: 0.0,
      radialOmega: 0.0,
      scaleVelocityX: 0.0,
      scaleVelocityY: 0.0,
      anchorXNormalized: 0.5,
      anchorYNormalized: 0.5,
      shutterAngleDegrees: policy.shutterAngleDegrees,
      shutterPhase: (policy.shutterPhaseDegrees / 180.0).clamp(-1.0, 1.0),
      sampleCount: 1,
      maxTrailPx: policy.maxTrailPx,
      mode: 'transformVelocity',
      fallbackReason: fallbackReason,
    );
  }

  int _sampleCountFor({
    required MotionBlurDirectiveQuality quality,
    required int requested,
    required int adaptiveLimit,
    required bool hasMeaningfulVelocity,
    required double kernelLengthPx,
    required double maxTrailPx,
  }) {
    if (!hasMeaningfulVelocity) {
      return 1;
    }
    final boundedRequested = requested.clamp(1, math.max(1, adaptiveLimit));
    final qualityFloor = switch (quality) {
      MotionBlurDirectiveQuality.liveScrub => 6,
      MotionBlurDirectiveQuality.playback => 8,
      MotionBlurDirectiveQuality.preview => 12,
      MotionBlurDirectiveQuality.export => 16,
    };
    final maxByQuality = switch (quality) {
      MotionBlurDirectiveQuality.liveScrub => 8,
      MotionBlurDirectiveQuality.playback => 16,
      MotionBlurDirectiveQuality.preview => 24,
      MotionBlurDirectiveQuality.export => 24,
    };
    final adaptiveCeiling = adaptiveLimit.clamp(1, maxByQuality);
    final trailRatio = maxTrailPx <= 0.0 ? 0.0 : (kernelLengthPx / maxTrailPx);
    final adaptiveBoost = switch (quality) {
      MotionBlurDirectiveQuality.liveScrub => trailRatio > 0.35 ? 1 : 0,
      MotionBlurDirectiveQuality.playback =>
        trailRatio > 0.35 ? 2 : (trailRatio > 0.2 ? 1 : 0),
      MotionBlurDirectiveQuality.preview =>
        trailRatio > 0.45 ? 4 : (trailRatio > 0.25 ? 2 : 0),
      MotionBlurDirectiveQuality.export =>
        trailRatio > 0.45 ? 6 : (trailRatio > 0.25 ? 3 : 0),
    };
    final requestedWithBoost =
        (boundedRequested + adaptiveBoost).clamp(1, adaptiveCeiling).toInt();
    final unclamped = math.max(qualityFloor, requestedWithBoost);
    return unclamped.clamp(1, maxByQuality).toInt();
  }
}
