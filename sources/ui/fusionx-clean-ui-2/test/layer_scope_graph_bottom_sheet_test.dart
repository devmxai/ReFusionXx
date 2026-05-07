import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/presentation/widgets/layer_scope_graph_bottom_sheet.dart';

void main() {
  testWidgets('copy paste actions emit graph edit types', (tester) async {
    final editTypes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerScopeGraphBottomSheet(
            easyEaseEnabled: true,
            selectedPreset: LayerScopeGraphSpeedPreset.easyEase,
            initialVelocity: const MotionKeyframeVelocity(
              incomingSpeed: 0,
              outgoingSpeed: 0,
              incomingInfluence: 33.333,
              outgoingInfluence: 33.333,
              presetId: 'easyEase',
            ),
            onDone: () {},
            onEasyEaseChanged: (_) {},
            onVelocityChanged: (_, {required editType}) {
              editTypes.add(editType);
            },
          ),
        ),
      ),
    );

    expect(find.text('Copy Curve'), findsOneWidget);
    expect(find.text('Paste Curve'), findsOneWidget);

    await tester.tap(find.text('Copy Curve'));
    await tester.pump();
    expect(find.text('Recent 1'), findsOneWidget);

    await tester.tap(find.text('Paste Curve'));
    await tester.pump();
    await tester.tap(find.text('Paste Selected'));
    await tester.pump();
    await tester.tap(find.text('Paste Lane'));
    await tester.pump();

    expect(editTypes.contains('paste'), isTrue);
    expect(editTypes.contains('pasteSelected'), isTrue);
    expect(editTypes.contains('pasteLane'), isTrue);
  });
}
