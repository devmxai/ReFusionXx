import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/services/universal_mcp_motion_property_resolver.dart';

void main() {
  const resolver = UniversalMcpMotionPropertyResolver();

  test('resolves core transform aliases to canonical definitions', () {
    expect(
      resolver.resolve('position.x'),
      same(MotionPropertyCatalog.positionX),
    );
    expect(
      resolver.resolve('positionY'),
      same(MotionPropertyCatalog.positionY),
    );
    expect(
      resolver.resolve('rotationDeg'),
      same(MotionPropertyCatalog.rotationDegrees),
    );
  });

  test('resolves visual and effect aliases used by MCP payloads', () {
    expect(
      resolver.resolve('gaussian_blur'),
      same(MotionPropertyCatalog.blurAmount),
    );
    expect(
      resolver.resolve('blurAmount'),
      same(MotionPropertyCatalog.blurAmount),
    );
    expect(
      resolver.resolve('motionBlurAmount'),
      same(MotionPropertyCatalog.motionBlurAmount),
    );
    expect(
      resolver.resolve('motion_blur'),
      same(MotionPropertyCatalog.motionBlurAmount),
    );
  });

  test('returns null for unsupported property ids', () {
    expect(resolver.resolve('video.color.temperature'), isNull);
    expect(resolver.resolve(''), isNull);
  });
}
