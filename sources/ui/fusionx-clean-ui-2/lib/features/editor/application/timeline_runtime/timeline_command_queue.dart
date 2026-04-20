import 'dart:async';

import 'timeline_runtime_command.dart';

typedef TimelineCommandHook = void Function(
  TimelineRuntimeCommand<dynamic> command,
);

typedef TimelineCommandErrorHook = void Function(
  TimelineRuntimeCommand<dynamic> command,
  Object error,
  StackTrace stackTrace,
);

class TimelineCommandQueue {
  TimelineCommandQueue({
    this.onQueued,
    this.onStarted,
    this.onCompleted,
    this.onFailed,
  });

  final TimelineCommandHook? onQueued;
  final TimelineCommandHook? onStarted;
  final TimelineCommandHook? onCompleted;
  final TimelineCommandErrorHook? onFailed;

  Future<void> _tail = Future<void>.value();
  int _pendingCount = 0;

  bool get hasPendingCommands => _pendingCount > 0;

  Future<T> enqueue<T>(TimelineRuntimeCommand<T> command) {
    onQueued?.call(command);
    _pendingCount += 1;
    final completer = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      onStarted?.call(command);
      try {
        final result = await command.action();
        onCompleted?.call(command);
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (error, stackTrace) {
        onFailed?.call(command, error, stackTrace);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        _pendingCount -= 1;
      }
    });
    return completer.future;
  }
}
