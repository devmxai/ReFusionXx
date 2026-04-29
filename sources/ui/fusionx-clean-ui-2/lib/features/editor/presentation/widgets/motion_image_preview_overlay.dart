import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/professional_motion_compilation_models.dart';
import '../../domain/models/professional_motion_evaluation_models.dart';
import '../../domain/models/professional_motion_models.dart';

class MotionImagePreviewAsset {
  const MotionImagePreviewAsset({
    required this.assetId,
    this.sourceUri,
    this.thumbnailBytes,
    this.width,
    this.height,
  });

  final String assetId;
  final String? sourceUri;
  final Uint8List? thumbnailBytes;
  final int? width;
  final int? height;

  bool get hasFilePath {
    final sourceUri = this.sourceUri;
    return sourceUri != null &&
        sourceUri.isNotEmpty &&
        !sourceUri.startsWith('content://');
  }
}

typedef MotionImagePreviewAssetResolver = MotionImagePreviewAsset? Function(
  String assetId,
);

class MotionImagePreviewOverlay extends StatelessWidget {
  const MotionImagePreviewOverlay({
    super.key,
    required this.composition,
    required this.snapshot,
    required this.canvasSize,
    required this.assetResolver,
  });

  final MotionNormalizedComposition composition;
  final MotionEvaluationSnapshot snapshot;
  final MotionSize2D canvasSize;
  final MotionImagePreviewAssetResolver assetResolver;

  static bool hasVisibleImages({
    required MotionNormalizedComposition composition,
    required MotionEvaluationSnapshot snapshot,
    required MotionImagePreviewAssetResolver assetResolver,
  }) {
    return _imageNodes(
      composition: composition,
      snapshot: snapshot,
      canvasSize: composition.format.canvasSize,
      assetResolver: assetResolver,
    ).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _imageNodes(
      composition: composition,
      snapshot: snapshot,
      canvasSize: canvasSize,
      assetResolver: assetResolver,
    );
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final viewportHeight = constraints.maxHeight;
          if (viewportWidth <= 0 ||
              viewportHeight <= 0 ||
              canvasSize.width <= 0 ||
              canvasSize.height <= 0) {
            return const SizedBox.shrink();
          }
          final scaleX = viewportWidth / canvasSize.width;
          final scaleY = viewportHeight / canvasSize.height;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              for (final node in nodes)
                _MotionImagePreviewNodeWidget(
                  key: ValueKey<String>(node.id),
                  node: node,
                  viewportWidth: viewportWidth,
                  viewportHeight: viewportHeight,
                  scaleX: scaleX,
                  scaleY: scaleY,
                ),
            ],
          );
        },
      ),
    );
  }

  static List<_MotionImagePreviewNode> _imageNodes({
    required MotionNormalizedComposition composition,
    required MotionEvaluationSnapshot snapshot,
    required MotionSize2D canvasSize,
    required MotionImagePreviewAssetResolver assetResolver,
  }) {
    final sourceByElementId = <String, MotionElementSourceBinding>{};
    for (final scene in composition.scenes) {
      for (final layer in scene.layers) {
        for (final element in layer.elements) {
          final sourceBinding = element.sourceBinding;
          if (element.kind == MotionElementKind.image &&
              sourceBinding != null) {
            sourceByElementId[element.id] = sourceBinding;
          }
        }
      }
    }

    final nodes = <_MotionImagePreviewNode>[];
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
          if (element.kind != MotionElementKind.image ||
              element.activationState != MotionActivationState.active) {
            continue;
          }
          final sourceBinding = sourceByElementId[element.id];
          final assetId = sourceBinding?.assetId ?? sourceBinding?.sourceId;
          if (assetId == null || assetId.isEmpty) {
            continue;
          }
          final asset = assetResolver(assetId);
          if (asset == null) {
            continue;
          }
          final properties = _propertiesById(element.properties);
          final opacity =
              _scalar(properties, MotionPropertyCatalog.opacity.id, 1) *
                  layerOpacity;
          if (opacity <= 0) {
            continue;
          }
          final size = _resolveImageSize(
            properties: properties,
            asset: asset,
            canvasSize: canvasSize,
          );
          if (size.width <= 0 || size.height <= 0) {
            continue;
          }
          nodes.add(
            _MotionImagePreviewNode(
              id: element.id,
              order: order++,
              zIndex: layer.zIndex,
              asset: asset,
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
              width: size.width,
              height: size.height,
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
          );
        }
      }
    }

    nodes.sort((a, b) {
      final zIndex = a.zIndex.compareTo(b.zIndex);
      if (zIndex != 0) {
        return zIndex;
      }
      return a.order.compareTo(b.order);
    });
    return nodes;
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

  static double? _scalarOrNull(
    Map<String, MotionPropertyValue> properties,
    String id,
  ) {
    final rawValue = properties[id]?.rawValue;
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    return null;
  }

  static Size _resolveImageSize({
    required Map<String, MotionPropertyValue> properties,
    required MotionImagePreviewAsset asset,
    required MotionSize2D canvasSize,
  }) {
    final explicitWidth = _scalarOrNull(
      properties,
      MotionPropertyCatalog.width.id,
    );
    final explicitHeight = _scalarOrNull(
      properties,
      MotionPropertyCatalog.height.id,
    );
    if (explicitWidth != null &&
        explicitWidth > 0 &&
        explicitHeight != null &&
        explicitHeight > 0) {
      return Size(explicitWidth, explicitHeight);
    }

    final sourceWidth = asset.width?.toDouble();
    final sourceHeight = asset.height?.toDouble();
    if (sourceWidth != null &&
        sourceWidth > 0 &&
        sourceHeight != null &&
        sourceHeight > 0) {
      final fitScale = math.min(
        canvasSize.width / sourceWidth,
        canvasSize.height / sourceHeight,
      );
      return Size(sourceWidth * fitScale, sourceHeight * fitScale);
    }

    final fallbackWidth = canvasSize.width * 0.72;
    final fallbackHeight = canvasSize.height * 0.72;
    return Size(fallbackWidth, fallbackHeight);
  }
}

class _MotionImagePreviewNode {
  const _MotionImagePreviewNode({
    required this.id,
    required this.order,
    required this.zIndex,
    required this.asset,
    required this.positionX,
    required this.positionY,
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDegrees,
    required this.opacity,
    required this.blurAmount,
  });

  final String id;
  final int order;
  final int zIndex;
  final MotionImagePreviewAsset asset;
  final double positionX;
  final double positionY;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;
  final double opacity;
  final double blurAmount;
}

class _MotionImagePreviewNodeWidget extends StatelessWidget {
  const _MotionImagePreviewNodeWidget({
    super.key,
    required this.node,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.scaleX,
    required this.scaleY,
  });

  final _MotionImagePreviewNode node;
  final double viewportWidth;
  final double viewportHeight;
  final double scaleX;
  final double scaleY;

  @override
  Widget build(BuildContext context) {
    final width = math.max(0.0, node.width * scaleX);
    final height = math.max(0.0, node.height * scaleY);
    if (width <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }
    final image = _buildImage();
    if (image == null) {
      return const SizedBox.shrink();
    }

    final centerX = viewportWidth / 2 + (node.positionX * scaleX);
    final centerY = viewportHeight / 2 + (node.positionY * scaleY);
    final child = ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: node.blurAmount * scaleX,
          sigmaY: node.blurAmount * scaleY,
        ),
        enabled: node.blurAmount > 0,
        child: Opacity(
          opacity: node.opacity,
          child: image,
        ),
      ),
    );

    return Positioned(
      left: centerX - (width / 2),
      top: centerY - (height / 2),
      width: width,
      height: height,
      child: Transform.rotate(
        angle: node.rotationDegrees * math.pi / 180,
        child: Transform.scale(
          scaleX: node.scaleX,
          scaleY: node.scaleY,
          child: child,
        ),
      ),
    );
  }

  Widget? _buildImage() {
    final bytes = node.asset.thumbnailBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }
    final sourceUri = node.asset.sourceUri;
    if (sourceUri == null || sourceUri.isEmpty || !node.asset.hasFilePath) {
      return null;
    }
    return Image.file(
      File(_filePathForUri(sourceUri)),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }

  String _filePathForUri(String sourceUri) {
    if (sourceUri.startsWith('file://')) {
      return Uri.parse(sourceUri).toFilePath();
    }
    return sourceUri;
  }
}
