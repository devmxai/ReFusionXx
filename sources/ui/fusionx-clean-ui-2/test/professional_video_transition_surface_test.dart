import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/professional_video_transition_compositor.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/widgets/professional_video_transition_surface.dart';

void main() {
  group('ProfessionalVideoTransitionSurfaceOverlay retry policy', () {
    test('retries while the interactive surface is still registering', () {
      final result = _result(
        blockedReasons: const <String>[
          'native_transition_interactive_surface_not_registered',
        ],
      );

      expect(
        shouldRetryInteractiveRenderResult(
          result,
          retryCount: 0,
          maxRetryCount: 24,
        ),
        isTrue,
      );
    });

    test('retries transient presentation failures', () {
      final result = _result(
        pixelOutputReady: true,
        frameDelivered: true,
        surfaceAttached: true,
        blockedReasons: const <String>[
          'native_transition_preview_interactive_surface_presentation_missing',
        ],
      );

      expect(
        shouldRetryInteractiveRenderResult(
          result,
          retryCount: 3,
          maxRetryCount: 24,
        ),
        isTrue,
      );
    });

    test('retries while the Android surface is not attached yet', () {
      final result = _result(
        pixelOutputReady: false,
        surfaceAttached: false,
        blockedReasons: const <String>[
          'native_transition_preview_interactive_surface_missing',
        ],
      );

      expect(
        shouldRetryInteractiveRenderResult(
          result,
          retryCount: 1,
          maxRetryCount: 24,
        ),
        isTrue,
      );
    });

    test('does not retry permanent source pixel blockers', () {
      final result = _result(
        blockedReasons: const <String>[
          'native_transition_temporal_video_pixels_missing',
        ],
      );

      expect(
        shouldRetryInteractiveRenderResult(
          result,
          retryCount: 0,
          maxRetryCount: 24,
        ),
        isFalse,
      );
    });

    test('does not retry once a frame rendered successfully', () {
      final result = _result(
        canRenderFrame: true,
        pixelOutputReady: true,
        frameDelivered: true,
        framePresented: true,
        surfaceAttached: true,
      );

      expect(
        shouldRetryInteractiveRenderResult(
          result,
          retryCount: 0,
          maxRetryCount: 24,
        ),
        isFalse,
      );
    });

    test('keeps Android surface warm before first presented frame', () {
      expect(
        professionalTransitionSurfaceOpacityForPresentedState(false),
        greaterThan(0),
      );
      expect(
        professionalTransitionSurfaceOpacityForPresentedState(false),
        lessThan(1),
      );
      expect(
        professionalTransitionSurfaceOpacityForPresentedState(true),
        1.0,
      );
    });
  });
}

ProfessionalVideoTransitionInteractiveFrameRenderResult _result({
  bool canRenderFrame = false,
  bool pixelOutputReady = false,
  bool frameDelivered = false,
  bool framePresented = false,
  bool surfaceAttached = false,
  List<String> blockedReasons = const <String>[],
}) {
  return ProfessionalVideoTransitionInteractiveFrameRenderResult(
    status: ProfessionalVideoTransitionInteractiveFrameRenderStatus.planned,
    reason: '',
    rendererVersion: 'test',
    definitionId: 'distortionZoomInV1',
    renderSessionId: 'session',
    mode: 'preview',
    surfaceId: 'surface',
    timelineTime: TimelineTime.fromMilliseconds(1000),
    transitionStartTime: TimelineTime.zero,
    transitionEndTime: TimelineTime.fromMilliseconds(2000),
    pixelOutputReady: pixelOutputReady,
    frameDelivered: frameDelivered,
    framePresented: framePresented,
    frameByteCount: frameDelivered ? 64 : 0,
    frameChecksum: frameDelivered ? 7 : 0,
    surfaceAttached: surfaceAttached,
    surfaceKind: surfaceAttached ? 'interactiveNativeTransitionSurface' : '',
    renderOwner: 'professionalCompositor',
    motionBlurEnabled: false,
    sampleCount: 0,
    outgoingContributionCount: 0,
    incomingContributionCount: 0,
    centerContributionCount: 0,
    trailContributionCount: 0,
    motionBlurAmount: 0,
    checksumBefore: 0,
    checksumAfter: frameDelivered ? 7 : 0,
    checksumDelta: frameDelivered,
    canRenderFrame: canRenderFrame,
    blockedReasons: blockedReasons,
  );
}
