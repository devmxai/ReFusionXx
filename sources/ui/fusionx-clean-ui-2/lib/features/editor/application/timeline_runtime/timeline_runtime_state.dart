enum TimelineRuntimePhase {
  idle,
  structuralCommit,
  transportPreparing,
  scrubReadinessPending,
  scrubActive,
  scrubSettling,
  ready,
  playing,
  paused,
  error,
}

extension TimelineRuntimePhaseX on TimelineRuntimePhase {
  bool get blocksPlayback {
    return switch (this) {
      TimelineRuntimePhase.structuralCommit ||
      TimelineRuntimePhase.transportPreparing ||
      TimelineRuntimePhase.scrubReadinessPending ||
      TimelineRuntimePhase.scrubActive ||
      TimelineRuntimePhase.scrubSettling =>
        true,
      TimelineRuntimePhase.idle ||
      TimelineRuntimePhase.ready ||
      TimelineRuntimePhase.playing ||
      TimelineRuntimePhase.paused ||
      TimelineRuntimePhase.error =>
        false,
    };
  }

  bool get ownsScrub {
    return switch (this) {
      TimelineRuntimePhase.scrubActive ||
      TimelineRuntimePhase.scrubSettling ||
      TimelineRuntimePhase.scrubReadinessPending =>
        true,
      _ => false,
    };
  }
}

class TimelineRuntimeState {
  const TimelineRuntimeState({
    this.phase = TimelineRuntimePhase.idle,
    this.timelineRevision = 0,
    this.commandRevision = 0,
    this.currentPositionMs = 0,
    this.activeCommandId,
    this.lastCompletedCommandId,
    this.lastError,
  });

  final TimelineRuntimePhase phase;
  final int timelineRevision;
  final int commandRevision;
  final int currentPositionMs;
  final String? activeCommandId;
  final String? lastCompletedCommandId;
  final String? lastError;

  bool get canStartPlayback => !phase.blocksPlayback;

  bool get isScrubOwnedByRuntime => phase.ownsScrub;

  TimelineRuntimeState copyWith({
    TimelineRuntimePhase? phase,
    int? timelineRevision,
    int? commandRevision,
    int? currentPositionMs,
    Object? activeCommandId = _noChange,
    Object? lastCompletedCommandId = _noChange,
    Object? lastError = _noChange,
  }) {
    return TimelineRuntimeState(
      phase: phase ?? this.phase,
      timelineRevision: timelineRevision ?? this.timelineRevision,
      commandRevision: commandRevision ?? this.commandRevision,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      activeCommandId: identical(activeCommandId, _noChange)
          ? this.activeCommandId
          : activeCommandId as String?,
      lastCompletedCommandId: identical(lastCompletedCommandId, _noChange)
          ? this.lastCompletedCommandId
          : lastCompletedCommandId as String?,
      lastError: identical(lastError, _noChange)
          ? this.lastError
          : lastError as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TimelineRuntimeState &&
        other.phase == phase &&
        other.timelineRevision == timelineRevision &&
        other.commandRevision == commandRevision &&
        other.currentPositionMs == currentPositionMs &&
        other.activeCommandId == activeCommandId &&
        other.lastCompletedCommandId == lastCompletedCommandId &&
        other.lastError == lastError;
  }

  @override
  int get hashCode => Object.hash(
        phase,
        timelineRevision,
        commandRevision,
        currentPositionMs,
        activeCommandId,
        lastCompletedCommandId,
        lastError,
      );
}

const Object _noChange = Object();
