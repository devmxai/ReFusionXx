import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import 'professional_video_transition_compositor.dart';

enum ProfessionalVideoTransitionReadinessStageId {
  capabilityGate,
  renderSession,
  sourceBinding,
  sourceMediaProbe,
  frameSamples,
  frameDecode,
  dualVideoDecoder,
  temporalAccumulator,
  mirrorEdgeTiling,
  renderPassGraph,
  renderGraphExecution,
  outputSurface,
  surfaceRenderer,
  frameRenderCommands,
  parityOutputs,
}

@immutable
class ProfessionalVideoTransitionReadinessStage {
  const ProfessionalVideoTransitionReadinessStage({
    required this.id,
    required this.label,
    required this.canPlan,
    required this.canAdvance,
    this.blockers = const <String>[],
    this.issues = const <Map<String, Object?>>[],
  });

  final ProfessionalVideoTransitionReadinessStageId id;
  final String label;
  final bool canPlan;
  final bool canAdvance;
  final List<String> blockers;
  final List<Map<String, Object?>> issues;
}

@immutable
class ProfessionalVideoTransitionReadinessReport {
  const ProfessionalVideoTransitionReadinessReport({
    required this.definitionId,
    required this.transitionId,
    required this.timelineTime,
    required this.stages,
  });

  final String definitionId;
  final String transitionId;
  final TimelineTime timelineTime;
  final List<ProfessionalVideoTransitionReadinessStage> stages;

  bool get canExposeTransition =>
      stages.isNotEmpty &&
      stages.every((stage) => stage.canPlan && stage.canAdvance);

  List<ProfessionalVideoTransitionReadinessStage> get blockingStages {
    return List<ProfessionalVideoTransitionReadinessStage>.unmodifiable(
      stages.where((stage) => !stage.canPlan || !stage.canAdvance),
    );
  }

  ProfessionalVideoTransitionReadinessStage? get firstBlockingStage {
    for (final stage in stages) {
      if (!stage.canPlan || !stage.canAdvance) {
        return stage;
      }
    }
    return null;
  }
}

class ProfessionalVideoTransitionReadinessPreflight {
  const ProfessionalVideoTransitionReadinessPreflight({
    required ProfessionalVideoTransitionCompositorClient client,
  }) : _client = client;

  final ProfessionalVideoTransitionCompositorClient _client;

  Future<ProfessionalVideoTransitionReadinessReport> run({
    required ProfessionalVideoTransitionRenderPlan plan,
    required TimelineTime timelineTime,
  }) async {
    final stages = <ProfessionalVideoTransitionReadinessStage>[];

    final capabilities = await _client.loadCapabilities();
    stages.add(_capabilityStage(capabilities));

    final prepare = await _client.prepareRenderPlan(plan);
    stages.add(_prepareStage(prepare));

    final sourceBinding = await _client.planVideoSourceBindings(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_sourceBindingStage(sourceBinding));

    final sourceProbe = await _client.planVideoSourceProbe(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_sourceProbeStage(sourceProbe));

    final frameSamples = await _client.planFrameSamples(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_frameSamplesStage(frameSamples));

    final frameDecode = await _client.planFrameDecodeRequests(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_frameDecodeStage(frameDecode));

    final decoderSession = await _client.planDualVideoDecoderSession(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_decoderSessionStage(decoderSession));

    final temporalAccumulator = await _client.planTemporalSampleAccumulator(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_temporalAccumulatorStage(temporalAccumulator));

    final mirrorEdgeTiling = await _client.planMirrorEdgeTiling(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_mirrorEdgeTilingStage(mirrorEdgeTiling));

    final renderPassGraph = await _client.planRenderPassGraph(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_renderPassGraphStage(renderPassGraph));

    final renderGraphExecution = await _client.planRenderGraphExecution(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_renderGraphExecutionStage(renderGraphExecution));

    final outputSurface = await _client.planOutputSurface(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_outputSurfaceStage(outputSurface));

    final surfaceRenderer = await _client.planSurfaceRenderer(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_surfaceRendererStage(surfaceRenderer));

    final frameRenderCommands = await _client.planFrameRenderCommands(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_frameRenderCommandsStage(frameRenderCommands));

    final parityOutputs = await _client.planParityOutputs(
      plan: plan,
      timelineTime: timelineTime,
    );
    stages.add(_parityOutputsStage(parityOutputs));

    return ProfessionalVideoTransitionReadinessReport(
      definitionId: plan.definitionId,
      transitionId: plan.transitionId,
      timelineTime: timelineTime,
      stages: List<ProfessionalVideoTransitionReadinessStage>.unmodifiable(
        stages,
      ),
    );
  }

  static ProfessionalVideoTransitionReadinessStage _capabilityStage(
    ProfessionalVideoTransitionCompositorCapabilities capabilities,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.capabilityGate,
      label: 'Native compositor capabilities',
      canPlan: true,
      canAdvance: capabilities.canExposeProfessionalVideoTransitions,
      blockers: capabilities.missingForProfessionalVideoTransitions,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _prepareStage(
    ProfessionalVideoTransitionCompositorPrepareResult result,
  ) {
    final blockers = <String>[
      ...result.missingCapabilities,
      if (!result.canRender && result.reason.isNotEmpty) result.reason,
    ];
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.renderSession,
      label: 'Strict native render session',
      canPlan: result.status !=
          ProfessionalVideoTransitionCompositorPrepareStatus.invalidRequest,
      canAdvance: result.canRender,
      blockers: List<String>.unmodifiable(blockers),
    );
  }

  static ProfessionalVideoTransitionReadinessStage _sourceBindingStage(
    ProfessionalVideoTransitionSourceBindingPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.sourceBinding,
      label: 'Concrete source URI binding',
      canPlan: result.canPlan,
      canAdvance: result.canBind,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canBind,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _sourceProbeStage(
    ProfessionalVideoTransitionSourceProbePlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.sourceMediaProbe,
      label: 'Real video source probe',
      canPlan: result.canPlan,
      canAdvance: result.canProbe,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canProbe,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _frameSamplesStage(
    ProfessionalVideoTransitionFrameSamplePlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.frameSamples,
      label: 'Live frame sample plan',
      canPlan: result.canPlan,
      canAdvance: result.canPlan,
      blockers: _blockers(
        reason: result.reason,
        issues: result.issues,
        includeReason: !result.canPlan,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _frameDecodeStage(
    ProfessionalVideoTransitionFrameDecodePlanResult result,
  ) {
    final canAdvance = result.canPlan &&
        result.requiresRealVideoFrame &&
        !result.allowThumbnailFallback &&
        !result.allowBoundaryFreeze &&
        result.decodeRequests.isNotEmpty &&
        result.decodeRequests.every((request) {
          return !request.allowThumbnailFallback &&
              !request.allowBoundaryFreeze &&
              request.sourceUri.trim().isNotEmpty;
        });
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.frameDecode,
      label: 'Exact frame decode requests',
      canPlan: result.canPlan,
      canAdvance: canAdvance,
      blockers: _blockers(
        reason: result.reason,
        issues: result.issues,
        includeReason: !canAdvance,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _decoderSessionStage(
    ProfessionalVideoTransitionDecoderSessionPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.dualVideoDecoder,
      label: 'Dual-video decoder session',
      canPlan: result.canPlan,
      canAdvance: result.canDecode,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canDecode,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _temporalAccumulatorStage(
    ProfessionalVideoTransitionTemporalAccumulatorPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.temporalAccumulator,
      label: 'Temporal shutter accumulator',
      canPlan: result.canPlan,
      canAdvance: result.canAccumulate,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canAccumulate,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _mirrorEdgeTilingStage(
    ProfessionalVideoTransitionMirrorEdgeTilingPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.mirrorEdgeTiling,
      label: 'Mirror-edge tiling',
      canPlan: result.canPlan,
      canAdvance: result.canTile,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canTile,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _renderPassGraphStage(
    ProfessionalVideoTransitionRenderPassGraphPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.renderPassGraph,
      label: 'Render-pass graph',
      canPlan: result.canPlan,
      canAdvance: result.canRender,
      blockers: _blockers(
        reason: result.reason,
        issues: result.issues,
        includeReason: !result.canRender,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _outputSurfaceStage(
    ProfessionalVideoTransitionOutputSurfacePlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.outputSurface,
      label: 'Canvas-clipped output surface',
      canPlan: result.canPlan,
      canAdvance: result.canRender,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canRender,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _renderGraphExecutionStage(
    ProfessionalVideoTransitionRenderGraphExecutionPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.renderGraphExecution,
      label: 'Render graph executor',
      canPlan: result.canPlan,
      canAdvance: result.canExecuteGraph,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canExecuteGraph,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _surfaceRendererStage(
    ProfessionalVideoTransitionSurfaceRendererPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.surfaceRenderer,
      label: 'Native surface renderer',
      canPlan: result.canPlan,
      canAdvance: result.canRenderSurface,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canRenderSurface,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _frameRenderCommandsStage(
    ProfessionalVideoTransitionFrameRenderCommandPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.frameRenderCommands,
      label: 'Native frame render commands',
      canPlan: result.canPlan,
      canAdvance: result.canRenderFrame,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canRenderFrame,
      ),
      issues: result.issues,
    );
  }

  static ProfessionalVideoTransitionReadinessStage _parityOutputsStage(
    ProfessionalVideoTransitionParityPlanResult result,
  ) {
    return ProfessionalVideoTransitionReadinessStage(
      id: ProfessionalVideoTransitionReadinessStageId.parityOutputs,
      label: 'Preview/scrub/playback parity',
      canPlan: result.canPlan,
      canAdvance: result.canRender,
      blockers: _blockers(
        reason: result.reason,
        blockedReasons: result.blockedReasons,
        issues: result.issues,
        includeReason: !result.canRender,
      ),
      issues: result.issues,
    );
  }

  static List<String> _blockers({
    required String reason,
    List<String> blockedReasons = const <String>[],
    List<Map<String, Object?>> issues = const <Map<String, Object?>>[],
    bool includeReason = true,
  }) {
    return List<String>.unmodifiable(<String>{
      if (includeReason && reason.trim().isNotEmpty) reason.trim(),
      ...blockedReasons.where((reason) => reason.trim().isNotEmpty),
      ...issues.map((issue) {
        final path = issue['path']?.toString();
        final message = issue['message']?.toString() ?? issue.toString();
        return path == null || path.isEmpty ? message : '$path: $message';
      }),
    });
  }
}
