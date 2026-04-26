import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_mock_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_bridge_entry_adapter.dart';
import 'package:refusion_app/features/editor/presentation/services/transition_unified_scope_entry_gate.dart';

void main() {
  TimelineClipData clip({
    required String id,
    required int milliseconds,
  }) {
    return TimelineClipData(
      id: id,
      type: TimelineClipType.media,
      tone: TimelineClipTone.hero,
      durationTime: TimelineTime.fromMilliseconds(milliseconds),
      sourceDurationTime: TimelineTime.fromMilliseconds(milliseconds),
    );
  }

  TransitionUnifiedScopeBridgeEntryRequest request({
    TimelineTransitionPreset preset = TimelineTransitionPreset.crossDissolve,
    TimelineClipData? left,
    TimelineClipData? right,
    TimelineClipData? middle,
  }) {
    final resolvedLeft = left ?? clip(id: 'clip-a', milliseconds: 8000);
    final resolvedRight = right ?? clip(id: 'clip-b', milliseconds: 6000);
    return TransitionUnifiedScopeBridgeEntryRequest(
      track: TimelineTrackData(
        kind: TimelineTrackKind.video,
        clips: <TimelineClipData>[
          resolvedLeft,
          if (middle != null) middle,
          resolvedRight,
        ],
      ),
      leftClip: resolvedLeft,
      rightClip: resolvedRight,
      preset: preset,
      projectId: 'project',
      sceneId: 'scene',
      trackId: 'video-main',
      format: const MotionProjectFormat(
        canvasSize: MotionSize2D(width: 1080, height: 1920),
      ),
      frameRate: const MotionFrameRate(numerator: 60, denominator: 1),
    );
  }

  test('feature-disabled bridge entry falls back before graph work', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter();

    final result = adapter.resolveBridgeEntry(
      request(preset: TimelineTransitionPreset.manual),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.decision,
      TransitionUnifiedScopeEntryDecision.legacyTransitionScope,
    );
    expect(
      result.fallbackReason,
      TransitionUnifiedScopeBridgeFallbackReason.featureDisabled,
    );
    expect(result.factoryResult, isNull);
    expect(result.issues, isEmpty);
  });

  test('unsupported preset falls back with a clear issue when enabled', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter(
      config: const TransitionUnifiedScopeEntryConfig(
        enableUnifiedTransitionScope: true,
      ),
    );

    final result = adapter.resolveBridgeEntry(
      request(preset: TimelineTransitionPreset.manual),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.fallbackReason,
      TransitionUnifiedScopeBridgeFallbackReason.unsupportedPreset,
    );
    expect(result.issues.single.path, 'preset');
  });

  test('enabled cross dissolve bridge opens unified transition scope', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter(
      config: const TransitionUnifiedScopeEntryConfig(
        enableUnifiedTransitionScope: true,
      ),
    );

    final result = adapter.resolveBridgeEntry(request());

    expect(result.opensUnifiedScope, isTrue);
    expect(result.fallbackReason, isNull);
    expect(result.definition!.definitionId, 'cross_dissolve');
    expect(result.factoryResult!.canBuild, isTrue);
    expect(
      result.entryResult!.unifiedScope!.lanes!.lanes.map((lane) => lane.label),
      <String>['Outgoing Opacity', 'Incoming Opacity'],
    );
  });

  test('invalid boundary falls back before opening unified scope', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter(
      config: const TransitionUnifiedScopeEntryConfig(
        enableUnifiedTransitionScope: true,
      ),
    );

    final result = adapter.resolveBridgeEntry(
      request(middle: clip(id: 'middle', milliseconds: 1000)),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.fallbackReason,
      TransitionUnifiedScopeBridgeFallbackReason.requestBlocked,
    );
    expect(result.factoryResult!.canBuild, isFalse);
    expect(result.issues.single.path, 'boundary');
  });

  test('insufficient handles fall back through the entry gate', () {
    final adapter = TransitionUnifiedScopeBridgeEntryAdapter(
      config: const TransitionUnifiedScopeEntryConfig(
        enableUnifiedTransitionScope: true,
      ),
    );

    final result = adapter.resolveBridgeEntry(
      request(
        left: clip(id: 'clip-a', milliseconds: 1),
        right: clip(id: 'clip-b', milliseconds: 6000),
      ),
    );

    expect(result.opensUnifiedScope, isFalse);
    expect(
      result.fallbackReason,
      TransitionUnifiedScopeBridgeFallbackReason.entryGateBlocked,
    );
    expect(
      result.entryResult!.fallbackReason,
      TransitionUnifiedScopeEntryFallbackReason.graphApplyBlocked,
    );
    expect(result.issues.map((issue) => issue.path), contains('leftClipId'));
  });
}
