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

    test('reports real motion blur presentation only for non-debug frames', () {
      final debugMarker = _result(
        canRenderFrame: true,
        pixelOutputReady: true,
        frameDelivered: true,
        framePresented: true,
        surfaceAttached: true,
        motionBlurEnabled: true,
        forcedVisualTestPattern: true,
        checksumDelta: true,
      );
      expect(professionalTransitionRealFramePresented(debugMarker), isFalse);

      final debugSynthetic = _result(
        canRenderFrame: true,
        pixelOutputReady: true,
        frameDelivered: true,
        framePresented: true,
        surfaceAttached: true,
        motionBlurEnabled: true,
        forcedSyntheticMotionBlur: true,
        checksumDelta: true,
      );
      expect(professionalTransitionRealFramePresented(debugSynthetic), isFalse);

      final realMotionBlur = _result(
        canRenderFrame: true,
        pixelOutputReady: true,
        frameDelivered: true,
        framePresented: true,
        surfaceAttached: true,
        motionBlurEnabled: true,
        sampleCount: 8,
        trailContributionCount: 3,
        motionBlurAmount: 0.65,
        sampleTransformDelta: 0.08,
        rendererConsumedSamples: true,
        renderPassIncludesTemporalMotionBlur: true,
        checksumDelta: true,
      );
      expect(professionalTransitionRealFramePresented(realMotionBlur), isTrue);

      final staticMotionBlur = _result(
        canRenderFrame: true,
        pixelOutputReady: true,
        frameDelivered: true,
        framePresented: true,
        surfaceAttached: true,
        motionBlurEnabled: true,
        sampleCount: 8,
        trailContributionCount: 0,
        motionBlurAmount: 0.65,
        sampleTransformDelta: 0,
        rendererConsumedSamples: true,
        renderPassIncludesTemporalMotionBlur: true,
        checksumDelta: true,
      );
      expect(
          professionalTransitionRealFramePresented(staticMotionBlur), isFalse);
    });
  });
}

ProfessionalVideoTransitionInteractiveFrameRenderResult _result({
  bool canRenderFrame = false,
  bool pixelOutputReady = false,
  bool frameDelivered = false,
  bool framePresented = false,
  bool surfaceAttached = false,
  bool motionBlurEnabled = false,
  bool forcedVisualTestPattern = false,
  bool forcedSyntheticMotionBlur = false,
  int sampleCount = 0,
  int trailContributionCount = 0,
  double motionBlurAmount = 0,
  double sampleTransformDelta = 0,
  bool rendererConsumedSamples = false,
  bool renderPassIncludesTemporalMotionBlur = false,
  bool? checksumDelta,
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
    motionBlurEnabled: motionBlurEnabled,
    sampleCount: sampleCount,
    outgoingContributionCount: 0,
    incomingContributionCount: 0,
    centerContributionCount: 0,
    trailContributionCount: trailContributionCount,
    motionBlurAmount: motionBlurAmount,
    forcedVisualTestPattern: forcedVisualTestPattern,
    forcedSyntheticMotionBlur: forcedSyntheticMotionBlur,
    sampleTransformDelta: sampleTransformDelta,
    rendererConsumedSamples: rendererConsumedSamples,
    renderPassIncludesTemporalMotionBlur: renderPassIncludesTemporalMotionBlur,
    fallbackUsed: false,
    checksumBefore: 0,
    checksumAfter: frameDelivered ? 7 : 0,
    checksumDelta: checksumDelta ?? frameDelivered,
    canRenderFrame: canRenderFrame,
    blockedReasons: blockedReasons,
  );
}
