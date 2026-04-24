import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  test('manual transition lanes evaluate raw values without percent clamping',
      () {
    const lane = TimelineAnimationLaneData(
      id: 'incomingStartScale',
      label: 'Incoming Scale',
      targetClipId: 'clip-a',
      normalizedKeyframeStops: <double>[0.0, 1.0],
      keyframeValues: <double>[118.0, 100.0],
    );
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1200),
      manualAnimationLanes: const <TimelineAnimationLaneData>[lane],
    );

    expect(
      transition.manualLaneValueAtProgress(
        'incomingStartScale',
        0.0,
        fallbackValue: 100.0,
      ),
      118.0,
    );
    expect(
      transition.manualLaneValueAtProgress(
        'incomingStartScale',
        1.0,
        fallbackValue: 100.0,
      ),
      100.0,
    );
  });

  test('manual lane fallback returns provided value when lane is absent', () {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(1200),
    );

    expect(
      transition.manualLaneValueAtProgress(
        'blackPeak',
        0.5,
        fallbackValue: 42.0,
      ),
      42.0,
    );
  });
}
