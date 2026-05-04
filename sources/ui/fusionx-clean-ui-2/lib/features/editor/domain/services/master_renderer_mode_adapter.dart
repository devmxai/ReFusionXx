import '../models/master_live_scrub_descriptor_models.dart';
import '../models/master_render_graph_models.dart';
import '../models/master_renderer_adapter_models.dart';
import '../models/master_visual_program_models.dart';

class MasterRendererModeAdapter {
  const MasterRendererModeAdapter();

  RendererPresentationProof buildProof({
    required MasterRendererAdapterMode mode,
    required int requestedRootTimeMs,
    required int requestedFrameIndex,
    required int requestedCommitFrameNumber,
    required List<String> requestedSourceIds,
    required String requestId,
    required String sourceRevision,
    required String renderGraphRevision,
    required List<String> blockers,
    required String surfaceId,
    bool nativePresentationAck = false,
    int? presentedRootTimeMs,
    int? presentedFrameIndex,
    int? presentedCommitFrameNumber,
    List<String> presentedSourceIds = const <String>[],
    int? presentationTimestampUs,
  }) {
    final blockerSet = blockers.toSet();
    return RendererPresentationProof(
      requestedRootTimeMs: requestedRootTimeMs,
      requestedFrameIndex: requestedFrameIndex,
      requestedCommitFrameNumber: requestedCommitFrameNumber,
      requestedSourceIds: requestedSourceIds,
      requestId: requestId,
      sourceRevision: sourceRevision,
      renderGraphRevision: renderGraphRevision,
      rendererMode: mode.name,
      blockers: blockers,
      presentedRootTimeMs: presentedRootTimeMs,
      presentedFrameIndex: presentedFrameIndex,
      presentedCommitFrameNumber: presentedCommitFrameNumber,
      presentedSourceIds: presentedSourceIds,
      surfaceId: surfaceId,
      presentationTimestampUs: presentationTimestampUs,
      nativePresentationAck: nativePresentationAck,
      matchState: _resolveMatchState(
        blockers: blockerSet,
        nativePresentationAck: nativePresentationAck,
      ),
      matchReason: _resolveMatchReason(
        mode: mode,
        blockers: blockerSet,
        nativePresentationAck: nativePresentationAck,
      ),
    );
  }

  MasterRendererFrameResult project({
    required MasterRendererAdapterMode mode,
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
    final requestedSourceIds = <String>[
      for (final surface in program.surfaces)
        if (surface.source != null &&
            surface.source!.sourceUri.trim().isNotEmpty)
          surface.targetId,
    ];
    final blockers = <String>{
      ...program.blockers,
      ...renderGraph.blockers,
    };

    final renderGraphRevision = renderGraph.revision;
    final baseProof = buildProof(
      mode: mode,
      requestedRootTimeMs: program.time.rootTime.inMilliseconds,
      requestedFrameIndex: program.time.frameIndex,
      requestedCommitFrameNumber: program.time.commitFrameNumber,
      requestedSourceIds: requestedSourceIds,
      requestId: requestId,
      sourceRevision: sourceRevision,
      renderGraphRevision: renderGraphRevision,
      blockers: blockers.toList(growable: false),
      surfaceId: surfaceId,
      nativePresentationAck: nativePresentationAck,
      presentedRootTimeMs: presentedRootTimeMs,
      presentedFrameIndex: presentedFrameIndex,
      presentedCommitFrameNumber: presentedCommitFrameNumber,
      presentedSourceIds: presentedSourceIds,
      presentationTimestampUs: presentationTimestampUs,
    );

    return MasterRendererFrameResult(
      mode: mode,
      proof: baseProof,
      blockers: blockers.toList(growable: false),
      diagnostics: <String>[
        ...program.diagnostics,
        ...renderGraph.diagnostics,
        'renderer_mode:${mode.name}',
        'render_graph_revision:$renderGraphRevision',
      ],
    );
  }

  RendererPresentationMatchState _resolveMatchState({
    required Set<String> blockers,
    required bool nativePresentationAck,
  }) {
    if (blockers.isNotEmpty) {
      return RendererPresentationMatchState.blocked;
    }
    if (nativePresentationAck) {
      return RendererPresentationMatchState.matched;
    }
    return RendererPresentationMatchState.pendingNativeAck;
  }

  String _resolveMatchReason({
    required MasterRendererAdapterMode mode,
    required Set<String> blockers,
    required bool nativePresentationAck,
  }) {
    if (blockers.isNotEmpty) {
      return 'renderer_blocked_by_master_chain';
    }
    if (nativePresentationAck) {
      return 'renderer_acknowledged';
    }
    return 'awaiting_${mode.name}_native_ack';
  }
}
