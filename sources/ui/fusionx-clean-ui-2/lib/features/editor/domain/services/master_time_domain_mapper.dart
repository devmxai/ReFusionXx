import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';
import '../models/composition_scene_clip_models.dart';
import '../models/master_time_models.dart';

@immutable
class MasterTimeDomainMappingResult {
  const MasterTimeDomainMappingResult({
    required this.projection,
    this.progress,
  });

  final MasterTimeProjection projection;
  final double? progress;

  bool get isValid => projection.isValid;
}

class MasterTimeDomainMapper {
  const MasterTimeDomainMapper();

  MasterTimeProjection rootIdentity({
    required TimelineTime rootTime,
    MasterTimeProjectionPolicy policy = MasterTimeProjectionPolicy.clamp,
  }) {
    return MasterTimeProjection(
      fromDomain: const MasterTimeDomain.root(),
      toDomain: const MasterTimeDomain.root(),
      inputTime: rootTime,
      outputTime: rootTime,
      validRange: null,
      policy: policy,
      reason: 'root_time_identity_projection',
      isValid: true,
    );
  }

  MasterTimeProjection rootToScene({
    required TimelineTime rootTime,
    required CompositionSceneClipModel sceneClip,
    MasterTimeProjectionPolicy policy = MasterTimeProjectionPolicy.clamp,
  }) {
    final output = sceneClip.rootToSourceTime(rootTime);
    final isInside = sceneClip.rootRange.contains(rootTime);
    return MasterTimeProjection(
      fromDomain: const MasterTimeDomain.root(),
      toDomain: MasterTimeDomain.scene(sceneClip.sourceSceneId),
      inputTime: rootTime,
      outputTime: output,
      validRange: sceneClip.rootRange,
      policy: policy,
      reason: isInside
          ? 'root_time_mapped_to_source_scene'
          : 'root_time_outside_scene_clip_range',
      isValid:
          policy != MasterTimeProjectionPolicy.rejectOutsideRange || isInside,
    );
  }

  MasterTimeProjection sceneToRoot({
    required TimelineTime sceneTime,
    required CompositionSceneClipModel sceneClip,
    MasterTimeProjectionPolicy policy = MasterTimeProjectionPolicy.clamp,
  }) {
    final output = sceneClip.sourceToRootTime(sceneTime);
    final isInside = sceneClip.sourceRange.contains(sceneTime);
    return MasterTimeProjection(
      fromDomain: MasterTimeDomain.scene(sceneClip.sourceSceneId),
      toDomain: const MasterTimeDomain.root(),
      inputTime: sceneTime,
      outputTime: output,
      validRange: sceneClip.sourceRange,
      policy: policy,
      reason: isInside
          ? 'scene_time_mapped_to_root'
          : 'scene_time_outside_source_range',
      isValid:
          policy != MasterTimeProjectionPolicy.rejectOutsideRange || isInside,
    );
  }

  MasterTimeProjection sceneToLayer({
    required TimelineTime sceneTime,
    required String sourceSceneId,
    required String layerId,
    required TimelineTimeRange layerRange,
    MasterTimeProjectionPolicy policy = MasterTimeProjectionPolicy.clamp,
  }) {
    final clamped = sceneTime.clamp(layerRange.start, layerRange.endExclusive);
    final output = clamped - layerRange.start;
    final isInside = layerRange.contains(sceneTime);
    return MasterTimeProjection(
      fromDomain: MasterTimeDomain.scene(sourceSceneId),
      toDomain: MasterTimeDomain.layer(layerId),
      inputTime: sceneTime,
      outputTime: output,
      validRange: layerRange,
      policy: policy,
      reason: isInside
          ? 'scene_time_mapped_to_layer_local'
          : 'scene_time_outside_layer_range',
      isValid:
          policy != MasterTimeProjectionPolicy.rejectOutsideRange || isInside,
    );
  }

  MasterTimeProjection layerToScene({
    required TimelineTime layerTime,
    required String sourceSceneId,
    required String layerId,
    required TimelineTimeRange layerRange,
    MasterTimeProjectionPolicy policy = MasterTimeProjectionPolicy.clamp,
  }) {
    final zero = TimelineTime.zero.rescaledTo(layerRange.start.timescale);
    final localDuration = layerRange.duration;
    final clamped = layerTime.clamp(zero, localDuration);
    final output = layerRange.start + clamped;
    final isInside = layerTime >= zero && layerTime <= localDuration;
    return MasterTimeProjection(
      fromDomain: MasterTimeDomain.layer(layerId),
      toDomain: MasterTimeDomain.scene(sourceSceneId),
      inputTime: layerTime,
      outputTime: output,
      validRange: TimelineTimeRange(start: zero, endExclusive: localDuration),
      policy: policy,
      reason: isInside
          ? 'layer_local_time_mapped_to_scene'
          : 'layer_local_time_outside_range',
      isValid:
          policy != MasterTimeProjectionPolicy.rejectOutsideRange || isInside,
    );
  }

  MasterTimeDomainMappingResult rootToTransitionProgress({
    required TimelineTime rootTime,
    required String transitionId,
    required TimelineTime seamStart,
    required TimelineTime seamDuration,
    MasterTimeProjectionPolicy policy =
        MasterTimeProjectionPolicy.transitionProgress,
  }) {
    final safeDuration = seamDuration <= TimelineTime.zero
        ? TimelineTime.fromMilliseconds(1)
        : seamDuration;
    final range = TimelineTimeRange(
      start: seamStart,
      endExclusive: seamStart + safeDuration,
    );
    final isInside = range.contains(rootTime);
    final clamped = rootTime.clamp(range.start, range.endExclusive);
    final progress =
        ((clamped - range.start).inSecondsDouble / safeDuration.inSecondsDouble)
            .clamp(0.0, 1.0)
            .toDouble();
    final projection = MasterTimeProjection(
      fromDomain: const MasterTimeDomain.root(),
      toDomain: MasterTimeDomain.transition(transitionId),
      inputTime: rootTime,
      outputTime: clamped,
      validRange: range,
      policy: policy,
      reason: isInside
          ? 'root_time_mapped_to_transition_window'
          : 'root_time_outside_transition_window',
      isValid:
          policy != MasterTimeProjectionPolicy.rejectOutsideRange || isInside,
    );
    return MasterTimeDomainMappingResult(
      projection: projection,
      progress: progress,
    );
  }

  MasterTimeProjection rootToSourceMedia({
    required TimelineTime rootTime,
    required CompositionSceneClipModel sceneClip,
    required String mediaId,
    MasterTimeProjectionPolicy policy =
        MasterTimeProjectionPolicy.sourceRateAdjusted,
  }) {
    final sourceTime = sceneClip.rootToSourceTime(rootTime);
    final isInside = sceneClip.rootRange.contains(rootTime);
    return MasterTimeProjection(
      fromDomain: const MasterTimeDomain.root(),
      toDomain: MasterTimeDomain.sourceMedia(mediaId),
      inputTime: rootTime,
      outputTime: sourceTime,
      validRange: sceneClip.rootRange,
      policy: policy,
      reason: isInside
          ? 'root_time_mapped_to_source_media_via_scene_clip'
          : 'root_time_outside_scene_clip_for_source_media',
      isValid:
          policy != MasterTimeProjectionPolicy.rejectOutsideRange || isInside,
    );
  }
}
