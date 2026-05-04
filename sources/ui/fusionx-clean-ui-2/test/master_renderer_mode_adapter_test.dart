import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_render_graph_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_adapter_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_contract_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_renderer_mode_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MasterVisualProgram _program(MasterTimeSnapshot time) {
    return MasterVisualProgram(
      time: time,
      surfaces: <MasterVisualSurface>[
        MasterVisualSurface(
          targetId: 'layer-a',
          sourceKind: MasterVisualSourceKind.video,
          source: const MasterVisualSourceBinding(
            targetId: 'layer-a',
            kind: MasterVisualSourceKind.video,
            sourceUri: '/media/a.mp4',
          ),
        ),
      ],
      transitionState: MasterVisualTransitionState(
        activeTransitionIds: const <String>[],
        hasRenderableTransitionPixels: false,
        reason: 'none',
      ),
    );
  }

  MasterRenderGraph _graph(MasterTimeSnapshot time,
      {List<String> blockers = const []}) {
    return MasterRenderGraph(
      revision: 'mrg:test',
      rootTimeMs: time.rootTime.inMilliseconds,
      frameIndex: time.frameIndex,
      renderMode: time.renderMode,
      outputWidth: 1080,
      outputHeight: 1920,
      colorProfile: 'srgb',
      outputNodeId: 'output:test',
      blockers: blockers,
    );
  }

  test('returns matched proof when ack exists and no blockers', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(5000),
      initialTime: ms(1200),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.preview,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final adapter = MasterRendererModeAdapter();
    final result = adapter.project(
      mode: MasterRendererAdapterMode.preview,
      program: _program(time),
      renderGraph: _graph(time),
      requestId: 'req-1',
      sourceRevision: 'msr:1',
      surfaceId: 'surface-1',
      nativePresentationAck: true,
      presentedRootTimeMs: 1200,
      presentedFrameIndex: time.frameIndex,
      presentedCommitFrameNumber: time.commitFrameNumber,
      presentedSourceIds: const <String>['layer-a'],
    );
    expect(result.proof.matchState, RendererPresentationMatchState.matched);
    expect(result.canPresentTruthfully, isTrue);
  });

  test('returns blocked proof when blockers exist', () {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(5000),
      initialTime: ms(1200),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: MasterRenderMode.playback,
      sourceScope: MasterTimeScope.rootComposition,
    );
    final adapter = MasterRendererModeAdapter();
    final result = adapter.project(
      mode: MasterRendererAdapterMode.playback,
      program: _program(time),
      renderGraph: _graph(
        time,
        blockers: const <String>['missing_source_binding:layer-a'],
      ),
      requestId: 'req-2',
      sourceRevision: 'msr:2',
      surfaceId: 'surface-2',
      nativePresentationAck: true,
    );
    expect(result.proof.matchState, RendererPresentationMatchState.blocked);
    expect(result.canPresentTruthfully, isFalse);
  });

  test('buildProof applies live scrub match contract', () {
    final adapter = MasterRendererModeAdapter();
    final pending = adapter.buildProof(
      mode: MasterRendererAdapterMode.liveScrub,
      requestedRootTimeMs: 1000,
      requestedFrameIndex: 30,
      requestedCommitFrameNumber: 2,
      requestedSourceIds: const <String>['layer-a'],
      requestId: 'req-live-1',
      sourceRevision: 'msr:live-1',
      renderGraphRevision: 'mrg:live-1',
      blockers: const <String>[],
      surfaceId: MasterRendererContracts.liveScrubDescriptorSurfaceId,
      nativePresentationAck: false,
    );

    expect(
      pending.matchState,
      RendererPresentationMatchState.pendingNativeAck,
    );
    expect(pending.matchReason, 'awaiting_liveScrub_native_ack');

    final blocked = adapter.buildProof(
      mode: MasterRendererAdapterMode.liveScrub,
      requestedRootTimeMs: 1000,
      requestedFrameIndex: 30,
      requestedCommitFrameNumber: 2,
      requestedSourceIds: const <String>['layer-a'],
      requestId: 'req-live-2',
      sourceRevision: 'msr:live-2',
      renderGraphRevision: 'mrg:live-2',
      blockers: const <String>['missing_source_window:layer-a'],
      surfaceId: MasterRendererContracts.liveScrubDescriptorSurfaceId,
      nativePresentationAck: false,
    );

    expect(blocked.matchState, RendererPresentationMatchState.blocked);
    expect(blocked.matchReason, 'renderer_blocked_by_master_chain');
  });
}
