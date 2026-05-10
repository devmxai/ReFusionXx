import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import '../models/unified_timeline_presentation_models.dart';

class UnifiedTimelinePresentationRequest {
  const UnifiedTimelinePresentationRequest({
    required this.scopeKind,
    required this.currentTime,
    required this.durationTime,
    required this.tracks,
    this.selectedRowId,
    this.solidLayers = const <UnifiedTimelineSolidLayerSeed>[],
  });

  final UnifiedTimelineScopeKind scopeKind;
  final TimelineTime currentTime;
  final TimelineTime durationTime;
  final List<TimelineTrackData> tracks;
  final String? selectedRowId;
  final List<UnifiedTimelineSolidLayerSeed> solidLayers;
}

class UnifiedTimelinePresentationAdapter {
  const UnifiedTimelinePresentationAdapter();

  UnifiedTimelinePresentation build(
      UnifiedTimelinePresentationRequest request) {
    final rows = <UnifiedTimelinePresentationRow>[];
    final issues = <UnifiedTimelinePresentationIssue>[];
    final rowIds = <String>{};

    for (final solid in request.solidLayers) {
      _appendRow(
        rows: rows,
        issues: issues,
        rowIds: rowIds,
        row: UnifiedTimelinePresentationRow(
          id: 'solid:${solid.id}',
          trackId: 'solidTrack',
          sourceId: solid.id,
          layerType: UnifiedTimelineLayerType.solid,
          sourceKind: 'solidLayer',
          label: solid.label,
          startTime: solid.startTime,
          durationTime: solid.durationTime,
          zIndex: solid.zIndex,
          isVisible: solid.isVisible,
          isLocked: solid.isLocked,
          isMuted: false,
          isTransition: false,
          canFocusKeyframes: false,
          canTrim: true,
          canMove: true,
          canReceiveEffects: true,
        ),
      );
    }

    for (var trackIndex = 0; trackIndex < request.tracks.length; trackIndex++) {
      final track = request.tracks[trackIndex];
      final trackId = 'track:$trackIndex:${track.kind.name}';
      final clipRanges = _clipRanges(track);

      for (var clipIndex = 0; clipIndex < track.clips.length; clipIndex++) {
        final clip = track.clips[clipIndex];
        final range = clipRanges[clip.id] ??
            TimelineTimeRange(
                start: TimelineTime.zero, endExclusive: TimelineTime.zero);
        final mapped = _mapClipLayerType(track: track, clip: clip);
        for (final issue in mapped.issues) {
          issues.add(
            UnifiedTimelinePresentationIssue(
              code: issue.code,
              message: issue.message,
              trackId: trackId,
              sourceId: clip.id,
            ),
          );
        }
        final hasLane = track.animationLanes.any(
          (lane) => lane.targetClipId == clip.id,
        );
        _appendRow(
          rows: rows,
          issues: issues,
          rowIds: rowIds,
          row: UnifiedTimelinePresentationRow(
            id: 'clip:$trackIndex:$clipIndex:${clip.id}',
            trackId: trackId,
            sourceId: clip.id,
            layerType: mapped.layerType,
            sourceKind: clip.contentKind.name,
            label: clip.label ?? _fallbackClipLabel(track, clip),
            startTime: range.start,
            durationTime: clip.durationTime,
            zIndex: trackIndex,
            isVisible: true,
            isLocked: false,
            isMuted: false,
            isTransition: false,
            canFocusKeyframes: hasLane,
            canTrim: clip.type == TimelineClipType.media ||
                clip.contentKind == TimelineClipContentKind.scene,
            canMove: true,
            canReceiveEffects:
                mapped.layerType != UnifiedTimelineLayerType.audio,
          ),
        );
      }

      for (var transitionIndex = 0;
          transitionIndex < track.transitions.length;
          transitionIndex++) {
        final transition = track.transitions[transitionIndex];
        final leftRange = clipRanges[transition.leftClipId];
        final rightRange = clipRanges[transition.rightClipId];
        if (leftRange == null || rightRange == null) {
          issues.add(
            UnifiedTimelinePresentationIssue(
              code: UnifiedTimelinePresentationIssueCode
                  .transitionBoundaryNotFound,
              message:
                  'Transition `${transition.id}` could not resolve clip boundary.',
              trackId: trackId,
              sourceId: transition.id,
            ),
          );
          continue;
        }
        final rawStart =
            rightRange.start - transition.resolvedLeadingDurationTime;
        final start =
            rawStart < TimelineTime.zero ? TimelineTime.zero : rawStart;
        _appendRow(
          rows: rows,
          issues: issues,
          rowIds: rowIds,
          row: UnifiedTimelinePresentationRow(
            id: 'transition:$trackIndex:$transitionIndex:${transition.id}',
            trackId: trackId,
            sourceId: transition.id,
            layerType: UnifiedTimelineLayerType.adjustment,
            sourceKind: 'transition',
            label: transition.preset.label,
            startTime: start,
            durationTime: transition.durationTime,
            zIndex: trackIndex,
            isVisible: true,
            isLocked: false,
            isMuted: false,
            isTransition: true,
            canFocusKeyframes: transition.manualAnimationLanes.isNotEmpty,
            canTrim: true,
            canMove: true,
            canReceiveEffects: true,
          ),
        );
      }
    }

    return UnifiedTimelinePresentation(
      scopeKind: request.scopeKind,
      currentTime: request.currentTime,
      durationTime: request.durationTime,
      rows: rows,
      issues: issues,
      selectedRowId: request.selectedRowId,
    );
  }

  void _appendRow({
    required List<UnifiedTimelinePresentationRow> rows,
    required List<UnifiedTimelinePresentationIssue> issues,
    required Set<String> rowIds,
    required UnifiedTimelinePresentationRow row,
  }) {
    if (!rowIds.add(row.id)) {
      issues.add(
        UnifiedTimelinePresentationIssue(
          code: UnifiedTimelinePresentationIssueCode.duplicateRowId,
          message: 'Duplicate unified timeline row id `${row.id}`.',
          trackId: row.trackId,
          sourceId: row.sourceId,
        ),
      );
      return;
    }
    if (row.durationTime <= TimelineTime.zero) {
      issues.add(
        UnifiedTimelinePresentationIssue(
          code: UnifiedTimelinePresentationIssueCode.zeroDurationRow,
          message: 'Row `${row.id}` has zero or negative duration.',
          trackId: row.trackId,
          sourceId: row.sourceId,
        ),
      );
    }
    rows.add(row);
  }

  Map<String, TimelineTimeRange> _clipRanges(TimelineTrackData track) {
    var cursor = TimelineTime.zero;
    final ranges = <String, TimelineTimeRange>{};
    for (final clip in track.clips) {
      final start = cursor;
      final end = start + clip.durationTime;
      ranges[clip.id] = TimelineTimeRange(start: start, endExclusive: end);
      cursor = end;
    }
    return ranges;
  }

  _ClipLayerTypeMapping _mapClipLayerType({
    required TimelineTrackData track,
    required TimelineClipData clip,
  }) {
    final issues = <_ClipLayerTypeIssue>[];

    if (clip.contentKind == TimelineClipContentKind.scene) {
      issues.add(
        const _ClipLayerTypeIssue(
          code: UnifiedTimelinePresentationIssueCode.sceneClipMappedAsMedia,
          message:
              'Scene clip is projected as Media Layer in the first adapter slice.',
        ),
      );
      return _ClipLayerTypeMapping(UnifiedTimelineLayerType.media, issues);
    }

    if (_looksSolidClip(clip)) {
      return _ClipLayerTypeMapping(UnifiedTimelineLayerType.solid, issues);
    }

    if (clip.visualKind == TimelineVisualKind.camera ||
        clip.visualKind == TimelineVisualKind.control ||
        clip.visualKind == TimelineVisualKind.lipSync) {
      issues.add(
        _ClipLayerTypeIssue(
          code: UnifiedTimelinePresentationIssueCode
              .unsupportedVisualKindMappedAsAdjustment,
          message:
              'Visual kind `${clip.visualKind.name}` is projected as Adjustment Layer for compatibility.',
        ),
      );
      return _ClipLayerTypeMapping(UnifiedTimelineLayerType.adjustment, issues);
    }

    switch (track.kind) {
      case TimelineTrackKind.audio:
        return _ClipLayerTypeMapping(UnifiedTimelineLayerType.audio, issues);
      case TimelineTrackKind.text:
        return _ClipLayerTypeMapping(UnifiedTimelineLayerType.text, issues);
      case TimelineTrackKind.shape:
        return _ClipLayerTypeMapping(UnifiedTimelineLayerType.shape, issues);
      case TimelineTrackKind.video:
      case TimelineTrackKind.image:
        return _ClipLayerTypeMapping(UnifiedTimelineLayerType.media, issues);
      case TimelineTrackKind.lipSync:
        issues.add(
          const _ClipLayerTypeIssue(
            code: UnifiedTimelinePresentationIssueCode
                .unsupportedTrackKindMappedAsAdjustment,
            message:
                'Lip Sync track is projected as Adjustment Layer in the first adapter slice.',
          ),
        );
        return _ClipLayerTypeMapping(
          UnifiedTimelineLayerType.adjustment,
          issues,
        );
    }
  }

  bool _looksSolidClip(TimelineClipData clip) {
    if (clip.type != TimelineClipType.placeholder) {
      return false;
    }
    final normalizedLabel = (clip.label ?? '').toLowerCase();
    if (normalizedLabel.contains('background') ||
        normalizedLabel.contains('solid') ||
        normalizedLabel.contains('gradient')) {
      return true;
    }
    return clip.visualKind == TimelineVisualKind.composition &&
        clip.contentKind == TimelineClipContentKind.placeholder;
  }

  String _fallbackClipLabel(TimelineTrackData track, TimelineClipData clip) {
    if (clip.isGapPlaceholder) {
      return '${track.kind.name.toUpperCase()} Placeholder';
    }
    return '${track.kind.name.toUpperCase()} Layer';
  }
}

class _ClipLayerTypeMapping {
  _ClipLayerTypeMapping(this.layerType, this.issues);

  final UnifiedTimelineLayerType layerType;
  final List<_ClipLayerTypeIssue> issues;
}

class _ClipLayerTypeIssue {
  const _ClipLayerTypeIssue({
    required this.code,
    required this.message,
  });

  final UnifiedTimelinePresentationIssueCode code;
  final String message;
}
