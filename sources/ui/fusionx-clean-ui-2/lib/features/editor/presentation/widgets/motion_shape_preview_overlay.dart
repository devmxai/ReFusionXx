import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/professional_motion_evaluation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import 'preview_stage.dart';

class MotionShapePreviewOverlay extends StatelessWidget {
  const MotionShapePreviewOverlay({
    super.key,
    required this.snapshot,
    required this.canvasSize,
  });

  final MotionEvaluationSnapshot snapshot;
  final MotionSize2D canvasSize;

  static bool hasVisibleShapes(MotionEvaluationSnapshot snapshot) {
    return _shapeNodes(snapshot).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _shapeNodes(snapshot);
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stageViewport = PreviewStageCanvasViewport.maybeOf(context);
          final canvasRect = stageViewport?.canvasRect ??
              Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight);
          final viewportWidth = canvasRect.width;
          final viewportHeight = canvasRect.height;
          if (constraints.maxWidth <= 0 ||
              constraints.maxHeight <= 0 ||
              viewportWidth <= 0 ||
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
              Positioned.fromRect(
                rect: canvasRect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    stageViewport?.canvasBorderRadius ?? 0,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      for (final node in nodes)
                        _MotionShapePreviewNodeWidget(
                          key: ValueKey<String>(node.id),
                          node: node,
                          viewportWidth: viewportWidth,
                          viewportHeight: viewportHeight,
                          scaleX: scaleX,
                          scaleY: scaleY,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<_MotionShapePreviewNode> _shapeNodes(
    MotionEvaluationSnapshot snapshot,
  ) {
    final nodes = <_MotionShapePreviewNode>[];
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
          if (element.kind != MotionElementKind.shape ||
              element.activationState != MotionActivationState.active) {
            continue;
          }
          final properties = _propertiesById(element.properties);
          final opacity =
              _scalar(properties, MotionPropertyCatalog.opacity.id, 1) *
                  layerOpacity;
          if (opacity <= 0) {
            continue;
          }
          nodes.add(
            _MotionShapePreviewNode(
              id: element.id,
              order: order++,
              zIndex: layer.zIndex,
              shapeKind: element.shapeKind ?? MotionShapeKind.rectangle,
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
              width: _shapeWidthFor(element, properties),
              height: _shapeHeightFor(element, properties),
              scaleX: _scalar(properties, MotionPropertyCatalog.scaleX.id, 1),
              scaleY: _scalar(properties, MotionPropertyCatalog.scaleY.id, 1),
              rotationDegrees: _scalar(
                properties,
                MotionPropertyCatalog.rotationDegrees.id,
                0,
              ),
              opacity: opacity.clamp(0.0, 1.0).toDouble(),
              color: _color(properties, const Color(0xFFFFFFFF)),
              borderColor: _colorById(
                properties,
                'visual.borderColor',
                const Color(0x00000000),
              ),
              borderWidth: math.max(
                0.0,
                _scalar(properties, 'visual.borderWidth', 0.0),
              ),
              cornerRadius: _scalar(
                properties,
                MotionPropertyCatalog.cornerRadius.id,
                0,
              ),
              trimStart: _trimProgress(
                properties,
                MotionPropertyCatalog.trimStart.id,
                0,
              ),
              trimEnd: _trimProgress(
                properties,
                MotionPropertyCatalog.trimEnd.id,
                1,
              ),
              trimOffset: _trimOffset(
                properties,
                MotionPropertyCatalog.trimOffset.id,
                0,
              ),
              shadow: _shadow(properties, opacity),
              iconId: _string(properties, 'asset.icon'),
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

  static double _shapeWidthFor(
    MotionEvaluatedElementState element,
    Map<String, MotionPropertyValue> properties,
  ) {
    final fallback = switch (element.shapeKind) {
      MotionShapeKind.circle => 160.0,
      MotionShapeKind.line => 420.0,
      _ => 240.0,
    };
    return math.max(
      0.0,
      _scalar(properties, MotionPropertyCatalog.width.id, fallback),
    );
  }

  static double _shapeHeightFor(
    MotionEvaluatedElementState element,
    Map<String, MotionPropertyValue> properties,
  ) {
    final fallback = switch (element.shapeKind) {
      MotionShapeKind.circle => 160.0,
      MotionShapeKind.line => 8.0,
      _ => 160.0,
    };
    return math.max(
      0.0,
      _scalar(properties, MotionPropertyCatalog.height.id, fallback),
    );
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

  static double _trimProgress(
    Map<String, MotionPropertyValue> properties,
    String id,
    double fallback,
  ) {
    return _normalizeTrimProgress(_scalar(properties, id, fallback));
  }

  static double _trimOffset(
    Map<String, MotionPropertyValue> properties,
    String id,
    double fallback,
  ) {
    final raw = _scalar(properties, id, fallback);
    final unit = raw.abs() > 1 ? raw / 100 : raw;
    if (!unit.isFinite) {
      return 0;
    }
    return unit % 1.0;
  }

  static double _normalizeTrimProgress(double raw) {
    final unit = raw.abs() > 1 ? raw / 100 : raw;
    if (!unit.isFinite) {
      return 0;
    }
    return unit.clamp(0.0, 1.0).toDouble();
  }

  static Color _color(
    Map<String, MotionPropertyValue> properties,
    Color fallback,
  ) {
    return _colorById(properties, 'visual.color', fallback);
  }

  static Color _colorById(
    Map<String, MotionPropertyValue> properties,
    String id,
    Color fallback,
  ) {
    final rawValue = properties[id]?.rawValue;
    if (rawValue is int) {
      return Color(rawValue);
    }
    return fallback;
  }

  static _MotionShapePreviewShadow? _shadow(
    Map<String, MotionPropertyValue> properties,
    double elementOpacity,
  ) {
    final opacity = (_scalar(
              properties,
              MotionPropertyCatalog.shadowOpacity.id,
              0,
            ) *
            elementOpacity)
        .clamp(0.0, 1.0)
        .toDouble();
    final blur = math.max(
      0.0,
      _scalar(properties, MotionPropertyCatalog.shadowBlur.id, 0),
    );
    final spread = _scalar(
      properties,
      MotionPropertyCatalog.shadowSpread.id,
      0,
    );
    final offsetX = _scalar(
      properties,
      MotionPropertyCatalog.shadowOffsetX.id,
      0,
    );
    final offsetY = _scalar(
      properties,
      MotionPropertyCatalog.shadowOffsetY.id,
      0,
    );
    if (opacity <= 0 &&
        blur <= 0 &&
        spread == 0 &&
        offsetX == 0 &&
        offsetY == 0) {
      return null;
    }
    return _MotionShapePreviewShadow(
      color: _colorById(
        properties,
        MotionPropertyCatalog.shadowColor.id,
        const Color(0xFF000000),
      ),
      opacity: opacity,
      blur: blur,
      offsetX: offsetX,
      offsetY: offsetY,
      spread: spread,
    );
  }

  static String? _string(
    Map<String, MotionPropertyValue> properties,
    String id,
  ) {
    final rawValue = properties[id]?.rawValue;
    if (rawValue is String && rawValue.trim().isNotEmpty) {
      return rawValue.trim();
    }
    return null;
  }
}

class _MotionShapePreviewNode {
  const _MotionShapePreviewNode({
    required this.id,
    required this.order,
    required this.zIndex,
    required this.shapeKind,
    required this.positionX,
    required this.positionY,
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDegrees,
    required this.opacity,
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.cornerRadius,
    required this.trimStart,
    required this.trimEnd,
    required this.trimOffset,
    this.shadow,
    this.iconId,
  });

  final String id;
  final int order;
  final int zIndex;
  final MotionShapeKind shapeKind;
  final double positionX;
  final double positionY;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;
  final double opacity;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;
  final double trimStart;
  final double trimEnd;
  final double trimOffset;
  final _MotionShapePreviewShadow? shadow;
  final String? iconId;
}

class _MotionShapePreviewShadow {
  const _MotionShapePreviewShadow({
    required this.color,
    required this.opacity,
    required this.blur,
    required this.offsetX,
    required this.offsetY,
    required this.spread,
  });

  final Color color;
  final double opacity;
  final double blur;
  final double offsetX;
  final double offsetY;
  final double spread;

  List<BoxShadow> toBoxShadows({
    required double scaleX,
    required double scaleY,
  }) {
    final effectiveOpacity = (color.opacity * opacity).clamp(0.0, 1.0);
    if (effectiveOpacity <= 0) {
      return const <BoxShadow>[];
    }
    final scale = math.min(scaleX, scaleY);
    return <BoxShadow>[
      BoxShadow(
        color: color.withOpacity(effectiveOpacity.toDouble()),
        offset: Offset(offsetX * scaleX, offsetY * scaleY),
        blurRadius: math.max(0.0, blur * scale),
        spreadRadius: spread * scale,
      ),
    ];
  }
}

class _MotionShapePreviewNodeWidget extends StatelessWidget {
  const _MotionShapePreviewNodeWidget({
    super.key,
    required this.node,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.scaleX,
    required this.scaleY,
  });

  final _MotionShapePreviewNode node;
  final double viewportWidth;
  final double viewportHeight;
  final double scaleX;
  final double scaleY;

  @override
  Widget build(BuildContext context) {
    final geometry = _effectiveGeometryForNode(node);
    final width = math.max(0.0, geometry.width * scaleX);
    final height = math.max(0.0, geometry.height * scaleY);
    if (width <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }

    final centerX =
        viewportWidth / 2 + ((node.positionX + geometry.offsetX) * scaleX);
    final centerY = viewportHeight / 2 + (node.positionY * scaleY);
    final colorOpacity = node.color.opacity;
    final decorationColor = node.color.withOpacity(
      (colorOpacity * node.opacity).clamp(0.0, 1.0).toDouble(),
    );
    final effectiveBorderOpacity =
        (node.borderColor.opacity * node.opacity).clamp(0.0, 1.0).toDouble();
    final effectiveBorderColor = node.borderColor.withOpacity(
      effectiveBorderOpacity,
    );
    final effectiveBorderWidth = node.borderWidth * math.min(scaleX, scaleY);
    final decoration = _decorationFor(
      shapeKind: node.shapeKind,
      color: decorationColor,
      width: width,
      height: height,
      cornerRadius: node.cornerRadius * math.min(scaleX, scaleY),
      borderColor: effectiveBorderColor,
      borderWidth: effectiveBorderWidth,
      boxShadow: node.shadow
          ?.toBoxShadows(
            scaleX: scaleX,
            scaleY: scaleY,
          )
          .where((shadow) => shadow.color.opacity > 0)
          .toList(growable: false),
    );
    final iconData = _iconDataFor(node.iconId);

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
          child: iconData == null
              ? DecoratedBox(decoration: decoration)
              : FittedBox(
                  fit: BoxFit.contain,
                  child: Icon(iconData, color: decorationColor),
                ),
        ),
      ),
    );
  }

  _MotionShapePreviewGeometry _effectiveGeometryForNode(
    _MotionShapePreviewNode node,
  ) {
    if (node.shapeKind != MotionShapeKind.line) {
      return _MotionShapePreviewGeometry(
        width: node.width,
        height: node.height,
      );
    }
    final rawLength = (node.trimEnd - node.trimStart).clamp(0.0, 1.0);
    final length = rawLength.toDouble();
    if (length <= 0) {
      return const _MotionShapePreviewGeometry(width: 0, height: 0);
    }
    final clampedStart =
        (node.trimStart + node.trimOffset).clamp(0.0, 1.0 - length).toDouble();
    final visibleWidth = node.width * length;
    return _MotionShapePreviewGeometry(
      width: visibleWidth,
      height: node.height,
      offsetX: ((clampedStart + (length / 2)) - 0.5) * node.width,
    );
  }

  IconData? _iconDataFor(String? iconId) {
    return switch (iconId) {
      'arrow-down' => Icons.arrow_downward_rounded,
      'arrow-left' => Icons.arrow_back_rounded,
      'arrow-right' => Icons.arrow_forward_rounded,
      'arrow-up' => Icons.arrow_upward_rounded,
      'bookmark' => Icons.bookmark_border_rounded,
      'camera' => Icons.photo_camera_outlined,
      'check' => Icons.check_rounded,
      'chevron-left' => Icons.chevron_left_rounded,
      'chevron-right' => Icons.chevron_right_rounded,
      'close' => Icons.close_rounded,
      'comment' => Icons.mode_comment_outlined,
      'crop' => Icons.crop_rounded,
      'heart' => Icons.favorite_border_rounded,
      'image' => Icons.image_outlined,
      'lock' => Icons.lock_outline_rounded,
      'mic' => Icons.mic_none_rounded,
      'music' => Icons.music_note_rounded,
      'paperclip' => Icons.attach_file_rounded,
      'pause' => Icons.pause_rounded,
      'play' => Icons.play_arrow_rounded,
      'plus' => Icons.add_rounded,
      'search' => Icons.search_rounded,
      'send' => Icons.arrow_upward_rounded,
      'settings' => Icons.tune_rounded,
      'share' => Icons.send_outlined,
      'sparkles' => Icons.auto_awesome_rounded,
      'text' => Icons.text_fields_rounded,
      'user' => Icons.person_outline_rounded,
      'verified' => Icons.verified_rounded,
      'video' => Icons.videocam_outlined,
      'volume' => Icons.graphic_eq_rounded,
      _ => null,
    };
  }

  BoxDecoration _decorationFor({
    required MotionShapeKind shapeKind,
    required Color color,
    required double width,
    required double height,
    required double cornerRadius,
    required Color borderColor,
    required double borderWidth,
    List<BoxShadow>? boxShadow,
  }) {
    final border = borderWidth > 0 && borderColor.opacity > 0
        ? Border.all(color: borderColor, width: borderWidth)
        : null;
    switch (shapeKind) {
      case MotionShapeKind.circle:
        return BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border,
          boxShadow: boxShadow,
        );
      case MotionShapeKind.line:
      case MotionShapeKind.roundedRectangle:
        return BoxDecoration(
          color: color,
          border: border,
          borderRadius: BorderRadius.circular(
            cornerRadius > 0 ? cornerRadius : math.min(width, height) / 2,
          ),
          boxShadow: boxShadow,
        );
      case MotionShapeKind.rectangle:
      case MotionShapeKind.mask:
      case MotionShapeKind.customPath:
        return BoxDecoration(
          color: color,
          border: border,
          borderRadius: cornerRadius > 0
              ? BorderRadius.circular(cornerRadius)
              : BorderRadius.zero,
          boxShadow: boxShadow,
        );
    }
  }
}

class _MotionShapePreviewGeometry {
  const _MotionShapePreviewGeometry({
    required this.width,
    required this.height,
    this.offsetX = 0,
  });

  final double width;
  final double height;
  final double offsetX;
}
