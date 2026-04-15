import 'package:flutter/foundation.dart';

enum LiveScrubPreviewSourceStatus { discovered, warming, ready, failed }

@immutable
class LiveScrubPreviewSourceDescriptor {
  const LiveScrubPreviewSourceDescriptor({
    required this.clipId,
    required this.assetId,
    required this.sourceUri,
    required this.previewUri,
    required this.scrubStoreKey,
    required this.label,
    required this.timelineStartMs,
    required this.timelineEndMs,
    required this.durationMs,
    required this.sourceStartMs,
    required this.sourceDurationMs,
    required this.playbackRate,
    this.status = LiveScrubPreviewSourceStatus.discovered,
    this.frameIntervalMs,
    this.frameCount,
    this.storageTier,
  });

  final String clipId;
  final String assetId;
  final String sourceUri;
  final String previewUri;
  final String scrubStoreKey;
  final String label;
  final int timelineStartMs;
  final int timelineEndMs;
  final int durationMs;
  final int sourceStartMs;
  final int sourceDurationMs;
  final double playbackRate;
  final LiveScrubPreviewSourceStatus status;
  final int? frameIntervalMs;
  final int? frameCount;
  final String? storageTier;

  bool containsPosition(int positionMs) =>
      positionMs >= timelineStartMs && positionMs < timelineEndMs;

  LiveScrubPreviewSourceDescriptor copyWith({
    LiveScrubPreviewSourceStatus? status,
    int? frameIntervalMs,
    int? frameCount,
    String? storageTier,
  }) {
    return LiveScrubPreviewSourceDescriptor(
      clipId: clipId,
      assetId: assetId,
      sourceUri: sourceUri,
      previewUri: previewUri,
      scrubStoreKey: scrubStoreKey,
      label: label,
      timelineStartMs: timelineStartMs,
      timelineEndMs: timelineEndMs,
      durationMs: durationMs,
      sourceStartMs: sourceStartMs,
      sourceDurationMs: sourceDurationMs,
      playbackRate: playbackRate,
      status: status ?? this.status,
      frameIntervalMs: frameIntervalMs ?? this.frameIntervalMs,
      frameCount: frameCount ?? this.frameCount,
      storageTier: storageTier ?? this.storageTier,
    );
  }
}

class LiveScrubPreviewSessionSources {
  const LiveScrubPreviewSessionSources({
    this.primary,
    this.previous,
    this.next,
  });

  final LiveScrubPreviewSourceDescriptor? primary;
  final LiveScrubPreviewSourceDescriptor? previous;
  final LiveScrubPreviewSourceDescriptor? next;

  List<LiveScrubPreviewSourceDescriptor> get orderedUnique {
    final result = <LiveScrubPreviewSourceDescriptor>[];
    final seenClipIds = <String>{};
    for (final descriptor in <LiveScrubPreviewSourceDescriptor?>[
      previous,
      primary,
      next,
    ]) {
      if (descriptor == null || !seenClipIds.add(descriptor.clipId)) {
        continue;
      }
      result.add(descriptor);
    }
    return result;
  }
}

class InMemoryLiveScrubPreviewSourceCatalog {
  final Map<String, LiveScrubPreviewSourceDescriptor> _descriptorsByClipId =
      <String, LiveScrubPreviewSourceDescriptor>{};

  List<LiveScrubPreviewSourceDescriptor> get descriptors =>
      _descriptorsByClipId.values.toList(growable: false)
        ..sort(
          (left, right) =>
              left.timelineStartMs.compareTo(right.timelineStartMs),
        );

  void replaceAll(Iterable<LiveScrubPreviewSourceDescriptor> descriptors) {
    _descriptorsByClipId
      ..clear()
      ..addEntries(
        descriptors
            .map((descriptor) => MapEntry(descriptor.clipId, descriptor)),
      );
  }

  void markStatus(
    String clipId,
    LiveScrubPreviewSourceStatus status,
  ) {
    final current = _descriptorsByClipId[clipId];
    if (current == null || current.status == status) {
      return;
    }
    _descriptorsByClipId[clipId] = current.copyWith(status: status);
  }

  LiveScrubPreviewSessionSources resolveSessionSources(int positionMs) {
    final ordered = descriptors;
    if (ordered.isEmpty) {
      return const LiveScrubPreviewSessionSources();
    }
    var primaryIndex = ordered.indexWhere(
      (descriptor) => descriptor.containsPosition(positionMs),
    );
    if (primaryIndex < 0) {
      primaryIndex = ordered.lastIndexWhere(
        (descriptor) => descriptor.timelineStartMs <= positionMs,
      );
      if (primaryIndex < 0) {
        primaryIndex = 0;
      }
    }
    final primary = ordered[primaryIndex];
    final previous = primaryIndex > 0 ? ordered[primaryIndex - 1] : null;
    final next =
        primaryIndex + 1 < ordered.length ? ordered[primaryIndex + 1] : null;
    return LiveScrubPreviewSessionSources(
      primary: primary,
      previous: previous,
      next: next,
    );
  }
}
