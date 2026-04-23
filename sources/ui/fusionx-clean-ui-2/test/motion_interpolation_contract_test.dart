import 'package:flutter_test/flutter_test.dart';

import 'package:refusion_app/features/editor/domain/models/export_motion_text_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';

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
}
