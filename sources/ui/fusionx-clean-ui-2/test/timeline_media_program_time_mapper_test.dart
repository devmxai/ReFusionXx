import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/timeline_media_program_time_mapper.dart';

void main() {
  const mapper = TimelineMediaProgramTimeMapper();

  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineClipData mediaClip(String id, int durationMs) {
    return TimelineClipData(
      id: id,
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      assetId: id,
      durationTime: ms(durationMs),
    );
  }

  TimelineClipData gap(String id, int durationMs) {
    return TimelineClipData(
      id: id,
      type: TimelineClipType.placeholder,
      tone: TimelineClipTone.placeholder,
      durationTime: ms(durationMs),
      label: '',
    );
  }

  TimelineTrackData videoTrack(List<TimelineClipData> clips) {
    return TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: clips,
    );
  }

  test('keeps authored gaps out of compact native media program time', () {
    final tracks = <TimelineTrackData>[
      videoTrack(<TimelineClipData>[
        mediaClip('a', 2000),
        gap('gap', 1000),
        mediaClip('b', 3000),
      ]),
    ];

    expect(mapper.programDurationForTracks(tracks), ms(5000));
    expect(mapper.programTimeForTimelineTime(tracks, ms(500)), ms(500));
    expect(mapper.programTimeForTimelineTime(tracks, ms(2500)), isNull);
    expect(mapper.programTimeForTimelineTime(tracks, ms(3000)), ms(2000));
    expect(mapper.programTimeForTimelineTime(tracks, ms(4500)), ms(3500));
  });

  test('maps authored gaps to compact program boundaries without raw fallback',
      () {
    final tracks = <TimelineTrackData>[
      videoTrack(<TimelineClipData>[
        mediaClip('a', 2000),
        gap('gap', 1000),
        mediaClip('b', 3000),
      ]),
    ];

    expect(
      mapper.programBoundaryTimeForTimelineTime(tracks, ms(2500)),
      ms(2000),
    );
    expect(
      mapper.programBoundaryTimeForTimelineTime(tracks, ms(7000)),
      ms(5000),
    );
  });

  test('maps compact native media program time back to authored scene time',
      () {
    final tracks = <TimelineTrackData>[
      videoTrack(<TimelineClipData>[
        mediaClip('a', 2000),
        gap('gap', 1000),
        mediaClip('b', 3000),
      ]),
    ];

    expect(mapper.timelineTimeForProgramTime(tracks, ms(500)), ms(500));
    expect(mapper.timelineTimeForProgramTime(tracks, ms(2000)), ms(2000));
    expect(mapper.timelineTimeForProgramTime(tracks, ms(2001)), ms(3001));
    expect(mapper.nextMediaTimelineTimeAtOrAfter(tracks, ms(2500)), ms(3000));
  });
}
