import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/master_clock_native_bridge.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  TimelineClockCoordinator newClock({
    int durationMs = 10000,
    int initialMs = 0,
  }) {
    return TimelineClockCoordinator(
      timelineDuration: ms(durationMs),
      initialTime: ms(initialMs),
    );
  }

  group('MasterClockNativeBridge', () {
    test('syncs duration and starts playback from requested time', () {
      final clock = newClock(durationMs: 5000, initialMs: 1000);
      final bridge = MasterClockNativeBridge(clock: clock);

      bridge.requestPlaybackStart(
        startTime: ms(4500),
        timelineDurationTime: ms(7000),
      );

      expect(clock.phase, TimelineClockPhase.playStarting);
      expect(clock.time.inMilliseconds, 4500);
      expect(clock.snapshot.timelineDuration.inMilliseconds, 7000);
    });

    test('applies native sample and auto-arms play phase when needed', () {
      final clock = newClock(durationMs: 12000, initialMs: 2300);
      final bridge = MasterClockNativeBridge(clock: clock);

      final decision = bridge.applyNativePlaybackSample(
        sampleTime: ms(2400),
        fallbackStartTime: ms(2300),
        timelineDurationTime: ms(12000),
      );

      expect(decision, TimelineClockSampleDecision.accepted);
      expect(clock.phase, TimelineClockPhase.playing);
      expect(clock.time.inMilliseconds, 2400);
    });

    test('keeps stale native sample rejection semantics from coordinator', () {
      final clock = newClock(durationMs: 12000, initialMs: 5000);
      final bridge = MasterClockNativeBridge(clock: clock);
      bridge.requestPlaybackStart(
        startTime: ms(5000),
        timelineDurationTime: ms(12000),
      );

      final stale = bridge.applyNativePlaybackSample(
        sampleTime: ms(2000),
        fallbackStartTime: ms(5000),
        timelineDurationTime: ms(12000),
      );

      expect(stale, TimelineClockSampleDecision.rejectedStale);
      expect(clock.phase, TimelineClockPhase.playStarting);
      expect(clock.time.inMilliseconds, 5000);
    });

    test('pause and seek calls preserve duration sync path', () {
      final clock = newClock(durationMs: 9000, initialMs: 1000);
      final bridge = MasterClockNativeBridge(clock: clock);

      bridge.pauseAt(time: ms(1300), timelineDurationTime: ms(9500));
      expect(clock.phase, TimelineClockPhase.paused);
      expect(clock.time.inMilliseconds, 1300);
      expect(clock.snapshot.timelineDuration.inMilliseconds, 9500);

      bridge.seekTo(time: ms(5000), timelineDurationTime: ms(9500));
      expect(clock.phase, TimelineClockPhase.seeking);
      expect(clock.time.inMilliseconds, 5000);
      expect(
        bridge.confirmSeek(time: ms(5000), timelineDurationTime: ms(9500)),
        isTrue,
      );
      expect(clock.phase, TimelineClockPhase.paused);
    });

    test('scrub lifecycle routes through clock with duration sync', () {
      final clock = newClock(durationMs: 9000, initialMs: 1000);
      final bridge = MasterClockNativeBridge(clock: clock);

      bridge.scrubStart(
        anchorTime: ms(1500),
        timelineDurationTime: ms(9200),
      );
      expect(clock.phase, TimelineClockPhase.scrubbing);
      expect(clock.time.inMilliseconds, 1500);
      expect(clock.snapshot.timelineDuration.inMilliseconds, 9200);

      expect(
        bridge.scrubUpdate(
          targetTime: ms(1700),
          timelineDurationTime: ms(9200),
        ),
        isTrue,
      );
      expect(clock.time.inMilliseconds, 1700);

      expect(
        bridge.scrubEnd(
          finalTime: ms(1800),
          timelineDurationTime: ms(9200),
        ),
        isTrue,
      );
      expect(clock.phase, TimelineClockPhase.scrubSettling);

      expect(
        bridge.confirmScrubSettled(
          settledTime: ms(1800),
          timelineDurationTime: ms(9200),
        ),
        isTrue,
      );
      expect(clock.phase, TimelineClockPhase.paused);
      expect(clock.time.inMilliseconds, 1800);
    });

    test('separates requested scrub target from rendered master frame', () {
      final clock = newClock(durationMs: 9000, initialMs: 1000);
      final bridge = MasterClockNativeBridge(clock: clock);

      bridge.scrubStart(
        anchorTime: ms(1000),
        timelineDurationTime: ms(9000),
      );

      expect(
        bridge.scrubRequest(
          targetTime: ms(3600),
          timelineDurationTime: ms(9000),
        ),
        isTrue,
      );
      expect(clock.time.inMilliseconds, 1000);
      expect(clock.snapshot.presentationTime.inMilliseconds, 1000);
      expect(clock.snapshot.scrubTargetTime!.inMilliseconds, 3600);

      expect(
        bridge.scrubPresentedFrame(
          presentedTime: ms(1400),
          timelineDurationTime: ms(9000),
        ),
        isTrue,
      );
      expect(clock.time.inMilliseconds, 1400);
      expect(clock.snapshot.presentationTime.inMilliseconds, 1400);
      expect(clock.snapshot.scrubTargetTime!.inMilliseconds, 3600);

      expect(
        bridge.commitPresentedScrubFrame(
          presentedTime: ms(1400),
          timelineDurationTime: ms(9000),
        ),
        isTrue,
      );
      expect(clock.phase, TimelineClockPhase.scrubSettling);
      expect(clock.snapshot.scrubTargetTime!.inMilliseconds, 1400);
    });
  });
}
