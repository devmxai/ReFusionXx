import 'package:flutter/foundation.dart';

import 'timeline_command_queue.dart';
import 'timeline_runtime_adapters.dart';
import 'timeline_runtime_command.dart';
import 'timeline_runtime_diagnostics.dart';
import 'timeline_runtime_state.dart';

typedef TimelineStructuralEditAction = Future<void> Function();

class TimelineRuntimeController extends ChangeNotifier {
  TimelineRuntimeController({
    required TimelineTransportRuntimeAdapter transport,
    required TimelineScrubRuntimeAdapter scrub,
    required TimelinePreviewRuntimeAdapter preview,
    TimelineRuntimeDiagnostics? diagnostics,
  })  : _transport = transport,
        _scrub = scrub,
        _preview = preview,
        diagnostics = diagnostics ?? TimelineRuntimeDiagnostics() {
    _queue = TimelineCommandQueue(
      onQueued: _recordQueued,
      onStarted: _recordStarted,
      onCompleted: _recordCompleted,
      onFailed: _recordFailed,
    );
  }

  final TimelineTransportRuntimeAdapter _transport;
  final TimelineScrubRuntimeAdapter _scrub;
  final TimelinePreviewRuntimeAdapter _preview;
  final TimelineRuntimeDiagnostics diagnostics;
  late final TimelineCommandQueue _queue;

  TimelineRuntimeState _state = const TimelineRuntimeState();
  int _nextCommandNumber = 0;

  TimelineRuntimeState get state => _state;

  bool get hasPendingCommands => _queue.hasPendingCommands;

  Future<TimelineRuntimeState> prepareProjection({
    required TimelineProjectionAdapter projection,
    int startPositionMs = 0,
  }) {
    final targetPositionMs = _safePositionMs(startPositionMs);
    return _enqueue<TimelineRuntimeState>(
      kind: TimelineRuntimeCommandKind.prepareProjection,
      targetPositionMs: targetPositionMs,
      timelineRevision: projection.timelineRevision,
      action: () async {
        _transition(
          TimelineRuntimePhase.transportPreparing,
          targetPositionMs: targetPositionMs,
          timelineRevision: projection.timelineRevision,
        );
        await _transport.prepareTimelineSegments(
          segments: projection.buildTransportSegments(),
          startPositionMs: targetPositionMs,
        );
        _transition(
          TimelineRuntimePhase.ready,
          targetPositionMs: targetPositionMs,
          timelineRevision: projection.timelineRevision,
        );
        return _state;
      },
    );
  }

  Future<TimelineRuntimeState> commitStructuralEdit({
    required TimelineStructuralEditAction applyEdit,
    required TimelineProjectionAdapter projection,
    required int targetPositionMs,
    bool awaitScrubReadiness = true,
    int scrubReadinessTimeoutMs = 1200,
  }) {
    final safeTargetPositionMs = _safePositionMs(targetPositionMs);
    return _enqueue<TimelineRuntimeState>(
      kind: TimelineRuntimeCommandKind.commitStructuralEdit,
      targetPositionMs: safeTargetPositionMs,
      timelineRevision: projection.timelineRevision,
      action: () async {
        _transition(
          TimelineRuntimePhase.structuralCommit,
          targetPositionMs: safeTargetPositionMs,
          timelineRevision: projection.timelineRevision,
        );
        await applyEdit();
        _transition(
          TimelineRuntimePhase.transportPreparing,
          targetPositionMs: safeTargetPositionMs,
          timelineRevision: projection.timelineRevision,
        );
        await _transport.pause();
        await _transport.prepareTimelineSegments(
          segments: projection.buildTransportSegments(),
          startPositionMs: safeTargetPositionMs,
        );
        _transition(
          TimelineRuntimePhase.scrubReadinessPending,
          targetPositionMs: safeTargetPositionMs,
          timelineRevision: projection.timelineRevision,
        );
        await _scrub.flushConfig();
        if (awaitScrubReadiness) {
          await _scrub.awaitReadiness(
            positionMs: safeTargetPositionMs,
            timeoutMs: scrubReadinessTimeoutMs,
          );
        }
        _transition(
          TimelineRuntimePhase.ready,
          targetPositionMs: safeTargetPositionMs,
          timelineRevision: projection.timelineRevision,
        );
        return _state;
      },
    );
  }

  Future<TimelineRuntimeState> requestSeek(int positionMs) {
    final safePositionMs = _safePositionMs(positionMs);
    return _enqueue<TimelineRuntimeState>(
      kind: TimelineRuntimeCommandKind.requestSeek,
      targetPositionMs: safePositionMs,
      action: () async {
        _transition(
          TimelineRuntimePhase.transportPreparing,
          targetPositionMs: safePositionMs,
        );
        await _transport.seekToPositionMs(safePositionMs);
        _transition(
          TimelineRuntimePhase.ready,
          targetPositionMs: safePositionMs,
        );
        return _state;
      },
    );
  }

  Future<TimelineRuntimeState> requestPlayback() {
    return _enqueue<TimelineRuntimeState>(
      kind: TimelineRuntimeCommandKind.requestPlayback,
      targetPositionMs: _state.currentPositionMs,
      action: () async {
        if (_transport.isScrubSettling || !_preview.hasFreshPreview) {
          _transition(
            TimelineRuntimePhase.scrubSettling,
            targetPositionMs: _state.currentPositionMs,
          );
          await _preview.awaitFreshPreview(
            positionMs: _state.currentPositionMs,
            timeout: const Duration(milliseconds: 500),
          );
        }
        await _transport.play();
        _transition(
          TimelineRuntimePhase.playing,
          targetPositionMs: _state.currentPositionMs,
        );
        return _state;
      },
    );
  }

  Future<TimelineRuntimeState> pausePlayback() {
    return _enqueue<TimelineRuntimeState>(
      kind: TimelineRuntimeCommandKind.pausePlayback,
      targetPositionMs: _state.currentPositionMs,
      action: () async {
        await _transport.pause();
        _transition(
          TimelineRuntimePhase.paused,
          targetPositionMs: _state.currentPositionMs,
        );
        return _state;
      },
    );
  }

  void beginScrubAt(int positionMs) {
    _transition(
      TimelineRuntimePhase.scrubActive,
      targetPositionMs: _safePositionMs(positionMs),
    );
  }

  void updateScrubPosition(int positionMs) {
    if (_state.phase != TimelineRuntimePhase.scrubActive) {
      return;
    }
    _transition(
      TimelineRuntimePhase.scrubActive,
      targetPositionMs: _safePositionMs(positionMs),
    );
  }

  Future<TimelineRuntimeState> endScrubAt(int positionMs) {
    final safePositionMs = _safePositionMs(positionMs);
    return _enqueue<TimelineRuntimeState>(
      kind: TimelineRuntimeCommandKind.endScrub,
      targetPositionMs: safePositionMs,
      action: () async {
        _transition(
          TimelineRuntimePhase.scrubSettling,
          targetPositionMs: safePositionMs,
        );
        await _transport.settleAfterScrubPositionMs(safePositionMs);
        _transition(
          TimelineRuntimePhase.ready,
          targetPositionMs: safePositionMs,
        );
        return _state;
      },
    );
  }

  Future<T> _enqueue<T>({
    required TimelineRuntimeCommandKind kind,
    required Future<T> Function() action,
    int? targetPositionMs,
    int? timelineRevision,
  }) {
    final command = TimelineRuntimeCommand<T>(
      id: _createCommandId(kind),
      kind: kind,
      targetPositionMs: targetPositionMs,
      timelineRevision: timelineRevision,
      action: action,
    );
    return _queue.enqueue(command);
  }

  String _createCommandId(TimelineRuntimeCommandKind kind) {
    _nextCommandNumber += 1;
    return '${kind.name}-$_nextCommandNumber';
  }

  void _transition(
    TimelineRuntimePhase phase, {
    int? targetPositionMs,
    int? timelineRevision,
    Object? activeCommandId = _noChange,
    Object? lastCompletedCommandId = _noChange,
    Object? lastError = _noChange,
  }) {
    final nextState = _state.copyWith(
      phase: phase,
      commandRevision: _state.commandRevision + 1,
      timelineRevision: timelineRevision,
      currentPositionMs: targetPositionMs,
      activeCommandId: activeCommandId,
      lastCompletedCommandId: lastCompletedCommandId,
      lastError: lastError,
    );
    if (nextState == _state) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  void _recordQueued(TimelineRuntimeCommand<dynamic> command) {
    diagnostics.record(
      command: command,
      status: TimelineRuntimeDiagnosticStatus.queued,
      phaseBefore: _state.phase,
      phaseAfter: _state.phase,
    );
  }

  void _recordStarted(TimelineRuntimeCommand<dynamic> command) {
    diagnostics.record(
      command: command,
      status: TimelineRuntimeDiagnosticStatus.started,
      phaseBefore: _state.phase,
      phaseAfter: _state.phase,
    );
    _transition(
      _state.phase,
      activeCommandId: command.id,
      lastError: null,
    );
  }

  void _recordCompleted(TimelineRuntimeCommand<dynamic> command) {
    diagnostics.record(
      command: command,
      status: TimelineRuntimeDiagnosticStatus.completed,
      phaseBefore: _state.phase,
      phaseAfter: _state.phase,
    );
    _transition(
      _state.phase,
      activeCommandId: null,
      lastCompletedCommandId: command.id,
      lastError: null,
    );
  }

  void _recordFailed(
    TimelineRuntimeCommand<dynamic> command,
    Object error,
    StackTrace stackTrace,
  ) {
    diagnostics.record(
      command: command,
      status: TimelineRuntimeDiagnosticStatus.failed,
      phaseBefore: _state.phase,
      phaseAfter: TimelineRuntimePhase.error,
      error: error.toString(),
    );
    _transition(
      TimelineRuntimePhase.error,
      activeCommandId: null,
      lastError: error.toString(),
    );
  }

  int _safePositionMs(int positionMs) {
    return positionMs < 0 ? 0 : positionMs;
  }
}

const Object _noChange = Object();
