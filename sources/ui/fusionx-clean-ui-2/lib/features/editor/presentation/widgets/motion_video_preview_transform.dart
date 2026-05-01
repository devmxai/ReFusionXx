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

class MotionVideoPreviewSurfaceTransform {
  const MotionVideoPreviewSurfaceTransform({
    this.positionX = 0,
    this.positionY = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotationDegrees = 0,
    this.opacity = 1,
    this.blurAmount = 0,
  });

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
    this.surfaceTransform,
    required this.canvasSize,
    required this.child,
  });

  final MotionVideoPreviewTransform? transform;
  final MotionVideoPreviewSurfaceTransform? surfaceTransform;
  final MotionSize2D canvasSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final transform = this.transform;
    final surfaceTransform = this.surfaceTransform;
    if ((transform == null || transform.isIdentity) &&
        (surfaceTransform == null || surfaceTransform.isIdentity)) {
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
        Widget transformed = child;
        if (transform != null && !transform.isIdentity) {
          transformed = _applyTransform(
            transformed,
            positionX: transform.positionX,
            positionY: transform.positionY,
            scaleX: transform.scaleX,
            scaleY: transform.scaleY,
            rotationDegrees: transform.rotationDegrees,
            opacity: transform.opacity,
            blurAmount: transform.blurAmount,
            viewportScaleX: scaleX,
            viewportScaleY: scaleY,
          );
        }
        if (surfaceTransform != null && !surfaceTransform.isIdentity) {
          transformed = _applyTransform(
            transformed,
            positionX: surfaceTransform.positionX,
            positionY: surfaceTransform.positionY,
            scaleX: surfaceTransform.scaleX,
            scaleY: surfaceTransform.scaleY,
            rotationDegrees: surfaceTransform.rotationDegrees,
            opacity: surfaceTransform.opacity,
            blurAmount: surfaceTransform.blurAmount,
            viewportScaleX: scaleX,
            viewportScaleY: scaleY,
          );
        }
        return transformed;
      },
    );
  }

  Widget _applyTransform(
    Widget child, {
    required double positionX,
    required double positionY,
    required double scaleX,
    required double scaleY,
    required double rotationDegrees,
    required double opacity,
    required double blurAmount,
    required double viewportScaleX,
    required double viewportScaleY,
  }) {
    Widget transformed = ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: blurAmount * viewportScaleX,
        sigmaY: blurAmount * viewportScaleY,
      ),
      enabled: blurAmount > 0,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0).toDouble(),
        child: child,
      ),
    );
    transformed = Transform.scale(
      scaleX: scaleX,
      scaleY: scaleY,
      child: transformed,
    );
    transformed = Transform.rotate(
      angle: rotationDegrees * math.pi / 180,
      child: transformed,
    );
    transformed = Transform.translate(
      offset: Offset(
        positionX * viewportScaleX,
        positionY * viewportScaleY,
      ),
      child: transformed,
    );
    return ClipRect(child: transformed);
  }
}
