import '../../domain/services/scene_scope_session.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

class SceneScopeTransitionPreviewProjection {
  const SceneScopeTransitionPreviewProjection({
    required this.track,
    required this.localTime,
    required this.localDuration,
  });

  final TimelineTrackData track;
  final TimelineTime localTime;
  final TimelineTime localDuration;
}

class SceneScopeTransitionPreviewResolver {
  const SceneScopeTransitionPreviewResolver();

  SceneScopeTransitionPreviewProjection? resolve({
    required SceneScopeSession session,
    required List<TimelineTrackData> sceneScopeTracks,
    required TimelineTime rootTime,
  }) {
    for (final track in sceneScopeTracks) {
      if (track.kind != TimelineTrackKind.video || track.transitions.isEmpty) {
        continue;
      }
      return SceneScopeTransitionPreviewProjection(
        track: track,
        localTime: session.rootToLocal(rootTime).clamp(
              TimelineTime.zero,
              session.localRange.duration,
            ),
        localDuration: session.localRange.duration,
      );
    }
    return null;
  }
}
