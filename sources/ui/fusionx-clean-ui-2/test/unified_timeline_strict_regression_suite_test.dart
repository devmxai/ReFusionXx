import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/models/unified_timeline_presentation_models.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_legacy_compatibility_gate.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_panel_projection_adapter.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_presentation_adapter.dart';

void main() {
  const presentationAdapter = UnifiedTimelinePresentationAdapter();
  const panelProjectionAdapter = UnifiedTimelinePanelProjectionAdapter();
  const compatibilityGate = UnifiedTimelineLegacyCompatibilityGate();

  UnifiedTimelinePresentation buildPresentation(
    List<TimelineTrackData> tracks,
  ) {
    return presentationAdapter.build(
      UnifiedTimelinePresentationRequest(
        scopeKind: UnifiedTimelineScopeKind.root,
        currentTime: TimelineTime.fromMilliseconds(1000),
        durationTime: TimelineTime.fromMilliseconds(6000),
        tracks: tracks,
      ),
    );
  }

  test('non-blocking mapping issues still allow unified fallback-safe path',
      () {
    final lipSyncTrack = TimelineTrackData(
      kind: TimelineTrackKind.lipSync,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'lipsync-clip',
          type: TimelineClipType.media,
          tone: TimelineClipTone.aiGenerated,
          durationTime: TimelineTime.fromMilliseconds(1500),
          label: 'Lip Sync',
        ),
      ],
    );
    final cameraVisualTrack = TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'camera-ctrl',
          type: TimelineClipType.media,
          tone: TimelineClipTone.placeholder,
          durationTime: TimelineTime.fromMilliseconds(1200),
          visualKind: TimelineVisualKind.camera,
          label: 'Camera Control',
        ),
      ],
    );

    final presentation = buildPresentation(<TimelineTrackData>[
      lipSyncTrack,
      cameraVisualTrack,
    ]);
    final projection = panelProjectionAdapter.project(presentation);
    final decision = compatibilityGate.evaluate(
      presentation: presentation,
      projection: projection,
    );

    expect(
      presentation.issues.map((issue) => issue.code),
      containsAll(<UnifiedTimelinePresentationIssueCode>[
        UnifiedTimelinePresentationIssueCode
            .unsupportedTrackKindMappedAsAdjustment,
        UnifiedTimelinePresentationIssueCode
            .unsupportedVisualKindMappedAsAdjustment,
      ]),
    );
    expect(decision.canUseUnifiedPresentation, isTrue);
    expect(decision.hasBlockingIssues, isFalse);
  });

  test('blocking transition boundary issue forces legacy fallback', () {
    final brokenTransitionTrack = TimelineTrackData(
      kind: TimelineTrackKind.video,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'only-clip',
          type: TimelineClipType.media,
          tone: TimelineClipTone.hero,
          durationTime: TimelineTime.fromMilliseconds(2200),
          label: 'Only Clip',
        ),
      ],
      transitions: <TimelineTrackTransitionData>[
        TimelineTrackTransitionData(
          id: 'broken-transition',
          leftClipId: 'missing-left',
          rightClipId: 'missing-right',
          preset: TimelineTransitionPreset.crossDissolve,
          durationTime: TimelineTime.fromMilliseconds(800),
        ),
      ],
    );

    final presentation = buildPresentation(<TimelineTrackData>[
      brokenTransitionTrack,
    ]);
    final projection = panelProjectionAdapter.project(presentation);
    final decision = compatibilityGate.evaluate(
      presentation: presentation,
      projection: projection,
    );

    expect(
      presentation.issues.any(
        (issue) =>
            issue.code ==
            UnifiedTimelinePresentationIssueCode.transitionBoundaryNotFound,
      ),
      isTrue,
    );
    expect(decision.canUseUnifiedPresentation, isFalse);
    expect(decision.hasBlockingIssues, isTrue);
    expect(
      decision.issues.any(
        (issue) =>
            issue.reason ==
            UnifiedTimelineCompatibilityBlockReason.presentationIssue,
      ),
      isTrue,
    );
  });

  test('projection preserves source to projected identity with offset gap', () {
    final track = TimelineTrackData(
      kind: TimelineTrackKind.text,
      clips: <TimelineClipData>[
        TimelineClipData(
          id: 'first',
          type: TimelineClipType.media,
          tone: TimelineClipTone.aiGenerated,
          durationTime: TimelineTime.fromMilliseconds(1000),
          label: 'First',
        ),
        TimelineClipData(
          id: 'second',
          type: TimelineClipType.media,
          tone: TimelineClipTone.aiGenerated,
          durationTime: TimelineTime.fromMilliseconds(1000),
          label: 'Second',
        ),
      ],
    );

    final presentation = buildPresentation(<TimelineTrackData>[track]);
    final projection = panelProjectionAdapter.project(presentation);

    expect(projection.sourceClipIdToRowClipId['first'], isNotNull);
    expect(projection.sourceClipIdToRowClipId['second'], isNotNull);
    final secondTrack = projection.tracks.last;
    expect(secondTrack.clips, hasLength(2));
    expect(secondTrack.clips.first.id, startsWith('gap:'));
    expect(secondTrack.clips.last.label, 'Second');
  });
}
