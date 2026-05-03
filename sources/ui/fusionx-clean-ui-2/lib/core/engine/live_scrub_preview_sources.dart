import 'package:flutter/foundation.dart';

enum LiveScrubPreviewSourceStatus { discovered, warming, ready, failed }

@immutable
class LiveScrubPreviewSourceDescriptor {
  const LiveScrubPreviewSourceDescriptor({
    required this.clipId,
    required this.assetId,
    required this.sourceUri,
    required this.scrubStoreKey,
    this.previewUri,
    required this.label,
    required this.timelineStartMs,
    required this.timelineEndMs,
    required this.durationMs,
    required this.sourceStartMs,
    required this.sourceDurationMs,
    required this.playbackRate,
    this.sourceWidth,
    this.sourceHeight,
    this.status = LiveScrubPreviewSourceStatus.discovered,
    this.frameIntervalMs,
    this.frameCount,
    this.storageTier,
    this.transformMatrix3x3 = const <double>[
      1.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      1.0,
    ],
    this.opacity = 1.0,
    this.effectProgramIds = const <String>[],
    this.transitionRole = 'none',
    this.transitionId,
    this.transitionProgress,
    this.transitionTimelineStartMs,
    this.transitionTimelineEndMs,
    this.runtimeBlockers = const <String>[],
  });

  final String clipId;
  final String assetId;
  final String sourceUri;
  final String scrubStoreKey;
  final String? previewUri;
  final String label;
  final int timelineStartMs;
  final int timelineEndMs;
  final int durationMs;
  final int sourceStartMs;
  final int sourceDurationMs;
  final double playbackRate;
  final int? sourceWidth;
  final int? sourceHeight;
  final LiveScrubPreviewSourceStatus status;
  final int? frameIntervalMs;
  final int? frameCount;
  final String? storageTier;
  final List<double> transformMatrix3x3;
  final double opacity;
  final List<String> effectProgramIds;
  final String transitionRole;
  final String? transitionId;
  final double? transitionProgress;
  final int? transitionTimelineStartMs;
  final int? transitionTimelineEndMs;
  final List<String> runtimeBlockers;

  bool containsPosition(int positionMs) =>
      positionMs >= timelineStartMs && positionMs < timelineEndMs;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'clipId': clipId,
      'assetId': assetId,
      'sourceUri': sourceUri,
      'scrubStoreKey': scrubStoreKey,
      'previewUri': previewUri,
      'label': label,
      'timelineStartMs': timelineStartMs,
      'timelineEndMs': timelineEndMs,
      'durationMs': durationMs,
      'sourceStartMs': sourceStartMs,
      'sourceDurationMs': sourceDurationMs,
      'playbackRate': playbackRate,
      'sourceWidth': sourceWidth,
      'sourceHeight': sourceHeight,
      'status': status.name,
      'frameIntervalMs': frameIntervalMs,
      'frameCount': frameCount,
      'storageTier': storageTier,
      'transformMatrix3x3': transformMatrix3x3,
      'opacity': opacity,
      'effectProgramIds': effectProgramIds,
      'transitionRole': transitionRole,
      'transitionId': transitionId,
      'transitionProgress': transitionProgress,
      'transitionTimelineStartMs': transitionTimelineStartMs,
      'transitionTimelineEndMs': transitionTimelineEndMs,
      'runtimeBlockers': runtimeBlockers,
    };
  }

  LiveScrubPreviewSourceDescriptor copyWith({
    LiveScrubPreviewSourceStatus? status,
    int? frameIntervalMs,
    int? frameCount,
    String? storageTier,
    int? sourceWidth,
    int? sourceHeight,
    List<double>? transformMatrix3x3,
    double? opacity,
    List<String>? effectProgramIds,
    String? transitionRole,
    String? transitionId,
    double? transitionProgress,
    int? transitionTimelineStartMs,
    int? transitionTimelineEndMs,
    List<String>? runtimeBlockers,
  }) {
    return LiveScrubPreviewSourceDescriptor(
      clipId: clipId,
      assetId: assetId,
      sourceUri: sourceUri,
      scrubStoreKey: scrubStoreKey,
      previewUri: previewUri,
      label: label,
      timelineStartMs: timelineStartMs,
      timelineEndMs: timelineEndMs,
      durationMs: durationMs,
      sourceStartMs: sourceStartMs,
      sourceDurationMs: sourceDurationMs,
      playbackRate: playbackRate,
      sourceWidth: sourceWidth ?? this.sourceWidth,
      sourceHeight: sourceHeight ?? this.sourceHeight,
      status: status ?? this.status,
      frameIntervalMs: frameIntervalMs ?? this.frameIntervalMs,
      frameCount: frameCount ?? this.frameCount,
      storageTier: storageTier ?? this.storageTier,
      transformMatrix3x3: transformMatrix3x3 ?? this.transformMatrix3x3,
      opacity: opacity ?? this.opacity,
      effectProgramIds: effectProgramIds ?? this.effectProgramIds,
      transitionRole: transitionRole ?? this.transitionRole,
      transitionId: transitionId ?? this.transitionId,
      transitionProgress: transitionProgress ?? this.transitionProgress,
      transitionTimelineStartMs:
          transitionTimelineStartMs ?? this.transitionTimelineStartMs,
      transitionTimelineEndMs:
          transitionTimelineEndMs ?? this.transitionTimelineEndMs,
      runtimeBlockers: runtimeBlockers ?? this.runtimeBlockers,
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
  List<LiveScrubPreviewSourceDescriptor> _orderedDescriptors =
      const <LiveScrubPreviewSourceDescriptor>[];

  List<LiveScrubPreviewSourceDescriptor> get descriptors => _orderedDescriptors;

  void _rebuildOrderedDescriptors() {
    _orderedDescriptors = _descriptorsByClipId.values.toList(growable: false)
      ..sort(
        (left, right) => left.timelineStartMs.compareTo(right.timelineStartMs),
      );
  }

  void replaceAll(Iterable<LiveScrubPreviewSourceDescriptor> descriptors) {
    final nextDescriptors = descriptors.toList(growable: false)
      ..sort(
        (left, right) => left.timelineStartMs.compareTo(right.timelineStartMs),
      );
    if (listEquals(_orderedDescriptors, nextDescriptors)) {
      return;
    }
    _descriptorsByClipId
      ..clear()
      ..addEntries(
        nextDescriptors
            .map((descriptor) => MapEntry(descriptor.clipId, descriptor)),
      );
    _orderedDescriptors = List<LiveScrubPreviewSourceDescriptor>.unmodifiable(
      nextDescriptors,
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
    _rebuildOrderedDescriptors();
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
