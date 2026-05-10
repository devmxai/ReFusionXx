import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/models/unified_timeline_presentation_models.dart';
import 'package:refusion_app/features/editor/presentation/services/unified_timeline_focus_routing_adapter.dart';

void main() {
  const adapter = UnifiedTimelineFocusRoutingAdapter();

  UnifiedTimelinePresentation presentation() {
    return UnifiedTimelinePresentation(
      scopeKind: UnifiedTimelineScopeKind.root,
      currentTime: TimelineTime.zero,
      durationTime: TimelineTime.fromMilliseconds(6000),
      rows: <UnifiedTimelinePresentationRow>[
        UnifiedTimelinePresentationRow(
          id: 'row:text',
          trackId: 'track:text',
          sourceId: 'clip:text',
          layerType: UnifiedTimelineLayerType.text,
          sourceKind: 'media',
          label: 'Title',
          startTime: TimelineTime.zero,
          durationTime: TimelineTime.fromMilliseconds(2000),
          zIndex: 2,
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
          id: 'row:scene',
          trackId: 'track:scene',
          sourceId: 'clip:scene',
          layerType: UnifiedTimelineLayerType.media,
          sourceKind: 'scene',
          label: 'Scene',
          startTime: TimelineTime.fromMilliseconds(2000),
          durationTime: TimelineTime.fromMilliseconds(2000),
          zIndex: 1,
          isVisible: true,
          isLocked: false,
          isMuted: false,
          isTransition: false,
          canFocusKeyframes: false,
          canTrim: true,
          canMove: true,
          canReceiveEffects: true,
        ),
        UnifiedTimelinePresentationRow(
          id: 'row:adjustment',
          trackId: 'track:fx',
          sourceId: 'transition:01',
          layerType: UnifiedTimelineLayerType.adjustment,
          sourceKind: 'transition',
          label: 'Cross Dissolve',
          startTime: TimelineTime.fromMilliseconds(3000),
          durationTime: TimelineTime.fromMilliseconds(500),
          zIndex: 3,
          isVisible: true,
          isLocked: false,
          isMuted: false,
          isTransition: true,
          canFocusKeyframes: true,
          canTrim: true,
          canMove: true,
          canReceiveEffects: true,
        ),
        UnifiedTimelinePresentationRow(
          id: 'row:audio',
          trackId: 'track:audio',
          sourceId: 'audio:01',
          layerType: UnifiedTimelineLayerType.audio,
          sourceKind: 'media',
          label: 'Music',
          startTime: TimelineTime.fromMilliseconds(0),
          durationTime: TimelineTime.fromMilliseconds(6000),
          zIndex: 0,
          isVisible: true,
          isLocked: false,
          isMuted: false,
          isTransition: false,
          canFocusKeyframes: false,
          canTrim: true,
          canMove: true,
          canReceiveEffects: false,
        ),
      ],
      issues: const <UnifiedTimelinePresentationIssue>[],
    );
  }

  test('routes text row to layer-scope focus', () {
    final decision = adapter.resolve(
      UnifiedTimelineFocusRoutingRequest(
        presentation: presentation(),
        projectedClipId: 'row:text',
        rowClipIdToSourceClipId: const <String, String>{
          'row:text': 'clip:text',
        },
      ),
    );

    expect(decision.route, UnifiedTimelineFocusRoute.layerScope);
    expect(decision.sourceId, 'clip:text');
    expect(decision.isSupported, isTrue);
  });

  test('routes scene row to scene-scope fallback', () {
    final decision = adapter.resolve(
      UnifiedTimelineFocusRoutingRequest(
        presentation: presentation(),
        projectedClipId: 'row:scene',
        rowClipIdToSourceClipId: const <String, String>{
          'row:scene': 'clip:scene',
        },
      ),
    );

    expect(decision.route, UnifiedTimelineFocusRoute.sceneScopeFallback);
    expect(decision.sourceId, 'clip:scene');
  });

  test('routes adjustment row to adjustment scope', () {
    final decision = adapter.resolve(
      UnifiedTimelineFocusRoutingRequest(
        presentation: presentation(),
        projectedClipId: 'row:adjustment',
        rowClipIdToSourceClipId: const <String, String>{
          'row:adjustment': 'transition:01',
        },
      ),
    );

    expect(decision.route, UnifiedTimelineFocusRoute.adjustmentScope);
    expect(decision.sourceId, 'transition:01');
  });

  test('returns unsupported for audio row', () {
    final decision = adapter.resolve(
      UnifiedTimelineFocusRoutingRequest(
        presentation: presentation(),
        projectedClipId: 'row:audio',
        rowClipIdToSourceClipId: const <String, String>{
          'row:audio': 'audio:01',
        },
      ),
    );

    expect(decision.route, UnifiedTimelineFocusRoute.unsupported);
    expect(
      decision.issue?.code,
      UnifiedTimelineFocusIssueCode.audioLayerFocusUnsupported,
    );
  });
}
