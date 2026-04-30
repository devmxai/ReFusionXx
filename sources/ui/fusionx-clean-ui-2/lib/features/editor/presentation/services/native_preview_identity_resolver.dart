import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

class NativePreviewIdentityResolver {
  const NativePreviewIdentityResolver();

  String? resolve({
    required List<TimelineTrackData> tracks,
    required String playbackScopeId,
    String? fallbackIdentity,
  }) {
    if (_hasPlayableVideo(tracks)) {
      final normalizedScopeId =
          playbackScopeId.trim().isEmpty ? 'timeline' : playbackScopeId.trim();
      return 'native-preview-scope:$normalizedScopeId';
    }
    return fallbackIdentity;
  }

  bool _hasPlayableVideo(List<TimelineTrackData> tracks) {
    for (final track in tracks) {
      if (track.kind != TimelineTrackKind.video) {
        continue;
      }
      for (final clip in track.clips) {
        if (clip.type == TimelineClipType.media &&
            clip.assetId != null &&
            clip.durationTime > TimelineTime.zero) {
          return true;
        }
      }
    }
    return false;
  }
}
