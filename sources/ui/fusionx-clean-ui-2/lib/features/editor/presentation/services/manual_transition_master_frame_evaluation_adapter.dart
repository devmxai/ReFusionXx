import '../../domain/models/master_frame_evaluation_models.dart';
import '../../domain/models/master_time_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/services/master_keyframe_value_evaluator.dart';
import '../../domain/services/master_time_domain_mapper.dart';
import '../../domain/services/master_value_truth_registry.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import 'manual_transition_lane_to_motion_channel_adapter.dart';

class ManualTransitionMasterFrameEvaluationRequest {
  const ManualTransitionMasterFrameEvaluationRequest({
    required this.time,
    required this.transition,
    required this.seamTime,
    required this.projectId,
    this.transitionTargetId,
    this.windowStartTime,
    this.windowEndTime,
  });

  final MasterTimeSnapshot time;
  final TimelineTrackTransitionData transition;
  final TimelineTime seamTime;
  final String projectId;
  final String? transitionTargetId;
  final TimelineTime? windowStartTime;
  final TimelineTime? windowEndTime;
}

class ManualTransitionMasterFrameEvaluationResult {
  ManualTransitionMasterFrameEvaluationResult({
    List<MotionPropertyChannelModel> channels =
        const <MotionPropertyChannelModel>[],
    List<MasterEvaluatedPropertyValue> evaluatedChannels =
        const <MasterEvaluatedPropertyValue>[],
    List<String> blockers = const <String>[],
    List<String> diagnostics = const <String>[],
    this.transitionProgress,
  })  : channels = List<MotionPropertyChannelModel>.unmodifiable(channels),
        evaluatedChannels =
            List<MasterEvaluatedPropertyValue>.unmodifiable(evaluatedChannels),
        blockers = List<String>.unmodifiable(blockers),
        diagnostics = List<String>.unmodifiable(diagnostics);

  final List<MotionPropertyChannelModel> channels;
  final List<MasterEvaluatedPropertyValue> evaluatedChannels;
  final List<String> blockers;
  final List<String> diagnostics;
  final double? transitionProgress;
}

class ManualTransitionMasterFrameEvaluationAdapter {
  ManualTransitionMasterFrameEvaluationAdapter({
    ManualTransitionLaneToMotionChannelAdapter? laneAdapter,
    MasterTimeDomainMapper? timeMapper,
    MasterKeyframeValueEvaluator? keyframeEvaluator,
    MasterValueTruthRegistry? valueRegistry,
  })  : laneAdapter =
            laneAdapter ?? const ManualTransitionLaneToMotionChannelAdapter(),
        timeMapper = timeMapper ?? const MasterTimeDomainMapper(),
        valueRegistry = valueRegistry ?? MasterValueTruthRegistry(),
        keyframeEvaluator = keyframeEvaluator ??
            MasterKeyframeValueEvaluator(
              registry: valueRegistry ?? MasterValueTruthRegistry(),
            );

  final ManualTransitionLaneToMotionChannelAdapter laneAdapter;
  final MasterTimeDomainMapper timeMapper;
  final MasterKeyframeValueEvaluator keyframeEvaluator;
  final MasterValueTruthRegistry valueRegistry;

  ManualTransitionMasterFrameEvaluationResult evaluate({
    required ManualTransitionMasterFrameEvaluationRequest request,
  }) {
    final seamStart = request.windowStartTime ??
        (request.seamTime - request.transition.resolvedLeadingDurationTime);
    final seamEnd = request.windowEndTime ??
        (request.seamTime + request.transition.resolvedTrailingDurationTime);
    final seamDuration = (seamEnd - seamStart) <= TimelineTime.zero
        ? TimelineTime.fromMilliseconds(1)
        : (seamEnd - seamStart);
    final transitionProjection = timeMapper.rootToTransitionProgress(
      rootTime: request.time.rootTime,
      transitionId: request.transition.id,
      seamStart: seamStart,
      seamDuration: seamDuration,
    );
    final laneProjection = laneAdapter.projectChannels(
      request: ManualTransitionLaneChannelProjectionRequest(
        transition: request.transition,
        seamTime: request.seamTime,
        projectId: request.projectId,
        transitionTargetId: request.transitionTargetId,
        windowStartTime: request.windowStartTime,
        windowEndTime: request.windowEndTime,
      ),
    );
    final blockers = <String>[
      for (final issue in laneProjection.issues)
        'manual_lane_projection_issue:${issue.code.name}:${issue.laneId ?? 'unknown'}',
    ];
    final diagnostics = <String>[
      for (final issue in laneProjection.issues) issue.message,
      'manual_transition_projection_reason:${transitionProjection.projection.reason}',
    ];

    final evaluatedChannels = <MasterEvaluatedPropertyValue>[];
    for (final channel in laneProjection.channels) {
      final result = keyframeEvaluator.evaluate(
        MasterKeyframeEvaluationRequest(
          channel: channel,
          time: request.time,
          domainProjection: transitionProjection.projection,
          transitionProgress: null,
        ),
      );
      if (result.mapping == null) {
        blockers
            .add('manual_channel_unresolved:${channel.id}:${result.reason}');
        diagnostics
            .add('manual_channel_unresolved:${channel.id}:${result.reason}');
        continue;
      }
      final definition =
          valueRegistry.definitionForMotionProperty(channel.definition);
      if (definition == null) {
        blockers
            .add('manual_channel_definition_missing:${channel.definition.id}');
        diagnostics
            .add('manual_channel_definition_missing:${channel.definition.id}');
        continue;
      }
      evaluatedChannels.add(
        MasterEvaluatedPropertyValue(
          targetId: channel.target.targetId,
          propertyDefinitionId: definition.id,
          domain: MasterTimeDomain.transition(request.transition.id),
          mapping: result.mapping!,
          sourceChannelId: channel.id,
          status: result.status.name,
        ),
      );
    }

    return ManualTransitionMasterFrameEvaluationResult(
      channels: laneProjection.channels,
      evaluatedChannels: evaluatedChannels,
      blockers: blockers,
      diagnostics: diagnostics,
      transitionProgress: transitionProjection.progress,
    );
  }
}
