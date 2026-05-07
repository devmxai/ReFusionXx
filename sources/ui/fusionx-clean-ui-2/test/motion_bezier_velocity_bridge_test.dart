import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/services/motion_bezier_velocity_bridge.dart';

void main() {
  const bridge = MotionBezierVelocityBridge();

  test('velocityToBezier keeps easy ease anchors for zero speeds', () {
    const velocity = MotionKeyframeVelocity(
      incomingSpeed: 0.0,
      outgoingSpeed: 0.0,
      incomingInfluence: 33.333,
      outgoingInfluence: 33.333,
      continuous: true,
      presetId: 'easyEase',
    );
    final bezier = bridge.velocityToBezier(velocity: velocity);
    expect(bezier.x1, closeTo(0.33333, 1e-3));
    expect(bezier.y1, closeTo(0.0, 1e-6));
    expect(bezier.x2, closeTo(0.66667, 1e-3));
    expect(bezier.y2, closeTo(1.0, 1e-6));
  });

  test('bezierToVelocity recovers easy ease style influence and speed', () {
    const bezier = MotionBezierControlPoints(
      x1: 0.3333,
      y1: 0.0,
      x2: 0.6667,
      y2: 1.0,
    );
    final velocity = bridge.bezierToVelocity(
      bezier: bezier,
      presetId: 'easyEase',
      continuous: true,
    );
    expect(velocity.incomingInfluence, closeTo(33.33, 0.2));
    expect(velocity.outgoingInfluence, closeTo(33.33, 0.2));
    expect((velocity.incomingSpeed ?? 0.0).abs(), lessThan(0.5));
    expect((velocity.outgoingSpeed ?? 0.0).abs(), lessThan(0.5));
    expect(velocity.presetId, 'easyEase');
  });

  test('velocityToBezier reflects non-zero speeds in control points', () {
    const velocity = MotionKeyframeVelocity(
      incomingSpeed: 90.0,
      outgoingSpeed: 40.0,
      incomingInfluence: 70.0,
      outgoingInfluence: 20.0,
      presetId: 'customSpeedGraph',
    );
    final bezier = bridge.velocityToBezier(velocity: velocity);
    expect(bezier.x1, closeTo(0.2, 1e-4));
    expect(bezier.x2, closeTo(0.3, 1e-4));
    expect(bezier.y1, greaterThan(0.0));
    expect(bezier.y2, lessThan(1.0));
  });
}

