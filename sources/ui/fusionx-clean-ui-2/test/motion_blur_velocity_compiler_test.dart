import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/motion_blur_velocity_compiler.dart';

void main() {
  const compiler = MotionBlurVelocityCompiler();

  test('amount zero disables directive', () {
    final directive = compiler.compile(
      policy: const MasterMotionBlurPolicy(
        enabled: true,
        amount: 0.0,
      ),
      current: const LiveScrubSurfaceTransform(positionX: 120, positionY: 0),
      previous: const LiveScrubSurfaceTransform(positionX: 0, positionY: 0),
      quality: MotionBlurDirectiveQuality.liveScrub,
      canvasWidth: 1080,
      canvasHeight: 1920,
    );

    expect(directive.enabled, isFalse);
    expect(directive.fallbackReason, 'motion_blur_amount_zero');
  });

  test('position delta produces velocity directive', () {
    final directive = compiler.compile(
      policy: const MasterMotionBlurPolicy(
        enabled: true,
        amount: 1.0,
        shutterAngleDegrees: 180,
      ),
      current: const LiveScrubSurfaceTransform(positionX: 200, positionY: 0),
      previous: const LiveScrubSurfaceTransform(positionX: 100, positionY: 0),
      quality: MotionBlurDirectiveQuality.playback,
      canvasWidth: 1080,
      canvasHeight: 1920,
    );

    expect(directive.enabled, isTrue);
    expect(directive.kernelLengthPx, greaterThan(0.5));
    expect(directive.directionX, closeTo(1.0, 0.001));
    expect(directive.directionY, closeTo(0.0, 0.001));
    expect(directive.sampleCount, greaterThanOrEqualTo(8));
  });

  test('maxTrailPx clamps kernel length', () {
    final directive = compiler.compile(
      policy: const MasterMotionBlurPolicy(
        enabled: true,
        amount: 1.0,
        shutterAngleDegrees: 360,
        maxTrailPx: 24,
      ),
      current: const LiveScrubSurfaceTransform(positionX: 1000, positionY: 0),
      previous: const LiveScrubSurfaceTransform(positionX: 0, positionY: 0),
      quality: MotionBlurDirectiveQuality.preview,
      canvasWidth: 1080,
      canvasHeight: 1920,
    );

    expect(directive.enabled, isTrue);
    expect(directive.kernelLengthPx, lessThanOrEqualTo(24.0));
  });

  test('rotation delta preserves authored multi-turn travel', () {
    final directive = compiler.compile(
      policy: const MasterMotionBlurPolicy(
        enabled: true,
        amount: 1.0,
        shutterAngleDegrees: 180,
      ),
      current: const LiveScrubSurfaceTransform(rotationRadians: 0.05),
      previous: const LiveScrubSurfaceTransform(rotationRadians: 6.20),
      quality: MotionBlurDirectiveQuality.preview,
      canvasWidth: 1080,
      canvasHeight: 1920,
    );

    expect(directive.enabled, isTrue);
    expect(directive.radialOmega.abs(), greaterThan(6.0));
  });

  test('amount is not double applied to radial and scale channels', () {
    final policy = const MasterMotionBlurPolicy(
      enabled: true,
      amount: 0.5,
      shutterAngleDegrees: 180,
      maxTrailPx: 240,
    );
    final directive = compiler.compile(
      policy: policy,
      current: const LiveScrubSurfaceTransform(
        rotationRadians: 0.6,
        scaleX: 1.2,
        scaleY: 1.1,
      ),
      previous: const LiveScrubSurfaceTransform(
        rotationRadians: 0.2,
        scaleX: 1.0,
        scaleY: 1.0,
      ),
      quality: MotionBlurDirectiveQuality.playback,
      canvasWidth: 1080,
      canvasHeight: 1920,
    );

    expect(directive.radialOmega, closeTo(0.4, 1e-6));
    expect(directive.scaleVelocityX, closeTo(0.2, 1e-6));
    expect(directive.scaleVelocityY, closeTo(0.1, 1e-6));
  });

  test('quality tiers raise sample counts for playback and export', () {
    final policy = const MasterMotionBlurPolicy(
      enabled: true,
      amount: 1.0,
      samples: 12,
      adaptiveSampleLimit: 24,
      maxTrailPx: 240,
    );
    final playback = compiler.compile(
      policy: policy,
      current: const LiveScrubSurfaceTransform(positionX: 180),
      previous: const LiveScrubSurfaceTransform(positionX: 0),
      quality: MotionBlurDirectiveQuality.playback,
      canvasWidth: 1080,
      canvasHeight: 1920,
    );
    final export = compiler.compile(
      policy: policy,
      current: const LiveScrubSurfaceTransform(positionX: 180),
      previous: const LiveScrubSurfaceTransform(positionX: 0),
      quality: MotionBlurDirectiveQuality.export,
      canvasWidth: 1080,
      canvasHeight: 1920,
    );

    expect(playback.sampleCount, inInclusiveRange(8, 16));
    expect(export.sampleCount, inInclusiveRange(16, 24));
    expect(export.sampleCount, greaterThanOrEqualTo(playback.sampleCount));
  });
}
