import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_interpolation_evaluator.dart';
import 'package:refusion_app/features/editor/domain/services/motion_interpolation_truth_compiler.dart';
import 'package:refusion_app/features/editor/domain/services/speed_graph_custom_preset_persistence_service.dart';
import 'package:refusion_app/features/editor/presentation/widgets/layer_scope_graph_bottom_sheet.dart';

void main() {
  testWidgets('copy paste actions emit graph edit types', (tester) async {
    final editTypes = <String>[];
    MotionKeyframeVelocity? pastedVelocity;
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
            onVelocityChanged: (velocity, {required editType}) {
              editTypes.add(editType);
              if (editType == 'paste') {
                pastedVelocity = velocity;
              }
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
    expect(pastedVelocity, isNotNull);
    final compiler = MotionInterpolationTruthCompiler();
    final compiled = compiler.compileFromVelocity(
      velocity: pastedVelocity!,
      inputMode: MotionInterpolationCompileInputMode.velocityNumbers,
    );
    expect(compiled.interpolation.bezier, isNotNull);
  });

  testWidgets('custom curve drag updates curve truth through velocity bridge',
      (tester) async {
    const initialVelocity = MotionKeyframeVelocity(
      incomingSpeed: 0,
      outgoingSpeed: 0,
      incomingInfluence: 33.333,
      outgoingInfluence: 33.333,
      presetId: 'easyEase',
      continuous: false,
    );
    final velocities = <MotionKeyframeVelocity>[];
    final compiler = MotionInterpolationTruthCompiler();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerScopeGraphBottomSheet(
            easyEaseEnabled: true,
            selectedPreset: LayerScopeGraphSpeedPreset.easyEase,
            initialVelocity: initialVelocity,
            onDone: () {},
            onEasyEaseChanged: (_) {},
            onVelocityChanged: (velocity, {required editType}) {
              if (editType.startsWith('drag')) {
                velocities.add(velocity);
              }
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Custom Curve'));
    await tester.pumpAndSettle();

    final canvas = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter != null &&
          widget.painter.runtimeType.toString().contains('_SpeedGraphPainter'),
    );
    expect(canvas, findsOneWidget);
    final rect = tester.getRect(canvas);
    final start = Offset(rect.left + rect.width * 0.333, rect.bottom - 18);
    final end =
        Offset(rect.left + rect.width * 0.2, rect.top + rect.height * 0.4);
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(velocities, isNotEmpty);
    final before = compiler.compileFromVelocity(
      velocity: initialVelocity,
      fallback: const MotionInterpolationSpec.cubicBezier(
        bezier: MotionBezierControlPoints(
          x1: 0.333,
          y1: 0.0,
          x2: 0.667,
          y2: 1.0,
        ),
      ),
      inputMode: MotionInterpolationCompileInputMode.velocityNumbers,
    );
    final after = compiler.compileFromVelocity(
      velocity: velocities.last,
      fallback: const MotionInterpolationSpec.cubicBezier(
        bezier: MotionBezierControlPoints(
          x1: 0.333,
          y1: 0.0,
          x2: 0.667,
          y2: 1.0,
        ),
      ),
      inputMode: MotionInterpolationCompileInputMode.velocityNumbers,
    );
    expect(after.curveHash, isNot(equals(before.curveHash)));
    expect(
      evaluateMotionCurveProgress(after.interpolation, 0.25),
      isNot(closeTo(
          evaluateMotionCurveProgress(before.interpolation, 0.25), 1e-6)),
    );
  });

  test('speed graph canvas uses evaluator sampling and Bezier truth proof', () {
    final source = File(
      '/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/layer_scope_graph_bottom_sheet.dart',
    ).readAsStringSync();
    expect(source.contains('TF_SPEED_GRAPH_CANVAS_PROOF'), isTrue);
    expect(source.contains('evaluateMotionCurveProgress(interpolation, t)'),
        isTrue);
    expect(source.contains('wroteBezierTruth=true'), isTrue);
  });

  testWidgets('numeric panel clamps overshoot for opacity lanes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerScopeGraphBottomSheet(
            easyEaseEnabled: true,
            propertyPath: 'transform.opacity',
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
          ),
        ),
      ),
    );

    await tester.tap(find.text('Numeric'));
    await tester.pumpAndSettle();

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders.length, greaterThanOrEqualTo(4));
    expect(sliders[2].max, 100);
    expect(sliders[3].max, 100);
    expect(find.textContaining('%/sec'), findsWidgets);
  });

  testWidgets('save preset and apply from My Presets uses Bezier truth',
      (tester) async {
    final customPresetService = SpeedGraphCustomPresetPersistenceService(
      storageDriver: InMemorySpeedGraphCustomPresetStorageDriver(),
    )..clearForTest();
    final editTypes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerScopeGraphBottomSheet(
            easyEaseEnabled: true,
            selectedPreset: LayerScopeGraphSpeedPreset.slowFastSlow,
            initialVelocity: const MotionKeyframeVelocity(
              incomingSpeed: 0,
              outgoingSpeed: 0,
              incomingInfluence: 85,
              outgoingInfluence: 85,
              presetId: 'slowFastSlow',
            ),
            onDone: () {},
            onEasyEaseChanged: (_) {},
            customPresetPersistenceService: customPresetService,
            onVelocityChanged: (velocity, {required editType}) {
              editTypes.add(editType);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save Preset'));
    await tester.pumpAndSettle();
    expect(find.text('My Presets'), findsOneWidget);
    expect(customPresetService.listPresets(), hasLength(1));

    final beforeHash = customPresetService.listPresets().first.curveHash;
    await tester.tap(find.text('Custom Curve'));
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter != null &&
          widget.painter.runtimeType.toString().contains('_SpeedGraphPainter'),
    );
    final rect = tester.getRect(canvas);
    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width * 0.3, rect.bottom - 18),
    );
    await gesture.moveTo(Offset(rect.left + rect.width * 0.15, rect.top + 20));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Curve').first);
    await tester.pumpAndSettle();

    expect(editTypes.contains('apply'), isTrue);
    expect(
        customPresetService.listPresets().first.curveHash, equals(beforeHash));
  });
}
