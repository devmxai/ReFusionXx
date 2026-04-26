import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/layer_scope_motion_authoring_adapter.dart';

void main() {
  const adapter = LayerScopeMotionAuthoringAdapter();
  const motionTarget = MotionPropertyTarget(
    kind: MotionTargetKind.element,
    targetId: 'title',
    projectId: 'project',
    sceneId: 'scene',
    layerId: 'layer',
    elementId: 'title',
  );

  TimelineTime time(double seconds) => TimelineTime.fromSecondsDouble(seconds);

  TimelineTimeRange range(double start, double end) {
    return TimelineTimeRange(start: time(start), endExclusive: time(end));
  }

  LayerScopeMotionAuthoringTarget target() {
    final activeRange = range(0, 4);
    return LayerScopeMotionAuthoringTarget(
      elementId: 'title',
      targetClipId: 'clip-title',
      motionTarget: motionTarget,
      activeRange: activeRange,
      projectionWindow: activeRange,
    );
  }

  test('adds opacity keyframes through the shared graph operation layer', () {
    final result = adapter.addOpacityKeyframe(
      channels: const [],
      target: target(),
      time: time(1),
      percent: 25,
    );

    expect(result.canApply, isTrue);
    expect(result.channels, hasLength(1));
    expect(
        result.channels.single.definition.id, MotionPropertyCatalog.opacity.id);
    expect(result.channels.single.keyframes.single.value.rawValue, 0.25);
    expect(result.lanes, hasLength(1));
    expect(result.lanes.single.label, 'Opacity');
    expect(result.lanes.single.normalizedKeyframeStops, <double>[0.25]);
    expect(result.lanes.single.keyframeValues, <double>[25]);
  });

  test('moves and edits opacity keyframes by stable channel and keyframe IDs',
      () {
    var result = adapter.addOpacityKeyframe(
      channels: const [],
      target: target(),
      time: time(1),
      percent: 25,
    );
    final channelId = result.lanes.single.id;
    final keyframeId = result.lanes.single.keyframeIds.single;

    result = adapter.moveKeyframe(
      channels: result.channels,
      target: target(),
      channelId: channelId,
      keyframeId: keyframeId,
      time: time(2),
    );

    expect(result.canApply, isTrue);
    expect(result.lanes.single.keyframeIds, <String>[keyframeId]);
    expect(result.lanes.single.normalizedKeyframeStops, <double>[0.5]);

    result = adapter.setOpacityKeyframeValue(
      channels: result.channels,
      target: target(),
      channelId: channelId,
      keyframeId: keyframeId,
      percent: 90,
    );

    expect(result.canApply, isTrue);
    expect(result.channels.single.keyframes.single.id, keyframeId);
    expect(result.channels.single.keyframes.single.value.rawValue, 0.9);
    expect(result.lanes.single.keyframeValues, <double>[90]);
  });

  test('deletes opacity keyframes without leaving a fake projected key', () {
    var result = adapter.addOpacityKeyframe(
      channels: const [],
      target: target(),
      time: time(1),
      percent: 50,
    );
    final channelId = result.lanes.single.id;
    final keyframeId = result.lanes.single.keyframeIds.single;

    result = adapter.deleteKeyframe(
      channels: result.channels,
      target: target(),
      channelId: channelId,
      keyframeId: keyframeId,
    );

    expect(result.canApply, isTrue);
    expect(result.channels.single.keyframes, isEmpty);
    expect(result.lanes.single.keyframeIds, isEmpty);
    expect(result.lanes.single.keyframeValues, isEmpty);
  });

  test('reports operation issues without projecting stale lanes', () {
    final result = adapter.setOpacityKeyframeValue(
      channels: const [],
      target: target(),
      channelId: 'missing-channel',
      keyframeId: 'missing-key',
      percent: 70,
    );

    expect(result.canApply, isFalse);
    expect(result.lanes, isEmpty);
    expect(result.issues.single.channelId, 'missing-channel');
    expect(
      result.issues.single.code,
      LayerScopeMotionAuthoringIssueCode.operationIssue,
    );
  });
}
