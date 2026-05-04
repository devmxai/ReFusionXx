import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_value_truth_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_live_scrub_descriptor_projection.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  test('projects stable descriptor id and exact source-time mapping', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(10000),
      initialTime: ms(2500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'element-1',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'element-1',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-a.mp4',
            scrubStoreKey: 'clip-1',
            sourceWidth: 1920,
            sourceHeight: 1080,
          ),
          transform: const LiveScrubSurfaceTransform(
            positionX: 120,
            positionY: -30,
            scaleX: 1.1,
            scaleY: 0.9,
            rotationRadians: math.pi / 4,
          ),
          opacity: 0.8,
          effects: const <LiveScrubEffectBinding>[
            LiveScrubEffectBinding(
              id: 'gaussianBlur',
              rendererValue: 5.0,
              rendererUnit: MasterValueUnit.shaderSigmaPx,
            ),
          ],
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[
        'master_source_revision:msr:test-source',
        'master_render_graph_revision:mrg:test-graph',
      ],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'phase1_domain_contract_only',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    const sourceWindow = LiveScrubTimelineSourceWindow(
      targetId: 'element-1',
      timelineStartMs: 1000,
      timelineEndMs: 5000,
      sourceStartMs: 5000,
      sourceDurationMs: 4000,
      playbackRate: 1.5,
    );

    final first = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'element-1': sourceWindow,
      },
      capabilities: const LiveScrubDescriptorCapabilities(
        supportsSourceDimensions: true,
        supportsCanvasPlacement: true,
        supportsCrop: true,
        supportsTransformMatrix: true,
        supportsOpacity: true,
        supportsEffectProgramIds: true,
        supportedEffectProgramIds: <String>['gaussianBlur'],
        supportsDualSourceTransitionWindow: true,
        source: 'test-full-capabilities',
      ),
    );
    final second = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'element-1': sourceWindow,
      },
      capabilities: const LiveScrubDescriptorCapabilities(
        supportsSourceDimensions: true,
        supportsCanvasPlacement: true,
        supportsCrop: true,
        supportsTransformMatrix: true,
        supportsOpacity: true,
        supportsEffectProgramIds: true,
        supportedEffectProgramIds: <String>['gaussianBlur'],
        supportsDualSourceTransitionWindow: true,
        source: 'test-full-capabilities',
      ),
    );

    expect(first.canProject, isTrue);
    expect(first.blockers, isEmpty);
    expect(first.descriptors.length, 1);

    final descriptor = first.descriptors.single;
    expect(descriptor.id, 'lsd:element-1:clip-1');
    expect(second.descriptors.single.id, descriptor.id);
    expect(descriptor.timelinePositionMs, 2500);
    expect(descriptor.sourcePositionMs, 7250);
    expect(descriptor.opacity, closeTo(0.8, 0.0001));
    expect(descriptor.effectProgramIds, contains('gaussianBlur'));
    expect(descriptor.transformMatrix3x3.length, 9);
    expect(descriptor.isValid, isTrue);
    expect(
      first.parityReport.latencyBudgetState,
      LiveScrubLatencyBudgetState.nativeMetricsUnavailable,
    );
    expect(first.rendererPresentationProof.requestedRootTimeMs, 2500);
    expect(
        first.rendererPresentationProof.requestedFrameIndex, time.frameIndex);
    expect(first.rendererPresentationProof.nativePresentationAck, isFalse);
    expect(
      first.rendererPresentationProof.matchState,
      RendererPresentationMatchState.pendingNativeAck,
    );
    expect(
      first.rendererPresentationProof.sourceRevision,
      'msr:test-source',
    );
    expect(
      first.rendererPresentationProof.renderGraphRevision,
      'mrg:test-graph',
    );
  });

  test('reports blockers when source window is missing', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(5000),
      initialTime: ms(1500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'layer-1',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'layer-1',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-b.mp4',
          ),
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'phase1_domain_contract_only',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    final result = projection.project(program: program);
    expect(result.canProject, isFalse);
    expect(result.blockers, contains('missing_source_window:layer-1'));
    expect(result.descriptors.single.isValid, isFalse);
    expect(
      result.rendererPresentationProof.matchState,
      RendererPresentationMatchState.blocked,
    );
  });

  test('blocks unsupported placement and transform capabilities', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(5000),
      initialTime: ms(1500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'layer-2',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'layer-2',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-c.mp4',
            sourceWidth: 1280,
            sourceHeight: 720,
          ),
          transform: const LiveScrubSurfaceTransform(
            positionX: 60,
            positionY: 25,
            scaleX: 1.2,
            scaleY: 0.8,
            rotationRadians: 0.2,
          ),
          opacity: 0.7,
          effects: const <LiveScrubEffectBinding>[
            LiveScrubEffectBinding(
              id: 'gaussianBlur',
              rendererValue: 4.0,
              rendererUnit: MasterValueUnit.shaderSigmaPx,
            ),
          ],
          transitionRole: LiveScrubTransitionRole.outgoing,
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>['t-1'],
        hasRenderableTransitionPixels: false,
        reason: 'phase4_capability_preflight',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    const sourceWindow = LiveScrubTimelineSourceWindow(
      targetId: 'layer-2',
      timelineStartMs: 1000,
      timelineEndMs: 3000,
      sourceStartMs: 0,
      sourceDurationMs: 2000,
      playbackRate: 1.0,
    );
    const capabilities = LiveScrubDescriptorCapabilities(
      supportsSourceDimensions: false,
      supportsCanvasPlacement: false,
      supportsCrop: false,
      supportsTransformMatrix: false,
      supportsOpacity: false,
      supportsEffectProgramIds: false,
      supportsDualSourceTransitionWindow: false,
      source: 'native-capability-test',
    );

    final result = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'layer-2': sourceWindow,
      },
      capabilities: capabilities,
    );

    expect(result.canProject, isFalse);
    expect(
      result.blockers,
      contains('native_missing_source_dimensions_capability'),
    );
    expect(
      result.blockers,
      contains('native_missing_canvas_placement_capability'),
    );
    expect(
      result.blockers,
      contains('native_missing_transform_matrix_capability'),
    );
    expect(result.blockers, contains('native_missing_opacity_capability'));
    expect(
      result.blockers,
      contains('native_missing_effect_programs_capability'),
    );
    expect(
      result.blockers,
      contains('native_missing_dual_source_transition_window_capability'),
    );
    expect(
      result.descriptors.single.debugReasons,
      contains('native_capabilities:native-capability-test'),
    );
  });

  test('blocks unsupported effect programs when capability catalog rejects id',
      () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(5000),
      initialTime: ms(1500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'layer-3',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'layer-3',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-d.mp4',
          ),
          effects: const <LiveScrubEffectBinding>[
            LiveScrubEffectBinding(
              id: 'motionBlur',
              rendererValue: 8.0,
              rendererUnit: MasterValueUnit.shaderSigmaPx,
            ),
          ],
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'phase5_effect_catalog_preflight',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    const sourceWindow = LiveScrubTimelineSourceWindow(
      targetId: 'layer-3',
      timelineStartMs: 1000,
      timelineEndMs: 3000,
      sourceStartMs: 0,
      sourceDurationMs: 2000,
      playbackRate: 1.0,
    );
    const capabilities = LiveScrubDescriptorCapabilities(
      supportsSourceDimensions: true,
      supportsCanvasPlacement: true,
      supportsCrop: true,
      supportsTransformMatrix: true,
      supportsOpacity: true,
      supportsEffectProgramIds: true,
      supportedEffectProgramIds: <String>['opacity', 'gaussianBlur'],
      supportsDualSourceTransitionWindow: false,
      source: 'native-effect-catalog',
    );

    final result = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'layer-3': sourceWindow,
      },
      capabilities: capabilities,
    );

    expect(result.canProject, isFalse);
    expect(result.blockers, contains('unsupported_effect_program:motionBlur'));
  });

  test('projects transition window progress inside real window', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(8000),
      initialTime: ms(2500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'layer-4',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'layer-4',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-e.mp4',
          ),
          transitionRole: LiveScrubTransitionRole.outgoing,
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>['tr-4'],
        hasRenderableTransitionPixels: false,
        reason: 'phase6_transition_window_preflight',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    const sourceWindow = LiveScrubTimelineSourceWindow(
      targetId: 'layer-4',
      timelineStartMs: 1000,
      timelineEndMs: 7000,
      sourceStartMs: 0,
      sourceDurationMs: 6000,
      playbackRate: 1.0,
    );
    const transitionWindow = LiveScrubTransitionTimelineWindow(
      targetId: 'layer-4',
      transitionId: 'tr-4',
      timelineStartMs: 2000,
      timelineEndMs: 3000,
    );
    const capabilities = LiveScrubDescriptorCapabilities(
      supportsSourceDimensions: true,
      supportsCanvasPlacement: true,
      supportsCrop: true,
      supportsTransformMatrix: true,
      supportsOpacity: true,
      supportsEffectProgramIds: true,
      supportedEffectProgramIds: <String>[],
      supportsDualSourceTransitionWindow: true,
      source: 'native-transition-window',
    );

    final result = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'layer-4': sourceWindow,
      },
      transitionWindowsByTargetId: <String, LiveScrubTransitionTimelineWindow>{
        'layer-4': transitionWindow,
      },
      capabilities: capabilities,
    );

    expect(result.canProject, isTrue);
    final descriptor = result.descriptors.single;
    expect(descriptor.transitionId, 'tr-4');
    expect(descriptor.transitionTimelineStartMs, 2000);
    expect(descriptor.transitionTimelineEndMs, 3000);
    expect(descriptor.transitionProgress, closeTo(0.5, 0.0001));
  });

  test(
      'blocks transition rendering when timeline is outside real transition window',
      () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(8000),
      initialTime: ms(3500),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'layer-5',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'layer-5',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-f.mp4',
          ),
          transitionRole: LiveScrubTransitionRole.incoming,
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>['tr-5'],
        hasRenderableTransitionPixels: false,
        reason: 'phase6_transition_window_preflight',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    const sourceWindow = LiveScrubTimelineSourceWindow(
      targetId: 'layer-5',
      timelineStartMs: 1000,
      timelineEndMs: 7000,
      sourceStartMs: 0,
      sourceDurationMs: 6000,
      playbackRate: 1.0,
    );
    const transitionWindow = LiveScrubTransitionTimelineWindow(
      targetId: 'layer-5',
      transitionId: 'tr-5',
      timelineStartMs: 2000,
      timelineEndMs: 3000,
    );
    const capabilities = LiveScrubDescriptorCapabilities(
      supportsSourceDimensions: true,
      supportsCanvasPlacement: true,
      supportsCrop: true,
      supportsTransformMatrix: true,
      supportsOpacity: true,
      supportsEffectProgramIds: false,
      supportsDualSourceTransitionWindow: true,
      source: 'native-transition-window',
    );

    final result = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'layer-5': sourceWindow,
      },
      transitionWindowsByTargetId: <String, LiveScrubTransitionTimelineWindow>{
        'layer-5': transitionWindow,
      },
      capabilities: capabilities,
    );

    expect(result.canProject, isFalse);
    expect(
      result.blockers,
      contains('transition_timeline_outside_window:layer-5'),
    );
    expect(
      result.parityReport.transitionParityState,
      LiveScrubTransitionParityState.blocked,
    );
  });

  test('reports latency budget within limits when native metrics are healthy',
      () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(8000),
      initialTime: ms(2400),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.liveScrub,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final program = LiveScrubVisualProgram(
      time: time,
      surfaces: <LiveScrubVisualSurface>[
        LiveScrubVisualSurface(
          targetId: 'layer-6',
          sourceKind: LiveScrubSourceKind.video,
          source: const LiveScrubSurfaceSource(
            targetId: 'layer-6',
            kind: LiveScrubSourceKind.video,
            sourceUri: '/media/video-g.mp4',
          ),
          blockers: const <String>[],
        ),
      ],
      blockers: const <String>[],
      diagnostics: const <String>[],
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: const <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'phase7_latency_preflight',
      ),
    );
    const projection = MasterLiveScrubDescriptorProjection();
    const sourceWindow = LiveScrubTimelineSourceWindow(
      targetId: 'layer-6',
      timelineStartMs: 1000,
      timelineEndMs: 7000,
      sourceStartMs: 0,
      sourceDurationMs: 6000,
      playbackRate: 1.0,
    );
    const capabilities = LiveScrubDescriptorCapabilities(
      supportsSourceDimensions: true,
      supportsCanvasPlacement: true,
      supportsCrop: true,
      supportsTransformMatrix: true,
      supportsOpacity: true,
      supportsEffectProgramIds: false,
      supportsDualSourceTransitionWindow: false,
      supportsLatencyMetrics: true,
      source: 'native-latency-test',
    );
    const performance = LiveScrubPerformanceSnapshot(
      frameRequestRateFps: 45,
      nativeDecodeRebindLatencyMs: 18,
      framePresentationLatencyMs: 12,
      droppedFrameCount: 0,
      crossSourceWarmupReady: true,
      memoryPressureLevel: 'normal',
    );

    final result = projection.project(
      program: program,
      sourceWindowsByTargetId: <String, LiveScrubTimelineSourceWindow>{
        'layer-6': sourceWindow,
      },
      capabilities: capabilities,
      performanceSnapshot: performance,
    );

    expect(result.canProject, isTrue);
    expect(
      result.parityReport.latencyBudgetState,
      LiveScrubLatencyBudgetState.withinBudget,
    );
    expect(
      result.parityReport.performanceSnapshot.descriptorProjectionLatencyUs,
      isNotNull,
    );
  });
}
