import '../../domain/models/composition_scene_clip_models.dart';
import '../../domain/models/master_frame_evaluation_models.dart';
import '../../domain/models/master_time_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
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
        if (channel.target.sceneId != clip.sourceSceneId) {
          continue;
        }
        if (channel.target.layerId != null) {
          visibleLayerIds.add(channel.target.layerId!);
        }
        final result = keyframeEvaluator.evaluate(
          MasterKeyframeEvaluationRequest(
            channel: channel,
            time: time,
            domainProjection: sceneProjection,
          ),
        );
        if (result.mapping == null) {
          diagnostics.add('unevaluated_channel:${channel.id}:${result.reason}');
          continue;
        }
        final definition =
            valueRegistry.definitionForMotionProperty(channel.definition);
        if (definition == null) {
          diagnostics.add('missing_definition:${channel.definition.id}');
          continue;
        }
        evaluated.add(
          MasterEvaluatedPropertyValue(
            targetId: channel.target.targetId,
            propertyDefinitionId: definition.id,
            domain: MasterTimeDomain.scene(clip.sourceSceneId),
            mapping: result.mapping!,
            sourceChannelId: channel.id,
            status: result.status.name,
          ),
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
}
