import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_interpolation_evaluator.dart';
import 'package:refusion_app/features/editor/presentation/widgets/professional_speed_graph_preset_card.dart';

void main() {
  test('thumbnail sampler uses evaluator progress and caches by curve hash',
      () {
    const interpolation = MotionInterpolationSpec.cubicBezier(
      bezier: MotionBezierControlPoints(
        x1: 0.2,
        y1: 0.0,
        x2: 0.8,
        y2: 1.0,
      ),
    );
    const hash = 'curve:test:slowFastSlow';
    final before = ProfessionalSpeedGraphThumbnailSampler.cacheSize;
    final sampled = ProfessionalSpeedGraphThumbnailSampler.sampleCurve(
      curveHash: hash,
      interpolation: interpolation,
      sampleCount: 40,
    );
    expect(sampled.length, 41);
    expect(sampled.first, closeTo(0.0, 1e-9));
    expect(sampled.last, closeTo(1.0, 1e-9));
    expect(
      sampled[20],
      closeTo(evaluateMotionCurveProgress(interpolation, 0.5), 1e-9),
    );

    final sampledAgain = ProfessionalSpeedGraphThumbnailSampler.sampleCurve(
      curveHash: hash,
      interpolation: interpolation,
      sampleCount: 40,
    );
    expect(identical(sampled, sampledAgain), isTrue);
    expect(ProfessionalSpeedGraphThumbnailSampler.cacheSize, before + 1);
  });
}
