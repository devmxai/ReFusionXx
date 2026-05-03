import '../../../../core/engine/live_scrub_preview_sources.dart';
import '../../domain/models/master_live_scrub_descriptor_models.dart';
import '../../domain/models/master_live_scrub_visual_program_models.dart';

class LiveScrubRuntimeSurfaceConfigAdapter {
  const LiveScrubRuntimeSurfaceConfigAdapter();

  List<LiveScrubPreviewSourceDescriptor> mergeProjectedSources({
    required List<LiveScrubPreviewSourceDescriptor> baselineSources,
    required LiveScrubDescriptorProjectionResult projection,
    required Map<String, LiveScrubTimelineSourceWindow> sourceWindowsByTargetId,
  }) {
    if (projection.descriptors.isEmpty || sourceWindowsByTargetId.isEmpty) {
      return baselineSources;
    }
    final replacements = <String, LiveScrubPreviewSourceDescriptor>{};
    for (final descriptor in projection.descriptors) {
      if (descriptor.sourceKind != LiveScrubSourceKind.video &&
          descriptor.sourceKind != LiveScrubSourceKind.image) {
        continue;
      }
      final sourceUri = descriptor.sourceUri.trim();
      if (sourceUri.isEmpty) {
        continue;
      }
      final window = sourceWindowsByTargetId[descriptor.targetId];
      if (window == null || window.timelineEndMs <= window.timelineStartMs) {
        continue;
      }
      final scrubStoreKey =
          (descriptor.scrubStoreKey?.trim().isNotEmpty ?? false)
              ? descriptor.scrubStoreKey!.trim()
              : descriptor.id;
      final playbackRate =
          window.playbackRate.isFinite && window.playbackRate > 0
              ? window.playbackRate
              : 1.0;
      replacements[descriptor.targetId] = LiveScrubPreviewSourceDescriptor(
        clipId: descriptor.targetId,
        assetId: scrubStoreKey,
        sourceUri: sourceUri,
        scrubStoreKey: scrubStoreKey,
        previewUri: null,
        label: descriptor.targetId,
        timelineStartMs: window.timelineStartMs,
        timelineEndMs: window.timelineEndMs,
        durationMs: window.timelineEndMs - window.timelineStartMs,
        sourceStartMs: window.sourceStartMs,
        sourceDurationMs: window.sourceDurationMs,
        playbackRate: playbackRate,
        sourceWidth: descriptor.sourceWidth,
        sourceHeight: descriptor.sourceHeight,
        status: LiveScrubPreviewSourceStatus.ready,
      );
    }
    if (replacements.isEmpty) {
      return baselineSources;
    }
    final mergedByClipId = <String, LiveScrubPreviewSourceDescriptor>{
      for (final baseline in baselineSources) baseline.clipId: baseline,
      ...replacements,
    };
    final merged = mergedByClipId.values.toList(growable: false)
      ..sort(
        (left, right) => left.timelineStartMs.compareTo(right.timelineStartMs),
      );
    return List<LiveScrubPreviewSourceDescriptor>.unmodifiable(merged);
  }
}
