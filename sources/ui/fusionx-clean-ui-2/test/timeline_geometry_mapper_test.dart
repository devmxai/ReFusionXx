import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_geometry_mapper.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  group('TimelineGeometryMapper', () {
    test('maps playhead-centered offsets to timeline time', () {
      final geometry = TimelineGeometryMapper(
        timelineDuration: TimelineTime.fromSecondsDouble(20),
        secondsWidth: 40,
        timelineOriginX: 24,
        playheadLeft: 180,
        maxScrollOffset: 1000,
      );

      final offset = geometry.offsetForTime(
        TimelineTime.fromSecondsDouble(10),
      );

      expect(offset, 244);
      expect(geometry.timeForOffset(offset).inMilliseconds, 10000);
    });

    test('clamps offset and time to timeline boundaries', () {
      final geometry = TimelineGeometryMapper(
        timelineDuration: TimelineTime.fromSecondsDouble(5),
        secondsWidth: 80,
        timelineOriginX: 0,
        playheadLeft: 100,
        maxScrollOffset: 250,
      );

      expect(geometry.offsetForTime(TimelineTime.fromSecondsDouble(-1)), 0);
      expect(geometry.offsetForTime(TimelineTime.fromSecondsDouble(9)), 250);
      expect(geometry.timeForOffset(-500).inMilliseconds, 0);
      expect(geometry.timeForOffset(10000).inMilliseconds, 5000);
    });

    test('keeps a locked frame stable when zoom scale changes', () {
      final lockedTime = TimelineTime.fromSecondsDouble(6);
      const timelineOriginX = 16.0;
      const playheadLeft = 160.0;

      final wide = TimelineGeometryMapper(
        timelineDuration: TimelineTime.fromSecondsDouble(12),
        secondsWidth: 30,
        timelineOriginX: timelineOriginX,
        playheadLeft: playheadLeft,
        maxScrollOffset: 2000,
      );
      final close = TimelineGeometryMapper(
        timelineDuration: TimelineTime.fromSecondsDouble(12),
        secondsWidth: 180,
        timelineOriginX: timelineOriginX,
        playheadLeft: playheadLeft,
        maxScrollOffset: 2000,
      );

      expect(wide.timeForOffset(wide.offsetForTime(lockedTime)), lockedTime);
      expect(close.timeForOffset(close.offsetForTime(lockedTime)), lockedTime);
    });

    test('recomputes zoom offsets from the locked playhead frame', () {
      final lockedTime = TimelineTime.fromSecondsDouble(10);
      const timelineOriginX = 24.0;
      const playheadLeft = 180.0;

      final zoomedOut = TimelineGeometryMapper(
        timelineDuration: TimelineTime.fromSecondsDouble(30),
        secondsWidth: 24,
        timelineOriginX: timelineOriginX,
        playheadLeft: playheadLeft,
        maxScrollOffset: 4000,
      );
      final zoomedIn = TimelineGeometryMapper(
        timelineDuration: TimelineTime.fromSecondsDouble(30),
        secondsWidth: 240,
        timelineOriginX: timelineOriginX,
        playheadLeft: playheadLeft,
        maxScrollOffset: 4000,
      );

      final zoomedOutOffset = zoomedOut.offsetForTime(lockedTime);
      final zoomedInOffset = zoomedIn.offsetForTime(lockedTime);

      expect(zoomedOut.timeForOffset(zoomedOutOffset), lockedTime);
      expect(zoomedIn.timeForOffset(zoomedInOffset), lockedTime);
      expect(zoomedInOffset, greaterThan(zoomedOutOffset));
    });

    test('computes playback visual follow offset from a stable anchor', () {
      final geometry = TimelineGeometryMapper(
        timelineDuration: TimelineTime.fromSecondsDouble(30),
        secondsWidth: 50,
        timelineOriginX: 0,
        playheadLeft: 200,
        maxScrollOffset: 1200,
      );

      final nextOffset = geometry.offsetForTimeFromAnchor(
        anchorTime: TimelineTime.fromSecondsDouble(10),
        anchorOffset: 400,
        time: TimelineTime.fromSecondsDouble(12),
      );

      expect(nextOffset, 500);
      expect(
        geometry.offsetForTimeFromAnchor(
          anchorTime: TimelineTime.fromSecondsDouble(10),
          anchorOffset: 400,
          time: TimelineTime.fromSecondsDouble(60),
        ),
        1200,
      );
    });

    test('converts durations and drag pixels with one scale contract', () {
      final geometry = TimelineGeometryMapper(
        timelineDuration: TimelineTime.fromSecondsDouble(20),
        secondsWidth: 60,
        timelineOriginX: 0,
        playheadLeft: 0,
        maxScrollOffset: 1000,
      );

      expect(
        geometry.pixelsForDuration(TimelineTime.fromSecondsDouble(2.5)),
        150,
      );
      expect(geometry.durationForPixels(150).inMilliseconds, 2500);
      expect(geometry.durationForPixels(-30).inMilliseconds, -500);
    });
  });
}
