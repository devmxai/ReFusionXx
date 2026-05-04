import '../models/professional_motion_animation_models.dart';
import '../../presentation/models/timeline_time.dart';
import 'scene_scope_session.dart';

class SceneScopeChannelTimeMapper {
  const SceneScopeChannelTimeMapper();

  MotionPropertyChannelModel channelToLocalTime(
    SceneScopeSession sceneScope,
    MotionPropertyChannelModel channel,
  ) {
    final activeRange = channel.activeRange;
    final localActiveRange = activeRange == null
        ? null
        : TimelineTimeRange(
            start: sceneScope.sourceToLocal(activeRange.start),
            endExclusive: sceneScope.sourceToLocal(activeRange.endExclusive),
          );
    return channel.copyWith(
      activeRange: localActiveRange,
      clearActiveRange: localActiveRange == null,
      keyframes: List<MotionKeyframeModel>.unmodifiable(
        <MotionKeyframeModel>[
          for (final keyframe in channel.keyframes)
            keyframe.copyWith(time: sceneScope.sourceToLocal(keyframe.time)),
        ]..sort((left, right) => left.time.compareTo(right.time)),
      ),
    );
  }

  MotionPropertyChannelModel channelToSourceTime(
    SceneScopeSession sceneScope,
    MotionPropertyChannelModel channel,
  ) {
    final activeRange = channel.activeRange;
    final sourceActiveRange = activeRange == null
        ? null
        : TimelineTimeRange(
            start: sceneScope.localToSource(activeRange.start),
            endExclusive: sceneScope.localToSource(activeRange.endExclusive),
          );
    return channel.copyWith(
      activeRange: sourceActiveRange,
      clearActiveRange: sourceActiveRange == null,
      keyframes: List<MotionKeyframeModel>.unmodifiable(
        <MotionKeyframeModel>[
          for (final keyframe in channel.keyframes)
            keyframe.copyWith(time: sceneScope.localToSource(keyframe.time)),
        ]..sort((left, right) => left.time.compareTo(right.time)),
      ),
    );
  }
}
