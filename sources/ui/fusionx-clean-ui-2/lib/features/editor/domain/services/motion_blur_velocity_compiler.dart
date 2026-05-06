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
    final shutterScale = (policy.shutterAngleDegrees / 360.0).clamp(0.0, 4.0);
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
    final clampedAmount = policy.amount.clamp(0.0, 1.0);
    final radialOmega = rotationDelta * clampedAmount;
    final scaleVelocityX = scaleDeltaX * clampedAmount;
    final scaleVelocityY = scaleDeltaY * clampedAmount;
    final minCanvas = math.max(1.0, math.min(canvasWidth, canvasHeight));
    final rotationTrail = radialOmega.abs() * minCanvas * 0.35;
    final scaleTrail =
        math.max(scaleVelocityX.abs(), scaleVelocityY.abs()) * minCanvas * 0.25;
    final requestedKernelLength =
        (motionMagnitude + rotationTrail + scaleTrail) *
            shutterScale *
            clampedAmount;
    final kernelLengthPx = requestedKernelLength.clamp(0.0, policy.maxTrailPx);
    final hasMeaningfulVelocity = kernelLengthPx > 0.5;
    final sampleCount = _sampleCountFor(
      quality: quality,
      requested: policy.samples,
      adaptiveLimit: policy.adaptiveSampleLimit,
      hasMeaningfulVelocity: hasMeaningfulVelocity,
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
  }) {
    if (!hasMeaningfulVelocity) {
      return 1;
    }
    final boundedRequested = requested.clamp(1, math.max(1, adaptiveLimit));
    final qualityFloor = switch (quality) {
      MotionBlurDirectiveQuality.liveScrub => 4,
      MotionBlurDirectiveQuality.playback => 6,
      MotionBlurDirectiveQuality.preview => 8,
      MotionBlurDirectiveQuality.export => 8,
    };
    return math.max(qualityFloor, boundedRequested).clamp(1, 12).toInt();
  }
}
