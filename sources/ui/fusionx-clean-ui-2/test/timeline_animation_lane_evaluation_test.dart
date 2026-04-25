import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';

void main() {
  test('empty animation lane falls back to provided percent', () {
    const lane = TimelineAnimationLaneData(
      id: 'opacity-lane',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[],
      keyframeValues: <double>[],
    );

    expect(
      lane.evaluatePercentAtProgress(0.35, fallbackPercent: 100),
      100,
    );
  });

  test('empty animation lane aligned values are caller-owned', () {
    const lane = TimelineAnimationLaneData(
      id: 'opacity-lane',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[],
      keyframeValues: <double>[],
    );

    final values = lane.alignedKeyframeValues();

    values.insert(0, 25);
    expect(values, <double>[25]);
  });

  test('single keyframe holds a constant value across the clip', () {
    const lane = TimelineAnimationLaneData(
      id: 'opacity-lane',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0.4],
      keyframeValues: <double>[25],
    );

    expect(lane.evaluatePercentAtProgress(0.0, fallbackPercent: 100), 25);
    expect(lane.evaluatePercentAtProgress(0.75, fallbackPercent: 100), 25);
  });

  test('animation lane interpolates linearly between keyframes', () {
    const lane = TimelineAnimationLaneData(
      id: 'opacity-lane',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0.2, 0.8],
      keyframeValues: <double>[0, 100],
    );

    expect(lane.evaluatePercentAtProgress(0.2, fallbackPercent: 100), 0);
    expect(
      lane.evaluatePercentAtProgress(0.5, fallbackPercent: 100),
      closeTo(50, 0.000001),
    );
    expect(lane.evaluatePercentAtProgress(0.8, fallbackPercent: 100), 100);
  });

  test('animation lane clamps to first and last keyframe values', () {
    const lane = TimelineAnimationLaneData(
      id: 'opacity-lane',
      label: 'Opacity',
      targetClipId: 'clip-1',
      normalizedKeyframeStops: <double>[0.25, 0.75],
      keyframeValues: <double>[10, 90],
    );

    expect(lane.evaluatePercentAtProgress(0.0, fallbackPercent: 100), 10);
    expect(lane.evaluatePercentAtProgress(1.0, fallbackPercent: 100), 90);
  });
}
