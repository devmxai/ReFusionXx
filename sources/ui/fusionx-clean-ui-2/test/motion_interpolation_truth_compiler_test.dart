import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_interpolation_evaluator.dart';
import 'package:refusion_app/features/editor/domain/services/motion_bezier_velocity_bridge.dart';
import 'package:refusion_app/features/editor/domain/services/motion_interpolation_truth_compiler.dart';

void main() {
  const compiler = MotionInterpolationTruthCompiler();

  test('compileFromPresetId maps easyEase aliases to cubic bezier truth', () {
    final result = compiler.compileFromPresetId('f9');
    expect(result.interpolation.kind, MotionInterpolationKind.cubicBezier);
    expect(result.interpolation.bezier, isNotNull);
    expect(result.interpolation.bezier!.x1, closeTo(0.3333, 1e-4));
    expect(result.interpolation.bezier!.x2, closeTo(0.6667, 1e-4));
    expect(result.interpolation.velocity?.presetId, 'easyEase');
  });

  test('compileFromPresetId supports fastSlowFast plateau preset', () {
    final result = compiler.compileFromPresetId('fastSlowFast');
    expect(result.interpolation.kind, MotionInterpolationKind.cubicBezier);
    expect(result.interpolation.bezier!.x1, closeTo(0.12, 1e-4));
    expect(result.interpolation.bezier!.y1, closeTo(0.72, 1e-4));
    expect(result.interpolation.bezier!.x2, closeTo(0.88, 1e-4));
    expect(result.interpolation.bezier!.y2, closeTo(0.28, 1e-4));
  });

  test('compileFromVelocity generates bezier for custom speed graph input', () {
    const velocity = MotionKeyframeVelocity(
      incomingSpeed: 100.0,
      outgoingSpeed: 40.0,
      incomingInfluence: 70.0,
      outgoingInfluence: 20.0,
      presetId: 'customSpeedGraph',
    );
    final result = compiler.compileFromVelocity(velocity: velocity);
    expect(result.interpolation.kind, MotionInterpolationKind.cubicBezier);
    expect(result.interpolation.bezier, isNotNull);
    expect(result.interpolation.velocity?.presetId, 'customSpeedGraph');
  });

  test('compileFromVelocity keeps preset truth when preset id is known', () {
    const velocity = MotionKeyframeVelocity(
      incomingInfluence: 85.0,
      outgoingInfluence: 85.0,
      presetId: 'slowFastSlow',
    );
    final result = compiler.compileFromVelocity(velocity: velocity);
    expect(result.interpolation.kind, MotionInterpolationKind.cubicBezier);
    expect(result.interpolation.bezier!.x1, closeTo(0.2, 1e-6));
    expect(result.interpolation.bezier!.x2, closeTo(0.8, 1e-6));
    final start = evaluateMotionCurveVelocity(result.interpolation, 0.05);
    final mid = evaluateMotionCurveVelocity(result.interpolation, 0.5);
    final end = evaluateMotionCurveVelocity(result.interpolation, 0.95);
    expect(mid, greaterThan(start));
    expect(mid, greaterThan(end));
  });

  test('compileFromInterpolation mirrors velocity from bezier truth', () {
    const interpolation = MotionInterpolationSpec.cubicBezier(
      bezier: MotionBezierControlPoints(
        x1: 0.3333,
        y1: 0.0,
        x2: 0.6667,
        y2: 1.0,
      ),
    );
    final result = compiler.compileFromInterpolation(
      interpolation: interpolation,
    );
    expect(result.interpolation.velocity, isNotNull);
    expect(result.interpolation.velocity!.incomingInfluence, closeTo(33.33, 0.2));
    expect(result.interpolation.velocity!.outgoingInfluence, closeTo(33.33, 0.2));
  });

  test('compileFromVelocity respects disallow overshoot policy clamp', () {
    const velocity = MotionKeyframeVelocity(
      incomingInfluence: 180.0,
      outgoingInfluence: 160.0,
      presetId: 'customSpeedGraph',
    );
    final disallow = compiler.compileFromVelocity(
      velocity: velocity,
      overshootPolicy: MotionPropertyOvershootPolicy.disallow,
    );
    final allow = compiler.compileFromVelocity(
      velocity: velocity,
      overshootPolicy: MotionPropertyOvershootPolicy.allowBezierOvershoot,
    );
    expect(disallow.interpolation.bezier!.x1, lessThanOrEqualTo(0.9999));
    expect(disallow.interpolation.bezier!.x2, greaterThanOrEqualTo(0.0001));
    expect(allow.interpolation.bezier!.x1, closeTo(0.9999, 1e-6));
  });
}
