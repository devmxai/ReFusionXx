import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_text_render_models.dart';

typedef MotionTextNodeMoveCallback = void Function(
  String elementId,
  Offset deltaCanvas,
);

typedef MotionTextNodeResizeCallback = void Function(
  String elementId,
  double nextFontSize,
);

class MotionTextTransformOverlay extends StatelessWidget {
  const MotionTextTransformOverlay({
    super.key,
    required this.snapshot,
    required this.selectedElementId,
    required this.isInteractive,
    required this.onNodeSelected,
    required this.onNodeEditRequested,
    required this.onNodeMoved,
    required this.onNodeFontSizeChanged,
  });

  final MotionTextRenderSnapshot snapshot;
  final String? selectedElementId;
  final bool isInteractive;
  final ValueChanged<String> onNodeSelected;
  final ValueChanged<String> onNodeEditRequested;
  final MotionTextNodeMoveCallback onNodeMoved;
  final MotionTextNodeResizeCallback onNodeFontSizeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layouts = _buildLayouts(
          context: context,
          constraints: constraints,
        );
        final selectedLayout = selectedElementId == null
            ? null
            : layouts.cast<_MotionTextNodeLayout?>().firstWhere(
                  (layout) => layout?.node.targetElementId == selectedElementId,
                  orElse: () => null,
                );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (isInteractive)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) {
                    final hit = _hitTest(
                      layouts: layouts,
                      point: details.localPosition,
                    );
                    if (hit == null) {
                      return;
                    }
                    onNodeSelected(hit.node.targetElementId);
                  },
                  onDoubleTapDown: (details) {
                    final hit = _hitTest(
                      layouts: layouts,
                      point: details.localPosition,
                    );
                    if (hit == null) {
                      return;
                    }
                    onNodeSelected(hit.node.targetElementId);
                    onNodeEditRequested(hit.node.targetElementId);
                  },
                ),
              ),
            if (selectedLayout != null)
              _SelectedNodeTransformBox(
                layout: selectedLayout,
                isInteractive: isInteractive,
                onNodeSelected: onNodeSelected,
                onNodeEditRequested: onNodeEditRequested,
                onNodeMoved: onNodeMoved,
                onNodeFontSizeChanged: onNodeFontSizeChanged,
              ),
          ],
        );
      },
    );
  }

  List<_MotionTextNodeLayout> _buildLayouts({
    required BuildContext context,
    required BoxConstraints constraints,
  }) {
    final canvasWidth = snapshot.canvasSize.width <= 0
        ? constraints.maxWidth
        : snapshot.canvasSize.width;
    final canvasHeight = snapshot.canvasSize.height <= 0
        ? constraints.maxHeight
        : snapshot.canvasSize.height;
    final stageScaleX =
        canvasWidth == 0 ? 1.0 : constraints.maxWidth / canvasWidth;
    final stageScaleY =
        canvasHeight == 0 ? 1.0 : constraints.maxHeight / canvasHeight;
    final effectiveScale = math.min(stageScaleX, stageScaleY);
    final stageCenter = Offset(
      constraints.maxWidth / 2,
      constraints.maxHeight / 2,
    );
    final textDirection = Directionality.of(context);

    final layouts = <_MotionTextNodeLayout>[
      for (final node in snapshot.nodes)
        if (node.isActive && node.text.isNotEmpty && node.opacity > 0)
          _MotionTextNodeLayout.measure(
            node: node,
            stageCenter: stageCenter,
            stageScaleX: stageScaleX,
            stageScaleY: stageScaleY,
            effectiveScale: effectiveScale,
            textDirection: textDirection,
          ),
    ];
    layouts.sort((left, right) {
      final zOrder = left.node.zIndex.compareTo(right.node.zIndex);
      if (zOrder != 0) {
        return zOrder;
      }
      return left.node.targetElementId.compareTo(right.node.targetElementId);
    });
    return layouts;
  }

  _MotionTextNodeLayout? _hitTest({
    required List<_MotionTextNodeLayout> layouts,
    required Offset point,
  }) {
    for (final layout in layouts.reversed) {
      if (layout.hitTest(point)) {
        return layout;
      }
    }
    return null;
  }
}

class _SelectedNodeTransformBox extends StatelessWidget {
  const _SelectedNodeTransformBox({
    required this.layout,
    required this.isInteractive,
    required this.onNodeSelected,
    required this.onNodeEditRequested,
    required this.onNodeMoved,
    required this.onNodeFontSizeChanged,
  });

  static const double _selectionPadding = 10;
  static const double _handleSize = 18;

  final _MotionTextNodeLayout layout;
  final bool isInteractive;
  final ValueChanged<String> onNodeSelected;
  final ValueChanged<String> onNodeEditRequested;
  final MotionTextNodeMoveCallback onNodeMoved;
  final MotionTextNodeResizeCallback onNodeFontSizeChanged;

  @override
  Widget build(BuildContext context) {
    final selectionRect = layout.axisAlignedBounds.inflate(_selectionPadding);
    const handleRadius = _handleSize / 2;
    final borderColor = isInteractive
        ? Colors.white.withOpacity(0.88)
        : Colors.white.withOpacity(0.32);

    return Stack(
      children: [
        Positioned.fromRect(
          rect: selectionRect,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: isInteractive
                ? () => onNodeSelected(layout.node.targetElementId)
                : null,
            onDoubleTap: isInteractive
                ? () => onNodeEditRequested(layout.node.targetElementId)
                : null,
            onPanUpdate: isInteractive
                ? (details) {
                    onNodeMoved(
                      layout.node.targetElementId,
                      Offset(
                        details.delta.dx / layout.stageScaleX,
                        details.delta.dy / layout.stageScaleY,
                      ),
                    );
                  }
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.3),
                color: Colors.white.withOpacity(isInteractive ? 0.02 : 0.01),
              ),
            ),
          ),
        ),
        for (final handle in _SelectionHandle.values)
          Positioned(
            left: handle.alignment.x < 0
                ? selectionRect.left - handleRadius
                : selectionRect.right - handleRadius,
            top: handle.alignment.y < 0
                ? selectionRect.top - handleRadius
                : selectionRect.bottom - handleRadius,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: isInteractive
                  ? (details) {
                      final projectedDelta =
                          ((details.delta.dx * handle.dxSign) +
                                  (details.delta.dy * handle.dySign)) /
                              2;
                      final nextFontSize = (layout.node.fontSize +
                              (projectedDelta / layout.effectiveScale))
                          .clamp(12.0, 180.0);
                      onNodeFontSizeChanged(
                        layout.node.targetElementId,
                        nextFontSize,
                      );
                    }
                  : null,
              child: Container(
                width: _handleSize,
                height: _handleSize,
                decoration: BoxDecoration(
                  color: isInteractive
                      ? FxPalette.accent
                      : FxPalette.textFaint.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FxPalette.background.withOpacity(0.9),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _SelectionHandle {
  topLeft(Alignment.topLeft, -1, -1),
  topRight(Alignment.topRight, 1, -1),
  bottomLeft(Alignment.bottomLeft, -1, 1),
  bottomRight(Alignment.bottomRight, 1, 1);

  const _SelectionHandle(this.alignment, this.dxSign, this.dySign);

  final Alignment alignment;
  final double dxSign;
  final double dySign;
}

class _MotionTextNodeLayout {
  const _MotionTextNodeLayout({
    required this.node,
    required this.stageCenter,
    required this.stageScaleX,
    required this.stageScaleY,
    required this.effectiveScale,
    required this.nodeCenter,
    required this.localRect,
    required this.axisAlignedBounds,
  });

  factory _MotionTextNodeLayout.measure({
    required MotionTextRenderNode node,
    required Offset stageCenter,
    required double stageScaleX,
    required double stageScaleY,
    required double effectiveScale,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: node.text,
        style: TextStyle(
          fontSize: node.fontSize * effectiveScale,
          fontWeight: FontWeight.w700,
          letterSpacing: node.letterSpacing * effectiveScale,
          height: 1.0,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    final size = Size(
      math.max(1, painter.width),
      math.max(1, painter.height),
    );
    final localRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    final nodeCenter = Offset(
      stageCenter.dx + (node.canvasOffset.x * stageScaleX),
      stageCenter.dy + (node.canvasOffset.y * stageScaleY),
    );
    final axisAlignedBounds = _axisAlignedBounds(
      localRect: localRect,
      center: nodeCenter,
      scaleX: node.scaleX,
      scaleY: node.scaleY,
      rotationDegrees: node.rotationDegrees,
    );

    return _MotionTextNodeLayout(
      node: node,
      stageCenter: stageCenter,
      stageScaleX: stageScaleX,
      stageScaleY: stageScaleY,
      effectiveScale: effectiveScale,
      nodeCenter: nodeCenter,
      localRect: localRect,
      axisAlignedBounds: axisAlignedBounds,
    );
  }

  final MotionTextRenderNode node;
  final Offset stageCenter;
  final double stageScaleX;
  final double stageScaleY;
  final double effectiveScale;
  final Offset nodeCenter;
  final Rect localRect;
  final Rect axisAlignedBounds;

  bool hitTest(Offset point) {
    final translated = point - nodeCenter;
    final radians = node.rotationDegrees * (math.pi / 180);
    final cosTheta = math.cos(-radians);
    final sinTheta = math.sin(-radians);
    final unrotated = Offset(
      (translated.dx * cosTheta) - (translated.dy * sinTheta),
      (translated.dx * sinTheta) + (translated.dy * cosTheta),
    );
    final safeScaleX = node.scaleX.abs() < 0.0001 ? 1.0 : node.scaleX;
    final safeScaleY = node.scaleY.abs() < 0.0001 ? 1.0 : node.scaleY;
    final localPoint = Offset(
      unrotated.dx / safeScaleX,
      unrotated.dy / safeScaleY,
    );
    return localRect.contains(localPoint);
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
