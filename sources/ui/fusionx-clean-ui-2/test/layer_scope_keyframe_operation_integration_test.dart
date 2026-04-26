import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/models/professional_canvas_timeline_authoring_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_animation_models.dart';
import 'package:refusion_app/features/editor/domain/models/professional_motion_models.dart';
import 'package:refusion_app/features/editor/domain/services/unified_keyframe_operations.dart';
import 'package:refusion_app/features/editor/presentation/models/timeline_time.dart';
import 'package:refusion_app/features/editor/presentation/services/layer_scope_motion_projection_adapter.dart';

void main() {
  const operations = UnifiedKeyframeOperationService();
  const adapter = LayerScopeMotionProjectionAdapter();
  const target = MotionPropertyTarget(
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

  test('layer scope opacity lane remains backed by real keyframe operations',
      () {
    final activeRange = range(0, 4);
    var channels = <MotionPropertyChannelModel>[];

    final added = operations.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: channels,
        target: target,
        activeRange: activeRange,
        definition: MotionPropertyCatalog.opacity,
        time: time(1),
        value: const MotionPropertyValue.scalar(0.25),
      ),
    );
    expect(added.hasIssues, isFalse);
    channels = added.channels;

    var projected = adapter.projectElement(
      channels: channels,
      elementId: 'title',
      targetClipId: 'clip-title',
      window: activeRange,
    );
    expect(projected.hasIssues, isFalse);
    expect(projected.lanes.single.keyframeValues, <double>[25]);
    expect(projected.lanes.single.normalizedKeyframeStops, <double>[0.25]);

    final channelId = projected.lanes.single.id;
    final keyframeId = projected.lanes.single.keyframeIds.single;
    final moved = operations.moveKeyframe(
      CanvasTimelineMoveKeyframeRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
        activeRange: activeRange,
        time: time(2),
      ),
    );
    expect(moved.hasIssues, isFalse);
    channels = moved.channels;

    projected = adapter.projectElement(
      channels: channels,
      elementId: 'title',
      targetClipId: 'clip-title',
      window: activeRange,
    );
    expect(projected.lanes.single.keyframeIds, <String>[keyframeId]);
    expect(projected.lanes.single.normalizedKeyframeStops, <double>[0.5]);

    final valued = operations.setKeyframeValue(
      CanvasTimelineKeyframeValueRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
        value: const MotionPropertyValue.scalar(0.9),
      ),
    );
    expect(valued.hasIssues, isFalse);
    channels = valued.channels;

    projected = adapter.projectElement(
      channels: channels,
      elementId: 'title',
      targetClipId: 'clip-title',
      window: activeRange,
    );
    expect(projected.lanes.single.keyframeValues, <double>[90]);

    final deleted = operations.deleteKeyframe(
      CanvasTimelineDeleteKeyframeRequest(
        channels: channels,
        channelId: channelId,
        keyframeId: keyframeId,
      ),
    );
    expect(deleted.hasIssues, isFalse);

    projected = adapter.projectElement(
      channels: deleted.channels,
      elementId: 'title',
      targetClipId: 'clip-title',
      window: activeRange,
    );
    expect(projected.hasIssues, isFalse);
    expect(projected.lanes.single.keyframeIds, isEmpty);
    expect(projected.lanes.single.keyframeValues, isEmpty);
  });
}
