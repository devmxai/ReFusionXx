import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_interpolation_evaluator.dart';

void main() {
  test('linear curve keeps constant velocity and zero acceleration', () {
    const interpolation = MotionInterpolationSpec.linear();
    expect(evaluateMotionCurveVelocity(interpolation, 0.1), closeTo(1.0, 1e-9));
    expect(evaluateMotionCurveVelocity(interpolation, 0.5), closeTo(1.0, 1e-9));
    expect(
      evaluateMotionCurveAcceleration(interpolation, 0.5),
      closeTo(0.0, 1e-9),
    );
  });

  test(
      'easy-ease style cubic has near-zero endpoint velocity and faster middle',
      () {
    const interpolation = MotionInterpolationSpec.cubicBezier(
      bezier: MotionBezierControlPoints(
        x1: 0.3333,
        y1: 0.0,
        x2: 0.6667,
        y2: 1.0,
      ),
    );

    final startVelocity = evaluateMotionCurveVelocity(interpolation, 0.01);
    final midVelocity = evaluateMotionCurveVelocity(interpolation, 0.5);
    final endVelocity = evaluateMotionCurveVelocity(interpolation, 0.99);

    expect(startVelocity.abs(), lessThan(0.2));
    expect(endVelocity.abs(), lessThan(0.2));
    expect(midVelocity, greaterThan(startVelocity.abs()));
    expect(midVelocity, greaterThan(endVelocity.abs()));
  });

  test('sampleMotionCurve returns stable count and endpoints', () {
    const interpolation = MotionInterpolationSpec.easeInOut();
    final samples = sampleMotionCurve(interpolation, sampleCount: 9);
    expect(samples.length, 9);
    expect(samples.first.progress, 0.0);
    expect(samples.last.progress, 1.0);
    expect(samples.first.value, 0.0);
    expect(samples.last.value, 1.0);
  });
}
