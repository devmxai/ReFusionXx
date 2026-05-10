import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/models/unified_timeline_presentation_models.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_legacy_compatibility_gate.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_panel_projection_adapter.dart';

void main() {
  const gate = UnifiedTimelineLegacyCompatibilityGate();

  UnifiedTimelinePresentation basePresentation({
    List<UnifiedTimelinePresentationIssue> issues =
        const <UnifiedTimelinePresentationIssue>[],
  }) {
    return UnifiedTimelinePresentation(
      scopeKind: UnifiedTimelineScopeKind.root,
      currentTime: TimelineTime.zero,
      durationTime: TimelineTime.fromMilliseconds(3000),
      rows: const <UnifiedTimelinePresentationRow>[],
      issues: issues,
    );
  }

  UnifiedTimelinePanelProjectionResult baseProjection({
    List<UnifiedTimelinePanelProjectionIssue> issues =
        const <UnifiedTimelinePanelProjectionIssue>[],
  }) {
    return UnifiedTimelinePanelProjectionResult(
      tracks: const <TimelineTrackData>[],
      sourceClipIdToRowClipId: const <String, String>{},
      issues: issues,
    );
  }

  test('allows unified presentation when there are no blocking issues', () {
    final decision = gate.evaluate(
      presentation: basePresentation(),
      projection: baseProjection(),
    );

    expect(decision.canUseUnifiedPresentation, isTrue);
    expect(decision.hasBlockingIssues, isFalse);
  });

  test('blocks unified presentation for blocking presentation issue', () {
    final decision = gate.evaluate(
      presentation: basePresentation(
        issues: const <UnifiedTimelinePresentationIssue>[
          UnifiedTimelinePresentationIssue(
            code: UnifiedTimelinePresentationIssueCode.duplicateRowId,
            message: 'duplicate',
          ),
        ],
      ),
      projection: baseProjection(),
    );

    expect(decision.canUseUnifiedPresentation, isFalse);
    expect(decision.hasBlockingIssues, isTrue);
    expect(
      decision.issues.first.reason,
      UnifiedTimelineCompatibilityBlockReason.presentationIssue,
    );
  });

  test('does not block for non-blocking informational presentation issue', () {
    final decision = gate.evaluate(
      presentation: basePresentation(
        issues: const <UnifiedTimelinePresentationIssue>[
          UnifiedTimelinePresentationIssue(
            code: UnifiedTimelinePresentationIssueCode.sceneClipMappedAsMedia,
            message: 'scene mapped as media',
          ),
        ],
      ),
      projection: baseProjection(),
    );

    expect(decision.canUseUnifiedPresentation, isTrue);
    expect(decision.hasBlockingIssues, isFalse);
  });

  test('blocks unified presentation for projection issues', () {
    final decision = gate.evaluate(
      presentation: basePresentation(),
      projection: baseProjection(
        issues: const <UnifiedTimelinePanelProjectionIssue>[
          UnifiedTimelinePanelProjectionIssue(
            code: UnifiedTimelinePanelProjectionIssueCode.unsupportedLayerType,
            message: 'unsupported layer',
          ),
        ],
      ),
    );

    expect(decision.canUseUnifiedPresentation, isFalse);
    expect(decision.hasBlockingIssues, isTrue);
    expect(
      decision.issues.first.reason,
      UnifiedTimelineCompatibilityBlockReason.projectionIssue,
    );
  });
}
