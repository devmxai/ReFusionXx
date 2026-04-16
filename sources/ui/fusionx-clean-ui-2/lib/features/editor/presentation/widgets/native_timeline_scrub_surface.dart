import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:flutter/src/rendering/platform_view.dart'
    show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';

import '../../../../core/engine/live_scrub_preview_sources.dart';
import '../../../../core/engine/stage5_native_transport_controller.dart';
import '../models/timeline_time.dart';
import 'timeline_panel.dart' show TimelineScrubViewportRegion;

class NativeTimelineScrubSurface extends StatefulWidget {
  const NativeTimelineScrubSurface({
    super.key,
    required this.currentTime,
    required this.timelineDurationTime,
    this.timelineOffsetTime = TimelineTime.zero,
    required this.secondsWidth,
    required this.previewSources,
    required this.onScrubStart,
    required this.onScrubTimeChanged,
    required this.onScrubEnd,
    this.regions = const <TimelineScrubViewportRegion>[],
    this.onTap,
    this.targetWidth = 480,
    this.targetHeight = 854,
  });

  final TimelineTime currentTime;
  final TimelineTime timelineDurationTime;
  final TimelineTime timelineOffsetTime;
  final double secondsWidth;
  final List<LiveScrubPreviewSourceDescriptor> previewSources;
  final VoidCallback onScrubStart;
  final ValueChanged<TimelineTime> onScrubTimeChanged;
  final ValueChanged<TimelineTime> onScrubEnd;
  final List<TimelineScrubViewportRegion> regions;
  final VoidCallback? onTap;
  final int targetWidth;
  final int targetHeight;

  bool get supportsNativeScrub => !kIsWeb && Platform.isAndroid;

  @override
  State<NativeTimelineScrubSurface> createState() =>
      _NativeTimelineScrubSurfaceState();
}

class _NativeTimelineScrubSurfaceState extends State<NativeTimelineScrubSurface> {
  MethodChannel? _channel;
  int? _viewId;
  bool _isScrubSessionActive = false;

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NativeTimelineScrubSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_viewId != null && !_isScrubSessionActive) {
      unawaited(_pushConfig());
    }
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (!mounted) {
      return;
    }
    final arguments = (call.arguments as Map?)?.cast<Object?, Object?>();
    final positionMs = switch (arguments?['positionMs']) {
      int value => value,
      double value => value.round(),
      _ => widget.currentTime.inMilliseconds + widget.timelineOffsetTime.inMilliseconds,
    };
    final localPositionMs =
        positionMs - widget.timelineOffsetTime.inMilliseconds;
    final timelineTime = TimelineTime.fromMilliseconds(localPositionMs).clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    if (call.method == 'scrubStart') {
      _isScrubSessionActive = true;
      widget.onScrubStart();
      return;
    }
    if (call.method == 'scrubTimeChanged') {
      widget.onScrubTimeChanged(timelineTime);
      return;
    }
    if (call.method == 'scrubEnd') {
      widget.onScrubEnd(timelineTime);
      _isScrubSessionActive = false;
      unawaited(_pushConfig());
      return;
    }
    if (call.method == 'tap') {
      widget.onTap?.call();
    }
  }

  Future<void> _pushConfig() async {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    await channel.invokeMethod<void>(
      'updateConfig',
      <String, Object?>{
        'currentPositionMs':
            widget.currentTime.inMilliseconds +
            widget.timelineOffsetTime.inMilliseconds,
        'timelineDurationMs': widget.timelineDurationTime.inMilliseconds,
        'timelineOffsetMs': widget.timelineOffsetTime.inMilliseconds,
        'secondsWidth': widget.secondsWidth,
        'targetWidth': widget.targetWidth,
        'targetHeight': widget.targetHeight,
        'tapEnabled': widget.onTap != null,
        'regions': widget.regions
            .map((region) => region.toMap())
            .toList(growable: false),
        'previewSources': widget.previewSources
            .map((descriptor) => descriptor.toMap())
            .toList(growable: false),
      },
    );
  }

  void _handlePlatformViewCreated(int viewId) {
    _viewId = viewId;
    final channel = MethodChannel(
      '${Stage5NativeTransportController.timelineScrubViewType}/$viewId',
    );
    _channel = channel;
    channel.setMethodCallHandler(_handleNativeCallback);
    unawaited(_pushConfig());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.supportsNativeScrub) {
      return const SizedBox.expand();
    }
    return AndroidView(
      viewType: Stage5NativeTransportController.timelineScrubViewType,
      creationParams: <String, Object?>{
        'currentPositionMs':
            widget.currentTime.inMilliseconds +
            widget.timelineOffsetTime.inMilliseconds,
        'timelineDurationMs': widget.timelineDurationTime.inMilliseconds,
        'timelineOffsetMs': widget.timelineOffsetTime.inMilliseconds,
        'secondsWidth': widget.secondsWidth,
        'targetWidth': widget.targetWidth,
        'targetHeight': widget.targetHeight,
        'tapEnabled': widget.onTap != null,
        'regions': widget.regions
            .map((region) => region.toMap())
            .toList(growable: false),
        'previewSources': widget.previewSources
            .map((descriptor) => descriptor.toMap())
            .toList(growable: false),
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _handlePlatformViewCreated,
      hitTestBehavior: PlatformViewHitTestBehavior.translucent,
    );
  }
}
