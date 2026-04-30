import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

class TimelineMediaProgramTimeMapper {
  const TimelineMediaProgramTimeMapper();

  TimelineTrackData? primaryVideoTrackFor(List<TimelineTrackData> tracks) {
    for (final track in tracks) {
      if (track.kind == TimelineTrackKind.video) {
        return track;
      }
    }
    return null;
  }

  TimelineTime programDurationForTracks(List<TimelineTrackData> tracks) {
    final track = primaryVideoTrackFor(tracks);
    if (track == null) {
      return TimelineTime.zero;
    }
    var duration = TimelineTime.zero;
    for (final clip in track.clips) {
      if (_isPlayableMediaClip(clip)) {
        duration += clip.durationTime;
      }
    }
    return duration;
  }

  TimelineTime? programTimeForTimelineTime(
    List<TimelineTrackData> tracks,
    TimelineTime timelineTime,
  ) {
    final track = primaryVideoTrackFor(tracks);
    if (track == null) {
      return null;
    }
    var timelineCursor = TimelineTime.zero;
    var programCursor = TimelineTime.zero;
    for (final clip in track.clips) {
      final clipStartTime = timelineCursor;
      final clipEndTime = clipStartTime + clip.durationTime;
      if (_isPlayableMediaClip(clip)) {
        if (timelineTime >= clipStartTime && timelineTime < clipEndTime) {
          return programCursor + (timelineTime - clipStartTime);
        }
        programCursor += clip.durationTime;
      }
      timelineCursor = clipEndTime;
    }
    return null;
  }

  TimelineTime programBoundaryTimeForTimelineTime(
    List<TimelineTrackData> tracks,
    TimelineTime timelineTime,
  ) {
    final track = primaryVideoTrackFor(tracks);
    if (track == null) {
      return TimelineTime.zero;
    }
    var timelineCursor = TimelineTime.zero;
    var programCursor = TimelineTime.zero;
    for (final clip in track.clips) {
      final clipStartTime = timelineCursor;
      final clipEndTime = clipStartTime + clip.durationTime;
      if (timelineTime < clipStartTime) {
        return programCursor;
      }
      if (_isPlayableMediaClip(clip)) {
        if (timelineTime <= clipEndTime) {
          final localOffset = (timelineTime - clipStartTime).clamp(
            TimelineTime.zero,
            clip.durationTime,
          );
          return programCursor + localOffset;
        }
        programCursor += clip.durationTime;
      } else if (timelineTime >= clipStartTime && timelineTime < clipEndTime) {
        return programCursor;
      }
      timelineCursor = clipEndTime;
    }
    return programCursor;
  }

  TimelineTime? timelineTimeForProgramTime(
    List<TimelineTrackData> tracks,
    TimelineTime programTime,
  ) {
    final track = primaryVideoTrackFor(tracks);
    if (track == null) {
      return null;
    }
    var timelineCursor = TimelineTime.zero;
    var programCursor = TimelineTime.zero;
    TimelineTime? lastMediaEndTime;
    for (final clip in track.clips) {
      final clipStartTime = timelineCursor;
      final clipEndTime = clipStartTime + clip.durationTime;
      if (_isPlayableMediaClip(clip)) {
        final nextProgramCursor = programCursor + clip.durationTime;
        if (programTime <= nextProgramCursor) {
          return clipStartTime +
              (programTime - programCursor).clamp(
                TimelineTime.zero,
                clip.durationTime,
              );
        }
        programCursor = nextProgramCursor;
        lastMediaEndTime = clipEndTime;
      }
      timelineCursor = clipEndTime;
    }
    return lastMediaEndTime;
  }

  TimelineTime? nextMediaTimelineTimeAtOrAfter(
    List<TimelineTrackData> tracks,
    TimelineTime timelineTime,
  ) {
    final track = primaryVideoTrackFor(tracks);
    if (track == null) {
      return null;
    }
    var timelineCursor = TimelineTime.zero;
    for (final clip in track.clips) {
      final clipStartTime = timelineCursor;
      final clipEndTime = clipStartTime + clip.durationTime;
      if (_isPlayableMediaClip(clip)) {
        if (timelineTime < clipStartTime) {
          return clipStartTime;
        }
        if (timelineTime >= clipStartTime && timelineTime < clipEndTime) {
          return timelineTime;
        }
      }
      timelineCursor = clipEndTime;
    }
    return null;
  }

  bool _isPlayableMediaClip(TimelineClipData clip) {
    return clip.type == TimelineClipType.media &&
        clip.assetId != null &&
        clip.durationTime > TimelineTime.zero;
  }
}
