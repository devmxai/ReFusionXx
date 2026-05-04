import '../../domain/models/composition_scene_clip_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_time.dart';
import 'universal_target_resolver.dart';

class UniversalMotionChannelCollectionSource {
  const UniversalMotionChannelCollectionSource({
    required this.id,
    required this.channels,
  });

  final String id;
  final Iterable<MotionPropertyChannelModel> channels;
}

class UniversalMotionChannelCollectionResult {
  UniversalMotionChannelCollectionResult({
    required List<MotionPropertyChannelModel> channels,
    List<String> diagnostics = const <String>[],
    List<String> blockers = const <String>[],
  })  : channels = List.unmodifiable(channels),
        diagnostics = List.unmodifiable(diagnostics),
        blockers = List.unmodifiable(blockers);

  final List<MotionPropertyChannelModel> channels;
  final List<String> diagnostics;
  final List<String> blockers;
}

class UniversalMotionChannelCollector {
  const UniversalMotionChannelCollector({
    this.targetResolver = const UniversalTargetResolver(),
  });

  final UniversalTargetResolver targetResolver;

  UniversalMotionChannelCollectionResult collect({
    required MotionProjectModel project,
    required List<CompositionSceneClipModel> sceneClips,
    required List<UniversalMotionChannelCollectionSource> sources,
  }) {
    final context = targetResolver.buildContext(
      project: project,
      sceneClips: sceneClips,
    );
    final byChannelId = <String, MotionPropertyChannelModel>{};
    final diagnostics = <String>[];
    final blockers = <String>[];
    for (final source in sources) {
      for (final channel in source.channels) {
        final resolution = targetResolver.resolveChannel(
          channel: channel,
          context: context,
        );
        diagnostics.addAll(
          resolution.diagnostics.map(
            (entry) => 'target_resolution:${source.id}:${channel.id}:$entry',
          ),
        );
        final resolvedChannel = resolution.channel;
        if (resolvedChannel == null) {
          blockers.add(
            'unresolved_target:${source.id}:${channel.id}:${resolution.blocker ?? 'unknown'}',
          );
          continue;
        }
        final existing = byChannelId[resolvedChannel.id];
        if (existing != null) {
          if (!_isEquivalentChannel(existing, resolvedChannel)) {
            blockers.add(
              'conflicting_channel_definition:${resolvedChannel.id}:${source.id}',
            );
            diagnostics.add(
              'duplicate_channel_conflict:${source.id}:${resolvedChannel.id}',
            );
            continue;
          }
          diagnostics.add(
            'duplicate_channel_ignored:${source.id}:${resolvedChannel.id}',
          );
          continue;
        }
        byChannelId[resolvedChannel.id] = resolvedChannel;
      }
    }
    return UniversalMotionChannelCollectionResult(
      channels: (byChannelId.values.toList(growable: false)
        ..sort((left, right) => left.id.compareTo(right.id))),
      diagnostics: diagnostics,
      blockers: blockers,
    );
  }

  bool _isEquivalentChannel(
    MotionPropertyChannelModel left,
    MotionPropertyChannelModel right,
  ) {
    if (left.definition.id != right.definition.id) {
      return false;
    }
    final leftTarget = left.target;
    final rightTarget = right.target;
    if (leftTarget.kind != rightTarget.kind ||
        leftTarget.targetId != rightTarget.targetId ||
        leftTarget.projectId != rightTarget.projectId ||
        leftTarget.sceneId != rightTarget.sceneId ||
        leftTarget.layerId != rightTarget.layerId ||
        leftTarget.elementId != rightTarget.elementId) {
      return false;
    }
    if (!_isEquivalentRange(left.activeRange, right.activeRange)) {
      return false;
    }
    if (!_isEquivalentPropertyValue(left.baseValue, right.baseValue)) {
      return false;
    }
    if (left.beforeStart != right.beforeStart ||
        left.afterEnd != right.afterEnd) {
      return false;
    }
    if (left.keyframes.length != right.keyframes.length) {
      return false;
    }
    for (var index = 0; index < left.keyframes.length; index += 1) {
      final leftKeyframe = left.keyframes[index];
      final rightKeyframe = right.keyframes[index];
      if (leftKeyframe.time != rightKeyframe.time ||
          leftKeyframe.value.rawValue != rightKeyframe.value.rawValue ||
          leftKeyframe.value.kind != rightKeyframe.value.kind ||
          !_isEquivalentInterpolation(
            leftKeyframe.interpolationToNext,
            rightKeyframe.interpolationToNext,
          )) {
        return false;
      }
    }
    return true;
  }

  bool _isEquivalentRange(TimelineTimeRange? left, TimelineTimeRange? right) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return left.start == right.start && left.endExclusive == right.endExclusive;
  }

  bool _isEquivalentPropertyValue(
    MotionPropertyValue? left,
    MotionPropertyValue? right,
  ) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return left.kind == right.kind && left.rawValue == right.rawValue;
  }

  bool _isEquivalentInterpolation(
    MotionInterpolationSpec left,
    MotionInterpolationSpec right,
  ) {
    return left.kind == right.kind &&
        _isEquivalentBezier(left.bezier, right.bezier) &&
        _isEquivalentSpring(left.spring, right.spring) &&
        _isEquivalentBounce(left.bounce, right.bounce) &&
        _isEquivalentElastic(left.elastic, right.elastic);
  }

  bool _isEquivalentBezier(
    MotionBezierControlPoints? left,
    MotionBezierControlPoints? right,
  ) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return left.x1 == right.x1 &&
        left.y1 == right.y1 &&
        left.x2 == right.x2 &&
        left.y2 == right.y2;
  }

  bool _isEquivalentSpring(MotionSpringSpec? left, MotionSpringSpec? right) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return left.stiffness == right.stiffness &&
        left.damping == right.damping &&
        left.mass == right.mass &&
        left.initialVelocity == right.initialVelocity;
  }

  bool _isEquivalentBounce(MotionBounceSpec? left, MotionBounceSpec? right) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return left.amplitude == right.amplitude &&
        left.bounces == right.bounces &&
        left.decay == right.decay;
  }

  bool _isEquivalentElastic(MotionElasticSpec? left, MotionElasticSpec? right) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return left.amplitude == right.amplitude &&
        left.period == right.period &&
        left.decay == right.decay;
  }
}
