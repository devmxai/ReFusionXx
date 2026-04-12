import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/professional_motion_text_raster_models.dart';
import '../../domain/models/professional_motion_text_render_models.dart';

class MotionTextPreviewOverlay extends StatelessWidget {
  const MotionTextPreviewOverlay({
    super.key,
    required this.snapshot,
  });

  final MotionTextRenderSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rasterSnapshot =
        const BasicMotionTextRasterContractAdapter().adapt(snapshot: snapshot);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasWidth = rasterSnapshot.canvasSize.width <= 0
              ? constraints.maxWidth
              : rasterSnapshot.canvasSize.width;
          final canvasHeight = rasterSnapshot.canvasSize.height <= 0
              ? constraints.maxHeight
              : rasterSnapshot.canvasSize.height;
          final scaleX =
              canvasWidth == 0 ? 1.0 : (constraints.maxWidth / canvasWidth);
          final scaleY =
              canvasHeight == 0 ? 1.0 : (constraints.maxHeight / canvasHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              for (final node in rasterSnapshot.nodes)
                if (node.text.isNotEmpty && node.effects.opacity > 0)
                  _MotionTextPreviewNodeWidget(
                    node: node,
                    rasterContract: rasterSnapshot.contract,
                    rasterizationPolicy: rasterSnapshot.rasterizationPolicy,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    viewportWidth: constraints.maxWidth,
                    viewportHeight: constraints.maxHeight,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _MotionTextPreviewNodeWidget extends StatelessWidget {
  const _MotionTextPreviewNodeWidget({
    required this.node,
    required this.rasterContract,
    required this.rasterizationPolicy,
    required this.scaleX,
    required this.scaleY,
    required this.viewportWidth,
    required this.viewportHeight,
  });

  final MotionTextRasterNode node;
  final MotionTextRasterContract rasterContract;
  final MotionTextRasterizationPolicy rasterizationPolicy;
  final double scaleX;
  final double scaleY;
  final double viewportWidth;
  final double viewportHeight;

  @override
  Widget build(BuildContext context) {
    final metrics = node.resolveMetrics(
      scaleX: scaleX,
      scaleY: scaleY,
      policy: rasterizationPolicy,
    );
    final textColor = Color(node.typography.colorArgb);
    final compositeOpacity = node.effects.opacity.clamp(0.0, 1.0);
    final baseStyle = TextStyle(
      color: textColor,
      fontSize: metrics.fontSizePx,
      fontFamily: node.typography.fontFamily,
      fontWeight: _resolveFontWeight(node.typography.fontWeight),
      fontStyle: _resolveFontStyle(node.typography.fontStyle),
    );
    final layout = _buildShapedTextLayout(
      text: node.text,
      style: baseStyle,
      letterSpacingPx: metrics.letterSpacingPx,
      horizontalPaddingPx: metrics.layoutPaddingPx,
      lineHeightMultiplier: node.typography.lineHeight,
      textAlignment: node.typography.textAlignment,
    );

    final anchorOffset = _resolveAnchorOffset(
      anchor: node.layout.anchor,
      width: layout.width,
      height: layout.height,
    );
    final centerX = (viewportWidth / 2) + metrics.translatedX;
    final centerY = (viewportHeight / 2) + metrics.translatedY;
    final transform = Matrix4.identity()
      ..translate(centerX, centerY)
      ..rotateZ(node.layout.rotationDegrees * (math.pi / 180))
      ..scale(node.layout.scaleX, node.layout.scaleY)
      ..translate(anchorOffset.dx, anchorOffset.dy);

    Widget child = SizedBox(
      width: layout.width,
      height: layout.height,
      child: ImageFiltered(
        imageFilter:
            _usesGaussianLayerBlur(rasterContract) && metrics.blurSigma > 0.05
                ? ui.ImageFilter.blur(
                    sigmaX: metrics.blurSigma,
                    sigmaY: metrics.blurSigma,
                  )
                : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: CustomPaint(
          painter: _ShapedTextPainter(
            layout: layout,
          ),
        ),
      ),
    );
    if (compositeOpacity < 0.999) {
      child = Opacity(
        opacity: compositeOpacity,
        child: child,
      );
    }

    return Positioned.fill(
      child: Transform(
        transform: transform,
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }
}

bool _usesGaussianLayerBlur(MotionTextRasterContract contract) =>
    contract.blurEngineId == 'gaussian_layer_blur';

class _ShapedTextPainter extends CustomPainter {
  const _ShapedTextPainter({
    required this.layout,
  });

  final _MeasuredTextLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    layout.painter.paint(canvas, layout.paintOffset);
  }

  @override
  bool shouldRepaint(covariant _ShapedTextPainter oldDelegate) =>
      oldDelegate.layout != layout;
}

class _MeasuredTextLayout {
  const _MeasuredTextLayout({
    required this.width,
    required this.height,
    required this.painter,
    required this.paintOffset,
  });

  final double width;
  final double height;
  final TextPainter painter;
  final Offset paintOffset;
}

_MeasuredTextLayout _buildShapedTextLayout({
  required String text,
  required TextStyle style,
  required double letterSpacingPx,
  required double horizontalPaddingPx,
  required double lineHeightMultiplier,
  required String textAlignment,
}) {
  final safeText = text.isEmpty ? ' ' : text;
  final shapedStyle = style.copyWith(
    letterSpacing: letterSpacingPx,
    height: math.max(0.1, lineHeightMultiplier),
  );
  final strutStyle = StrutStyle(
    fontFamily: shapedStyle.fontFamily,
    fontSize: shapedStyle.fontSize,
    fontWeight: shapedStyle.fontWeight,
    fontStyle: shapedStyle.fontStyle,
    height: shapedStyle.height,
    forceStrutHeight: true,
  );
  final painter = TextPainter(
    text: TextSpan(text: safeText, style: shapedStyle),
    textDirection: TextDirection.ltr,
    textAlign: _resolveTextAlign(textAlignment),
    textWidthBasis: TextWidthBasis.longestLine,
    textScaler: TextScaler.noScaling,
    strutStyle: strutStyle,
  )..layout();
  final contentWidth = math.max(1.0, painter.width);
  painter.layout(maxWidth: contentWidth);
  final width =
      math.max(1.0, painter.width.ceilToDouble() + (horizontalPaddingPx * 2));
  final height =
      math.max(1.0, painter.height.ceilToDouble() + (horizontalPaddingPx * 2));
  return _MeasuredTextLayout(
    width: width,
    height: height,
    painter: painter,
    paintOffset: Offset(horizontalPaddingPx, horizontalPaddingPx),
  );
}

TextAlign _resolveTextAlign(String textAlignment) {
  switch (textAlignment) {
    case 'start':
    case 'left':
      return TextAlign.left;
    case 'end':
    case 'right':
      return TextAlign.right;
    default:
      return TextAlign.center;
  }
}

Offset _resolveAnchorOffset({
  required String anchor,
  required double width,
  required double height,
}) {
  switch (anchor) {
    case 'topLeft':
      return Offset.zero;
    case 'topCenter':
      return Offset(-width / 2, 0);
    case 'topRight':
      return Offset(-width, 0);
    case 'centerLeft':
      return Offset(0, -height / 2);
    case 'centerRight':
      return Offset(-width, -height / 2);
    case 'bottomLeft':
      return Offset(0, -height);
    case 'bottomCenter':
      return Offset(-width / 2, -height);
    case 'bottomRight':
      return Offset(-width, -height);
    default:
      return Offset(-width / 2, -height / 2);
  }
}

FontWeight _resolveFontWeight(int weight) {
  if (weight >= 800) {
    return FontWeight.w800;
  }
  if (weight >= 700) {
    return FontWeight.w700;
  }
  if (weight >= 600) {
    return FontWeight.w600;
  }
  if (weight >= 500) {
    return FontWeight.w500;
  }
  if (weight >= 400) {
    return FontWeight.w400;
  }
  if (weight >= 300) {
    return FontWeight.w300;
  }
  return FontWeight.w200;
}

FontStyle _resolveFontStyle(String style) {
  return style == 'italic' ? FontStyle.italic : FontStyle.normal;
}

class MotionTextPreviewOverlayPlaceholder extends StatelessWidget {
  const MotionTextPreviewOverlayPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0x00000000),
              Color(0x00000000),
            ],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}
