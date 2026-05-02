import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/professional_video_transition_compositor.dart';
import 'package:refusion_app/features/editor/presentation/widgets/transition_browser_bottom_sheet.dart';

void main() {
  testWidgets('transition browser locks presets before full compositor gate',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransitionBrowserBottomSheet(),
        ),
      ),
    );

    expect(find.text('Preset'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('AI Transition'), findsOneWidget);
    expect(find.text('Professional compositor required'), findsOneWidget);
    expect(find.text('Cross Dissolve'), findsNothing);

    await tester.tap(find.text('Preset'));
    await tester.pumpAndSettle();

    expect(find.text('Preset Transitions'), findsNothing);
    expect(find.text('Zoom In Pro'), findsNothing);
    expect(find.text('Cross Dissolve'), findsNothing);
    expect(find.text('Zoom In Camera'), findsNothing);
    expect(find.text('Distortion Zoom Transition In V1'), findsNothing);
  });

  testWidgets('manual transition opens before full compositor gate',
      (WidgetTester tester) async {
    TransitionBrowserResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<TransitionBrowserResult>(
                  context: context,
                  builder: (_) => const TransitionBrowserBottomSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();

    expect(result?.action, TransitionBrowserAction.openManual);
  });

  testWidgets(
      'transition browser exposes presets only when native compositor is complete',
      (WidgetTester tester) async {
    const capabilities = ProfessionalVideoTransitionCompositorCapabilities(
      dualVideoSampling: true,
      temporalMotionBlur: true,
      mirrorEdgeTiling: true,
      previewParity: true,
      liveScrubParity: true,
      playbackParity: true,
      exportParity: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TransitionBrowserBottomSheet(
            compositorCapabilities: capabilities,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Preset'));
    await tester.pumpAndSettle();

    expect(find.text('Cross Dissolve'), findsOneWidget);
    expect(find.text('Zoom In Camera'), findsNothing);
    expect(find.text('Distortion Zoom Transition In V1'), findsNothing);
    expect(find.text('Fade Black'), findsNothing);
    expect(find.text('Zoom In Pro'), findsNothing);
  });
}
