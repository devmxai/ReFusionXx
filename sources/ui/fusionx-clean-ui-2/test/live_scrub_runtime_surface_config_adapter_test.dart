import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/core/engine/live_scrub_preview_sources.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_visual_program_models.dart';
import 'package:refusion_app/features/editor/presentation/services/live_scrub_runtime_surface_config_adapter.dart';

void main() {
  const adapter = LiveScrubRuntimeSurfaceConfigAdapter();

  test('merges projected descriptors over baseline clip entries', () {
    final baseline = <LiveScrubPreviewSourceDescriptor>[
      const LiveScrubPreviewSourceDescriptor(
        clipId: 'clip-a',
        assetId: 'asset-a',
        sourceUri: 'file:///baseline-a.mp4',
        scrubStoreKey: 'asset-a',
        label: 'A',
        timelineStartMs: 0,
        timelineEndMs: 2000,
        durationMs: 2000,
        sourceStartMs: 0,
        sourceDurationMs: 2000,
        playbackRate: 1.0,
      ),
      const LiveScrubPreviewSourceDescriptor(
        clipId: 'clip-b',
        assetId: 'asset-b',
        sourceUri: 'file:///baseline-b.mp4',
        scrubStoreKey: 'asset-b',
        label: 'B',
        timelineStartMs: 2000,
        timelineEndMs: 4000,
        durationMs: 2000,
        sourceStartMs: 0,
        sourceDurationMs: 2000,
        playbackRate: 1.0,
      ),
    ];
    final projection = LiveScrubDescriptorProjectionResult(
      timelinePositionMs: 2100,
      canProject: true,
      descriptors: const <LiveScrubSurfaceDescriptor>[
        LiveScrubSurfaceDescriptor(
          id: 'lsd:clip-b',
          targetId: 'clip-b',
          sourceKind: LiveScrubSourceKind.video,
          sourceUri: 'file:///projected-b.mp4',
          scrubStoreKey: 'clip-b-store',
          transitionId: 'transition-a',
          transitionTimelineStartMs: 2000,
          transitionTimelineEndMs: 2600,
          transitionProgress: 0.25,
          sourcePositionMs: 120,
          timelinePositionMs: 2100,
          timelineStartMs: 2000,
          timelineEndMs: 4000,
          transformMatrix3x3: <double>[
            1,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            1,
          ],
          opacity: 1.0,
          effectProgramIds: <String>['gaussianBlur'],
          transitionRole: LiveScrubTransitionRole.incoming,
          isValid: true,
          blockers: <String>[],
          debugReasons: <String>[],
        ),
      ],
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
        performanceSnapshot: LiveScrubPerformanceSnapshot(),
      ),
      rendererPresentationProof: const RendererPresentationProof.uninitialized(
        rendererMode: 'liveScrub',
        matchReason: 'surface_config_merge_test',
      ),
    );

    final merged = adapter.mergeProjectedSources(
      baselineSources: baseline,
      projection: projection,
      sourceWindowsByTargetId: const <String, LiveScrubTimelineSourceWindow>{
        'clip-b': LiveScrubTimelineSourceWindow(
          targetId: 'clip-b',
          timelineStartMs: 1800,
          timelineEndMs: 4300,
          sourceStartMs: 300,
          sourceDurationMs: 2500,
          playbackRate: 1.25,
        ),
      },
    );

    expect(merged, hasLength(2));
    expect(merged[1].clipId, 'clip-b');
    expect(merged[1].sourceUri, 'file:///projected-b.mp4');
    expect(merged[1].scrubStoreKey, 'clip-b-store');
    expect(merged[1].timelineStartMs, 1800);
    expect(merged[1].timelineEndMs, 4300);
    expect(merged[1].sourceStartMs, 300);
    expect(merged[1].sourceDurationMs, 2500);
    expect(merged[1].playbackRate, 1.25);
    expect(merged[1].transitionId, 'transition-a');
    expect(merged[1].transitionProgress, 0.25);
    expect(merged[1].transitionRole, 'incoming');
    expect(merged[1].effectProgramIds, <String>['gaussianBlur']);
    expect(merged[1].transformMatrix3x3, hasLength(9));
  });

  test('ignores descriptors that cannot map to timeline source windows', () {
    final baseline = <LiveScrubPreviewSourceDescriptor>[
      const LiveScrubPreviewSourceDescriptor(
        clipId: 'clip-a',
        assetId: 'asset-a',
        sourceUri: 'file:///baseline-a.mp4',
        scrubStoreKey: 'asset-a',
        label: 'A',
        timelineStartMs: 0,
        timelineEndMs: 2000,
        durationMs: 2000,
        sourceStartMs: 0,
        sourceDurationMs: 2000,
        playbackRate: 1.0,
      ),
    ];
    final projection = LiveScrubDescriptorProjectionResult(
      timelinePositionMs: 1000,
      canProject: false,
      descriptors: const <LiveScrubSurfaceDescriptor>[
        LiveScrubSurfaceDescriptor(
          id: 'lsd:missing',
          targetId: 'missing-clip',
          sourceKind: LiveScrubSourceKind.video,
          sourceUri: 'file:///missing.mp4',
          sourcePositionMs: 0,
          timelinePositionMs: 1000,
          timelineStartMs: 0,
          timelineEndMs: 1000,
          transformMatrix3x3: <double>[
            1,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            1,
          ],
          opacity: 1.0,
          effectProgramIds: <String>[],
          transitionRole: LiveScrubTransitionRole.none,
          isValid: false,
          blockers: <String>['missing_source_window:missing-clip'],
          debugReasons: <String>[],
        ),
      ],
      blockers: const <String>['missing_source_window:missing-clip'],
      parityReport: const LiveScrubParityReport(
        canScrubFrame: false,
        usesMasterClock: true,
        usesMasterFrameEvaluation: true,
        usesNativeScrubSurface: true,
        usesExoPlayerDuringActiveScrub: false,
        usesStillFallback: false,
        missingDescriptors: <String>['missing-clip'],
        unsupportedEffects: <String>[],
        transitionParityState: LiveScrubTransitionParityState.blocked,
        latencyBudgetState: LiveScrubLatencyBudgetState.nativeMetricsPending,
        performanceSnapshot: LiveScrubPerformanceSnapshot(),
      ),
      rendererPresentationProof: const RendererPresentationProof.uninitialized(
        rendererMode: 'liveScrub',
        matchReason: 'surface_config_ignore_test',
      ),
    );

    final merged = adapter.mergeProjectedSources(
      baselineSources: baseline,
      projection: projection,
      sourceWindowsByTargetId: const <String, LiveScrubTimelineSourceWindow>{},
    );

    expect(merged, baseline);
  });
}
