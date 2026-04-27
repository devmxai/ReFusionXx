import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'transition_unified_scope_bridge_entry_adapter.dart';

class TransitionUnifiedScopeTimelineViewModel {
  TransitionUnifiedScopeTimelineViewModel({
    required this.sessionId,
    required this.transitionWindowId,
    required this.durationTime,
    required this.timeDisplayOffset,
    required this.seamLocalTime,
    required List<TimelineTrackData> tracks,
    required List<TimelineAnimationLaneData> lanes,
  })  : tracks = List.unmodifiable(tracks),
        lanes = List.unmodifiable(lanes);

  final String sessionId;
  final String transitionWindowId;
  final TimelineTime durationTime;
  final TimelineTime timeDisplayOffset;
  final TimelineTime seamLocalTime;
  final List<TimelineTrackData> tracks;
  final List<TimelineAnimationLaneData> lanes;

  bool get canShowTimeline => durationTime > TimelineTime.zero;
  bool get hasEditableLanes => lanes.isNotEmpty;
}

class TransitionUnifiedScopeTimelineSessionAdapter {
  const TransitionUnifiedScopeTimelineSessionAdapter();

  TransitionUnifiedScopeTimelineViewModel viewModelForSession(
    TransitionUnifiedScopeBridgeSession session,
  ) {
    final duration = session.localWorkRange.duration;
    final seamLocal = _seamLocalTime(session, duration);
    final leftDuration = _leftDuration(
      duration: duration,
      seamLocal: seamLocal,
    );
    final rightDuration = (duration - leftDuration).clamp(
      TimelineTime.zero,
      duration,
    );
    final outgoingClip = _scopedClip(
      clip: session.leftClip,
      id: '${session.transitionWindowId}.outgoing.clip',
      labelFallback: 'Clip A',
      duration: leftDuration,
      sourceStart: _outgoingSourceStart(
        clip: session.leftClip,
        visibleDuration: leftDuration,
      ),
    );
    final incomingClip = _scopedClip(
      clip: session.rightClip,
      id: '${session.transitionWindowId}.incoming.clip',
      labelFallback: 'Clip B',
      duration: rightDuration,
      sourceStart: session.rightClip.sourceStartTime,
    );
    final targetClipId = outgoingClip.id;
    final lanes = session.lanes
        .map(
          (lane) => lane.copyWith(
            targetClipId: targetClipId,
            trackSpanStartProgress: 0,
            trackSpanEndProgress: 1,
          ),
        )
        .toList(growable: false);

    return TransitionUnifiedScopeTimelineViewModel(
      sessionId: session.id,
      transitionWindowId: session.transitionWindowId,
      durationTime: duration,
      timeDisplayOffset: session.globalWorkRange.start,
      seamLocalTime: seamLocal,
      tracks: <TimelineTrackData>[
        TimelineTrackData(
          kind: TimelineTrackKind.video,
          clips: <TimelineClipData>[
            outgoingClip,
            incomingClip,
          ],
          animationLanes: lanes,
        ),
      ],
      lanes: lanes,
    );
  }

  TimelineTime _seamLocalTime(
    TransitionUnifiedScopeBridgeSession session,
    TimelineTime duration,
  ) {
    final seam = session.globalToLocal(session.boundaryTime).clamp(
          TimelineTime.zero,
          duration,
        );
    if (seam > TimelineTime.zero && seam < duration) {
      return seam;
    }
    return TimelineTime.fromMilliseconds(duration.inMilliseconds ~/ 2);
  }

  TimelineTime _leftDuration({
    required TimelineTime duration,
    required TimelineTime seamLocal,
  }) {
    if (duration <= TimelineTime.zero) {
      return TimelineTime.zero;
    }
    final clamped = seamLocal.clamp(TimelineTime.zero, duration);
    if (clamped <= TimelineTime.zero || clamped >= duration) {
      return TimelineTime.fromMilliseconds(duration.inMilliseconds ~/ 2);
    }
    return clamped;
  }

  TimelineClipData _scopedClip({
    required TimelineClipData clip,
    required String id,
    required String labelFallback,
    required TimelineTime duration,
    required TimelineTime sourceStart,
  }) {
    final sourceDuration = TimelineTime.fromMilliseconds(
      (duration.inMilliseconds * clip.playbackRate).round(),
    );
    return clip.copyWith(
      id: id,
      label: clip.label ?? labelFallback,
      durationTime: duration,
      sourceDurationTime: sourceDuration,
      sourceStartTime: sourceStart,
    );
  }

  TimelineTime _outgoingSourceStart({
    required TimelineClipData clip,
    required TimelineTime visibleDuration,
  }) {
    final visibleSourceDuration = TimelineTime.fromMilliseconds(
      (visibleDuration.inMilliseconds * clip.playbackRate).round(),
    );
    final latestStart = clip.sourceEndTime - visibleSourceDuration;
    if (latestStart <= clip.sourceStartTime) {
      return clip.sourceStartTime;
    }
    return latestStart;
  }
}
