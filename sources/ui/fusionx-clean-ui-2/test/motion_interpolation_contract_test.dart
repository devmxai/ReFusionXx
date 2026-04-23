import 'package:flutter_test/flutter_test.dart';

import 'package:refusion_app/features/editor/domain/models/export_motion_text_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_interpolation_evaluator.dart';

void main() {
  test('core interpolation spec exposes canonical bounce and elastic payloads',
      () {
    const bounce = MotionInterpolationSpec.bounce(
      bounce: MotionBounceSpec(
        amplitude: 0.2,
        bounces: 4,
        decay: 6.0,
      ),
    );
    const elastic = MotionInterpolationSpec.elastic(
      elastic: MotionElasticSpec(
        amplitude: 0.12,
        period: 0.3,
        decay: 7.0,
      ),
    );

    expect(bounce.kind, MotionInterpolationKind.bounce);
    expect(bounce.bounce, isNotNull);
    expect(bounce.bounce!.bounces, 4);

    expect(elastic.kind, MotionInterpolationKind.elastic);
    expect(elastic.elastic, isNotNull);
    expect(elastic.elastic!.period, 0.3);
  });

  test('export interpolation bridge preserves bounce and elastic params', () {
    const interpolation = ExportMotionInterpolationSpec(
      kind: 'bounce',
      bounce: ExportMotionBounceSpec(
        amplitude: 0.22,
        bounces: 3,
        decay: 5.5,
      ),
    );
    const elastic = ExportMotionInterpolationSpec(
      kind: 'elastic',
      elastic: ExportMotionElasticSpec(
        amplitude: 0.14,
        period: 0.28,
        decay: 7.25,
      ),
    );

    final bounceMap = interpolation.toBridgeMap();
    final elasticMap = elastic.toBridgeMap();

    expect((bounceMap['bounce'] as Map<Object?, Object?>)['amplitude'], 0.22);
    expect((bounceMap['bounce'] as Map<Object?, Object?>)['bounces'], 3);
    expect((bounceMap['bounce'] as Map<Object?, Object?>)['decay'], 5.5);

    expect((elasticMap['elastic'] as Map<Object?, Object?>)['amplitude'], 0.14);
    expect((elasticMap['elastic'] as Map<Object?, Object?>)['period'], 0.28);
    expect((elasticMap['elastic'] as Map<Object?, Object?>)['decay'], 7.25);
  });

  test('spring evaluator produces a non-linear overshoot for underdamped specs',
      () {
    const interpolation = MotionInterpolationSpec.spring(
      spring: MotionSpringSpec(
        stiffness: 220,
        damping: 18,
        mass: 1,
        initialVelocity: 0,
      ),
    );

    final sample = evaluateMotionCurveProgress(interpolation, 0.25);

    expect(sample, greaterThan(1.0));
  });

  test('bounce evaluator stays anchored while differing from linear', () {
    const interpolation = MotionInterpolationSpec.bounce(
      bounce: MotionBounceSpec(
        amplitude: 0.22,
        bounces: 3,
        decay: 6.0,
      ),
    );

    expect(evaluateMotionCurveProgress(interpolation, 0.0), 0.0);
    expect(evaluateMotionCurveProgress(interpolation, 1.0), 1.0);
    expect(
      evaluateMotionCurveProgress(interpolation, 0.65),
      greaterThan(0.65),
    );
  });

  test('elastic evaluator oscillates and lands on the target', () {
    const interpolation = MotionInterpolationSpec.elastic(
      elastic: MotionElasticSpec(
        amplitude: 0.14,
        period: 0.28,
        decay: 8.0,
      ),
    );

    final mid = evaluateMotionCurveProgress(interpolation, 0.2);
    final nearEnd = evaluateMotionCurveProgress(interpolation, 1.0);

    expect(mid, isNot(closeTo(0.2, 0.0001)));
    expect(nearEnd, closeTo(1.0, 0.0001));
  });
}
