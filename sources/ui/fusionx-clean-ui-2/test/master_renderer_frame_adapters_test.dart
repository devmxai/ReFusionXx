import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/master_live_scrub_descriptor_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_render_graph_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_renderer_adapter_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_time_models.dart';
import 'package:refusion_app/features/editor/domain/models/master_visual_program_models.dart';
import 'package:refusion_app/features/editor/domain/services/master_render_graph_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/master_renderer_frame_adapters.dart';
import 'package:refusion_app/features/editor/domain/services/master_renderer_mode_adapter.dart';
import 'package:refusion_app/features/editor/domain/services/timeline_clock_coordinator.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';

void main() {
  TimelineTime ms(int value) => TimelineTime.fromMilliseconds(value);

  MasterVisualProgram _program(MasterRenderMode mode) {
    final clock = TimelineClockCoordinator(
      timelineDuration: ms(9000),
      initialTime: ms(1800),
    );
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock.snapshot,
      frameRate: 30,
      renderMode: mode,
      sourceScope: MasterTimeScope.rootComposition,
    );
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
        hasRenderableTransitionPixels: false,
        reason: 'test',
      ),
    );
  }

  MasterRenderGraph _graph(MasterVisualProgram program) {
    return const MasterRenderGraphAdapter().build(program: program);
  }

  test('mode adapter marks proof mismatched on stale presented frame', () {
    const adapter = MasterRendererModeAdapter();
    final program = _program(MasterRenderMode.playback);
    final graph = _graph(program);
    final result = adapter.project(
      mode: MasterRendererAdapterMode.playback,
      program: program,
      renderGraph: graph,
      requestId: 'req-playback',
      sourceRevision: 'src:1',
      surfaceId: 'stage5-playback-surface',
      nativePresentationAck: true,
      presentedRootTimeMs: program.time.rootTime.inMilliseconds + 33,
      presentedFrameIndex: program.time.frameIndex,
      presentedCommitFrameNumber: program.time.commitFrameNumber,
      presentedSourceIds: const <String>['layer-a'],
    );

    expect(result.proof.matchState, RendererPresentationMatchState.mismatched);
    expect(result.proof.matchReason, 'presented_root_time_mismatch');
    expect(result.canPresentTruthfully, isFalse);
  });

  test('mode adapter marks proof matched only with exact source/frame parity',
      () {
    const adapter = MasterRendererModeAdapter();
    final program = _program(MasterRenderMode.preview);
    final graph = _graph(program);
    final result = adapter.project(
      mode: MasterRendererAdapterMode.preview,
      program: program,
      renderGraph: graph,
      requestId: 'req-preview',
      sourceRevision: 'src:2',
      surfaceId: 'stage5-preview-surface',
      nativePresentationAck: true,
      presentedRootTimeMs: program.time.rootTime.inMilliseconds,
      presentedFrameIndex: program.time.frameIndex,
      presentedCommitFrameNumber: program.time.commitFrameNumber,
      presentedSourceIds: const <String>['layer-a'],
    );

    expect(result.proof.matchState, RendererPresentationMatchState.matched);
    expect(result.canPresentTruthfully, isTrue);
  });

  test('frame adapters expose preview/liveScrub/playback/export modes', () {
    const adapters = MasterRendererFrameAdapters();
    final previewProgram = _program(MasterRenderMode.preview);
    final liveProgram = _program(MasterRenderMode.liveScrub);
    final playbackProgram = _program(MasterRenderMode.playback);
    final exportProgram = _program(MasterRenderMode.export);

    final preview = adapters.projectPreview(
      program: previewProgram,
      renderGraph: _graph(previewProgram),
      requestId: 'preview',
      sourceRevision: 'src:p',
      surfaceId: 'stage5-preview-surface',
    );
    final liveScrub = adapters.projectLiveScrub(
      program: liveProgram,
      renderGraph: _graph(liveProgram),
      requestId: 'live',
      sourceRevision: 'src:l',
      surfaceId: 'stage5-scrub-surface',
    );
    final playback = adapters.projectPlayback(
      program: playbackProgram,
      renderGraph: _graph(playbackProgram),
      requestId: 'playback',
      sourceRevision: 'src:b',
      surfaceId: 'stage5-playback-surface',
    );
    final export = adapters.projectExport(
      program: exportProgram,
      renderGraph: _graph(exportProgram),
      requestId: 'export',
      sourceRevision: 'src:e',
      surfaceId: 'stage5-export-surface',
    );

    expect(preview.mode, MasterRendererAdapterMode.preview);
    expect(liveScrub.mode, MasterRendererAdapterMode.liveScrub);
    expect(playback.mode, MasterRendererAdapterMode.playback);
    expect(export.mode, MasterRendererAdapterMode.export);
  });
}
