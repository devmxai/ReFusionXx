import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/core/engine/stage5_native_transport_controller.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_visual_program_models.dart';

void main() {
  test(
    'builds native runtime bridge payload with descriptors and parity report',
    () {
      final result = LiveScrubDescriptorProjectionResult(
        timelinePositionMs: 1200,
        descriptors: const <LiveScrubSurfaceDescriptor>[
          LiveScrubSurfaceDescriptor(
            id: 'lsd:layer-1:test',
            targetId: 'layer-1',
            sourceKind: LiveScrubSourceKind.video,
            sourceUri: '/media/test.mp4',
            scrubStoreKey: 'clip-test',
            sourceWidth: 1920,
            sourceHeight: 1080,
            sourcePositionMs: 400,
            timelinePositionMs: 1200,
            timelineStartMs: 1000,
            timelineEndMs: 5000,
            transitionId: 'tr-1',
            transitionTimelineStartMs: 1100,
            transitionTimelineEndMs: 1400,
            transitionProgress: 0.5,
            transformMatrix3x3: <double>[1, 0, 0, 0, 1, 0, 0, 0, 1],
            opacity: 1.0,
            effectProgramIds: <String>['opacity'],
            transitionRole: LiveScrubTransitionRole.outgoing,
            isValid: true,
            blockers: <String>[],
            debugReasons: <String>['ok'],
          ),
        ],
        blockers: const <String>[],
        diagnostics: const <String>['diagnostic'],
        canProject: true,
        parityReport: const LiveScrubParityReport(
          canScrubFrame: true,
          usesMasterClock: true,
          usesMasterFrameEvaluation: true,
          usesNativeScrubSurface: true,
          usesExoPlayerDuringActiveScrub: false,
          usesStillFallback: false,
          missingDescriptors: <String>[],
          unsupportedEffects: <String>[],
          transitionParityState:
              LiveScrubTransitionParityState.windowReadyNoPixels,
          latencyBudgetState: LiveScrubLatencyBudgetState.nativeMetricsPending,
          performanceSnapshot: LiveScrubPerformanceSnapshot(
            frameRequestRateFps: 30,
            nativeDecodeRebindLatencyMs: 20,
            descriptorProjectionLatencyUs: 1200,
            framePresentationLatencyMs: 16,
            droppedFrameCount: 0,
            crossSourceWarmupReady: true,
            memoryPressureLevel: 'normal',
          ),
        ),
      );

      final payload = buildLiveScrubRuntimeBridgePayload(result);
      expect(payload['timelinePositionMs'], 1200);
      final descriptors = payload['descriptors'] as List<Object?>;
      expect(descriptors.length, 1);
      final descriptor = descriptors.single as Map<String, Object?>;
      expect(descriptor['id'], 'lsd:layer-1:test');
      expect(descriptor['transitionId'], 'tr-1');
      expect(descriptor['transitionProgress'], 0.5);

      final parity = payload['parityReport'] as Map<String, Object?>;
      expect(parity['canScrubFrame'], isTrue);
      expect(parity['latencyBudgetState'], 'nativeMetricsPending');
      final performance = parity['performanceSnapshot'] as Map<String, Object?>;
      expect(performance['descriptorProjectionLatencyUs'], 1200);
    },
  );
}
