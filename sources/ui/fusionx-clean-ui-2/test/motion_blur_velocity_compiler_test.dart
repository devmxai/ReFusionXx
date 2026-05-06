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
    expect(directive.sampleCount, greaterThanOrEqualTo(6));
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
}
