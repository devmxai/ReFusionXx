import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import '../models/unified_timeline_presentation_models.dart';

enum UnifiedTimelinePanelProjectionIssueCode {
  unsupportedLayerType,
}

class UnifiedTimelinePanelProjectionIssue {
  const UnifiedTimelinePanelProjectionIssue({
    required this.code,
    required this.message,
    this.rowId,
  });

  final UnifiedTimelinePanelProjectionIssueCode code;
  final String message;
  final String? rowId;
}

class UnifiedTimelinePanelProjectionResult {
  UnifiedTimelinePanelProjectionResult({
    required List<TimelineTrackData> tracks,
    required Map<String, String> sourceClipIdToRowClipId,
    required List<UnifiedTimelinePanelProjectionIssue> issues,
  })  : tracks = List<TimelineTrackData>.unmodifiable(tracks),
        sourceClipIdToRowClipId = Map<String, String>.unmodifiable(
          sourceClipIdToRowClipId,
        ),
        issues = List<UnifiedTimelinePanelProjectionIssue>.unmodifiable(issues);

  final List<TimelineTrackData> tracks;
  final Map<String, String> sourceClipIdToRowClipId;
  final List<UnifiedTimelinePanelProjectionIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

class UnifiedTimelinePanelProjectionAdapter {
  const UnifiedTimelinePanelProjectionAdapter();

  UnifiedTimelinePanelProjectionResult project(
    UnifiedTimelinePresentation presentation,
  ) {
    final tracks = <TimelineTrackData>[];
    final sourceClipIdToRowClipId = <String, String>{};
    final issues = <UnifiedTimelinePanelProjectionIssue>[];

    final sortedRows = List<UnifiedTimelinePresentationRow>.from(
      presentation.rows,
    )..sort((left, right) {
        final byStart = left.startTime.compareTo(right.startTime);
        if (byStart != 0) {
          return byStart;
        }
        final byZ = left.zIndex.compareTo(right.zIndex);
        if (byZ != 0) {
          return byZ;
        }
        return left.id.compareTo(right.id);
      });

    for (var index = 0; index < sortedRows.length; index++) {
      final row = sortedRows[index];
      final kind = _trackKindForRow(row, issues);
      final clip = TimelineClipData(
        id: row.id,
        type: TimelineClipType.placeholder,
        tone: row.isTransition
            ? TimelineClipTone.heroMuted
            : TimelineClipTone.aiGenerated,
        durationTime: row.durationTime,
        sourceStartTime: TimelineTime.zero,
        sourceDurationTime: row.durationTime,
        label: row.label,
        contentKind: _clipContentKindForRow(row),
        visualKind: _visualKindForTrackKind(kind),
      );
      final track = TimelineTrackData(
        kind: kind,
        contentKind: _trackContentKindForRow(row),
        visualKind: _visualKindForTrackKind(kind),
        placeholderLabel: row.layerType.name,
        clips: <TimelineClipData>[clip],
      );
      tracks.add(track);
      sourceClipIdToRowClipId[row.sourceId] = row.id;
    }

    return UnifiedTimelinePanelProjectionResult(
      tracks: tracks,
      sourceClipIdToRowClipId: sourceClipIdToRowClipId,
      issues: issues,
    );
  }

  TimelineTrackKind _trackKindForRow(
    UnifiedTimelinePresentationRow row,
    List<UnifiedTimelinePanelProjectionIssue> issues,
  ) {
    switch (row.layerType) {
      case UnifiedTimelineLayerType.audio:
        return TimelineTrackKind.audio;
      case UnifiedTimelineLayerType.text:
        return TimelineTrackKind.text;
      case UnifiedTimelineLayerType.shape:
        return TimelineTrackKind.shape;
      case UnifiedTimelineLayerType.media:
        return TimelineTrackKind.video;
      case UnifiedTimelineLayerType.solid:
        return TimelineTrackKind.shape;
      case UnifiedTimelineLayerType.adjustment:
        return TimelineTrackKind.shape;
    }
  }

  TimelineTrackContentKind _trackContentKindForRow(
    UnifiedTimelinePresentationRow row,
  ) {
    switch (row.layerType) {
      case UnifiedTimelineLayerType.audio:
        return TimelineTrackContentKind.audio;
      case UnifiedTimelineLayerType.text:
        return TimelineTrackContentKind.text;
      case UnifiedTimelineLayerType.shape:
        return TimelineTrackContentKind.shape;
      case UnifiedTimelineLayerType.media:
        return TimelineTrackContentKind.video;
      case UnifiedTimelineLayerType.solid:
        return TimelineTrackContentKind.shape;
      case UnifiedTimelineLayerType.adjustment:
        return TimelineTrackContentKind.shape;
    }
  }

  TimelineClipContentKind _clipContentKindForRow(
    UnifiedTimelinePresentationRow row,
  ) {
    switch (row.layerType) {
      case UnifiedTimelineLayerType.audio:
        return TimelineClipContentKind.media;
      case UnifiedTimelineLayerType.text:
        return TimelineClipContentKind.media;
      case UnifiedTimelineLayerType.shape:
        return TimelineClipContentKind.media;
      case UnifiedTimelineLayerType.media:
        return TimelineClipContentKind.media;
      case UnifiedTimelineLayerType.solid:
        return TimelineClipContentKind.placeholder;
      case UnifiedTimelineLayerType.adjustment:
        return TimelineClipContentKind.placeholder;
    }
  }

  TimelineVisualKind _visualKindForTrackKind(TimelineTrackKind kind) {
    return switch (kind) {
      TimelineTrackKind.video => TimelineVisualKind.video,
      TimelineTrackKind.image => TimelineVisualKind.image,
      TimelineTrackKind.audio => TimelineVisualKind.audio,
      TimelineTrackKind.text => TimelineVisualKind.text,
      TimelineTrackKind.shape => TimelineVisualKind.shape,
      TimelineTrackKind.lipSync => TimelineVisualKind.lipSync,
    };
  }
}
