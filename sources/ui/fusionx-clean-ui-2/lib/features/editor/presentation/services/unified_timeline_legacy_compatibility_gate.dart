import '../models/unified_timeline_presentation_models.dart';
import 'unified_timeline_panel_projection_adapter.dart';

enum UnifiedTimelineCompatibilityBlockReason {
  presentationIssue,
  projectionIssue,
}

class UnifiedTimelineCompatibilityIssue {
  const UnifiedTimelineCompatibilityIssue({
    required this.reason,
    required this.message,
    this.code,
  });

  final UnifiedTimelineCompatibilityBlockReason reason;
  final String message;
  final String? code;
}

class UnifiedTimelineCompatibilityDecision {
  UnifiedTimelineCompatibilityDecision({
    required this.canUseUnifiedPresentation,
    required List<UnifiedTimelineCompatibilityIssue> issues,
  }) : issues = List<UnifiedTimelineCompatibilityIssue>.unmodifiable(issues);

  final bool canUseUnifiedPresentation;
  final List<UnifiedTimelineCompatibilityIssue> issues;

  bool get hasBlockingIssues => issues.isNotEmpty;
}

class UnifiedTimelineLegacyCompatibilityGate {
  const UnifiedTimelineLegacyCompatibilityGate();

  UnifiedTimelineCompatibilityDecision evaluate({
    required UnifiedTimelinePresentation presentation,
    required UnifiedTimelinePanelProjectionResult projection,
  }) {
    final issues = <UnifiedTimelineCompatibilityIssue>[];

    for (final issue in presentation.issues) {
      if (_isBlockingPresentationIssue(issue.code)) {
        issues.add(
          UnifiedTimelineCompatibilityIssue(
            reason: UnifiedTimelineCompatibilityBlockReason.presentationIssue,
            message: issue.message,
            code: issue.code.name,
          ),
        );
      }
    }

    for (final issue in projection.issues) {
      issues.add(
        UnifiedTimelineCompatibilityIssue(
          reason: UnifiedTimelineCompatibilityBlockReason.projectionIssue,
          message: issue.message,
          code: issue.code.name,
        ),
      );
    }

    return UnifiedTimelineCompatibilityDecision(
      canUseUnifiedPresentation: issues.isEmpty,
      issues: issues,
    );
  }

  bool _isBlockingPresentationIssue(UnifiedTimelinePresentationIssueCode code) {
    return switch (code) {
      UnifiedTimelinePresentationIssueCode.duplicateRowId => true,
      UnifiedTimelinePresentationIssueCode.zeroDurationRow => true,
      UnifiedTimelinePresentationIssueCode.transitionBoundaryNotFound => true,
      UnifiedTimelinePresentationIssueCode.sceneClipMappedAsMedia => false,
      UnifiedTimelinePresentationIssueCode
            .unsupportedTrackKindMappedAsAdjustment =>
        false,
      UnifiedTimelinePresentationIssueCode
            .unsupportedVisualKindMappedAsAdjustment =>
        false,
    };
  }
}
