import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/widgets/timeline_panel.dart';

void main() {
  test('scene video layer proxies keep duration-based timeline width', () {
    final clip = TimelineClipData(
      id: 'scene-video-layer',
      type: TimelineClipType.placeholder,
      tone: TimelineClipTone.aiGenerated,
      duration: 0.5,
      label: 'Video Layer',
      contentKind: TimelineClipContentKind.scene,
      visualKind: TimelineVisualKind.video,
    );

    expect(clip.visualWidth(32), 16);
  });

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

  testWidgets('scene video layer boundaries expose transition bridge taps',
      (WidgetTester tester) async {
    TimelineTrackData? tappedTrack;
    TimelineClipData? tappedLeftClip;
    TimelineClipData? tappedRightClip;

    final firstClip = TimelineClipData(
      id: 'scene-video-layer-1',
      type: TimelineClipType.placeholder,
      tone: TimelineClipTone.aiGenerated,
      duration: 2,
      label: 'Video 1',
      contentKind: TimelineClipContentKind.scene,
      visualKind: TimelineVisualKind.video,
    );
    final secondClip = TimelineClipData(
      id: 'scene-video-layer-2',
      type: TimelineClipType.placeholder,
      tone: TimelineClipTone.aiGenerated,
      duration: 1.5,
      label: 'Video 2',
      contentKind: TimelineClipContentKind.scene,
      visualKind: TimelineVisualKind.video,
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
                    contentKind: TimelineTrackContentKind.scene,
                    visualKind: TimelineVisualKind.video,
                    clips: <TimelineClipData>[firstClip, secondClip],
                  ),
                ],
                currentTime: TimelineTime.zero,
                timelineDurationTime: TimelineTime.fromSecondsDouble(10),
                isPlaying: false,
                selectedClipId: null,
                onClipSelected: (_) {},
                onBackgroundTap: () {},
                onTransitionTap: (track, leftClip, rightClip) {
                  tappedTrack = track;
                  tappedLeftClip = leftClip;
                  tappedRightClip = rightClip;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

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
    final boundaryX = clipStart + firstClip.visualWidth(secondsWidth);
    const boundaryY =
        rulerHeaderHeight + trackGapTop + clipTopInset + (clipHeight / 2);

    final panelOrigin = tester.getTopLeft(find.byType(TimelinePanel));
    await tester.tapAt(panelOrigin + Offset(boundaryX, boundaryY));
    await tester.pump();

    expect(tappedTrack?.contentKind, TimelineTrackContentKind.scene);
    expect(tappedLeftClip?.id, firstClip.id);
    expect(tappedRightClip?.id, secondClip.id);
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
