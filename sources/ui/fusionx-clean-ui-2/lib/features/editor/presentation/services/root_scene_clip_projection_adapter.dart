import '../../domain/models/composition_scene_clip_models.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

enum RootSceneClipProjectionIssueCode {
  invalidSceneClip,
  overlappingSceneClip,
}

class RootSceneClipProjectionIssue {
  const RootSceneClipProjectionIssue({
    required this.code,
    required this.message,
    this.clipId,
  });

  final RootSceneClipProjectionIssueCode code;
  final String message;
  final String? clipId;
}

class RootSceneClipProjectionResult {
  RootSceneClipProjectionResult({
    required this.track,
    required Map<String, CompositionSceneClipModel> sceneClipByTimelineClipId,
    List<RootSceneClipProjectionIssue> issues =
        const <RootSceneClipProjectionIssue>[],
  })  : sceneClipByTimelineClipId = Map.unmodifiable(sceneClipByTimelineClipId),
        issues = List.unmodifiable(issues);

  final TimelineTrackData track;
  final Map<String, CompositionSceneClipModel> sceneClipByTimelineClipId;
  final List<RootSceneClipProjectionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class RootSceneClipProjectionAdapter {
  const RootSceneClipProjectionAdapter();

  RootSceneClipProjectionResult projectSceneTrack({
    required List<CompositionSceneClipModel> sceneClips,
    String placeholderLabel = 'Scenes',
  }) {
    final issues = <RootSceneClipProjectionIssue>[];
    final timelineClips = <TimelineClipData>[];
    final sceneClipByTimelineClipId = <String, CompositionSceneClipModel>{};
    final sortedClips = sceneClips
        .where((clip) => clip.isEnabled)
        .toList(growable: false)
      ..sort((left, right) => left.startTime.compareTo(right.startTime));
    var cursor = TimelineTime.zero;

    for (final sceneClip in sortedClips) {
      final clipIssues = sceneClip.validate();
      if (clipIssues.isNotEmpty) {
        issues.add(
          RootSceneClipProjectionIssue(
            code: RootSceneClipProjectionIssueCode.invalidSceneClip,
            message: clipIssues.map((issue) => issue.message).join(' '),
            clipId: sceneClip.id,
          ),
        );
        continue;
      }

      if (sceneClip.startTime < cursor) {
        issues.add(
          RootSceneClipProjectionIssue(
            code: RootSceneClipProjectionIssueCode.overlappingSceneClip,
            message:
                'Scene clip `${sceneClip.id}` overlaps a previous scene clip.',
            clipId: sceneClip.id,
          ),
        );
        continue;
      }

      if (sceneClip.startTime > cursor) {
        timelineClips.add(
          _gapClip(
            id: 'scene_gap_${timelineClips.length}',
            durationTime: sceneClip.startTime - cursor,
          ),
        );
      }

      final timelineClip = _timelineClipFor(sceneClip);
      timelineClips.add(timelineClip);
      sceneClipByTimelineClipId[timelineClip.id] = sceneClip;
      cursor = sceneClip.endTime;
    }

    return RootSceneClipProjectionResult(
      track: TimelineTrackData(
        kind: TimelineTrackKind.text,
        contentKind: TimelineTrackContentKind.scene,
        placeholderLabel: placeholderLabel,
        clips: List<TimelineClipData>.unmodifiable(timelineClips),
      ),
      sceneClipByTimelineClipId: sceneClipByTimelineClipId,
      issues: issues,
    );
  }

  List<TimelineTrackData> mergeSceneTrack({
    required List<TimelineTrackData> existingTracks,
    required List<CompositionSceneClipModel> sceneClips,
    String placeholderLabel = 'Scenes',
  }) {
    final projected = projectSceneTrack(
      sceneClips: sceneClips,
      placeholderLabel: placeholderLabel,
    );
    return <TimelineTrackData>[
      for (final track in existingTracks)
        if (!track.isSceneTrack) track,
      projected.track,
    ];
  }

  TimelineClipData _timelineClipFor(CompositionSceneClipModel sceneClip) {
    return TimelineClipData(
      id: sceneClip.id,
      type: TimelineClipType.placeholder,
      tone: TimelineClipTone.aiGenerated,
      contentKind: TimelineClipContentKind.scene,
      sourceSceneId: sceneClip.sourceSceneId,
      assetId: sceneClip.sourceSceneId,
      label: _labelFor(sceneClip),
      durationTime: sceneClip.durationTime,
      sourceStartTime: sceneClip.sourceInTime,
      sourceDurationTime: sceneClip.sourceDurationTime,
      playbackRate: sceneClip.timeScale,
    );
  }

  TimelineClipData _gapClip({
    required String id,
    required TimelineTime durationTime,
  }) {
    return TimelineClipData(
      id: id,
      type: TimelineClipType.placeholder,
      tone: TimelineClipTone.placeholder,
      contentKind: TimelineClipContentKind.placeholder,
      durationTime: durationTime,
    );
  }

  String _labelFor(CompositionSceneClipModel sceneClip) {
    final name = sceneClip.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return sceneClip.sourceSceneId;
  }
}
