import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../domain/services/professional_video_transition_compositor.dart';
import '../models/timeline_time.dart';

@visibleForTesting
bool shouldRetryInteractiveRenderResult(
  ProfessionalVideoTransitionInteractiveFrameRenderResult result, {
  required int retryCount,
  required int maxRetryCount,
}) {
  if (result.canRenderFrame || retryCount >= maxRetryCount) {
    return false;
  }
  final reasons = result.blockedReasons;
  if (reasons.any(
    (reason) =>
        reason == 'native_transition_interactive_surface_not_registered' ||
        reason.endsWith('_production_surface_missing'),
  )) {
    return true;
  }
  if (!result.pixelOutputReady || !result.surfaceAttached) {
    return false;
  }
  if (reasons.any(
    (reason) =>
        reason == 'native_transition_surface_upload_failed' ||
        reason.endsWith('_interactive_surface_frame_missing'),
  )) {
    return true;
  }
  return result.frameDelivered &&
      reasons.any(
        (reason) => reason.endsWith(
          '_interactive_surface_presentation_missing',
        ),
      );
}

@visibleForTesting
String interactiveRenderDiagnosticKey(
  ProfessionalVideoTransitionInteractiveFrameRenderResult result,
) {
  return [
    result.definitionId,
    result.mode,
    result.surfaceId,
    result.pixelOutputReady,
    result.frameDelivered,
    result.framePresented,
    result.surfaceAttached,
    result.blockedReasons.join(','),
    result.reason,
  ].join('|');
}

class ProfessionalVideoTransitionSurfaceOverlay extends StatefulWidget {
  const ProfessionalVideoTransitionSurfaceOverlay({
    super.key,
    required this.plan,
    required this.timelineTime,
    required this.mode,
    required this.surfaceId,
    this.onPresentationChanged,
    this.client =
        const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(),
  });

  static const String viewType =
      'com.refusion.app/professional_video_transition_surface';

  final ProfessionalVideoTransitionRenderPlan plan;
  final TimelineTime timelineTime;
  final String mode;
  final String surfaceId;
  final ValueChanged<bool>? onPresentationChanged;
  final ProfessionalVideoTransitionCompositorClient client;

  bool get _supportsAndroidSurface => !kIsWeb && Platform.isAndroid;

  @override
  State<ProfessionalVideoTransitionSurfaceOverlay> createState() =>
      _ProfessionalVideoTransitionSurfaceOverlayState();
}

class _ProfessionalVideoTransitionSurfaceOverlayState
    extends State<ProfessionalVideoTransitionSurfaceOverlay> {
  static const int _maxRenderRetryCount = 4;

  bool _platformViewReady = false;
  bool _renderInFlight = false;
  bool _pendingRenderAfterCurrent = false;
  int _renderSequence = 0;
  int _registrationRetryCount = 0;
  String? _lastRenderedKey;
  String? _lastReportedRenderIssueKey;
  Timer? _renderTimer;
  bool _hasPresentedFrame = false;

  @override
  void didUpdateWidget(
    covariant ProfessionalVideoTransitionSurfaceOverlay oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surfaceId != widget.surfaceId ||
        oldWidget.mode != widget.mode) {
      _platformViewReady = false;
      _registrationRetryCount = 0;
      _lastRenderedKey = null;
      _lastReportedRenderIssueKey = null;
      widget.onPresentationChanged?.call(false);
      _hasPresentedFrame = false;
      _renderTimer?.cancel();
      return;
    }
    _scheduleRender();
  }

  @override
  void dispose() {
    widget.onPresentationChanged?.call(false);
    _renderTimer?.cancel();
    super.dispose();
  }

  void _handlePlatformViewCreated(int viewId) {
    _platformViewReady = true;
    _registrationRetryCount = 0;
    _scheduleRender(const Duration(milliseconds: 48));
    _scheduleRender(const Duration(milliseconds: 160));
  }

  void _scheduleRender([Duration delay = Duration.zero]) {
    if (!widget._supportsAndroidSurface || !_platformViewReady) {
      return;
    }
    _renderTimer?.cancel();
    _renderTimer = Timer(delay, _renderCurrentFrame);
  }

  Future<void> _renderCurrentFrame() async {
    if (!mounted || !_platformViewReady) {
      return;
    }
    if (_renderInFlight) {
      _pendingRenderAfterCurrent = true;
      return;
    }
    final renderKey = _currentRenderKey;
    if (_lastRenderedKey == renderKey) {
      return;
    }
    _renderInFlight = true;
    final sequence = ++_renderSequence;
    final result = await widget.client.renderInteractiveFrame(
      plan: widget.plan,
      timelineTime: widget.timelineTime,
      mode: widget.mode,
      surfaceId: widget.surfaceId,
    );
    if (!mounted || sequence != _renderSequence) {
      _renderInFlight = false;
      return;
    }
    _renderInFlight = false;
    if (_pendingRenderAfterCurrent) {
      _pendingRenderAfterCurrent = false;
      _scheduleRender();
    }
    if (result.canRenderFrame) {
      _lastRenderedKey = renderKey;
      _registrationRetryCount = 0;
      if (!_hasPresentedFrame) {
        setState(() {
          _hasPresentedFrame = true;
        });
        widget.onPresentationChanged?.call(true);
      }
      return;
    }
    _debugRenderIssue(result);
    if (shouldRetryInteractiveRenderResult(
      result,
      retryCount: _registrationRetryCount,
      maxRetryCount: _maxRenderRetryCount,
    )) {
      _registrationRetryCount += 1;
      _scheduleRender(_retryDelayForAttempt(_registrationRetryCount));
    }
  }

  void _debugRenderIssue(
    ProfessionalVideoTransitionInteractiveFrameRenderResult result,
  ) {
    final issueKey = interactiveRenderDiagnosticKey(result);
    if (_lastReportedRenderIssueKey == issueKey) {
      return;
    }
    _lastReportedRenderIssueKey = issueKey;
    debugPrint(
      'Professional transition interactive render blocked: '
      'definition=${result.definitionId}, mode=${result.mode}, '
      'surface=${result.surfaceId}, time=${result.timelineTime?.inMilliseconds}, '
      'pixelOutputReady=${result.pixelOutputReady}, '
      'frameDelivered=${result.frameDelivered}, '
      'framePresented=${result.framePresented}, '
      'surfaceAttached=${result.surfaceAttached}, '
      'blockedReasons=${result.blockedReasons}, reason=${result.reason}',
    );
  }

  Duration _retryDelayForAttempt(int attempt) {
    final delayMs = 72 + (attempt.clamp(0, 8) * 36);
    return Duration(milliseconds: delayMs);
  }

  String get _currentRenderKey {
    return [
      widget.plan.transitionId,
      _timelineFrameKey,
      widget.mode,
      widget.surfaceId,
      widget.plan.parameters,
    ].join(':');
  }

  int get _timelineFrameKey {
    final frameRate = _doubleFromPolicy(
      widget.plan.motionBlurPolicy['frameRate'],
      fallback: 30.0,
    ).clamp(1.0, 120.0);
    final frameDurationMs = 1000.0 / frameRate;
    return (widget.timelineTime.inMilliseconds / frameDurationMs).round();
  }

  double _doubleFromPolicy(Object? value, {required double fallback}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._supportsAndroidSurface) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Opacity(
        opacity: _hasPresentedFrame ? 1.0 : 0.0,
        child: AndroidView(
          key: ValueKey<String>(widget.surfaceId),
          viewType: ProfessionalVideoTransitionSurfaceOverlay.viewType,
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          creationParams: <String, Object?>{
            'surfaceId': widget.surfaceId,
            'mode': widget.mode,
            'canvasWidth': widget.plan.canvasWidth,
            'canvasHeight': widget.plan.canvasHeight,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _handlePlatformViewCreated,
        ),
      ),
    );
  }
}
