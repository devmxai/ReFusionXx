import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../domain/services/professional_video_transition_compositor.dart';
import '../models/timeline_time.dart';

class ProfessionalVideoTransitionSurfaceOverlay extends StatefulWidget {
  const ProfessionalVideoTransitionSurfaceOverlay({
    super.key,
    required this.plan,
    required this.timelineTime,
    required this.mode,
    required this.surfaceId,
    this.client =
        const MethodChannelProfessionalVideoTransitionCompositorCapabilityProvider(),
  });

  static const String viewType =
      'com.refusion.app/professional_video_transition_surface';

  final ProfessionalVideoTransitionRenderPlan plan;
  final TimelineTime timelineTime;
  final String mode;
  final String surfaceId;
  final ProfessionalVideoTransitionCompositorClient client;

  bool get _supportsAndroidSurface => !kIsWeb && Platform.isAndroid;

  @override
  State<ProfessionalVideoTransitionSurfaceOverlay> createState() =>
      _ProfessionalVideoTransitionSurfaceOverlayState();
}

class _ProfessionalVideoTransitionSurfaceOverlayState
    extends State<ProfessionalVideoTransitionSurfaceOverlay> {
  bool _platformViewReady = false;
  bool _renderInFlight = false;
  bool _pendingRenderAfterCurrent = false;
  int _renderSequence = 0;
  int _registrationRetryCount = 0;
  String? _lastRenderedKey;
  Timer? _renderTimer;

  @override
  void didUpdateWidget(
    covariant ProfessionalVideoTransitionSurfaceOverlay oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surfaceId != widget.surfaceId) {
      _platformViewReady = false;
      _registrationRetryCount = 0;
      _lastRenderedKey = null;
      _renderTimer?.cancel();
      return;
    }
    _scheduleRender();
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    super.dispose();
  }

  void _handlePlatformViewCreated(int viewId) {
    _platformViewReady = true;
    _registrationRetryCount = 0;
    _scheduleRender(const Duration(milliseconds: 48));
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
      return;
    }
    final surfaceNotRegistered = result.blockedReasons.any(
      (reason) =>
          reason == 'native_transition_interactive_surface_not_registered' ||
          reason.endsWith('_production_surface_missing'),
    );
    if (surfaceNotRegistered && _registrationRetryCount < 4) {
      _registrationRetryCount += 1;
      _scheduleRender(const Duration(milliseconds: 72));
    }
  }

  String get _currentRenderKey {
    return [
      widget.plan.transitionId,
      widget.timelineTime.inMilliseconds,
      widget.mode,
      widget.surfaceId,
    ].join(':');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._supportsAndroidSurface) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
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
    );
  }
}
