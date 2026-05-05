import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_value_truth_registry.dart';

void main() {
  final registry = MasterValueTruthRegistry();

  MasterPropertyDefinition definition(String id) {
    final result = registry.definitionById(id);
    expect(result, isNotNull, reason: 'definition `$id` must exist');
    return result!;
  }

  group('MasterValueTruthRegistry', () {
    test('contains baseline required definitions', () {
      expect(registry.definitionById('opacity'), isNotNull);
      expect(registry.definitionById('scale'), isNotNull);
      expect(registry.definitionById('position'), isNotNull);
      expect(registry.definitionById('rotation'), isNotNull);
      expect(registry.definitionById('gaussianBlur'), isNotNull);
      expect(registry.definitionById('motionBlurEnabled'), isNotNull);
      expect(registry.definitionById('motionBlurAmount'), isNotNull);
      expect(registry.definitionById('motionBlurShutterAngle'), isNotNull);
      expect(registry.definitionById('motionBlurShutterPhase'), isNotNull);
      expect(registry.definitionById('motionBlurSamples'), isNotNull);
      expect(
          registry.definitionById('motionBlurAdaptiveSampleLimit'), isNotNull);
      expect(registry.definitionById('motionBlurMaxTrailPx'), isNotNull);
      expect(registry.definitionById('tileOutputScale'), isNotNull);
      expect(registry.definitionById('cropRect'), isNotNull);
      expect(registry.definitionById('shapeWidth'), isNotNull);
      expect(registry.definitionById('shapeHeight'), isNotNull);
      expect(registry.definitionById('shapeCornerRadius'), isNotNull);
      expect(registry.definitionById('textFontSize'), isNotNull);
      expect(registry.definitionById('textFontFamily'), isNotNull);
      expect(registry.definitionById('shadowColor'), isNotNull);
      expect(registry.definitionById('visualColor'), isNotNull);
      expect(registry.definitionById('maskRevealProgress'), isNotNull);
    });

    test('opacity 100 percent maps to normalized alpha 1.0', () {
      final mapped = registry.mapValue(
        definition: definition('opacity'),
        value: const MotionPropertyValue.scalar(100),
      );
      expect(mapped.uiUnit, MasterValueUnit.percentUi);
      expect(mapped.rendererUnit, MasterValueUnit.normalized01);
      expect(mapped.renderer.scalar, closeTo(1.0, 0.0001));
    });

    test('opacity 0 percent maps to normalized alpha 0.0', () {
      final mapped = registry.mapValue(
        definition: definition('opacity'),
        value: const MotionPropertyValue.scalar(0),
      );
      expect(mapped.renderer.scalar, 0.0);
    });

    test('scale signed percent maps to multiplier', () {
      final normal = registry.mapValue(
        definition: definition('scale'),
        value: const MotionPropertyValue.scalar(0),
      );
      final doubled = registry.mapValue(
        definition: definition('scale'),
        value: const MotionPropertyValue.scalar(100),
      );
      final half = registry.mapValue(
        definition: definition('scale'),
        value: const MotionPropertyValue.scalar(-50),
      );

      expect(normal.engine.scalar, closeTo(1.0, 0.0001));
      expect(doubled.engine.scalar, closeTo(2.0, 0.0001));
      expect(half.engine.scalar, closeTo(0.5, 0.0001));
    });

    test('rotation 180 degrees maps to pi radians', () {
      final mapped = registry.mapValue(
        definition: definition('rotation'),
        value: const MotionPropertyValue.scalar(180),
      );
      expect(mapped.renderer.scalar, closeTo(3.1415926535, 0.0001));
    });

    test('gaussian blur clamps negative values', () {
      final mapped = registry.mapValue(
        definition: definition('gaussianBlur'),
        value: const MotionPropertyValue.scalar(-20),
      );
      expect(mapped.ui.scalar, 0.0);
      expect(mapped.renderer.scalar, 0.0);
    });

    test('maps extended effect and trim motion properties', () {
      expect(
        registry
            .definitionForMotionProperty(MotionPropertyCatalog.shadowOpacity)
            ?.id,
        'shadowOpacity',
      );
      expect(
        registry
            .definitionForMotionProperty(MotionPropertyCatalog.trimStart)
            ?.id,
        'trimStart',
      );
      expect(
        registry
            .definitionForMotionProperty(MotionPropertyCatalog.shadowColor)
            ?.id,
        'shadowColor',
      );
      final trimOffset = registry.mapValue(
        definition: definition('trimOffset'),
        value: const MotionPropertyValue.scalar(50),
      );
      expect(trimOffset.renderer.scalar, closeTo(0.5, 0.0001));
    });

    test('maps professional temporal motion blur controls', () {
      expect(
        registry
            .definitionForMotionProperty(
              MotionPropertyCatalog.motionBlurEnabled,
            )
            ?.id,
        'motionBlurEnabled',
      );
      expect(
        registry
            .definitionForMotionProperty(MotionPropertyCatalog.motionBlurAmount)
            ?.id,
        'motionBlurAmount',
      );
      expect(
        registry
            .definitionForMotionProperty(
              MotionPropertyCatalog.motionBlurShutterAngle,
            )
            ?.id,
        'motionBlurShutterAngle',
      );

      final enabled = registry.mapValue(
        definition: definition('motionBlurEnabled'),
        value: const MotionPropertyValue.boolean(true),
      );
      expect(enabled.renderer.booleanValue, isTrue);

      final amount = registry.mapValue(
        definition: definition('motionBlurAmount'),
        value: const MotionPropertyValue.scalar(75),
      );
      expect(amount.renderer.scalar, closeTo(0.75, 0.0001));

      final samples = registry.mapValue(
        definition: definition('motionBlurSamples'),
        value: const MotionPropertyValue.integer(120),
      );
      expect(samples.renderer.scalar, 64);

      final phase = registry.mapValue(
        definition: definition('motionBlurShutterPhase'),
        value: const MotionPropertyValue.scalar(-900),
      );
      expect(phase.renderer.scalar, -720);
    });

    test('maps crop, shape, and text motion properties', () {
      expect(
        registry
            .definitionForMotionProperty(MotionPropertyCatalog.cropRect)
            ?.id,
        'cropRect',
      );
      expect(
        registry.definitionForMotionProperty(MotionPropertyCatalog.width)?.id,
        'shapeWidth',
      );
      expect(
        registry
            .definitionForMotionProperty(MotionPropertyCatalog.fontSize)
            ?.id,
        'textFontSize',
      );
      expect(
        registry
            .definitionForMotionProperty(MotionPropertyCatalog.fontFamily)
            ?.id,
        'textFontFamily',
      );

      final crop = registry.mapValue(
        definition: definition('cropRect'),
        value: const MotionPropertyValue.rect(
          MotionRect(left: -0.2, top: 0.1, width: 1.4, height: 0.5),
        ),
      );
      expect(crop.renderer.rect?.left, closeTo(0.0, 0.0001));
      expect(crop.renderer.rect?.width, closeTo(1.0, 0.0001));

      final fontFamily = registry.mapValue(
        definition: definition('textFontFamily'),
        value: const MotionPropertyValue.stringValue('Inter'),
      );
      expect(fontFamily.renderer.token, 'Inter');

      final visualColor = registry.mapValue(
        definition: definition('visualColor'),
        value: const MotionPropertyValue.colorArgb(0xFF102030),
      );
      expect(visualColor.renderer.colorArgb, 0xFF102030);

      final maskReveal = registry.mapValue(
        definition: definition('maskRevealProgress'),
        value: const MotionPropertyValue.scalar(65),
      );
      expect(maskReveal.renderer.scalar, closeTo(0.65, 0.0001));
    });
  });
}
