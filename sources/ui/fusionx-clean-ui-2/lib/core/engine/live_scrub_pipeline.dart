import 'dart:async';

import 'package:flutter/foundation.dart';

import 'live_scrub_preview_sources.dart';
import 'stage5_native_transport_controller.dart';

enum LiveScrubVelocityClass { slow, medium, fast }

enum LiveScrubPreviewPath { transportSeekLegacy, proxyPreview, frameCache }

@immutable
class LiveScrubFrameRequest {
  const LiveScrubFrameRequest({
    required this.positionMs,
    this.velocityPxPerSecond = 0,
    this.velocityClass = LiveScrubVelocityClass.slow,
  });

  final int positionMs;
  final double velocityPxPerSecond;
  final LiveScrubVelocityClass velocityClass;
}

@immutable
class LiveScrubSessionConfig {
  const LiveScrubSessionConfig({
    required this.anchorPositionMs,
    this.path = LiveScrubPreviewPath.frameCache,
    this.previewSources = const <LiveScrubPreviewSourceDescriptor>[],
  });

  final int anchorPositionMs;
  final LiveScrubPreviewPath path;
  final List<LiveScrubPreviewSourceDescriptor> previewSources;
}

abstract class PlaybackController {
  Future<void> play();
  Future<void> pause();
  Future<void> togglePlayPause();
  Future<void> exactSeekTo(int positionMs);
}

abstract class ScrubPreviewController {
  Future<void> beginSession(LiveScrubSessionConfig config);
  Future<void> presentFrame(LiveScrubFrameRequest request);
  Future<void> endSession({required int finalPositionMs});
}

class TransportBackedPlaybackController implements PlaybackController {
  TransportBackedPlaybackController(this._transportController);

  final Stage5NativeTransportController _transportController;

  @override
  Future<void> exactSeekTo(int positionMs) =>
      _transportController.seekToPositionMs(positionMs);

  @override
  Future<void> pause() => _transportController.pause();

  @override
  Future<void> play() => _transportController.play();

  @override
  Future<void> togglePlayPause() => _transportController.togglePlayPause();
}

class TransportBackedScrubPreviewController implements ScrubPreviewController {
  const TransportBackedScrubPreviewController();

  @override
  Future<void> beginSession(LiveScrubSessionConfig config) =>
      SynchronousFuture<void>(null);

  @override
  Future<void> endSession({required int finalPositionMs}) =>
      SynchronousFuture<void>(null);

  @override
  Future<void> presentFrame(LiveScrubFrameRequest request) =>
      SynchronousFuture<void>(null);
}

/// Session coordinator for the post-transport live scrub migration.
///
/// During active scrub the player is paused and left out of the per-frame path.
/// The only player interaction that remains here is the final exact seek when
/// the scrub session ends.
class LiveScrubPipeline {
  LiveScrubPipeline({
    required PlaybackController playbackController,
    required ScrubPreviewController scrubPreviewController,
  })  : _playbackController = playbackController,
        _scrubPreviewController = scrubPreviewController;

  final PlaybackController _playbackController;
  final ScrubPreviewController _scrubPreviewController;

  bool _isSessionActive = false;
  int _lastRequestedPositionMs = 0;

  bool get isSessionActive => _isSessionActive;

  Future<void> beginSession(LiveScrubSessionConfig config) async {
    _lastRequestedPositionMs = config.anchorPositionMs;
    await _playbackController.pause();
    _isSessionActive = true;
    await _scrubPreviewController.beginSession(config);
  }

  Future<void> presentFrame(LiveScrubFrameRequest request) async {
    _lastRequestedPositionMs = request.positionMs;
    if (!_isSessionActive) {
      await beginSession(
        LiveScrubSessionConfig(anchorPositionMs: request.positionMs),
      );
    }
    await _scrubPreviewController.presentFrame(request);
  }

  Future<void> endSession({int? finalPositionMs}) async {
    final resolvedFinalPositionMs = finalPositionMs ?? _lastRequestedPositionMs;
    _lastRequestedPositionMs = resolvedFinalPositionMs;
    if (_isSessionActive) {
      await _scrubPreviewController.endSession(
        finalPositionMs: resolvedFinalPositionMs,
      );
    }
    await _playbackController.exactSeekTo(resolvedFinalPositionMs);
    _isSessionActive = false;
  }
}
