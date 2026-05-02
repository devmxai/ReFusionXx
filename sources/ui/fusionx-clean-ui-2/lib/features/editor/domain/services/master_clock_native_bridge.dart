import '../../presentation/models/timeline_time.dart';
import 'timeline_clock_coordinator.dart';

class MasterClockNativeBridge {
  MasterClockNativeBridge({
    required TimelineClockCoordinator clock,
  }) : _clock = clock;

  final TimelineClockCoordinator _clock;

  TimelineClockSnapshot get snapshot => _clock.snapshot;

  TimelineTime get time => _clock.time;

  void syncTimelineDuration(TimelineTime durationTime) {
    _clock.setTimelineDuration(durationTime);
  }

  void requestPlaybackStart({
    required TimelineTime startTime,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    _clock.playFrom(startTime);
  }

  void scrubStart({
    required TimelineTime anchorTime,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    _clock.scrubStart(anchorTime);
  }

  bool scrubUpdate({
    required TimelineTime targetTime,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    return _clock.scrubUpdate(targetTime);
  }

  bool scrubEnd({
    required TimelineTime finalTime,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    return _clock.scrubEnd(finalTime);
  }

  bool confirmScrubSettled({
    required TimelineTime settledTime,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    return _clock.confirmScrubSettled(settledTime);
  }

  TimelineClockSampleDecision applyNativePlaybackSample({
    required TimelineTime sampleTime,
    required TimelineTime fallbackStartTime,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    if (_clock.phase != TimelineClockPhase.playStarting &&
        _clock.phase != TimelineClockPhase.playing) {
      _clock.playFrom(fallbackStartTime);
    }
    return _clock.applyNativeSample(sampleTime);
  }

  void pauseAt({
    required TimelineTime time,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    _clock.pauseAt(time);
  }

  void seekTo({
    required TimelineTime time,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    _clock.seekTo(time);
  }

  bool confirmSeek({
    required TimelineTime time,
    required TimelineTime timelineDurationTime,
  }) {
    syncTimelineDuration(timelineDurationTime);
    return _clock.confirmSeek(time);
  }
}
