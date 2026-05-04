import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineClockCoordinator newClock({
    int durationMs = 10000,
    int initialMs = 0,
  }) {
    return TimelineClockCoordinator(
      timelineDuration: TimelineTime.fromMilliseconds(durationMs),
      initialTime: TimelineTime.fromMilliseconds(initialMs),
    );
  }

  group('TimelineClockCoordinator', () {
    test('starts paused and exposes one evaluation time', () {
      final clock = newClock(initialMs: 1200);

      expect(clock.phase, TimelineClockPhase.paused);
      expect(clock.time.inMilliseconds, 1200);
      expect(clock.evaluationTime, clock.time);
      expect(clock.snapshot.presentationTime, clock.time);
      expect(clock.authority, TimelineClockAuthority.none);
      expect(clock.snapshot.commitFrameNumber, 0);
      expect(clock.snapshot.monotonicTimeUs, 0);
    });

    test('scrub lifecycle settles to a paused authoritative frame', () {
      final clock = newClock();

      clock.scrubStart(TimelineTime.fromMilliseconds(1000));
      expect(clock.phase, TimelineClockPhase.scrubbing);
      expect(clock.authority, TimelineClockAuthority.user);

      expect(clock.scrubUpdate(TimelineTime.fromMilliseconds(2400)), isTrue);
      expect(clock.time.inMilliseconds, 2400);

      expect(clock.scrubEnd(TimelineTime.fromMilliseconds(2500)), isTrue);
      expect(clock.phase, TimelineClockPhase.scrubSettling);
      expect(clock.snapshot.scrubTargetTime!.inMilliseconds, 2500);

      expect(
        clock.confirmScrubSettled(TimelineTime.fromMilliseconds(2500)),
        isTrue,
      );
      expect(clock.phase, TimelineClockPhase.paused);
      expect(clock.time.inMilliseconds, 2500);
      expect(clock.snapshot.scrubTargetTime, isNull);
    });

    test('scrub requests do not move the presented master frame', () {
      final clock = newClock();

      clock.scrubStart(TimelineTime.fromMilliseconds(1000));

      expect(clock.scrubRequest(TimelineTime.fromMilliseconds(3600)), isTrue);
      expect(clock.time.inMilliseconds, 1000);
      expect(clock.evaluationTime.inMilliseconds, 1000);
      expect(clock.snapshot.presentationTime.inMilliseconds, 1000);
      expect(clock.snapshot.scrubTargetTime!.inMilliseconds, 3600);

      expect(clock.scrubUpdate(TimelineTime.fromMilliseconds(1400)), isTrue);
      expect(clock.time.inMilliseconds, 1400);
      expect(clock.evaluationTime.inMilliseconds, 1400);
      expect(clock.snapshot.presentationTime.inMilliseconds, 1400);
      expect(clock.snapshot.scrubTargetTime!.inMilliseconds, 3600);

      expect(clock.scrubEnd(TimelineTime.fromMilliseconds(1400)), isTrue);
      expect(clock.phase, TimelineClockPhase.scrubSettling);
      expect(clock.snapshot.scrubTargetTime!.inMilliseconds, 1400);
    });

    test('playFrom supersedes scrub settling and rejects stale samples', () {
      final clock = newClock();

      clock.scrubStart(TimelineTime.fromMilliseconds(6000));
      clock.scrubEnd(TimelineTime.fromMilliseconds(5200));
      expect(clock.phase, TimelineClockPhase.scrubSettling);

      clock.playFrom(TimelineTime.fromMilliseconds(5200));
      expect(clock.phase, TimelineClockPhase.playStarting);
      expect(clock.time.inMilliseconds, 5200);
      expect(clock.snapshot.scrubTargetTime, isNull);
      expect(clock.snapshot.requestedPlaybackStartTime!.inMilliseconds, 5200);

      final staleDecision =
          clock.applyNativeSample(TimelineTime.fromMilliseconds(4900));
      expect(staleDecision, TimelineClockSampleDecision.rejectedStale);
      expect(clock.phase, TimelineClockPhase.playStarting);
      expect(clock.time.inMilliseconds, 5200);

      final acceptedDecision =
          clock.applyNativeSample(TimelineTime.fromMilliseconds(5200));
      expect(acceptedDecision, TimelineClockSampleDecision.accepted);
      expect(clock.phase, TimelineClockPhase.playing);
      expect(clock.time.inMilliseconds, 5200);
      expect(clock.snapshot.requestedPlaybackStartTime, isNull);
    });

    test('native samples cannot steal time during scrub or scrub settling', () {
      final clock = newClock();

      clock.playFrom(TimelineTime.fromMilliseconds(1000));
      expect(
        clock.applyNativeSample(TimelineTime.fromMilliseconds(1200)),
        TimelineClockSampleDecision.accepted,
      );
      expect(clock.phase, TimelineClockPhase.playing);

      clock.scrubStart(TimelineTime.fromMilliseconds(3000));
      expect(clock.phase, TimelineClockPhase.scrubbing);
      expect(clock.time.inMilliseconds, 3000);

      expect(
        clock.applyNativeSample(TimelineTime.fromMilliseconds(7200)),
        TimelineClockSampleDecision.ignoredForPhase,
      );
      expect(clock.time.inMilliseconds, 3000);
      expect(clock.evaluationTime.inMilliseconds, 3000);

      expect(clock.scrubUpdate(TimelineTime.fromMilliseconds(3400)), isTrue);
      expect(clock.scrubEnd(TimelineTime.fromMilliseconds(3600)), isTrue);
      expect(clock.phase, TimelineClockPhase.scrubSettling);

      expect(
        clock.applyNativeSample(TimelineTime.fromMilliseconds(8200)),
        TimelineClockSampleDecision.ignoredForPhase,
      );
      expect(clock.time.inMilliseconds, 3600);
      expect(clock.evaluationTime.inMilliseconds, 3600);
    });

    test('scrub settle followed by play requests the exact settled frame', () {
      final clock = newClock();

      clock.scrubStart(TimelineTime.fromMilliseconds(9000));
      clock.scrubUpdate(TimelineTime.fromMilliseconds(4200));
      clock.scrubEnd(TimelineTime.fromMilliseconds(4100));
      expect(
        clock.confirmScrubSettled(TimelineTime.fromMilliseconds(4100)),
        isTrue,
      );

      clock.playFrom(clock.time);
      expect(clock.phase, TimelineClockPhase.playStarting);
      expect(clock.snapshot.requestedPlaybackStartTime!.inMilliseconds, 4100);

      expect(
        clock.applyNativeSample(TimelineTime.fromMilliseconds(0)),
        TimelineClockSampleDecision.rejectedStale,
      );
      expect(clock.time.inMilliseconds, 4100);

      expect(
        clock.applyNativeSample(TimelineTime.fromMilliseconds(4100)),
        TimelineClockSampleDecision.accepted,
      );
      expect(clock.phase, TimelineClockPhase.playing);
      expect(clock.time.inMilliseconds, 4100);
    });

    test('playStarting accepts delayed samples after requested start', () {
      final clock = newClock();

      clock.playFrom(TimelineTime.fromMilliseconds(5000));

      final delayedDecision =
          clock.applyNativeSample(TimelineTime.fromMilliseconds(6200));
      expect(delayedDecision, TimelineClockSampleDecision.accepted);
      expect(clock.phase, TimelineClockPhase.playing);
      expect(clock.time.inMilliseconds, 6200);
    });

    test('playStarting rejects clearly stale samples from old positions', () {
      final clock = newClock();

      clock.playFrom(TimelineTime.fromMilliseconds(5000));

      final staleAheadDecision =
          clock.applyNativeSample(TimelineTime.fromMilliseconds(9000));
      expect(staleAheadDecision, TimelineClockSampleDecision.rejectedStale);
      expect(clock.phase, TimelineClockPhase.playStarting);
      expect(clock.time.inMilliseconds, 5000);

      final acceptedDecision =
          clock.applyNativeSample(TimelineTime.fromMilliseconds(5033));
      expect(acceptedDecision, TimelineClockSampleDecision.accepted);
    });

    test('playing never moves backwards on stale native samples', () {
      final clock = newClock();

      clock.playFrom(TimelineTime.fromMilliseconds(1000));
      clock.applyNativeSample(TimelineTime.fromMilliseconds(1033));
      expect(clock.phase, TimelineClockPhase.playing);
      expect(clock.time.inMilliseconds, 1033);

      final staleDecision =
          clock.applyNativeSample(TimelineTime.fromMilliseconds(1010));
      expect(staleDecision, TimelineClockSampleDecision.rejectedStale);
      expect(clock.time.inMilliseconds, 1033);

      final acceptedDecision =
          clock.applyNativeSample(TimelineTime.fromMilliseconds(1066));
      expect(acceptedDecision, TimelineClockSampleDecision.accepted);
      expect(clock.time.inMilliseconds, 1066);
    });

    test('does not emit revisions when duration and time are unchanged', () {
      final clock = newClock(initialMs: 1000);
      final startingRevision = clock.snapshot.revision;
      final startingCommitFrameNumber = clock.snapshot.commitFrameNumber;

      clock.setTimelineDuration(TimelineTime.fromMilliseconds(10000));

      expect(clock.snapshot.revision, startingRevision);
      expect(clock.snapshot.commitFrameNumber, startingCommitFrameNumber);
      expect(clock.time.inMilliseconds, 1000);
    });

    test('phase transition policy rejects known invalid transition', () {
      final clock = newClock();
      expect(
        clock.isValidPhaseTransitionForTesting(
          TimelineClockPhase.playing,
          TimelineClockPhase.structuralEditing,
        ),
        isFalse,
      );
      expect(
        clock.isValidPhaseTransitionForTesting(
          TimelineClockPhase.playing,
          TimelineClockPhase.scrubbing,
        ),
        isTrue,
      );
    });

    test('authority policy rejects invalid authority for phase', () {
      final clock = newClock();
      expect(
        clock.isAuthorityAllowedForPhaseForTesting(
          TimelineClockAuthority.geometry,
          TimelineClockPhase.playing,
        ),
        isFalse,
      );
      expect(
        clock.isAuthorityAllowedForPhaseForTesting(
          TimelineClockAuthority.nativeTransport,
          TimelineClockPhase.playing,
        ),
        isTrue,
      );
    });

    test('zoom locks the exact frame and ignores native samples', () {
      final clock = newClock(initialMs: 3000);

      clock.zoomStart(TimelineTime.fromMilliseconds(3000));
      expect(clock.phase, TimelineClockPhase.zooming);
      expect(clock.time.inMilliseconds, 3000);

      expect(clock.zoomUpdate(TimelineTime.fromMilliseconds(4500)), isTrue);
      expect(clock.time.inMilliseconds, 3000);
      expect(clock.evaluationTime.inMilliseconds, 3000);

      final sampleDecision =
          clock.applyNativeSample(TimelineTime.fromMilliseconds(3500));
      expect(sampleDecision, TimelineClockSampleDecision.ignoredForPhase);
      expect(clock.time.inMilliseconds, 3000);

      expect(clock.zoomEnd(TimelineTime.fromMilliseconds(4500)), isTrue);
      expect(clock.phase, TimelineClockPhase.paused);
      expect(clock.time.inMilliseconds, 3000);
    });

    test('zoom end preserves the locked frame before playback starts', () {
      final clock = newClock(initialMs: 8000);

      clock.zoomStart(TimelineTime.fromMilliseconds(8000));
      clock.zoomUpdate(TimelineTime.fromMilliseconds(2000));
      clock.zoomEnd(TimelineTime.fromMilliseconds(2000));

      expect(clock.phase, TimelineClockPhase.paused);
      expect(clock.time.inMilliseconds, 8000);
      expect(clock.evaluationTime.inMilliseconds, 8000);

      clock.playFrom(clock.evaluationTime);
      expect(clock.snapshot.requestedPlaybackStartTime!.inMilliseconds, 8000);

      expect(
        clock.applyNativeSample(TimelineTime.fromMilliseconds(7900)),
        TimelineClockSampleDecision.rejectedStale,
      );
      expect(clock.time.inMilliseconds, 8000);
    });

    test('projects global time to scoped local time without a second clock',
        () {
      final clock = newClock(initialMs: 6200);

      final local = clock.projectToLocal(
        TimelineTime.fromMilliseconds(5000),
        scopeDuration: TimelineTime.fromMilliseconds(3000),
      );
      expect(local.inMilliseconds, 1200);

      final clampedLocal = clock.projectToLocal(
        TimelineTime.fromMilliseconds(5000),
        scopeDuration: TimelineTime.fromMilliseconds(1000),
      );
      expect(clampedLocal.inMilliseconds, 1000);
    });

    test('computes transition progress from the same evaluation time', () {
      final clock = newClock(initialMs: 5500);

      final progress = clock.progressForWindow(
        start: TimelineTime.fromMilliseconds(5000),
        duration: TimelineTime.fromMilliseconds(1000),
      );
      expect(progress, 0.5);
    });

    test('clamps all commands to timeline duration', () {
      final clock = newClock(durationMs: 3000);

      clock.playFrom(TimelineTime.fromMilliseconds(6000));
      expect(clock.time.inMilliseconds, 3000);
      expect(clock.snapshot.requestedPlaybackStartTime!.inMilliseconds, 3000);

      clock.pauseAt(TimelineTime.fromMilliseconds(-200));
      expect(clock.time.inMilliseconds, 0);
    });
  });
}
