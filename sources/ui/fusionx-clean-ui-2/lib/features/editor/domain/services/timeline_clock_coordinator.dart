import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';

enum TimelineClockPhase {
  idle,
  paused,
  scrubbing,
  scrubSettling,
  playStarting,
  playing,
  pausing,
  seeking,
  zooming,
  structuralEditing,
}

enum TimelineClockAuthority {
  none,
  user,
  nativeTransport,
  geometry,
  structuralEdit,
}

enum TimelineClockSampleDecision {
  accepted,
  rejectedStale,
  ignoredForPhase,
}

const Object _clockUnset = Object();

@immutable
class TimelineClockSnapshot {
  const TimelineClockSnapshot({
    required this.time,
    required this.evaluationTime,
    required this.timelineDuration,
    required this.phase,
    required this.authority,
    required this.revision,
    this.requestedPlaybackStartTime,
    this.scrubTargetTime,
    this.seekTargetTime,
    this.zoomAnchorTime,
    this.phaseBeforeZoom,
  });

  factory TimelineClockSnapshot.initial({
    required TimelineTime initialTime,
    required TimelineTime timelineDuration,
  }) {
    final safeDuration = _sanitizeDuration(timelineDuration);
    final clampedTime = _clampToDuration(initialTime, safeDuration);
    return TimelineClockSnapshot(
      time: clampedTime,
      evaluationTime: clampedTime,
      timelineDuration: safeDuration,
      phase: TimelineClockPhase.paused,
      authority: TimelineClockAuthority.none,
      revision: 0,
    );
  }

  final TimelineTime time;
  final TimelineTime evaluationTime;
  final TimelineTime timelineDuration;
  final TimelineClockPhase phase;
  final TimelineClockAuthority authority;
  final int revision;
  final TimelineTime? requestedPlaybackStartTime;
  final TimelineTime? scrubTargetTime;
  final TimelineTime? seekTargetTime;
  final TimelineTime? zoomAnchorTime;
  final TimelineClockPhase? phaseBeforeZoom;

  bool get isPlaybackActive =>
      phase == TimelineClockPhase.playStarting ||
      phase == TimelineClockPhase.playing;

  bool get isUserScrubbing => phase == TimelineClockPhase.scrubbing;

  bool get isZoomLocked => phase == TimelineClockPhase.zooming;

  TimelineClockSnapshot copyWith({
    TimelineTime? time,
    TimelineTime? evaluationTime,
    TimelineTime? timelineDuration,
    TimelineClockPhase? phase,
    TimelineClockAuthority? authority,
    int? revision,
    Object? requestedPlaybackStartTime = _clockUnset,
    Object? scrubTargetTime = _clockUnset,
    Object? seekTargetTime = _clockUnset,
    Object? zoomAnchorTime = _clockUnset,
    Object? phaseBeforeZoom = _clockUnset,
  }) {
    return TimelineClockSnapshot(
      time: time ?? this.time,
      evaluationTime: evaluationTime ?? this.evaluationTime,
      timelineDuration: timelineDuration ?? this.timelineDuration,
      phase: phase ?? this.phase,
      authority: authority ?? this.authority,
      revision: revision ?? this.revision,
      requestedPlaybackStartTime:
          identical(requestedPlaybackStartTime, _clockUnset)
              ? this.requestedPlaybackStartTime
              : requestedPlaybackStartTime as TimelineTime?,
      scrubTargetTime: identical(scrubTargetTime, _clockUnset)
          ? this.scrubTargetTime
          : scrubTargetTime as TimelineTime?,
      seekTargetTime: identical(seekTargetTime, _clockUnset)
          ? this.seekTargetTime
          : seekTargetTime as TimelineTime?,
      zoomAnchorTime: identical(zoomAnchorTime, _clockUnset)
          ? this.zoomAnchorTime
          : zoomAnchorTime as TimelineTime?,
      phaseBeforeZoom: identical(phaseBeforeZoom, _clockUnset)
          ? this.phaseBeforeZoom
          : phaseBeforeZoom as TimelineClockPhase?,
    );
  }

  TimelineTime projectToLocal(
    TimelineTime scopeStart, {
    TimelineTime? scopeDuration,
  }) {
    final localTime = evaluationTime - scopeStart;
    final upper = scopeDuration ?? timelineDuration;
    return localTime.clamp(TimelineTime.zero, _sanitizeDuration(upper));
  }

  double progressForWindow({
    required TimelineTime start,
    required TimelineTime duration,
  }) {
    final durationSeconds = duration.inSecondsDouble;
    if (durationSeconds <= 0) {
      return 0;
    }
    final progress = (evaluationTime - start).inSecondsDouble / durationSeconds;
    return progress.clamp(0.0, 1.0).toDouble();
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TimelineClockSnapshot &&
            other.time == time &&
            other.evaluationTime == evaluationTime &&
            other.timelineDuration == timelineDuration &&
            other.phase == phase &&
            other.authority == authority &&
            other.revision == revision &&
            other.requestedPlaybackStartTime == requestedPlaybackStartTime &&
            other.scrubTargetTime == scrubTargetTime &&
            other.seekTargetTime == seekTargetTime &&
            other.zoomAnchorTime == zoomAnchorTime &&
            other.phaseBeforeZoom == phaseBeforeZoom;
  }

  @override
  int get hashCode => Object.hash(
        time,
        evaluationTime,
        timelineDuration,
        phase,
        authority,
        revision,
        requestedPlaybackStartTime,
        scrubTargetTime,
        seekTargetTime,
        zoomAnchorTime,
        phaseBeforeZoom,
      );
}

class TimelineClockCoordinator extends ChangeNotifier {
  TimelineClockCoordinator({
    required TimelineTime timelineDuration,
    TimelineTime initialTime = TimelineTime.zero,
    TimelineTime? playStartSampleTolerance,
  })  : _snapshot = TimelineClockSnapshot.initial(
          initialTime: initialTime,
          timelineDuration: timelineDuration,
        ),
        _playStartSampleTolerance =
            playStartSampleTolerance ?? TimelineTime.fromMilliseconds(2000);

  TimelineClockSnapshot _snapshot;
  final TimelineTime _playStartSampleTolerance;

  TimelineClockSnapshot get snapshot => _snapshot;

  TimelineTime get time => _snapshot.time;

  TimelineTime get evaluationTime => _snapshot.evaluationTime;

  TimelineClockPhase get phase => _snapshot.phase;

  TimelineClockAuthority get authority => _snapshot.authority;

  void setTimelineDuration(TimelineTime duration) {
    final safeDuration = _sanitizeDuration(duration);
    final clampedTime = _clampToDuration(_snapshot.time, safeDuration);
    TimelineTime? clampOptional(TimelineTime? time) {
      if (time == null) {
        return null;
      }
      return _clampToDuration(time, safeDuration);
    }

    _commit(
      _snapshot.copyWith(
        time: clampedTime,
        evaluationTime: clampedTime,
        timelineDuration: safeDuration,
        requestedPlaybackStartTime:
            clampOptional(_snapshot.requestedPlaybackStartTime),
        scrubTargetTime: clampOptional(_snapshot.scrubTargetTime),
        seekTargetTime: clampOptional(_snapshot.seekTargetTime),
        zoomAnchorTime: clampOptional(_snapshot.zoomAnchorTime),
      ),
    );
  }

  void scrubStart(TimelineTime anchorTime) {
    final clamped = _clamp(anchorTime);
    _commit(
      _snapshot.copyWith(
        time: clamped,
        evaluationTime: clamped,
        phase: TimelineClockPhase.scrubbing,
        authority: TimelineClockAuthority.user,
        requestedPlaybackStartTime: null,
        scrubTargetTime: clamped,
        seekTargetTime: null,
        zoomAnchorTime: null,
        phaseBeforeZoom: null,
      ),
    );
  }

  bool scrubUpdate(TimelineTime targetTime) {
    if (_snapshot.phase != TimelineClockPhase.scrubbing) {
      return false;
    }
    final clamped = _clamp(targetTime);
    _commit(
      _snapshot.copyWith(
        time: clamped,
        evaluationTime: clamped,
        authority: TimelineClockAuthority.user,
        scrubTargetTime: clamped,
      ),
    );
    return true;
  }

  bool scrubEnd(TimelineTime finalTime) {
    if (_snapshot.phase != TimelineClockPhase.scrubbing) {
      return false;
    }
    final clamped = _clamp(finalTime);
    _commit(
      _snapshot.copyWith(
        time: clamped,
        evaluationTime: clamped,
        phase: TimelineClockPhase.scrubSettling,
        authority: TimelineClockAuthority.user,
        scrubTargetTime: clamped,
      ),
    );
    return true;
  }

  bool confirmScrubSettled(TimelineTime settledTime) {
    if (_snapshot.phase != TimelineClockPhase.scrubSettling) {
      return false;
    }
    final clamped = _clamp(settledTime);
    _commitPausedAt(clamped, authority: TimelineClockAuthority.nativeTransport);
    return true;
  }

  void playFrom(TimelineTime startTime) {
    final clamped = _clamp(startTime);
    _commit(
      _snapshot.copyWith(
        time: clamped,
        evaluationTime: clamped,
        phase: TimelineClockPhase.playStarting,
        authority: TimelineClockAuthority.nativeTransport,
        requestedPlaybackStartTime: clamped,
        scrubTargetTime: null,
        seekTargetTime: null,
        zoomAnchorTime: null,
        phaseBeforeZoom: null,
      ),
    );
  }

  TimelineClockSampleDecision applyNativeSample(TimelineTime sampleTime) {
    final clamped = _clamp(sampleTime);
    switch (_snapshot.phase) {
      case TimelineClockPhase.playStarting:
        final requested =
            _snapshot.requestedPlaybackStartTime ?? _snapshot.time;
        if (clamped < requested) {
          return TimelineClockSampleDecision.rejectedStale;
        }
        final lead = (clamped - requested).inSecondsDouble;
        if (lead > _playStartSampleTolerance.inSecondsDouble) {
          return TimelineClockSampleDecision.rejectedStale;
        }
        _commitPlayingAt(clamped);
        return TimelineClockSampleDecision.accepted;
      case TimelineClockPhase.playing:
        if (clamped < _snapshot.time) {
          return TimelineClockSampleDecision.rejectedStale;
        }
        _commitPlayingAt(clamped);
        return TimelineClockSampleDecision.accepted;
      case TimelineClockPhase.seeking:
        _commitPausedAt(clamped,
            authority: TimelineClockAuthority.nativeTransport);
        return TimelineClockSampleDecision.accepted;
      case TimelineClockPhase.idle:
      case TimelineClockPhase.paused:
      case TimelineClockPhase.scrubbing:
      case TimelineClockPhase.scrubSettling:
      case TimelineClockPhase.pausing:
      case TimelineClockPhase.zooming:
      case TimelineClockPhase.structuralEditing:
        return TimelineClockSampleDecision.ignoredForPhase;
    }
  }

  void pauseAt(TimelineTime time) {
    final clamped = _clamp(time);
    _commitPausedAt(clamped, authority: TimelineClockAuthority.nativeTransport);
  }

  void seekTo(TimelineTime targetTime) {
    final clamped = _clamp(targetTime);
    _commit(
      _snapshot.copyWith(
        time: clamped,
        evaluationTime: clamped,
        phase: TimelineClockPhase.seeking,
        authority: TimelineClockAuthority.nativeTransport,
        requestedPlaybackStartTime: null,
        scrubTargetTime: null,
        seekTargetTime: clamped,
        zoomAnchorTime: null,
        phaseBeforeZoom: null,
      ),
    );
  }

  bool confirmSeek(TimelineTime actualTime) {
    if (_snapshot.phase != TimelineClockPhase.seeking) {
      return false;
    }
    final clamped = _clamp(actualTime);
    _commitPausedAt(clamped, authority: TimelineClockAuthority.nativeTransport);
    return true;
  }

  void zoomStart(TimelineTime anchorTime) {
    final clamped = _clamp(anchorTime);
    final previousPhase = _snapshot.phase == TimelineClockPhase.zooming
        ? _snapshot.phaseBeforeZoom
        : _snapshot.phase;
    _commit(
      _snapshot.copyWith(
        time: clamped,
        evaluationTime: clamped,
        phase: TimelineClockPhase.zooming,
        authority: TimelineClockAuthority.geometry,
        zoomAnchorTime: clamped,
        phaseBeforeZoom: previousPhase,
      ),
    );
  }

  bool zoomUpdate(TimelineTime anchorTime) {
    if (_snapshot.phase != TimelineClockPhase.zooming) {
      return false;
    }
    final locked = _snapshot.zoomAnchorTime ?? _clamp(anchorTime);
    _commit(
      _snapshot.copyWith(
        time: locked,
        evaluationTime: locked,
        authority: TimelineClockAuthority.geometry,
      ),
    );
    return true;
  }

  bool zoomEnd(TimelineTime anchorTime) {
    if (_snapshot.phase != TimelineClockPhase.zooming) {
      return false;
    }
    final locked = _snapshot.zoomAnchorTime ?? _clamp(anchorTime);
    final nextPhase = _snapshot.phaseBeforeZoom == TimelineClockPhase.playing ||
            _snapshot.phaseBeforeZoom == TimelineClockPhase.playStarting
        ? TimelineClockPhase.paused
        : (_snapshot.phaseBeforeZoom ?? TimelineClockPhase.paused);
    _commit(
      _snapshot.copyWith(
        time: locked,
        evaluationTime: locked,
        phase: nextPhase,
        authority: TimelineClockAuthority.geometry,
        zoomAnchorTime: null,
        phaseBeforeZoom: null,
      ),
    );
    return true;
  }

  void applyStructuralEdit(TimelineTime resultingTime) {
    final clamped = _clamp(resultingTime);
    _commit(
      _snapshot.copyWith(
        time: clamped,
        evaluationTime: clamped,
        phase: TimelineClockPhase.structuralEditing,
        authority: TimelineClockAuthority.structuralEdit,
        requestedPlaybackStartTime: null,
        scrubTargetTime: null,
        seekTargetTime: null,
        zoomAnchorTime: null,
        phaseBeforeZoom: null,
      ),
    );
  }

  void completeStructuralEdit(TimelineTime resultingTime) {
    final clamped = _clamp(resultingTime);
    _commitPausedAt(clamped, authority: TimelineClockAuthority.structuralEdit);
  }

  TimelineTime projectToLocal(
    TimelineTime scopeStart, {
    TimelineTime? scopeDuration,
  }) {
    return _snapshot.projectToLocal(
      scopeStart,
      scopeDuration: scopeDuration,
    );
  }

  double progressForWindow({
    required TimelineTime start,
    required TimelineTime duration,
  }) {
    return _snapshot.progressForWindow(start: start, duration: duration);
  }

  TimelineTime _clamp(TimelineTime time) {
    return _clampToDuration(time, _snapshot.timelineDuration);
  }

  void _commitPlayingAt(TimelineTime time) {
    _commit(
      _snapshot.copyWith(
        time: time,
        evaluationTime: time,
        phase: TimelineClockPhase.playing,
        authority: TimelineClockAuthority.nativeTransport,
        requestedPlaybackStartTime: null,
        scrubTargetTime: null,
        seekTargetTime: null,
        zoomAnchorTime: null,
        phaseBeforeZoom: null,
      ),
    );
  }

  void _commitPausedAt(
    TimelineTime time, {
    required TimelineClockAuthority authority,
  }) {
    _commit(
      _snapshot.copyWith(
        time: time,
        evaluationTime: time,
        phase: TimelineClockPhase.paused,
        authority: authority,
        requestedPlaybackStartTime: null,
        scrubTargetTime: null,
        seekTargetTime: null,
        zoomAnchorTime: null,
        phaseBeforeZoom: null,
      ),
    );
  }

  void _commit(TimelineClockSnapshot next) {
    final clampedTime = _clampToDuration(next.time, next.timelineDuration);
    final clampedEvaluationTime =
        _clampToDuration(next.evaluationTime, next.timelineDuration);
    final normalizedWithoutRevision = next.copyWith(
      time: clampedTime,
      evaluationTime: clampedEvaluationTime,
      revision: _snapshot.revision,
    );
    if (normalizedWithoutRevision == _snapshot) {
      return;
    }
    final normalized = normalizedWithoutRevision.copyWith(
      revision: _snapshot.revision + 1,
    );
    _snapshot = normalized;
    notifyListeners();
  }
}

TimelineTime _sanitizeDuration(TimelineTime duration) {
  if (duration < TimelineTime.zero) {
    return TimelineTime.zero;
  }
  return duration;
}

TimelineTime _clampToDuration(TimelineTime time, TimelineTime duration) {
  return time.clamp(TimelineTime.zero, _sanitizeDuration(duration));
}
