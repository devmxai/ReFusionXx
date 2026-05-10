import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_keyframe_motion_timeline_adapter.dart';

void main() {
  const adapter = UnifiedKeyframeMotionTimelineAdapter();

  TimelineTrackData textTrack() {
    return TimelineTrackData(
      kind: TimelineTrackKind.text,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'clip:a',
          type: TimelineClipType.media,
          tone: TimelineClipTone.aiGenerated,
          durationTime: TimelineTime.fromMilliseconds(1000),
          sourceStartTime: TimelineTime.zero,
          sourceDurationTime: TimelineTime.fromMilliseconds(1000),
          contentKind: TimelineClipContentKind.media,
          visualKind: TimelineVisualKind.text,
        ),
        TimelineClipData(
          id: 'clip:b',
          type: TimelineClipType.media,
          tone: TimelineClipTone.aiGenerated,
          durationTime: TimelineTime.fromMilliseconds(1500),
          sourceStartTime: TimelineTime.zero,
          sourceDurationTime: TimelineTime.fromMilliseconds(1500),
          contentKind: TimelineClipContentKind.media,
          visualKind: TimelineVisualKind.text,
        ),
      ],
      animationLanes: <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'lane:opacity',
          label: 'Opacity',
          targetClipId: 'clip:b',
          normalizedKeyframeStops: const <double>[0, 1],
          keyframeValues: const <double>[0, 100],
          keyframeIds: const <String>['k0', 'k1'],
        ),
      ],
    );
  }

  test('projects focused clip as local keyframe timeline', () {
    final result = adapter.project(
      UnifiedKeyframeMotionTimelineRequest(
        tracks: <TimelineTrackData>[textTrack()],
        focusedClipId: 'clip:b',
        globalTimelineTime: TimelineTime.fromMilliseconds(1800),
      ),
    );

    expect(result.hasIssues, isFalse);
    expect(result.focusedTrack, isNotNull);
    expect(result.focusedTrack!.clips.single.id, 'clip:b');
    expect(result.focusedTrack!.animationLanes, hasLength(1));
    expect(result.timeDisplayOffset, TimelineTime.fromMilliseconds(1000));
    expect(result.localTimelineTime, TimelineTime.fromMilliseconds(800));
    expect(result.durationTime, TimelineTime.fromMilliseconds(1500));
  });

  test('reports not found diagnostic when focus clip is missing', () {
    final result = adapter.project(
      UnifiedKeyframeMotionTimelineRequest(
        tracks: <TimelineTrackData>[textTrack()],
        focusedClipId: 'missing',
        globalTimelineTime: TimelineTime.fromMilliseconds(300),
      ),
    );

    expect(result.focusedTrack, isNull);
    expect(result.hasIssues, isTrue);
    expect(
      result.issues.first.code,
      UnifiedKeyframeMotionTimelineIssueCode.focusTargetNotFound,
    );
  });

  test('reports missing-lane diagnostic while still projecting clip', () {
    final track = TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'clip:v',
          type: TimelineClipType.media,
          tone: TimelineClipTone.aiGenerated,
          durationTime: TimelineTime.fromMilliseconds(2000),
          sourceStartTime: TimelineTime.zero,
          sourceDurationTime: TimelineTime.fromMilliseconds(2000),
          contentKind: TimelineClipContentKind.media,
          visualKind: TimelineVisualKind.video,
        ),
      ],
    );
    final result = adapter.project(
      UnifiedKeyframeMotionTimelineRequest(
        tracks: <TimelineTrackData>[track],
        focusedClipId: 'clip:v',
        globalTimelineTime: TimelineTime.fromMilliseconds(400),
      ),
    );

    expect(result.focusedTrack, isNotNull);
    expect(result.focusedTrack!.clips.single.id, 'clip:v');
    expect(result.hasIssues, isTrue);
    expect(
      result.issues.first.code,
      UnifiedKeyframeMotionTimelineIssueCode.noEditableLanesForTarget,
    );
  });
}
