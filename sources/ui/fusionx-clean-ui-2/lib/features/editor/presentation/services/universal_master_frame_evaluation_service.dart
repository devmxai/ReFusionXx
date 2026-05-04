import '../../domain/models/composition_scene_clip_models.dart';
import '../../domain/models/master_frame_evaluation_models.dart';
import '../../domain/models/master_time_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/services/timeline_clock_coordinator.dart';
import 'master_frame_evaluation_read_adapter.dart';
import 'universal_motion_channel_collector.dart';

class UniversalMasterFrameEvaluationRequest {
  const UniversalMasterFrameEvaluationRequest({
    required this.clock,
    required this.frameRate,
    required this.project,
    required this.sceneClips,
    required this.channelSources,
    required this.renderMode,
  });

  final TimelineClockSnapshot clock;
  final double frameRate;
  final MotionProjectModel project;
  final List<CompositionSceneClipModel> sceneClips;
  final List<UniversalMotionChannelCollectionSource> channelSources;
  final MasterRenderMode renderMode;
}

class UniversalMasterFrameEvaluationResult {
  UniversalMasterFrameEvaluationResult({
    required this.frame,
    required List<MotionPropertyChannelModel> channels,
    List<String> diagnostics = const <String>[],
    List<String> blockers = const <String>[],
  })  : channels = List.unmodifiable(channels),
        diagnostics = List.unmodifiable(diagnostics),
        blockers = List.unmodifiable(blockers);

  final MasterFrameEvaluation frame;
  final List<MotionPropertyChannelModel> channels;
  final List<String> diagnostics;
  final List<String> blockers;
}

class UniversalMasterFrameEvaluationService {
  const UniversalMasterFrameEvaluationService({
    required this.readAdapter,
    required this.channelCollector,
  });

  final MasterFrameEvaluationReadAdapter readAdapter;
  final UniversalMotionChannelCollector channelCollector;

  UniversalMasterFrameEvaluationResult evaluate(
    UniversalMasterFrameEvaluationRequest request,
  ) {
    final channelCollection = channelCollector.collect(
      project: request.project,
      sceneClips: request.sceneClips,
      sources: request.channelSources,
    );
    final frame = readAdapter.evaluate(
      clock: request.clock,
      frameRate: request.frameRate,
      sceneClips: request.sceneClips,
      channels: channelCollection.channels,
      renderMode: request.renderMode,
    );
    final evaluationBlockers = _evaluationBlockers(frame);
    final blockers = <String>[
      ...channelCollection.blockers,
      ...evaluationBlockers,
    ];
    final diagnostics = <String>[
      ...channelCollection.diagnostics,
      ...evaluationBlockers,
    ];
    if (diagnostics.isEmpty && blockers.isEmpty) {
      return UniversalMasterFrameEvaluationResult(
        frame: frame,
        channels: channelCollection.channels,
      );
    }
    return UniversalMasterFrameEvaluationResult(
      frame: MasterFrameEvaluation(
        time: frame.time,
        projections: frame.projections,
        visibleLayerIds: frame.visibleLayerIds,
        activeTransitionIds: frame.activeTransitionIds,
        evaluatedChannels: frame.evaluatedChannels,
        effectParameters: frame.effectParameters,
        diagnostics: <String>[
          ...frame.diagnostics,
          ...diagnostics,
          ...blockers,
        ],
      ),
      channels: channelCollection.channels,
      diagnostics: diagnostics,
      blockers: blockers,
    );
  }

  List<String> _evaluationBlockers(MasterFrameEvaluation frame) {
    final blockers = <String>[];
    for (final diagnostic in frame.diagnostics) {
      if (diagnostic.startsWith('missing_definition:')) {
        blockers.add('master_evaluation_blocked:$diagnostic');
      } else if (diagnostic.startsWith('unevaluated_channel:')) {
        blockers.add('master_evaluation_blocked:$diagnostic');
      }
    }
    return blockers;
  }
}
