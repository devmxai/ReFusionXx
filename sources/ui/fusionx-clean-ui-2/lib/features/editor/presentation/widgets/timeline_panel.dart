import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../core/media/native_media_thumbnailer.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

typedef TimelineAssetPathResolver = String? Function(String assetId);
typedef TimelineClipReorderCallback = void Function(
  String clipId,
  int insertionIndex,
);
typedef TimelineClipTimeShiftCallback = void Function(
  String clipId,
  TimelineTime startTime,
);
typedef TimelineBoundaryTransitionTapCallback = void Function(
  TimelineTrackData track,
  TimelineClipData leftClip,
  TimelineClipData rightClip,
);
typedef TimelineScrubSurfaceBuilder = Widget Function(
    TimelineScrubSurfaceConfig config);

@immutable
class TimelineScrubViewportRegion {
  const TimelineScrubViewportRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  bool get isEmpty => width <= 0 || height <= 0;

  Map<String, Object> toMap() {
    return <String, Object>{
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }
}

@immutable
class TimelineScrubSurfaceConfig {
  const TimelineScrubSurfaceConfig({
    required this.currentTime,
    required this.currentTimeListenable,
    required this.timelineDurationTime,
    required this.timelineOffsetTime,
    required this.secondsWidth,
    required this.onScrubStart,
    required this.onScrubTimeChanged,
    required this.onScrubEnd,
    this.regions = const <TimelineScrubViewportRegion>[],
    this.onTap,
  });

  final TimelineTime currentTime;
  final ValueListenable<TimelineTime> currentTimeListenable;
  final TimelineTime timelineDurationTime;
  final TimelineTime timelineOffsetTime;
  final double secondsWidth;
  final VoidCallback onScrubStart;
  final ValueChanged<TimelineTime> onScrubTimeChanged;
  final ValueChanged<TimelineTime> onScrubEnd;
  final List<TimelineScrubViewportRegion> regions;
  final VoidCallback? onTap;
}

class _TimelineZoomCanonicalProfile {
  const _TimelineZoomCanonicalProfile._();

  static const double minSecondsWidth = 0.75;
  static const double maxSecondsWidth = 840.0;
  static const double scaleGestureDampingFactor = 0.84;
  static const double scaleGestureActivationDistance = 4.0;
  static const double scaleGestureWidthEpsilon = 0.04;
}

class _TimelineSecondModeSpec {
  const _TimelineSecondModeSpec({
    required this.minLabelSpacingPx,
    required this.minStepSeconds,
    this.preserveBoundaryLabels = false,
  });

  final double minLabelSpacingPx;
  final double minStepSeconds;
  final bool preserveBoundaryLabels;
}

class _TimelineRulerCanonicalProfile {
  const _TimelineRulerCanonicalProfile._();

  static const double coarseToNormalVisibleWindowEnter = 14.0;
  static const double normalToCoarseVisibleWindowExit = 16.5;
  static const double normalToSecondsAndFramesVisibleWindowEnter = 8.0;
  static const double normalToSecondsAndFramesPixelsPerFrameEnter = 6.0;
  static const double secondsAndFramesToNormalVisibleWindowExit = 9.5;
  static const double secondsAndFramesToNormalPixelsPerFrameExit = 5.0;
  static const double secondsAndFramesToFineFramesVisibleWindowEnter = 3.5;
  static const double secondsAndFramesToFineFramesPixelsPerFrameEnter = 12.0;
  static const double fineFramesToSecondsAndFramesVisibleWindowExit = 4.25;
  static const double fineFramesToSecondsAndFramesPixelsPerFrameExit = 10.0;
  static const double durationBoundaryEpsilonSeconds = 0.0005;
  static const double secondsAndFramesCanonicalSecondStep = 1.0;
  static const double secondsAndFramesFrameMarkerFraction = 0.5;
  static const double secondsAndFramesLabelMinGap = 12.0;
  static const double secondModeVisibleLabelMarginPx = 48.0;
  static const int secondModeWholeLabelPriority = 2;
  static const double secondModeLabelMinGap = 14.0;
  static const double secondModeDotOpacity = 0.42;
  static const double secondModeDotRadius = 2.25;
  static const double secondsAndFramesFrameMarkerEdgeInsetPx = 8.0;
  static const int secondsAndFramesFrameLabelPriority = 1;
  static const double wholeSecondLabelVisibleMarginPx = 48.0;
  static const int wholeSecondLabelPriority = 3;
  static const double fineFramesWholeSecondAnchorMinSpacingPx = 84.0;
  static const double fineFramesWholeSecondAnchorMinStepSeconds = 1.0;
  static const double fineFramesMinLabelSpacingPx = 36.0;
  static const double fineFramesLabelMinGap = 8.0;
  static const double fineFramesDurationToleranceFrames = 0.5;
  static const double fineFramesVisibleLabelMarginPx = 36.0;
  static const int fineFramesFrameLabelPriority = 1;
  static const double fineFramesDotOpacity = 0.24;
  static const double fineFramesDotRadius = 2.0;
  static const double preciseBoundaryWholeSecondEpsilon = 0.0005;
  static const double preciseBoundaryFrameEpsilon = 0.001;
  static const double interLabelDotMinGapPx = 14.0;
  static const double interLabelDotMinOpacity = 0.08;
  static const double labelPlacementSafeInsetPx = 6.0;
  static const double boundaryPlacementInsetPx = 6.0;
  static const int boundaryLabelPriority = 99;
  static const double edgeFadeSafeInsetPx = 8.0;
  static const double edgeFadeDistancePx = 42.0;
  static const double viewportOverscanPx = 40.0;

  static const _TimelineSecondModeSpec coarseSecondsSpec =
      _TimelineSecondModeSpec(
    minLabelSpacingPx: 136.0,
    minStepSeconds: 2.0,
    preserveBoundaryLabels: true,
  );

  static const _TimelineSecondModeSpec normalSecondsSpec =
      _TimelineSecondModeSpec(
    minLabelSpacingPx: 86.0,
    minStepSeconds: 1.0,
    preserveBoundaryLabels: true,
  );

  static const List<double> niceSecondSteps = <double>[
    1,
    2,
    3,
    5,
    10,
    15,
    20,
    30,
    45,
    60,
    90,
    120,
    180,
    300,
    600,
    900,
    1200,
    1800,
    3600,
  ];

  static const List<int> niceFrameSteps = <int>[
    1,
    2,
    3,
    5,
    6,
    10,
    12,
    15,
    20,
    24,
    30,
    45,
    60,
  ];

  static double pickNiceSecondStep({required double minSeconds}) {
    if (minSeconds <= niceSecondSteps.first) {
      return niceSecondSteps.first;
    }
    for (final step in niceSecondSteps) {
      if (step >= minSeconds) {
        return step;
      }
    }

    final exponent = math
        .pow(
          10,
          (math.log(minSeconds) / math.ln10).floor(),
        )
        .toDouble();
    final normalized = minSeconds / exponent;
    final niceBase = normalized <= 1
        ? 1
        : normalized <= 2
            ? 2
            : normalized <= 3
                ? 3
                : normalized <= 5
                    ? 5
                    : 10;
    return niceBase * exponent;
  }
}

class _TimelineTrimCanonicalProfile {
  const _TimelineTrimCanonicalProfile._();

  static const double handleHitWidth = 40.0;
  static const double handleVisualWidth = 20.0;
  static const double handleMinVisualWidth = 8.0;
  static const double handleVisualInset = 0.0;
  static const double handlePressedBorderWidth = 1.2;
  static const double horizontalLockThresholdPx = 4.0;
  static const double horizontalLockDominanceRatio = 1.1;
}

class _TimelineTrackLaneProfile {
  const _TimelineTrackLaneProfile({
    required this.shortLabel,
    required this.accentColor,
    required this.rowHeight,
    required this.controlHitSize,
    required this.headerTopInset,
    required this.clipTopInset,
    required this.clipHeight,
    required this.reorderCardTopInset,
    required this.insertionSlotTopInset,
  });

  final String shortLabel;
  final Color accentColor;
  final double rowHeight;
  final double controlHitSize;
  final double headerTopInset;
  final double clipTopInset;
  final double clipHeight;
  final double reorderCardTopInset;
  final double insertionSlotTopInset;

  static const _TimelineTrackLaneProfile video = _TimelineTrackLaneProfile(
    shortLabel: 'VID',
    accentColor: Color(0xFF729C80),
    rowHeight: 42,
    controlHitSize: 42,
    headerTopInset: 1,
    clipTopInset: 2,
    clipHeight: 38,
    reorderCardTopInset: 1,
    insertionSlotTopInset: 8,
  );

  static const _TimelineTrackLaneProfile image = _TimelineTrackLaneProfile(
    shortLabel: 'IMG',
    accentColor: Color(0xFF7D91B6),
    rowHeight: 42,
    controlHitSize: 42,
    headerTopInset: 1,
    clipTopInset: 2,
    clipHeight: 38,
    reorderCardTopInset: 1,
    insertionSlotTopInset: 8,
  );

  static const _TimelineTrackLaneProfile audio = _TimelineTrackLaneProfile(
    shortLabel: 'AUD',
    accentColor: Color(0xFFA98A5F),
    rowHeight: 42,
    controlHitSize: 42,
    headerTopInset: 1,
    clipTopInset: 2,
    clipHeight: 38,
    reorderCardTopInset: 1,
    insertionSlotTopInset: 8,
  );

  static const _TimelineTrackLaneProfile text = _TimelineTrackLaneProfile(
    shortLabel: 'TXT',
    accentColor: Color(0xFF9A85B6),
    rowHeight: 42,
    controlHitSize: 42,
    headerTopInset: 1,
    clipTopInset: 2,
    clipHeight: 38,
    reorderCardTopInset: 1,
    insertionSlotTopInset: 8,
  );

  static const _TimelineTrackLaneProfile lipSync = _TimelineTrackLaneProfile(
    shortLabel: 'LIP',
    accentColor: Color(0xFF6DA7A1),
    rowHeight: 42,
    controlHitSize: 42,
    headerTopInset: 1,
    clipTopInset: 2,
    clipHeight: 38,
    reorderCardTopInset: 1,
    insertionSlotTopInset: 8,
  );

  static _TimelineTrackLaneProfile forKind(TimelineTrackKind kind) {
    switch (kind) {
      case TimelineTrackKind.video:
        return video;
      case TimelineTrackKind.image:
        return image;
      case TimelineTrackKind.audio:
        return audio;
      case TimelineTrackKind.text:
        return text;
      case TimelineTrackKind.lipSync:
        return lipSync;
    }
  }
}

Color _timelineTrackAccentColor(TimelineTrackKind kind) =>
    _TimelineTrackLaneProfile.forKind(kind).accentColor;

Color _timelineClipAccentColor({
  required TimelineTrackKind trackKind,
  required TimelineClipTone tone,
}) {
  if (tone == TimelineClipTone.placeholder) {
    return FxPalette.clipFill;
  }
  final accent = _timelineTrackAccentColor(trackKind);
  return switch (tone) {
    TimelineClipTone.hero => accent,
    TimelineClipTone.heroMuted => Color.lerp(
          accent,
          FxPalette.surfaceRaised,
          0.18,
        ) ??
        accent,
    TimelineClipTone.placeholder => FxPalette.clipFill,
  };
}

Color _timelineClipSurfaceColor(TimelineTrackKind trackKind) {
  final accent = _timelineTrackAccentColor(trackKind);
  return Color.alphaBlend(
    accent.withOpacity(0.18),
    FxPalette.surfaceRaised,
  );
}

Color _timelineSelectionAccentColor(TimelineTrackKind trackKind) {
  final accent = _timelineTrackAccentColor(trackKind);
  return Color.lerp(accent, Colors.white, 0.34) ?? Colors.white;
}

class _TimelineAnimationLaneMetrics {
  static const double sectionTopSpacing = 8;
  static const double sectionBottomSpacing = 6;
  static const double rowHeight = 30;
  static const double rowGap = 6;
}

class _TimelineAnimationClipGeometry {
  const _TimelineAnimationClipGeometry({
    required this.left,
    required this.width,
  });

  final double left;
  final double width;
}

class _TimelineStackDensityProfile {
  const _TimelineStackDensityProfile({
    required this.rowGap,
  });

  final double rowGap;

  static const _TimelineStackDensityProfile relaxed =
      _TimelineStackDensityProfile(rowGap: 6);
  static const _TimelineStackDensityProfile compact =
      _TimelineStackDensityProfile(rowGap: 4);

  static _TimelineStackDensityProfile forTrackCount(int trackCount) {
    if (trackCount >= 4) {
      return compact;
    }
    return relaxed;
  }
}

enum _TimelineInteractionOwner {
  idle,
  tap,
  pan,
  trim,
  zoom,
  move,
  reorder,
}

enum _TimelineInteractionPhase {
  idle,
  pending,
  active,
}

class TimelinePanel extends StatefulWidget {
  const TimelinePanel({
    super.key,
    this.embedded = false,
    required this.tracks,
    required this.currentTime,
    this.displayTimeListenable,
    this.onDisplayTimeChanged,
    this.playbackSampleTimeListenable,
    required this.timelineDurationTime,
    required this.isPlaying,
    required this.selectedClipId,
    required this.onClipSelected,
    this.onClipDoubleTap,
    this.onClipReorder,
    this.onClipTimeShift,
    this.onTransitionTap,
    this.onTrackAnimateTap,
    this.onBackgroundTap,
    this.assetPathResolver,
    this.onScrubStateChanged,
    this.onScrubFinalized,
    this.timelineFps = 30,
    this.trimSelection,
    this.onTrimCommit,
    this.onTrimPreviewChanged,
    this.selectedTransitionId,
    this.selectedAnimationLaneId,
    this.onAnimationLaneTap,
    this.timeDisplayOffset = TimelineTime.zero,
    this.timeReadoutTotalTime,
    this.initialSecondsWidth = 32,
    this.animateTrackKinds = const <TimelineTrackKind>{
      TimelineTrackKind.text,
    },
    this.scrubSurfaceBuilder,
  });

  final bool embedded;
  final List<TimelineTrackData> tracks;
  final TimelineTime currentTime;
  final ValueListenable<TimelineTime>? displayTimeListenable;
  final ValueChanged<TimelineTime>? onDisplayTimeChanged;
  final ValueListenable<TimelineTime>? playbackSampleTimeListenable;
  final TimelineTime timelineDurationTime;
  final bool isPlaying;
  final String? selectedClipId;
  final ValueChanged<String> onClipSelected;
  final ValueChanged<String>? onClipDoubleTap;
  final TimelineClipReorderCallback? onClipReorder;
  final TimelineClipTimeShiftCallback? onClipTimeShift;
  final TimelineBoundaryTransitionTapCallback? onTransitionTap;
  final ValueChanged<TimelineTrackData>? onTrackAnimateTap;
  final VoidCallback? onBackgroundTap;
  final TimelineAssetPathResolver? assetPathResolver;
  final ValueChanged<bool>? onScrubStateChanged;
  final ValueChanged<TimelineTime>? onScrubFinalized;
  final double timelineFps;
  final TimelineTrimSelection? trimSelection;
  final ValueChanged<TimelineTrimCommitRequest>? onTrimCommit;
  final ValueChanged<TimelineTrimPreviewRequest?>? onTrimPreviewChanged;
  final String? selectedTransitionId;
  final String? selectedAnimationLaneId;
  final ValueChanged<String>? onAnimationLaneTap;
  final TimelineTime timeDisplayOffset;
  final TimelineTime? timeReadoutTotalTime;
  final double initialSecondsWidth;
  final Set<TimelineTrackKind> animateTrackKinds;
  final TimelineScrubSurfaceBuilder? scrubSurfaceBuilder;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel>
    with TickerProviderStateMixin {
  static const double _panelPadding = 8;
  static const double _controlTileSize = 36;
  static const double _controlGap = 6;
  static const double _splitGap = 2;
  static const double _joinedMediaGap = 0;
  static const double _playheadLineWidth = 3;
  static final double _timelineControlColumnWidth = math.max(
    _controlTileSize,
    _TimelineTrackLaneProfile.video.controlHitSize,
  );
  static const double _trailingPadding = 120;
  static const double _timeReadoutWidth = 96;
  static const double _rulerHeaderHeight = 20;
  static const double _rulerVisualLift = 3;
  static const double _minSecondsWidth =
      _TimelineZoomCanonicalProfile.minSecondsWidth;
  static const double _maxSecondsWidth =
      _TimelineZoomCanonicalProfile.maxSecondsWidth;
  static const double _scaleGestureDampingFactor =
      _TimelineZoomCanonicalProfile.scaleGestureDampingFactor;
  static const double _scaleGestureActivationDistance =
      _TimelineZoomCanonicalProfile.scaleGestureActivationDistance;
  static const double _scaleGestureWidthEpsilon =
      _TimelineZoomCanonicalProfile.scaleGestureWidthEpsilon;
  static const double _manualPanActivationDistance = 18;
  static const double _maxPlaybackInterpolationLeadSeconds = 0.0;
  static const double _maxPlaybackRegressionToleranceSeconds = 0.24;
  static const double _playbackStartConfirmationThresholdSeconds = 0.01;
  static const double _reorderCardHeight = 40;
  static const double _reorderCardWidth = 40;
  static const double _reorderBaseSlotWidth = 6;
  static const double _reorderActiveSlotWidth = 20;
  static const double _reorderEdgePadding = 12;
  static const double _reorderTrailingPadding = 40;
  static const Duration _reorderExitDelay = Duration(milliseconds: 180);
  static const Duration _reorderEntryDuration = Duration(milliseconds: 240);

  final ScrollController _scrollController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  late final ValueNotifier<TimelineTime> _displayTimeNotifier;
  late final Ticker _playbackTicker;
  late final AnimationController _reorderTransitionController;

  double _playheadLeft = 0;
  double _leadingOffset = 0;
  double _secondsWidth = 32;
  double _scaleStartSecondsWidth = 32;
  TimelineTime _scaleAnchorTime = TimelineTime.zero;
  double _scaleStartDistance = 0;
  double _scrollViewportWidth = 0;
  double _activeTrailingPadding = _trailingPadding;
  bool _isSyncingFromExternal = false;
  bool _isScaleGestureActive = false;
  bool _isNativeScrubbing = false;
  bool _isScrubInteractionActive = false;
  TimelineTime? _pendingNativeScrubUiTime;
  bool _nativeScrubUiUpdateScheduled = false;
  List<TimelineTrackData>? _reorderTracksSnapshot;
  int? _reorderTrackIndex;
  String? _draggedClipId;
  int? _hoverInsertionIndex;
  double _dragOffset = 0;
  double _dragStartOffset = 0;
  double _dragCardWidth = 0;
  int? _reorderPointerId;
  double? _reorderPointerOriginGlobalDx;
  bool _isDropSettling = false;
  Timer? _reorderExitTimer;
  double _manualPanAccumulatedDx = 0;
  _TimelineTrimDragSession? _trimDragSession;
  _TimelineClipMoveSession? _clipMoveSession;
  double? _lockedVerticalOffset;
  _TimelineRulerMode _rulerMode = _TimelineRulerMode.normalSeconds;
  final Set<int> _activePointers = <int>{};
  final Map<int, Offset> _activePointerPositions = <int, Offset>{};
  final Map<int, Offset> _pointerDownPositions = <int, Offset>{};
  List<int>? _scalePointerIds;
  TimelineTime _playbackAnchorTime = TimelineTime.zero;
  Duration _playbackAnchorElapsed = Duration.zero;
  Duration _playbackLastElapsed = Duration.zero;
  TimelineTime _playbackVisualAnchorTime = TimelineTime.zero;
  double _playbackVisualAnchorOffset = 0;
  bool _ignoreProgrammaticHorizontalScroll = false;
  bool _awaitingConfirmedPlaybackMotion = false;
  _TimelineInteractionOwner _interactionOwner = _TimelineInteractionOwner.idle;
  _TimelineInteractionPhase _interactionPhase = _TimelineInteractionPhase.idle;
  int? _nativeScrubPointerId;
  double? _nativeScrubPointerDownDx;
  TimelineTime? _nativeScrubPointerStartTime;
  bool _isDrivingNativeScrubUiLocally = false;

  VoidCallback? _playbackSampleListener;
  VoidCallback? _displayTimeListener;

  double get _currentSeconds => _displayTimeNotifier.value.inSecondsDouble;

  double get _timelineDurationSeconds =>
      widget.timelineDurationTime.inSecondsDouble;

  bool get _shouldAnimatePlayback =>
      widget.isPlaying &&
      !_usesExternalPlaybackSamples &&
      !_isAnyTimelineScrubbing &&
      !_isScaleGestureActive &&
      !_isTrimDragging &&
      !_isClipMoveMode &&
      !_isReorderMode;

  bool get _isPlaybackVisualFollowActive =>
      _shouldAnimatePlayback && !_awaitingConfirmedPlaybackMotion;

  bool get _usesExternalPlaybackSamples =>
      widget.playbackSampleTimeListenable != null;

  bool get _hasHorizontalPanExtent =>
      _scrollController.hasClients &&
      (_scrollController.position.maxScrollExtent -
                  _scrollController.position.minScrollExtent)
              .abs() >
          0.5;

  bool get _blocksVerticalTrackNavigation =>
      _isInteractionPending(_TimelineInteractionOwner.pan) ||
      _isInteractionActive(_TimelineInteractionOwner.pan) ||
      _isAnyTimelineScrubbing ||
      _isScaleGestureActive ||
      _isTrimDragging ||
      _isClipMoveMode ||
      _isTrimInteractionLocked ||
      widget.trimSelection != null ||
      _isReorderMode ||
      _isDropSettling;

  bool get _isAnyTimelineScrubbing => _isNativeScrubbing;

  double _animationRowsHeightForTrack(TimelineTrackData track) {
    if (track.animationLanes.isEmpty) {
      return 0;
    }
    return _TimelineAnimationLaneMetrics.sectionTopSpacing +
        (track.animationLanes.length *
            _TimelineAnimationLaneMetrics.rowHeight) +
        (math.max(0, track.animationLanes.length - 1) *
            _TimelineAnimationLaneMetrics.rowGap) +
        _TimelineAnimationLaneMetrics.sectionBottomSpacing;
  }

  double _rowHeightForTrack(TimelineTrackData track) =>
      _TimelineTrackLaneProfile.forKind(track.kind).rowHeight +
      _animationRowsHeightForTrack(track);

  double _tracksContentHeight(List<TimelineTrackData> tracks) {
    if (tracks.isEmpty) {
      return 0;
    }
    final densityProfile = _stackDensityProfileForTracks(tracks);
    final rowsHeight = tracks.fold<double>(
      0,
      (sum, track) => sum + _rowHeightForTrack(track),
    );
    return rowsHeight +
        (math.max(0, tracks.length - 1) * densityProfile.rowGap);
  }

  _TimelineStackDensityProfile _stackDensityProfileForTracks(
    List<TimelineTrackData> tracks,
  ) =>
      _TimelineStackDensityProfile.forTrackCount(tracks.length);

  bool _isInteractionPending(_TimelineInteractionOwner owner) =>
      _interactionOwner == owner &&
      _interactionPhase == _TimelineInteractionPhase.pending;

  bool _isInteractionActive(_TimelineInteractionOwner owner) =>
      _interactionOwner == owner &&
      _interactionPhase == _TimelineInteractionPhase.active;

  void _runTapOwned(VoidCallback action) {
    if (!_acquireInteractionOwner(
      _TimelineInteractionOwner.tap,
      phase: _TimelineInteractionPhase.active,
    )) {
      return;
    }
    try {
      action();
    } finally {
      _releaseInteractionOwner(_TimelineInteractionOwner.tap);
    }
  }

  void _handleOwnedBackgroundTap() {
    final onBackgroundTap = widget.onBackgroundTap;
    if (onBackgroundTap == null) {
      return;
    }
    _runTapOwned(onBackgroundTap);
  }

  void _handleOwnedClipSelected(String clipId) {
    _runTapOwned(() => widget.onClipSelected(clipId));
  }

  void _handleOwnedClipDoubleTap(TimelineClipData clip) {
    final onClipDoubleTap = widget.onClipDoubleTap;
    if (onClipDoubleTap == null) {
      return;
    }
    _runTapOwned(() => onClipDoubleTap(clip.id));
  }

  bool _acquireInteractionOwner(
    _TimelineInteractionOwner owner, {
    _TimelineInteractionPhase phase = _TimelineInteractionPhase.pending,
  }) {
    if (_interactionOwner == owner) {
      if (phase.index > _interactionPhase.index) {
        _interactionPhase = phase;
      }
      return true;
    }
    if (_interactionOwner == _TimelineInteractionOwner.idle) {
      _interactionOwner = owner;
      _interactionPhase = phase;
      return true;
    }
    return false;
  }

  void _activateInteractionOwner(_TimelineInteractionOwner owner) {
    if (_interactionOwner != owner) {
      return;
    }
    if (_interactionPhase != _TimelineInteractionPhase.active) {
      _interactionPhase = _TimelineInteractionPhase.active;
    }
  }

  void _releaseInteractionOwner(_TimelineInteractionOwner owner) {
    if (_interactionOwner == owner) {
      _interactionOwner = _TimelineInteractionOwner.idle;
      _interactionPhase = _TimelineInteractionPhase.idle;
    }
  }

  void _cancelInteractionOwner(
    _TimelineInteractionOwner owner, {
    bool syncAfterCancel = true,
  }) {
    switch (owner) {
      case _TimelineInteractionOwner.idle:
        return;
      case _TimelineInteractionOwner.tap:
        _releaseInteractionOwner(_TimelineInteractionOwner.tap);
        return;
      case _TimelineInteractionOwner.pan:
        _cancelManualTimelinePan();
        return;
      case _TimelineInteractionOwner.trim:
        if (_isTrimDragging) {
          _endTrimDrag(cancel: true);
          return;
        }
        if (!_isTrimInteractionLocked) {
          _releaseInteractionOwner(_TimelineInteractionOwner.trim);
          return;
        }
        _endTrimInteractionLock();
        return;
      case _TimelineInteractionOwner.zoom:
        _cancelScaleGesture(syncToTime: syncAfterCancel);
        return;
      case _TimelineInteractionOwner.move:
        _clearClipMoveMode(syncToTime: syncAfterCancel);
        return;
      case _TimelineInteractionOwner.reorder:
        _clearReorderMode(syncToTime: syncAfterCancel);
        return;
    }
  }

  void _cancelCurrentInteractionForExternalChange({
    bool syncAfterCancel = false,
  }) {
    final owner = _interactionOwner;
    if (owner == _TimelineInteractionOwner.idle) {
      return;
    }
    _cancelInteractionOwner(
      owner,
      syncAfterCancel: syncAfterCancel,
    );
  }

  TimelineTime get _externalDisplayTime =>
      (widget.displayTimeListenable?.value ?? widget.currentTime).clamp(
        TimelineTime.zero,
        widget.timelineDurationTime,
      );

  TimelineTime _timelineTimeForOffset(double offset) {
    final nextSeconds = (offset / _secondsWidth)
        .clamp(0.0, _timelineDurationSeconds)
        .toDouble();
    return TimelineTime.fromSecondsDouble(nextSeconds);
  }

  double _contentWidthForScale(double secondsWidth) {
    return _buildContentWidth(_activeTrailingPadding,
        secondsWidth: secondsWidth);
  }

  double _headerTextTopInset(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: '00:00', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return ((_rulerHeaderHeight - painter.height) / 2)
        .clamp(0.0, math.max(0.0, _rulerHeaderHeight - painter.height))
        .toDouble();
  }

  double get _resolvedViewportWidth => math.max(_scrollViewportWidth, 1);

  TimelineTime _timeUnderPlayhead() {
    if (!_scrollController.hasClients) {
      return _displayTimeNotifier.value.clamp(
        TimelineTime.zero,
        widget.timelineDurationTime,
      );
    }
    return _timelineTimeForOffset(_scrollController.offset);
  }

  _TimelineRulerMode _resolveRulerMode(
    double secondsWidth, {
    double? viewportWidth,
    _TimelineRulerMode? previousMode,
  }) {
    final fps = widget.timelineFps <= 0 ? 30.0 : widget.timelineFps;
    final pixelsPerFrame = secondsWidth / fps;
    final visibleWindowSeconds = (viewportWidth ?? _resolvedViewportWidth) /
        math.max(secondsWidth, 0.001);
    final currentMode = previousMode ?? _rulerMode;

    switch (currentMode) {
      case _TimelineRulerMode.coarseSeconds:
        if (visibleWindowSeconds <=
            _TimelineRulerCanonicalProfile.coarseToNormalVisibleWindowEnter) {
          return _TimelineRulerMode.normalSeconds;
        }
        return _TimelineRulerMode.coarseSeconds;
      case _TimelineRulerMode.normalSeconds:
        if (visibleWindowSeconds >=
            _TimelineRulerCanonicalProfile.normalToCoarseVisibleWindowExit) {
          return _TimelineRulerMode.coarseSeconds;
        }
        if (visibleWindowSeconds <=
                _TimelineRulerCanonicalProfile
                    .normalToSecondsAndFramesVisibleWindowEnter &&
            pixelsPerFrame >=
                _TimelineRulerCanonicalProfile
                    .normalToSecondsAndFramesPixelsPerFrameEnter) {
          return _TimelineRulerMode.secondsAndFrames;
        }
        return _TimelineRulerMode.normalSeconds;
      case _TimelineRulerMode.secondsAndFrames:
        if (visibleWindowSeconds >=
                _TimelineRulerCanonicalProfile
                    .secondsAndFramesToNormalVisibleWindowExit ||
            pixelsPerFrame <
                _TimelineRulerCanonicalProfile
                    .secondsAndFramesToNormalPixelsPerFrameExit) {
          return _TimelineRulerMode.normalSeconds;
        }
        if (visibleWindowSeconds <=
                _TimelineRulerCanonicalProfile
                    .secondsAndFramesToFineFramesVisibleWindowEnter &&
            pixelsPerFrame >=
                _TimelineRulerCanonicalProfile
                    .secondsAndFramesToFineFramesPixelsPerFrameEnter) {
          return _TimelineRulerMode.fineFrames;
        }
        return _TimelineRulerMode.secondsAndFrames;
      case _TimelineRulerMode.fineFrames:
        if (visibleWindowSeconds >=
                _TimelineRulerCanonicalProfile
                    .fineFramesToSecondsAndFramesVisibleWindowExit ||
            pixelsPerFrame <
                _TimelineRulerCanonicalProfile
                    .fineFramesToSecondsAndFramesPixelsPerFrameExit) {
          return _TimelineRulerMode.secondsAndFrames;
        }
        return _TimelineRulerMode.fineFrames;
    }
  }

  bool get _isReorderMode =>
      _reorderTracksSnapshot != null &&
      _reorderTrackIndex != null &&
      _draggedClipId != null;

  bool get _isTrimDragging => _trimDragSession != null;
  bool get _isClipMoveMode => _clipMoveSession != null;
  bool _isTrimInteractionLocked = false;

  bool _supportsClipTimeShift(TimelineTrackData track, TimelineClipData clip) {
    return track.kind != TimelineTrackKind.video &&
        clip.type == TimelineClipType.media &&
        widget.onClipTimeShift != null;
  }

  TimelineTime? _timelineStartTimeForClip(
    TimelineTrackData track,
    String clipId,
  ) {
    var cursor = TimelineTime.zero;
    for (final clip in track.clips) {
      if (clip.id == clipId) {
        return cursor;
      }
      cursor += clip.durationTime;
    }
    return null;
  }

  List<_TimelinePositionedTrackClip> _positionedMediaClipsForTrack(
    TimelineTrackData track, {
    String? excludingClipId,
  }) {
    final positioned = <_TimelinePositionedTrackClip>[];
    var cursor = TimelineTime.zero;
    for (final clip in track.clips) {
      final clipStartTime = cursor;
      cursor += clip.durationTime;
      if (clip.type != TimelineClipType.media || clip.id == excludingClipId) {
        continue;
      }
      positioned.add(
        _TimelinePositionedTrackClip(
          clip: clip,
          startTime: clipStartTime,
        ),
      );
    }
    return positioned;
  }

  TimelineTime _resolveNearestAllowedClipStartTime({
    required TimelineTrackData track,
    required TimelineClipData clip,
    required TimelineTime candidateStartTime,
  }) {
    final maxStartTime =
        (widget.timelineDurationTime - clip.durationTime).clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    final occupiedClips = _positionedMediaClipsForTrack(
      track,
      excludingClipId: clip.id,
    )..sort((left, right) => left.startTime.compareTo(right.startTime));
    final clampedCandidate =
        candidateStartTime.clamp(TimelineTime.zero, maxStartTime);
    final intervals = <_TimelineClipMoveInterval>[];
    var cursor = TimelineTime.zero;
    for (final occupied in occupiedClips) {
      final intervalEnd = (occupied.startTime - clip.durationTime).clamp(
        TimelineTime.zero,
        maxStartTime,
      );
      if (intervalEnd >= cursor) {
        intervals.add(
          _TimelineClipMoveInterval(
            start: cursor,
            end: intervalEnd,
          ),
        );
      }
      if (occupied.endTime > cursor) {
        cursor = occupied.endTime;
      }
    }
    if (cursor <= maxStartTime) {
      intervals.add(
        _TimelineClipMoveInterval(
          start: cursor,
          end: maxStartTime,
        ),
      );
    }
    if (intervals.isEmpty) {
      return TimelineTime.zero;
    }
    for (final interval in intervals) {
      if (clampedCandidate >= interval.start &&
          clampedCandidate <= interval.end) {
        return clampedCandidate;
      }
    }

    TimelineTime nearestStart = intervals.first.start;
    var nearestDistance =
        (clampedCandidate - nearestStart).inProjectTicks.abs();
    for (final interval in intervals) {
      for (final boundary in <TimelineTime>[interval.start, interval.end]) {
        final distance = (clampedCandidate - boundary).inProjectTicks.abs();
        if (distance < nearestDistance) {
          nearestStart = boundary;
          nearestDistance = distance;
        }
      }
    }
    return nearestStart;
  }

  void _captureLockedVerticalOffset() {
    _lockedVerticalOffset ??=
        _verticalController.hasClients ? _verticalController.offset : 0.0;
  }

  void _restoreLockedVerticalOffset() {
    final lockedOffset = _lockedVerticalOffset;
    if (lockedOffset == null || !_verticalController.hasClients) {
      return;
    }
    final position = _verticalController.position;
    final safeOffset = lockedOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((_verticalController.offset - safeOffset).abs() < 0.5) {
      return;
    }
    _verticalController.jumpTo(safeOffset);
  }

  void _releaseLockedVerticalOffsetIfPossible() {
    if (_blocksVerticalTrackNavigation) {
      _restoreLockedVerticalOffset();
      return;
    }
    _lockedVerticalOffset = null;
  }

  void _beginTrimInteractionLock() {
    if (_isTrimInteractionLocked) {
      _restoreLockedVerticalOffset();
      return;
    }
    if (!_acquireInteractionOwner(_TimelineInteractionOwner.trim)) {
      return;
    }
    _captureLockedVerticalOffset();
    _restoreLockedVerticalOffset();
    setState(() {
      _isTrimInteractionLocked = true;
    });
    _setScrubInteractionActive(true);
    _ensurePlaybackTickerForCurrentMode();
  }

  void _endTrimInteractionLock() {
    if (!_isTrimInteractionLocked || _isTrimDragging) {
      return;
    }
    _restoreLockedVerticalOffset();
    setState(() {
      _isTrimInteractionLocked = false;
    });
    _releaseLockedVerticalOffsetIfPossible();
    _releaseInteractionOwner(_TimelineInteractionOwner.trim);
    _syncScrubInteractionActive();
    _ensurePlaybackTickerForCurrentMode();
  }

  void _handleTrimHandleEngagementChanged(bool isEngaged) {
    if (isEngaged) {
      _beginTrimInteractionLock();
      return;
    }
    _endTrimInteractionLock();
  }

  @override
  void initState() {
    super.initState();
    final seededSecondsWidth = widget.initialSecondsWidth.clamp(
      _minSecondsWidth,
      _maxSecondsWidth,
    );
    _secondsWidth = seededSecondsWidth;
    _scaleStartSecondsWidth = seededSecondsWidth;
    final initialDisplayTime =
        widget.displayTimeListenable?.value ?? widget.currentTime;
    _displayTimeNotifier = ValueNotifier<TimelineTime>(
      initialDisplayTime.clamp(
        TimelineTime.zero,
        widget.timelineDurationTime,
      ),
    );
    _playbackTicker = createTicker(_handlePlaybackTick);
    _reorderTransitionController = AnimationController(
      vsync: this,
      duration: _reorderEntryDuration,
    );
    _rulerMode = _resolveRulerMode(_secondsWidth, viewportWidth: 320);
    _attachDisplayTimeListener(widget.displayTimeListenable);
    _attachPlaybackSampleListener(widget.playbackSampleTimeListenable);
    _ensurePlaybackTickerForCurrentMode();
  }

  @override
  void didUpdateWidget(covariant TimelinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clampedWidgetTime = _externalDisplayTime;
    final seededPlaybackTime = widget.playbackSampleTimeListenable?.value.clamp(
          TimelineTime.zero,
          widget.timelineDurationTime,
        ) ??
        clampedWidgetTime;
    final enteringPlayback = !oldWidget.isPlaying && widget.isPlaying;
    final leavingPlayback = oldWidget.isPlaying && !widget.isPlaying;
    final preserveDisplayTimeOnPlaybackExit = leavingPlayback;
    if (enteringPlayback) {
      _cancelCurrentInteractionForExternalChange(
        syncAfterCancel: false,
      );
    }
    if (enteringPlayback) {
      _setDisplayTime(seededPlaybackTime);
      _snapScrollForPlaybackStart(seededPlaybackTime);
      _playbackAnchorTime = _displayTimeNotifier.value;
      _playbackAnchorElapsed = Duration.zero;
      _playbackLastElapsed = Duration.zero;
      _capturePlaybackVisualAnchor(anchorTime: seededPlaybackTime);
      _awaitingConfirmedPlaybackMotion = true;
    }
    if (leavingPlayback) {
      _awaitingConfirmedPlaybackMotion = false;
      final settledDisplayTime = _displayTimeNotifier.value.clamp(
        TimelineTime.zero,
        widget.timelineDurationTime,
      );
      _driveScrollToTime(settledDisplayTime, epsilonPx: 0.01);
      _setDisplayTime(settledDisplayTime);
    }
    _ensurePlaybackTickerForCurrentMode();
    if (_shouldAnimatePlayback) {
      if (!_usesExternalPlaybackSamples) {
        _applyReportedPlaybackSample(
          clampedWidgetTime,
          snapDisplay: oldWidget.isPlaying && !widget.isPlaying,
        );
      }
    } else if (!preserveDisplayTimeOnPlaybackExit && !_isNativeScrubbing) {
      _setDisplayTime(clampedWidgetTime);
    }
    if ((oldWidget.currentTime != widget.currentTime ||
            oldWidget.isPlaying != widget.isPlaying) &&
        !_shouldAnimatePlayback &&
        !_isNativeScrubbing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (preserveDisplayTimeOnPlaybackExit) {
          _driveScrollToTime(_displayTimeNotifier.value, epsilonPx: 0.01);
          return;
        }
        _syncToTime();
      });
    }
    if (oldWidget.timelineFps != widget.timelineFps) {
      _rulerMode = _resolveRulerMode(_secondsWidth,
          viewportWidth: _resolvedViewportWidth);
    }
    final trimSelection = widget.trimSelection;
    if (trimSelection == null ||
        trimSelection.clipId != oldWidget.trimSelection?.clipId) {
      _cancelCurrentInteractionForExternalChange(
        syncAfterCancel: false,
      );
      _syncScrubInteractionActive();
    }
    if (oldWidget.playbackSampleTimeListenable !=
        widget.playbackSampleTimeListenable) {
      _detachPlaybackSampleListener(oldWidget.playbackSampleTimeListenable);
      _attachPlaybackSampleListener(widget.playbackSampleTimeListenable);
    }
    if (oldWidget.displayTimeListenable != widget.displayTimeListenable) {
      _detachDisplayTimeListener(oldWidget.displayTimeListenable);
      _attachDisplayTimeListener(widget.displayTimeListenable);
    }
  }

  @override
  void dispose() {
    _detachDisplayTimeListener(widget.displayTimeListenable);
    _detachPlaybackSampleListener(widget.playbackSampleTimeListenable);
    _playbackTicker.dispose();
    _reorderTransitionController.dispose();
    _reorderExitTimer?.cancel();
    _displayTimeNotifier.dispose();
    _scrollController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _attachDisplayTimeListener(
    ValueListenable<TimelineTime>? listenable,
  ) {
    if (listenable == null) {
      return;
    }
    _displayTimeListener = () {
      if (_shouldAnimatePlayback ||
          _isAnyTimelineScrubbing ||
          _isTrimDragging ||
          _isClipMoveMode ||
          _isScaleGestureActive) {
        return;
      }
      final clamped = listenable.value.clamp(
        TimelineTime.zero,
        widget.timelineDurationTime,
      );
      _setDisplayTime(clamped);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _shouldAnimatePlayback ||
            _isAnyTimelineScrubbing ||
            _isTrimDragging ||
            _isClipMoveMode ||
            _isScaleGestureActive) {
          return;
        }
        _syncToTime();
      });
    };
    listenable.addListener(_displayTimeListener!);
  }

  void _detachDisplayTimeListener(
    ValueListenable<TimelineTime>? listenable,
  ) {
    final listener = _displayTimeListener;
    if (listenable == null || listener == null) {
      _displayTimeListener = null;
      return;
    }
    listenable.removeListener(listener);
    _displayTimeListener = null;
  }

  void _attachPlaybackSampleListener(
    ValueListenable<TimelineTime>? listenable,
  ) {
    if (listenable == null) {
      return;
    }
    _playbackSampleListener = () {
      if (!_shouldAnimatePlayback) {
        return;
      }
      _applyReportedPlaybackSample(listenable.value);
    };
    listenable.addListener(_playbackSampleListener!);
  }

  void _detachPlaybackSampleListener(
    ValueListenable<TimelineTime>? listenable,
  ) {
    final listener = _playbackSampleListener;
    if (listenable == null || listener == null) {
      _playbackSampleListener = null;
      return;
    }
    listenable.removeListener(listener);
    _playbackSampleListener = null;
  }

  void _setDisplayTime(
    TimelineTime time, {
    bool invokeParentSynchronously = false,
    bool notifyParent = true,
  }) {
    final clamped = time.clamp(TimelineTime.zero, widget.timelineDurationTime);
    if (_displayTimeNotifier.value == clamped) {
      return;
    }
    _displayTimeNotifier.value = clamped;
    if (!notifyParent) {
      return;
    }
    final onDisplayTimeChanged = widget.onDisplayTimeChanged;
    if (onDisplayTimeChanged != null) {
      if (invokeParentSynchronously) {
        onDisplayTimeChanged(clamped);
      } else {
        _invokeParentCallback(() => onDisplayTimeChanged(clamped));
      }
    }
  }

  void _applyReportedPlaybackSample(
    TimelineTime reportedTime, {
    bool snapDisplay = false,
  }) {
    final clamped = reportedTime.clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    final displayTime = _displayTimeNotifier.value;
    if (widget.isPlaying && _awaitingConfirmedPlaybackMotion) {
      final advanceSeconds = (clamped - displayTime).inSecondsDouble;
      _playbackAnchorTime = clamped;
      _playbackAnchorElapsed = Duration.zero;
      _playbackLastElapsed = Duration.zero;
      if (advanceSeconds <= _playbackStartConfirmationThresholdSeconds) {
        _setDisplayTime(clamped);
        return;
      }
      _awaitingConfirmedPlaybackMotion = false;
      _rebasePlaybackVisualFollow(clamped);
      _setDisplayTime(clamped);
      _ensurePlaybackTickerForCurrentMode();
      return;
    }
    final regressionSeconds = (displayTime - clamped).inSecondsDouble;
    final maxPlaybackRegressionToleranceSeconds = _usesExternalPlaybackSamples
        ? 0.0
        : _maxPlaybackRegressionToleranceSeconds;
    if (widget.isPlaying &&
        regressionSeconds > 0 &&
        regressionSeconds <= maxPlaybackRegressionToleranceSeconds) {
      _playbackAnchorTime = displayTime;
      _playbackAnchorElapsed = _playbackLastElapsed;
      return;
    }
    _playbackAnchorTime = clamped;
    _playbackAnchorElapsed = _playbackLastElapsed;
    if (snapDisplay ||
        !_playbackTicker.isActive ||
        (displayTime - clamped).inSecondsDouble.abs() > 0.18) {
      if (_isPlaybackVisualFollowActive) {
        _rebasePlaybackVisualFollow(clamped);
      }
      _setDisplayTime(clamped);
      if (!_shouldAnimatePlayback || snapDisplay) {
        _driveScrollToTime(
          clamped,
          epsilonPx: _playbackTicker.isActive ? 0.01 : 0.5,
        );
      }
    }
  }

  void _ensurePlaybackTickerForCurrentMode() {
    if (_shouldAnimatePlayback) {
      if (_awaitingConfirmedPlaybackMotion) {
        if (_playbackTicker.isActive) {
          _playbackTicker.stop();
        }
        return;
      }
      if (!_playbackTicker.isActive) {
        _playbackAnchorTime = _displayTimeNotifier.value.clamp(
          TimelineTime.zero,
          widget.timelineDurationTime,
        );
        _playbackAnchorElapsed = Duration.zero;
        _playbackLastElapsed = Duration.zero;
        _playbackTicker.start();
      }
      return;
    }
    if (_playbackTicker.isActive) {
      _playbackTicker.stop();
    }
    _awaitingConfirmedPlaybackMotion = false;
  }

  void _handlePlaybackTick(Duration elapsed) {
    if (!_shouldAnimatePlayback) {
      return;
    }
    _playbackLastElapsed = elapsed;
    final delta = elapsed - _playbackAnchorElapsed;
    final deltaSeconds = math.min(
      delta.inMicroseconds / Duration.microsecondsPerSecond,
      _maxPlaybackInterpolationLeadSeconds,
    );
    final nextTime =
        (_playbackAnchorTime + TimelineTime.fromSecondsDouble(deltaSeconds))
            .clamp(TimelineTime.zero, widget.timelineDurationTime);
    _setDisplayTime(nextTime);
  }

  void _capturePlaybackVisualAnchor({
    TimelineTime? anchorTime,
    double? anchorOffset,
  }) {
    final resolvedTime = (anchorTime ?? _displayTimeNotifier.value).clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    final resolvedOffset = anchorOffset ??
        (_scrollController.hasClients
            ? _scrollController.offset
            : _targetHorizontalOffsetForTime(resolvedTime));
    _playbackVisualAnchorTime = resolvedTime;
    _playbackVisualAnchorOffset = resolvedOffset;
  }

  void _snapScrollForPlaybackStart(TimelineTime time) {
    if (!_scrollController.hasClients ||
        _isScaleGestureActive ||
        _isAnyTimelineScrubbing ||
        _isTrimDragging ||
        _isClipMoveMode) {
      return;
    }
    final targetOffset = _targetHorizontalOffsetForTime(time);
    if ((_scrollController.offset - targetOffset).abs() < 0.01) {
      return;
    }
    _ignoreProgrammaticHorizontalScroll = true;
    _isSyncingFromExternal = true;
    _scrollController.jumpTo(targetOffset);
    _isSyncingFromExternal = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ignoreProgrammaticHorizontalScroll = false;
    });
  }

  void _rebasePlaybackVisualFollow(TimelineTime newAnchorTime) {
    _capturePlaybackVisualAnchor(
      anchorTime: newAnchorTime,
      anchorOffset: _effectiveHorizontalScrollOffset(),
    );
  }

  double _targetHorizontalOffsetForTime(TimelineTime time) {
    if (!_scrollController.hasClients) {
      return _targetOffsetForAnchorTime(time, _secondsWidth);
    }
    return (time.inSecondsDouble * _secondsWidth)
        .clamp(0, _scrollController.position.maxScrollExtent)
        .toDouble();
  }

  double _effectiveHorizontalScrollOffset() {
    if (!_scrollController.hasClients) {
      return _targetHorizontalOffsetForTime(_displayTimeNotifier.value);
    }
    if (!_isPlaybackVisualFollowActive) {
      return _scrollController.offset;
    }
    final visualDeltaSeconds =
        (_displayTimeNotifier.value - _playbackVisualAnchorTime)
            .inSecondsDouble;
    return (_playbackVisualAnchorOffset + (visualDeltaSeconds * _secondsWidth))
        .clamp(0, _scrollController.position.maxScrollExtent)
        .toDouble();
  }

  double _playbackVisualTranslateX() {
    if (!_scrollController.hasClients || !_isPlaybackVisualFollowActive) {
      return 0;
    }
    final baseOffset = _scrollController.offset;
    final effectiveOffset = _effectiveHorizontalScrollOffset();
    return -(effectiveOffset - baseOffset);
  }

  void _driveScrollToTime(
    TimelineTime time, {
    double epsilonPx = 0.5,
    bool allowDuringNativeScrub = false,
  }) {
    if (!_scrollController.hasClients ||
        _isScaleGestureActive ||
        (_isAnyTimelineScrubbing && !allowDuringNativeScrub) ||
        _isTrimDragging ||
        _isClipMoveMode) {
      return;
    }
    final target = (time.inSecondsDouble * _secondsWidth)
        .clamp(0, _scrollController.position.maxScrollExtent)
        .toDouble();
    if ((_scrollController.offset - target).abs() < epsilonPx) {
      return;
    }
    _ignoreProgrammaticHorizontalScroll = true;
    _isSyncingFromExternal = true;
    _scrollController.jumpTo(target);
    _isSyncingFromExternal = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ignoreProgrammaticHorizontalScroll = false;
    });
  }

  bool get _canRunScaleGesture =>
      !_isReorderMode &&
      !_isTrimDragging &&
      !_isClipMoveMode &&
      widget.trimSelection == null;

  List<int>? _resolveBestScalePointerIds() {
    if (_activePointerPositions.length < 2) {
      return null;
    }

    final entries = _activePointerPositions.entries.toList(growable: false);
    List<int>? bestPair;
    var bestDistance = -1.0;

    for (var i = 0; i < entries.length - 1; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        final distance = (entries[i].value - entries[j].value).distance;
        if (distance > bestDistance) {
          bestDistance = distance;
          bestPair = <int>[entries[i].key, entries[j].key];
        }
      }
    }

    return bestPair;
  }

  double? _currentScaleDistance() {
    var scalePointerIds = _scalePointerIds;
    if (scalePointerIds == null || scalePointerIds.length < 2) {
      scalePointerIds = _resolveBestScalePointerIds();
      if (scalePointerIds != null) {
        _scalePointerIds = scalePointerIds;
      }
    }
    if (scalePointerIds == null || scalePointerIds.length < 2) {
      return null;
    }
    final firstPosition = _activePointerPositions[scalePointerIds[0]];
    final secondPosition = _activePointerPositions[scalePointerIds[1]];
    if (firstPosition == null || secondPosition == null) {
      return null;
    }
    return (firstPosition - secondPosition).distance;
  }

  double _targetOffsetForAnchorTime(
    TimelineTime anchorTime,
    double secondsWidth,
  ) {
    final nextContentWidth = _contentWidthForScale(secondsWidth);
    final maxOffset =
        math.max(0.0, nextContentWidth - math.max(_scrollViewportWidth, 1));
    return (anchorTime.inSecondsDouble * secondsWidth)
        .clamp(0.0, maxOffset)
        .toDouble();
  }

  void _rebaseActiveScaleGesture() {
    if (!_isScaleGestureActive) {
      return;
    }
    final pointerIds = _resolveBestScalePointerIds();
    if (pointerIds == null || pointerIds.length < 2) {
      return;
    }
    final firstPosition = _activePointerPositions[pointerIds[0]];
    final secondPosition = _activePointerPositions[pointerIds[1]];
    if (firstPosition == null || secondPosition == null) {
      return;
    }
    final rebasedDistance = (firstPosition - secondPosition).distance;
    if (rebasedDistance <= 0) {
      return;
    }
    _scalePointerIds = pointerIds;
    _scaleStartDistance = rebasedDistance;
    _scaleStartSecondsWidth = _secondsWidth;
    _scaleAnchorTime = _timeUnderPlayhead();
  }

  void _beginScaleGesture() {
    if (_isScaleGestureActive || !_canRunScaleGesture) {
      return;
    }
    final pointerIds = _resolveBestScalePointerIds();
    if (pointerIds == null || pointerIds.length < 2) {
      return;
    }
    final firstPosition = _activePointerPositions[pointerIds[0]];
    final secondPosition = _activePointerPositions[pointerIds[1]];
    if (firstPosition == null || secondPosition == null) {
      return;
    }
    final startDistance = (firstPosition - secondPosition).distance;
    if (startDistance < _scaleGestureActivationDistance) {
      return;
    }
    _cancelInteractionOwner(_TimelineInteractionOwner.pan);
    if (!_acquireInteractionOwner(
      _TimelineInteractionOwner.zoom,
      phase: _TimelineInteractionPhase.active,
    )) {
      return;
    }
    _captureLockedVerticalOffset();
    _restoreLockedVerticalOffset();
    _scalePointerIds = pointerIds;
    _scaleStartDistance = startDistance;
    _scaleStartSecondsWidth = _secondsWidth;
    _scaleAnchorTime = _timeUnderPlayhead();
    _isScaleGestureActive = true;
    _ensurePlaybackTickerForCurrentMode();
  }

  void _updateScaleGesture() {
    if (!_isScaleGestureActive) {
      return;
    }
    final currentDistance = _currentScaleDistance();
    if (currentDistance == null || currentDistance <= 0) {
      return;
    }
    final rawScale = currentDistance / math.max(_scaleStartDistance, 0.001);
    final dampedScale = 1 + ((rawScale - 1) * _scaleGestureDampingFactor);
    final nextWidth = (_scaleStartSecondsWidth * dampedScale)
        .clamp(_minSecondsWidth, _maxSecondsWidth)
        .toDouble();

    if ((nextWidth - _secondsWidth).abs() < _scaleGestureWidthEpsilon) {
      return;
    }

    final targetOffset =
        _targetOffsetForAnchorTime(_scaleAnchorTime, nextWidth);
    final nextMode = _resolveRulerMode(
      nextWidth,
      viewportWidth: _resolvedViewportWidth,
      previousMode: _rulerMode,
    );

    setState(() {
      _secondsWidth = nextWidth;
      _rulerMode = nextMode;
    });

    if (_scrollController.hasClients) {
      _isSyncingFromExternal = true;
      _scrollController.jumpTo(targetOffset);
      _isSyncingFromExternal = false;
    }
  }

  void _cancelScaleGesture({bool syncToTime = true}) {
    if (!_isScaleGestureActive) {
      _releaseInteractionOwner(_TimelineInteractionOwner.zoom);
      return;
    }
    _isScaleGestureActive = false;
    _scalePointerIds = null;
    _scaleStartDistance = 0;
    _releaseInteractionOwner(_TimelineInteractionOwner.zoom);
    _releaseLockedVerticalOffsetIfPossible();
    _ensurePlaybackTickerForCurrentMode();
    if (syncToTime &&
        (_externalDisplayTime - _scaleAnchorTime).inSecondsDouble.abs() >
            0.05) {
      _syncToTime();
    }
  }

  void _setScrubInteractionActive(bool isActive) {
    if (_isScrubInteractionActive == isActive) {
      return;
    }
    _isScrubInteractionActive = isActive;
    final onScrubStateChanged = widget.onScrubStateChanged;
    if (onScrubStateChanged != null) {
      _invokeParentCallback(() => onScrubStateChanged(isActive));
    }
  }

  void _syncScrubInteractionActive() {
    _setScrubInteractionActive(_isAnyTimelineScrubbing);
  }

  void _cancelNativeScrub({required bool finalize}) {
    if (!_isNativeScrubbing) {
      return;
    }
    final finalTime = _displayTimeNotifier.value.clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    if (finalize) {
      _setDisplayTime(
        finalTime,
        invokeParentSynchronously: true,
      );
      final onScrubFinalized = widget.onScrubFinalized;
      if (onScrubFinalized != null) {
        _invokeParentCallback(() => onScrubFinalized(finalTime));
      }
    }
    _isNativeScrubbing = false;
    _releaseLockedVerticalOffsetIfPossible();
    _syncScrubInteractionActive();
    _ensurePlaybackTickerForCurrentMode();
    if (!finalize) {
      _setDisplayTime(
        _externalDisplayTime,
        invokeParentSynchronously: true,
      );
    }
  }

  void _invokeParentCallback(VoidCallback callback) {
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.idle ||
        schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      callback();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      callback();
    });
  }

  void _beginManualTimelinePan() {
    if (widget.isPlaying ||
        _isReorderMode ||
        _isTrimDragging ||
        _isClipMoveMode ||
        _isScaleGestureActive ||
        _isAnyTimelineScrubbing ||
        !_hasHorizontalPanExtent) {
      return;
    }
    if (!_acquireInteractionOwner(_TimelineInteractionOwner.pan)) {
      return;
    }
    _manualPanAccumulatedDx = 0;
    _captureLockedVerticalOffset();
    _restoreLockedVerticalOffset();
  }

  void _updateManualTimelinePan(double deltaDx) {
    final isPending = _isInteractionPending(_TimelineInteractionOwner.pan);
    final isActive = _isInteractionActive(_TimelineInteractionOwner.pan);
    if (!isPending && !isActive) {
      return;
    }
    if (!_hasHorizontalPanExtent) {
      _cancelManualTimelinePan();
      return;
    }
    var appliedDeltaDx = deltaDx;
    if (isPending && !isActive) {
      final nextAccumulatedDx = _manualPanAccumulatedDx + deltaDx;
      if (nextAccumulatedDx.abs() < _manualPanActivationDistance) {
        _manualPanAccumulatedDx = nextAccumulatedDx;
        _restoreLockedVerticalOffset();
        return;
      }
      appliedDeltaDx = nextAccumulatedDx.isNegative
          ? nextAccumulatedDx + _manualPanActivationDistance
          : nextAccumulatedDx - _manualPanActivationDistance;
      _manualPanAccumulatedDx = 0;
      _activateInteractionOwner(_TimelineInteractionOwner.pan);
      if (appliedDeltaDx.abs() < 0.01) {
        _restoreLockedVerticalOffset();
        return;
      }
    } else {
      _activateInteractionOwner(_TimelineInteractionOwner.pan);
    }
    final position = _scrollController.position;
    final targetOffset = (_scrollController.offset - appliedDeltaDx)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((_scrollController.offset - targetOffset).abs() < 0.01) {
      _restoreLockedVerticalOffset();
      return;
    }
    _isSyncingFromExternal = true;
    _scrollController.jumpTo(targetOffset);
    _isSyncingFromExternal = false;
    _restoreLockedVerticalOffset();
  }

  void _endManualTimelinePan() {
    final wasOwned = _isInteractionPending(_TimelineInteractionOwner.pan) ||
        _isInteractionActive(_TimelineInteractionOwner.pan);
    if (!wasOwned) {
      return;
    }
    final finalTime = _displayTimeNotifier.value.clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    _manualPanAccumulatedDx = 0;
    _restoreLockedVerticalOffset();
    if (_isScrubInteractionActive) {
      final onScrubFinalized = widget.onScrubFinalized;
      if (onScrubFinalized != null) {
        _invokeParentCallback(() => onScrubFinalized(finalTime));
      }
    }
    _releaseInteractionOwner(_TimelineInteractionOwner.pan);
    _releaseLockedVerticalOffsetIfPossible();
    _setScrubInteractionActive(false);
  }

  void _cancelManualTimelinePan() {
    final wasOwned = _isInteractionPending(_TimelineInteractionOwner.pan) ||
        _isInteractionActive(_TimelineInteractionOwner.pan);
    if (!wasOwned) {
      return;
    }
    _manualPanAccumulatedDx = 0;
    _restoreLockedVerticalOffset();
    _releaseInteractionOwner(_TimelineInteractionOwner.pan);
    _releaseLockedVerticalOffsetIfPossible();
  }

  void _handleGlobalPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _activePointerPositions[event.pointer] = event.position;
    _pointerDownPositions[event.pointer] = event.position;
    if (_isScaleGestureActive) {
      _rebaseActiveScaleGesture();
    }
    if (_activePointers.length > 1) {
      _beginScaleGesture();
    }
  }

  void _handleGlobalPointerMove(PointerMoveEvent event) {
    if (!_activePointers.contains(event.pointer)) {
      return;
    }
    _activePointerPositions[event.pointer] = event.position;
    if (_isNativeScrubbing &&
        event.pointer == _nativeScrubPointerId &&
        !_isScaleGestureActive &&
        !_isReorderMode &&
        !_isTrimDragging &&
        !_isClipMoveMode) {
      final pointerDownDx = _nativeScrubPointerDownDx;
      final pointerStartTime = _nativeScrubPointerStartTime;
      if (pointerDownDx != null && pointerStartTime != null) {
        final secondsWidth = _secondsWidth.abs() < 0.0001 ? 0.0001 : _secondsWidth;
        final deltaMs =
            (((event.position.dx - pointerDownDx) / secondsWidth) * 1000.0)
                .round();
        final nextTime = (pointerStartTime -
                TimelineTime.fromMilliseconds(deltaMs))
            .clamp(
              TimelineTime.zero,
              widget.timelineDurationTime,
            );
        _isDrivingNativeScrubUiLocally = true;
        _scheduleNativeScrubUiUpdate(nextTime);
      }
    }
    if (_reorderPointerId == event.pointer &&
        _isReorderMode &&
        !_isDropSettling) {
      _updateActiveReorderFromGlobalDx(event.position.dx);
      return;
    }
    if (_isScaleGestureActive) {
      _updateScaleGesture();
      return;
    }
    if (_activePointers.length > 1) {
      _beginScaleGesture();
    }
  }

  void _handleGlobalPointerEnd(int pointer) {
    final wasReorderPointer = _reorderPointerId == pointer;
    final wasScalePointer =
        _scalePointerIds?.contains(pointer) ?? _isScaleGestureActive;
    _activePointers.remove(pointer);
    _activePointerPositions.remove(pointer);
    _pointerDownPositions.remove(pointer);
    if (_nativeScrubPointerId == pointer) {
      _nativeScrubPointerId = null;
      _nativeScrubPointerDownDx = null;
      _nativeScrubPointerStartTime = null;
      _isDrivingNativeScrubUiLocally = false;
    }
    if (wasReorderPointer) {
      _reorderPointerId = null;
      _reorderPointerOriginGlobalDx = null;
      final trackIndex = _reorderTrackIndex;
      final draggedClip = _resolveActiveReorderClip();
      if (trackIndex != null && draggedClip != null) {
        _finishClipReorder(trackIndex, draggedClip);
      }
    }
    if (wasScalePointer && _activePointers.length < 2) {
      _cancelInteractionOwner(_TimelineInteractionOwner.zoom);
    } else if (_isScaleGestureActive) {
      _rebaseActiveScaleGesture();
    }
    if (_activePointers.isEmpty &&
        (_isInteractionPending(_TimelineInteractionOwner.pan) ||
            _isInteractionActive(_TimelineInteractionOwner.pan))) {
      _cancelInteractionOwner(_TimelineInteractionOwner.pan);
    }
  }

  void _handleNativeScrubStart() {
    if (_isReorderMode ||
        _isTrimDragging ||
        _isClipMoveMode ||
        _isScaleGestureActive) {
      return;
    }
    if (_isNativeScrubbing) {
      return;
    }
    _captureLockedVerticalOffset();
    _restoreLockedVerticalOffset();
    _isNativeScrubbing = true;
    if (_activePointers.length == 1) {
      final pointerId = _activePointers.first;
      _nativeScrubPointerId = pointerId;
      _nativeScrubPointerDownDx =
          _pointerDownPositions[pointerId]?.dx ?? _activePointerPositions[pointerId]?.dx;
      _nativeScrubPointerStartTime = _displayTimeNotifier.value;
      _isDrivingNativeScrubUiLocally = _nativeScrubPointerDownDx != null;
    } else {
      _nativeScrubPointerId = null;
      _nativeScrubPointerDownDx = null;
      _nativeScrubPointerStartTime = null;
      _isDrivingNativeScrubUiLocally = false;
    }
    _syncScrubInteractionActive();
    _ensurePlaybackTickerForCurrentMode();
  }

  void _applyNativeScrubUiTime(
    TimelineTime time, {
    bool notifyParent = false,
    bool invokeParentSynchronously = false,
  }) {
    _driveScrollToTime(
      time,
      epsilonPx: 0.01,
      allowDuringNativeScrub: true,
    );
    _setDisplayTime(
      time,
      notifyParent: notifyParent,
      invokeParentSynchronously: invokeParentSynchronously,
    );
  }

  void _scheduleNativeScrubUiUpdate(TimelineTime time) {
    _pendingNativeScrubUiTime = time;
    if (_nativeScrubUiUpdateScheduled) {
      return;
    }
    _nativeScrubUiUpdateScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _nativeScrubUiUpdateScheduled = false;
      if (!mounted || !_isNativeScrubbing) {
        _pendingNativeScrubUiTime = null;
        return;
      }
      final pendingTime = _pendingNativeScrubUiTime;
      _pendingNativeScrubUiTime = null;
      if (pendingTime == null) {
        return;
      }
      _applyNativeScrubUiTime(pendingTime);
    });
  }

  void _flushPendingNativeScrubUiUpdate() {
    final pendingTime = _pendingNativeScrubUiTime;
    _pendingNativeScrubUiTime = null;
    _nativeScrubUiUpdateScheduled = false;
    if (pendingTime == null) {
      return;
    }
    _applyNativeScrubUiTime(pendingTime);
  }

  void _handleNativeScrubTimeChanged(TimelineTime time) {
    final nextTime = time.clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    if (!_isNativeScrubbing) {
      _handleNativeScrubStart();
      if (!_isNativeScrubbing) {
        return;
      }
    }
    if (_isDrivingNativeScrubUiLocally) {
      return;
    }
    _scheduleNativeScrubUiUpdate(nextTime);
  }

  void _handleNativeScrubEnd(TimelineTime time) {
    final finalTime = time.clamp(
      TimelineTime.zero,
      widget.timelineDurationTime,
    );
    if (!_isNativeScrubbing) {
      final onScrubFinalized = widget.onScrubFinalized;
      if (onScrubFinalized != null) {
        _invokeParentCallback(() => onScrubFinalized(finalTime));
      }
      return;
    }
    _flushPendingNativeScrubUiUpdate();
    _applyNativeScrubUiTime(
      finalTime,
      notifyParent: true,
      invokeParentSynchronously: true,
    );
    final onScrubFinalized = widget.onScrubFinalized;
    if (onScrubFinalized != null) {
      _invokeParentCallback(() => onScrubFinalized(finalTime));
    }
    _isNativeScrubbing = false;
    _nativeScrubPointerId = null;
    _nativeScrubPointerDownDx = null;
    _nativeScrubPointerStartTime = null;
    _isDrivingNativeScrubUiLocally = false;
    _pendingNativeScrubUiTime = null;
    _nativeScrubUiUpdateScheduled = false;
    _releaseLockedVerticalOffsetIfPossible();
    _syncScrubInteractionActive();
    _ensurePlaybackTickerForCurrentMode();
  }

  double _nativeScrubAnimateButtonWidthForTrack(TimelineTrackData track) {
    final showsAnimateButton = widget.onTrackAnimateTap != null &&
        widget.animateTrackKinds.contains(track.kind) &&
        track.clips.any((clip) => clip.type == TimelineClipType.media);
    return showsAnimateButton ? 32.0 : 0.0;
  }

  bool _nativeScrubIsGapPlaceholderClip(TimelineClipData clip) {
    if (clip.type != TimelineClipType.placeholder) {
      return false;
    }
    final label = clip.label;
    return label == null || label.trim().isEmpty;
  }

  bool _nativeScrubShouldJoinWith(
    TimelineTrackData track,
    TimelineClipData left,
    TimelineClipData right,
  ) {
    return track.kind == TimelineTrackKind.video &&
        left.type == TimelineClipType.media &&
        right.type == TimelineClipType.media &&
        left.assetId != null &&
        right.assetId != null;
  }

  double _nativeScrubGapAfterClip(
    TimelineTrackData track,
    TimelineClipData clip,
    TimelineClipData next,
  ) {
    if (_nativeScrubIsGapPlaceholderClip(clip) ||
        _nativeScrubIsGapPlaceholderClip(next)) {
      return 0;
    }
    final isSplitSibling =
        clip.splitGroupId != null && clip.splitGroupId == next.splitGroupId;
    if (isSplitSibling) {
      return _splitGap;
    }
    if (_nativeScrubShouldJoinWith(track, clip, next)) {
      return 0;
    }
    return _controlGap;
  }

  bool _nativeScrubSupportsTrimChrome(
    TimelineTrackData track,
    TimelineClipData clip,
  ) {
    final selection = widget.trimSelection;
    if (selection == null) {
      return false;
    }
    return selection.clipId == clip.id &&
        selection.trackKind == track.kind &&
        track.kind == TimelineTrackKind.video &&
        clip.type == TimelineClipType.media;
  }

  _ResolvedTrimClipGeometry _nativeScrubResolveTrimGeometry({
    required TimelineClipData clip,
    required double originalLeft,
    required double originalWidth,
    required _TimelineTrimDragSession? trimSession,
  }) {
    if (trimSession == null) {
      return _ResolvedTrimClipGeometry(
        clip: clip,
        left: originalLeft,
        width: originalWidth,
        sourceStartTime: clip.sourceStartTime,
        durationTime: clip.durationTime,
      );
    }

    final previewWidth = math.max(
      1.0,
      trimSession.durationTime.inSecondsDouble * _secondsWidth,
    );
    final previewLeft = trimSession.edge == TimelineTrimEdge.start
        ? originalLeft + (originalWidth - previewWidth)
        : originalLeft;
    return _ResolvedTrimClipGeometry(
      clip: clip,
      left: previewLeft,
      width: previewWidth,
      sourceStartTime: trimSession.sourceStartTime,
      durationTime: trimSession.durationTime,
      isPreviewing: true,
    );
  }

  void _addNativeScrubViewportRegion(
    List<TimelineScrubViewportRegion> regions, {
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final clampedLeft = left.clamp(0.0, viewportWidth).toDouble();
    final clampedTop = top.clamp(0.0, viewportHeight).toDouble();
    final clampedRight = right.clamp(0.0, viewportWidth).toDouble();
    final clampedBottom = bottom.clamp(0.0, viewportHeight).toDouble();
    final width = clampedRight - clampedLeft;
    final height = clampedBottom - clampedTop;
    if (width <= 0.5 || height <= 0.5) {
      return;
    }
    regions.add(
      TimelineScrubViewportRegion(
        left: clampedLeft,
        top: clampedTop,
        width: width,
        height: height,
      ),
    );
  }

  List<_TimelineScrubExclusion> _mergeNativeScrubExclusions(
    List<_TimelineScrubExclusion> exclusions,
    double rowWidth,
  ) {
    final normalized = exclusions
        .map(
          (exclusion) => _TimelineScrubExclusion(
            left: exclusion.left.clamp(0.0, rowWidth).toDouble(),
            right: exclusion.right.clamp(0.0, rowWidth).toDouble(),
          ),
        )
        .where((exclusion) => exclusion.right - exclusion.left > 0.5)
        .toList()
      ..sort((left, right) => left.left.compareTo(right.left));
    if (normalized.isEmpty) {
      return const <_TimelineScrubExclusion>[];
    }

    final merged = <_TimelineScrubExclusion>[];
    var current = normalized.first;
    for (var index = 1; index < normalized.length; index++) {
      final next = normalized[index];
      if (next.left <= current.right + 0.5) {
        current = _TimelineScrubExclusion(
          left: current.left,
          right: math.max(current.right, next.right),
        );
        continue;
      }
      merged.add(current);
      current = next;
    }
    merged.add(current);
    return merged;
  }

  List<TimelineScrubViewportRegion> _buildNativeTrackViewportScrubRegions({
    required double viewportWidth,
    required double viewportHeight,
    required double contentWidth,
    required double tracksContentHeight,
  }) {
    final horizontalOffset = _scrollController.hasClients
        ? _scrollController.offset
            .clamp(0.0, _scrollController.position.maxScrollExtent)
            .toDouble()
        : 0.0;
    final verticalOffset = _verticalController.hasClients
        ? _verticalController.offset
            .clamp(0.0, _verticalController.position.maxScrollExtent)
            .toDouble()
        : 0.0;
    final regions = <TimelineScrubViewportRegion>[];
    final densityProfile = _stackDensityProfileForTracks(widget.tracks);
    var rowTop = -verticalOffset;

    for (var trackIndex = 0; trackIndex < widget.tracks.length; trackIndex++) {
      final track = widget.tracks[trackIndex];
      final rowHeight = _rowHeightForTrack(track);
      _appendNativeTrackViewportRegionsForTrack(
        regions,
        track: track,
        trackIndex: trackIndex,
        rowTop: rowTop,
        rowHeight: rowHeight,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        contentWidth: contentWidth,
        horizontalOffset: horizontalOffset,
      );
      rowTop += rowHeight;
      if (trackIndex != widget.tracks.length - 1) {
        rowTop += densityProfile.rowGap;
      }
    }

    if (tracksContentHeight < viewportHeight - 0.5) {
      _addNativeScrubViewportRegion(
        regions,
        left: 0,
        top: tracksContentHeight - verticalOffset,
        right: viewportWidth,
        bottom: viewportHeight,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
      );
    }

    return regions;
  }

  void _appendNativeTrackViewportRegionsForTrack(
    List<TimelineScrubViewportRegion> regions, {
    required TimelineTrackData track,
    required int trackIndex,
    required double rowTop,
    required double rowHeight,
    required double viewportWidth,
    required double viewportHeight,
    required double contentWidth,
    required double horizontalOffset,
  }) {
    _addNativeScrubViewportRegion(
      regions,
      left: 0,
      top: rowTop,
      right: viewportWidth,
      bottom: rowTop + rowHeight,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );

    final laneProfile = _TimelineTrackLaneProfile.forKind(track.kind);
    final controlHitSize =
        math.max(_controlTileSize, laneProfile.controlHitSize);
    final panZoneRight = _leadingOffset + controlHitSize + _controlGap;
    final clipStart = panZoneRight;
    final controlLeft =
        _leadingOffset - _nativeScrubAnimateButtonWidthForTrack(track);
    final scrubExclusions = <_TimelineScrubExclusion>[
      _TimelineScrubExclusion(left: controlLeft, right: panZoneRight),
    ];
    final clipGeometryById = <String, _TimelineAnimationClipGeometry>{};
    final moveSession = _clipMoveSession;
    final previewClipId =
        moveSession?.trackIndex == trackIndex ? moveSession?.clipId : null;
    final previewStartTime = moveSession?.trackIndex == trackIndex
        ? moveSession?.currentStartTime
        : null;
    var cursor = clipStart;

    for (var index = 0; index < track.clips.length; index++) {
      final clip = track.clips[index];
      final clipWidth = clip.visualWidth(_secondsWidth);
      final isGapPlaceholder = _nativeScrubIsGapPlaceholderClip(clip);
      final showsTrimChrome = _nativeScrubSupportsTrimChrome(track, clip);
      final activeTrimSession = _trimDragSession?.selection.clipId == clip.id
          ? _trimDragSession
          : null;
      final trimGeometry = _nativeScrubResolveTrimGeometry(
        clip: clip,
        originalLeft: cursor,
        originalWidth: clipWidth,
        trimSession: activeTrimSession,
      );
      final previewLeft = previewClipId == clip.id && previewStartTime != null
          ? clipStart + (previewStartTime.inSecondsDouble * _secondsWidth)
          : trimGeometry.left;
      if (!isGapPlaceholder && clip.type == TimelineClipType.media) {
        clipGeometryById[clip.id] = _TimelineAnimationClipGeometry(
          left: previewLeft,
          width: trimGeometry.width,
        );
      }
      if (showsTrimChrome) {
        scrubExclusions.add(
          _TimelineScrubExclusion(
            left: trimGeometry.left - _TimelineTrimChrome.handleTouchInset,
            right: trimGeometry.left +
                trimGeometry.width +
                _TimelineTrimChrome.handleTouchInset,
          ),
        );
      }
      if (index != track.clips.length - 1) {
        final next = track.clips[index + 1];
        cursor += clipWidth + _nativeScrubGapAfterClip(track, clip, next);
      } else {
        cursor += clipWidth;
      }
    }

    final rowWidth = math.max(cursor + _controlGap, clipStart + 12);
    final interactiveWidth = math.max(rowWidth, contentWidth);
    final trackSpanWidth = math.max(1.0, cursor - clipStart);
    final visibleAnimationLanes = track.animationLanes
        .where(
          (lane) =>
              clipGeometryById.containsKey(lane.targetClipId) ||
              (lane.trackSpanStartProgress != null &&
                  lane.trackSpanEndProgress != null),
        )
        .toList(growable: false);
    for (final lane in visibleAnimationLanes) {
      final geometry = switch ((
        lane.trackSpanStartProgress,
        lane.trackSpanEndProgress,
      )) {
        (final start?, final end?) => _TimelineAnimationClipGeometry(
            left: clipStart + (trackSpanWidth * start.clamp(0.0, 1.0)),
            width: math.max(
              1.0,
              trackSpanWidth * (end.clamp(0.0, 1.0) - start.clamp(0.0, 1.0)),
            ),
          ),
        _ => clipGeometryById[lane.targetClipId],
      };
      if (geometry == null) {
        continue;
      }
      scrubExclusions.add(
        _TimelineScrubExclusion(
          left: controlLeft,
          right:
              math.min(interactiveWidth, geometry.left + geometry.width + 18),
        ),
      );
    }

    final mergedExclusions =
        _mergeNativeScrubExclusions(scrubExclusions, interactiveWidth);
    var zoneCursor = 0.0;
    for (final exclusion in mergedExclusions) {
      _addNativeScrubViewportRegion(
        regions,
        left: zoneCursor - horizontalOffset,
        top: rowTop,
        right: exclusion.left - horizontalOffset,
        bottom: rowTop + rowHeight,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
      );
      zoneCursor = math.max(zoneCursor, exclusion.right);
    }
    _addNativeScrubViewportRegion(
      regions,
      left: zoneCursor - horizontalOffset,
      top: rowTop,
      right: interactiveWidth - horizontalOffset,
      bottom: rowTop + rowHeight,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
  }

  List<TimelineScrubViewportRegion> _buildUnifiedNativeScrubRegions({
    required double viewportWidth,
    required double tracksViewportHeight,
    required double contentWidth,
    required double tracksContentHeight,
  }) {
    final regions = <TimelineScrubViewportRegion>[];
    const headerLeft = _timeReadoutWidth + 6;
    final headerWidth = math.max(0.0, viewportWidth - headerLeft);
    if (headerWidth > 0.5) {
      regions.add(
        TimelineScrubViewportRegion(
          left: headerLeft,
          top: -_rulerVisualLift,
          width: headerWidth,
          height: _rulerHeaderHeight,
        ),
      );
    }
    regions.add(
      TimelineScrubViewportRegion(
        left: 0,
        top: _rulerHeaderHeight,
        width: viewportWidth,
        height: 8,
      ),
    );
    const trackTop = _rulerHeaderHeight + 8;
    final trackRegions = _buildNativeTrackViewportScrubRegions(
      viewportWidth: viewportWidth,
      viewportHeight: tracksViewportHeight,
      contentWidth: contentWidth,
      tracksContentHeight: tracksContentHeight,
    );
    for (final region in trackRegions) {
      regions.add(
        TimelineScrubViewportRegion(
          left: region.left,
          top: region.top + trackTop,
          width: region.width,
          height: region.height,
        ),
      );
    }
    return regions;
  }

  Widget _buildUnifiedNativeScrubOverlay({
    required double viewportWidth,
    required double tracksViewportHeight,
    required double contentWidth,
    required double tracksContentHeight,
  }) {
    final builder = widget.scrubSurfaceBuilder;
    if (builder == null || _isReorderMode) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _scrollController,
        _verticalController,
      ]),
      builder: (context, _) {
        final regions = _buildUnifiedNativeScrubRegions(
          viewportWidth: viewportWidth,
          tracksViewportHeight: tracksViewportHeight,
          contentWidth: contentWidth,
          tracksContentHeight: tracksContentHeight,
        );
        return builder(
          TimelineScrubSurfaceConfig(
            currentTime: _displayTimeNotifier.value,
            currentTimeListenable: _displayTimeNotifier,
            timelineDurationTime: widget.timelineDurationTime,
            timelineOffsetTime: widget.timeDisplayOffset,
            secondsWidth: _secondsWidth,
            regions: regions,
            onTap: widget.onBackgroundTap == null
                ? null
                : _handleOwnedBackgroundTap,
            onScrubStart: _handleNativeScrubStart,
            onScrubTimeChanged: _handleNativeScrubTimeChanged,
            onScrubEnd: _handleNativeScrubEnd,
          ),
        );
      },
    );
  }

  void _handleManualPanDragStart(DragStartDetails details) {
    if (_activePointers.length > 1) {
      return;
    }
    _beginManualTimelinePan();
  }

  void _handleManualPanDragUpdate(DragUpdateDetails details) {
    final deltaDx = details.primaryDelta ?? details.delta.dx;
    if (deltaDx == 0) {
      return;
    }
    _updateManualTimelinePan(deltaDx);
  }

  void _handleManualPanDragEnd([DragEndDetails? details]) {
    _endManualTimelinePan();
  }

  void _handleManualPanDragCancel() {
    _cancelInteractionOwner(_TimelineInteractionOwner.pan);
  }

  void _syncToTime() {
    if (!_scrollController.hasClients ||
        _shouldAnimatePlayback ||
        _isScaleGestureActive ||
        _isAnyTimelineScrubbing ||
        _isTrimDragging ||
        _isClipMoveMode) {
      return;
    }
    _driveScrollToTime(_displayTimeNotifier.value);
  }

  List<TimelineTrackData> _cloneTracks(List<TimelineTrackData> tracks) {
    return tracks
        .map(
          (track) => track.copyWith(
            clips: List<TimelineClipData>.from(track.clips),
          ),
        )
        .toList(growable: false);
  }

  bool _isJoinedTimelineMediaPair(
    TimelineTrackKind kind,
    TimelineClipData left,
    TimelineClipData right,
  ) {
    return kind == TimelineTrackKind.video &&
        left.type == TimelineClipType.media &&
        right.type == TimelineClipType.media;
  }

  double _expandedTrackGapAfterClip(
    TimelineTrackData track,
    TimelineClipData clip,
    TimelineClipData next,
  ) {
    final isSplitSibling =
        clip.splitGroupId != null && clip.splitGroupId == next.splitGroupId;
    if (isSplitSibling) {
      return _splitGap;
    }
    if (_isJoinedTimelineMediaPair(track.kind, clip, next)) {
      return _joinedMediaGap;
    }
    return _controlGap;
  }

  _TimelineExpandedTrackRowLayout _buildExpandedTrackRowLayout(
    TimelineTrackData track,
  ) {
    final laneProfile = _TimelineTrackLaneProfile.forKind(track.kind);
    final controlColumnWidth =
        math.max(_controlTileSize, laneProfile.controlHitSize);
    final clipStart = _leadingOffset + controlColumnWidth + _controlGap;
    final leftByClipId = <String, double>{};
    final widthByClipId = <String, double>{};
    var cursor = clipStart;

    for (var i = 0; i < track.clips.length; i++) {
      final clip = track.clips[i];
      final clipWidth = clip.visualWidth(_secondsWidth);
      leftByClipId[clip.id] = cursor;
      widthByClipId[clip.id] = clipWidth;
      cursor += clipWidth;
      if (i != track.clips.length - 1) {
        cursor += _expandedTrackGapAfterClip(track, clip, track.clips[i + 1]);
      }
    }

    return _TimelineExpandedTrackRowLayout(
      leftByClipId: leftByClipId,
      widthByClipId: widthByClipId,
      rowWidth: math.max(cursor + _controlGap, clipStart + 12),
      clipTopInset: laneProfile.clipTopInset,
      clipHeight: laneProfile.clipHeight,
    );
  }

  double _compactClipWidth(TimelineClipData clip) {
    if (clip.type == TimelineClipType.placeholder) {
      return 52;
    }
    return _reorderCardWidth;
  }

  _TimelineReorderRowLayout _buildReorderRowLayout(
    TimelineTrackData track, {
    String? draggedClipId,
    int? hoverInsertionIndex,
  }) {
    final stationaryClips = <TimelineClipData>[
      for (final clip in track.clips)
        if (clip.id != draggedClipId) clip,
    ];
    final controlColumnWidth = math.max(
      _controlTileSize,
      _TimelineTrackLaneProfile.forKind(track.kind).controlHitSize,
    );
    final clipStart =
        _leadingOffset + controlColumnWidth + _controlGap + _reorderEdgePadding;
    final slotCenters = <double>[];
    final leftByClipId = <String, double>{};
    final widthByClipId = <String, double>{};
    var cursor = clipStart;

    for (var slotIndex = 0; slotIndex <= stationaryClips.length; slotIndex++) {
      final slotWidth = slotIndex == hoverInsertionIndex
          ? _reorderActiveSlotWidth
          : _reorderBaseSlotWidth;
      slotCenters.add(cursor + (slotWidth / 2));
      cursor += slotWidth;
      if (slotIndex == stationaryClips.length) {
        continue;
      }

      final clip = stationaryClips[slotIndex];
      final cardWidth = _compactClipWidth(clip);
      leftByClipId[clip.id] = cursor;
      widthByClipId[clip.id] = cardWidth;
      cursor += cardWidth;
    }

    return _TimelineReorderRowLayout(
      stationaryClips: stationaryClips,
      slotCenters: slotCenters,
      leftByClipId: leftByClipId,
      widthByClipId: widthByClipId,
      rowWidth: cursor + _reorderTrailingPadding,
    );
  }

  int _resolveHoverInsertionIndex(
    List<double> slotCenters,
    double dragCenter,
  ) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < slotCenters.length; i++) {
      final distance = (slotCenters[i] - dragCenter).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    final currentIndex = _hoverInsertionIndex;
    if (currentIndex != null && currentIndex < slotCenters.length) {
      final currentDistance = (slotCenters[currentIndex] - dragCenter).abs();
      if (nearestIndex != currentIndex &&
          nearestDistance + 12 >= currentDistance) {
        return currentIndex;
      }
    }
    return nearestIndex;
  }

  double _magnetizedDragOffset(List<double> slotCenters) {
    final hoverIndex = _hoverInsertionIndex;
    if (hoverIndex == null || hoverIndex >= slotCenters.length) {
      return _dragOffset;
    }

    final target = slotCenters[hoverIndex];
    final distance = (target - _dragOffset).abs();
    const snapRange = 58.0;
    if (distance >= snapRange) {
      return _dragOffset;
    }

    final t = Curves.easeOut.transform(1 - (distance / snapRange));
    return lerpDouble(_dragOffset, target, 0.2 + (t * 0.5)) ?? _dragOffset;
  }

  TimelineClipData? _resolveActiveReorderClip() {
    final tracksSnapshot = _reorderTracksSnapshot;
    final trackIndex = _reorderTrackIndex;
    final draggedClipId = _draggedClipId;
    if (tracksSnapshot == null ||
        trackIndex == null ||
        draggedClipId == null ||
        trackIndex < 0 ||
        trackIndex >= tracksSnapshot.length) {
      return null;
    }
    for (final clip in tracksSnapshot[trackIndex].clips) {
      if (clip.id == draggedClipId) {
        return clip;
      }
    }
    return null;
  }

  void _updateActiveReorderFromGlobalDx(double globalDx) {
    final originGlobalDx = _reorderPointerOriginGlobalDx;
    final trackIndex = _reorderTrackIndex;
    final draggedClip = _resolveActiveReorderClip();
    if (originGlobalDx == null || trackIndex == null || draggedClip == null) {
      return;
    }
    _updateClipReorder(trackIndex, draggedClip, globalDx - originGlobalDx);
  }

  void _beginClipReorder(int trackIndex, TimelineClipData clip) {
    if (_isTrimDragging ||
        widget.trimSelection != null ||
        _isAnyTimelineScrubbing ||
        _isScaleGestureActive ||
        widget.onClipReorder == null ||
        widget.tracks[trackIndex].clips.length < 2) {
      return;
    }
    if (!_acquireInteractionOwner(_TimelineInteractionOwner.reorder)) {
      return;
    }
    _captureLockedVerticalOffset();
    _restoreLockedVerticalOffset();

    _reorderExitTimer?.cancel();
    final snapshotTracks = _cloneTracks(widget.tracks);
    final snapshotTrack = snapshotTracks[trackIndex];
    final originIndex =
        snapshotTrack.clips.indexWhere((candidate) => candidate.id == clip.id);
    if (originIndex < 0) {
      _cancelInteractionOwner(
        _TimelineInteractionOwner.reorder,
        syncAfterCancel: false,
      );
      return;
    }

    final cardWidth = _compactClipWidth(clip);
    final reorderPointerId =
        _activePointers.length == 1 ? _activePointers.first : null;
    final reorderPointerOriginGlobalDx = reorderPointerId == null
        ? null
        : _activePointerPositions[reorderPointerId]?.dx;
    final layout = _buildReorderRowLayout(
      snapshotTrack,
      draggedClipId: clip.id,
      hoverInsertionIndex: originIndex,
    );
    final initialOffset = layout.slotCenters[originIndex];
    _handleOwnedClipSelected(clip.id);
    setState(() {
      _reorderTracksSnapshot = snapshotTracks;
      _reorderTrackIndex = trackIndex;
      _draggedClipId = clip.id;
      _hoverInsertionIndex = originIndex;
      _dragCardWidth = cardWidth;
      _dragStartOffset = initialOffset;
      _dragOffset = initialOffset;
      _reorderPointerId = reorderPointerId;
      _reorderPointerOriginGlobalDx = reorderPointerOriginGlobalDx;
      _isDropSettling = false;
    });
    _reorderTransitionController
      ..stop()
      ..value = 0
      ..forward();
    _ensurePlaybackTickerForCurrentMode();
  }

  void _updateClipReorder(
      int trackIndex, TimelineClipData clip, double deltaDx) {
    if (!_isReorderMode ||
        _isDropSettling ||
        _reorderTrackIndex != trackIndex ||
        _draggedClipId != clip.id) {
      return;
    }
    _activateInteractionOwner(_TimelineInteractionOwner.reorder);

    final tracksSnapshot = _reorderTracksSnapshot;
    if (tracksSnapshot == null) {
      return;
    }
    final layout = _buildReorderRowLayout(
      tracksSnapshot[trackIndex],
      draggedClipId: clip.id,
      hoverInsertionIndex: _hoverInsertionIndex,
    );
    final minOffset = layout.slotCenters.first;
    final maxOffset = layout.slotCenters.last;
    final nextOffset =
        (_dragStartOffset + deltaDx).clamp(minOffset, maxOffset).toDouble();
    final nextInsertionIndex =
        _resolveHoverInsertionIndex(layout.slotCenters, nextOffset);

    setState(() {
      _dragOffset = nextOffset;
      _hoverInsertionIndex = nextInsertionIndex;
    });
  }

  void _finishClipReorder(int trackIndex, TimelineClipData clip) {
    if (!_isReorderMode ||
        _isDropSettling ||
        _reorderTrackIndex != trackIndex ||
        _draggedClipId != clip.id) {
      return;
    }
    if (_isInteractionPending(_TimelineInteractionOwner.reorder)) {
      _cancelInteractionOwner(_TimelineInteractionOwner.reorder);
      return;
    }

    final tracksSnapshot = _reorderTracksSnapshot;
    if (tracksSnapshot == null) {
      _cancelInteractionOwner(_TimelineInteractionOwner.reorder);
      return;
    }

    final originIndex = tracksSnapshot[trackIndex]
        .clips
        .indexWhere((candidate) => candidate.id == clip.id);
    final insertionIndex = (_hoverInsertionIndex ?? originIndex)
        .clamp(0, tracksSnapshot[trackIndex].clips.length - 1);
    final settledLayout = _buildReorderRowLayout(
      tracksSnapshot[trackIndex],
      draggedClipId: clip.id,
      hoverInsertionIndex: insertionIndex,
    );

    setState(() {
      _hoverInsertionIndex = insertionIndex;
      _dragOffset = settledLayout.slotCenters[insertionIndex];
      _isDropSettling = true;
    });

    if (originIndex != insertionIndex) {
      widget.onClipReorder?.call(clip.id, insertionIndex);
    }

    _reorderExitTimer?.cancel();
    _reorderExitTimer = Timer(_reorderExitDelay, _clearReorderMode);
  }

  void _clearReorderMode({bool syncToTime = true}) {
    if (!_isReorderMode && !_isDropSettling) {
      _releaseInteractionOwner(_TimelineInteractionOwner.reorder);
      _releaseLockedVerticalOffsetIfPossible();
      return;
    }
    _reorderExitTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _reorderTracksSnapshot = null;
      _reorderTrackIndex = null;
      _draggedClipId = null;
      _hoverInsertionIndex = null;
      _dragOffset = 0;
      _dragStartOffset = 0;
      _dragCardWidth = 0;
      _reorderPointerId = null;
      _reorderPointerOriginGlobalDx = null;
      _isDropSettling = false;
    });
    _reorderTransitionController
      ..stop()
      ..value = 0;
    _releaseInteractionOwner(_TimelineInteractionOwner.reorder);
    _releaseLockedVerticalOffsetIfPossible();
    _ensurePlaybackTickerForCurrentMode();
    if (syncToTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncToTime());
    }
  }

  void _beginClipTimeShift(int trackIndex, TimelineClipData clip) {
    final track = widget.tracks[trackIndex];
    if (widget.isPlaying ||
        _isTrimDragging ||
        widget.trimSelection != null ||
        _isAnyTimelineScrubbing ||
        _isScaleGestureActive ||
        !_supportsClipTimeShift(track, clip)) {
      return;
    }
    if (!_acquireInteractionOwner(_TimelineInteractionOwner.move)) {
      return;
    }
    final originalStartTime = _timelineStartTimeForClip(track, clip.id);
    if (originalStartTime == null) {
      _cancelInteractionOwner(
        _TimelineInteractionOwner.move,
        syncAfterCancel: false,
      );
      return;
    }
    _captureLockedVerticalOffset();
    _restoreLockedVerticalOffset();
    _handleOwnedClipSelected(clip.id);
    setState(() {
      _clipMoveSession = _TimelineClipMoveSession(
        trackIndex: trackIndex,
        clipId: clip.id,
        originalStartTime: originalStartTime,
        currentStartTime: originalStartTime,
        durationTime: clip.durationTime,
      );
    });
    _ensurePlaybackTickerForCurrentMode();
  }

  void _updateClipTimeShift(
      int trackIndex, TimelineClipData clip, double deltaDx) {
    final session = _clipMoveSession;
    if (session == null ||
        session.trackIndex != trackIndex ||
        session.clipId != clip.id) {
      return;
    }
    _activateInteractionOwner(_TimelineInteractionOwner.move);
    final candidateStartTime = session.originalStartTime +
        TimelineTime.fromSecondsDouble(deltaDx / _secondsWidth);
    final resolvedStartTime = _resolveNearestAllowedClipStartTime(
      track: widget.tracks[trackIndex],
      clip: clip,
      candidateStartTime: candidateStartTime,
    );
    if (resolvedStartTime == session.currentStartTime) {
      return;
    }
    setState(() {
      _clipMoveSession = session.copyWith(currentStartTime: resolvedStartTime);
    });
  }

  void _finishClipTimeShift(int trackIndex, TimelineClipData clip) {
    final session = _clipMoveSession;
    if (session == null ||
        session.trackIndex != trackIndex ||
        session.clipId != clip.id) {
      return;
    }
    if (_isInteractionPending(_TimelineInteractionOwner.move)) {
      _clearClipMoveMode(syncToTime: false);
      return;
    }
    final resolvedStartTime = session.currentStartTime;
    final didChange = resolvedStartTime != session.originalStartTime;
    if (didChange) {
      widget.onClipTimeShift?.call(clip.id, resolvedStartTime);
    }
    _clearClipMoveMode(syncToTime: false);
  }

  void _clearClipMoveMode({bool syncToTime = true}) {
    if (_clipMoveSession == null) {
      _releaseInteractionOwner(_TimelineInteractionOwner.move);
      _releaseLockedVerticalOffsetIfPossible();
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _clipMoveSession = null;
    });
    _releaseInteractionOwner(_TimelineInteractionOwner.move);
    _releaseLockedVerticalOffsetIfPossible();
    _ensurePlaybackTickerForCurrentMode();
    if (syncToTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncToTime());
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      if (_blocksVerticalTrackNavigation) {
        _restoreLockedVerticalOffset();
        return true;
      }
      return false;
    }
    return _ignoreProgrammaticHorizontalScroll || _isSyncingFromExternal;
  }

  String _formatClock(double value) {
    final totalMillis = (value.clamp(0, 359999.999) * 1000).round();
    final wholeSeconds = totalMillis ~/ 1000;
    final mins = wholeSeconds ~/ 60;
    final secs = wholeSeconds % 60;
    final millis = (totalMillis % 1000).toString().padLeft(3, '0');
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.$millis';
  }

  String _formatWholeSeconds(double value) {
    final totalSeconds = value.round().clamp(0, 359999);
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _beginTrimDrag(TimelineTrimEdge edge) {
    final selection = widget.trimSelection;
    if (selection == null || widget.isPlaying || _isReorderMode) {
      return;
    }
    _cancelNativeScrub(finalize: true);
    _beginTrimInteractionLock();
    _activateInteractionOwner(_TimelineInteractionOwner.trim);
    setState(() {
      _trimDragSession = _resolveTrimDragSession(
        selection: selection,
        edge: edge,
        dragDx: 0,
      );
    });
    _emitTrimPreviewChanged(_trimDragSession);
    _setScrubInteractionActive(true);
    _ensurePlaybackTickerForCurrentMode();
  }

  void _updateTrimDrag(double dragDeltaDx) {
    final session = _trimDragSession;
    if (session == null) {
      return;
    }
    _restoreLockedVerticalOffset();
    final nextDragDx = session.dragDx + dragDeltaDx;
    setState(() {
      _trimDragSession = _resolveTrimDragSession(
        selection: session.selection,
        edge: session.edge,
        dragDx: nextDragDx,
      );
    });
    _emitTrimPreviewChanged(_trimDragSession);
  }

  void _endTrimDrag({bool cancel = false}) {
    final session = _trimDragSession;
    if (session == null) {
      return;
    }
    _restoreLockedVerticalOffset();
    if (!cancel) {
      widget.onTrimCommit?.call(
        TimelineTrimCommitRequest(
          clipId: session.selection.clipId,
          edge: session.edge,
          sourceStartTime: session.sourceStartTime,
          durationTime: session.durationTime,
        ),
      );
    }
    setState(() {
      _trimDragSession = null;
      _isTrimInteractionLocked = false;
    });
    _releaseLockedVerticalOffsetIfPossible();
    _releaseInteractionOwner(_TimelineInteractionOwner.trim);
    _syncScrubInteractionActive();
    _ensurePlaybackTickerForCurrentMode();
    widget.onTrimPreviewChanged?.call(null);
  }

  void _emitTrimPreviewChanged(_TimelineTrimDragSession? session) {
    final selection = session?.selection;
    if (selection == null || session == null) {
      widget.onTrimPreviewChanged?.call(null);
      return;
    }
    final frameDuration =
        TimelineTime.fromSecondsDouble(1 / widget.timelineFps);
    final timelinePreviewTime = switch (session.edge) {
      TimelineTrimEdge.start =>
        (selection.clipEndTime - session.durationTime).clamp(
          TimelineTime.zero,
          widget.timelineDurationTime,
        ),
      TimelineTrimEdge.end =>
        (selection.clipStartTime + session.durationTime).clamp(
          TimelineTime.zero,
          widget.timelineDurationTime,
        ),
    };
    final rawSourcePreviewTime = switch (session.edge) {
      TimelineTrimEdge.start => session.sourceStartTime,
      TimelineTrimEdge.end =>
        session.sourceStartTime + session.sourceDurationTime - frameDuration,
    };
    final sourcePreviewTime = rawSourcePreviewTime < TimelineTime.zero
        ? TimelineTime.zero
        : rawSourcePreviewTime;
    widget.onTrimPreviewChanged?.call(
      TimelineTrimPreviewRequest(
        clipId: selection.clipId,
        edge: session.edge,
        sourceStartTime: session.sourceStartTime,
        durationTime: session.durationTime,
        timelinePreviewTime: timelinePreviewTime,
        sourcePreviewTime: sourcePreviewTime,
      ),
    );
  }

  _TimelineTrimDragSession _resolveTrimDragSession({
    required TimelineTrimSelection selection,
    required TimelineTrimEdge edge,
    required double dragDx,
  }) {
    final deltaTime = TimelineTime.fromSecondsDouble(dragDx / _secondsWidth);
    final playbackRate =
        selection.playbackRate <= 0 ? 1.0 : selection.playbackRate;
    TimelineTime sourceDurationForTimelineDuration(
        TimelineTime timelineDuration) {
      return TimelineTime.fromSecondsDouble(
        timelineDuration.inSecondsDouble * playbackRate,
      );
    }

    TimelineTime timelineDurationForSourceDuration(
        TimelineTime sourceDuration) {
      return TimelineTime.fromSecondsDouble(
        sourceDuration.inSecondsDouble / playbackRate,
      );
    }

    final minSourceDurationTime =
        sourceDurationForTimelineDuration(selection.minDurationTime);
    final playheadBarrierTime = selection.playheadBarrierTime;
    final barrierOffsetTime = playheadBarrierTime == null
        ? null
        : (playheadBarrierTime - selection.clipStartTime).clamp(
            TimelineTime.zero,
            selection.durationTime,
          );
    final barrierOffsetSourceTime = barrierOffsetTime == null
        ? null
        : sourceDurationForTimelineDuration(barrierOffsetTime).clamp(
            TimelineTime.zero,
            selection.sourceDurationTime,
          );
    if (edge == TimelineTrimEdge.end) {
      final maxSourceDurationTime = selection.assetDurationTime == null
          ? selection.sourceDurationTime
          : selection.assetDurationTime! - selection.sourceStartTime;
      final resolvedMaxSourceDuration =
          maxSourceDurationTime < minSourceDurationTime
              ? minSourceDurationTime
              : maxSourceDurationTime;
      final minBarrierSourceDuration = barrierOffsetSourceTime == null ||
              barrierOffsetSourceTime < minSourceDurationTime
          ? minSourceDurationTime
          : barrierOffsetSourceTime;
      final requestedSourceDurationTime =
          sourceDurationForTimelineDuration(selection.durationTime + deltaTime);
      final nextSourceDurationTime = requestedSourceDurationTime.clamp(
        minBarrierSourceDuration,
        resolvedMaxSourceDuration,
      );
      final nextDurationTime =
          timelineDurationForSourceDuration(nextSourceDurationTime);
      return _TimelineTrimDragSession(
        selection: selection,
        edge: edge,
        dragDx: dragDx,
        sourceStartTime: selection.sourceStartTime,
        sourceDurationTime: nextSourceDurationTime,
        durationTime: nextDurationTime,
      );
    }

    final maxSourceStartTime = selection.sourceEndTime - minSourceDurationTime;
    final barrierMaxSourceStartTime = barrierOffsetTime == null
        ? maxSourceStartTime
        : selection.sourceStartTime + barrierOffsetSourceTime!;
    final requestedSourceStartTime = selection.sourceStartTime +
        sourceDurationForTimelineDuration(deltaTime);
    final nextSourceStartTime = requestedSourceStartTime.clamp(
      TimelineTime.zero,
      barrierMaxSourceStartTime < TimelineTime.zero
          ? TimelineTime.zero
          : barrierMaxSourceStartTime,
    );
    final nextSourceDurationTime =
        selection.sourceEndTime - nextSourceStartTime;
    final nextDurationTime =
        timelineDurationForSourceDuration(nextSourceDurationTime);
    return _TimelineTrimDragSession(
      selection: selection,
      edge: edge,
      dragDx: dragDx,
      sourceStartTime: nextSourceStartTime,
      sourceDurationTime: nextSourceDurationTime,
      durationTime: nextDurationTime,
    );
  }

  double _buildContentWidth(
    double trailingPadding, {
    double? secondsWidth,
  }) {
    final resolvedSecondsWidth = secondsWidth ?? _secondsWidth;
    final farthest = widget.tracks.fold<double>(
      0,
      (maxWidth, track) {
        var clipsWidth = 0.0;
        for (var i = 0; i < track.clips.length; i++) {
          final clip = track.clips[i];
          clipsWidth += clip.visualWidth(resolvedSecondsWidth);
          if (i == track.clips.length - 1) {
            continue;
          }
          final next = track.clips[i + 1];
          final isSplitSibling = clip.splitGroupId != null &&
              clip.splitGroupId == next.splitGroupId;
          final isJoinedTimelineMediaPair =
              track.kind == TimelineTrackKind.video &&
                  clip.type == TimelineClipType.media &&
                  next.type == TimelineClipType.media;
          clipsWidth += isSplitSibling
              ? _splitGap
              : (isJoinedTimelineMediaPair ? _joinedMediaGap : _controlGap);
        }
        return math.max(maxWidth, clipsWidth);
      },
    );

    return _leadingOffset +
        math.max(
            _controlTileSize, _TimelineTrackLaneProfile.video.controlHitSize) +
        _controlGap +
        farthest +
        trailingPadding;
  }

  double _buildReorderContentWidth() {
    final tracks = _reorderTracksSnapshot ?? widget.tracks;
    var maxWidth = _leadingOffset +
        math.max(
            _controlTileSize, _TimelineTrackLaneProfile.video.controlHitSize) +
        _controlGap +
        _reorderTrailingPadding;
    for (var index = 0; index < tracks.length; index++) {
      final layout = _buildReorderRowLayout(
        tracks[index],
        draggedClipId: index == _reorderTrackIndex ? _draggedClipId : null,
        hoverInsertionIndex:
            index == _reorderTrackIndex ? _hoverInsertionIndex : null,
      );
      maxWidth = math.max(maxWidth, layout.rowWidth);
    }
    return maxWidth;
  }

  double _resolvedReorderTransitionProgress() {
    if (!_isReorderMode) {
      return 0;
    }
    return Curves.easeOutCubic.transform(
      _reorderTransitionController.value.clamp(0.0, 1.0),
    );
  }

  double _resolvedBaseTimelineOpacity() {
    if (!_isReorderMode) {
      return 1;
    }
    return (1 - _resolvedReorderTransitionProgress()).clamp(0.0, 1.0);
  }

  double _trackTopForIndex(List<TimelineTrackData> tracks, int trackIndex) {
    final densityProfile = _stackDensityProfileForTracks(tracks);
    var top = 0.0;
    for (var index = 0; index < trackIndex; index++) {
      top += _rowHeightForTrack(tracks[index]);
      top += densityProfile.rowGap;
    }
    return top;
  }

  Widget _buildReorderOverlay({
    required double viewportWidth,
    required double viewportHeight,
  }) {
    return AnimatedBuilder(
      animation: _reorderTransitionController,
      builder: (context, child) {
        final tracks = _reorderTracksSnapshot ?? widget.tracks;
        final activeTrackIndex = _reorderTrackIndex;
        final draggedClipId = _draggedClipId;
        final contentWidth = _buildReorderContentWidth();
        final contentHeight = _tracksContentHeight(tracks);
        final maxHorizontalOffset = math.max(0.0, contentWidth - viewportWidth);
        final maxVerticalOffset = math.max(0.0, contentHeight - viewportHeight);
        final horizontalOffset = _scrollController.hasClients
            ? _scrollController.offset
                .clamp(0.0, maxHorizontalOffset)
                .toDouble()
            : 0.0;
        final verticalOffset = _verticalController.hasClients
            ? _verticalController.offset
                .clamp(0.0, maxVerticalOffset)
                .toDouble()
            : 0.0;
        final activeLayout = activeTrackIndex == null
            ? null
            : _buildReorderRowLayout(
                tracks[activeTrackIndex],
                draggedClipId: draggedClipId,
                hoverInsertionIndex: _hoverInsertionIndex,
              );
        final activeExpandedLayout = activeTrackIndex == null
            ? null
            : _buildExpandedTrackRowLayout(tracks[activeTrackIndex]);
        final draggedCenter = activeLayout == null
            ? _dragOffset
            : _magnetizedDragOffset(activeLayout.slotCenters);
        final transitionProgress = _resolvedReorderTransitionProgress();
        if (activeTrackIndex == null || activeLayout == null) {
          return const SizedBox.shrink();
        }
        final activeTrackTop = _trackTopForIndex(tracks, activeTrackIndex);

        return IgnorePointer(
          child: Transform.translate(
            offset: Offset(-horizontalOffset, -verticalOffset),
            child: SizedBox(
              width: contentWidth,
              height: contentHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: activeTrackTop,
                    child: _TimelineReorderTrackRow(
                      leadingOffset: _leadingOffset,
                      controlTileSize: _controlTileSize,
                      controlGap: _controlGap,
                      rowHeight: _rowHeightForTrack(tracks[activeTrackIndex]),
                      cardHeight: _reorderCardHeight,
                      track: tracks[activeTrackIndex],
                      selectedClipId: widget.selectedClipId,
                      draggedClipId: draggedClipId,
                      hoverInsertionIndex: _hoverInsertionIndex,
                      layout: activeLayout,
                      entryLayout: activeExpandedLayout,
                      transitionProgress: transitionProgress,
                      draggedCenter: draggedCenter,
                      draggedWidth: _dragCardWidth,
                      isDropSettling: _isDropSettling,
                      assetPathResolver: widget.assetPathResolver,
                      showLaneBadge: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackDensityProfile = _stackDensityProfileForTracks(
          widget.tracks,
        );
        const headerTextStyle = TextStyle(
          color: Color(0xB8FFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1,
        );
        final headerTextTopInset = _headerTextTopInset(headerTextStyle);
        final contentViewportWidth = constraints.maxWidth - (_panelPadding * 2);
        _playheadLeft = contentViewportWidth / 2;
        _leadingOffset = math.max(
          6,
          _playheadLeft - _timelineControlColumnWidth - _controlGap,
        );
        final trailingPadding = math.max(
          _trailingPadding,
          contentViewportWidth - _playheadLeft + 24,
        );
        _activeTrailingPadding = trailingPadding;
        final contentWidth = _buildContentWidth(trailingPadding);
        final tracksViewportHeight = math.max(
          0.0,
          constraints.maxHeight - _rulerHeaderHeight - 8,
        );
        final tracksContentHeight = _tracksContentHeight(widget.tracks);

        return Container(
          padding: EdgeInsets.fromLTRB(
            _panelPadding,
            widget.embedded ? 2 : _panelPadding,
            _panelPadding,
            10,
          ),
          decoration: BoxDecoration(
            color: widget.embedded ? Colors.transparent : FxPalette.surface,
            borderRadius: BorderRadius.circular(widget.embedded ? 0 : 20),
            border: widget.embedded
                ? null
                : Border.all(color: FxPalette.divider, width: 1),
          ),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handleGlobalPointerDown,
            onPointerMove: _handleGlobalPointerMove,
            onPointerUp: (event) => _handleGlobalPointerEnd(event.pointer),
            onPointerCancel: (event) => _handleGlobalPointerEnd(event.pointer),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -_rulerVisualLift),
                      child: SizedBox(
                        height: _rulerHeaderHeight,
                        child: ListenableBuilder(
                          listenable: Listenable.merge(
                            <Listenable>[
                              _displayTimeNotifier,
                              _scrollController,
                            ],
                          ),
                          builder: (context, _) {
                            final displayOffsetSeconds =
                                widget.timeDisplayOffset.inSecondsDouble;
                            final readoutTotalSeconds =
                                (widget.timeReadoutTotalTime ??
                                        (widget.timeDisplayOffset +
                                            widget.timelineDurationTime))
                                    .inSecondsDouble;
                            final headerReadoutText =
                                '${_formatClock(_currentSeconds + displayOffsetSeconds)} / ${_formatWholeSeconds(readoutTotalSeconds)}';
                            final effectiveScrollOffset =
                                _effectiveHorizontalScrollOffset();
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _TimelineRulerPainter(
                                      readoutText: headerReadoutText,
                                      readoutWidth: _timeReadoutWidth,
                                      gapWidth: 6,
                                      scrollOffset: effectiveScrollOffset,
                                      playheadLeft: math.max(
                                          0,
                                          _playheadLeft -
                                              _timeReadoutWidth -
                                              6),
                                      viewportWidth: math.max(
                                        0,
                                        constraints.maxWidth -
                                            (_panelPadding * 2) -
                                            _timeReadoutWidth -
                                            6,
                                      ),
                                      secondsWidth: _secondsWidth,
                                      durationSeconds: _timelineDurationSeconds,
                                      timeDisplayOffsetSeconds:
                                          displayOffsetSeconds,
                                      fps: widget.timelineFps,
                                      mode: _rulerMode,
                                      labelTopInset: headerTextTopInset,
                                      labelTextStyle: headerTextStyle,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  width: _timeReadoutWidth + 6,
                                  top: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart:
                                        _handleManualPanDragStart,
                                    onHorizontalDragUpdate:
                                        _handleManualPanDragUpdate,
                                    onHorizontalDragEnd:
                                        _handleManualPanDragEnd,
                                    onHorizontalDragCancel:
                                        _handleManualPanDragCancel,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, scrollConstraints) {
                          _scrollViewportWidth = contentViewportWidth;
                          final canVerticallyScrollTracks =
                              tracksContentHeight >
                                  (scrollConstraints.maxHeight + 0.5);
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: _handleScrollNotification,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      scrollDirection: Axis.horizontal,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      child: AnimatedBuilder(
                                        animation: Listenable.merge(
                                          <Listenable>[
                                            _displayTimeNotifier,
                                            _reorderTransitionController,
                                          ],
                                        ),
                                        builder: (context, _) {
                                          final timelineContent = SizedBox(
                                            width: contentWidth,
                                            height: scrollConstraints.maxHeight,
                                            child: SingleChildScrollView(
                                              controller: _verticalController,
                                              physics: !canVerticallyScrollTracks ||
                                                      _blocksVerticalTrackNavigation
                                                  ? const NeverScrollableScrollPhysics()
                                                  : const BouncingScrollPhysics(),
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  minHeight: scrollConstraints
                                                      .maxHeight,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    for (var i = 0;
                                                        i <
                                                            widget
                                                                .tracks.length;
                                                        i++) ...[
                                                      Builder(
                                                        builder: (context) {
                                                          final track =
                                                              widget.tracks[i];
                                                          final moveSession =
                                                              _clipMoveSession;
                                                          final previewClipId =
                                                              moveSession?.trackIndex ==
                                                                      i
                                                                  ? moveSession
                                                                      ?.clipId
                                                                  : null;
                                                          final previewStartTime =
                                                              moveSession?.trackIndex ==
                                                                      i
                                                                  ? moveSession
                                                                      ?.currentStartTime
                                                                  : null;
                                                          return _TimelineTrackRow(
                                                            contentWidth:
                                                                contentWidth,
                                                            leadingOffset:
                                                                _leadingOffset,
                                                            controlTileSize:
                                                                _controlTileSize,
                                                            controlGap:
                                                                _controlGap,
                                                            splitGap: _splitGap,
                                                            rowHeight:
                                                                _rowHeightForTrack(
                                                              track,
                                                            ),
                                                            secondsWidth:
                                                                _secondsWidth,
                                                            track: track,
                                                            isPlaying: widget
                                                                .isPlaying,
                                                            selectedClipId: widget
                                                                .selectedClipId,
                                                            selectedTransitionId:
                                                                widget
                                                                    .selectedTransitionId,
                                                            selectedAnimationLaneId:
                                                                widget
                                                                    .selectedAnimationLaneId,
                                                            onClipSelected:
                                                                _handleOwnedClipSelected,
                                                            onClipDoubleTap:
                                                                widget.onClipDoubleTap ==
                                                                        null
                                                                    ? null
                                                                    : _handleOwnedClipDoubleTap,
                                                            onClipLongPressStart:
                                                                (clip) {
                                                              if (track.kind ==
                                                                  TimelineTrackKind
                                                                      .video) {
                                                                _beginClipReorder(
                                                                  i,
                                                                  clip,
                                                                );
                                                                return;
                                                              }
                                                              _beginClipTimeShift(
                                                                i,
                                                                clip,
                                                              );
                                                            },
                                                            onClipLongPressMove:
                                                                (clip,
                                                                    deltaDx) {
                                                              if (track.kind ==
                                                                  TimelineTrackKind
                                                                      .video) {
                                                                _updateClipReorder(
                                                                  i,
                                                                  clip,
                                                                  deltaDx,
                                                                );
                                                                return;
                                                              }
                                                              _updateClipTimeShift(
                                                                i,
                                                                clip,
                                                                deltaDx,
                                                              );
                                                            },
                                                            onClipLongPressEnd:
                                                                (clip) {
                                                              if (track.kind ==
                                                                  TimelineTrackKind
                                                                      .video) {
                                                                _finishClipReorder(
                                                                  i,
                                                                  clip,
                                                                );
                                                                return;
                                                              }
                                                              _finishClipTimeShift(
                                                                i,
                                                                clip,
                                                              );
                                                            },
                                                            onTrackAnimateTap:
                                                                widget
                                                                    .onTrackAnimateTap,
                                                            onAnimationLaneTap:
                                                                widget
                                                                    .onAnimationLaneTap,
                                                            onTransitionTap: widget
                                                                .onTransitionTap,
                                                            onBackgroundTap:
                                                                widget.onBackgroundTap ==
                                                                        null
                                                                    ? null
                                                                    : _handleOwnedBackgroundTap,
                                                            onManualPanDragStart:
                                                                _handleManualPanDragStart,
                                                            onManualPanDragUpdate:
                                                                _handleManualPanDragUpdate,
                                                            onManualPanDragEnd:
                                                                _handleManualPanDragEnd,
                                                            onManualPanDragCancel:
                                                                _handleManualPanDragCancel,
                                                            assetPathResolver:
                                                                widget
                                                                    .assetPathResolver,
                                                            trimSelection:
                                                                !_isReorderMode
                                                                    ? widget
                                                                        .trimSelection
                                                                    : null,
                                                            trimDragSession:
                                                                !_isReorderMode
                                                                    ? _trimDragSession
                                                                    : null,
                                                            onTrimDragStart:
                                                                _beginTrimDrag,
                                                            onTrimDragUpdate:
                                                                _updateTrimDrag,
                                                            onTrimDragEnd:
                                                                _endTrimDrag,
                                                            onTrimHandleEngagementChanged:
                                                                _handleTrimHandleEngagementChanged,
                                                            animateTrackKinds:
                                                                widget
                                                                    .animateTrackKinds,
                                                            timeShiftPreviewClipId:
                                                                previewClipId,
                                                            timeShiftPreviewStartTime:
                                                                previewStartTime,
                                                            baseClipOpacity:
                                                                _isReorderMode &&
                                                                        _reorderTrackIndex ==
                                                                            i
                                                                    ? _resolvedBaseTimelineOpacity()
                                                                    : 1,
                                                          );
                                                        },
                                                      ),
                                                      if (i !=
                                                          widget.tracks.length -
                                                              1)
                                                        SizedBox(
                                                          height:
                                                              stackDensityProfile
                                                                  .rowGap,
                                                        ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                          final translateX =
                                              _playbackVisualTranslateX();
                                          if (translateX == 0) {
                                            return timelineContent;
                                          }
                                          return Transform.translate(
                                            offset: Offset(translateX, 0),
                                            child: timelineContent,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_isReorderMode)
                                Positioned.fill(
                                  child: _buildReorderOverlay(
                                    viewportWidth: contentViewportWidth,
                                    viewportHeight: scrollConstraints.maxHeight,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (widget.scrubSurfaceBuilder != null && !_isReorderMode)
                  Positioned.fill(
                    child: _buildUnifiedNativeScrubOverlay(
                      viewportWidth: contentViewportWidth,
                      tracksViewportHeight: tracksViewportHeight,
                      contentWidth: contentWidth,
                      tracksContentHeight: tracksContentHeight,
                    ),
                  ),
                if (!_isReorderMode)
                  Positioned(
                    left: _playheadLeft - (_playheadLineWidth / 2),
                    top: 30,
                    bottom: 10,
                    child: IgnorePointer(
                      child: Container(
                        width: _playheadLineWidth,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.22),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimelineTrackRow extends StatelessWidget {
  const _TimelineTrackRow({
    required this.contentWidth,
    required this.leadingOffset,
    required this.controlTileSize,
    required this.controlGap,
    required this.splitGap,
    required this.rowHeight,
    required this.secondsWidth,
    required this.track,
    required this.isPlaying,
    required this.selectedClipId,
    required this.selectedTransitionId,
    required this.selectedAnimationLaneId,
    required this.onClipSelected,
    required this.onClipDoubleTap,
    required this.onClipLongPressStart,
    required this.onClipLongPressMove,
    required this.onClipLongPressEnd,
    required this.onTrackAnimateTap,
    required this.onAnimationLaneTap,
    required this.onTransitionTap,
    required this.onBackgroundTap,
    required this.onManualPanDragStart,
    required this.onManualPanDragUpdate,
    required this.onManualPanDragEnd,
    required this.onManualPanDragCancel,
    required this.assetPathResolver,
    required this.trimSelection,
    required this.trimDragSession,
    required this.onTrimDragStart,
    required this.onTrimDragUpdate,
    required this.onTrimDragEnd,
    required this.onTrimHandleEngagementChanged,
    required this.animateTrackKinds,
    this.timeShiftPreviewClipId,
    this.timeShiftPreviewStartTime,
    this.baseClipOpacity = 1,
  });

  final double contentWidth;
  final double leadingOffset;
  final double controlTileSize;
  final double controlGap;
  final double splitGap;
  final double rowHeight;
  final double secondsWidth;
  final TimelineTrackData track;
  final bool isPlaying;
  final String? selectedClipId;
  final String? selectedTransitionId;
  final String? selectedAnimationLaneId;
  final ValueChanged<String> onClipSelected;
  final ValueChanged<TimelineClipData>? onClipDoubleTap;
  final ValueChanged<TimelineClipData>? onClipLongPressStart;
  final void Function(TimelineClipData clip, double deltaDx)?
      onClipLongPressMove;
  final ValueChanged<TimelineClipData>? onClipLongPressEnd;
  final ValueChanged<TimelineTrackData>? onTrackAnimateTap;
  final ValueChanged<String>? onAnimationLaneTap;
  final TimelineBoundaryTransitionTapCallback? onTransitionTap;
  final VoidCallback? onBackgroundTap;
  final GestureDragStartCallback onManualPanDragStart;
  final GestureDragUpdateCallback onManualPanDragUpdate;
  final GestureDragEndCallback onManualPanDragEnd;
  final GestureDragCancelCallback onManualPanDragCancel;
  final TimelineAssetPathResolver? assetPathResolver;
  final TimelineTrimSelection? trimSelection;
  final _TimelineTrimDragSession? trimDragSession;
  final ValueChanged<TimelineTrimEdge> onTrimDragStart;
  final ValueChanged<double> onTrimDragUpdate;
  final VoidCallback onTrimDragEnd;
  final ValueChanged<bool> onTrimHandleEngagementChanged;
  final Set<TimelineTrackKind> animateTrackKinds;
  final String? timeShiftPreviewClipId;
  final TimelineTime? timeShiftPreviewStartTime;
  final double baseClipOpacity;

  IconData get _trackIcon {
    switch (track.kind) {
      case TimelineTrackKind.video:
        return Icons.videocam_rounded;
      case TimelineTrackKind.image:
        return Icons.image_rounded;
      case TimelineTrackKind.audio:
        return Icons.music_note_rounded;
      case TimelineTrackKind.text:
        return Icons.text_fields_rounded;
      case TimelineTrackKind.lipSync:
        return Icons.graphic_eq_rounded;
    }
  }

  IconData get _clipIcon {
    switch (track.kind) {
      case TimelineTrackKind.video:
        return Icons.videocam_rounded;
      case TimelineTrackKind.image:
        return Icons.image_rounded;
      case TimelineTrackKind.audio:
        return Icons.music_note_rounded;
      case TimelineTrackKind.text:
        return Icons.text_fields_rounded;
      case TimelineTrackKind.lipSync:
        return Icons.graphic_eq_rounded;
    }
  }

  _TimelineTrackLaneProfile get _laneProfile =>
      _TimelineTrackLaneProfile.forKind(track.kind);

  double get _controlHitSize =>
      math.max(controlTileSize, _laneProfile.controlHitSize);

  bool get _isActiveRow =>
      selectedClipId != null &&
      track.clips.any((clip) => clip.id == selectedClipId);

  bool get _showsAnimateButton =>
      onTrackAnimateTap != null &&
      animateTrackKinds.contains(track.kind) &&
      track.clips.any((clip) => clip.type == TimelineClipType.media);

  double get _animateButtonWidth => _showsAnimateButton ? 32 : 0;

  bool _isMainTrackMediaClip(TimelineClipData clip) =>
      track.kind == TimelineTrackKind.video &&
      clip.type == TimelineClipType.media &&
      clip.assetId != null;

  bool _shouldJoinWith(TimelineClipData left, TimelineClipData right) =>
      _isMainTrackMediaClip(left) && _isMainTrackMediaClip(right);

  double _gapAfterClip(TimelineClipData clip, TimelineClipData next) {
    if (_isGapPlaceholderClip(clip) || _isGapPlaceholderClip(next)) {
      return 0;
    }
    final isSplitSibling =
        clip.splitGroupId != null && clip.splitGroupId == next.splitGroupId;
    if (isSplitSibling) {
      return splitGap;
    }
    if (_shouldJoinWith(clip, next)) {
      return 0;
    }
    return controlGap;
  }

  bool _supportsTrimChrome(TimelineClipData clip) {
    final selection = trimSelection;
    if (selection == null) {
      return false;
    }
    return selection.clipId == clip.id &&
        selection.trackKind == track.kind &&
        track.kind == TimelineTrackKind.video &&
        clip.type == TimelineClipType.media;
  }

  bool _isGapPlaceholderClip(TimelineClipData clip) {
    if (clip.type != TimelineClipType.placeholder) {
      return false;
    }
    final label = clip.label;
    return label == null || label.trim().isEmpty;
  }

  _ResolvedTrimClipGeometry _resolveTrimClipGeometry({
    required TimelineClipData clip,
    required double originalLeft,
    required double originalWidth,
    required _TimelineTrimDragSession? trimSession,
  }) {
    if (trimSession == null) {
      return _ResolvedTrimClipGeometry(
        clip: clip,
        left: originalLeft,
        width: originalWidth,
        sourceStartTime: clip.sourceStartTime,
        durationTime: clip.durationTime,
      );
    }

    final previewWidth = math.max(
      1.0,
      trimSession.durationTime.inSecondsDouble * secondsWidth,
    );
    final previewLeft = trimSession.edge == TimelineTrimEdge.start
        ? originalLeft + (originalWidth - previewWidth)
        : originalLeft;
    return _ResolvedTrimClipGeometry(
      clip: clip,
      left: previewLeft,
      width: previewWidth,
      sourceStartTime: trimSession.sourceStartTime,
      durationTime: trimSession.durationTime,
      isPreviewing: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clipChildren = <Widget>[];
    final splitBridges = <Widget>[];
    final clipGeometryById = <String, _TimelineAnimationClipGeometry>{};
    final panZoneRight = leadingOffset + _controlHitSize + controlGap;
    final clipStart = panZoneRight;
    final mainRowHeight = _laneProfile.rowHeight;
    final clipTop = _laneProfile.clipTopInset;
    final clipHeight = _laneProfile.clipHeight;
    var cursor = clipStart;
    final controlLeft = leadingOffset - _animateButtonWidth;
    Widget? selectedTrimClipChild;
    Widget? selectedTrimChromeChild;
    for (var i = 0; i < track.clips.length; i++) {
      final clip = track.clips[i];
      final isGapPlaceholder = _isGapPlaceholderClip(clip);
      final isSelected = selectedClipId == clip.id;
      final previousClip = i > 0 ? track.clips[i - 1] : null;
      final nextClip = i < track.clips.length - 1 ? track.clips[i + 1] : null;
      final joinLeft =
          previousClip != null && _shouldJoinWith(previousClip, clip);
      final joinRight = nextClip != null && _shouldJoinWith(clip, nextClip);
      final assetPath =
          clip.assetId == null ? null : assetPathResolver?.call(clip.assetId!);
      final clipWidth = clip.visualWidth(secondsWidth);
      final showsTrimChrome = _supportsTrimChrome(clip);
      final activeTrimSession =
          trimDragSession?.selection.clipId == clip.id ? trimDragSession : null;
      final trimGeometry = _resolveTrimClipGeometry(
        clip: clip,
        originalLeft: cursor,
        originalWidth: clipWidth,
        trimSession: activeTrimSession,
      );
      final previewLeft =
          timeShiftPreviewClipId == clip.id && timeShiftPreviewStartTime != null
              ? clipStart +
                  (timeShiftPreviewStartTime!.inSecondsDouble * secondsWidth)
              : trimGeometry.left;
      final trimTouchInset =
          showsTrimChrome ? _TimelineTrimChrome.handleTouchInset : 0.0;
      if (!isGapPlaceholder && clip.type == TimelineClipType.media) {
        clipGeometryById[clip.id] = _TimelineAnimationClipGeometry(
          left: previewLeft,
          width: trimGeometry.width,
        );
      }
      final clipWidget = isGapPlaceholder
          ? null
          : clip.type == TimelineClipType.placeholder
              ? _TimelinePlaceholderClip(
                  width: clipWidth,
                  label: clip.label ?? track.placeholderLabel ?? 'Add',
                  isSelected: isSelected,
                  onTap: () => onClipSelected(clip.id),
                  onDoubleTap: track.kind == TimelineTrackKind.text &&
                          onClipDoubleTap != null
                      ? () => onClipDoubleTap!(clip)
                      : null,
                  onLongPressStart: onClipLongPressStart == null
                      ? null
                      : () => onClipLongPressStart!(clip),
                  onLongPressMoveUpdate: onClipLongPressMove == null
                      ? null
                      : (details) => onClipLongPressMove!(
                            clip,
                            details.offsetFromOrigin.dx,
                          ),
                  onLongPressEnd: onClipLongPressEnd == null
                      ? null
                      : () => onClipLongPressEnd!(clip),
                )
              : _TimelineMediaClip(
                  width: trimGeometry.width,
                  tone: clip.tone,
                  icon: _clipIcon,
                  trackKind: track.kind,
                  isPlaying: isPlaying,
                  assetPath: assetPath,
                  sourceOffsetSeconds:
                      trimGeometry.sourceStartTime.inSecondsDouble,
                  durationSeconds: trimGeometry.durationTime.inSecondsDouble,
                  playbackRate: clip.playbackRate,
                  speedMode: clip.speedMode,
                  isSelected: isSelected,
                  usesTrimChrome: showsTrimChrome,
                  joinLeft: joinLeft,
                  joinRight: joinRight,
                  onTap: () => onClipSelected(clip.id),
                  onDoubleTap: track.kind == TimelineTrackKind.text &&
                          onClipDoubleTap != null
                      ? () => onClipDoubleTap!(clip)
                      : null,
                  height: clipHeight,
                  onLongPressStart:
                      showsTrimChrome || onClipLongPressStart == null
                          ? null
                          : () => onClipLongPressStart!(clip),
                  onLongPressMoveUpdate:
                      showsTrimChrome || onClipLongPressMove == null
                          ? null
                          : (details) => onClipLongPressMove!(
                                clip,
                                details.offsetFromOrigin.dx,
                              ),
                  onLongPressEnd: showsTrimChrome || onClipLongPressEnd == null
                      ? null
                      : () => onClipLongPressEnd!(clip),
                );
      final clipChild = clipWidget == null
          ? null
          : Positioned(
              key: ValueKey<String>(clip.id),
              left: previewLeft,
              top: clipTop,
              child: clipWidget,
            );
      if (clipChild != null && showsTrimChrome) {
        selectedTrimClipChild = clipChild;
        selectedTrimChromeChild = Positioned(
          key: ValueKey<String>('trim-chrome-${clip.id}'),
          left: trimGeometry.left - trimTouchInset,
          top: clipTop,
          child: SizedBox(
            width: trimGeometry.width + (trimTouchInset * 2),
            height: clipHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: trimTouchInset,
                  top: 0,
                  width: trimGeometry.width,
                  height: clipHeight,
                  child: _TimelineTrimChrome(
                    width: trimGeometry.width,
                    height: clipHeight,
                    isPlaying: isPlaying,
                    isPreviewing: trimGeometry.isPreviewing,
                    activeEdge: activeTrimSession?.edge,
                    onTrimDragStart: onTrimDragStart,
                    onTrimDragUpdate: onTrimDragUpdate,
                    onTrimDragEnd: onTrimDragEnd,
                    onTrimHandleEngagementChanged:
                        onTrimHandleEngagementChanged,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (clipChild != null) {
        clipChildren.add(clipChild);
      }

      if (i != track.clips.length - 1) {
        final next = track.clips[i + 1];
        final showBridge =
            clip.splitGroupId != null && clip.splitGroupId == next.splitGroupId;
        final showCutSeam = !showBridge && _shouldJoinWith(clip, next);
        final boundaryTransition =
            track.transitionForBoundary(clip.id, next.id);
        final showInteractiveTransitionBridge =
            track.kind == TimelineTrackKind.video &&
                showCutSeam &&
                onTransitionTap != null;
        final gapAfterClip = _gapAfterClip(clip, next);

        if (showBridge) {
          const splitBridgeWidth = 6.0;
          splitBridges.add(
            Positioned(
              left:
                  cursor + clipWidth + ((gapAfterClip - splitBridgeWidth) / 2),
              top: clipTop + 2,
              bottom: 2,
              child: const IgnorePointer(
                child: SizedBox(
                  width: splitBridgeWidth,
                  child: _TransitionBridge(),
                ),
              ),
            ),
          );
        } else if (showInteractiveTransitionBridge) {
          splitBridges.add(
            Positioned(
              left: cursor + clipWidth - 14,
              top: clipTop + ((clipHeight - 22) / 2),
              width: 28,
              height: 22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => onTransitionTap?.call(track, clip, next),
                child: _TransitionBridge(
                  hasAttachedTransition: boundaryTransition != null,
                  isActive: selectedTransitionId == boundaryTransition?.id,
                ),
              ),
            ),
          );
        } else if (showCutSeam) {
          splitBridges.add(
            Positioned(
              left: cursor + clipWidth - 2,
              top: 4,
              bottom: 4,
              child: const IgnorePointer(
                child: _TimelineCutSeam(),
              ),
            ),
          );
        }
        cursor += clipWidth + gapAfterClip;
      } else {
        cursor += clipWidth;
      }
    }

    final rowWidth = math.max(
      cursor + controlGap,
      clipStart + 12,
    );
    final interactiveWidth = math.max(rowWidth, contentWidth);
    final animationLaneChildren = <Widget>[];
    final trackSpanWidth = math.max(1.0, cursor - clipStart);
    final visibleAnimationLanes = track.animationLanes
        .where(
          (lane) =>
              clipGeometryById.containsKey(lane.targetClipId) ||
              (lane.trackSpanStartProgress != null &&
                  lane.trackSpanEndProgress != null),
        )
        .toList(growable: false);
    for (var index = 0; index < visibleAnimationLanes.length; index++) {
      final lane = visibleAnimationLanes[index];
      final geometry = switch ((
        lane.trackSpanStartProgress,
        lane.trackSpanEndProgress,
      )) {
        (final start?, final end?) => _TimelineAnimationClipGeometry(
            left: clipStart + (trackSpanWidth * start.clamp(0.0, 1.0)),
            width: math.max(
              1.0,
              trackSpanWidth * (end.clamp(0.0, 1.0) - start.clamp(0.0, 1.0)),
            ),
          ),
        _ => clipGeometryById[lane.targetClipId],
      };
      if (geometry == null) {
        continue;
      }
      final top = mainRowHeight +
          _TimelineAnimationLaneMetrics.sectionTopSpacing +
          (index *
              (_TimelineAnimationLaneMetrics.rowHeight +
                  _TimelineAnimationLaneMetrics.rowGap));
      animationLaneChildren.add(
        Positioned(
          left: controlLeft,
          top: top,
          child: SizedBox(
            width: interactiveWidth - controlLeft,
            height: _TimelineAnimationLaneMetrics.rowHeight,
            child: _TimelineAnimationLaneRow(
              label: lane.label,
              clipLeft: geometry.left - controlLeft,
              clipWidth: geometry.width,
              keyframeStops: lane.normalizedKeyframeStops,
              isSelected: selectedAnimationLaneId == lane.id ||
                  (selectedAnimationLaneId == null &&
                      selectedClipId == lane.targetClipId),
              onTap: () {
                if (onAnimationLaneTap != null) {
                  onAnimationLaneTap!(lane.id);
                  return;
                }
                onClipSelected(lane.targetClipId);
              },
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: interactiveWidth,
      height: rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _TimelineTrackLaneUnderlay(
                accentColor: _laneProfile.accentColor,
                leadingOffset: leadingOffset,
                controlColumnWidth: panZoneRight - leadingOffset,
                rowHeight: mainRowHeight,
                clipTopInset: clipTop,
                clipHeight: clipHeight,
                isReorder: false,
                isActive: _isActiveRow,
                showRail: baseClipOpacity >= 0.999,
              ),
            ),
          ),
          Positioned(
            left: controlLeft,
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBackgroundTap,
              onHorizontalDragStart: onManualPanDragStart,
              onHorizontalDragUpdate: onManualPanDragUpdate,
              onHorizontalDragEnd: onManualPanDragEnd,
              onHorizontalDragCancel: onManualPanDragCancel,
              child: SizedBox(
                width: panZoneRight - controlLeft,
                height: mainRowHeight,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (_showsAnimateButton)
                        Positioned(
                          left: 0,
                          top: _laneProfile.headerTopInset + 5,
                          child: _TimelineAnimateButton(
                            onTap: () => onTrackAnimateTap?.call(track),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: _animateButtonWidth,
                          top: _laneProfile.headerTopInset,
                        ),
                        child: _TimelineTrackLaneBadge(
                          size: controlTileSize,
                          icon: _trackIcon,
                          label: _laneProfile.shortLabel,
                          accentColor: _laneProfile.accentColor,
                          isReorder: false,
                          isEmphasized: _isActiveRow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: baseClipOpacity.clamp(0.0, 1.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...clipChildren,
                  ...splitBridges,
                  ...animationLaneChildren,
                  if (selectedTrimClipChild != null) selectedTrimClipChild,
                  if (selectedTrimChromeChild != null) selectedTrimChromeChild,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineAnimateButton extends StatelessWidget {
  const _TimelineAnimateButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.055),
            border: Border.all(
              color: Colors.white.withOpacity(0.11),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 16,
              color: Colors.white.withOpacity(0.76),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineAnimationLaneRow extends StatelessWidget {
  const _TimelineAnimationLaneRow({
    required this.label,
    required this.clipLeft,
    required this.clipWidth,
    required this.keyframeStops,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final double clipLeft;
  final double clipWidth;
  final List<double> keyframeStops;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const labelLeft = -24.0;
    final resolvedLabelWidth = math.max(
      82.0,
      math.min(124.0, clipLeft - 8 - labelLeft),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: labelLeft,
            top: 2,
            child: _TimelineAnimationLabelChip(
              label: label,
              isSelected: isSelected,
              width: resolvedLabelWidth,
            ),
          ),
          Positioned(
            left: clipLeft,
            top: 3,
            child: _TimelineAnimationSegment(
              width: clipWidth,
              keyframeStops: keyframeStops,
              isSelected: isSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineAnimationLabelChip extends StatelessWidget {
  const _TimelineAnimationLabelChip({
    required this.label,
    required this.isSelected,
    required this.width,
  });

  final String label;
  final bool isSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: 24,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(isSelected ? 0.1 : 0.05),
                Colors.white.withOpacity(isSelected ? 0.055 : 0.026),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(isSelected ? 0.22 : 0.11),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isSelected ? 0.22 : 0.12),
                blurRadius: isSelected ? 16 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(isSelected ? 0.97 : 0.78),
                    fontSize: 9.7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.02,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineAnimationSegment extends StatelessWidget {
  const _TimelineAnimationSegment({
    required this.width,
    required this.keyframeStops,
    required this.isSelected,
  });

  final double width;
  final List<double> keyframeStops;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = math.max(30.0, width);
    final resolvedStops = keyframeStops.isEmpty
        ? const <double>[0.0, 1.0]
        : keyframeStops
            .map((stop) => stop.clamp(0.0, 1.0))
            .toList(growable: false);
    return RepaintBoundary(
      child: Container(
        width: resolvedWidth,
        height: 24,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(isSelected ? 0.065 : 0.038),
              Colors.white.withOpacity(isSelected ? 0.032 : 0.016),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(isSelected ? 0.24 : 0.14),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: FxPalette.accent.withOpacity(isSelected ? 0.1 : 0.045),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 10,
              right: 10,
              top: 11,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(isSelected ? 0.34 : 0.24),
                      Colors.white.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            for (var index = 0; index < resolvedStops.length; index++)
              Positioned(
                left: (resolvedWidth - 12) * resolvedStops[index],
                top: 6,
                child: _TimelineAnimationKeyframeMarker(
                  isPrimary: index == 0 || index == resolvedStops.length - 1,
                  isSelected: isSelected,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineAnimationKeyframeMarker extends StatelessWidget {
  const _TimelineAnimationKeyframeMarker({
    required this.isPrimary,
    required this.isSelected,
  });

  final bool isPrimary;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final fillColor = isPrimary
        ? FxPalette.accent.withOpacity(isSelected ? 0.96 : 0.82)
        : Colors.white.withOpacity(isSelected ? 0.82 : 0.62);
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: isPrimary ? 10 : 8,
        height: isPrimary ? 10 : 8,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(2.5),
          border: Border.all(
            color: Colors.white.withOpacity(isSelected ? 0.46 : 0.28),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: fillColor.withOpacity(isPrimary ? 0.22 : 0.12),
              blurRadius: isPrimary ? 6 : 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTrackLaneBadge extends StatelessWidget {
  const _TimelineTrackLaneBadge({
    required this.size,
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.isReorder,
    this.isEmphasized = false,
  });

  final double size;
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isReorder;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Colors.white.withOpacity(
      isEmphasized ? 0.065 : (isReorder ? 0.052 : 0.04),
    );
    final borderColor = Colors.white.withOpacity(
      isEmphasized ? 0.16 : (isReorder ? 0.1 : 0.065),
    );
    final iconColor = Colors.white.withOpacity(
      isEmphasized ? 0.9 : (isReorder ? 0.8 : 0.68),
    );
    final labelColor = Colors.white.withOpacity(
      isEmphasized ? 0.72 : (isReorder ? 0.64 : 0.5),
    );
    final accentLineColor = accentColor.withOpacity(
      isEmphasized ? 0.82 : (isReorder ? 0.68 : 0.54),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(isReorder ? 10 : 8),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              isEmphasized ? 0.2 : (isReorder ? 0.15 : 0.1),
            ),
            blurRadius: isEmphasized ? 14 : (isReorder ? 11 : 8),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: labelColor,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 14,
            height: 1.5,
            decoration: BoxDecoration(
              color: accentLineColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedTrimClipGeometry {
  const _ResolvedTrimClipGeometry({
    required this.clip,
    required this.left,
    required this.width,
    required this.sourceStartTime,
    required this.durationTime,
    this.isPreviewing = false,
  });

  final TimelineClipData clip;
  final double left;
  final double width;
  final TimelineTime sourceStartTime;
  final TimelineTime durationTime;
  final bool isPreviewing;
}

class _TimelineScrubExclusion {
  const _TimelineScrubExclusion({
    required this.left,
    required this.right,
  });

  final double left;
  final double right;
}

class _TimelineTrimChrome extends StatelessWidget {
  const _TimelineTrimChrome({
    required this.width,
    required this.height,
    required this.isPlaying,
    required this.isPreviewing,
    this.activeEdge,
    required this.onTrimDragStart,
    required this.onTrimDragUpdate,
    required this.onTrimDragEnd,
    required this.onTrimHandleEngagementChanged,
  });

  static double get handleTouchInset => 0;

  final double width;
  final double height;
  final bool isPlaying;
  final bool isPreviewing;
  final TimelineTrimEdge? activeEdge;
  final ValueChanged<TimelineTrimEdge> onTrimDragStart;
  final ValueChanged<double> onTrimDragUpdate;
  final VoidCallback onTrimDragEnd;
  final ValueChanged<bool> onTrimHandleEngagementChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = math.max(width, 24).toDouble();
    final handleHitWidth = math.min(
      _TimelineTrimCanonicalProfile.handleHitWidth,
      resolvedWidth / 2,
    );
    final handleVisualWidth = math.min(
      _TimelineTrimCanonicalProfile.handleVisualWidth,
      math.max(
        _TimelineTrimCanonicalProfile.handleMinVisualWidth,
        handleHitWidth - (_TimelineTrimCanonicalProfile.handleVisualInset * 2),
      ),
    );
    return SizedBox(
      width: resolvedWidth,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isPreviewing
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.08),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: handleHitWidth,
            child: _TimelineTrimHandle(
              edge: TimelineTrimEdge.start,
              enabled: !isPlaying,
              isActive: activeEdge == TimelineTrimEdge.start,
              trackHeight: height,
              hitWidth: handleHitWidth,
              visualWidth: handleVisualWidth,
              onDragStart: onTrimDragStart,
              onDragUpdate: onTrimDragUpdate,
              onDragEnd: onTrimDragEnd,
              onEngagementChanged: onTrimHandleEngagementChanged,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: handleHitWidth,
            child: _TimelineTrimHandle(
              edge: TimelineTrimEdge.end,
              enabled: !isPlaying,
              isActive: activeEdge == TimelineTrimEdge.end,
              trackHeight: height,
              hitWidth: handleHitWidth,
              visualWidth: handleVisualWidth,
              onDragStart: onTrimDragStart,
              onDragUpdate: onTrimDragUpdate,
              onDragEnd: onTrimDragEnd,
              onEngagementChanged: onTrimHandleEngagementChanged,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.94),
                    width: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineClipMoveSession {
  const _TimelineClipMoveSession({
    required this.trackIndex,
    required this.clipId,
    required this.originalStartTime,
    required this.currentStartTime,
    required this.durationTime,
  });

  final int trackIndex;
  final String clipId;
  final TimelineTime originalStartTime;
  final TimelineTime currentStartTime;
  final TimelineTime durationTime;

  _TimelineClipMoveSession copyWith({
    TimelineTime? currentStartTime,
  }) {
    return _TimelineClipMoveSession(
      trackIndex: trackIndex,
      clipId: clipId,
      originalStartTime: originalStartTime,
      currentStartTime: currentStartTime ?? this.currentStartTime,
      durationTime: durationTime,
    );
  }
}

class _TimelinePositionedTrackClip {
  const _TimelinePositionedTrackClip({
    required this.clip,
    required this.startTime,
  });

  final TimelineClipData clip;
  final TimelineTime startTime;

  TimelineTime get endTime => startTime + clip.durationTime;
}

class _TimelineClipMoveInterval {
  const _TimelineClipMoveInterval({
    required this.start,
    required this.end,
  });

  final TimelineTime start;
  final TimelineTime end;
}

class _TimelineTrimHandle extends StatefulWidget {
  const _TimelineTrimHandle({
    required this.edge,
    required this.enabled,
    required this.isActive,
    required this.trackHeight,
    required this.hitWidth,
    required this.visualWidth,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onEngagementChanged,
  });

  final TimelineTrimEdge edge;
  final bool enabled;
  final bool isActive;
  final double trackHeight;
  final double hitWidth;
  final double visualWidth;
  final ValueChanged<TimelineTrimEdge> onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<bool> onEngagementChanged;

  @override
  State<_TimelineTrimHandle> createState() => _TimelineTrimHandleState();
}

class _TimelineTrimHandleState extends State<_TimelineTrimHandle> {
  bool _isPressed = false;
  bool _isCapturing = false;
  bool _isHorizontallyLocked = false;
  bool _hasStartedTrimDrag = false;
  double? _lastGlobalDx;
  Offset? _captureOrigin;

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  void _beginCapture(Offset globalPosition) {
    if (!widget.enabled || _isCapturing) {
      return;
    }
    _isCapturing = true;
    _isHorizontallyLocked = false;
    _hasStartedTrimDrag = false;
    _lastGlobalDx = globalPosition.dx;
    _captureOrigin = globalPosition;
    HapticFeedback.selectionClick();
    _setPressed(true);
  }

  void _handlePointerDown() {
    if (!widget.enabled) {
      return;
    }
    _setPressed(true);
    widget.onEngagementChanged(true);
  }

  void _handlePointerRelease() {
    if (_isCapturing) {
      return;
    }
    _setPressed(false);
    widget.onEngagementChanged(false);
  }

  void _updateCapture(DragUpdateDetails details) {
    if (!_isCapturing) {
      return;
    }
    if (!_isHorizontallyLocked) {
      final captureOrigin = _captureOrigin;
      if (captureOrigin == null) {
        _captureOrigin = details.globalPosition;
        _lastGlobalDx = details.globalPosition.dx;
        return;
      }
      final totalDx = details.globalPosition.dx - captureOrigin.dx;
      final totalDy = details.globalPosition.dy - captureOrigin.dy;
      final absDx = totalDx.abs();
      final absDy = totalDy.abs();
      if (absDx < _TimelineTrimCanonicalProfile.horizontalLockThresholdPx &&
          absDy < _TimelineTrimCanonicalProfile.horizontalLockThresholdPx) {
        return;
      }
      if (absDx <
          math.max(
            _TimelineTrimCanonicalProfile.horizontalLockThresholdPx,
            absDy * _TimelineTrimCanonicalProfile.horizontalLockDominanceRatio,
          )) {
        return;
      }
      _isHorizontallyLocked = true;
      if (!_hasStartedTrimDrag) {
        _hasStartedTrimDrag = true;
        widget.onDragStart(widget.edge);
      }
      _lastGlobalDx = details.globalPosition.dx;
      return;
    }
    final lastGlobalDx = _lastGlobalDx;
    if (lastGlobalDx == null) {
      _lastGlobalDx = details.globalPosition.dx;
      return;
    }
    final deltaDx = details.globalPosition.dx - lastGlobalDx;
    _lastGlobalDx = details.globalPosition.dx;
    if (deltaDx == 0) {
      return;
    }
    widget.onDragUpdate(deltaDx);
  }

  void _endCapture() {
    final wasCapturing = _isCapturing;
    if (!wasCapturing && !_isPressed && _lastGlobalDx == null) {
      return;
    }
    _isCapturing = false;
    _isHorizontallyLocked = false;
    final didStartTrimDrag = _hasStartedTrimDrag;
    _hasStartedTrimDrag = false;
    _lastGlobalDx = null;
    _captureOrigin = null;
    _setPressed(false);
    widget.onEngagementChanged(false);
    if (wasCapturing && didStartTrimDrag) {
      widget.onDragEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCaptured = widget.isActive || _isPressed;
    final visualHeight = math.max(24.0, widget.trackHeight - 2);
    const outerRadius = Radius.circular(6);
    const innerRadius = Radius.circular(4);
    final visualChild = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: widget.visualWidth,
      height: visualHeight,
      decoration: BoxDecoration(
        color: widget.enabled
            ? (isCaptured
                ? const Color(0xFFF8FFFD)
                : Colors.white.withOpacity(0.98))
            : Colors.white.withOpacity(0.24),
        borderRadius: widget.edge == TimelineTrimEdge.start
            ? const BorderRadius.only(
                topLeft: outerRadius,
                bottomLeft: outerRadius,
                topRight: innerRadius,
                bottomRight: innerRadius,
              )
            : const BorderRadius.only(
                topLeft: innerRadius,
                bottomLeft: innerRadius,
                topRight: outerRadius,
                bottomRight: outerRadius,
              ),
        border: isCaptured
            ? Border.all(
                color: const Color(0xFF53E7D8).withOpacity(0.95),
                width: _TimelineTrimCanonicalProfile.handlePressedBorderWidth,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: (isCaptured ? const Color(0xFF53E7D8) : Colors.black)
                .withOpacity(
                    widget.enabled ? (isCaptured ? 0.26 : 0.18) : 0.08),
            blurRadius: isCaptured ? 14 : 10,
            offset: Offset(0, isCaptured ? 4 : 3),
          ),
        ],
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: isCaptured ? 3.8 : 3.4,
          height: isCaptured ? 18 : 16,
          decoration: BoxDecoration(
            color: isCaptured
                ? const Color(0xFF2F7BFF)
                : Colors.black.withOpacity(
                    widget.enabled ? 0.24 : 0.12,
                  ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _handlePointerDown(),
      onPointerUp: (_) => _handlePointerRelease(),
      onPointerCancel: (_) => _handlePointerRelease(),
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  ImmediateMultiDragGestureRecognizer>(
            () => ImmediateMultiDragGestureRecognizer(debugOwner: this),
            (ImmediateMultiDragGestureRecognizer recognizer) {
              recognizer.onStart = widget.enabled
                  ? (Offset position) {
                      _beginCapture(position);
                      return _TimelineTrimHandleDrag(
                        onUpdate: _updateCapture,
                        onFinish: _endCapture,
                      );
                    }
                  : null;
            },
          ),
        },
        child: SizedBox(
          width: widget.hitWidth,
          child: Align(
            alignment: widget.edge == TimelineTrimEdge.start
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: visualChild,
          ),
        ),
      ),
    );
  }
}

class _TimelineTrimHandleDrag extends Drag {
  _TimelineTrimHandleDrag({
    required this.onUpdate,
    required this.onFinish,
  });

  final ValueChanged<DragUpdateDetails> onUpdate;
  final VoidCallback onFinish;

  @override
  void update(DragUpdateDetails details) {
    onUpdate(details);
  }

  @override
  void end(DragEndDetails details) {
    onFinish();
  }

  @override
  void cancel() {
    onFinish();
  }
}

class _TimelineTrimDragSession {
  const _TimelineTrimDragSession({
    required this.selection,
    required this.edge,
    required this.dragDx,
    required this.sourceStartTime,
    required this.sourceDurationTime,
    required this.durationTime,
  });

  final TimelineTrimSelection selection;
  final TimelineTrimEdge edge;
  final double dragDx;
  final TimelineTime sourceStartTime;
  final TimelineTime sourceDurationTime;
  final TimelineTime durationTime;
}

class _TimelineReorderRowLayout {
  const _TimelineReorderRowLayout({
    required this.stationaryClips,
    required this.slotCenters,
    required this.leftByClipId,
    required this.widthByClipId,
    required this.rowWidth,
  });

  final List<TimelineClipData> stationaryClips;
  final List<double> slotCenters;
  final Map<String, double> leftByClipId;
  final Map<String, double> widthByClipId;
  final double rowWidth;
}

class _TimelineExpandedTrackRowLayout {
  const _TimelineExpandedTrackRowLayout({
    required this.leftByClipId,
    required this.widthByClipId,
    required this.rowWidth,
    required this.clipTopInset,
    required this.clipHeight,
  });

  final Map<String, double> leftByClipId;
  final Map<String, double> widthByClipId;
  final double rowWidth;
  final double clipTopInset;
  final double clipHeight;
}

class _TimelineReorderTrackRow extends StatelessWidget {
  const _TimelineReorderTrackRow({
    required this.leadingOffset,
    required this.controlTileSize,
    required this.controlGap,
    required this.rowHeight,
    required this.cardHeight,
    required this.track,
    required this.selectedClipId,
    required this.draggedClipId,
    required this.hoverInsertionIndex,
    required this.layout,
    required this.entryLayout,
    required this.transitionProgress,
    required this.draggedCenter,
    required this.draggedWidth,
    required this.isDropSettling,
    required this.assetPathResolver,
    this.showLaneBadge = true,
  });

  final double leadingOffset;
  final double controlTileSize;
  final double controlGap;
  final double rowHeight;
  final double cardHeight;
  final TimelineTrackData track;
  final String? selectedClipId;
  final String? draggedClipId;
  final int? hoverInsertionIndex;
  final _TimelineReorderRowLayout layout;
  final _TimelineExpandedTrackRowLayout? entryLayout;
  final double transitionProgress;
  final double? draggedCenter;
  final double? draggedWidth;
  final bool isDropSettling;
  final TimelineAssetPathResolver? assetPathResolver;
  final bool showLaneBadge;

  IconData get _trackIcon {
    switch (track.kind) {
      case TimelineTrackKind.video:
        return Icons.videocam_rounded;
      case TimelineTrackKind.image:
        return Icons.image_rounded;
      case TimelineTrackKind.audio:
        return Icons.music_note_rounded;
      case TimelineTrackKind.text:
        return Icons.text_fields_rounded;
      case TimelineTrackKind.lipSync:
        return Icons.graphic_eq_rounded;
    }
  }

  IconData get _clipIcon {
    switch (track.kind) {
      case TimelineTrackKind.video:
        return Icons.videocam_rounded;
      case TimelineTrackKind.image:
        return Icons.image_rounded;
      case TimelineTrackKind.audio:
        return Icons.music_note_rounded;
      case TimelineTrackKind.text:
        return Icons.text_fields_rounded;
      case TimelineTrackKind.lipSync:
        return Icons.graphic_eq_rounded;
    }
  }

  _TimelineTrackLaneProfile get _laneProfile =>
      _TimelineTrackLaneProfile.forKind(track.kind);

  double get _controlHitSize =>
      math.max(controlTileSize, _laneProfile.controlHitSize);

  bool get _isActiveRow => draggedClipId != null || hoverInsertionIndex != null;

  Widget _buildClipCard(
    TimelineClipData clip,
    double width, {
    required double height,
    bool isDragged = false,
    double morphProgress = 1,
  }) {
    final isSelected = selectedClipId == clip.id;
    final assetPath =
        clip.assetId == null ? null : assetPathResolver?.call(clip.assetId!);

    if (clip.type == TimelineClipType.placeholder) {
      return _TimelinePlaceholderClip(
        width: width,
        height: height,
        label: clip.label ?? track.placeholderLabel ?? 'Add',
        isSelected: isSelected,
        isDragged: isDragged,
        onTap: () {},
      );
    }

    return _TimelineReorderClipCard(
      width: width,
      height: height,
      tone: clip.tone,
      icon: _clipIcon,
      trackKind: track.kind,
      assetPath: assetPath,
      sourceOffsetSeconds: clip.sourceOffsetSeconds,
      durationSeconds: clip.duration,
      isSelected: isSelected,
      isDragged: isDragged,
      morphProgress: morphProgress,
    );
  }

  @override
  Widget build(BuildContext context) {
    TimelineClipData? draggedClip;
    final draggedClipId = this.draggedClipId;
    if (draggedClipId != null) {
      for (final clip in track.clips) {
        if (clip.id == draggedClipId) {
          draggedClip = clip;
          break;
        }
      }
    }
    final resolvedDraggedWidth = draggedWidth ??
        (draggedClip == null ? null : layout.widthByClipId[draggedClip.id]);
    final draggedLeft = draggedClip == null ||
            draggedCenter == null ||
            resolvedDraggedWidth == null
        ? null
        : draggedCenter! - (resolvedDraggedWidth / 2);
    final hasEntryMorph = entryLayout != null && transitionProgress < 0.999;
    final entryProgress = Curves.easeOutCubic.transform(
      transitionProgress.clamp(0.0, 1.0),
    );
    final reorderTopInset = _laneProfile.reorderCardTopInset;
    final reorderCardHeight = cardHeight;

    return SizedBox(
      width: layout.rowWidth,
      height: rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showLaneBadge)
            Positioned(
              left: leadingOffset,
              top: 0,
              child: SizedBox(
                width: _controlHitSize,
                height: rowHeight,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: _laneProfile.headerTopInset),
                    child: _TimelineTrackLaneBadge(
                      size: controlTileSize,
                      icon: _trackIcon,
                      label: _laneProfile.shortLabel,
                      accentColor: _laneProfile.accentColor,
                      isReorder: true,
                      isEmphasized: _isActiveRow,
                    ),
                  ),
                ),
              ),
            ),
          for (final clip in layout.stationaryClips)
            if (hasEntryMorph)
              Positioned(
                left: lerpDouble(
                      entryLayout!.leftByClipId[clip.id] ??
                          layout.leftByClipId[clip.id]!,
                      layout.leftByClipId[clip.id]!,
                      entryProgress,
                    ) ??
                    layout.leftByClipId[clip.id]!,
                top: lerpDouble(
                      entryLayout!.clipTopInset,
                      reorderTopInset,
                      entryProgress,
                    ) ??
                    reorderTopInset,
                child: _buildClipCard(
                  clip,
                  lerpDouble(
                        entryLayout!.widthByClipId[clip.id] ??
                            layout.widthByClipId[clip.id]!,
                        layout.widthByClipId[clip.id]!,
                        entryProgress,
                      ) ??
                      layout.widthByClipId[clip.id]!,
                  height: lerpDouble(
                        entryLayout!.clipHeight,
                        reorderCardHeight,
                        entryProgress,
                      ) ??
                      reorderCardHeight,
                  morphProgress: entryProgress,
                ),
              )
            else
              AnimatedPositioned(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                left: layout.leftByClipId[clip.id]!,
                top: reorderTopInset,
                child: _buildClipCard(
                  clip,
                  layout.widthByClipId[clip.id]!,
                  height: reorderCardHeight,
                  morphProgress: 1,
                ),
              ),
          if (draggedClip != null &&
              draggedLeft != null &&
              resolvedDraggedWidth != null)
            () {
              final dragged = draggedClip;
              if (dragged == null) {
                return const SizedBox.shrink();
              }
              final sourceLeft =
                  entryLayout?.leftByClipId[dragged.id] ?? draggedLeft;
              final sourceWidth = entryLayout?.widthByClipId[dragged.id] ??
                  resolvedDraggedWidth;
              final sourceTop = entryLayout?.clipTopInset ?? reorderTopInset;
              final sourceHeight = entryLayout?.clipHeight ?? reorderCardHeight;
              final draggedScale = lerpDouble(
                    1.0,
                    isDropSettling ? 1.0 : 1.012,
                    Curves.easeOut.transform(
                      transitionProgress.clamp(0.0, 1.0),
                    ),
                  ) ??
                  1.012;

              if (hasEntryMorph) {
                return Positioned(
                  left: lerpDouble(sourceLeft, draggedLeft, entryProgress) ??
                      draggedLeft,
                  top: lerpDouble(sourceTop, reorderTopInset, entryProgress) ??
                      reorderTopInset,
                  child: Transform.scale(
                    scale: draggedScale,
                    child: _buildClipCard(
                      dragged,
                      lerpDouble(
                            sourceWidth,
                            resolvedDraggedWidth,
                            entryProgress,
                          ) ??
                          resolvedDraggedWidth,
                      height: lerpDouble(
                            sourceHeight,
                            reorderCardHeight,
                            entryProgress,
                          ) ??
                          reorderCardHeight,
                      isDragged: true,
                      morphProgress: entryProgress,
                    ),
                  ),
                );
              }

              if (isDropSettling) {
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 190),
                  curve: Curves.easeOutCubic,
                  left: draggedLeft,
                  top: reorderTopInset,
                  child: _buildClipCard(
                    dragged,
                    resolvedDraggedWidth,
                    height: reorderCardHeight,
                    isDragged: true,
                    morphProgress: 1,
                  ),
                );
              }

              return Positioned(
                left: draggedLeft,
                top: reorderTopInset,
                child: Transform.scale(
                  scale: draggedScale,
                  child: _buildClipCard(
                    dragged,
                    resolvedDraggedWidth,
                    height: reorderCardHeight,
                    isDragged: true,
                    morphProgress: 1,
                  ),
                ),
              );
            }(),
        ],
      ),
    );
  }
}

class _TimelineMediaClip extends StatelessWidget {
  const _TimelineMediaClip({
    required this.width,
    required this.tone,
    required this.icon,
    required this.trackKind,
    required this.isPlaying,
    required this.assetPath,
    required this.sourceOffsetSeconds,
    required this.durationSeconds,
    required this.playbackRate,
    required this.speedMode,
    required this.isSelected,
    this.usesTrimChrome = false,
    required this.joinLeft,
    required this.joinRight,
    required this.onTap,
    this.onDoubleTap,
    this.height = 38,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });

  final double width;
  final TimelineClipTone tone;
  final IconData icon;
  final TimelineTrackKind trackKind;
  final bool isPlaying;
  final String? assetPath;
  final double sourceOffsetSeconds;
  final double durationSeconds;
  final double playbackRate;
  final TimelineClipSpeedMode speedMode;
  final bool isSelected;
  final bool usesTrimChrome;
  final bool joinLeft;
  final bool joinRight;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final double height;
  final VoidCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final VoidCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final accent = _timelineClipAccentColor(
      trackKind: trackKind,
      tone: tone,
    );
    final selectionAccent = _timelineSelectionAccentColor(trackKind);
    final hasVideoFrames =
        trackKind == TimelineTrackKind.video && assetPath != null;
    final hasImagePreview =
        trackKind == TimelineTrackKind.image && assetPath != null;
    final baseColor = hasVideoFrames || hasImagePreview
        ? _timelineClipSurfaceColor(trackKind)
        : accent;
    final borderRadius = BorderRadius.horizontal(
      left: Radius.circular(joinLeft ? 2 : 6),
      right: Radius.circular(joinRight ? 2 : 6),
    );
    final clipBorderColor = usesTrimChrome
        ? Colors.transparent
        : isSelected
            ? Colors.white.withOpacity(0.9)
            : Colors.white.withOpacity(0.08);
    final clipBorderWidth = usesTrimChrome ? 0.0 : (isSelected ? 1.55 : 0.95);
    final showsFallbackInterior = !hasVideoFrames && !hasImagePreview;
    final showSpeedBadge = speedMode == TimelineClipSpeedMode.curve ||
        (playbackRate - 1.0).abs() > 0.001;
    final speedLabel = speedMode == TimelineClipSpeedMode.curve
        ? 'Curve'
        : _formatSpeedLabel(playbackRate);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPressStart:
          onLongPressStart == null ? null : (_) => onLongPressStart!(),
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressEnd:
          onLongPressEnd == null ? null : (_) => onLongPressEnd!(),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: clipBorderColor,
                    width: clipBorderWidth,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    if (isSelected && !usesTrimChrome)
                      BoxShadow(
                        color: selectionAccent.withOpacity(0.2),
                        blurRadius: 16,
                        spreadRadius: 0.5,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(joinLeft ? 2 : 5),
                    right: Radius.circular(joinRight ? 2 : 5),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasVideoFrames)
                        _TimelineVideoFilmstrip(
                          path: assetPath!,
                          isPlaying: isPlaying,
                          width: width,
                          height: height,
                          sourceOffsetSeconds: sourceOffsetSeconds,
                          durationSeconds: durationSeconds,
                        )
                      else if (hasImagePreview)
                        _TimelineImageFill(path: assetPath!)
                      else
                        ColoredBox(color: accent),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              selectionAccent.withOpacity(
                                hasVideoFrames || hasImagePreview ? 0.16 : 0.12,
                              ),
                              Colors.transparent,
                              Colors.black.withOpacity(
                                hasVideoFrames || hasImagePreview ? 0.06 : 0.02,
                              ),
                            ],
                            stops: const [0.0, 0.52, 1.0],
                          ),
                        ),
                      ),
                      if (showsFallbackInterior)
                        _TimelineFallbackClipInterior(
                          width: width,
                          icon: icon,
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.07),
                              Colors.transparent,
                              Colors.black.withOpacity(0.06),
                            ],
                          ),
                        ),
                      ),
                      if (isSelected && !usesTrimChrome)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _TimelineSelectedPulse(
                              borderRadius: borderRadius,
                              accentColor: selectionAccent,
                            ),
                          ),
                        ),
                      if (showSpeedBadge)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.56),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                child: Text(
                                  speedLabel,
                                  style: const TextStyle(
                                    color: FxPalette.textPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSpeedLabel(double value) {
    final fixed = value >= 10
        ? value.toStringAsFixed(0)
        : value >= 2
            ? value.toStringAsFixed(1)
            : value.toStringAsFixed(2);
    final normalized =
        fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
    return '${normalized}x';
  }
}

class _TimelineReorderClipCard extends StatelessWidget {
  const _TimelineReorderClipCard({
    required this.width,
    required this.height,
    required this.tone,
    required this.icon,
    required this.trackKind,
    required this.assetPath,
    required this.sourceOffsetSeconds,
    required this.durationSeconds,
    required this.isSelected,
    required this.isDragged,
    this.morphProgress = 1,
  });

  final double width;
  final double height;
  final TimelineClipTone tone;
  final IconData icon;
  final TimelineTrackKind trackKind;
  final String? assetPath;
  final double sourceOffsetSeconds;
  final double durationSeconds;
  final bool isSelected;
  final bool isDragged;
  final double morphProgress;

  @override
  Widget build(BuildContext context) {
    final accent = _timelineClipAccentColor(
      trackKind: trackKind,
      tone: tone,
    );
    final hasVideoFrames =
        trackKind == TimelineTrackKind.video && assetPath != null;
    final hasImagePreview =
        trackKind == TimelineTrackKind.image && assetPath != null;
    final progress = morphProgress.clamp(0.0, 1.0);
    final radiusValue = lerpDouble(6, 14, progress) ?? 14;
    final baseColor = hasVideoFrames || hasImagePreview
        ? _timelineClipSurfaceColor(trackKind)
        : accent;
    final borderColor = Color.lerp(
          Colors.white.withOpacity(0.04),
          isDragged
              ? Colors.white.withOpacity(0.7)
              : isSelected
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.14),
          progress,
        ) ??
        Colors.white.withOpacity(0.14);
    final iconSize = lerpDouble(13, isDragged ? 17 : 15, progress) ?? 15;
    final overlayOpacity = lerpDouble(0.0, 0.22, progress) ?? 0.22;
    final chromeOpacity = lerpDouble(0.0, 1.0, progress) ?? 1.0;
    final iconBubbleSize = lerpDouble(0, isDragged ? 24 : 22, progress) ?? 22;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radiusValue),
          border: Border.all(
            color: borderColor,
            width: isDragged ? 1.4 : (isSelected ? 1.2 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isDragged ? 0.28 : (isSelected ? 0.18 : 0.12),
              ),
              blurRadius: isDragged ? 18 : 12,
              offset: Offset(0, isDragged ? 8 : 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radiusValue - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideoFrames)
                _TimelineVideoFilmstrip(
                  path: assetPath!,
                  isPlaying: false,
                  width: width,
                  height: height,
                  sourceOffsetSeconds: sourceOffsetSeconds,
                  durationSeconds: durationSeconds,
                )
              else if (hasImagePreview)
                _TimelineImageFill(path: assetPath!)
              else
                ColoredBox(color: baseColor),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.08 * chromeOpacity),
                        Colors.transparent,
                        Colors.black.withOpacity(overlayOpacity),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(
                      hasVideoFrames || hasImagePreview ? 0.14 : 0.02,
                    ),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: chromeOpacity,
                  child: Container(
                    width: iconBubbleSize,
                    height: iconBubbleSize,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(
                        hasVideoFrames || hasImagePreview ? 0.34 : 0.16,
                      ),
                      borderRadius: BorderRadius.circular(
                        lerpDouble(8, 10, progress) ?? 10,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: Colors.white.withOpacity(0.94),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineFallbackClipInterior extends StatelessWidget {
  const _TimelineFallbackClipInterior({
    required this.width,
    required this.icon,
  });

  final double width;
  final IconData icon;

  List<double> get _iconAnchors {
    if (width < 92) {
      return const <double>[];
    }
    if (width < 164) {
      return const <double>[0.5];
    }
    if (width < 278) {
      return const <double>[0.34, 0.66];
    }
    return const <double>[0.24, 0.5, 0.76];
  }

  @override
  Widget build(BuildContext context) {
    final anchors = _iconAnchors;
    if (anchors.isEmpty) {
      return const SizedBox.shrink();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final anchor in anchors)
          Align(
            alignment: Alignment((anchor * 2) - 1, 0),
            child: Icon(
              icon,
              size: 18,
              color: Colors.black.withOpacity(0.85),
            ),
          ),
      ],
    );
  }
}

class _TimelineImageFill extends StatelessWidget {
  const _TimelineImageFill({
    required this.path,
  });

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(color: FxPalette.clipFillAlt);
      },
    );
  }
}

class _TimelineTrackLaneUnderlay extends StatelessWidget {
  const _TimelineTrackLaneUnderlay({
    required this.accentColor,
    required this.leadingOffset,
    required this.controlColumnWidth,
    required this.rowHeight,
    required this.clipTopInset,
    required this.clipHeight,
    required this.isReorder,
    required this.isActive,
    this.showRail = true,
  });

  final Color accentColor;
  final double leadingOffset;
  final double controlColumnWidth;
  final double rowHeight;
  final double clipTopInset;
  final double clipHeight;
  final bool isReorder;
  final bool isActive;
  final bool showRail;

  @override
  Widget build(BuildContext context) {
    final railLeft = leadingOffset + controlColumnWidth + 3;
    final railTop = (clipTopInset + 3).clamp(0.0, rowHeight);
    final railHeight = math.max(10.0, clipHeight - 6);
    final neutralFill = Colors.white.withOpacity(
      isActive ? (isReorder ? 0.028 : 0.02) : (isReorder ? 0.018 : 0.012),
    );
    final railColor = accentColor.withOpacity(
      isActive ? (isReorder ? 0.34 : 0.24) : (isReorder ? 0.2 : 0.14),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: neutralFill,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(isActive ? 0.05 : 0.028),
          ),
        ),
        if (showRail)
          Positioned(
            left: railLeft,
            top: railTop,
            child: Container(
              width: 1.5,
              height: railHeight,
              decoration: BoxDecoration(
                color: railColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimelineVideoFilmstrip extends StatefulWidget {
  const _TimelineVideoFilmstrip({
    required this.path,
    required this.isPlaying,
    required this.width,
    required this.height,
    required this.sourceOffsetSeconds,
    required this.durationSeconds,
  });

  final String path;
  final bool isPlaying;
  final double width;
  final double height;
  final double sourceOffsetSeconds;
  final double durationSeconds;

  @override
  State<_TimelineVideoFilmstrip> createState() =>
      _TimelineVideoFilmstripState();
}

class _TimelineVideoFilmstripState extends State<_TimelineVideoFilmstrip> {
  static const Duration _thumbnailLoadDelay = Duration.zero;

  Future<List<Uint8List>>? _thumbnailsFuture;
  List<Uint8List>? _seedThumbnails;

  int get _tileCount => math.max(2, (widget.width / 54).ceil());

  int get _targetWidth {
    final tileWidth = widget.width / _tileCount;
    return math.max(96, (tileWidth * 2).round());
  }

  int get _targetHeight => math.max(68, (widget.height * 2).round());

  @override
  void initState() {
    super.initState();
    _refreshThumbnails();
  }

  @override
  void didUpdateWidget(covariant _TimelineVideoFilmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.isPlaying != widget.isPlaying ||
        (oldWidget.width - widget.width).abs() > 0.5 ||
        (oldWidget.height - widget.height).abs() > 0.5 ||
        (oldWidget.sourceOffsetSeconds - widget.sourceOffsetSeconds).abs() >
            0.001 ||
        (oldWidget.durationSeconds - widget.durationSeconds).abs() > 0.001) {
      _refreshThumbnails();
    }
  }

  void _refreshThumbnails() {
    _seedThumbnails = _TimelineFilmstripCache.peek(
      path: widget.path,
      sourceOffsetSeconds: widget.sourceOffsetSeconds,
      durationSeconds: widget.durationSeconds,
      tileCount: _tileCount,
      targetWidth: _targetWidth,
      targetHeight: _targetHeight,
    );
    if (widget.isPlaying &&
        _seedThumbnails != null &&
        _seedThumbnails!.isNotEmpty) {
      _thumbnailsFuture = null;
      return;
    }
    final timestamps = List<double>.generate(_tileCount, (index) {
      final fraction = (index + 0.5) / _tileCount;
      return widget.sourceOffsetSeconds + (widget.durationSeconds * fraction);
    });
    _thumbnailsFuture = Future<List<Uint8List>>.delayed(
      _thumbnailLoadDelay,
      () => _TimelineFilmstripCache.load(
        path: widget.path,
        sourceOffsetSeconds: widget.sourceOffsetSeconds,
        durationSeconds: widget.durationSeconds,
        tileCount: _tileCount,
        targetWidth: _targetWidth,
        targetHeight: _targetHeight,
        timestampsSeconds: timestamps,
      ),
    );
  }

  Widget _buildFallback() {
    return ColoredBox(
      color: const Color(0xFF2B2B2B),
      child: Row(
        children: List.generate(
          _tileCount,
          (index) => Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.03),
                    Colors.transparent,
                    Colors.black.withOpacity(0.08),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnails(List<Uint8List> thumbnails) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth / _tileCount;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < _tileCount; index++)
              Positioned(
                left: tileWidth * index,
                top: 0,
                bottom: 0,
                width: index == _tileCount - 1 ? tileWidth : tileWidth + 1.5,
                child: Image.memory(
                  thumbnails[index % thumbnails.length],
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _thumbnailsFuture,
      builder: (context, snapshot) {
        final thumbnails = snapshot.data;
        if (thumbnails != null && thumbnails.isNotEmpty) {
          return _buildThumbnails(thumbnails);
        }

        final seededThumbnails = _seedThumbnails;
        if (seededThumbnails != null && seededThumbnails.isNotEmpty) {
          return _buildThumbnails(seededThumbnails);
        }

        if (snapshot.hasError) {
          return _buildFallback();
        }

        return _buildFallback();
      },
    );
  }
}

class _TimelineFilmstripCache {
  static final Map<String, Future<List<Uint8List>>> _entries =
      <String, Future<List<Uint8List>>>{};
  static final Map<String, List<Uint8List>> _segmentEntries =
      <String, List<Uint8List>>{};
  static final Map<String, Uint8List> _frameEntries = <String, Uint8List>{};

  static List<Uint8List>? peek({
    required String path,
    required double sourceOffsetSeconds,
    required double durationSeconds,
    required int tileCount,
    required int targetWidth,
    required int targetHeight,
  }) {
    final key = _segmentKey(
      path: path,
      sourceOffsetSeconds: sourceOffsetSeconds,
      durationSeconds: durationSeconds,
      tileCount: tileCount,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    return _segmentEntries[key];
  }

  static double _normalizeTimestamp(double value) {
    return (value * 4).round() / 4;
  }

  static String _frameKey({
    required String path,
    required double timestampSeconds,
    required int targetWidth,
    required int targetHeight,
  }) {
    return [
      path,
      timestampSeconds.toStringAsFixed(2),
      targetWidth,
      targetHeight,
    ].join('|');
  }

  static String _segmentKey({
    required String path,
    required double sourceOffsetSeconds,
    required double durationSeconds,
    required int tileCount,
    required int targetWidth,
    required int targetHeight,
  }) {
    return [
      path,
      sourceOffsetSeconds.toStringAsFixed(3),
      durationSeconds.toStringAsFixed(3),
      tileCount,
      targetWidth,
      targetHeight,
    ].join('|');
  }

  static Future<List<Uint8List>> load({
    required String path,
    required double sourceOffsetSeconds,
    required double durationSeconds,
    required int tileCount,
    required int targetWidth,
    required int targetHeight,
    required List<double> timestampsSeconds,
  }) {
    final normalizedTimestamps =
        timestampsSeconds.map(_normalizeTimestamp).toList(growable: false);
    final frameKeys = normalizedTimestamps
        .map(
          (timestamp) => _frameKey(
            path: path,
            timestampSeconds: timestamp,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
          ),
        )
        .toList(growable: false);
    final missingTimestamps = <double>[];
    final missingFrameKeys = <String>[];
    for (var i = 0; i < frameKeys.length; i++) {
      final key = frameKeys[i];
      if (_frameEntries.containsKey(key)) {
        continue;
      }
      if (missingFrameKeys.contains(key)) {
        continue;
      }
      missingFrameKeys.add(key);
      missingTimestamps.add(normalizedTimestamps[i]);
    }

    final segmentKey = _segmentKey(
      path: path,
      sourceOffsetSeconds: sourceOffsetSeconds,
      durationSeconds: durationSeconds,
      tileCount: tileCount,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final key = [
      segmentKey,
      for (final timestamp in normalizedTimestamps)
        timestamp.toStringAsFixed(2),
    ].join('|');
    return _entries.putIfAbsent(
      key,
      () async {
        try {
          if (missingTimestamps.isNotEmpty) {
            final generated =
                await NativeMediaThumbnailer.generateVideoThumbnails(
              path: path,
              timestampsSeconds: missingTimestamps,
              targetWidth: targetWidth,
              targetHeight: targetHeight,
            );
            final resolvedCount =
                math.min(generated.length, missingFrameKeys.length);
            for (var i = 0; i < resolvedCount; i++) {
              _frameEntries[missingFrameKeys[i]] = generated[i];
            }
          }
          final thumbnails = <Uint8List>[
            for (final frameKey in frameKeys)
              if (_frameEntries[frameKey] case final bytes?) bytes,
          ];
          if (thumbnails.isNotEmpty) {
            _segmentEntries[segmentKey] =
                List<Uint8List>.unmodifiable(thumbnails);
          } else {
            _entries.remove(key);
          }
          return thumbnails;
        } catch (_) {
          _entries.remove(key);
          rethrow;
        }
      },
    );
  }
}

class _TimelinePlaceholderClip extends StatelessWidget {
  const _TimelinePlaceholderClip({
    required this.width,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onDoubleTap,
    this.height = 38,
    this.isDragged = false,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });

  final double width;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final double height;
  final bool isDragged;
  final VoidCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final VoidCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final isCompact = width < 126;
    final hideLabel = width < 108;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPressStart:
          onLongPressStart == null ? null : (_) => onLongPressStart!(),
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressEnd: onLongPressEnd == null ? null : (_) => onLongPressEnd!(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.86)
                : Colors.white.withOpacity(0.04),
            width: isSelected ? 1.6 : 0.95,
          ),
          boxShadow: [
            if (isDragged)
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            if (isSelected)
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 0.3,
              ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: FxPalette.textMuted,
                  ),
                  if (!hideLabel) ...[
                    SizedBox(width: isCompact ? 4 : 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FxPalette.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Positioned.fill(
                child: IgnorePointer(
                  child: _TimelineSelectedPulse(
                    borderRadius: BorderRadius.circular(6),
                    accentColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSelectedPulse extends StatefulWidget {
  const _TimelineSelectedPulse({
    required this.borderRadius,
    required this.accentColor,
  });

  final BorderRadius borderRadius;
  final Color accentColor;

  @override
  State<_TimelineSelectedPulse> createState() => _TimelineSelectedPulseState();
}

class _TimelineSelectedPulseState extends State<_TimelineSelectedPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1680),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return CustomPaint(
          painter: _TimelineSelectedPulsePainter(
            progress: t,
            borderRadius: widget.borderRadius,
            accentColor: widget.accentColor,
          ),
        );
      },
    );
  }
}

class _TimelineSelectedPulsePainter extends CustomPainter {
  const _TimelineSelectedPulsePainter({
    required this.progress,
    required this.borderRadius,
    required this.accentColor,
  });

  final double progress;
  final BorderRadius borderRadius;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    final strokeRect = rect.deflate(0.85);
    final rrect = borderRadius.toRRect(strokeRect);
    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation((math.pi * 2 * progress) - (math.pi / 2)),
      colors: [
        Colors.transparent,
        accentColor.withOpacity(0.0),
        accentColor.withOpacity(0.08),
        accentColor.withOpacity(0.95),
        accentColor.withOpacity(0.1),
        Colors.transparent,
      ],
      stops: const [0.0, 0.56, 0.74, 0.84, 0.92, 1.0],
    );
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5)
      ..shader = sweep.createShader(rect);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..shader = sweep.createShader(rect);
    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TimelineSelectedPulsePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.accentColor != accentColor;
  }
}

class _TransitionBridge extends StatelessWidget {
  const _TransitionBridge({
    this.hasAttachedTransition = false,
    this.isActive = false,
  });

  final bool hasAttachedTransition;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final baseFill = hasAttachedTransition
        ? Colors.white.withOpacity(0.22)
        : Colors.white.withOpacity(0.1);
    final baseStroke = hasAttachedTransition
        ? Colors.white.withOpacity(0.72)
        : Colors.white.withOpacity(0.38);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: baseFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive ? FxPalette.accent.withOpacity(0.92) : baseStroke,
          width: isActive ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? FxPalette.accent.withOpacity(0.44)
                : Colors.white.withOpacity(0.14),
            blurRadius: isActive ? 10 : 4,
            spreadRadius: isActive ? 1 : 0,
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 1.35,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 1.35,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCutSeam extends StatelessWidget {
  const _TimelineCutSeam();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.0),
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.36),
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 1.4,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineRulerPainter extends CustomPainter {
  static const double _labelVisualLift = 2.25;

  const _TimelineRulerPainter({
    required this.readoutText,
    required this.readoutWidth,
    required this.gapWidth,
    required this.scrollOffset,
    required this.playheadLeft,
    required this.viewportWidth,
    required this.secondsWidth,
    required this.durationSeconds,
    required this.timeDisplayOffsetSeconds,
    required this.fps,
    required this.mode,
    required this.labelTopInset,
    required this.labelTextStyle,
  });

  final String readoutText;
  final double readoutWidth;
  final double gapWidth;
  final double scrollOffset;
  final double playheadLeft;
  final double viewportWidth;
  final double secondsWidth;
  final double durationSeconds;
  final double timeDisplayOffsetSeconds;
  final double fps;
  final _TimelineRulerMode mode;
  final double labelTopInset;
  final TextStyle labelTextStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final readoutPainter = _layoutLabel(readoutText, labelTextStyle);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, readoutWidth, size.height));
    readoutPainter.paint(
      canvas,
      Offset(0, _labelTop(size, readoutPainter)),
    );
    canvas.restore();

    final rulerOriginX = readoutWidth + gapWidth;
    final rulerWidth = math.max(0.0, size.width - rulerOriginX);
    if (rulerWidth <= 0) {
      return;
    }

    canvas.save();
    canvas.translate(rulerOriginX, 0);
    final rulerSize = Size(rulerWidth, size.height);
    final transform = _TimelineViewportTransform(
      scrollOffset: scrollOffset,
      playheadLeft: playheadLeft,
      secondsWidth: secondsWidth,
      durationSeconds: durationSeconds,
    );
    final textStyle = labelTextStyle;
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final frameDotPaint = Paint()..style = PaintingStyle.fill;
    final visibleStart = transform.secondsForX(
      -_TimelineRulerCanonicalProfile.viewportOverscanPx,
    );
    final visibleEnd = transform.secondsForX(
      rulerSize.width + _TimelineRulerCanonicalProfile.viewportOverscanPx,
    );

    switch (mode) {
      case _TimelineRulerMode.coarseSeconds:
        const spec = _TimelineRulerCanonicalProfile.coarseSecondsSpec;
        _paintSecondMode(
          canvas,
          rulerSize,
          transform,
          textStyle,
          dotPaint,
          visibleStart: visibleStart,
          visibleEnd: visibleEnd,
          minLabelSpacingPx: spec.minLabelSpacingPx,
          minStepSeconds: spec.minStepSeconds,
          preserveBoundaryLabels: spec.preserveBoundaryLabels,
        );
        break;
      case _TimelineRulerMode.normalSeconds:
        const spec = _TimelineRulerCanonicalProfile.normalSecondsSpec;
        _paintSecondMode(
          canvas,
          rulerSize,
          transform,
          textStyle,
          dotPaint,
          visibleStart: visibleStart,
          visibleEnd: visibleEnd,
          minLabelSpacingPx: spec.minLabelSpacingPx,
          minStepSeconds: spec.minStepSeconds,
        );
        break;
      case _TimelineRulerMode.secondsAndFrames:
        _paintSecondsAndFramesMode(
          canvas,
          rulerSize,
          transform,
          textStyle,
          dotPaint,
          visibleStart: visibleStart,
          visibleEnd: visibleEnd,
        );
        break;
      case _TimelineRulerMode.fineFrames:
        _paintFineFrameMode(
          canvas,
          rulerSize,
          transform,
          textStyle,
          dotPaint,
          frameDotPaint,
          visibleStart: visibleStart,
          visibleEnd: visibleEnd,
        );
        break;
    }
    canvas.restore();
  }

  void _paintSecondMode(
    Canvas canvas,
    Size size,
    _TimelineViewportTransform transform,
    TextStyle textStyle,
    Paint dotPaint, {
    required double visibleStart,
    required double visibleEnd,
    required double minLabelSpacingPx,
    required double minStepSeconds,
    bool preserveBoundaryLabels = false,
  }) {
    final labelStepSeconds = _TimelineRulerCanonicalProfile.pickNiceSecondStep(
      minSeconds: math.max(
        minStepSeconds,
        minLabelSpacingPx / secondsWidth,
      ),
    );
    final firstIndex =
        math.max(0, (visibleStart / labelStepSeconds).floor() - 1);
    final lastIndex = (visibleEnd / labelStepSeconds).ceil() + 1;
    final labelCandidates = <_TimelineRulerLabelCandidate>[];
    final seenKeys = <String>{};
    for (var index = firstIndex; index <= lastIndex; index++) {
      final seconds = index * labelStepSeconds;
      if (seconds >
          durationSeconds +
              _TimelineRulerCanonicalProfile.durationBoundaryEpsilonSeconds) {
        break;
      }
      final x = transform.xForSeconds(seconds);
      if (x < -_TimelineRulerCanonicalProfile.secondModeVisibleLabelMarginPx ||
          x >
              size.width +
                  _TimelineRulerCanonicalProfile
                      .secondModeVisibleLabelMarginPx) {
        continue;
      }
      final key = seconds.toStringAsFixed(3);
      if (seenKeys.add(key)) {
        labelCandidates.add(
          _TimelineRulerLabelCandidate(
            label: _formatWholeTime(seconds),
            centerX: x,
            priority:
                _TimelineRulerCanonicalProfile.secondModeWholeLabelPriority,
          ),
        );
      }
      if (index == lastIndex) {
        continue;
      }
    }
    final placements = _resolveLabelPlacements(
      labelCandidates,
      size,
      textStyle,
      minGap: _TimelineRulerCanonicalProfile.secondModeLabelMinGap,
      fixedPlacements: preserveBoundaryLabels
          ? _buildBoundaryPlacements(
              size,
              transform,
              textStyle,
            )
          : const <_TimelineRulerLabelPlacement>[],
    );
    _paintSelectedLabels(
      canvas,
      size,
      placements,
    );
    _paintInterLabelDots(
      canvas,
      size,
      placements,
      dotPaint,
      baseOpacity: _TimelineRulerCanonicalProfile.secondModeDotOpacity,
      radius: _TimelineRulerCanonicalProfile.secondModeDotRadius,
    );
  }

  void _paintSecondsAndFramesMode(
    Canvas canvas,
    Size size,
    _TimelineViewportTransform transform,
    TextStyle textStyle,
    Paint dotPaint, {
    required double visibleStart,
    required double visibleEnd,
  }) {
    const secondStep =
        _TimelineRulerCanonicalProfile.secondsAndFramesCanonicalSecondStep;
    final firstSecond = math.max(0, visibleStart.floor() - 1);
    final lastSecond = visibleEnd.ceil() + 1;
    final midpointFrames = _midpointFrameIndex();
    final labelCandidates = <_TimelineRulerLabelCandidate>[];
    final seenKeys = <String>{};
    _appendWholeSecondLabelCandidates(
      labelCandidates,
      seenKeys,
      transform,
      size,
      firstSecondIndex: firstSecond,
      lastSecondIndex: lastSecond,
      secondStepSeconds: secondStep,
    );

    for (var index = firstSecond; index <= lastSecond; index++) {
      final seconds = index.toDouble() * secondStep;
      if (seconds >
          durationSeconds +
              _TimelineRulerCanonicalProfile.durationBoundaryEpsilonSeconds) {
        break;
      }
      final frameMarkerSeconds = seconds +
          _TimelineRulerCanonicalProfile.secondsAndFramesFrameMarkerFraction;
      if (frameMarkerSeconds >
          durationSeconds +
              _TimelineRulerCanonicalProfile.durationBoundaryEpsilonSeconds) {
        continue;
      }
      final frameX = transform.xForSeconds(frameMarkerSeconds);
      if (frameX >
              _TimelineRulerCanonicalProfile
                  .secondsAndFramesFrameMarkerEdgeInsetPx &&
          frameX <
              size.width -
                  _TimelineRulerCanonicalProfile
                      .secondsAndFramesFrameMarkerEdgeInsetPx) {
        final key = 'f:${frameMarkerSeconds.toStringAsFixed(3)}';
        if (seenKeys.add(key)) {
          labelCandidates.add(
            _TimelineRulerLabelCandidate(
              label: '${midpointFrames}f',
              centerX: frameX,
              priority: _TimelineRulerCanonicalProfile
                  .secondsAndFramesFrameLabelPriority,
            ),
          );
        }
      }
    }
    final placements = _resolveLabelPlacements(
      labelCandidates,
      size,
      textStyle,
      minGap: _TimelineRulerCanonicalProfile.secondsAndFramesLabelMinGap,
      fixedPlacements: _buildBoundaryPlacements(
        size,
        transform,
        textStyle,
      ),
    );
    _paintSelectedLabels(
      canvas,
      size,
      placements,
    );
    _paintInterLabelDots(
      canvas,
      size,
      placements,
      dotPaint,
      baseOpacity: _TimelineRulerCanonicalProfile.secondModeDotOpacity,
      radius: _TimelineRulerCanonicalProfile.secondModeDotRadius,
    );
  }

  void _paintFineFrameMode(
    Canvas canvas,
    Size size,
    _TimelineViewportTransform transform,
    TextStyle textStyle,
    Paint dotPaint,
    Paint frameDotPaint, {
    required double visibleStart,
    required double visibleEnd,
  }) {
    final resolvedFps = fps <= 0 ? 30.0 : fps;
    final pixelsPerFrame = secondsWidth / resolvedFps;
    final stepFrames = _pickNiceFrameStep(
      minFrames: math.max(
        1,
        (_TimelineRulerCanonicalProfile.fineFramesMinLabelSpacingPx /
                math.max(pixelsPerFrame, 0.001))
            .ceil(),
      ),
    );
    final startFrame = math.max(
      0,
      (((visibleStart * resolvedFps).floor()) ~/ stepFrames) * stepFrames,
    );
    final endFrame = ((visibleEnd * resolvedFps).ceil()) + stepFrames;
    final labelCandidates = <_TimelineRulerLabelCandidate>[];
    final seenKeys = <String>{};
    final wholeSecondAnchorStep = _pickWholeSecondAnchorStep(
      minLabelSpacingPx: _TimelineRulerCanonicalProfile
          .fineFramesWholeSecondAnchorMinSpacingPx,
      minStepSeconds: _TimelineRulerCanonicalProfile
          .fineFramesWholeSecondAnchorMinStepSeconds,
    );
    final firstWholeSecondIndex = math.max(
      0,
      (visibleStart / wholeSecondAnchorStep).floor() - 1,
    );
    final lastWholeSecondIndex =
        (visibleEnd / wholeSecondAnchorStep).ceil() + 1;
    _appendWholeSecondLabelCandidates(
      labelCandidates,
      seenKeys,
      transform,
      size,
      firstSecondIndex: firstWholeSecondIndex,
      lastSecondIndex: lastWholeSecondIndex,
      secondStepSeconds: wholeSecondAnchorStep,
    );
    for (var totalFrames = startFrame;
        totalFrames <= endFrame;
        totalFrames += stepFrames) {
      final timeSeconds = totalFrames / resolvedFps;
      if (timeSeconds >
          durationSeconds +
              (_TimelineRulerCanonicalProfile
                      .fineFramesDurationToleranceFrames /
                  resolvedFps)) {
        break;
      }
      final x = transform.xForSeconds(timeSeconds);
      if (x < -_TimelineRulerCanonicalProfile.fineFramesVisibleLabelMarginPx ||
          x >
              size.width +
                  _TimelineRulerCanonicalProfile
                      .fineFramesVisibleLabelMarginPx) {
        continue;
      }
      final frameInSecond = _frameIndexWithinSecond(timeSeconds);
      if (frameInSecond == 0) {
        continue;
      }
      labelCandidates.add(
        _TimelineRulerLabelCandidate(
          label: '${frameInSecond}f',
          centerX: x,
          priority: _TimelineRulerCanonicalProfile.fineFramesFrameLabelPriority,
        ),
      );
    }
    final placements = _resolveLabelPlacements(
      labelCandidates,
      size,
      textStyle,
      minGap: _TimelineRulerCanonicalProfile.fineFramesLabelMinGap,
      fixedPlacements: _buildBoundaryPlacements(
        size,
        transform,
        textStyle,
      ),
    );
    _paintSelectedLabels(
      canvas,
      size,
      placements,
    );
    _paintInterLabelDots(
      canvas,
      size,
      placements,
      frameDotPaint,
      baseOpacity: _TimelineRulerCanonicalProfile.fineFramesDotOpacity,
      radius: _TimelineRulerCanonicalProfile.fineFramesDotRadius,
    );
  }

  void _appendWholeSecondLabelCandidates(
    List<_TimelineRulerLabelCandidate> labelCandidates,
    Set<String> seenKeys,
    _TimelineViewportTransform transform,
    Size size, {
    required int firstSecondIndex,
    required int lastSecondIndex,
    required double secondStepSeconds,
  }) {
    for (var index = firstSecondIndex; index <= lastSecondIndex; index++) {
      final seconds = index.toDouble() * secondStepSeconds;
      if (seconds >
          durationSeconds +
              _TimelineRulerCanonicalProfile.durationBoundaryEpsilonSeconds) {
        break;
      }
      final secondX = transform.xForSeconds(seconds);
      if (secondX <
              -_TimelineRulerCanonicalProfile.wholeSecondLabelVisibleMarginPx ||
          secondX >
              size.width +
                  _TimelineRulerCanonicalProfile
                      .wholeSecondLabelVisibleMarginPx) {
        continue;
      }
      final key = 's:${seconds.toStringAsFixed(3)}';
      if (seenKeys.add(key)) {
        labelCandidates.add(
          _TimelineRulerLabelCandidate(
            label: _formatWholeTime(seconds),
            centerX: secondX,
            priority: _TimelineRulerCanonicalProfile.wholeSecondLabelPriority,
          ),
        );
      }
    }
  }

  void _paintSelectedLabels(
    Canvas canvas,
    Size size,
    List<_TimelineRulerLabelPlacement> placements,
  ) {
    for (final placement in placements) {
      placement.painter.paint(
        canvas,
        Offset(placement.left, _labelTop(size, placement.painter)),
      );
    }
  }

  void _paintInterLabelDots(
    Canvas canvas,
    Size size,
    List<_TimelineRulerLabelPlacement> placements,
    Paint dotPaint, {
    required double baseOpacity,
    required double radius,
  }) {
    if (placements.length < 2) {
      return;
    }
    final dotY = ((size.height / 2) + 0.5 - _labelVisualLift)
        .clamp(0.0, size.height)
        .toDouble();
    for (var index = 0; index < placements.length - 1; index++) {
      final current = placements[index];
      final next = placements[index + 1];
      final gap = next.left - current.right;
      if (gap < _TimelineRulerCanonicalProfile.interLabelDotMinGapPx) {
        continue;
      }
      final dotX = current.right + (gap / 2);
      final opacity = _edgeOpacity(dotX, size.width);
      if (opacity <= _TimelineRulerCanonicalProfile.interLabelDotMinOpacity) {
        continue;
      }
      dotPaint.color = Colors.white.withOpacity(baseOpacity * opacity);
      canvas.drawCircle(Offset(dotX, dotY), radius, dotPaint);
    }
  }

  List<_TimelineRulerLabelPlacement> _resolveLabelPlacements(
    List<_TimelineRulerLabelCandidate> candidates,
    Size size,
    TextStyle baseStyle, {
    required double minGap,
    List<_TimelineRulerLabelPlacement> fixedPlacements = const [],
  }) {
    final placements = <_TimelineRulerLabelPlacement>[];
    final baseColor = baseStyle.color ?? Colors.white;
    const safeLeft = _TimelineRulerCanonicalProfile.labelPlacementSafeInsetPx;
    final safeRight =
        size.width - _TimelineRulerCanonicalProfile.labelPlacementSafeInsetPx;
    for (final candidate in candidates) {
      final opacity = _edgeOpacity(candidate.centerX, size.width);
      if (opacity <= 0.04) {
        continue;
      }
      final painter = _layoutLabel(
        candidate.label,
        baseStyle.copyWith(
          color: baseColor.withOpacity(baseColor.opacity * opacity),
        ),
      );
      final left = candidate.centerX - (painter.width / 2);
      final right = candidate.centerX + (painter.width / 2);
      if (left < safeLeft || right > safeRight) {
        continue;
      }
      placements.add(
        _TimelineRulerLabelPlacement(
          candidate: candidate,
          painter: painter,
          left: left,
          right: right,
        ),
      );
    }

    placements.sort((a, b) {
      final priorityOrder =
          b.candidate.priority.compareTo(a.candidate.priority);
      if (priorityOrder != 0) {
        return priorityOrder;
      }
      return a.left.compareTo(b.left);
    });

    final selected = <_TimelineRulerLabelPlacement>[...fixedPlacements];
    for (final placement in placements) {
      final overlaps = selected.any(
        (existing) =>
            placement.right + minGap > existing.left &&
            placement.left < existing.right + minGap,
      );
      if (!overlaps) {
        selected.add(placement);
      }
    }
    selected.sort((a, b) => a.left.compareTo(b.left));
    return selected;
  }

  List<_TimelineRulerLabelPlacement> _buildBoundaryPlacements(
    Size size,
    _TimelineViewportTransform transform,
    TextStyle baseStyle,
  ) {
    const inset = _TimelineRulerCanonicalProfile.boundaryPlacementInsetPx;
    final placements = <_TimelineRulerLabelPlacement>[];
    final startX = transform.xForSeconds(0);
    final startPlacement = _buildBoundaryPlacement(
      label: '__boundary_start__',
      displayLabel: _formatBoundaryTime(0),
      anchorX: startX,
      size: size,
      inset: inset,
      baseStyle: baseStyle,
      alignToStart: true,
    );
    if (startPlacement != null) {
      placements.add(startPlacement);
    }
    if (durationSeconds <= 0) {
      return placements;
    }
    final endX = transform.xForSeconds(durationSeconds);
    final endPlacement = _buildBoundaryPlacement(
      label: '__boundary_end__',
      displayLabel: _formatBoundaryTime(durationSeconds),
      anchorX: endX,
      size: size,
      inset: inset,
      baseStyle: baseStyle,
      alignToStart: false,
      centerX: durationSeconds,
    );
    if (endPlacement != null) {
      placements.add(endPlacement);
    }
    return placements;
  }

  _TimelineRulerLabelPlacement? _buildBoundaryPlacement({
    required String label,
    required String displayLabel,
    required double anchorX,
    required Size size,
    required double inset,
    required TextStyle baseStyle,
    required bool alignToStart,
    double? centerX,
  }) {
    if (anchorX < 0 || anchorX > size.width) {
      return null;
    }
    final opacity = _edgeOpacity(anchorX, size.width);
    if (opacity <= 0.04) {
      return null;
    }
    final baseColor = baseStyle.color ?? Colors.white;
    final painter = _layoutLabel(
      displayLabel,
      baseStyle.copyWith(
        color: baseColor.withOpacity(baseColor.opacity * opacity),
      ),
    );
    final unclampedLeft = alignToStart ? anchorX : anchorX - painter.width;
    final maxLeft = math.max(inset, size.width - inset - painter.width);
    final left = unclampedLeft.clamp(inset, maxLeft).toDouble();
    final right = left + painter.width;
    return _TimelineRulerLabelPlacement(
      candidate: _TimelineRulerLabelCandidate(
        label: label,
        centerX: centerX ?? anchorX,
        priority: _TimelineRulerCanonicalProfile.boundaryLabelPriority,
      ),
      painter: painter,
      left: left,
      right: right,
    );
  }

  double _edgeOpacity(double centerX, double width) {
    const safeInset = _TimelineRulerCanonicalProfile.edgeFadeSafeInsetPx;
    const fadeDistance = _TimelineRulerCanonicalProfile.edgeFadeDistancePx;
    final leftFactor = ((centerX - safeInset) / fadeDistance).clamp(0.0, 1.0);
    final rightFactor =
        (((width - safeInset) - centerX) / fadeDistance).clamp(0.0, 1.0);
    return math.min(leftFactor, rightFactor);
  }

  double _labelTop(Size size, TextPainter painter) {
    return (labelTopInset - _labelVisualLift)
        .clamp(0.0, math.max(0.0, size.height - painter.height))
        .toDouble();
  }

  TextPainter _layoutLabel(String label, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  int _pickNiceFrameStep({required int minFrames}) {
    for (final step in _TimelineRulerCanonicalProfile.niceFrameSteps) {
      if (step >= minFrames) {
        return step;
      }
    }
    return _TimelineRulerCanonicalProfile.niceFrameSteps.last;
  }

  double _pickWholeSecondAnchorStep({
    required double minLabelSpacingPx,
    required double minStepSeconds,
  }) {
    return _TimelineRulerCanonicalProfile.pickNiceSecondStep(
      minSeconds: math.max(
        minStepSeconds,
        minLabelSpacingPx / math.max(secondsWidth, 0.001),
      ),
    );
  }

  int _midpointFrameIndex() {
    final resolvedFps = fps <= 0 ? 30.0 : fps;
    final fpsInt = math.max(1, resolvedFps.round());
    return ((resolvedFps *
                _TimelineRulerCanonicalProfile
                    .secondsAndFramesFrameMarkerFraction)
            .round())
        .clamp(1, math.max(1, fpsInt - 1));
  }

  int _frameIndexWithinSecond(double timeSeconds) {
    final remainderSeconds = timeSeconds - timeSeconds.floorToDouble();
    final frameValue = (remainderSeconds * fps).round();
    final maxFrameValue = math.max(1, fps.ceil());
    if (frameValue <= 0 || frameValue >= maxFrameValue) {
      return 0;
    }
    return frameValue;
  }

  String _formatWholeTime(double secondsValue) {
    final totalSeconds =
        (secondsValue + timeDisplayOffsetSeconds).round().clamp(0, 359999);
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatBoundaryTime(double secondsValue) {
    final clampedSeconds = secondsValue.clamp(0, 359999).toDouble();
    switch (mode) {
      case _TimelineRulerMode.fineFrames:
      case _TimelineRulerMode.secondsAndFrames:
        return _formatBoundaryFrameAwareTime(clampedSeconds);
      case _TimelineRulerMode.coarseSeconds:
      case _TimelineRulerMode.normalSeconds:
        return _formatPreciseBoundaryTime(clampedSeconds);
    }
  }

  String _formatBoundaryFrameAwareTime(double secondsValue) {
    final resolvedFps = fps <= 0 ? 30.0 : fps;
    final framePosition = secondsValue * resolvedFps;
    final nearestFrame = framePosition.roundToDouble();
    if ((framePosition - nearestFrame).abs() <=
        _TimelineRulerCanonicalProfile.preciseBoundaryFrameEpsilon) {
      return _formatFrameTime(secondsValue);
    }
    return _formatPreciseBoundaryTime(secondsValue);
  }

  String _formatPreciseBoundaryTime(double secondsValue) {
    final absoluteSeconds = secondsValue + timeDisplayOffsetSeconds;
    final roundedWholeSeconds = absoluteSeconds.roundToDouble();
    if ((absoluteSeconds - roundedWholeSeconds).abs() <=
        _TimelineRulerCanonicalProfile.preciseBoundaryWholeSecondEpsilon) {
      return _formatWholeTime(secondsValue);
    }

    final totalMilliseconds =
        (absoluteSeconds * 1000).round().clamp(0, 359999999);
    final wholeSeconds = totalMilliseconds ~/ 1000;
    final millis = totalMilliseconds % 1000;
    final mins = wholeSeconds ~/ 60;
    final secs = wholeSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }

  String _formatFrameTime(double secondsValue) {
    final resolvedFps = fps <= 0 ? 30.0 : fps;
    final totalFrames =
        ((secondsValue + timeDisplayOffsetSeconds) * resolvedFps).round();
    final fpsInt = math.max(1, resolvedFps.round());
    final wholeSeconds = totalFrames ~/ fpsInt;
    final frames = totalFrames % fpsInt;
    final mins = wholeSeconds ~/ 60;
    final secs = wholeSeconds % 60;
    if (frames == 0) {
      return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}:${frames.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.readoutText != readoutText ||
        oldDelegate.readoutWidth != readoutWidth ||
        oldDelegate.gapWidth != gapWidth ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.playheadLeft != playheadLeft ||
        oldDelegate.viewportWidth != viewportWidth ||
        oldDelegate.secondsWidth != secondsWidth ||
        oldDelegate.durationSeconds != durationSeconds ||
        oldDelegate.timeDisplayOffsetSeconds != timeDisplayOffsetSeconds ||
        oldDelegate.fps != fps ||
        oldDelegate.mode != mode ||
        oldDelegate.labelTopInset != labelTopInset ||
        oldDelegate.labelTextStyle != labelTextStyle;
  }
}

enum _TimelineRulerMode {
  coarseSeconds,
  normalSeconds,
  secondsAndFrames,
  fineFrames,
}

class _TimelineRulerLabelCandidate {
  const _TimelineRulerLabelCandidate({
    required this.label,
    required this.centerX,
    required this.priority,
  });

  final String label;
  final double centerX;
  final int priority;
}

class _TimelineRulerLabelPlacement {
  const _TimelineRulerLabelPlacement({
    required this.candidate,
    required this.painter,
    required this.left,
    required this.right,
  });

  final _TimelineRulerLabelCandidate candidate;
  final TextPainter painter;
  final double left;
  final double right;
}

class _TimelineViewportTransform {
  const _TimelineViewportTransform({
    required this.scrollOffset,
    required this.playheadLeft,
    required this.secondsWidth,
    required this.durationSeconds,
  });

  final double scrollOffset;
  final double playheadLeft;
  final double secondsWidth;
  final double durationSeconds;

  double secondsForX(double x) {
    return ((scrollOffset + x - playheadLeft) / secondsWidth)
        .clamp(0.0, durationSeconds)
        .toDouble();
  }

  double xForSeconds(double seconds) {
    return playheadLeft + (seconds * secondsWidth) - scrollOffset;
  }
}
