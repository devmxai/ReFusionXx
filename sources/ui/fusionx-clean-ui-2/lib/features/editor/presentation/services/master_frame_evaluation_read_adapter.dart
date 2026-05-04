import '../../domain/models/composition_scene_clip_models.dart';
import '../../domain/models/master_frame_evaluation_models.dart';
import '../../domain/models/master_time_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/services/master_keyframe_value_evaluator.dart';
import '../../domain/services/master_time_domain_mapper.dart';
import '../../domain/services/master_value_truth_registry.dart';
import '../../domain/services/timeline_clock_coordinator.dart';

class MasterFrameEvaluationReadAdapter {
  MasterFrameEvaluationReadAdapter({
    MasterTimeDomainMapper? timeMapper,
    MasterKeyframeValueEvaluator? keyframeEvaluator,
    MasterValueTruthRegistry? valueRegistry,
  })  : timeMapper = timeMapper ?? const MasterTimeDomainMapper(),
        valueRegistry = valueRegistry ?? MasterValueTruthRegistry(),
        keyframeEvaluator = keyframeEvaluator ??
            MasterKeyframeValueEvaluator(
              registry: valueRegistry ?? MasterValueTruthRegistry(),
            );

  final MasterTimeDomainMapper timeMapper;
  final MasterValueTruthRegistry valueRegistry;
  final MasterKeyframeValueEvaluator keyframeEvaluator;

  MasterFrameEvaluation evaluate({
    required TimelineClockSnapshot clock,
    required double frameRate,
    required List<CompositionSceneClipModel> sceneClips,
    required List<MotionPropertyChannelModel> channels,
    MasterRenderMode renderMode = MasterRenderMode.preview,
  }) {
    final time = MasterTimeSnapshot.fromClockSnapshot(
      clock: clock,
      frameRate: frameRate,
      renderMode: renderMode,
      sourceScope: MasterTimeScope.rootComposition,
      monotonicTimeUs: clock.monotonicTimeUs,
    );
    final projections = <MasterTimeProjection>[];
    final evaluated = <MasterEvaluatedPropertyValue>[];
    final diagnostics = <String>[];
    final visibleLayerIds = <String>{};
    final rootProjection = timeMapper.rootIdentity(rootTime: time.rootTime);

    for (final channel in channels) {
      if (!_isRootScopedChannel(channel)) {
        continue;
      }
      _evaluateChannel(
        channel: channel,
        time: time,
        projection: rootProjection,
        evaluated: evaluated,
        diagnostics: diagnostics,
        visibleLayerIds: visibleLayerIds,
      );
    }

    for (final clip in sceneClips) {
      if (!clip.containsRootTime(time.rootTime)) {
        continue;
      }
      final sceneProjection = timeMapper.rootToScene(
        rootTime: time.rootTime,
        sceneClip: clip,
      );
      projections.add(sceneProjection);
      if (!sceneProjection.isValid) {
        diagnostics.add('invalid_scene_projection:${clip.id}');
        continue;
      }

      for (final channel in channels) {
        if (_isRootScopedChannel(channel) ||
            channel.target.sceneId != clip.sourceSceneId) {
          continue;
        }
        _evaluateChannel(
          channel: channel,
          time: time,
          projection: sceneProjection,
          evaluated: evaluated,
          diagnostics: diagnostics,
          visibleLayerIds: visibleLayerIds,
        );
      }
    }

    return MasterFrameEvaluation(
      time: time,
      projections: projections,
      visibleLayerIds: visibleLayerIds.toList(growable: false),
      activeTransitionIds: const <String>[],
      evaluatedChannels: evaluated,
      diagnostics: diagnostics,
    );
  }

  bool _isRootScopedChannel(MotionPropertyChannelModel channel) {
    return channel.target.kind == MotionTargetKind.project;
  }

  void _evaluateChannel({
    required MotionPropertyChannelModel channel,
    required MasterTimeSnapshot time,
    required MasterTimeProjection projection,
    required List<MasterEvaluatedPropertyValue> evaluated,
    required List<String> diagnostics,
    required Set<String> visibleLayerIds,
  }) {
    if (channel.target.layerId != null) {
      visibleLayerIds.add(channel.target.layerId!);
    }
    final result = keyframeEvaluator.evaluate(
      MasterKeyframeEvaluationRequest(
        channel: channel,
        time: time,
        domainProjection: projection,
      ),
    );
    if (result.mapping == null) {
      diagnostics.add('unevaluated_channel:${channel.id}:${result.reason}');
      return;
    }
    final definition =
        valueRegistry.definitionForMotionProperty(channel.definition);
    if (definition == null) {
      diagnostics.add('missing_definition:${channel.definition.id}');
      return;
    }
    evaluated.add(
      MasterEvaluatedPropertyValue(
        targetId: channel.target.targetId,
        propertyDefinitionId: definition.id,
        domain: projection.toDomain,
        mapping: result.mapping!,
        sourceChannelId: channel.id,
        status: result.status.name,
      ),
    );
  }
}
