import 'timeline_runtime_command.dart';
import 'timeline_runtime_state.dart';

enum TimelineRuntimeDiagnosticStatus {
  queued,
  started,
  completed,
  failed,
  transition,
}

class TimelineRuntimeDiagnosticEvent {
  const TimelineRuntimeDiagnosticEvent({
    required this.commandId,
    required this.kind,
    required this.status,
    required this.timestamp,
    required this.phaseBefore,
    required this.phaseAfter,
    this.targetPositionMs,
    this.timelineRevision,
    this.error,
  });

  final String commandId;
  final TimelineRuntimeCommandKind kind;
  final TimelineRuntimeDiagnosticStatus status;
  final DateTime timestamp;
  final TimelineRuntimePhase phaseBefore;
  final TimelineRuntimePhase phaseAfter;
  final int? targetPositionMs;
  final int? timelineRevision;
  final String? error;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'commandId': commandId,
      'kind': kind.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'phaseBefore': phaseBefore.name,
      'phaseAfter': phaseAfter.name,
      'targetPositionMs': targetPositionMs,
      'timelineRevision': timelineRevision,
      'error': error,
    };
  }
}

class TimelineRuntimeDiagnostics {
  TimelineRuntimeDiagnostics({this.maxEvents = 256});

  final int maxEvents;
  final List<TimelineRuntimeDiagnosticEvent> _events =
      <TimelineRuntimeDiagnosticEvent>[];

  List<TimelineRuntimeDiagnosticEvent> get events {
    return List<TimelineRuntimeDiagnosticEvent>.unmodifiable(_events);
  }

  TimelineRuntimeDiagnosticEvent record({
    required TimelineRuntimeCommand<dynamic> command,
    required TimelineRuntimeDiagnosticStatus status,
    required TimelineRuntimePhase phaseBefore,
    required TimelineRuntimePhase phaseAfter,
    String? error,
  }) {
    final event = TimelineRuntimeDiagnosticEvent(
      commandId: command.id,
      kind: command.kind,
      status: status,
      timestamp: DateTime.now().toUtc(),
      phaseBefore: phaseBefore,
      phaseAfter: phaseAfter,
      targetPositionMs: command.targetPositionMs,
      timelineRevision: command.timelineRevision,
      error: error,
    );
    _events.add(event);
    while (_events.length > maxEvents) {
      _events.removeAt(0);
    }
    return event;
  }

  void clear() {
    _events.clear();
  }
}
