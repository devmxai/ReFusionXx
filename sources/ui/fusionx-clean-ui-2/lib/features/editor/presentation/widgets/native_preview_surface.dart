import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/engine/stage5_native_transport_controller.dart';
import '../../../../core/theme/app_theme.dart';

@visibleForTesting
bool shouldResetNativePreviewForFrameLoss({
  required String? previewIdentity,
  required bool hasRenderedFirstFrame,
  required bool hasPresentedNativeFrameForPreview,
}) {
  return previewIdentity != null &&
      !hasRenderedFirstFrame &&
      hasPresentedNativeFrameForPreview;
}

@visibleForTesting
PlatformViewHitTestBehavior nativePreviewHitTestBehaviorFor({
  required bool allowPointerInteraction,
}) {
  return allowPointerInteraction
      ? PlatformViewHitTestBehavior.opaque
      : PlatformViewHitTestBehavior.transparent;
}

class NativePreviewSurface extends StatefulWidget {
  const NativePreviewSurface({
    super.key,
    required this.controller,
    required this.previewIdentity,
    required this.recoveryRevision,
    required this.fallback,
    this.allowPointerInteraction = true,
  });

  final Stage5NativeTransportController controller;
  final String? previewIdentity;
  final int recoveryRevision;
  final Widget fallback;
  final bool allowPointerInteraction;

  bool get _supportsAndroidPreview => !kIsWeb && Platform.isAndroid;

  @override
  State<NativePreviewSurface> createState() => _NativePreviewSurfaceState();
}

class _NativePreviewSurfaceState extends State<NativePreviewSurface> {
  String? _previewIdentity;
  bool _hasPresentedNativeFrameForPreview = false;
  bool _awaitingNativeFrameResetForPreview = false;
  bool _sawNativeFrameResetForPreview = false;

  @override
  void initState() {
    super.initState();
    _markPreviewIdentityChanged();
    widget.controller.addListener(_handleControllerChanged);
    _handleControllerChanged();
  }

  @override
  void didUpdateWidget(covariant NativePreviewSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    var shouldRefresh = false;
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _markPreviewIdentityChanged();
      shouldRefresh = true;
    }
    if (oldWidget.previewIdentity != widget.previewIdentity) {
      _markPreviewIdentityChanged();
      shouldRefresh = true;
    }
    if (oldWidget.recoveryRevision != widget.recoveryRevision) {
      _markPreviewIdentityChanged();
      shouldRefresh = true;
    }
    if (shouldRefresh) {
      _handleControllerChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _markPreviewIdentityChanged() {
    _previewIdentity = widget.previewIdentity;
    _hasPresentedNativeFrameForPreview = false;
    _awaitingNativeFrameResetForPreview = widget.previewIdentity != null;
    _sawNativeFrameResetForPreview = !widget.controller.hasRenderedFirstFrame;
  }

  void _handleControllerChanged() {
    final hasNativeFrameNow = widget.controller.hasRenderedFirstFrame &&
        widget.controller.aspectRatio != null &&
        widget.controller.isPreviewContentSized;
    var shouldNotify = false;
    if (_previewIdentity != widget.previewIdentity) {
      _markPreviewIdentityChanged();
      shouldNotify = true;
    }
    if (widget.previewIdentity == null) {
      _awaitingNativeFrameResetForPreview = false;
      _sawNativeFrameResetForPreview = false;
      _hasPresentedNativeFrameForPreview = false;
      shouldNotify = true;
    }
    if (_awaitingNativeFrameResetForPreview &&
        !widget.controller.hasRenderedFirstFrame) {
      _sawNativeFrameResetForPreview = true;
    }
    if (shouldResetNativePreviewForFrameLoss(
      previewIdentity: widget.previewIdentity,
      hasRenderedFirstFrame: widget.controller.hasRenderedFirstFrame,
      hasPresentedNativeFrameForPreview: _hasPresentedNativeFrameForPreview,
    )) {
      _awaitingNativeFrameResetForPreview = true;
      _sawNativeFrameResetForPreview = true;
      _hasPresentedNativeFrameForPreview = false;
      shouldNotify = true;
    }

    final canPresentNativeFrame = hasNativeFrameNow &&
        (!_awaitingNativeFrameResetForPreview ||
            _sawNativeFrameResetForPreview);
    if (canPresentNativeFrame && !_hasPresentedNativeFrameForPreview) {
      _awaitingNativeFrameResetForPreview = false;
      _hasPresentedNativeFrameForPreview = true;
      shouldNotify = true;
    }
    if (shouldNotify && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._supportsAndroidPreview) {
      return widget.fallback;
    }

    final showNative = _hasPresentedNativeFrameForPreview;
    final nativeView = AndroidView(
      key: ValueKey<int>(widget.recoveryRevision),
      viewType: Stage5NativeTransportController.previewViewType,
      hitTestBehavior: nativePreviewHitTestBehaviorFor(
        allowPointerInteraction: widget.allowPointerInteraction,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !widget.allowPointerInteraction,
              child: nativeView,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: showNative ? 0 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: widget.fallback,
              ),
            ),
          ),
          if (widget.controller.isInitializing && !showNative)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FxPalette.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.controller.errorMessage != null &&
              widget.controller.errorMessage!.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.76),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.controller.errorMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
