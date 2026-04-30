import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/widgets/transition_browser_bottom_sheet.dart';

void main() {
  testWidgets('transition browser opens preset picker before manual and ai',
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
    expect(find.text('Cross Dissolve'), findsNothing);

    await tester.tap(find.text('Preset'));
    await tester.pumpAndSettle();

    expect(find.text('Preset Transitions'), findsOneWidget);
    expect(find.text('Cross Dissolve'), findsOneWidget);
    expect(find.text('Fade Black'), findsOneWidget);
    expect(find.text('Zoom In Camera'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Transition Bridge'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
  });
}
