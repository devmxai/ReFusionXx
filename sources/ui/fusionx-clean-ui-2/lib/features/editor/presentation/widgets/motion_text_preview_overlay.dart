import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/professional_motion_text_raster_models.dart';
import '../../domain/models/professional_motion_text_render_models.dart';
import '../../domain/models/professional_motion_text_models.dart';

const int _motionTextLayoutCacheCapacity = 192;
final LinkedHashMap<_TextLayoutCacheKey, _MeasuredTextLayout>
    _motionTextLayoutCache =
    LinkedHashMap<_TextLayoutCacheKey, _MeasuredTextLayout>();

void warmMotionTextPreviewOverlayCaches({
  required MotionTextRenderSnapshot snapshot,
  Size? viewportSize,
}) {
  final rasterSnapshot =
      const BasicMotionTextRasterContractAdapter().adapt(snapshot: snapshot);
  final canvasWidth = rasterSnapshot.canvasSize.width <= 0
      ? (viewportSize?.width ?? 1)
      : rasterSnapshot.canvasSize.width;
  final canvasHeight = rasterSnapshot.canvasSize.height <= 0
      ? (viewportSize?.height ?? 1)
      : rasterSnapshot.canvasSize.height;
  final viewportWidth = viewportSize?.width ?? canvasWidth;
  final viewportHeight = viewportSize?.height ?? canvasHeight;
  final scaleX = canvasWidth == 0 ? 1.0 : viewportWidth / canvasWidth;
  final scaleY = canvasHeight == 0 ? 1.0 : viewportHeight / canvasHeight;

  for (final node in rasterSnapshot.nodes) {
    if (node.text.isEmpty || node.effects.opacity <= 0) {
      continue;
    }
    final metrics = node.resolveMetrics(
      scaleX: scaleX,
      scaleY: scaleY,
      policy: rasterSnapshot.rasterizationPolicy,
    );
    final revealFrameText = node.hasRevealAnimation && node.fullText.isNotEmpty
        ? node.fullText
        : node.text;
    final revealFrameLayout = _motionTextLayoutForKey(
      _TextLayoutCacheKey(
        text: revealFrameText,
        style: _textStyleForMotionNode(node, metrics),
        letterSpacingPx: metrics.letterSpacingPx,
        lineHeightMultiplier: node.typography.lineHeight,
        textAlignment: node.typography.textAlignment,
      ),
    );
    if (node.hasRevealAnimation) {
      _motionTextLayoutForKey(
        _TextLayoutCacheKey(
          text: node.text,
          style: _textStyleForMotionNode(node, metrics),
          letterSpacingPx: metrics.letterSpacingPx,
          lineHeightMultiplier: node.typography.lineHeight,
          textAlignment: node.typography.textAlignment,
          maxWidth: revealFrameLayout.contentWidth,
        ),
      );
    }
  }
}

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
                    key: ValueKey<String>(node.id),
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

class _MotionTextPreviewNodeWidget extends StatefulWidget {
  const _MotionTextPreviewNodeWidget({
    super.key,
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
  State<_MotionTextPreviewNodeWidget> createState() =>
      _MotionTextPreviewNodeWidgetState();
}

class _MotionTextPreviewNodeWidgetState
    extends State<_MotionTextPreviewNodeWidget> {
  _TextLayoutCacheKey? _layoutKey;
  _MeasuredTextLayout? _layout;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final metrics = node.resolveMetrics(
      scaleX: widget.scaleX,
      scaleY: widget.scaleY,
      policy: widget.rasterizationPolicy,
    );
    final compositeOpacity = node.effects.opacity.clamp(0.0, 1.0);
    final baseStyle = _textStyleForMotionNode(node, metrics);
    final scaledTextFrame = node.textFrame?.scaled(
      scaleX: widget.scaleX,
      scaleY: widget.scaleY,
    );
    final revealFrameText = node.hasRevealAnimation && node.fullText.isNotEmpty
        ? node.fullText
        : node.text;
    final revealFrameLayout = _motionTextLayoutForKey(
      _TextLayoutCacheKey(
        text: revealFrameText,
        style: baseStyle,
        letterSpacingPx: metrics.letterSpacingPx,
        lineHeightMultiplier: node.typography.lineHeight,
        textAlignment: node.typography.textAlignment,
        textFrame: scaledTextFrame,
      ),
    );
    final layoutKey = _TextLayoutCacheKey(
      text: node.text,
      style: baseStyle,
      letterSpacingPx: metrics.letterSpacingPx,
      lineHeightMultiplier: node.typography.lineHeight,
      textAlignment: node.typography.textAlignment,
      maxWidth: scaledTextFrame?.width ??
          (node.hasRevealAnimation ? revealFrameLayout.contentWidth : null),
      textFrame: scaledTextFrame,
    );
    final layout =
        _layoutKey == layoutKey ? _layout! : _buildAndCacheLayout(layoutKey);
    final resolvedContentWidth = node.hasRevealAnimation
        ? math.max(layout.contentWidth, revealFrameLayout.contentWidth)
        : layout.contentWidth;
    final resolvedContentHeight = node.hasRevealAnimation
        ? math.max(layout.contentHeight, revealFrameLayout.contentHeight)
        : layout.contentHeight;
    final layoutWidth = _paddedLayoutExtent(
      scaledTextFrame?.width ?? resolvedContentWidth,
      metrics.layoutPaddingPx,
    );
    final layoutHeight = _paddedLayoutExtent(
      scaledTextFrame?.height ?? resolvedContentHeight,
      metrics.layoutPaddingPx,
    );
    final paintOffset = Offset(
      metrics.layoutPaddingPx,
      metrics.layoutPaddingPx,
    );

    final anchorOffset = _resolveAnchorOffset(
      anchor: node.layout.anchor,
      width: layoutWidth,
      height: layoutHeight,
    );
    final centerX = (widget.viewportWidth / 2) + metrics.translatedX;
    final centerY = (widget.viewportHeight / 2) + metrics.translatedY;
    final transform = Matrix4.identity()
      ..translate(centerX, centerY)
      ..rotateZ(node.layout.rotationDegrees * (math.pi / 180))
      ..scale(node.layout.scaleX, node.layout.scaleY)
      ..translate(anchorOffset.dx, anchorOffset.dy);

    Widget buildPaintedText() => CustomPaint(
          painter: _ShapedTextPainter(
            layout: layout,
            paintOffset: paintOffset,
          ),
        );
    Widget paintedText = buildPaintedText();
    if (_usesGaussianLayerBlur(widget.rasterContract) &&
        metrics.blurSigma > 0.05 &&
        metrics.blurMix > 0.001) {
      final blurredText = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: metrics.blurSigmaX,
          sigmaY: metrics.blurSigmaY,
          tileMode: _blurTileModeForValue(metrics.blurEdgeMode),
        ),
        child: buildPaintedText(),
      );
      paintedText = metrics.blurMix >= 0.999
          ? blurredText
          : Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: 1.0 - metrics.blurMix,
                  child: paintedText,
                ),
                Opacity(
                  opacity: metrics.blurMix,
                  child: blurredText,
                ),
              ],
            );
    }

    Widget child = RepaintBoundary(
      child: SizedBox(
        width: layoutWidth,
        height: layoutHeight,
        child: paintedText,
      ),
    );
    if (scaledTextFrame?.hasBounds ?? false) {
      child = ClipRect(child: child);
    }
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

  _MeasuredTextLayout _buildAndCacheLayout(_TextLayoutCacheKey key) {
    final layout = _motionTextLayoutForKey(key);
    _layoutKey = key;
    _layout = layout;
    return layout;
  }
}

bool _usesGaussianLayerBlur(MotionTextRasterContract contract) =>
    contract.blurEngineId == 'gaussian_layer_blur';

ui.TileMode _blurTileModeForValue(double value) {
  final mode = value.round();
  if (mode <= 0) {
    return ui.TileMode.decal;
  }
  return ui.TileMode.clamp;
}

class _ShapedTextPainter extends CustomPainter {
  const _ShapedTextPainter({
    required this.layout,
    required this.paintOffset,
  });

  final _MeasuredTextLayout layout;
  final Offset paintOffset;

  @override
  void paint(Canvas canvas, Size size) {
    layout.painter.paint(canvas, paintOffset);
  }

  @override
  bool shouldRepaint(covariant _ShapedTextPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.paintOffset != paintOffset;
}

class _MeasuredTextLayout {
  const _MeasuredTextLayout({
    required this.contentWidth,
    required this.contentHeight,
    required this.painter,
  });

  final double contentWidth;
  final double contentHeight;
  final TextPainter painter;
}

@immutable
class _TextLayoutCacheKey {
  const _TextLayoutCacheKey({
    required this.text,
    required this.style,
    required this.letterSpacingPx,
    required this.lineHeightMultiplier,
    required this.textAlignment,
    this.maxWidth,
    this.textFrame,
  });

  final String text;
  final TextStyle style;
  final double letterSpacingPx;
  final double lineHeightMultiplier;
  final String textAlignment;
  final double? maxWidth;
  final MotionTextFrameContract? textFrame;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _TextLayoutCacheKey &&
            other.text == text &&
            other.style == style &&
            other.letterSpacingPx == letterSpacingPx &&
            other.lineHeightMultiplier == lineHeightMultiplier &&
            other.textAlignment == textAlignment &&
            other.maxWidth == maxWidth &&
            other.textFrame?.width == textFrame?.width &&
            other.textFrame?.height == textFrame?.height &&
            other.textFrame?.maxLines == textFrame?.maxLines &&
            other.textFrame?.overflow == textFrame?.overflow &&
            other.textFrame?.fitPolicy == textFrame?.fitPolicy;
  }

  @override
  int get hashCode => Object.hash(
        text,
        style,
        letterSpacingPx,
        lineHeightMultiplier,
        textAlignment,
        maxWidth,
        textFrame?.width,
        textFrame?.height,
        textFrame?.maxLines,
        textFrame?.overflow,
        textFrame?.fitPolicy,
      );
}

_MeasuredTextLayout _motionTextLayoutForKey(_TextLayoutCacheKey key) {
  final cached = _motionTextLayoutCache.remove(key);
  if (cached != null) {
    _motionTextLayoutCache[key] = cached;
    return cached;
  }
  final layout = _buildShapedTextLayout(
    text: key.text,
    style: key.style,
    letterSpacingPx: key.letterSpacingPx,
    lineHeightMultiplier: key.lineHeightMultiplier,
    textAlignment: key.textAlignment,
    maxWidth: key.maxWidth,
    textFrame: key.textFrame,
  );
  _motionTextLayoutCache[key] = layout;
  while (_motionTextLayoutCache.length > _motionTextLayoutCacheCapacity) {
    _motionTextLayoutCache.remove(_motionTextLayoutCache.keys.first);
  }
  return layout;
}

_MeasuredTextLayout _buildShapedTextLayout({
  required String text,
  required TextStyle style,
  required double letterSpacingPx,
  required double lineHeightMultiplier,
  required String textAlignment,
  double? maxWidth,
  MotionTextFrameContract? textFrame,
}) {
  final safeText = text.isEmpty ? ' ' : text;
  var shapedStyle = style.copyWith(
    letterSpacing: letterSpacingPx,
    height: math.max(0.1, lineHeightMultiplier),
  );
  final boundedWidth = textFrame?.width ?? maxWidth;
  final boundedHeight = textFrame?.height;
  final resolvedMaxWidth =
      boundedWidth == null ? null : math.max(1.0, boundedWidth.floorToDouble());
  final maxLines =
      textFrame?.maxLines == null ? null : math.max(1, textFrame!.maxLines!);
  final overflow = (textFrame?.overflow ?? '').toLowerCase();
  final fitPolicy = (textFrame?.fitPolicy ?? '').toLowerCase();
  final ellipsis =
      overflow == 'ellipsis' || fitPolicy == 'ellipsis' ? '…' : null;

  TextPainter buildPainter(TextStyle currentStyle) {
    final strutStyle = StrutStyle(
      fontFamily: currentStyle.fontFamily,
      fontSize: currentStyle.fontSize,
      fontWeight: currentStyle.fontWeight,
      fontStyle: currentStyle.fontStyle,
      height: currentStyle.height,
      forceStrutHeight: true,
    );
    return TextPainter(
      text: TextSpan(text: safeText, style: currentStyle),
      textDirection: TextDirection.ltr,
      textAlign: _resolveTextAlign(textAlignment),
      textWidthBasis: TextWidthBasis.longestLine,
      textScaler: TextScaler.noScaling,
      strutStyle: strutStyle,
      maxLines: maxLines,
      ellipsis: ellipsis,
    )..layout(maxWidth: resolvedMaxWidth ?? double.infinity);
  }

  var painter = buildPainter(shapedStyle);
  if ((fitPolicy == 'shrinktofit' || fitPolicy == 'shrink') &&
      resolvedMaxWidth != null) {
    final originalFontSize = shapedStyle.fontSize ?? 16;
    var fontSize = originalFontSize;
    final minimumFontSize = math.min(12.0, originalFontSize);
    while (fontSize > minimumFontSize &&
        (painter.didExceedMaxLines ||
            painter.width > resolvedMaxWidth + 0.5 ||
            (boundedHeight != null && painter.height > boundedHeight + 0.5))) {
      fontSize -= 1;
      shapedStyle = shapedStyle.copyWith(fontSize: fontSize);
      painter = buildPainter(shapedStyle);
    }
  }

  final contentWidth = resolvedMaxWidth ?? math.max(1.0, painter.width);
  painter.layout(maxWidth: contentWidth);
  return _MeasuredTextLayout(
    contentWidth: math.max(
      1.0,
      (resolvedMaxWidth ?? painter.width).ceilToDouble(),
    ),
    contentHeight: math.max(
      1.0,
      (boundedHeight ?? painter.height).ceilToDouble(),
    ),
    painter: painter,
  );
}

double _paddedLayoutExtent(double contentExtent, double padding) =>
    math.max(1.0, contentExtent + (padding * 2));

TextStyle _textStyleForMotionNode(
  MotionTextRasterNode node,
  MotionTextResolvedRasterMetrics metrics,
) {
  return TextStyle(
    color: Color(node.typography.colorArgb),
    fontSize: metrics.fontSizePx,
    fontFamily: node.typography.fontFamily,
    fontWeight: _resolveFontWeight(node.typography.fontWeight),
    fontStyle: _resolveFontStyle(node.typography.fontStyle),
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
