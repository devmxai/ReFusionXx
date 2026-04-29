import '../models/professional_motion_models.dart';

class ScopeMotionPropertyCatalog {
  const ScopeMotionPropertyCatalog();

  static final List<MotionPropertyDefinition> sharedVisualElementProperties =
      List<MotionPropertyDefinition>.unmodifiable(<MotionPropertyDefinition>[
    MotionPropertyCatalog.positionX,
    MotionPropertyCatalog.positionY,
    MotionPropertyCatalog.scaleX,
    MotionPropertyCatalog.scaleY,
    MotionPropertyCatalog.rotationDegrees,
    MotionPropertyCatalog.opacity,
    MotionPropertyCatalog.blurAmount,
  ]);

  static final List<MotionPropertyDefinition> _textElementProperties =
      List<MotionPropertyDefinition>.unmodifiable(<MotionPropertyDefinition>[
    ...sharedVisualElementProperties,
    MotionPropertyCatalog.fontSize,
    MotionPropertyCatalog.fontWeight,
    MotionPropertyCatalog.lineHeight,
    MotionPropertyCatalog.letterSpacing,
    MotionPropertyCatalog.revealProgress,
  ]);

  static final List<MotionPropertyDefinition> _imageElementProperties =
      List<MotionPropertyDefinition>.unmodifiable(<MotionPropertyDefinition>[
    ...sharedVisualElementProperties,
    MotionPropertyCatalog.cropRect,
  ]);

  static final List<MotionPropertyDefinition> _shapeElementProperties =
      List<MotionPropertyDefinition>.unmodifiable(<MotionPropertyDefinition>[
    ...sharedVisualElementProperties,
    MotionPropertyCatalog.width,
    MotionPropertyCatalog.height,
    MotionPropertyCatalog.cornerRadius,
  ]);

  static final Map<MotionElementKind, List<MotionPropertyDefinition>>
      _propertiesByElementKind =
      Map<MotionElementKind, List<MotionPropertyDefinition>>.unmodifiable(
    <MotionElementKind, List<MotionPropertyDefinition>>{
      MotionElementKind.text: _textElementProperties,
      MotionElementKind.image: _imageElementProperties,
      MotionElementKind.shape: _shapeElementProperties,
    },
  );

  List<MotionPropertyDefinition> propertiesForElementKind(
    MotionElementKind elementKind,
  ) {
    return _propertiesByElementKind[elementKind] ??
        const <MotionPropertyDefinition>[];
  }

  bool supportsElementKind(MotionElementKind elementKind) {
    return propertiesForElementKind(elementKind).isNotEmpty;
  }

  bool supportsPropertyForElementKind({
    required MotionElementKind elementKind,
    required MotionPropertyDefinition definition,
    MotionTargetKind targetKind = MotionTargetKind.element,
  }) {
    if (!definition.isAnimatable ||
        !definition.supportedTargets.contains(targetKind)) {
      return false;
    }
    return propertiesForElementKind(elementKind).any(
      (property) => property.id == definition.id,
    );
  }

  MotionPropertyTarget elementTarget({
    required String projectId,
    required String sceneId,
    required String layerId,
    required String elementId,
  }) {
    return MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: elementId,
      projectId: projectId,
      sceneId: sceneId,
      layerId: layerId,
      elementId: elementId,
    );
  }
}
