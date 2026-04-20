import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/application/timeline_runtime/timeline_runtime.dart';

void main() {
  test('structural edit runs through prepare, scrub config, and readiness',
      () async {
    final log = <String>[];
    final runtime = _buildRuntime(log);
    const projection = StaticTimelineProjectionAdapter(
      timelineRevision: 7,
      segments: <Map<String, dynamic>>[
        <String, dynamic>{'clipId': 'clip-1', 'startMs': 0, 'endMs': 1000},
      ],
    );

    final state = await runtime.commitStructuralEdit(
      applyEdit: () async {
        log.add('apply-edit');
      },
      projection: projection,
      targetPositionMs: 240,
    );

    expect(
      log,
      <String>[
        'apply-edit',
        'pause',
        'prepare:240:1',
        'flush-scrub-config',
        'await-scrub-ready:240:1200',
      ],
    );
    expect(state.phase, TimelineRuntimePhase.ready);
    expect(state.currentPositionMs, 240);
    expect(state.timelineRevision, 7);
    expect(
        runtime.diagnostics.events.map((event) => event.status),
        containsAll(
          <TimelineRuntimeDiagnosticStatus>[
            TimelineRuntimeDiagnosticStatus.queued,
            TimelineRuntimeDiagnosticStatus.started,
            TimelineRuntimeDiagnosticStatus.completed,
          ],
        ));
  });

  test('playback waits behind a pending structural edit command', () async {
    final log = <String>[];
    final prepareGate = Completer<void>();
    final runtime = _buildRuntime(log, prepareGate: prepareGate);
    const projection = StaticTimelineProjectionAdapter(
      timelineRevision: 8,
      segments: <Map<String, dynamic>>[
        <String, dynamic>{'clipId': 'clip-1', 'startMs': 0, 'endMs': 1000},
      ],
    );

    final editFuture = runtime.commitStructuralEdit(
      applyEdit: () async {
        log.add('apply-edit');
      },
      projection: projection,
      targetPositionMs: 500,
    );
    await Future<void>.delayed(Duration.zero);

    final playFuture = runtime.requestPlayback();
    await Future<void>.delayed(Duration.zero);

    expect(log, contains('prepare:500:1'));
    expect(log, isNot(contains('play')));

    prepareGate.complete();
    await editFuture;
    await playFuture;

    expect(log.last, 'play');
    expect(
      log.indexOf('play') > log.indexOf('await-scrub-ready:500:1200'),
      isTrue,
    );
  });

  test('scrub handoff is represented as runtime ownership then settle',
      () async {
    final log = <String>[];
    final runtime = _buildRuntime(log);

    runtime.beginScrubAt(100);
    runtime.updateScrubPosition(350);

    expect(runtime.state.phase, TimelineRuntimePhase.scrubActive);
    expect(runtime.state.currentPositionMs, 350);

    final state = await runtime.endScrubAt(360);

    expect(log, <String>['settle-after-scrub:360']);
    expect(state.phase, TimelineRuntimePhase.ready);
    expect(state.currentPositionMs, 360);
  });
}

TimelineRuntimeController _buildRuntime(
  List<String> log, {
  Completer<void>? prepareGate,
}) {
  return TimelineRuntimeController(
    transport: _FakeTransportRuntimeAdapter(
      log,
      prepareGate: prepareGate,
    ),
    scrub: CallbackTimelineScrubRuntimeAdapter(
      onFlushConfig: () async {
        log.add('flush-scrub-config');
      },
      onAwaitReadiness: ({
        required int positionMs,
        required int timeoutMs,
      }) async {
        log.add('await-scrub-ready:$positionMs:$timeoutMs');
        return true;
      },
    ),
    preview: const CallbackTimelinePreviewRuntimeAdapter(),
  );
}

class _FakeTransportRuntimeAdapter implements TimelineTransportRuntimeAdapter {
  _FakeTransportRuntimeAdapter(
    this.log, {
    this.prepareGate,
  });

  final List<String> log;
  final Completer<void>? prepareGate;

  @override
  bool isPlaying = false;

  @override
  bool isScrubSettling = false;

  @override
  bool hasRenderedFirstFrame = true;

  @override
  bool isPreviewContentSized = true;

  @override
  Future<void> pause() async {
    isPlaying = false;
    log.add('pause');
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    log.add('play');
  }

  @override
  Future<Object?> prepareTimelineSegments({
    required List<Map<String, dynamic>> segments,
    required int startPositionMs,
  }) async {
    log.add('prepare:$startPositionMs:${segments.length}');
    await prepareGate?.future;
    return null;
  }

  @override
  Future<void> seekToPositionMs(int positionMs) async {
    log.add('seek:$positionMs');
  }

  @override
  Future<void> settleAfterScrubPositionMs(int positionMs) async {
    log.add('settle-after-scrub:$positionMs');
  }
}
