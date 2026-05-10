import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

enum UnifiedKeyframeMotionTimelineIssueCode {
  focusTargetNotFound,
  noEditableLanesForTarget,
}

class UnifiedKeyframeMotionTimelineIssue {
  const UnifiedKeyframeMotionTimelineIssue({
    required this.code,
    required this.message,
    this.trackKind,
    this.clipId,
  });

  final UnifiedKeyframeMotionTimelineIssueCode code;
  final String message;
  final TimelineTrackKind? trackKind;
  final String? clipId;
}

class UnifiedKeyframeMotionTimelineRequest {
  const UnifiedKeyframeMotionTimelineRequest({
    required this.tracks,
    required this.focusedClipId,
    required this.globalTimelineTime,
  });

  final List<TimelineTrackData> tracks;
  final String focusedClipId;
  final TimelineTime globalTimelineTime;
}

class UnifiedKeyframeMotionTimelineProjection {
  UnifiedKeyframeMotionTimelineProjection({
    required this.focusedTrack,
    required this.focusedClipId,
    required this.localTimelineTime,
    required this.timeDisplayOffset,
    required this.durationTime,
    required List<UnifiedKeyframeMotionTimelineIssue> issues,
  }) : issues = List<UnifiedKeyframeMotionTimelineIssue>.unmodifiable(issues);

  final TimelineTrackData? focusedTrack;
  final String focusedClipId;
  final TimelineTime localTimelineTime;
  final TimelineTime timeDisplayOffset;
  final TimelineTime durationTime;
  final List<UnifiedKeyframeMotionTimelineIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class UnifiedKeyframeMotionTimelineAdapter {
  const UnifiedKeyframeMotionTimelineAdapter();

  UnifiedKeyframeMotionTimelineProjection project(
    UnifiedKeyframeMotionTimelineRequest request,
  ) {
    TimelineTrackData? ownerTrack;
    TimelineClipData? ownerClip;
    TimelineTime ownerClipStart = TimelineTime.zero;

    for (final track in request.tracks) {
      var cursor = TimelineTime.zero;
      for (final clip in track.clips) {
        if (clip.id == request.focusedClipId) {
          ownerTrack = track;
          ownerClip = clip;
          ownerClipStart = cursor;
          break;
        }
        cursor += clip.durationTime;
      }
      if (ownerTrack != null) {
        break;
      }
    }

    if (ownerTrack == null || ownerClip == null) {
      return UnifiedKeyframeMotionTimelineProjection(
        focusedTrack: null,
        focusedClipId: request.focusedClipId,
        localTimelineTime: TimelineTime.zero,
        timeDisplayOffset: TimelineTime.zero,
        durationTime: TimelineTime.zero,
        issues: <UnifiedKeyframeMotionTimelineIssue>[
          UnifiedKeyframeMotionTimelineIssue(
            code: UnifiedKeyframeMotionTimelineIssueCode.focusTargetNotFound,
            message:
                'Focused clip `${request.focusedClipId}` was not found in timeline tracks.',
            clipId: request.focusedClipId,
          ),
        ],
      );
    }

    final editableLanes = ownerTrack.animationLanes
        .where((lane) => lane.targetClipId == ownerClip!.id)
        .toList(growable: false);
    final issues = <UnifiedKeyframeMotionTimelineIssue>[];
    if (editableLanes.isEmpty) {
      issues.add(
        UnifiedKeyframeMotionTimelineIssue(
          code: UnifiedKeyframeMotionTimelineIssueCode.noEditableLanesForTarget,
          message:
              'Focused clip `${ownerClip.id}` has no editable keyframe lanes.',
          trackKind: ownerTrack.kind,
          clipId: ownerClip.id,
        ),
      );
    }

    final focusedTrack = ownerTrack.copyWith(
      clips: <TimelineClipData>[ownerClip],
      animationLanes: editableLanes,
      transitions: const <TimelineTrackTransitionData>[],
    );
    final localTimelineTime = (request.globalTimelineTime - ownerClipStart)
        .clamp(TimelineTime.zero, ownerClip.durationTime);

    return UnifiedKeyframeMotionTimelineProjection(
      focusedTrack: focusedTrack,
      focusedClipId: ownerClip.id,
      localTimelineTime: localTimelineTime,
      timeDisplayOffset: ownerClipStart,
      durationTime: ownerClip.durationTime,
      issues: issues,
    );
  }
}
