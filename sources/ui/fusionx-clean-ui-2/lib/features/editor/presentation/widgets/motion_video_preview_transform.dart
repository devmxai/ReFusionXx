import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/professional_motion_compilation_models.dart';
import '../../domain/models/professional_motion_evaluation_models.dart';
import '../../domain/models/professional_motion_models.dart';

class MotionVideoPreviewTransform {
  const MotionVideoPreviewTransform({
    required this.elementId,
    required this.assetId,
    required this.zIndex,
    required this.positionX,
    required this.positionY,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDegrees,
    required this.opacity,
    required this.blurAmount,
  });

  final String elementId;
  final String? assetId;
  final int zIndex;
  final double positionX;
  final double positionY;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;
  final double opacity;
  final double blurAmount;

  bool get isIdentity =>
      positionX == 0 &&
      positionY == 0 &&
      scaleX == 1 &&
      scaleY == 1 &&
      rotationDegrees == 0 &&
      opacity >= 0.999 &&
      blurAmount <= 0;
}

class MotionVideoPreviewTransformResolver {
  const MotionVideoPreviewTransformResolver();

  MotionVideoPreviewTransform? resolve({
    required MotionNormalizedComposition composition,
    required MotionEvaluationSnapshot snapshot,
    String? preferredAssetId,
  }) {
    final transforms = resolveAll(
      composition: composition,
      snapshot: snapshot,
    );
    if (transforms.isEmpty) {
      return null;
    }
    final normalizedPreferredAssetId = preferredAssetId?.trim();
    if (normalizedPreferredAssetId != null &&
        normalizedPreferredAssetId.isNotEmpty) {
      for (final transform in transforms.reversed) {
        if (transform.assetId == normalizedPreferredAssetId) {
          return transform;
        }
      }
    }
    return transforms.last;
  }

  List<MotionVideoPreviewTransform> resolveAll({
    required MotionNormalizedComposition composition,
    required MotionEvaluationSnapshot snapshot,
  }) {
    final sourceByElementId = <String, MotionElementSourceBinding>{};
    for (final scene in composition.scenes) {
      for (final layer in scene.layers) {
        for (final element in layer.elements) {
          final sourceBinding = element.sourceBinding;
          if (element.kind == MotionElementKind.videoClip &&
              sourceBinding != null) {
            sourceByElementId[element.id] = sourceBinding;
          }
        }
      }
    }

    final transforms = <({int order, MotionVideoPreviewTransform transform})>[];
    var order = 0;
    for (final scene in snapshot.scenes) {
      if (scene.activationState != MotionActivationState.active) {
        continue;
      }
      for (final layer in scene.layers) {
        if (layer.activationState != MotionActivationState.active) {
          continue;
        }
        final layerProperties = _propertiesById(layer.properties);
        final layerOpacity = _scalar(
          layerProperties,
          MotionPropertyCatalog.opacity.id,
          1,
        );
        if (layerOpacity <= 0) {
          continue;
        }
        for (final element in layer.elements) {
          if (element.kind != MotionElementKind.videoClip ||
              element.activationState != MotionActivationState.active) {
            continue;
          }
          final sourceBinding = sourceByElementId[element.id];
          if (sourceBinding == null) {
            continue;
          }
          final assetId = sourceBinding.assetId ?? sourceBinding.sourceId;
          if (assetId.isEmpty) {
            continue;
          }
          final properties = _propertiesById(element.properties);
          final opacity =
              _scalar(properties, MotionPropertyCatalog.opacity.id, 1) *
                  layerOpacity;
          if (opacity <= 0) {
            continue;
          }
          transforms.add((
            order: order++,
            transform: MotionVideoPreviewTransform(
              elementId: element.id,
              assetId: assetId,
              zIndex: layer.zIndex,
              positionX: _scalar(
                properties,
                MotionPropertyCatalog.positionX.id,
                0,
              ),
              positionY: _scalar(
                properties,
                MotionPropertyCatalog.positionY.id,
                0,
              ),
              scaleX: _scalar(properties, MotionPropertyCatalog.scaleX.id, 1),
              scaleY: _scalar(properties, MotionPropertyCatalog.scaleY.id, 1),
              rotationDegrees: _scalar(
                properties,
                MotionPropertyCatalog.rotationDegrees.id,
                0,
              ),
              opacity: opacity.clamp(0.0, 1.0).toDouble(),
              blurAmount: math.max(
                0,
                _scalar(properties, MotionPropertyCatalog.blurAmount.id, 0),
              ),
            ),
          ));
        }
      }
    }

    transforms.sort((left, right) {
      final zIndex = left.transform.zIndex.compareTo(right.transform.zIndex);
      if (zIndex != 0) {
        return zIndex;
      }
      return left.order.compareTo(right.order);
    });
    return List<MotionVideoPreviewTransform>.unmodifiable(
      transforms.map((entry) => entry.transform),
    );
  }

  static Map<String, MotionPropertyValue> _propertiesById(
    List<MotionEvaluatedPropertyValue> properties,
  ) {
    return <String, MotionPropertyValue>{
      for (final property in properties) property.definition.id: property.value,
    };
  }

  static double _scalar(
    Map<String, MotionPropertyValue> properties,
    String id,
    double fallback,
  ) {
    final rawValue = properties[id]?.rawValue;
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    return fallback;
  }
}

class MotionVideoPreviewTransformSurface extends StatelessWidget {
  const MotionVideoPreviewTransformSurface({
    super.key,
    required this.transform,
    required this.canvasSize,
    required this.child,
  });

  final MotionVideoPreviewTransform? transform;
  final MotionSize2D canvasSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final transform = this.transform;
    if (transform == null || transform.isIdentity) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        if (viewportWidth <= 0 ||
            viewportHeight <= 0 ||
            canvasSize.width <= 0 ||
            canvasSize.height <= 0) {
          return child;
        }
        final scaleX = viewportWidth / canvasSize.width;
        final scaleY = viewportHeight / canvasSize.height;
        Widget transformed = ClipRect(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: transform.blurAmount * scaleX,
              sigmaY: transform.blurAmount * scaleY,
            ),
            enabled: transform.blurAmount > 0,
            child: Opacity(
              opacity: transform.opacity,
              child: child,
            ),
          ),
        );
        transformed = Transform.scale(
          scaleX: transform.scaleX,
          scaleY: transform.scaleY,
          child: transformed,
        );
        transformed = Transform.rotate(
          angle: transform.rotationDegrees * math.pi / 180,
          child: transformed,
        );
        return Transform.translate(
          offset: Offset(
            transform.positionX * scaleX,
            transform.positionY * scaleY,
          ),
          child: transformed,
        );
      },
    );
  }
}
