import '../models/master_render_graph_models.dart';
import '../models/master_renderer_adapter_models.dart';
import '../models/master_visual_program_models.dart';
import 'master_renderer_mode_adapter.dart';

class MasterRendererFrameAdapters {
  const MasterRendererFrameAdapters({
    this.modeAdapter = const MasterRendererModeAdapter(),
  });

  final MasterRendererModeAdapter modeAdapter;

  MasterRendererFrameResult projectPreview({
    required MasterVisualProgram program,
    required MasterRenderGraph renderGraph,
    required String requestId,
    required String sourceRevision,
    required String surfaceId,
    bool nativePresentationAck = false,
    int? presentedRootTimeMs,
    int? presentedFrameIndex,
    int? presentedCommitFrameNumber,
    List<String> presentedSourceIds = const <String>[],
    int? presentationTimestampUs,
  }) {
    return modeAdapter.project(
      mode: MasterRendererAdapterMode.preview,
      program: program,
      renderGraph: renderGraph,
      requestId: requestId,
      sourceRevision: sourceRevision,
      surfaceId: surfaceId,
      nativePresentationAck: nativePresentationAck,
      presentedRootTimeMs: presentedRootTimeMs,
      presentedFrameIndex: presentedFrameIndex,
      presentedCommitFrameNumber: presentedCommitFrameNumber,
      presentedSourceIds: presentedSourceIds,
      presentationTimestampUs: presentationTimestampUs,
    );
  }

  MasterRendererFrameResult projectLiveScrub({
    required MasterVisualProgram program,
    required MasterRenderGraph renderGraph,
    required String requestId,
    required String sourceRevision,
    required String surfaceId,
    bool nativePresentationAck = false,
    int? presentedRootTimeMs,
    int? presentedFrameIndex,
    int? presentedCommitFrameNumber,
    List<String> presentedSourceIds = const <String>[],
    int? presentationTimestampUs,
  }) {
    return modeAdapter.project(
      mode: MasterRendererAdapterMode.liveScrub,
      program: program,
      renderGraph: renderGraph,
      requestId: requestId,
      sourceRevision: sourceRevision,
      surfaceId: surfaceId,
      nativePresentationAck: nativePresentationAck,
      presentedRootTimeMs: presentedRootTimeMs,
      presentedFrameIndex: presentedFrameIndex,
      presentedCommitFrameNumber: presentedCommitFrameNumber,
      presentedSourceIds: presentedSourceIds,
      presentationTimestampUs: presentationTimestampUs,
    );
  }

  MasterRendererFrameResult projectPlayback({
    required MasterVisualProgram program,
    required MasterRenderGraph renderGraph,
    required String requestId,
    required String sourceRevision,
    required String surfaceId,
    bool nativePresentationAck = false,
    int? presentedRootTimeMs,
    int? presentedFrameIndex,
    int? presentedCommitFrameNumber,
    List<String> presentedSourceIds = const <String>[],
    int? presentationTimestampUs,
  }) {
    return modeAdapter.project(
      mode: MasterRendererAdapterMode.playback,
      program: program,
      renderGraph: renderGraph,
      requestId: requestId,
      sourceRevision: sourceRevision,
      surfaceId: surfaceId,
      nativePresentationAck: nativePresentationAck,
      presentedRootTimeMs: presentedRootTimeMs,
      presentedFrameIndex: presentedFrameIndex,
      presentedCommitFrameNumber: presentedCommitFrameNumber,
      presentedSourceIds: presentedSourceIds,
      presentationTimestampUs: presentationTimestampUs,
    );
  }

  MasterRendererFrameResult projectExport({
    required MasterVisualProgram program,
    required MasterRenderGraph renderGraph,
    required String requestId,
    required String sourceRevision,
    required String surfaceId,
    bool nativePresentationAck = false,
    int? presentedRootTimeMs,
    int? presentedFrameIndex,
    int? presentedCommitFrameNumber,
    List<String> presentedSourceIds = const <String>[],
    int? presentationTimestampUs,
  }) {
    return modeAdapter.project(
      mode: MasterRendererAdapterMode.export,
      program: program,
      renderGraph: renderGraph,
      requestId: requestId,
      sourceRevision: sourceRevision,
      surfaceId: surfaceId,
      nativePresentationAck: nativePresentationAck,
      presentedRootTimeMs: presentedRootTimeMs,
      presentedFrameIndex: presentedFrameIndex,
      presentedCommitFrameNumber: presentedCommitFrameNumber,
      presentedSourceIds: presentedSourceIds,
      presentationTimestampUs: presentationTimestampUs,
    );
  }
}
