import '../../domain/models/professional_motion_models.dart';

/// Canonical resolver for MCP property ids/aliases used by runtime motion apply.
///
/// This keeps property semantics consistent across MCP payload variants
/// (`blurAmount`, `motion_blur`, `rotationDeg`, etc.) and maps them into
/// the canonical MotionPropertyCatalog ids.
class UniversalMcpMotionPropertyResolver {
  const UniversalMcpMotionPropertyResolver();

  static const Map<String, String> _aliases = <String, String>{
    'transform.position.x': 'transform.position.x',
    'transform.translate.x': 'transform.position.x',
    'transform.translation.x': 'transform.position.x',
    'position.x': 'transform.position.x',
    'positionx': 'transform.position.x',
    'x': 'transform.position.x',
    'transform.position.y': 'transform.position.y',
    'transform.translate.y': 'transform.position.y',
    'transform.translation.y': 'transform.position.y',
    'position.y': 'transform.position.y',
    'positiony': 'transform.position.y',
    'y': 'transform.position.y',
    'transform.scale.x': 'transform.scale.x',
    'scale.x': 'transform.scale.x',
    'scalex': 'transform.scale.x',
    'transform.scale.y': 'transform.scale.y',
    'scale.y': 'transform.scale.y',
    'scaley': 'transform.scale.y',
    'transform.rotation.degrees': 'transform.rotation.degrees',
    'transform.rotation': 'transform.rotation.degrees',
    'rotation': 'transform.rotation.degrees',
    'rotation.degrees': 'transform.rotation.degrees',
    'rotationdegrees': 'transform.rotation.degrees',
    'rotationdeg': 'transform.rotation.degrees',
    'rotate': 'transform.rotation.degrees',
    'visual.opacity': 'visual.opacity',
    'visual.opacity.alpha': 'visual.opacity',
    'opacity': 'visual.opacity',
    'alpha': 'visual.opacity',
    'visual.blur.amount': 'visual.blur.amount',
    'bluramount': 'visual.blur.amount',
    'blur.amount': 'visual.blur.amount',
    'gaussian_blur': 'visual.blur.amount',
    'gaussianblur': 'visual.blur.amount',
    'blur': 'visual.blur.amount',
    'effect.motionblur.amount': 'effect.motionBlur.amount',
    'effect.motionblur': 'effect.motionBlur.amount',
    'motionbluramount': 'effect.motionBlur.amount',
    'motionblur': 'effect.motionBlur.amount',
    'motion_blur': 'effect.motionBlur.amount',
    'motion_blur_amount': 'effect.motionBlur.amount',
    'motion.blur.amount': 'effect.motionBlur.amount',
  };

  MotionPropertyDefinition? resolve(String propertyId) {
    final normalized = propertyId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final canonical = _aliases[normalized] ?? normalized;
    switch (canonical) {
      case 'transform.position.x':
        return MotionPropertyCatalog.positionX;
      case 'transform.position.y':
        return MotionPropertyCatalog.positionY;
      case 'transform.scale.x':
        return MotionPropertyCatalog.scaleX;
      case 'transform.scale.y':
        return MotionPropertyCatalog.scaleY;
      case 'transform.rotation.degrees':
        return MotionPropertyCatalog.rotationDegrees;
      case 'visual.opacity':
        return MotionPropertyCatalog.opacity;
      case 'visual.blur.amount':
        return MotionPropertyCatalog.blurAmount;
      case 'effect.motionBlur.amount':
        return MotionPropertyCatalog.motionBlurAmount;
    }
    return null;
  }
}
