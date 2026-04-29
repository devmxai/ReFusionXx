import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

@immutable
class PreviewViewportState {
  const PreviewViewportState({
    this.scale = 1.0,
    this.offset = Offset.zero,
  });

  static const PreviewViewportState identity = PreviewViewportState();

  final double scale;
  final Offset offset;

  bool get isIdentity =>
      (scale - 1.0).abs() < 0.001 && offset.distanceSquared < 0.25;

  PreviewViewportState copyWith({
    double? scale,
    Offset? offset,
  }) {
    return PreviewViewportState(
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PreviewViewportState &&
        other.scale == scale &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(scale, offset);
}

class PreviewStage extends StatelessWidget {
  const PreviewStage({
    super.key,
    required this.workspaceAspectRatio,
    required this.child,
    this.overlay,
    this.canvasBackgroundColor = Colors.black,
    this.hasVisibleContent = true,
    this.viewportState = PreviewViewportState.identity,
    this.onViewportChanged,
    this.onViewportReset,
  });

  final double? workspaceAspectRatio;
  final Widget child;
  final Widget? overlay;
  final Color canvasBackgroundColor;
  final bool hasVisibleContent;
  final PreviewViewportState viewportState;
  final ValueChanged<PreviewViewportState>? onViewportChanged;
  final VoidCallback? onViewportReset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio =
            (workspaceAspectRatio != null && workspaceAspectRatio! > 0)
                ? workspaceAspectRatio!
                : 9 / 16;

        var targetWidth = constraints.maxWidth;
        var targetHeight = targetWidth / aspectRatio;

        if (targetHeight > constraints.maxHeight) {
          targetHeight = constraints.maxHeight;
          targetWidth = targetHeight * aspectRatio;
        }

        return ColoredBox(
          color: FxPalette.background,
          child: Center(
            child: SizedBox(
              width: targetWidth,
              height: targetHeight,
              child: _PreviewStageViewportShell(
                hasVisibleContent: hasVisibleContent,
                viewportState: viewportState,
                onViewportChanged: onViewportChanged,
                onViewportReset: onViewportReset,
                canvasBackgroundColor: canvasBackgroundColor,
                overlay: overlay,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PreviewStageViewportShell extends StatefulWidget {
  const _PreviewStageViewportShell({
    required this.hasVisibleContent,
    required this.viewportState,
    required this.child,
    required this.canvasBackgroundColor,
    this.overlay,
    this.onViewportChanged,
    this.onViewportReset,
  });

  final bool hasVisibleContent;
  final PreviewViewportState viewportState;
  final Widget child;
  final Color canvasBackgroundColor;
  final Widget? overlay;
  final ValueChanged<PreviewViewportState>? onViewportChanged;
  final VoidCallback? onViewportReset;

  @override
  State<_PreviewStageViewportShell> createState() =>
      _PreviewStageViewportShellState();
}

class _PreviewStageViewportShellState
    extends State<_PreviewStageViewportShell> {
  int _activePointerCount = 0;
  bool _viewportGestureActive = false;
  double _gestureStartScale = 1.0;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocalLocal = Offset.zero;
  late PreviewViewportState _interactiveViewportState;

  @override
  void initState() {
    super.initState();
    _interactiveViewportState = widget.viewportState;
  }

  @override
  void didUpdateWidget(covariant _PreviewStageViewportShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_viewportGestureActive) {
      return;
    }
    if (widget.viewportState != _interactiveViewportState) {
      _interactiveViewportState = widget.viewportState;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportState = _interactiveViewportState;

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
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onDoubleTap: !widget.hasVisibleContent || viewportState.isIdentity
            ? null
            : _handleViewportReset,
        onScaleStart: (details) {
          if (!widget.hasVisibleContent || _activePointerCount < 2) {
            _viewportGestureActive = false;
            return;
          }
          _viewportGestureActive = true;
          _gestureStartScale = viewportState.scale;
          _gestureStartOffset = viewportState.offset;
          _gestureStartFocalLocal = details.localFocalPoint;
        },
        onScaleUpdate: (details) {
          if (!_viewportGestureActive) {
            return;
          }
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null || !renderBox.hasSize) {
            return;
          }
          final stageSize = renderBox.size;
          final stageCenter = stageSize.center(Offset.zero);
          final startFocal = _gestureStartFocalLocal - stageCenter;
          final currentFocal = details.localFocalPoint - stageCenter;
          final unclampedScale = (_gestureStartScale * details.scale).clamp(
            0.55,
            6.0,
          );
          final safeStartScale =
              _gestureStartScale.abs() < 0.0001 ? 1.0 : _gestureStartScale;
          final anchoredCanvasPoint =
              (startFocal - _gestureStartOffset) / safeStartScale;
          final nextOffset =
              currentFocal - (anchoredCanvasPoint * unclampedScale);
          final nextState = PreviewViewportState(
            scale: unclampedScale,
            offset: _clampOffset(
              offset: nextOffset,
              scale: unclampedScale,
              stageSize: stageSize,
            ),
          );
          if (nextState == _interactiveViewportState) {
            return;
          }
          setState(() {
            _interactiveViewportState = nextState;
          });
        },
        onScaleEnd: (_) {
          _viewportGestureActive = false;
          widget.onViewportChanged?.call(_interactiveViewportState);
        },
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(
                  viewportState.offset.dx,
                  viewportState.offset.dy,
                )
                ..scale(viewportState.scale),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: widget.hasVisibleContent
                      ? widget.canvasBackgroundColor
                      : Colors.transparent,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.child,
                      if (widget.overlay != null) widget.overlay!,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleViewportReset() {
    setState(() {
      _interactiveViewportState = PreviewViewportState.identity;
    });
    widget.onViewportChanged?.call(_interactiveViewportState);
    widget.onViewportReset?.call();
  }

  Offset _clampOffset({
    required Offset offset,
    required double scale,
    required Size stageSize,
  }) {
    if (scale <= 1.001) {
      return Offset.zero;
    }
    final horizontalLimit = (stageSize.width * (scale - 1.0)) / 2;
    final verticalLimit = (stageSize.height * (scale - 1.0)) / 2;
    return Offset(
      offset.dx.clamp(-horizontalLimit, horizontalLimit),
      offset.dy.clamp(-verticalLimit, verticalLimit),
    );
  }
}
