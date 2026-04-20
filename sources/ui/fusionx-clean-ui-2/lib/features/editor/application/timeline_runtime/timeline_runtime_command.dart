import 'dart:async';

enum TimelineRuntimeCommandKind {
  prepareProjection,
  commitStructuralEdit,
  requestSeek,
  requestPlayback,
  pausePlayback,
  beginScrub,
  updateScrub,
  endScrub,
  enterProjection,
  exitProjection,
  refreshScrubReadiness,
}

typedef TimelineRuntimeCommandAction<T> = FutureOr<T> Function();

class TimelineRuntimeCommand<T> {
  const TimelineRuntimeCommand({
    required this.id,
    required this.kind,
    required this.action,
    this.label,
    this.targetPositionMs,
    this.timelineRevision,
  });

  final String id;
  final TimelineRuntimeCommandKind kind;
  final String? label;
  final int? targetPositionMs;
  final int? timelineRevision;
  final TimelineRuntimeCommandAction<T> action;
}
