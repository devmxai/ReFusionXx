import '../../../../core/engine/stage5_native_transport_controller.dart';

abstract class TimelineTransportRuntimeAdapter {
  bool get isPlaying;

  bool get isScrubSettling;

  bool get hasRenderedFirstFrame;

  bool get isPreviewContentSized;

  Future<void> play();

  Future<void> pause();

  Future<void> seekToPositionMs(int positionMs);

  Future<void> settleAfterScrubPositionMs(int positionMs);

  Future<Object?> prepareTimelineSegments({
    required List<Map<String, dynamic>> segments,
    required int startPositionMs,
  });
}

class Stage5TransportRuntimeAdapter implements TimelineTransportRuntimeAdapter {
  const Stage5TransportRuntimeAdapter(this.controller);

  final Stage5NativeTransportController controller;

  @override
  bool get isPlaying => controller.state.isPlaying;

  @override
  bool get isScrubSettling => controller.state.isScrubSettling;

  @override
  bool get hasRenderedFirstFrame => controller.state.hasRenderedFirstFrame;

  @override
  bool get isPreviewContentSized => controller.state.isPreviewContentSized;

  @override
  Future<void> play() => controller.play();

  @override
  Future<void> pause() => controller.pause();

  @override
  Future<void> seekToPositionMs(int positionMs) {
    return controller.seekToPositionMs(positionMs);
  }

  @override
  Future<void> settleAfterScrubPositionMs(int positionMs) {
    return controller.settleAfterScrubPositionMs(positionMs);
  }

  @override
  Future<Object?> prepareTimelineSegments({
    required List<Map<String, dynamic>> segments,
    required int startPositionMs,
  }) {
    return controller.prepareTimelineSegments(
      segments: segments,
      startPositionMs: startPositionMs,
    );
  }
}

abstract class TimelineScrubRuntimeAdapter {
  Future<void> flushConfig();

  Future<bool> awaitReadiness({
    required int positionMs,
    required int timeoutMs,
  });
}

class CallbackTimelineScrubRuntimeAdapter
    implements TimelineScrubRuntimeAdapter {
  const CallbackTimelineScrubRuntimeAdapter({
    this.onFlushConfig,
    this.onAwaitReadiness,
  });

  final Future<void> Function()? onFlushConfig;
  final Future<bool> Function({
    required int positionMs,
    required int timeoutMs,
  })? onAwaitReadiness;

  @override
  Future<void> flushConfig() async {
    await onFlushConfig?.call();
  }

  @override
  Future<bool> awaitReadiness({
    required int positionMs,
    required int timeoutMs,
  }) async {
    final awaitReadinessCallback = onAwaitReadiness;
    if (awaitReadinessCallback == null) {
      return true;
    }
    return await awaitReadinessCallback(
      positionMs: positionMs,
      timeoutMs: timeoutMs,
    );
  }
}

abstract class TimelinePreviewRuntimeAdapter {
  bool get hasFreshPreview;

  Future<void> awaitFreshPreview({
    required int positionMs,
    required Duration timeout,
  });
}

class CallbackTimelinePreviewRuntimeAdapter
    implements TimelinePreviewRuntimeAdapter {
  const CallbackTimelinePreviewRuntimeAdapter({
    this.onHasFreshPreview,
    this.onAwaitFreshPreview,
  });

  final bool Function()? onHasFreshPreview;
  final Future<void> Function({
    required int positionMs,
    required Duration timeout,
  })? onAwaitFreshPreview;

  @override
  bool get hasFreshPreview => onHasFreshPreview?.call() ?? true;

  @override
  Future<void> awaitFreshPreview({
    required int positionMs,
    required Duration timeout,
  }) async {
    await onAwaitFreshPreview?.call(
      positionMs: positionMs,
      timeout: timeout,
    );
  }
}

abstract class TimelineProjectionAdapter {
  int get timelineRevision;

  List<Map<String, dynamic>> buildTransportSegments();
}

class StaticTimelineProjectionAdapter implements TimelineProjectionAdapter {
  const StaticTimelineProjectionAdapter({
    required this.timelineRevision,
    required this.segments,
  });

  @override
  final int timelineRevision;

  final List<Map<String, dynamic>> segments;

  @override
  List<Map<String, dynamic>> buildTransportSegments() {
    return segments
        .map((segment) => Map<String, dynamic>.unmodifiable(segment))
        .toList(growable: false);
  }
}
