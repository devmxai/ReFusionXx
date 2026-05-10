import '../models/unified_timeline_presentation_models.dart';

enum UnifiedTimelineFocusRoute {
  layerScope,
  sceneScopeFallback,
  adjustmentScope,
  unsupported,
}

enum UnifiedTimelineFocusIssueCode {
  rowNotFound,
  rowCannotFocusKeyframes,
  audioLayerFocusUnsupported,
  adjustmentLayerFocusUnsupported,
}

class UnifiedTimelineFocusIssue {
  const UnifiedTimelineFocusIssue({
    required this.code,
    required this.message,
    this.rowId,
    this.sourceId,
  });

  final UnifiedTimelineFocusIssueCode code;
  final String message;
  final String? rowId;
  final String? sourceId;
}

class UnifiedTimelineFocusRoutingRequest {
  const UnifiedTimelineFocusRoutingRequest({
    required this.presentation,
    required this.projectedClipId,
    required this.rowClipIdToSourceClipId,
  });

  final UnifiedTimelinePresentation presentation;
  final String projectedClipId;
  final Map<String, String> rowClipIdToSourceClipId;
}

class UnifiedTimelineFocusRoutingDecision {
  const UnifiedTimelineFocusRoutingDecision({
    required this.route,
    required this.sourceId,
    required this.message,
    this.issue,
  });

  final UnifiedTimelineFocusRoute route;
  final String sourceId;
  final String message;
  final UnifiedTimelineFocusIssue? issue;

  bool get isSupported => route != UnifiedTimelineFocusRoute.unsupported;
}

class UnifiedTimelineFocusRoutingAdapter {
  const UnifiedTimelineFocusRoutingAdapter();

  UnifiedTimelineFocusRoutingDecision resolve(
    UnifiedTimelineFocusRoutingRequest request,
  ) {
    final sourceId = request.rowClipIdToSourceClipId[request.projectedClipId] ??
        request.projectedClipId;
    final row = _rowFor(
      presentation: request.presentation,
      projectedClipId: request.projectedClipId,
      sourceId: sourceId,
    );
    if (row == null) {
      return UnifiedTimelineFocusRoutingDecision(
        route: UnifiedTimelineFocusRoute.unsupported,
        sourceId: sourceId,
        message: 'Unable to resolve unified timeline focus target.',
        issue: UnifiedTimelineFocusIssue(
          code: UnifiedTimelineFocusIssueCode.rowNotFound,
          message:
              'No unified timeline row matched clip `${request.projectedClipId}`.',
          sourceId: sourceId,
        ),
      );
    }

    if (row.layerType == UnifiedTimelineLayerType.audio) {
      return UnifiedTimelineFocusRoutingDecision(
        route: UnifiedTimelineFocusRoute.unsupported,
        sourceId: sourceId,
        message: 'Audio keyframe focus is not available yet.',
        issue: UnifiedTimelineFocusIssue(
          code: UnifiedTimelineFocusIssueCode.audioLayerFocusUnsupported,
          message: 'Audio rows are not focusable in this adapter checkpoint.',
          rowId: row.id,
          sourceId: sourceId,
        ),
      );
    }

    if (row.isTransition ||
        row.layerType == UnifiedTimelineLayerType.adjustment) {
      return UnifiedTimelineFocusRoutingDecision(
        route: UnifiedTimelineFocusRoute.adjustmentScope,
        sourceId: sourceId,
        message: row.canFocusKeyframes
            ? 'Opening adjustment keyframe focus.'
            : 'Opening adjustment layer controls.',
      );
    }

    if (row.sourceKind == 'scene') {
      return UnifiedTimelineFocusRoutingDecision(
        route: UnifiedTimelineFocusRoute.sceneScopeFallback,
        sourceId: sourceId,
        message: 'Opening Scene Scope fallback for this scene clip.',
      );
    }

    if (row.canFocusKeyframes) {
      return UnifiedTimelineFocusRoutingDecision(
        route: UnifiedTimelineFocusRoute.layerScope,
        sourceId: sourceId,
        message: 'Opening Keyframe Motion Timeline.',
      );
    }

    return UnifiedTimelineFocusRoutingDecision(
      route: UnifiedTimelineFocusRoute.unsupported,
      sourceId: sourceId,
      message: 'This layer is not keyframe-focusable in the current scope.',
      issue: UnifiedTimelineFocusIssue(
        code: UnifiedTimelineFocusIssueCode.rowCannotFocusKeyframes,
        message: 'Row `${row.id}` cannot focus keyframes in this checkpoint.',
        rowId: row.id,
        sourceId: sourceId,
      ),
    );
  }

  UnifiedTimelinePresentationRow? _rowFor({
    required UnifiedTimelinePresentation presentation,
    required String projectedClipId,
    required String sourceId,
  }) {
    for (final row in presentation.rows) {
      if (row.id == projectedClipId) {
        return row;
      }
    }
    for (final row in presentation.rows) {
      if (row.sourceId == sourceId) {
        return row;
      }
    }
    return null;
  }
}
