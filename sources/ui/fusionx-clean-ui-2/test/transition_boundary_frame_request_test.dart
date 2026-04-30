import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_boundary_frame_request.dart';

void main() {
  const resolver = TransitionBoundaryFrameRequestResolver();

  TimelineClipData videoClip({
    TimelineTime sourceStartTime = TimelineTime.zero,
    TimelineTime durationTime = const TimelineTime(value: 2000000),
  }) {
    return TimelineClipData(
      id: 'clip-a',
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      contentKind: TimelineClipContentKind.media,
      visualKind: TimelineVisualKind.video,
      label: 'Clip A',
      durationTime: durationTime,
      assetId: 'asset-a',
      sourceStartTime: sourceStartTime,
      sourceDurationTime: durationTime,
    );
  }

  test('outgoing request samples the last visible frame before the seam', () {
    final request = resolver.resolve(
      clip: videoClip(
        sourceStartTime: TimelineTime.fromMilliseconds(400),
        durationTime: TimelineTime.fromMilliseconds(1200),
      ),
      sourceUri: 'content://video-a',
      role: TransitionBoundaryFrameRole.outgoing,
      frameDurationMs: 33,
      targetWidth: 480,
      targetHeight: 854,
    );

    expect(request, isNotNull);
    expect(request!.positionMs, 1567);
    expect(request.cacheKey, contains(':out:1567:480x854'));
  });

  test('incoming request samples the first visible frame of the next clip', () {
    final request = resolver.resolve(
      clip: videoClip(
        sourceStartTime: TimelineTime.fromMilliseconds(900),
        durationTime: TimelineTime.fromMilliseconds(1200),
      ),
      sourceUri: 'content://video-b',
      role: TransitionBoundaryFrameRole.incoming,
      frameDurationMs: 33,
      targetWidth: 480,
      targetHeight: 854,
    );

    expect(request, isNotNull);
    expect(request!.positionMs, 900);
    expect(request.cacheKey, contains(':in:900:480x854'));
  });

  test('outgoing request never samples before a trimmed source start', () {
    final request = resolver.resolve(
      clip: videoClip(
        sourceStartTime: TimelineTime.fromMilliseconds(1000),
        durationTime: TimelineTime.fromMilliseconds(16),
      ),
      sourceUri: 'content://video-a',
      role: TransitionBoundaryFrameRole.outgoing,
      frameDurationMs: 33,
      targetWidth: 480,
      targetHeight: 854,
    );

    expect(request, isNotNull);
    expect(request!.positionMs, 1000);
  });
}
