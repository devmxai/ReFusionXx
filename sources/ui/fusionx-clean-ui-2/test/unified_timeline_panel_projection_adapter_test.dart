import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/models/unified_timeline_presentation_models.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_panel_projection_adapter.dart';

void main() {
  const adapter = UnifiedTimelinePanelProjectionAdapter();

  UnifiedTimelinePresentation presentation() {
    return UnifiedTimelinePresentation(
      scopeKind: UnifiedTimelineScopeKind.root,
      currentTime: TimelineTime.fromMilliseconds(500),
      durationTime: TimelineTime.fromMilliseconds(4000),
      selectedRowId: 'clip:text',
      rows: <UnifiedTimelinePresentationRow>[
        UnifiedTimelinePresentationRow(
          id: 'clip:media',
          trackId: 'track:video',
          sourceId: 'media-source',
          layerType: UnifiedTimelineLayerType.media,
          sourceKind: 'media',
          label: 'Media',
          startTime: TimelineTime.zero,
          durationTime: TimelineTime.fromMilliseconds(2000),
          zIndex: 0,
          isVisible: true,
          isLocked: false,
          isMuted: false,
          isTransition: false,
          canFocusKeyframes: true,
          canTrim: true,
          canMove: true,
          canReceiveEffects: true,
        ),
        UnifiedTimelinePresentationRow(
          id: 'clip:text',
          trackId: 'track:text',
          sourceId: 'text-source',
          layerType: UnifiedTimelineLayerType.text,
          sourceKind: 'text',
          label: 'Title',
          startTime: TimelineTime.fromMilliseconds(300),
          durationTime: TimelineTime.fromMilliseconds(1300),
          zIndex: 1,
          isVisible: true,
          isLocked: false,
          isMuted: false,
          isTransition: false,
          canFocusKeyframes: true,
          canTrim: true,
          canMove: true,
          canReceiveEffects: true,
        ),
        UnifiedTimelinePresentationRow(
          id: 'clip:adjustment',
          trackId: 'track:fx',
          sourceId: 'fx-source',
          layerType: UnifiedTimelineLayerType.adjustment,
          sourceKind: 'transition',
          label: 'Cross Dissolve',
          startTime: TimelineTime.fromMilliseconds(1200),
          durationTime: TimelineTime.fromMilliseconds(600),
          zIndex: 2,
          isVisible: true,
          isLocked: false,
          isMuted: false,
          isTransition: true,
          canFocusKeyframes: true,
          canTrim: true,
          canMove: true,
          canReceiveEffects: true,
        ),
      ],
      issues: const <UnifiedTimelinePresentationIssue>[],
    );
  }

  test('projects unified rows into timeline panel tracks', () {
    final result = adapter.project(presentation());

    expect(result.hasIssues, isFalse);
    expect(result.tracks, hasLength(3));
    expect(result.tracks[0].kind.name, 'video');
    expect(result.tracks[1].kind.name, 'text');
    expect(result.tracks[2].kind.name, 'shape');
    expect(
      result.tracks.map((track) => track.clips.single.label),
      <String>['Media', 'Title', 'Cross Dissolve'],
    );
  });

  test('returns source-id to projected-clip-id mapping', () {
    final result = adapter.project(presentation());

    expect(result.sourceClipIdToRowClipId['media-source'], 'clip:media');
    expect(result.sourceClipIdToRowClipId['text-source'], 'clip:text');
    expect(result.sourceClipIdToRowClipId['fx-source'], 'clip:adjustment');
  });
}
