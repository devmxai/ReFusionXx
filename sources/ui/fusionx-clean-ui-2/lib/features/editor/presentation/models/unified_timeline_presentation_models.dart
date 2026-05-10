import 'timeline_time.dart';

enum UnifiedTimelineScopeKind {
  root,
  scene,
  sceneLayer,
  layer,
  transition,
  unknown,
}

enum UnifiedTimelineLayerType {
  solid,
  media,
  text,
  shape,
  audio,
  adjustment,
}

enum UnifiedTimelinePresentationIssueCode {
  sceneClipMappedAsMedia,
  unsupportedTrackKindMappedAsAdjustment,
  unsupportedVisualKindMappedAsAdjustment,
  transitionBoundaryNotFound,
  duplicateRowId,
  zeroDurationRow,
}

class UnifiedTimelinePresentationIssue {
  const UnifiedTimelinePresentationIssue({
    required this.code,
    required this.message,
    this.trackId,
    this.sourceId,
  });

  final UnifiedTimelinePresentationIssueCode code;
  final String message;
  final String? trackId;
  final String? sourceId;
}

class UnifiedTimelinePresentationRow {
  const UnifiedTimelinePresentationRow({
    required this.id,
    required this.trackId,
    required this.sourceId,
    required this.layerType,
    required this.sourceKind,
    required this.label,
    required this.startTime,
    required this.durationTime,
    required this.zIndex,
    required this.isVisible,
    required this.isLocked,
    required this.isMuted,
    required this.isTransition,
    required this.canFocusKeyframes,
    required this.canTrim,
    required this.canMove,
    required this.canReceiveEffects,
  });

  final String id;
  final String trackId;
  final String sourceId;
  final UnifiedTimelineLayerType layerType;
  final String sourceKind;
  final String label;
  final TimelineTime startTime;
  final TimelineTime durationTime;
  final int zIndex;
  final bool isVisible;
  final bool isLocked;
  final bool isMuted;
  final bool isTransition;
  final bool canFocusKeyframes;
  final bool canTrim;
  final bool canMove;
  final bool canReceiveEffects;
}

class UnifiedTimelineSolidLayerSeed {
  const UnifiedTimelineSolidLayerSeed({
    required this.id,
    required this.label,
    required this.startTime,
    required this.durationTime,
    this.zIndex = -1000,
    this.isVisible = true,
    this.isLocked = false,
  });

  final String id;
  final String label;
  final TimelineTime startTime;
  final TimelineTime durationTime;
  final int zIndex;
  final bool isVisible;
  final bool isLocked;
}

class UnifiedTimelinePresentation {
  UnifiedTimelinePresentation({
    required this.scopeKind,
    required this.currentTime,
    required this.durationTime,
    required List<UnifiedTimelinePresentationRow> rows,
    required List<UnifiedTimelinePresentationIssue> issues,
    this.selectedRowId,
  })  : rows = List<UnifiedTimelinePresentationRow>.unmodifiable(rows),
        issues = List<UnifiedTimelinePresentationIssue>.unmodifiable(issues);

  final UnifiedTimelineScopeKind scopeKind;
  final TimelineTime currentTime;
  final TimelineTime durationTime;
  final List<UnifiedTimelinePresentationRow> rows;
  final List<UnifiedTimelinePresentationIssue> issues;
  final String? selectedRowId;

  bool get hasIssues => issues.isNotEmpty;
}
