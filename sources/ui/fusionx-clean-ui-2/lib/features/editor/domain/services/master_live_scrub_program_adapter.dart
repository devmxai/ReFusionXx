import '../models/master_frame_evaluation_models.dart';
import '../models/master_live_scrub_visual_program_models.dart';
import '../models/master_render_graph_models.dart';
import '../models/master_renderer_adapter_models.dart';
import '../models/master_renderer_contract_models.dart';
import '../models/master_visual_program_models.dart';
import '../models/professional_motion_animation_models.dart';
import 'master_render_graph_adapter.dart';
import 'master_renderer_frame_adapters.dart';
import 'master_visual_program_adapter.dart';

class MasterLiveScrubProgramAdapter {
  const MasterLiveScrubProgramAdapter({
    this.masterVisualProgramAdapter = const MasterVisualProgramAdapter(),
    this.masterRenderGraphAdapter = const MasterRenderGraphAdapter(),
    this.masterRendererFrameAdapters = const MasterRendererFrameAdapters(),
  });

  final MasterVisualProgramAdapter masterVisualProgramAdapter;
  final MasterRenderGraphAdapter masterRenderGraphAdapter;
  final MasterRendererFrameAdapters masterRendererFrameAdapters;

  LiveScrubVisualProgram build({
    required MasterFrameEvaluation frame,
    Map<String, LiveScrubSurfaceSource> sourcesByTargetId =
        const <String, LiveScrubSurfaceSource>{},
    Map<String, LiveScrubTransitionRole> transitionRolesByTargetId =
        const <String, LiveScrubTransitionRole>{},
    Iterable<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
  }) {
    final masterProgram = masterVisualProgramAdapter.build(
      frame: frame,
      sourcesByTargetId: _mapSources(sourcesByTargetId),
      transitionRolesByTargetId: _mapRoles(transitionRolesByTargetId),
      channels: channels,
    );
    final renderGraph = masterRenderGraphAdapter.build(program: masterProgram);
    final rendererFrameResult = masterRendererFrameAdapters.projectLiveScrub(
      program: masterProgram,
      renderGraph: renderGraph,
      requestId: MasterRendererContracts.liveScrubProgramRequestId(frame.time),
      sourceRevision: _buildSourceRevision(masterProgram),
      surfaceId: MasterRendererContracts.liveScrubRuntimeBridgeSurfaceId,
      nativePresentationAck: false,
    );
    return _projectFromMasterVisualProgram(
      masterProgram,
      renderGraph,
      rendererFrameResult,
    );
  }

  Map<String, MasterVisualSourceBinding> _mapSources(
    Map<String, LiveScrubSurfaceSource> sourcesByTargetId,
  ) {
    return <String, MasterVisualSourceBinding>{
      for (final entry in sourcesByTargetId.entries)
        entry.key: MasterVisualSourceBinding(
          targetId: entry.value.targetId,
          kind: _sourceKindToMaster(entry.value.kind),
          sourceUri: entry.value.sourceUri,
          scrubStoreKey: entry.value.scrubStoreKey,
          sourceWidth: entry.value.sourceWidth,
          sourceHeight: entry.value.sourceHeight,
        ),
    };
  }

  Map<String, MasterVisualTransitionRole> _mapRoles(
    Map<String, LiveScrubTransitionRole> transitionRolesByTargetId,
  ) {
    return <String, MasterVisualTransitionRole>{
      for (final entry in transitionRolesByTargetId.entries)
        entry.key: _roleToMaster(entry.value),
    };
  }

  LiveScrubVisualProgram _projectFromMasterVisualProgram(
    MasterVisualProgram masterProgram,
    MasterRenderGraph renderGraph,
    MasterRendererFrameResult rendererFrameResult,
  ) {
    final sourceRevision = _buildSourceRevision(masterProgram);
    final blockers = <String>{
      ...masterProgram.blockers,
      ...renderGraph.blockers,
      ...rendererFrameResult.blockers,
    };
    final diagnostics = <String>[
      ...masterProgram.diagnostics,
      ...renderGraph.diagnostics,
      ...rendererFrameResult.diagnostics,
      'renderer_frame_match_state:${rendererFrameResult.proof.matchState.name}',
      'renderer_frame_match_reason:${rendererFrameResult.proof.matchReason}',
      'renderer_frame_request_id:${rendererFrameResult.proof.requestId}',
      'master_render_graph_output:${renderGraph.outputNodeId}',
    ];
    return LiveScrubVisualProgram(
      time: masterProgram.time,
      surfaces: <LiveScrubVisualSurface>[
        for (final surface in masterProgram.surfaces)
          LiveScrubVisualSurface(
            targetId: surface.targetId,
            sourceKind: _sourceKindFromMaster(surface.sourceKind),
            source: surface.source == null
                ? null
                : LiveScrubSurfaceSource(
                    targetId: surface.source!.targetId,
                    kind: _sourceKindFromMaster(surface.source!.kind),
                    sourceUri: surface.source!.sourceUri,
                    scrubStoreKey: surface.source!.scrubStoreKey,
                    sourceWidth: surface.source!.sourceWidth,
                    sourceHeight: surface.source!.sourceHeight,
                  ),
            transitionRole: _roleFromMaster(surface.transitionRole),
            transform: LiveScrubSurfaceTransform(
              positionX: surface.transform.positionX,
              positionY: surface.transform.positionY,
              scaleX: surface.transform.scaleX,
              scaleY: surface.transform.scaleY,
              rotationRadians: surface.transform.rotationRadians,
            ),
            opacity: surface.opacity,
            motionBlur: surface.motionBlur,
            effects: <LiveScrubEffectBinding>[
              for (final effect in surface.effects)
                LiveScrubEffectBinding(
                  id: effect.id,
                  rendererValue: effect.rendererValue,
                  rendererUnit: effect.rendererUnit,
                ),
            ],
            blockers: surface.blockers,
          ),
      ],
      blockers: blockers.toList(growable: false),
      diagnostics: diagnostics,
      sourceRevision: sourceRevision,
      renderGraphRevision: renderGraph.revision,
      transitionState: LiveScrubTransitionState(
        activeTransitionIds: masterProgram.transitionState.activeTransitionIds,
        hasRenderableTransitionPixels:
            masterProgram.transitionState.hasRenderableTransitionPixels,
        reason: masterProgram.transitionState.reason,
      ),
    );
  }

  String _buildSourceRevision(MasterVisualProgram program) {
    final signature = <Object?>[
      for (final surface in [...program.surfaces]..sort((left, right) =>
          left.targetId.compareTo(right.targetId))) ...<Object?>[
        surface.targetId,
        surface.sourceKind.name,
        surface.source?.sourceUri,
        surface.source?.scrubStoreKey,
        surface.source?.sourceWidth,
        surface.source?.sourceHeight,
      ],
    ];
    final hash = Object.hashAll(signature).toUnsigned(32).toRadixString(16);
    return 'msr:$hash';
  }

  MasterVisualSourceKind _sourceKindToMaster(LiveScrubSourceKind kind) {
    switch (kind) {
      case LiveScrubSourceKind.video:
        return MasterVisualSourceKind.video;
      case LiveScrubSourceKind.image:
        return MasterVisualSourceKind.image;
      case LiveScrubSourceKind.unknown:
        return MasterVisualSourceKind.unknown;
    }
  }

  LiveScrubSourceKind _sourceKindFromMaster(MasterVisualSourceKind kind) {
    switch (kind) {
      case MasterVisualSourceKind.video:
        return LiveScrubSourceKind.video;
      case MasterVisualSourceKind.image:
        return LiveScrubSourceKind.image;
      case MasterVisualSourceKind.unknown:
        return LiveScrubSourceKind.unknown;
    }
  }

  MasterVisualTransitionRole _roleToMaster(LiveScrubTransitionRole role) {
    switch (role) {
      case LiveScrubTransitionRole.none:
        return MasterVisualTransitionRole.none;
      case LiveScrubTransitionRole.outgoing:
        return MasterVisualTransitionRole.outgoing;
      case LiveScrubTransitionRole.incoming:
        return MasterVisualTransitionRole.incoming;
      case LiveScrubTransitionRole.overlay:
        return MasterVisualTransitionRole.overlay;
      case LiveScrubTransitionRole.matte:
        return MasterVisualTransitionRole.matte;
    }
  }

  LiveScrubTransitionRole _roleFromMaster(MasterVisualTransitionRole role) {
    switch (role) {
      case MasterVisualTransitionRole.none:
        return LiveScrubTransitionRole.none;
      case MasterVisualTransitionRole.outgoing:
        return LiveScrubTransitionRole.outgoing;
      case MasterVisualTransitionRole.incoming:
        return LiveScrubTransitionRole.incoming;
      case MasterVisualTransitionRole.overlay:
        return LiveScrubTransitionRole.overlay;
      case MasterVisualTransitionRole.matte:
        return LiveScrubTransitionRole.matte;
    }
  }
}
