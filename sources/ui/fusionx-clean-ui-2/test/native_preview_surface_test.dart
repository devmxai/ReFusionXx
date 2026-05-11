import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/widgets/native_preview_surface.dart';

void main() {
  test(
      'native preview returns to fallback when the same source loses its frame',
      () {
    expect(
      shouldResetNativePreviewForFrameLoss(
        previewIdentity: 'file:///clip-a.mp4',
        hasRenderedFirstFrame: false,
        hasPresentedNativeFrameForPreview: true,
      ),
      isTrue,
    );
  });

  test('native preview does not reset without an active presented source', () {
    expect(
      shouldResetNativePreviewForFrameLoss(
        previewIdentity: null,
        hasRenderedFirstFrame: false,
        hasPresentedNativeFrameForPreview: true,
      ),
      isFalse,
    );
    expect(
      shouldResetNativePreviewForFrameLoss(
        previewIdentity: 'file:///clip-a.mp4',
        hasRenderedFirstFrame: true,
        hasPresentedNativeFrameForPreview: true,
      ),
      isFalse,
    );
    expect(
      shouldResetNativePreviewForFrameLoss(
        previewIdentity: 'file:///clip-a.mp4',
        hasRenderedFirstFrame: false,
        hasPresentedNativeFrameForPreview: false,
      ),
      isFalse,
    );
  });

  test('native preview is transparent to gestures during canvas transform', () {
    expect(
      nativePreviewHitTestBehaviorFor(allowPointerInteraction: false),
      PlatformViewHitTestBehavior.transparent,
    );
  });

  test(
      'native preview remains opaque when normal preview interaction is allowed',
      () {
    expect(
      nativePreviewHitTestBehaviorFor(allowPointerInteraction: true),
      PlatformViewHitTestBehavior.opaque,
    );
  });
}
