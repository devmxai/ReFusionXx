import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/models/professional_motion_models.dart';

typedef UnifiedCanvasNodeMoveCallback = void Function(
  String elementId,
  Offset deltaCanvas,
);

typedef UnifiedCanvasNodeScaleCallback = void Function(
  String elementId,
  double nextScaleX,
  double nextScaleY,
);

typedef UnifiedCanvasNodeRotationCallback = void Function(
  String elementId,
  double nextRotationDegrees,
);

enum UnifiedCanvasTransformNodeKind {
  text,
  shape,
  image,
  video,
}

@immutable
class UnifiedCanvasTransformSnapshot {
  UnifiedCanvasTransformSnapshot({
    required this.canvasSize,
    required List<UnifiedCanvasTransformNode> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final MotionSize2D canvasSize;
  final List<UnifiedCanvasTransformNode> nodes;

  bool get isEmpty => nodes.isEmpty;
}

@immutable
class UnifiedCanvasTransformNode {
  const UnifiedCanvasTransformNode({
    required this.id,
    required this.layerId,
    required this.kind,
    required this.positionX,
    required this.positionY,
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
    required this.rotationDegrees,
    required this.opacity,
    required this.zIndex,
  });

  final String id;
  final String layerId;
  final UnifiedCanvasTransformNodeKind kind;
  final double positionX;
  final double positionY;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;
  final double rotationDegrees;
  final double opacity;
  final int zIndex;
}

class UnifiedCanvasTransformOverlay extends StatelessWidget {
  const UnifiedCanvasTransformOverlay({
    super.key,
    required this.snapshot,
    required this.selectedElementId,
    required this.isInteractive,
    required this.onNodeSelected,
    required this.onNodeEditRequested,
    required this.onNodeMoved,
    required this.onNodeScaleChanged,
    required this.onNodeRotationChanged,
  });

  final UnifiedCanvasTransformSnapshot snapshot;
  final String? selectedElementId;
  final bool isInteractive;
  final ValueChanged<String> onNodeSelected;
  final ValueChanged<String> onNodeEditRequested;
  final UnifiedCanvasNodeMoveCallback onNodeMoved;
  final UnifiedCanvasNodeScaleCallback onNodeScaleChanged;
  final UnifiedCanvasNodeRotationCallback onNodeRotationChanged;

  @override
  Widget build(BuildContext context) {
    if (snapshot.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final layouts = _buildLayouts(constraints);
        final effectiveSelectedElementId = selectedElementId ??
            (layouts.length == 1 ? layouts.single.node.id : null);
        final selectedLayout = effectiveSelectedElementId == null
            ? null
            : layouts.cast<_UnifiedCanvasNodeLayout?>().firstWhere(
                  (layout) =>
                      layout?.node.id == effectiveSelectedElementId ||
                      layout?.node.layerId == effectiveSelectedElementId,
                  orElse: () => null,
                );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (selectedLayout != null)
              _SelectedNodeTransformBox(
                key: const ValueKey<String>(
                  'unifiedCanvasTransformSelectionBox',
                ),
                layout: selectedLayout,
                isInteractive: isInteractive,
                onNodeMoved: onNodeMoved,
                onNodeScaleChanged: onNodeScaleChanged,
                onNodeRotationChanged: onNodeRotationChanged,
              ),
          ],
        );
      },
    );
  }

  List<_UnifiedCanvasNodeLayout> _buildLayouts(BoxConstraints constraints) {
    final canvasWidth = snapshot.canvasSize.width <= 0
        ? constraints.maxWidth
        : snapshot.canvasSize.width;
    final canvasHeight = snapshot.canvasSize.height <= 0
        ? constraints.maxHeight
        : snapshot.canvasSize.height;
    final stageScaleX =
        canvasWidth == 0 ? 1.0 : (constraints.maxWidth / canvasWidth);
    final stageScaleY =
        canvasHeight == 0 ? 1.0 : (constraints.maxHeight / canvasHeight);
    final stageCenter = Offset(
      constraints.maxWidth / 2,
      constraints.maxHeight / 2,
    );
    final layouts = <_UnifiedCanvasNodeLayout>[
      for (final node in snapshot.nodes)
        if (node.opacity > 0 && node.width > 0 && node.height > 0)
          _UnifiedCanvasNodeLayout.measure(
            node: node,
            stageCenter: stageCenter,
            stageScaleX: stageScaleX,
            stageScaleY: stageScaleY,
          ),
    ];
    layouts.sort((left, right) {
      final zOrder = left.node.zIndex.compareTo(right.node.zIndex);
      if (zOrder != 0) {
        return zOrder;
      }
      return left.node.id.compareTo(right.node.id);
    });
    return layouts;
  }
}

class _SelectedNodeTransformBox extends StatefulWidget {
  const _SelectedNodeTransformBox({
    super.key,
    required this.layout,
    required this.isInteractive,
    required this.onNodeMoved,
    required this.onNodeScaleChanged,
    required this.onNodeRotationChanged,
  });

  final _UnifiedCanvasNodeLayout layout;
  final bool isInteractive;
  final UnifiedCanvasNodeMoveCallback onNodeMoved;
  final UnifiedCanvasNodeScaleCallback onNodeScaleChanged;
  final UnifiedCanvasNodeRotationCallback onNodeRotationChanged;

  @override
  State<_SelectedNodeTransformBox> createState() =>
      _SelectedNodeTransformBoxState();
}

class _SelectedNodeTransformBoxState extends State<_SelectedNodeTransformBox> {
  static const double _selectionPadding = 8;
  static const double _handleSize = 10;
  static const double _handleHitSize = 30;
  static const double _stemLength = 16;

  int _activePointerCount = 0;
  double? _rotationGestureStartAngle;
  double? _rotationGestureStartDegrees;

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final selectionRect = layout.localRect.inflate(_selectionPadding);
    final chromeOpacity = widget.isInteractive ? 1.0 : 0.44;
    final cornerPoints = <Offset>[
      layout.transformLocalPoint(selectionRect.topLeft),
      layout.transformLocalPoint(selectionRect.topRight),
      layout.transformLocalPoint(selectionRect.bottomRight),
      layout.transformLocalPoint(selectionRect.bottomLeft),
    ];
    final topCenter = layout.transformLocalPoint(
      Offset(selectionRect.center.dx, selectionRect.top),
    );
    final bottomCenter = layout.transformLocalPoint(
      Offset(selectionRect.center.dx, selectionRect.bottom),
    );
    final rotationHandlePoint = layout.transformLocalPoint(
      Offset(selectionRect.center.dx, selectionRect.top - _stemLength),
    );
    final moveHandlePoint = layout.transformLocalPoint(
      Offset(selectionRect.center.dx, selectionRect.bottom + _stemLength),
    );
    final pivotDotPoint = layout.transformLocalPoint(
      Offset(
          selectionRect.center.dx, selectionRect.bottom + (_stemLength * 0.34)),
    );

    return Listener(
      onPointerDown: (_) {
        _activePointerCount += 1;
      },
      onPointerUp: (_) {
        _activePointerCount = (_activePointerCount - 1).clamp(0, 1000);
      },
      onPointerCancel: (_) {
        _activePointerCount = (_activePointerCount - 1).clamp(0, 1000);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SelectionChromePainter(
                borderPoints: cornerPoints,
                topCenter: topCenter,
                bottomCenter: bottomCenter,
                rotationHandlePoint: rotationHandlePoint,
                moveHandlePoint: moveHandlePoint,
                pivotDotPoint: pivotDotPoint,
                opacity: chromeOpacity,
              ),
            ),
          ),
          for (final handle in _ResizeHandle.values)
            _buildResizeHandle(
              handle: handle,
              point: layout.transformLocalPoint(
                handle.localPointForRect(selectionRect),
              ),
            ),
          _buildMoveHandle(point: moveHandlePoint),
          _buildRotationHandle(point: rotationHandlePoint),
        ],
      ),
    );
  }

  Widget _buildResizeHandle({
    required _ResizeHandle handle,
    required Offset point,
  }) {
    return Positioned(
      left: point.dx - (_handleHitSize / 2),
      top: point.dy - (_handleHitSize / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onPanUpdate: widget.isInteractive
            ? (details) {
                if (_activePointerCount > 1) {
                  return;
                }
                final localDelta = widget.layout.projectScreenDeltaToLocal(
                  details.delta,
                );
                final baseWidth = math.max(1.0, widget.layout.localRect.width);
                final baseHeight =
                    math.max(1.0, widget.layout.localRect.height);
                var nextScaleX = widget.layout.node.scaleX;
                var nextScaleY = widget.layout.node.scaleY;
                if (handle.affectsHorizontal) {
                  nextScaleX = (nextScaleX +
                          ((localDelta.dx * handle.dxSign) / baseWidth))
                      .clamp(0.05, 20.0);
                }
                if (handle.affectsVertical) {
                  nextScaleY = (nextScaleY +
                          ((localDelta.dy * handle.dySign) / baseHeight))
                      .clamp(0.05, 20.0);
                }
                widget.onNodeScaleChanged(
                  widget.layout.node.id,
                  nextScaleX,
                  nextScaleY,
                );
              }
            : null,
        child: SizedBox(
          width: _handleHitSize,
          height: _handleHitSize,
          child: Center(
            child: _TransformHandleDot(
              size: _handleSize,
              opacity: widget.isInteractive ? 1.0 : 0.52,
              strokeWidth: 1.15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoveHandle({
    required Offset point,
  }) {
    return Positioned(
      left: point.dx - (_handleHitSize / 2),
      top: point.dy - (_handleHitSize / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onPanUpdate: widget.isInteractive
            ? (details) {
                if (_activePointerCount > 1) {
                  return;
                }
                widget.onNodeMoved(
                  widget.layout.node.id,
                  Offset(
                    details.delta.dx / widget.layout.stageScaleX,
                    details.delta.dy / widget.layout.stageScaleY,
                  ),
                );
              }
            : null,
        child: SizedBox(
          width: _handleHitSize,
          height: _handleHitSize,
          child: Center(
            child: _TransformHandleDot(
              size: _handleSize,
              opacity: widget.isInteractive ? 1.0 : 0.52,
              fillColor: const Color(0xFF4A8FFF),
              strokeWidth: 1.15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotationHandle({
    required Offset point,
  }) {
    return Positioned(
      left: point.dx - (_handleHitSize / 2),
      top: point.dy - (_handleHitSize / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: widget.isInteractive ? _handleRotationStart : null,
        onPanUpdate: widget.isInteractive ? _handleRotationUpdate : null,
        onPanEnd: widget.isInteractive ? (_) => _handleRotationCancel() : null,
        onPanCancel: widget.isInteractive ? _handleRotationCancel : null,
        child: SizedBox(
          width: _handleHitSize,
          height: _handleHitSize,
          child: Center(
            child: _TransformHandleDot(
              size: _handleSize,
              opacity: widget.isInteractive ? 1.0 : 0.52,
              fillColor: const Color(0xFF4A8FFF),
              strokeWidth: 1.15,
            ),
          ),
        ),
      ),
    );
  }

  void _handleRotationStart(DragStartDetails details) {
    if (_activePointerCount > 1) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final centerGlobal = renderBox.localToGlobal(widget.layout.nodeCenter);
    _rotationGestureStartAngle = math.atan2(
      details.globalPosition.dy - centerGlobal.dy,
      details.globalPosition.dx - centerGlobal.dx,
    );
    _rotationGestureStartDegrees = widget.layout.node.rotationDegrees;
  }

  void _handleRotationUpdate(DragUpdateDetails details) {
    if (_activePointerCount > 1) {
      return;
    }
    final startAngle = _rotationGestureStartAngle;
    final startDegrees = _rotationGestureStartDegrees;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (startAngle == null || startDegrees == null || renderBox == null) {
      return;
    }
    final centerGlobal = renderBox.localToGlobal(widget.layout.nodeCenter);
    final currentAngle = math.atan2(
      details.globalPosition.dy - centerGlobal.dy,
      details.globalPosition.dx - centerGlobal.dx,
    );
    final deltaDegrees = (currentAngle - startAngle) * (180 / math.pi);
    widget.onNodeRotationChanged(
      widget.layout.node.id,
      startDegrees + deltaDegrees,
    );
  }

  void _handleRotationCancel() {
    _rotationGestureStartAngle = null;
    _rotationGestureStartDegrees = null;
  }
}

class _TransformHandleDot extends StatelessWidget {
  const _TransformHandleDot({
    required this.size,
    required this.opacity,
    this.fillColor = const Color(0xFF4A8FFF),
    this.strokeWidth = 1.5,
  });

  final double size;
  final double opacity;
  final Color fillColor;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.94),
            width: strokeWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 6,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionChromePainter extends CustomPainter {
  const _SelectionChromePainter({
    required this.borderPoints,
    required this.topCenter,
    required this.bottomCenter,
    required this.rotationHandlePoint,
    required this.moveHandlePoint,
    required this.pivotDotPoint,
    required this.opacity,
  });

  final List<Offset> borderPoints;
  final Offset topCenter;
  final Offset bottomCenter;
  final Offset rotationHandlePoint;
  final Offset moveHandlePoint;
  final Offset pivotDotPoint;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (borderPoints.length != 4) {
      return;
    }
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.74 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final stemPaint = Paint()
      ..color = Colors.white.withOpacity(0.54 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;
    final pivotPaint = Paint()
      ..color = const Color(0xFF47E082).withOpacity(0.94 * opacity)
      ..style = PaintingStyle.fill;

    final borderPath = Path()
      ..moveTo(borderPoints[0].dx, borderPoints[0].dy)
      ..lineTo(borderPoints[1].dx, borderPoints[1].dy)
      ..lineTo(borderPoints[2].dx, borderPoints[2].dy)
      ..lineTo(borderPoints[3].dx, borderPoints[3].dy)
      ..close();
    canvas.drawPath(borderPath, borderPaint);
    canvas.drawLine(topCenter, rotationHandlePoint, stemPaint);
    canvas.drawLine(bottomCenter, moveHandlePoint, stemPaint);
    canvas.drawCircle(pivotDotPoint, 4, pivotPaint);
  }

  @override
  bool shouldRepaint(covariant _SelectionChromePainter oldDelegate) {
    return oldDelegate.borderPoints != borderPoints ||
        oldDelegate.topCenter != topCenter ||
        oldDelegate.bottomCenter != bottomCenter ||
        oldDelegate.rotationHandlePoint != rotationHandlePoint ||
        oldDelegate.moveHandlePoint != moveHandlePoint ||
        oldDelegate.pivotDotPoint != pivotDotPoint ||
        oldDelegate.opacity != opacity;
  }
}

enum _ResizeHandle {
  topLeft(true, true, -1, -1),
  topRight(true, true, 1, -1),
  bottomLeft(true, true, -1, 1),
  bottomRight(true, true, 1, 1);

  const _ResizeHandle(
    this.affectsHorizontal,
    this.affectsVertical,
    this.dxSign,
    this.dySign,
  );

  final bool affectsHorizontal;
  final bool affectsVertical;
  final double dxSign;
  final double dySign;

  Offset localPointForRect(Rect rect) {
    switch (this) {
      case _ResizeHandle.topLeft:
        return rect.topLeft;
      case _ResizeHandle.topRight:
        return rect.topRight;
      case _ResizeHandle.bottomLeft:
        return rect.bottomLeft;
      case _ResizeHandle.bottomRight:
        return rect.bottomRight;
    }
  }
}

class _UnifiedCanvasNodeLayout {
  const _UnifiedCanvasNodeLayout({
    required this.node,
    required this.stageScaleX,
    required this.stageScaleY,
    required this.nodeCenter,
    required this.localRect,
    required this.axisAlignedBounds,
  });

  factory _UnifiedCanvasNodeLayout.measure({
    required UnifiedCanvasTransformNode node,
    required Offset stageCenter,
    required double stageScaleX,
    required double stageScaleY,
  }) {
    final localRect = Rect.fromCenter(
      center: Offset.zero,
      width: math.max(1, node.width * stageScaleX),
      height: math.max(1, node.height * stageScaleY),
    );
    final nodeCenter = Offset(
      stageCenter.dx + (node.positionX * stageScaleX),
      stageCenter.dy + (node.positionY * stageScaleY),
    );
    final axisAlignedBounds = _axisAlignedBounds(
      localRect: localRect,
      center: nodeCenter,
      scaleX: node.scaleX,
      scaleY: node.scaleY,
      rotationDegrees: node.rotationDegrees,
    );

    return _UnifiedCanvasNodeLayout(
      node: node,
      stageScaleX: stageScaleX,
      stageScaleY: stageScaleY,
      nodeCenter: nodeCenter,
      localRect: localRect,
      axisAlignedBounds: axisAlignedBounds,
    );
  }

  final UnifiedCanvasTransformNode node;
  final double stageScaleX;
  final double stageScaleY;
  final Offset nodeCenter;
  final Rect localRect;
  final Rect axisAlignedBounds;

  Offset transformLocalPoint(Offset point) {
    final radians = node.rotationDegrees * (math.pi / 180);
    final cosTheta = math.cos(radians);
    final sinTheta = math.sin(radians);
    final scaled = Offset(point.dx * node.scaleX, point.dy * node.scaleY);
    final rotated = Offset(
      (scaled.dx * cosTheta) - (scaled.dy * sinTheta),
      (scaled.dx * sinTheta) + (scaled.dy * cosTheta),
    );
    return nodeCenter + rotated;
  }

  Offset projectScreenDeltaToLocal(Offset screenDelta) {
    final radians = node.rotationDegrees * (math.pi / 180);
    final cosTheta = math.cos(-radians);
    final sinTheta = math.sin(-radians);
    return Offset(
      (screenDelta.dx * cosTheta) - (screenDelta.dy * sinTheta),
      (screenDelta.dx * sinTheta) + (screenDelta.dy * cosTheta),
    );
  }

  static Rect _axisAlignedBounds({
    required Rect localRect,
    required Offset center,
    required double scaleX,
    required double scaleY,
    required double rotationDegrees,
  }) {
    final radians = rotationDegrees * (math.pi / 180);
    final cosTheta = math.cos(radians);
    final sinTheta = math.sin(radians);
    final transformedCorners = <Offset>[
      localRect.topLeft,
      localRect.topRight,
      localRect.bottomLeft,
      localRect.bottomRight,
    ].map((corner) {
      final scaled = Offset(corner.dx * scaleX, corner.dy * scaleY);
      final rotated = Offset(
        (scaled.dx * cosTheta) - (scaled.dy * sinTheta),
        (scaled.dx * sinTheta) + (scaled.dy * cosTheta),
      );
      return center + rotated;
    }).toList(growable: false);

    var minX = transformedCorners.first.dx;
    var maxX = transformedCorners.first.dx;
    var minY = transformedCorners.first.dy;
    var maxY = transformedCorners.first.dy;
    for (final point in transformedCorners.skip(1)) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
