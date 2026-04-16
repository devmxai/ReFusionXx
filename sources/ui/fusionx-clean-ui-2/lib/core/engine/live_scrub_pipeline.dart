import 'dart:async';

import 'package:flutter/foundation.dart';

import 'live_scrub_preview_sources.dart';
import 'stage5_native_transport_controller.dart';

enum LiveScrubVelocityClass { slow, medium, fast }

enum LiveScrubPreviewPath { proxyPreview, frameCache }

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
  Future<void> settleAfterScrub(int positionMs);
}

abstract class ScrubPreviewController {
  Future<void> beginSession(LiveScrubSessionConfig config);
  Future<void> presentFrame(LiveScrubFrameRequest request);
  Future<void> endSession({required int finalPositionMs});
}

typedef ScrubPreviewWarmupCallback =
    void Function(
      LiveScrubPreviewSourceDescriptor descriptor, {
      int? preferredPreviewPositionMs,
    });

class TransportBackedPlaybackController implements PlaybackController {
  TransportBackedPlaybackController(this._transportController);

  final Stage5NativeTransportController _transportController;

  @override
  Future<void> exactSeekTo(int positionMs) =>
      _transportController.seekToPositionMs(positionMs);

  @override
  Future<void> settleAfterScrub(int positionMs) =>
      _transportController.settleAfterScrubPositionMs(positionMs);

  @override
  Future<void> pause() => _transportController.pause();

  @override
  Future<void> play() => _transportController.play();

  @override
  Future<void> togglePlayPause() => _transportController.togglePlayPause();
}

class TransportBackedScrubPreviewController implements ScrubPreviewController {
  TransportBackedScrubPreviewController(
    this._transportController, {
    this.targetWidth = 480,
    this.targetHeight = 854,
    this.onPreparingChanged,
    this.onFrameStoreStatusChanged,
    this.onWarmupRequested,
  }) {
    _transportController.addListener(_handleTransportStateChanged);
  }

  final Stage5NativeTransportController _transportController;
  final int targetWidth;
  final int targetHeight;
  final ValueChanged<bool>? onPreparingChanged;
  final ValueChanged<Stage5ScrubFrameStoreStatus>? onFrameStoreStatusChanged;
  final ScrubPreviewWarmupCallback? onWarmupRequested;

  LiveScrubSessionConfig? _activeConfig;
  String? _activeScrubStoreKey;
  bool _hasBegunTextureSession = false;
  bool _isBeginningTextureSession = false;
  int _textureSessionGeneration = 0;
  bool _retainTextureUntilSettle = false;

  static LiveScrubPreviewSourceDescriptor? _resolveDescriptorForPosition(
    LiveScrubSessionConfig config,
    int positionMs,
  ) {
    final previewSources = config.previewSources;
    if (previewSources.isEmpty) {
      return null;
    }
    for (final descriptor in previewSources) {
      if (descriptor.containsPosition(positionMs)) {
        return descriptor;
      }
    }
    LiveScrubPreviewSourceDescriptor? nearest;
    var nearestDistance = 1 << 30;
    for (final descriptor in previewSources) {
      final distance = positionMs < descriptor.timelineStartMs
          ? descriptor.timelineStartMs - positionMs
          : positionMs - descriptor.timelineEndMs;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = descriptor;
      }
    }
    return nearest;
  }

  static int _resolveSourcePositionMs(
    LiveScrubPreviewSourceDescriptor descriptor,
    int timelinePositionMs,
  ) {
    final localTimelineOffsetMs =
        (timelinePositionMs - descriptor.timelineStartMs).clamp(
      0,
      descriptor.durationMs,
    );
    final sourceOffsetMs = (localTimelineOffsetMs * descriptor.playbackRate).round();
    return (descriptor.sourceStartMs + sourceOffsetMs).clamp(
      descriptor.sourceStartMs,
      descriptor.sourceStartMs + descriptor.sourceDurationMs,
    );
  }

  void _handleTransportStateChanged() {
    if (_retainTextureUntilSettle &&
        !_transportController.state.isScrubSettling) {
      _retainTextureUntilSettle = false;
      unawaited(_disposeTextureSession());
    }
  }

  Future<void> _disposeTextureSession() async {
    _textureSessionGeneration += 1;
    _activeScrubStoreKey = null;
    _hasBegunTextureSession = false;
    _isBeginningTextureSession = false;
    await _transportController.endScrubPreviewTextureSession();
    await _transportController.clearScrubPreviewTexture();
  }

  Future<void> _presentPositionMs(int timelinePositionMs) async {
    final config = _activeConfig;
    if (config == null || config.path != LiveScrubPreviewPath.proxyPreview) {
      return;
    }
    final descriptor = _resolveDescriptorForPosition(config, timelinePositionMs);
    if (descriptor == null) {
      return;
    }
    final sourcePositionMs = _resolveSourcePositionMs(descriptor, timelinePositionMs);
    final status = await _transportController.requestScrubFrameWindow(
      assetId: descriptor.scrubStoreKey,
      positionMs: sourcePositionMs,
    );
    if (status != null) {
      onFrameStoreStatusChanged?.call(status);
    }
    final isWindowReady =
        status?.isActiveWindowReady == true ||
        status?.state == Stage5ScrubFrameStoreState.ready;
    if (!isWindowReady) {
      onPreparingChanged?.call(true);
      onWarmupRequested?.call(
        descriptor,
        preferredPreviewPositionMs: sourcePositionMs,
      );
      return;
    }
    _retainTextureUntilSettle = false;
    final requiresNewTextureSession =
        !_hasBegunTextureSession || _activeScrubStoreKey != descriptor.scrubStoreKey;
    if (requiresNewTextureSession) {
      if (_isBeginningTextureSession) {
        return;
      }
      final sessionGeneration = _textureSessionGeneration;
      _isBeginningTextureSession = true;
      try {
        onPreparingChanged?.call(true);
        final rendered = await _transportController.beginScrubPreviewTextureSession(
          scrubStoreKey: descriptor.scrubStoreKey,
          positionMs: sourcePositionMs,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
        if (sessionGeneration != _textureSessionGeneration ||
            _activeConfig != config) {
          return;
        }
        _activeScrubStoreKey = descriptor.scrubStoreKey;
        _hasBegunTextureSession = true;
        onPreparingChanged?.call(!rendered);
      } finally {
        if (sessionGeneration == _textureSessionGeneration) {
          _isBeginningTextureSession = false;
        }
      }
      return;
    }
    final rendered = await _transportController.updateScrubPreviewTextureTarget(
      scrubStoreKey: descriptor.scrubStoreKey,
      positionMs: sourcePositionMs,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    onPreparingChanged?.call(!rendered);
  }

  @override
  Future<void> beginSession(LiveScrubSessionConfig config) async {
    _activeConfig = config;
    _retainTextureUntilSettle = false;
    _textureSessionGeneration += 1;
    _activeScrubStoreKey = null;
    _hasBegunTextureSession = false;
    _isBeginningTextureSession = false;
    await _transportController.beginScrubSession();
    if (config.path != LiveScrubPreviewPath.proxyPreview ||
        config.previewSources.isEmpty) {
      await _disposeTextureSession();
      onPreparingChanged?.call(false);
      return;
    }
    await _transportController.ensureScrubPreviewTexture(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    await _presentPositionMs(config.anchorPositionMs);
  }

  @override
  Future<void> endSession({required int finalPositionMs}) async {
    final shouldRetainTexture =
        _activeConfig?.path == LiveScrubPreviewPath.proxyPreview &&
        _transportController.isScrubPreviewTextureVisible;
    _activeConfig = null;
    _textureSessionGeneration += 1;
    _activeScrubStoreKey = null;
    _hasBegunTextureSession = false;
    _isBeginningTextureSession = false;
    onPreparingChanged?.call(false);
    if (shouldRetainTexture) {
      _retainTextureUntilSettle = true;
      return;
    }
    _retainTextureUntilSettle = false;
    await _disposeTextureSession();
  }

  @override
  Future<void> presentFrame(LiveScrubFrameRequest request) async {
    final config = _activeConfig;
    if (config == null || config.path != LiveScrubPreviewPath.proxyPreview) {
      return;
    }
    await _presentPositionMs(request.positionMs);
  }
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
  LiveScrubSessionConfig? _activeSessionConfig;
  Future<void>? _beginSessionInFlight;

  bool get isSessionActive => _isSessionActive;

  Future<void> beginSession(LiveScrubSessionConfig config) async {
    _lastRequestedPositionMs = config.anchorPositionMs;
    _activeSessionConfig = config;
    if (_beginSessionInFlight != null) {
      await _beginSessionInFlight;
      return;
    }
    _isSessionActive = true;
    final beginFuture = () async {
      try {
        await _playbackController.pause();
        await _scrubPreviewController.beginSession(config);
      } catch (_) {
        _isSessionActive = false;
        rethrow;
      } finally {
        _beginSessionInFlight = null;
      }
    }();
    _beginSessionInFlight = beginFuture;
    await beginFuture;
  }

  Future<void> presentFrame(LiveScrubFrameRequest request) async {
    _lastRequestedPositionMs = request.positionMs;
    if (!_isSessionActive) {
      await beginSession(
        _activeSessionConfig ??
            LiveScrubSessionConfig(anchorPositionMs: request.positionMs),
      );
    } else if (_beginSessionInFlight != null) {
      await _beginSessionInFlight;
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
    await _playbackController.settleAfterScrub(resolvedFinalPositionMs);
    _isSessionActive = false;
    _activeSessionConfig = null;
    _beginSessionInFlight = null;
  }
}
