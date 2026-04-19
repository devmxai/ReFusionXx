import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/widgets/timeline_panel.dart';

void main() {
  testWidgets('native scrub regions exclude clip bodies but keep empty gaps',
      (WidgetTester tester) async {
    TimelineScrubSurfaceConfig? capturedConfig;

    final firstClip = TimelineClipData(
      id: 'clip-1',
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      duration: 2,
    );
    final secondClip = TimelineClipData(
      id: 'clip-2',
      type: TimelineClipType.media,
      tone: TimelineClipTone.heroMuted,
      duration: 1.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 220,
              child: TimelinePanel(
                embedded: true,
                tracks: <TimelineTrackData>[
                  TimelineTrackData(
                    kind: TimelineTrackKind.video,
                    clips: <TimelineClipData>[firstClip, secondClip],
                  ),
                ],
                currentTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(10),
                isPlaying: false,
                selectedClipId: null,
                onClipSelected: (_) {},
                onBackgroundTap: () {},
                scrubSurfaceBuilder: (config) {
                  capturedConfig = config;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final config = capturedConfig;
    expect(config, isNotNull);

    const panelWidth = 600.0;
    const panelPadding = 8.0;
    const controlHitSize = 42.0;
    const controlGap = 6.0;
    const rulerHeaderHeight = 20.0;
    const trackGapTop = 8.0;
    const clipTopInset = 2.0;
    const clipHeight = 38.0;
    const secondsWidth = 32.0;

    const contentViewportWidth = panelWidth - (panelPadding * 2);
    const playheadLeft = contentViewportWidth / 2;
    const leadingOffset = playheadLeft - controlHitSize - controlGap;
    const clipStart = leadingOffset + controlHitSize + controlGap;
    final firstClipWidth = firstClip.visualWidth(secondsWidth);
    final secondClipWidth = secondClip.visualWidth(secondsWidth);
    const gapWidth = controlGap;
    const trackCenterY =
        rulerHeaderHeight + trackGapTop + clipTopInset + (clipHeight / 2);

    final firstClipCenterX = clipStart + (firstClipWidth / 2);
    final gapCenterX = clipStart + firstClipWidth + (gapWidth / 2);
    final secondClipCenterX =
        clipStart + firstClipWidth + gapWidth + (secondClipWidth / 2);

    expect(
      _regionsContainPoint(config!.regions, firstClipCenterX, trackCenterY),
      isFalse,
    );
    expect(
      _regionsContainPoint(config.regions, gapCenterX, trackCenterY),
      isTrue,
    );
    expect(
      _regionsContainPoint(config.regions, secondClipCenterX, trackCenterY),
      isFalse,
    );
  });
}

bool _regionsContainPoint(
  List<TimelineScrubViewportRegion> regions,
  double x,
  double y,
) {
  return regions.any(
    (region) =>
        x >= region.left &&
        x <= region.left + region.width &&
        y >= region.top &&
        y <= region.top + region.height,
  );
}
