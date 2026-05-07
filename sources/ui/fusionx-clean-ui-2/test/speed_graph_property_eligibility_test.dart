import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/speed_graph_property_eligibility.dart';

void main() {
  const resolver = SpeedGraphPropertyEligibilityResolver();

  MotionPropertyDefinition _def({
    required String id,
    required MotionPropertyValueKind kind,
    String name = 'value',
    MotionPropertyGroup group = MotionPropertyGroup.effect,
    bool isAnimatable = true,
  }) {
    return MotionPropertyDefinition(
      id: id,
      path: MotionPropertyPath(group: group, name: name),
      valueKind: kind,
      supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
      defaultValue: switch (kind) {
        MotionPropertyValueKind.scalar => const MotionPropertyValue.scalar(0.0),
        MotionPropertyValueKind.integer => const MotionPropertyValue.integer(0),
        MotionPropertyValueKind.boolean =>
          const MotionPropertyValue.boolean(false),
        MotionPropertyValueKind.stringValue =>
          const MotionPropertyValue.stringValue(''),
        MotionPropertyValueKind.colorArgb =>
          const MotionPropertyValue.colorArgb(0xFFFFFFFF),
        MotionPropertyValueKind.point2D =>
          const MotionPropertyValue.point2D(MotionPoint2D(x: 0.0, y: 0.0)),
        MotionPropertyValueKind.size2D => const MotionPropertyValue.size2D(
            MotionSize2D(width: 1.0, height: 1.0),
          ),
        MotionPropertyValueKind.rect => const MotionPropertyValue.rect(
            MotionRect(left: 0.0, top: 0.0, width: 1.0, height: 1.0),
          ),
        MotionPropertyValueKind.enumValue =>
          const MotionPropertyValue.enumValue('default'),
      },
      isAnimatable: isAnimatable,
    );
  }

  test('scalar property is eligible and supports value/speed graph', () {
    final eligibility = resolver.resolve(
      _def(id: 'rotation', kind: MotionPropertyValueKind.scalar),
    );
    expect(eligibility.supportsSpeedGraph, isTrue);
    expect(eligibility.supportsValueGraph, isTrue);
    expect(eligibility.reason, 'supported_scalar_channel');
  });

  test('opacity scalar is eligible but overshoot is blocked', () {
    final eligibility = resolver.resolve(
      _def(
        id: 'opacity',
        kind: MotionPropertyValueKind.scalar,
        name: 'opacity',
        group: MotionPropertyGroup.visual,
      ),
    );
    expect(eligibility.supportsSpeedGraph, isTrue);
    expect(eligibility.supportsOvershoot, isFalse);
  });

  test('point2d property reports decomposition channels', () {
    final eligibility = resolver.resolve(
      _def(
        id: 'position',
        kind: MotionPropertyValueKind.point2D,
        name: 'position',
        group: MotionPropertyGroup.transform,
      ),
    );
    expect(eligibility.supportsSpeedGraph, isTrue);
    expect(eligibility.decomposedChannels, containsAll(<String>['x', 'y']));
  });

  test('boolean and string properties are unsupported', () {
    final boolEligibility = resolver.resolve(
      _def(id: 'enabled', kind: MotionPropertyValueKind.boolean),
    );
    final stringEligibility = resolver.resolve(
      _def(id: 'label', kind: MotionPropertyValueKind.stringValue),
    );
    expect(boolEligibility.supportsSpeedGraph, isFalse);
    expect(boolEligibility.reason, 'unsupported_boolean');
    expect(stringEligibility.supportsSpeedGraph, isFalse);
    expect(stringEligibility.reason, 'unsupported_string');
  });

  test('non-animatable property is blocked with explicit reason', () {
    final eligibility = resolver.resolve(
      _def(
        id: 'locked',
        kind: MotionPropertyValueKind.scalar,
        isAnimatable: false,
      ),
    );
    expect(eligibility.supportsSpeedGraph, isFalse);
    expect(eligibility.reason, 'property_not_animatable');
  });
}

