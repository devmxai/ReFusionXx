import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/widgets/timeline_transition_preview_overlay.dart';

void main() {
  final samplePngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wn0n1wAAAAASUVORK5CYII=',
  );

  Widget buildHarness({
    required TimelineTrackTransitionData transition,
    Uint8List? outgoingBytes,
    Uint8List? incomingBytes,
    double progress = 0.35,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: TimelineTransitionPreviewOverlay(
            transition: transition,
            progress: progress,
            outgoingThumbnailBytes: outgoingBytes,
            incomingThumbnailBytes: incomingBytes,
          ),
        ),
      ),
    );
  }

  double? blackBoxOpacity(WidgetTester tester) {
    for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
      final color = box.color;
      if (color.red == 0 && color.green == 0 && color.blue == 0) {
        return color.opacity;
      }
    }
    return null;
  }

  testWidgets(
      'manual transition does not inject incoming image for outgoing-only effects',
      (tester) async {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(620),
      manualEffectIds: const <String>['outgoingBoostScale'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'outgoingBoostScale',
          label: 'Outgoing Scale',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[100.0, 112.0],
        ),
      ],
    );

    await tester.pumpWidget(
      buildHarness(
        transition: transition,
        incomingBytes: samplePngBytes,
        progress: 0.78,
      ),
    );

    expect(find.byType(ClipRRect), findsNothing);
  });

  testWidgets('manual black mix follows keyframe value away from the seam',
      (tester) async {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(2000),
      manualEffectIds: const <String>['blackPeak'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'blackPeak',
          label: 'Black Mix',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[0.0, 1.0],
          keyframeValues: <double>[100.0, 100.0],
        ),
      ],
    );

    await tester.pumpWidget(
      buildHarness(
        transition: transition,
        progress: 0.1,
      ),
    );

    expect(blackBoxOpacity(tester), closeTo(1.0, 0.01));
  });

  testWidgets(
      'manual black mix stays inactive until real keyframes are authored',
      (tester) async {
    final transition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(2000),
      manualEffectIds: const <String>['blackPeak'],
      manualAnimationLanes: const <TimelineAnimationLaneData>[
        TimelineAnimationLaneData(
          id: 'blackPeak',
          label: 'Black Mix',
          targetClipId: 'clip-a',
          normalizedKeyframeStops: <double>[],
          keyframeValues: <double>[],
        ),
      ],
      parameterValues: const <String, double>{'blackPeak': 0.0},
    );

    await tester.pumpWidget(
      buildHarness(
        transition: transition,
        progress: 0.5,
      ),
    );

    expect(blackBoxOpacity(tester), isNull);
  });

  testWidgets('manual black mix accepts normalized and percent fallbacks',
      (tester) async {
    final normalizedTransition = TimelineTrackTransitionData(
      id: 'transition-1',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.manual,
      durationTime: TimelineTime.fromMilliseconds(2000),
      manualEffectIds: const <String>['blackPeak'],
      parameterValues: const <String, double>{'blackPeak': 0.5},
    );

    await tester.pumpWidget(
      buildHarness(
        transition: normalizedTransition,
        progress: 0.5,
      ),
    );

    expect(blackBoxOpacity(tester), closeTo(0.5, 0.01));

    final percentTransition = normalizedTransition.copyWith(
      parameterValues: const <String, double>{'blackPeak': 50.0},
    );

    await tester.pumpWidget(
      buildHarness(
        transition: percentTransition,
        progress: 0.5,
      ),
    );

    expect(blackBoxOpacity(tester), closeTo(0.5, 0.01));
  });

  testWidgets(
      'zoom in camera does not draw fake still-frame or speed-line preview',
      (tester) async {
    final transition = TimelineTrackTransitionData(
      id: 'transition-zoom',
      leftClipId: 'clip-a',
      rightClipId: 'clip-b',
      preset: TimelineTransitionPreset.zoomInCamera,
      durationTime: TimelineTime.fromMilliseconds(4000),
      parameterValues: const <String, double>{
        'outgoingBoostScale': 3.0,
        'incomingStartScale': 0.28,
        'motionBlurAmount': 18.0,
        'shakeAmount': 5.0,
      },
    );

    await tester.pumpWidget(
      buildHarness(
        transition: transition,
        outgoingBytes: samplePngBytes,
        incomingBytes: samplePngBytes,
        progress: 0.5,
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byType(ClipRRect), findsNothing);
    expect(find.text('Preview warming'), findsNothing);
  });
}
