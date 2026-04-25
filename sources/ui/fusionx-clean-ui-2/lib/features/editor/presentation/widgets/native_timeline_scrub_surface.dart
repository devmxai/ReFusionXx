import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../core/engine/live_scrub_preview_sources.dart';
import '../../../../core/engine/stage5_native_transport_controller.dart';
import '../models/timeline_time.dart';
import 'timeline_panel.dart' show TimelineScrubViewportRegion;

@visibleForTesting
PlatformViewHitTestBehavior resolveNativeTimelineScrubHitTestBehavior(
  bool hasInteractiveRegions,
) {
  if (!hasInteractiveRegions) {
    return PlatformViewHitTestBehavior.transparent;
  }
  // A Flutter hit-test gate filters the view to configured scrub regions before
  // AndroidView participates, so opaque is safe and keeps scrub ownership firm.
  return PlatformViewHitTestBehavior.opaque;
}

@visibleForTesting
bool timelineScrubRegionsContainPoint(
  List<TimelineScrubViewportRegion> regions,
  Offset position,
) {
  return regions.any(
    (region) =>
        position.dx >= region.left &&
        position.dx <= region.left + region.width &&
        position.dy >= region.top &&
        position.dy <= region.top + region.height,
  );
}

class NativeTimelineScrubSurface extends StatefulWidget {
  const NativeTimelineScrubSurface({
    super.key,
    required this.currentTime,
    required this.currentTimeListenable,
    required this.timelineDurationTime,
    this.timelineOffsetTime = TimelineTime.zero,
    required this.secondsWidth,
    required this.timelineFps,
    required this.previewSources,
    required this.onScrubStart,
    required this.onScrubTimeChanged,
    required this.onScrubEnd,
    this.configRevision = 0,
    this.onConfigApplied,
    this.regions = const <TimelineScrubViewportRegion>[],
    this.onTap,
    this.targetWidth = 0,
    this.targetHeight = 0,
    this.interactionEnabled = true,
  });

  final TimelineTime currentTime;
  final ValueListenable<TimelineTime> currentTimeListenable;
  final TimelineTime timelineDurationTime;
  final TimelineTime timelineOffsetTime;
  final double secondsWidth;
  final double timelineFps;
  final List<LiveScrubPreviewSourceDescriptor> previewSources;
  final ValueChanged<TimelineTime> onScrubStart;
  final ValueChanged<TimelineTime> onScrubTimeChanged;
  final ValueChanged<TimelineTime> onScrubEnd;
  final int configRevision;
  final ValueChanged<int>? onConfigApplied;
  final List<TimelineScrubViewportRegion> regions;
  final VoidCallback? onTap;
  final int targetWidth;
  final int targetHeight;
  final bool interactionEnabled;

  bool get supportsNativeScrub => !kIsWeb && Platform.isAndroid;

  @override
  State<NativeTimelineScrubSurface> createState() =>
      _NativeTimelineScrubSurfaceState();
}

class _NativeTimelineScrubSurfaceState
    extends State<NativeTimelineScrubSurface> {
  MethodChannel? _channel;
  int? _viewId;
  bool _isScrubSessionActive = false;
  TimelineTime? _lastNativeTimelineTime;
  VoidCallback? _currentTimeListener;
  bool _configPushScheduled = false;
  int? _lastPushedTargetWidth;
  int? _lastPushedTargetHeight;
  int? _lastPushedConfigRevision;
  int? _lastAppliedConfigRevision;
  TimelineTime? _lastPushedCurrentTime;
  TimelineTime? _lastPushedTimelineDurationTime;
  TimelineTime? _lastPushedTimelineOffsetTime;
  double? _lastPushedSecondsWidth;
  double? _lastPushedTimelineFps;
  bool? _lastPushedTapEnabled;
  List<TimelineScrubViewportRegion>? _lastPushedRegions;
  List<LiveScrubPreviewSourceDescriptor>? _lastPushedPreviewSources;

  @override
  void initState() {
    super.initState();
    _lastNativeTimelineTime = widget.currentTime;
    _attachCurrentTimeListener(widget.currentTimeListenable);
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      channel.setMethodCallHandler(null);
    }
    _detachCurrentTimeListener(widget.currentTimeListenable);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NativeTimelineScrubSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTimeListenable != widget.currentTimeListenable) {
      _detachCurrentTimeListener(oldWidget.currentTimeListenable);
      _attachCurrentTimeListener(widget.currentTimeListenable);
    }
    if (!_isScrubSessionActive && oldWidget.currentTime != widget.currentTime) {
      _lastNativeTimelineTime = widget.currentTime;
    }
    if (_viewId != null &&
        !_isScrubSessionActive &&
        oldWidget.configRevision != widget.configRevision) {
      unawaited(_pushConfig());
      return;
    }
    if (_viewId != null &&
        !_isScrubSessionActive &&
        _shouldPushConfigForWidgetUpdate(oldWidget)) {
      _scheduleConfigPush();
    }
  }

  void _attachCurrentTimeListener(ValueListenable<TimelineTime> listenable) {
    _currentTimeListener = () {
      _lastNativeTimelineTime = listenable.value.clamp(
        TimelineTime.zero,
        widget.timelineDurationTime,
      );
      if (_viewId != null &&
          !_isScrubSessionActive &&
          widget.interactionEnabled) {
        _scheduleConfigPush();
      }
    };
    listenable.addListener(_currentTimeListener!);
  }

  void _detachCurrentTimeListener(ValueListenable<TimelineTime> listenable) {
    final listener = _currentTimeListener;
    if (listener == null) {
      return;
    }
    listenable.removeListener(listener);
    _currentTimeListener = null;
  }

  bool _shouldPushConfigForWidgetUpdate(
    NativeTimelineScrubSurface oldWidget,
  ) {
    return oldWidget.timelineDurationTime != widget.timelineDurationTime ||
        oldWidget.timelineOffsetTime != widget.timelineOffsetTime ||
        oldWidget.secondsWidth != widget.secondsWidth ||
        oldWidget.timelineFps != widget.timelineFps ||
        oldWidget.targetWidth != widget.targetWidth ||
        oldWidget.targetHeight != widget.targetHeight ||
        oldWidget.onTap != widget.onTap ||
        !listEquals(oldWidget.regions, widget.regions) ||
        !listEquals(oldWidget.previewSources, widget.previewSources);
  }

  void _scheduleConfigPush() {
    if (_configPushScheduled) {
      return;
    }
    _configPushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configPushScheduled = false;
      if (!mounted || _viewId == null || _isScrubSessionActive) {
        return;
      }
      unawaited(_pushConfig());
    });
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (!mounted) {
      return;
    }
    final arguments = (call.arguments as Map?)?.cast<Object?, Object?>();
    final positionMs = switch (arguments?['positionMs']) {
      int value => value,
      double value => value.round(),
      _ => widget.currentTime.inMilliseconds +
          widget.timelineOffsetTime.inMilliseconds,
    };
    final localPositionMs =
        positionMs - widget.timelineOffsetTime.inMilliseconds;
    final timelineTime = TimelineTime.fromMilliseconds(localPositionMs).clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    if (call.method == 'scrubStart') {
      _lastNativeTimelineTime = timelineTime;
      _isScrubSessionActive = true;
      widget.onScrubStart(timelineTime);
      return;
    }
    if (call.method == 'scrubTimeChanged') {
      _lastNativeTimelineTime = timelineTime;
      widget.onScrubTimeChanged(timelineTime);
      return;
    }
    if (call.method == 'scrubEnd') {
      _lastNativeTimelineTime = timelineTime;
      widget.onScrubEnd(timelineTime);
      _isScrubSessionActive = false;
      await _pushConfig();
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
    final effectiveCurrentTime = _effectiveCurrentTime();
    final resolvedTargetWidth = _resolvedTargetWidth(context);
    final resolvedTargetHeight =
        _resolvedTargetHeight(context, resolvedTargetWidth);
    final tapEnabled = widget.interactionEnabled && widget.onTap != null;
    if (_lastPushedTargetWidth == resolvedTargetWidth &&
        _lastPushedTargetHeight == resolvedTargetHeight &&
        _lastPushedConfigRevision == widget.configRevision &&
        _lastPushedCurrentTime == effectiveCurrentTime &&
        _lastPushedTimelineDurationTime == widget.timelineDurationTime &&
        _lastPushedTimelineOffsetTime == widget.timelineOffsetTime &&
        _lastPushedSecondsWidth == widget.secondsWidth &&
        _lastPushedTimelineFps == widget.timelineFps &&
        _lastPushedTapEnabled == tapEnabled &&
        listEquals(_lastPushedRegions, widget.regions) &&
        listEquals(_lastPushedPreviewSources, widget.previewSources)) {
      return;
    }
    await channel.invokeMethod<void>(
      'updateConfig',
      <String, Object?>{
        'currentPositionMs': effectiveCurrentTime.inMilliseconds +
            widget.timelineOffsetTime.inMilliseconds,
        'timelineDurationMs': widget.timelineDurationTime.inMilliseconds,
        'timelineOffsetMs': widget.timelineOffsetTime.inMilliseconds,
        'secondsWidth': widget.secondsWidth,
        'timelineFps': widget.timelineFps,
        'configRevision': widget.configRevision,
        'targetWidth': resolvedTargetWidth,
        'targetHeight': resolvedTargetHeight,
        'tapEnabled': tapEnabled,
        'regions': widget.regions
            .map((region) => region.toMap())
            .toList(growable: false),
        'previewSources': widget.previewSources
            .map((descriptor) => descriptor.toMap())
            .toList(growable: false),
      },
    );
    _lastPushedTargetWidth = resolvedTargetWidth;
    _lastPushedTargetHeight = resolvedTargetHeight;
    _lastPushedConfigRevision = widget.configRevision;
    _lastPushedCurrentTime = effectiveCurrentTime;
    _lastPushedTimelineDurationTime = widget.timelineDurationTime;
    _lastPushedTimelineOffsetTime = widget.timelineOffsetTime;
    _lastPushedSecondsWidth = widget.secondsWidth;
    _lastPushedTimelineFps = widget.timelineFps;
    _lastPushedTapEnabled = tapEnabled;
    _lastPushedRegions = List<TimelineScrubViewportRegion>.unmodifiable(
      widget.regions,
    );
    _lastPushedPreviewSources =
        List<LiveScrubPreviewSourceDescriptor>.unmodifiable(
      widget.previewSources,
    );
    if (_lastAppliedConfigRevision != widget.configRevision) {
      _lastAppliedConfigRevision = widget.configRevision;
      widget.onConfigApplied?.call(widget.configRevision);
    }
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
    final effectiveCurrentTime = _effectiveCurrentTime();
    final resolvedTargetWidth = _resolvedTargetWidth(context);
    final resolvedTargetHeight =
        _resolvedTargetHeight(context, resolvedTargetWidth);
    final hasInteractiveRegions = widget.regions.isNotEmpty;
    return _TimelineScrubRegionHitTestGate(
      enabled: hasInteractiveRegions && widget.interactionEnabled,
      regions: widget.regions,
      child: AndroidView(
        viewType: Stage5NativeTransportController.timelineScrubViewType,
        creationParams: <String, Object?>{
          'currentPositionMs': effectiveCurrentTime.inMilliseconds +
              widget.timelineOffsetTime.inMilliseconds,
          'timelineDurationMs': widget.timelineDurationTime.inMilliseconds,
          'timelineOffsetMs': widget.timelineOffsetTime.inMilliseconds,
          'secondsWidth': widget.secondsWidth,
          'timelineFps': widget.timelineFps,
          'targetWidth': resolvedTargetWidth,
          'targetHeight': resolvedTargetHeight,
          'tapEnabled': widget.interactionEnabled && widget.onTap != null,
          'regions': widget.regions
              .map((region) => region.toMap())
              .toList(growable: false),
          'previewSources': widget.previewSources
              .map((descriptor) => descriptor.toMap())
              .toList(growable: false),
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _handlePlatformViewCreated,
        hitTestBehavior:
            resolveNativeTimelineScrubHitTestBehavior(hasInteractiveRegions),
      ),
    );
  }

  TimelineTime _effectiveCurrentTime() {
    final canonicalCurrentTime = widget.currentTime.clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    if (!_isScrubSessionActive) {
      return canonicalCurrentTime;
    }
    return (_lastNativeTimelineTime ?? canonicalCurrentTime).clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
  }

  int _resolvedTargetWidth(BuildContext context) {
    if (widget.targetWidth > 0) {
      return widget.targetWidth;
    }
    final mediaQuery = MediaQuery.maybeOf(context);
    final logicalWidth = mediaQuery?.size.width ?? 360;
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 2.0;
    return (logicalWidth * devicePixelRatio).round().clamp(540, 720);
  }

  int _resolvedTargetHeight(
    BuildContext context,
    int targetWidth,
  ) {
    if (widget.targetHeight > 0) {
      return widget.targetHeight;
    }
    final mediaQuery = MediaQuery.maybeOf(context);
    final aspectRatio = mediaQuery == null || mediaQuery.size.width <= 0
        ? (16 / 9)
        : (mediaQuery.size.height / mediaQuery.size.width);
    return (targetWidth * aspectRatio).round().clamp(960, 1280);
  }
}

class _TimelineScrubRegionHitTestGate extends SingleChildRenderObjectWidget {
  const _TimelineScrubRegionHitTestGate({
    required this.enabled,
    required this.regions,
    required super.child,
  });

  final bool enabled;
  final List<TimelineScrubViewportRegion> regions;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTimelineScrubRegionHitTestGate(
      enabled: enabled,
      regions: regions,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTimelineScrubRegionHitTestGate renderObject,
  ) {
    renderObject
      ..enabled = enabled
      ..regions = regions;
  }
}

class _RenderTimelineScrubRegionHitTestGate extends RenderProxyBox {
  _RenderTimelineScrubRegionHitTestGate({
    required bool enabled,
    required List<TimelineScrubViewportRegion> regions,
  })  : _enabled = enabled,
        _regions = regions;

  bool _enabled;
  List<TimelineScrubViewportRegion> _regions;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    markNeedsPaint();
  }

  List<TimelineScrubViewportRegion> get regions => _regions;
  set regions(List<TimelineScrubViewportRegion> value) {
    if (listEquals(_regions, value)) {
      return;
    }
    _regions = value;
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_enabled || !timelineScrubRegionsContainPoint(_regions, position)) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}
