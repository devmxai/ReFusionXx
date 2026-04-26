import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/engine/live_scrub_preview_sources.dart';
import '../../../../core/engine/stage5_native_transport_controller.dart';
import '../../../../core/engine/stage6_export_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/export_composition_builder.dart';
import '../../domain/models/export_composition_models.dart';
import '../../domain/models/export_motion_text_program_models.dart';
import '../../domain/models/export_output_profile.dart';
import '../../domain/models/professional_canvas_timeline_authoring_models.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_compilation_models.dart';
import '../../domain/models/professional_motion_evaluation_models.dart';
import '../../domain/models/professional_motion_fx_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/models/professional_motion_runtime_helpers.dart';
import '../../domain/models/professional_motion_text_authoring_models.dart';
import '../../domain/models/professional_motion_text_keyframe_authoring_models.dart';
import '../../domain/models/professional_motion_text_models.dart';
import '../../domain/models/professional_motion_text_preview_models.dart';
import '../../domain/models/professional_motion_text_render_models.dart';
import '../../domain/models/professional_motion_text_runtime_helpers.dart';
import '../../domain/models/professional_normal_transition_models.dart';
import '../../domain/services/ai_transition/kie_ai_transition_service.dart';
import '../../domain/services/normal_transition_command_history.dart';
import '../../domain/services/scoped_text_motion_script_import_service.dart';
import '../../domain/services/timeline_clock_coordinator.dart';
import '../models/ai_transition_models.dart';
import '../models/editor_asset_item.dart';
import '../models/editor_media_tab.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import '../services/layer_scope_motion_authoring_adapter.dart';
import '../services/normal_transition_timeline_authoring_adapter.dart';
import '../services/normal_transition_script_timeline_mapper.dart';
import '../widgets/editor_tools_bar.dart';
import '../widgets/editor_top_bar.dart';
import '../widgets/animate_browser_bottom_sheet.dart';
import '../widgets/ai_transition_bottom_sheet.dart';
import '../widgets/clip_speed_bottom_sheet.dart';
import '../widgets/export_bottom_sheet.dart';
import '../widgets/fx_icon_button.dart';
import '../widgets/layer_scope_graph_bottom_sheet.dart';
import '../widgets/layer_scope_keyframe_dock.dart';
import '../widgets/layer_scope_value_bottom_sheet.dart';
import '../widgets/media_bottom_sheet.dart';
import '../widgets/media_dock.dart';
import '../widgets/motion_text_preview_overlay.dart';
import '../widgets/motion_text_transform_overlay.dart';
import '../widgets/native_timeline_scrub_surface.dart';
import '../widgets/native_preview_surface.dart';
import '../widgets/preview_stage.dart';
import '../widgets/scoped_text_motion_script_bottom_sheet.dart';
import '../widgets/text_clip_edit_bottom_sheet.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/timeline_transition_preview_overlay.dart';
import '../widgets/transition_browser_bottom_sheet.dart';
import '../widgets/transition_focus_panel.dart';
import '../widgets/transition_inspector_bottom_sheet.dart';
import '../widgets/transition_script_import_bottom_sheet.dart';
import '../widgets/text_preset_bottom_sheet.dart';

class FusionXCleanUiScreen extends StatefulWidget {
  const FusionXCleanUiScreen({super.key});

  @override
  State<FusionXCleanUiScreen> createState() => _FusionXCleanUiScreenState();
}

class _FusionXCleanUiScreenState extends State<FusionXCleanUiScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _minEditableClipDuration = 0.25;
  static const int _deviceMediaPageSize = 24;
  static const String _motionProjectId = 'motion-project';
  static const String _motionSceneId = 'scene-main';
  static const String _exportContractVersion = 'v1alpha1';
  static const String _normalTransitionVideoTrackId = 'video-main';
  static const int _playbackStartPositionToleranceMs = 24;
  static const NormalTransitionTimelineAuthoringAdapter
      _normalTransitionAuthoringAdapter =
      NormalTransitionTimelineAuthoringAdapter();
  static const NormalTransitionScriptTimelineMapper
      _normalTransitionScriptTimelineMapper =
      NormalTransitionScriptTimelineMapper();
  static final TimelineTime _manualTransitionScopeSideTime =
      TimelineTime.fromSecondsDouble(10);
  static const bool _textPresetPickerEnabled = false;
  static const String _defaultInsertedTextValue = 'Text';
  static const double _defaultInsertedTextFontSize = 56;
  static const bool _timelineClockCoordinatorOwnsPlaybackSamples = true;
  static const double _motionPreviewClockResyncThresholdSeconds = 0.08;
  static const MotionInterpolationSpec _afterEffectsEasyEaseInterpolation =
      MotionInterpolationSpec.cubicBezier(
    bezier: MotionBezierControlPoints(
      x1: 0.3333,
      y1: 0.0,
      x2: 0.6667,
      y2: 1.0,
    ),
  );
  static final TimelineTime _defaultTextPresetDurationTime =
      TimelineTime.fromSecondsDouble(3);
  static const List<AnimateBrowserItem> _manualTransitionAnimateItems =
      <AnimateBrowserItem>[
    AnimateBrowserItem(
      id: 'outgoingBoostScale',
      label: 'Outgoing Scale',
      category: 'Animate',
      summary: 'Push the outgoing clip forward before the handoff.',
      keywords: <String>['zoom out', 'scale', 'push'],
    ),
    AnimateBrowserItem(
      id: 'incomingStartScale',
      label: 'Incoming Scale',
      category: 'Animate',
      summary: 'Start the incoming clip close, then relax to full frame.',
      keywords: <String>['zoom in', 'scale', 'size'],
    ),
    AnimateBrowserItem(
      id: 'outgoingOffsetX',
      label: 'Outgoing Slide X',
      category: 'Animate',
      summary: 'Move the outgoing clip horizontally through the seam.',
      keywords: <String>['push', 'slide', 'position', 'x'],
    ),
    AnimateBrowserItem(
      id: 'incomingOffsetX',
      label: 'Incoming Slide X',
      category: 'Animate',
      summary: 'Bring the incoming clip from the side.',
      keywords: <String>['push', 'slide', 'position', 'x'],
    ),
    AnimateBrowserItem(
      id: 'outgoingOffsetY',
      label: 'Outgoing Slide Y',
      category: 'Animate',
      summary: 'Move the outgoing clip vertically through the seam.',
      keywords: <String>['push', 'slide', 'position', 'y'],
    ),
    AnimateBrowserItem(
      id: 'incomingOffsetY',
      label: 'Incoming Slide Y',
      category: 'Animate',
      summary: 'Bring the incoming clip from above or below.',
      keywords: <String>['push', 'slide', 'position', 'y'],
    ),
    AnimateBrowserItem(
      id: 'outgoingRotation',
      label: 'Outgoing Rotation',
      category: 'Animate',
      summary: 'Rotate the outgoing clip during the handoff.',
      keywords: <String>['rotate', 'rotation', 'angle'],
    ),
    AnimateBrowserItem(
      id: 'incomingRotation',
      label: 'Incoming Rotation',
      category: 'Animate',
      summary: 'Rotate the incoming clip into place.',
      keywords: <String>['rotate', 'rotation', 'angle'],
    ),
    AnimateBrowserItem(
      id: 'entryDelay',
      label: 'Entry Delay',
      category: 'Animate',
      summary: 'Delay when the incoming clip starts taking over.',
      keywords: <String>['timing', 'delay', 'handoff'],
    ),
  ];
  static const List<AnimateBrowserItem> _manualTransitionFxItems =
      <AnimateBrowserItem>[
    AnimateBrowserItem(
      id: 'blackPeak',
      label: 'Black Mix',
      category: 'FX',
      summary: 'Dip through black around the seam midpoint.',
      keywords: <String>['fade', 'opacity', 'black'],
    ),
    AnimateBrowserItem(
      id: 'bridgeDarkness',
      label: 'Bridge Darkness',
      category: 'FX',
      summary: 'Add a dark cinematic bridge between the two clips.',
      keywords: <String>['dark', 'bridge', 'shade'],
    ),
    AnimateBrowserItem(
      id: 'whiteFlash',
      label: 'White Flash',
      category: 'FX',
      summary: 'Flash through white at the seam.',
      keywords: <String>['flash', 'white', 'light'],
    ),
    AnimateBrowserItem(
      id: 'blurAmount',
      label: 'Blur Amount',
      category: 'FX',
      summary: 'Blur the seam to hide fast motion.',
      keywords: <String>['blur', 'soft', 'motion'],
    ),
    AnimateBrowserItem(
      id: 'outgoingOpacity',
      label: 'Outgoing Opacity',
      category: 'FX',
      summary: 'Fade the outgoing clip with editable keyframes.',
      keywords: <String>['opacity', 'fade', 'alpha'],
    ),
    AnimateBrowserItem(
      id: 'incomingOpacity',
      label: 'Incoming Opacity',
      category: 'FX',
      summary: 'Fade the incoming clip with editable keyframes.',
      keywords: <String>['opacity', 'fade', 'alpha'],
    ),
  ];
  static const List<AnimateBrowserItem> _scopedLayerCoreAnimateItems =
      <AnimateBrowserItem>[
    AnimateBrowserItem(
      id: 'opacity',
      label: 'Opacity',
      category: 'Animate',
      summary: 'Animate layer transparency with keyframes.',
      keywords: <String>['fade', 'alpha', 'transparency'],
    ),
    AnimateBrowserItem(
      id: 'position',
      label: 'Position',
      category: 'Animate',
      summary: 'Animate layer movement on X and Y.',
      keywords: <String>['move', 'x', 'y', 'translate'],
    ),
    AnimateBrowserItem(
      id: 'scale',
      label: 'Scale',
      category: 'Animate',
      summary: 'Animate layer size on X and Y.',
      keywords: <String>['scale', 'size', 'zoom', 'resize'],
    ),
    AnimateBrowserItem(
      id: 'rotation',
      label: 'Rotation',
      category: 'Animate',
      summary: 'Animate layer angle over time.',
      keywords: <String>['rotate', 'angle', 'spin', 'turn'],
    ),
  ];
  static const List<AnimateBrowserItem> _scopedTextAnimateItems =
      <AnimateBrowserItem>[
    ..._scopedLayerCoreAnimateItems,
    AnimateBrowserItem(
      id: 'text_effect.type_on',
      label: 'Type On',
      category: 'Text',
      summary: 'Reveal text letter by letter over the layer timeline.',
      keywords: <String>['typewriter', 'letter', 'reveal', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.word_reveal',
      label: 'Word Reveal',
      category: 'Text',
      summary: 'Reveal words progressively across the selected text layer.',
      keywords: <String>['word', 'words', 'reveal', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.letter_reveal',
      label: 'Letter Reveal',
      category: 'Text',
      summary: 'Reveal letters with a clean per-character progression.',
      keywords: <String>['letter', 'letters', 'character', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.bounce_in',
      label: 'Bounce In',
      category: 'Text',
      summary: 'Bring text in with a readable bounce, scale, and rise.',
      keywords: <String>['bounce', 'boing', 'pop', 'scale', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.rise_in',
      label: 'Rise In',
      category: 'Text',
      summary: 'Lift text into place with a soft spring finish.',
      keywords: <String>['rise', 'up', 'spring', 'position', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.slide_in',
      label: 'Slide In',
      category: 'Text',
      summary: 'Slide text horizontally into the frame with a settled finish.',
      keywords: <String>['slide', 'left', 'right', 'spring', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.word_rise_in',
      label: 'Word Rise In',
      category: 'Text',
      summary: 'Reveal words while the line rises gently into place.',
      keywords: <String>['word', 'reveal', 'rise', 'headline', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.letter_pop_in',
      label: 'Letter Pop In',
      category: 'Text',
      summary: 'Pop letters in with per-character reveal and scale settle.',
      keywords: <String>['letter', 'character', 'pop', 'reveal', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.word_cascade',
      label: 'Word Cascade',
      category: 'Text',
      summary: 'Cascade words into view with reveal, lift, and soft focus.',
      keywords: <String>['word', 'cascade', 'reveal', 'stagger', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.letter_bounce',
      label: 'Letter Bounce',
      category: 'Text',
      summary: 'Reveal letters with bounce, scale, and lift.',
      keywords: <String>['letter', 'bounce', 'character', 'scale', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.slide_blur_in',
      label: 'Slide Blur In',
      category: 'Text FX',
      summary: 'Slide text in while blur resolves into crisp focus.',
      keywords: <String>['slide', 'blur', 'focus', 'cinematic', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.blur_rise_in',
      label: 'Blur Rise In',
      category: 'Text FX',
      summary: 'Lift text in from soft blur to crisp focus.',
      keywords: <String>['blur', 'rise', 'focus', 'cinematic', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.rotate_in',
      label: 'Rotate In',
      category: 'Text',
      summary: 'Rotate and scale text into a settled lockup.',
      keywords: <String>['rotate', 'spin', 'scale', 'spring', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.blur_in',
      label: 'Blur In',
      category: 'Text FX',
      summary: 'Bring text in from soft blur to sharp focus.',
      keywords: <String>['blur', 'soft', 'focus', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.blur_out',
      label: 'Blur Out',
      category: 'Text FX',
      summary: 'Send text out through soft blur and opacity fade.',
      keywords: <String>['blur', 'fade', 'out', 'exit', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.scale_pop',
      label: 'Elastic Pop',
      category: 'Text',
      summary: 'Pop text scale with an elastic overshoot and settle.',
      keywords: <String>['scale', 'elastic', 'pop', 'spring', 'text'],
    ),
    AnimateBrowserItem(
      id: 'text_effect.tracking_settle',
      label: 'Tracking Settle',
      category: 'Text',
      summary: 'Settle wide letter spacing into a clean final text lockup.',
      keywords: <String>['tracking', 'letter spacing', 'spacing', 'text'],
    ),
  ];
  static const List<AnimateBrowserItem> _scopedImageAnimateItems =
      _scopedLayerCoreAnimateItems;
  static const List<AnimateBrowserItem> _scopedTextFxItems =
      <AnimateBrowserItem>[
    AnimateBrowserItem(
      id: 'gaussian_blur',
      label: 'Gaussian Blur',
      category: 'FX',
      summary: 'Soften the selected text layer with keyframeable blur.',
      keywords: <String>['blur', 'gaussian', 'soften', 'focus', 'defocus'],
    ),
  ];
  static const List<AnimateBrowserItem> _scopedImageFxItems =
      <AnimateBrowserItem>[];

  late final Stage5NativeTransportController _transportController;
  late final InMemoryLiveScrubPreviewSourceCatalog
      _liveScrubPreviewSourceCatalog;
  late final Stage6ExportController _exportController;
  late final KieAiTransitionService _aiTransitionService;
  late final NormalTransitionCommandHistoryController _normalTransitionHistory;
  late final ValueNotifier<List<EditorAssetItem>> _assetLibrary;
  late final ValueNotifier<bool> _assetLibraryLoading;
  late final ValueNotifier<String?> _assetLibraryError;
  late final ValueNotifier<TimelineTime> _timelineDisplayTimeNotifier;
  late final ValueNotifier<TimelineTime> _playbackSampleTimeNotifier;
  late final TimelineClockCoordinator _timelineClockCoordinator;
  late final ValueNotifier<TimelineTime> _transitionFocusDisplayTimeNotifier;
  late final ValueNotifier<TimelineTime>
      _transitionFocusPlaybackSampleTimeNotifier;
  late final ValueNotifier<TimelineTime> _layerScopeDisplayTimeNotifier;
  late final ValueNotifier<TimelineTime> _layerScopePlaybackSampleTimeNotifier;
  late final ValueNotifier<Uint8List?> _previewThumbnailNotifier;
  late final Ticker _motionPreviewFrameTicker;
  late final BasicMotionRuntimeEvaluator _motionEvaluator;
  late final BasicMotionTextRenderAdapter _motionTextRenderAdapter;
  final Map<String, EditorAssetItem> _importedAssetsById =
      <String, EditorAssetItem>{};
  final Map<String, Uint8List> _previewThumbnailCache = <String, Uint8List>{};
  final Map<EditorMediaTab, int> _assetOffsets = <EditorMediaTab, int>{};
  final Map<EditorMediaTab, bool> _assetHasMore = <EditorMediaTab, bool>{};
  final Set<EditorMediaTab> _assetPageRequestsInFlight = <EditorMediaTab>{};
  EditorMediaTab _activeTab = EditorMediaTab.video;
  List<TimelineTrackData> _tracks = const <TimelineTrackData>[];
  String? _selectedClipId;
  String? _selectedTransitionId;
  _TransitionFocusSession? _transitionFocusSession;
  _LayerScopeSession? _layerScopeSession;
  String? _selectedLayerScopeAnimationLaneId;
  int? _selectedLayerScopeKeyframeIndex;
  String? _selectedLayerScopeKeyframeId;
  int? _selectedTransitionFocusKeyframeIndex;
  String? _selectedTransitionFocusKeyframeId;
  bool _isLayerScopeValueEditorOpen = false;
  bool _isLayerScopeGraphEditorOpen = false;
  bool _isTransitionFocusValueEditorOpen = false;
  bool _isTransitionFocusGraphEditorOpen = false;
  String? _previewAssetId;
  PreviewViewportState _previewViewportState = PreviewViewportState.identity;
  double? _lockedWorkspaceAspectRatio;
  TimelineTime _currentTime = TimelineTime.zero;
  bool _isPlaying = false;
  bool _isTimelineScrubbing = false;
  bool _isTimelineScrubHandoffInFlight = false;
  TimelineTime? _timelineScrubHandoffTargetTime;
  int _timelineScrubHandoffRevision = 0;
  TimelineTime? _timelineZoomLockedDisplayTime;
  int _timelineZoomLockRevision = 0;
  bool _isAnimateBrowserOpen = false;
  TimelineTime? _timelineScrubFinalTime;
  bool _isApplyingStructuralEdit = false;
  Future<void> _timelineStructuralCommit = Future<void>.value();
  MotionProjectModel? _motionProject;
  List<MotionTextAnimationBindingModel> _motionTextAnimationBindings =
      const <MotionTextAnimationBindingModel>[];
  List<MotionPropertyChannelModel> _manualMotionPropertyChannels =
      const <MotionPropertyChannelModel>[];
  List<MotionTextPresetDefinition> _customTextPresets =
      const <MotionTextPresetDefinition>[];
  _ActiveTextEditSession? _textEditSession;
  _TextEditPreviewRange? _textEditPreviewRange;
  String? _activeTrimClipId;
  _TimelineTrimPreviewSession? _timelineTrimPreviewSession;
  String? _activeTrimPreviewSourceUri;
  int _timelineTrimPreviewRequestId = 0;
  bool _isStoppingTextEditPreviewPlayback = false;
  bool _isStoppingTransitionFocusPlayback = false;
  TimelineTime? _playbackStopTimeLock;
  int _playbackStopTimeLockRevision = 0;
  Timer? _playbackStopTimeLockTimer;
  MotionNormalizedComposition? _cachedMotionComposition;
  int _motionRevision = 0;
  int _motionPreviewWarmupRequestId = 0;
  int? _lastWarmedMotionRevision;
  Timer? _motionPreviewWarmupDebounce;
  int? _cachedMotionRevision;
  int? _cachedMotionTimelineDurationTicks;
  int? _cachedMotionCanvasWidth;
  int? _cachedMotionCanvasHeight;
  String? _lastExportStatusNotificationKey;
  MotionProjectModel? _cachedMotionTimelineProjectionProject;
  List<MotionTextAnimationBindingModel>?
      _cachedMotionTimelineProjectionBindings;
  int? _cachedMotionTimelineProjectionRevision;
  List<_MotionTextTimelineEntry>? _cachedMotionTimelineEntries;
  TimelineTrackData? _cachedMotionTimelineTrack;
  List<TimelineTrackData>? _cachedMotionTimelineBaseTracks;
  List<TimelineTrackData>? _cachedMotionDisplayTracks;
  String? _previewThumbnailAssetId;
  String? _previewThumbnailResolvedAssetId;
  int _previewThumbnailRequestId = 0;
  int _timelineScrubConfigRevision = 0;
  int _lastAppliedTimelineScrubConfigRevision = 0;
  int? _pendingTimelineScrubConfigTargetRevision;
  Completer<void>? _pendingTimelineScrubConfigCompleter;
  OverlayEntry? _topStageBannerEntry;
  Timer? _topStageBannerTimer;
  TimelineTime _motionPreviewClockAnchorTime = TimelineTime.zero;
  Duration _motionPreviewClockAnchorElapsed = Duration.zero;
  Duration _motionPreviewClockLatestElapsed = Duration.zero;
  Size? _lastPreviewStageSize;
  int _nativePreviewRecoveryRevision = 0;
  bool _isNativePreviewRecoveryScheduled = false;
  int _nativeTransitionEffectRevision = 0;
  double? _lastNativeTransitionBlurSigma;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final transportController = Stage5NativeTransportController();
    transportController.addListener(_handleTransportStateChanged);
    _transportController = transportController;
    _liveScrubPreviewSourceCatalog = InMemoryLiveScrubPreviewSourceCatalog();
    final exportController = Stage6ExportController();
    exportController.addListener(_handleExportStateChanged);
    _exportController = exportController;
    _aiTransitionService = KieAiTransitionService();
    unawaited(_aiTransitionService.ensureConfigured());
    _normalTransitionHistory = NormalTransitionCommandHistoryController();
    _motionEvaluator = const BasicMotionRuntimeEvaluator();
    _motionTextRenderAdapter = const BasicMotionTextRenderAdapter();
    _assetLibrary =
        ValueNotifier<List<EditorAssetItem>>(const <EditorAssetItem>[]);
    _assetLibraryLoading = ValueNotifier<bool>(false);
    _assetLibraryError = ValueNotifier<String?>(null);
    _timelineDisplayTimeNotifier = ValueNotifier<TimelineTime>(_currentTime);
    _playbackSampleTimeNotifier = ValueNotifier<TimelineTime>(_currentTime);
    _transitionFocusDisplayTimeNotifier =
        ValueNotifier<TimelineTime>(TimelineTime.zero);
    _transitionFocusPlaybackSampleTimeNotifier =
        ValueNotifier<TimelineTime>(TimelineTime.zero);
    _layerScopeDisplayTimeNotifier =
        ValueNotifier<TimelineTime>(TimelineTime.zero);
    _layerScopePlaybackSampleTimeNotifier =
        ValueNotifier<TimelineTime>(TimelineTime.zero);
    _previewThumbnailNotifier = ValueNotifier<Uint8List?>(null);
    _motionPreviewFrameTicker = createTicker(_handleMotionPreviewFrameTick);
    _assetOffsets[EditorMediaTab.video] = 0;
    _assetOffsets[EditorMediaTab.image] = 0;
    _assetHasMore[EditorMediaTab.video] = true;
    _assetHasMore[EditorMediaTab.image] = true;
    _tracks = _buildInitialTracks();
    _motionProject = _buildInitialMotionProject();
    _timelineClockCoordinator = TimelineClockCoordinator(
      timelineDuration: _timelineDurationTime,
      initialTime: _currentTime,
    );
    unawaited(_transportController.initialize());
    unawaited(_exportController.ensureInitialized());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissTopStageBanner();
    unawaited(
      _transportController.setPreviewTransitionEffects(blurSigma: 0),
    );
    _exportController
      ..removeListener(_handleExportStateChanged)
      ..dispose();
    _transportController
      ..removeListener(_handleTransportStateChanged)
      ..dispose();
    _assetLibrary.dispose();
    _assetLibraryLoading.dispose();
    _assetLibraryError.dispose();
    _motionPreviewWarmupDebounce?.cancel();
    _playbackStopTimeLockTimer?.cancel();
    _motionPreviewFrameTicker.dispose();
    _timelineClockCoordinator.dispose();
    _timelineDisplayTimeNotifier.dispose();
    _playbackSampleTimeNotifier.dispose();
    _transitionFocusDisplayTimeNotifier.dispose();
    _transitionFocusPlaybackSampleTimeNotifier.dispose();
    _layerScopeDisplayTimeNotifier.dispose();
    _layerScopePlaybackSampleTimeNotifier.dispose();
    _previewThumbnailNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _handleNativePreviewLifecycleSuspended();
        break;
      case AppLifecycleState.resumed:
        _scheduleNativePreviewLifecycleRecovery();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _handleNativePreviewLifecycleSuspended() {
    if (!_useNativePreview) {
      return;
    }
    _motionPreviewWarmupDebounce?.cancel();
    _stopMotionPreviewFrameClock(resetTo: _currentTime);
    if (_transportController.isPlaying) {
      unawaited(_pausePlayback());
    }
  }

  void _scheduleNativePreviewLifecycleRecovery() {
    if (!_useNativePreview || _isNativePreviewRecoveryScheduled) {
      return;
    }
    _isNativePreviewRecoveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_recoverNativePreviewAfterLifecycleResume());
    });
  }

  Future<void> _recoverNativePreviewAfterLifecycleResume() async {
    try {
      if (!mounted || !_useNativePreview) {
        return;
      }
      setState(() {
        _nativePreviewRecoveryRevision += 1;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_useNativePreview) {
        return;
      }
      await _transportController.recoverPreviewSurface(
        positionMs: _currentTime.inMilliseconds,
      );
      if (!mounted) {
        return;
      }
      _syncPlaybackSampleToCurrentTime();
    } finally {
      _isNativePreviewRecoveryScheduled = false;
    }
  }

  double get _workspaceAspectRatio =>
      _lockedWorkspaceAspectRatio ?? _previewAsset?.aspectRatio ?? (9 / 16);

  double get _timelineFps => _motionProject?.frameRate.framesPerSecond ?? 30;

  TimelineTime get _minEditableClipDurationTime =>
      TimelineTime.fromSecondsDouble(_minEditableClipDuration);

  TimelineTime get _timelineDurationTime {
    final nativeDuration = _transportController.durationSeconds;
    final nativeDurationTime = nativeDuration > 0
        ? TimelineTime.fromSecondsDouble(nativeDuration)
        : TimelineTime.zero;
    final tracksDuration = _timelineDurationForTracksTime(_timelineTruthTracks);
    if (_isApplyingStructuralEdit) {
      if (tracksDuration > TimelineTime.zero) {
        return tracksDuration;
      }
      return nativeDurationTime > TimelineTime.zero
          ? nativeDurationTime
          : TimelineTime.fromSecondsDouble(14);
    }
    if (_useNativePreview && nativeDuration > 0) {
      return nativeDurationTime;
    }
    if (tracksDuration <= TimelineTime.zero) {
      return nativeDurationTime > TimelineTime.zero
          ? nativeDurationTime
          : TimelineTime.fromSecondsDouble(14);
    }
    return tracksDuration >= nativeDurationTime
        ? tracksDuration
        : nativeDurationTime;
  }

  MotionProjectFormat get _motionProjectFormat {
    const canvasWidth = 1080.0;
    final aspectRatio =
        _previewAspectRatio > 0 ? _previewAspectRatio : (9 / 16);
    final canvasHeight = (canvasWidth / aspectRatio).clamp(1.0, 10000.0);
    return MotionProjectFormat(
      canvasSize: MotionSize2D(
        width: canvasWidth,
        height: canvasHeight,
      ),
    );
  }

  MotionProjectModel _buildInitialMotionProject() {
    return MotionProjectModel(
      id: _motionProjectId,
      format: _motionProjectFormat,
      frameRate: const MotionFrameRate(numerator: 30, denominator: 1),
      scenes: <MotionSceneModel>[
        MotionSceneModel(
          id: _motionSceneId,
          projectRange: TimelineTimeRange(
            start: TimelineTime.zero,
            endExclusive: _timelineDurationTime,
          ),
          layers: const <MotionLayerModel>[],
          name: 'Main Scene',
        ),
      ],
      name: 'Editor Motion Project',
    );
  }

  MotionProjectModel get _effectiveMotionProject {
    final baseProject = _motionProject ?? _buildInitialMotionProject();
    final effectiveDuration = _timelineDurationTime > baseProject.durationTime
        ? _timelineDurationTime
        : baseProject.durationTime;
    final updatedScenes = baseProject.scenes.map((scene) {
      if (scene.id != _motionSceneId) {
        return scene;
      }
      return scene.copyWith(
        projectRange: TimelineTimeRange(
          start: TimelineTime.zero,
          endExclusive: effectiveDuration,
        ),
      );
    }).toList(growable: false);
    return baseProject.copyWith(
      format: _motionProjectFormat,
      scenes: updatedScenes,
    );
  }

  bool get _hasMotionTextContent {
    final project = _motionProject;
    if (project == null) {
      return false;
    }
    for (final scene in project.scenes) {
      for (final layer in scene.layers) {
        for (final element in layer.elements) {
          if (element.kind == MotionElementKind.text) {
            return true;
          }
        }
      }
    }
    return false;
  }

  MotionNormalizedComposition? _motionCompositionForCurrentState() {
    if (!_hasMotionTextContent &&
        _motionTextAnimationBindings.isEmpty &&
        _manualMotionPropertyChannels.isEmpty) {
      _cachedMotionComposition = null;
      _cachedMotionRevision = _motionRevision;
      _cachedMotionTimelineDurationTicks = _timelineDurationTime.inProjectTicks;
      _cachedMotionCanvasWidth = _motionProjectFormat.canvasSize.width.round();
      _cachedMotionCanvasHeight =
          _motionProjectFormat.canvasSize.height.round();
      return null;
    }

    final currentDurationTicks = _timelineDurationTime.inProjectTicks;
    final currentCanvasWidth = _motionProjectFormat.canvasSize.width.round();
    final currentCanvasHeight = _motionProjectFormat.canvasSize.height.round();
    final isCacheValid = _cachedMotionComposition != null &&
        _cachedMotionRevision == _motionRevision &&
        _cachedMotionTimelineDurationTicks == currentDurationTicks &&
        _cachedMotionCanvasWidth == currentCanvasWidth &&
        _cachedMotionCanvasHeight == currentCanvasHeight;
    if (isCacheValid) {
      return _cachedMotionComposition;
    }

    final compileResult = _buildMotionCompiler().compile(
      MotionCompileRequest(
        project: _effectiveMotionProject,
        propertyChannels: _manualMotionPropertyChannels,
        transitionBindings:
            _motionTransitionBindingsForTracks(_timelineTruthTracks),
        textAnimationBindings: _motionTextAnimationBindings,
      ),
    );
    _cachedMotionComposition = compileResult.composition;
    _cachedMotionRevision = _motionRevision;
    _cachedMotionTimelineDurationTicks = currentDurationTicks;
    _cachedMotionCanvasWidth = currentCanvasWidth;
    _cachedMotionCanvasHeight = currentCanvasHeight;
    return _cachedMotionComposition;
  }

  void _markMotionAuthoringChanged({bool scheduleWarmup = true}) {
    _motionRevision += 1;
    _cachedMotionComposition = null;
    _cachedMotionRevision = null;
    _cachedMotionTimelineProjectionRevision = null;
    _cachedMotionTimelineEntries = null;
    _cachedMotionTimelineTrack = null;
    _cachedMotionDisplayTracks = null;
    _lastWarmedMotionRevision = null;
    if (scheduleWarmup) {
      _scheduleMotionPreviewWarmup();
    }
  }

  void _scheduleMotionPreviewWarmup({TimelineTime? time}) {
    if (!mounted) {
      return;
    }
    final requestId = ++_motionPreviewWarmupRequestId;
    final warmupTime = time ?? _timelineDisplayTimeNotifier.value;
    _motionPreviewWarmupDebounce?.cancel();
    _motionPreviewWarmupDebounce = Timer(const Duration(milliseconds: 24), () {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || requestId != _motionPreviewWarmupRequestId) {
          return;
        }
        _warmMotionPreviewForCurrentState(warmupTime);
      });
    });
  }

  void _prepareMotionPreviewForPlaybackStart({TimelineTime? time}) {
    if (_lastWarmedMotionRevision == _motionRevision &&
        _cachedMotionRevision == _motionRevision) {
      return;
    }
    _motionPreviewWarmupDebounce?.cancel();
    _motionPreviewWarmupRequestId += 1;
    _warmMotionPreviewForCurrentState(time ?? _currentTime);
  }

  void _warmMotionPreviewForCurrentState(TimelineTime preferredTime) {
    final composition = _motionCompositionForCurrentState();
    if (composition == null) {
      return;
    }
    final baseTime = preferredTime.clamp(
      TimelineTime.zero,
      composition.projectRange.endExclusive,
    );
    final sampleTimes = <TimelineTime>[
      baseTime,
      (baseTime + TimelineTime.fromSecondsDouble(1 / 60)).clamp(
        TimelineTime.zero,
        composition.projectRange.endExclusive,
      ),
      (baseTime + TimelineTime.fromSecondsDouble(2 / 60)).clamp(
        TimelineTime.zero,
        composition.projectRange.endExclusive,
      ),
      (baseTime + TimelineTime.fromSecondsDouble(4 / 60)).clamp(
        TimelineTime.zero,
        composition.projectRange.endExclusive,
      ),
    ];
    for (final sampleTime in sampleTimes) {
      final snapshot = _motionTextRenderSnapshotForTime(
        sampleTime,
        reason: MotionEvaluationReason.diagnostics,
      );
      if (snapshot != null) {
        warmMotionTextPreviewOverlayCaches(
          snapshot: snapshot,
          viewportSize: _lastPreviewStageSize,
        );
      }
    }
    _lastWarmedMotionRevision = _motionRevision;
  }

  void _handleExportStateChanged() {
    if (!mounted) {
      return;
    }
    final exportState = _exportController.state;
    final notificationKey =
        '${exportState.jobId}:${exportState.status.name}:${exportState.outputPath}:${exportState.error}';
    if (_lastExportStatusNotificationKey != notificationKey) {
      if (exportState.status == ExportJobStatus.completed &&
          exportState.outputPath != null) {
        _lastExportStatusNotificationKey = notificationKey;
        _showStageMessage(
          'Export completed: ${exportState.outputPath}',
        );
      } else if (exportState.status == ExportJobStatus.failed &&
          exportState.error != null) {
        _lastExportStatusNotificationKey = notificationKey;
        _showStageMessage(
          'Export failed: ${exportState.error}',
        );
      } else if (exportState.status == ExportJobStatus.cancelled) {
        _lastExportStatusNotificationKey = notificationKey;
        _showStageMessage('Export cancelled.');
      }
    }
    setState(() {});
  }

  ExportComposition _buildCurrentExportComposition({
    bool includeMotionTextRenderTrack = false,
  }) {
    final effectiveProject = _effectiveMotionProject;
    final motionComposition = _motionCompositionForCurrentState();
    final canonicalTracks = _timelineTruthTracks;
    final canonicalTimelineDuration =
        _timelineDurationForTracksTime(canonicalTracks);
    final projectDuration = canonicalTimelineDuration > TimelineTime.zero
        ? canonicalTimelineDuration
        : _timelineDurationTime;
    final projectFormat = ExportProjectFormatDescriptor(
      canvasWidth: effectiveProject.format.canvasSize.width.round(),
      canvasHeight: effectiveProject.format.canvasSize.height.round(),
      pixelAspectRatio: effectiveProject.format.pixelAspectRatio,
      frameRateNumerator: effectiveProject.frameRate.numerator,
      frameRateDenominator: effectiveProject.frameRate.denominator,
      durationTime: projectDuration,
    );
    final exportAssets = _buildExportAssetDescriptors(canonicalTracks);
    final exportTracks = _buildExportTrackSeeds(canonicalTracks);
    final transitionVideoEffects = _buildExportTransitionVideoEffectSegments(
      canonicalTracks,
      projectFormat,
    );
    final motionTextProgram = buildExportMotionTextProgram(motionComposition);
    final motionTextRenderTrack = includeMotionTextRenderTrack
        ? _buildMotionTextRenderTrackForExport(
            motionComposition: motionComposition,
            projectFormat: projectFormat,
          )
        : null;
    return const ExportCompositionBuilder().build(
      ExportCompositionBuildInput(
        contractVersion: _exportContractVersion,
        projectId: effectiveProject.id,
        projectFormat: projectFormat,
        assets: exportAssets,
        timelineTracks: exportTracks,
        transitionVideoEffects: transitionVideoEffects,
        motionComposition: motionComposition,
        motionTextProgram: motionTextProgram,
        motionTextRenderTrack: motionTextRenderTrack,
      ),
    );
  }

  ExportMotionTextRenderTrack? _buildMotionTextRenderTrackForExport({
    required MotionNormalizedComposition? motionComposition,
    required ExportProjectFormatDescriptor projectFormat,
  }) {
    if (motionComposition == null) {
      return null;
    }
    if (!motionComposition.allElements
        .any((element) => element.kind == MotionElementKind.text)) {
      return null;
    }
    final durationMs = motionComposition.projectRange.duration.inMilliseconds;
    final rawFrameRate = projectFormat.framesPerSecond;
    final hasAnimatedTextMotion = motionComposition.textAnimations.isNotEmpty ||
        motionComposition.allPropertyChannels.isNotEmpty;
    final targetSamplesPerSecond = rawFrameRate.isFinite && rawFrameRate > 0
        ? rawFrameRate.clamp(
            hasAnimatedTextMotion ? 24.0 : 12.0,
            hasAnimatedTextMotion ? 60.0 : 30.0,
          )
        : (hasAnimatedTextMotion ? 48.0 : 24.0);
    final baseStepMs = (1000 / targetSamplesPerSecond).round().clamp(1, 1000);
    final cappedStepMs = durationMs <= 0
        ? baseStepMs
        : ((durationMs / (hasAnimatedTextMotion ? 3600 : 1800)).ceil())
            .clamp(1, 1000);
    final sampleStepMs = baseStepMs > cappedStepMs ? baseStepMs : cappedStepMs;
    final criticalPaddingMs = (baseStepMs ~/ 2).clamp(1, 250);
    final samples = <ExportMotionTextRenderSample>[];
    final sampleTimesMs = <int>{};

    void addSampleTime(int milliseconds) {
      sampleTimesMs.add(milliseconds.clamp(0, durationMs));
    }

    void addCriticalSampleTime(int milliseconds) {
      addSampleTime(milliseconds);
      addSampleTime(milliseconds - criticalPaddingMs);
      addSampleTime(milliseconds + criticalPaddingMs);
    }

    void addDenseRangeSampleTimes(
      int startMilliseconds,
      int endMilliseconds,
    ) {
      final clampedStart = startMilliseconds.clamp(0, durationMs);
      final clampedEnd = endMilliseconds.clamp(0, durationMs);
      if (clampedEnd < clampedStart) {
        return;
      }
      addCriticalSampleTime(clampedStart);
      addCriticalSampleTime(clampedEnd);
      final denseStepMs = baseStepMs.clamp(1, 1000);
      if (denseStepMs <= 0 || clampedEnd - clampedStart <= denseStepMs) {
        return;
      }
      for (var milliseconds = clampedStart + denseStepMs;
          milliseconds < clampedEnd;
          milliseconds += denseStepMs) {
        addSampleTime(milliseconds);
      }
    }

    void addSampleAt(int milliseconds) {
      final snapshot = _motionTextRenderSnapshotForTime(
        TimelineTime.fromMilliseconds(milliseconds),
        reason: MotionEvaluationReason.exportFrame,
      );
      samples.add(
        ExportMotionTextRenderSample(
          time: TimelineTime.fromMilliseconds(milliseconds),
          nodes: snapshot == null
              ? const <ExportMotionTextRenderNode>[]
              : snapshot.nodes
                  .where(
                    (node) =>
                        node.text.isNotEmpty &&
                        node.opacity > 0 &&
                        node.projectRange.duration > TimelineTime.zero,
                  )
                  .map(ExportMotionTextRenderNode.fromSnapshotNode)
                  .toList(growable: false),
        ),
      );
    }

    if (durationMs <= 0) {
      addSampleTime(0);
    } else {
      for (var milliseconds = 0;
          milliseconds < durationMs;
          milliseconds += sampleStepMs) {
        addSampleTime(milliseconds);
      }
      addCriticalSampleTime(durationMs);
      for (final textAnimation in motionComposition.textAnimations) {
        addCriticalSampleTime(textAnimation.projectRange.start.inMilliseconds);
        addCriticalSampleTime(
            textAnimation.projectRange.endExclusive.inMilliseconds);
        for (final animationBlock in textAnimation.animationBlocks) {
          addDenseRangeSampleTimes(
            animationBlock.projectRange.start.inMilliseconds,
            animationBlock.projectRange.endExclusive.inMilliseconds,
          );
        }
      }
      for (final channel in motionComposition.allPropertyChannels) {
        addCriticalSampleTime(channel.projectRange.start.inMilliseconds);
        addCriticalSampleTime(channel.projectRange.endExclusive.inMilliseconds);
        for (final keyframe in channel.channel.keyframes) {
          addCriticalSampleTime(keyframe.time.inMilliseconds);
        }
      }
    }
    final orderedSampleTimes = sampleTimesMs.toList(growable: false)..sort();
    for (final milliseconds in orderedSampleTimes) {
      addSampleAt(milliseconds);
    }

    return ExportMotionTextRenderTrack(
      canvasSize: motionComposition.format.canvasSize,
      sampleStepMs: sampleStepMs,
      samples: samples,
    );
  }

  List<ExportAssetDescriptor> _buildExportAssetDescriptors(
    List<TimelineTrackData> tracks,
  ) {
    final referencedAssetIds = <String>{};
    for (final track in tracks) {
      for (final clip in track.clips) {
        final assetId = clip.assetId;
        if (assetId != null && assetId.isNotEmpty) {
          referencedAssetIds.add(assetId);
        }
      }
    }
    final exportAssets = <ExportAssetDescriptor>[];
    for (final assetId in referencedAssetIds) {
      final asset = _assetForId(assetId);
      if (asset == null) {
        continue;
      }
      exportAssets.add(
        ExportAssetDescriptor(
          assetId: asset.id,
          kind: _exportAssetKindForTab(asset.tab),
          label: asset.label,
          sourceUri: asset.sourceUri,
          durationTime: asset.durationSeconds == null
              ? null
              : TimelineTime.fromSecondsDouble(asset.durationSeconds!),
          width: asset.width,
          height: asset.height,
          isImported: asset.isImported,
        ),
      );
    }
    exportAssets.sort((left, right) => left.assetId.compareTo(right.assetId));
    return List<ExportAssetDescriptor>.unmodifiable(exportAssets);
  }

  List<ExportTrackSeed> _buildExportTrackSeeds(List<TimelineTrackData> tracks) {
    final exportTracks = <ExportTrackSeed>[];
    for (final track in tracks) {
      if (track.kind == TimelineTrackKind.text) {
        // Motion/text export is driven by `motionTextProgram`, not by the
        // generated timeline text track that exists for editor interaction.
        continue;
      }
      var timelineCursor = TimelineTime.zero;
      exportTracks.add(
        ExportTrackSeed(
          kind: _exportTrackKindForTimelineTrack(track.kind),
          clips: track.clips.map(
            (clip) {
              return ExportClipSeed(
                clipId: clip.id,
                assetId: clip.assetId,
                timelineStartTime: timelineCursor,
                // Export must inherit the canonical clip duration from the
                // accepted timeline truth, not re-derive it from source/rate.
                timelineDurationTime: clip.durationTime,
                sourceStartTime: clip.sourceStartTime,
                sourceDurationTime: clip.sourceDurationTime,
                playbackRate: clip.playbackRate,
                speedMode: _exportClipSpeedModeForTimelineClip(clip.speedMode),
                splitGroupId: clip.splitGroupId,
                label: clip.label,
                isPlaceholder: clip.type != TimelineClipType.media ||
                    (clip.aiTransition != null &&
                        (clip.assetId == null || clip.assetId!.isEmpty)),
              );
            },
          ).map((seed) {
            timelineCursor += seed.timelineDurationTime;
            return seed;
          }).toList(growable: false),
        ),
      );
    }
    return List<ExportTrackSeed>.unmodifiable(exportTracks);
  }

  List<ExportTransitionVideoEffectSegment>
      _buildExportTransitionVideoEffectSegments(
    List<TimelineTrackData> tracks,
    ExportProjectFormatDescriptor projectFormat,
  ) {
    final output = <ExportTransitionVideoEffectSegment>[];
    final projectDuration = projectFormat.durationTime;
    if (projectDuration <= TimelineTime.zero) {
      return const <ExportTransitionVideoEffectSegment>[];
    }
    final exportFps = projectFormat.framesPerSecond.isFinite &&
            projectFormat.framesPerSecond > 0
        ? projectFormat.framesPerSecond
        : _timelineFps;
    final stepMs = (1000 / exportFps.clamp(12.0, 30.0)).round().clamp(16, 84);

    for (final track in tracks) {
      if (track.kind != TimelineTrackKind.video ||
          track.transitions.isEmpty ||
          track.clips.length < 2) {
        continue;
      }
      final positionedClips = _positionedMediaClipsForTrack(track);
      final clipById = <String, _PositionedTimelineTrackClip>{
        for (final positionedClip in positionedClips)
          positionedClip.clip.id: positionedClip,
      };
      for (final transition in _sanitizeTransitionsForTrack(track)) {
        final leftClip = clipById[transition.leftClipId];
        final rightClip = clipById[transition.rightClipId];
        if (leftClip == null || rightClip == null) {
          continue;
        }
        final focusContext =
            transition.preset == TimelineTransitionPreset.manual
                ? _transitionFocusContextById(transition.id)
                : null;
        final manualAuthoredRange = focusContext == null
            ? null
            : _manualTransitionAuthoredEffectTimeRange(focusContext);
        final seamTime = leftClip.endTime;
        final startTime = manualAuthoredRange?.start ??
            focusContext?.activeStartTime ??
            (seamTime - transition.resolvedLeadingDurationTime).clamp(
              TimelineTime.zero,
              projectDuration,
            );
        final endTime = manualAuthoredRange?.end ??
            focusContext?.activeEndTime ??
            (seamTime + transition.resolvedTrailingDurationTime).clamp(
              TimelineTime.zero,
              projectDuration,
            );
        if (endTime <= startTime) {
          continue;
        }
        final startMs = startTime.inMilliseconds;
        final endMs = endTime.inMilliseconds;
        var cursorMs = startMs;
        var segmentIndex = 0;
        while (cursorMs < endMs) {
          final nextMs = math.min(endMs, cursorMs + stepMs);
          final midpoint = TimelineTime.fromMilliseconds(
            cursorMs + ((nextMs - cursorMs) ~/ 2),
          );
          final totalSpanMs = math.max(1, endMs - startMs);
          final elapsedMs = (midpoint - startTime).inMilliseconds;
          final progress = (elapsedMs / totalSpanMs).clamp(0.0, 1.0).toDouble();
          final manualLaneProgress = focusContext == null
              ? progress
              : _transitionFocusProgressForTime(focusContext, midpoint);
          final sigma = _transitionBlurSigmaForExport(
            transition: transition,
            progress: progress,
            manualLaneProgress: manualLaneProgress,
          );
          if (sigma > 0.05) {
            output.add(
              ExportTransitionVideoEffectSegment(
                id: 'transition-fx-${transition.id}-blur-$segmentIndex',
                transitionId: transition.id,
                effectId: 'blurAmount',
                timelineRange: TimelineTimeRange(
                  start: TimelineTime.fromMilliseconds(cursorMs),
                  endExclusive: TimelineTime.fromMilliseconds(nextMs),
                ),
                blurSigma: sigma,
              ),
            );
            segmentIndex += 1;
          }
          cursorMs = nextMs;
        }
      }
    }

    return List<ExportTransitionVideoEffectSegment>.unmodifiable(output);
  }

  double _transitionBlurSigmaForExport({
    required TimelineTrackTransitionData transition,
    required double progress,
    required double manualLaneProgress,
  }) {
    final blurSigma = switch (transition.preset) {
      TimelineTransitionPreset.manual =>
        transition.manualEffectIds.contains('blurAmount')
            ? transition.manualLaneValueAtProgress(
                'blurAmount',
                manualLaneProgress,
                fallbackValue: transition.parameterValue(
                  'blurAmount',
                  fallback: 0.0,
                ),
              )
            : 0.0,
      TimelineTransitionPreset.blurDissolve =>
        transition.parameterValue('maxBlur', fallback: 10.0) *
            _centeredTransitionPulse(progress),
      TimelineTransitionPreset.whipPanLeft ||
      TimelineTransitionPreset.whipPanRight =>
        transition.parameterValue('maxBlur', fallback: 16.0) *
            _sineTransitionPulse(progress),
      TimelineTransitionPreset.slideBlurLeft ||
      TimelineTransitionPreset.slideBlurRight =>
        transition.parameterValue('maxBlur', fallback: 8.0) *
            _sineTransitionPulse(progress),
      _ => 0.0,
    };
    if (blurSigma.isNaN || blurSigma.isInfinite) {
      return 0.0;
    }
    return blurSigma.clamp(0.0, 24.0).toDouble();
  }

  ExportTrackKind _exportTrackKindForTimelineTrack(TimelineTrackKind kind) {
    return switch (kind) {
      TimelineTrackKind.video => ExportTrackKind.video,
      TimelineTrackKind.image => ExportTrackKind.image,
      TimelineTrackKind.audio => ExportTrackKind.audio,
      TimelineTrackKind.text => ExportTrackKind.text,
      TimelineTrackKind.lipSync => ExportTrackKind.lipSync,
    };
  }

  ExportAssetKind _exportAssetKindForTab(EditorMediaTab tab) {
    return switch (tab) {
      EditorMediaTab.video => ExportAssetKind.video,
      EditorMediaTab.image => ExportAssetKind.image,
      EditorMediaTab.audio => ExportAssetKind.audio,
      EditorMediaTab.text => ExportAssetKind.text,
      EditorMediaTab.lipSync => ExportAssetKind.lipSync,
      EditorMediaTab.speed => ExportAssetKind.unknown,
    };
  }

  ExportClipSpeedMode _exportClipSpeedModeForTimelineClip(
    TimelineClipSpeedMode mode,
  ) {
    return switch (mode) {
      TimelineClipSpeedMode.normal => ExportClipSpeedMode.normal,
      TimelineClipSpeedMode.curve => ExportClipSpeedMode.curve,
    };
  }

  MotionTextRenderSnapshot? _motionTextRenderSnapshotForTime(
    TimelineTime time, {
    MotionEvaluationReason reason = MotionEvaluationReason.previewPlayback,
  }) {
    final composition = _motionCompositionForCurrentState();
    if (composition == null) {
      return null;
    }
    final evaluation = _motionEvaluator.evaluate(
      MotionEvaluationRequest(
        composition: composition,
        time: time.clamp(
          TimelineTime.zero,
          composition.projectRange.endExclusive,
        ),
        reason: reason == MotionEvaluationReason.previewPlayback
            ? (_isTimelineScrubbing
                ? MotionEvaluationReason.liveScrub
                : MotionEvaluationReason.previewPlayback)
            : reason,
      ),
    );
    final preview = _buildMotionTextPreviewBinder().bind(
      composition: composition,
      evaluation: evaluation,
    );
    if (preview.nodes.isEmpty) {
      return null;
    }
    final snapshot = _motionTextRenderAdapter.adapt(
      composition: composition,
      preview: preview,
    );
    final activeNodes = snapshot.nodes.where((node) {
      final bindingRange =
          _motionTextBindingForElementId(node.targetElementId)?.activeRange;
      final effectiveRange =
          bindingRange != null && bindingRange.endExclusive > bindingRange.start
              ? bindingRange
              : node.projectRange;
      return node.isActive && effectiveRange.contains(snapshot.time);
    }).map((node) {
      if (_hasManualOpacityChannelForElement(node.targetElementId)) {
        return node;
      }
      final clipContext = _selectedClipContextForTracks(
        _timelineTruthTracks,
        node.targetElementId,
      );
      if (clipContext == null) {
        return node;
      }
      final clipOpacity = _clipOpacityForTimelineTime(
        clipContext,
        snapshot.time,
      );
      if (clipOpacity >= 0.999) {
        return node;
      }
      return _copyMotionTextRenderNodeWithOpacity(
        node,
        (node.opacity * clipOpacity).clamp(0.0, 1.0).toDouble(),
      );
    }).toList(growable: false);
    if (activeNodes.isEmpty) {
      return null;
    }
    return MotionTextRenderSnapshot(
      projectId: snapshot.projectId,
      time: snapshot.time,
      canvasSize: snapshot.canvasSize,
      nodes: activeNodes,
    );
  }

  MotionTextRenderNode _copyMotionTextRenderNodeWithOpacity(
    MotionTextRenderNode node,
    double opacity,
  ) {
    return MotionTextRenderNode(
      id: node.id,
      targetElementId: node.targetElementId,
      sceneId: node.sceneId,
      layerId: node.layerId,
      projectRange: node.projectRange,
      isActive: node.isActive,
      text: node.text,
      fullText: node.fullText,
      revealUnit: node.revealUnit,
      revealProgress: node.revealProgress,
      hasRevealAnimation: node.hasRevealAnimation,
      animationKinds: node.animationKinds,
      animationProgressByKind: node.animationProgressByKind,
      canvasOffset: node.canvasOffset,
      scaleX: node.scaleX,
      scaleY: node.scaleY,
      rotationDegrees: node.rotationDegrees,
      opacity: opacity,
      blurAmount: node.blurAmount,
      blurHorizontal: node.blurHorizontal,
      blurVertical: node.blurVertical,
      blurMix: node.blurMix,
      blurEdgeMode: node.blurEdgeMode,
      blurCrop: node.blurCrop,
      fontSize: node.fontSize,
      letterSpacing: node.letterSpacing,
      colorArgb: node.colorArgb,
      fontFamily: node.fontFamily,
      fontWeight: node.fontWeight,
      fontStyle: node.fontStyle,
      lineHeight: node.lineHeight,
      textAlignment: node.textAlignment,
      anchor: node.anchor,
      blendMode: node.blendMode,
      zIndex: node.zIndex,
      name: node.name,
      presetId: node.presetId,
    );
  }

  EditorAssetItem? get _previewAsset {
    final previewAsset = _assetForId(_previewAssetId);
    if (previewAsset != null && previewAsset.isVisual) {
      return previewAsset;
    }

    for (final track in _tracks) {
      if (track.kind != TimelineTrackKind.video &&
          track.kind != TimelineTrackKind.image) {
        continue;
      }
      for (final clip in track.clips) {
        final asset = _assetForId(clip.assetId);
        if (asset != null && asset.isVisual) {
          return asset;
        }
      }
    }
    return null;
  }

  List<LiveScrubPreviewSourceDescriptor>
      _buildLiveScrubPreviewSourceDescriptors(
    List<TimelineTrackData> tracks,
  ) {
    final descriptors = <LiveScrubPreviewSourceDescriptor>[];
    for (final track in tracks) {
      if (track.kind != TimelineTrackKind.video &&
          track.kind != TimelineTrackKind.image) {
        continue;
      }
      var clipStartTime = TimelineTime.zero;
      for (final clip in track.clips) {
        final clipEndTime = clipStartTime + clip.durationTime;
        final assetId = clip.assetId;
        final asset = assetId == null ? null : _assetForId(assetId);
        final sourceUri = asset?.sourceUri;
        if (clip.type == TimelineClipType.media &&
            assetId != null &&
            asset != null &&
            asset.isVisual &&
            sourceUri != null &&
            sourceUri.isNotEmpty) {
          descriptors.add(
            LiveScrubPreviewSourceDescriptor(
              clipId: clip.id,
              assetId: assetId,
              sourceUri: sourceUri,
              scrubStoreKey: clip.id,
              previewUri: asset.previewUri,
              label: asset.label,
              timelineStartMs: clipStartTime.inMilliseconds,
              timelineEndMs: clipEndTime.inMilliseconds,
              durationMs: clip.durationTime.inMilliseconds,
              sourceStartMs: clip.sourceStartTime.inMilliseconds,
              sourceDurationMs: clip.sourceDurationTime.inMilliseconds,
              playbackRate: clip.playbackRate,
              sourceWidth: asset.width,
              sourceHeight: asset.height,
              status: LiveScrubPreviewSourceStatus.ready,
            ),
          );
        }
        clipStartTime = clipEndTime;
      }
    }
    return descriptors;
  }

  void _refreshLiveScrubPreviewSourceCatalog({
    List<TimelineTrackData>? tracks,
  }) {
    final descriptors =
        _buildLiveScrubPreviewSourceDescriptors(tracks ?? _tracks);
    _liveScrubPreviewSourceCatalog.replaceAll(descriptors);
  }

  List<LiveScrubPreviewSourceDescriptor> _allLiveScrubPreviewSources() {
    return _liveScrubPreviewSourceCatalog.descriptors;
  }

  void _schedulePreviewThumbnailWarmup(EditorAssetItem? asset) {
    final assetId = asset?.id;
    if (_previewThumbnailAssetId == assetId) {
      return;
    }
    _previewThumbnailAssetId = assetId;
    final cached = assetId == null ? null : _previewThumbnailCache[assetId];
    if (cached != null &&
        cached.isNotEmpty &&
        _previewThumbnailResolvedAssetId != assetId) {
      _previewThumbnailResolvedAssetId = assetId;
      if (!identical(_previewThumbnailNotifier.value, cached)) {
        _previewThumbnailNotifier.value = cached;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_warmPreviewThumbnail(asset));
    });
  }

  Future<void> _primePreviewThumbnailForAsset(
    EditorAssetItem? asset, {
    bool publishIfNotCurrent = true,
  }) async {
    if (asset == null || !asset.isVisual) {
      return;
    }
    final sourceUri = asset.sourceUri;
    if (sourceUri == null || sourceUri.isEmpty) {
      return;
    }
    final cached = _previewThumbnailCache[asset.id];
    if (cached != null && cached.isNotEmpty) {
      if (publishIfNotCurrent || _previewAssetId == asset.id) {
        _previewThumbnailAssetId = asset.id;
        _previewThumbnailResolvedAssetId = asset.id;
        if (!identical(_previewThumbnailNotifier.value, cached)) {
          _previewThumbnailNotifier.value = cached;
        }
      }
      return;
    }
    Uint8List? bytes;
    try {
      bytes = await _loadPreviewFallbackBytes(asset);
    } catch (_) {
      return;
    }
    if (!mounted || bytes == null || bytes.isEmpty) {
      return;
    }
    _previewThumbnailCache[asset.id] = bytes;
    if (publishIfNotCurrent || _previewAssetId == asset.id) {
      _previewThumbnailAssetId = asset.id;
      _previewThumbnailResolvedAssetId = asset.id;
      _previewThumbnailNotifier.value = bytes;
    }
  }

  void _schedulePreviewThumbnailPrimeForAsset(
    EditorAssetItem asset, {
    bool publishIfNotCurrent = true,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _primePreviewThumbnailForAsset(
          asset,
          publishIfNotCurrent: publishIfNotCurrent,
        ),
      );
    });
  }

  Future<void> _warmPreviewThumbnail(EditorAssetItem? asset) async {
    final sourceUri = asset?.sourceUri;
    if (asset == null ||
        !asset.isVisual ||
        sourceUri == null ||
        sourceUri.isEmpty) {
      if (_previewThumbnailNotifier.value != null) {
        _previewThumbnailNotifier.value = null;
      }
      _previewThumbnailResolvedAssetId = null;
      return;
    }
    final cached = _previewThumbnailCache[asset.id];
    if (cached != null && cached.isNotEmpty) {
      _previewThumbnailResolvedAssetId = asset.id;
      if (!identical(_previewThumbnailNotifier.value, cached)) {
        _previewThumbnailNotifier.value = cached;
      }
      return;
    }
    final requestId = ++_previewThumbnailRequestId;
    Uint8List? bytes;
    try {
      bytes = await _loadPreviewFallbackBytes(asset);
    } catch (_) {
      return;
    }
    if (!mounted ||
        requestId != _previewThumbnailRequestId ||
        _previewAssetId != asset.id ||
        bytes == null ||
        bytes.isEmpty) {
      return;
    }
    _previewThumbnailCache[asset.id] = bytes;
    _previewThumbnailResolvedAssetId = asset.id;
    _previewThumbnailNotifier.value = bytes;
  }

  Future<Uint8List?> _loadPreviewFallbackBytes(EditorAssetItem asset) async {
    final sourceUri = asset.sourceUri;
    if (sourceUri == null || sourceUri.isEmpty) {
      return null;
    }
    if (asset.tab == EditorMediaTab.video) {
      final displayGeometry =
          await _transportController.loadMediaDisplayGeometry(
        sourceUri: sourceUri,
      );
      if (displayGeometry != null &&
          (asset.width != displayGeometry.width ||
              asset.height != displayGeometry.height)) {
        _replaceKnownAssetMetadata(
          asset.copyWith(
            width: displayGeometry.width,
            height: displayGeometry.height,
          ),
        );
      }
      final normalizedAspectRatio = displayGeometry != null &&
              displayGeometry.width > 0 &&
              displayGeometry.height > 0
          ? displayGeometry.width / displayGeometry.height
          : asset.aspectRatio;
      final previewTarget = _resolvePreviewFallbackTargetSizeForAspectRatio(
        normalizedAspectRatio,
      );
      for (final positionMs in const <int>[0, 33, 100, 250]) {
        final framePreview = await _transportController.loadMediaFramePreview(
          sourceUri: sourceUri,
          positionMs: positionMs,
          targetWidth: previewTarget.width,
          targetHeight: previewTarget.height,
        );
        if (framePreview != null && framePreview.isNotEmpty) {
          return framePreview;
        }
      }
      return null;
    }
    final previewTarget = _resolvePreviewFallbackTargetSizeForAspectRatio(
      asset.aspectRatio,
    );
    return _transportController.loadMediaThumbnail(
      sourceUri: sourceUri,
      targetWidth: previewTarget.width,
      targetHeight: previewTarget.height,
    );
  }

  ({int width, int height}) _resolvePreviewFallbackTargetSizeForAspectRatio(
    double? aspectRatio,
  ) {
    const fallbackWidth = 480.0;
    const fallbackHeight = 854.0;
    if (aspectRatio == null || aspectRatio <= 0) {
      return (width: fallbackWidth.round(), height: fallbackHeight.round());
    }
    if (aspectRatio >= 1.0) {
      final height = (fallbackWidth / aspectRatio).clamp(180.0, fallbackHeight);
      return (width: fallbackWidth.round(), height: height.round());
    }
    final width = (fallbackHeight * aspectRatio).clamp(120.0, fallbackWidth);
    return (width: width.round(), height: fallbackHeight.round());
  }

  bool _matchesCurrentMotionTimelineProjection(
    MotionProjectModel? project, {
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    return identical(project, _motionProject) &&
        identical(
          bindings ?? _motionTextAnimationBindings,
          _motionTextAnimationBindings,
        );
  }

  bool get _hasValidCurrentMotionTimelineProjectionCache =>
      identical(_cachedMotionTimelineProjectionProject, _motionProject) &&
      identical(
        _cachedMotionTimelineProjectionBindings,
        _motionTextAnimationBindings,
      ) &&
      _cachedMotionTimelineProjectionRevision == _motionRevision;

  TimelineTrackData _buildMotionTextTimelineTrackFromEntries(
    List<_MotionTextTimelineEntry> entries,
  ) {
    final sortedEntries = List<_MotionTextTimelineEntry>.from(entries)
      ..sort((left, right) => left.start.compareTo(right.start));
    if (sortedEntries.isEmpty) {
      return const TimelineTrackData(
        kind: TimelineTrackKind.text,
        clips: <TimelineClipData>[],
        placeholderLabel: 'Text',
      );
    }

    final clips = <TimelineClipData>[];
    var cursor = TimelineTime.zero;
    for (final entry in sortedEntries) {
      if (entry.start > cursor) {
        clips.add(
          TimelineClipData(
            id: 'text-gap-${cursor.inProjectTicks}-${entry.start.inProjectTicks}',
            type: TimelineClipType.placeholder,
            tone: TimelineClipTone.placeholder,
            durationTime: entry.start - cursor,
            label: '',
          ),
        );
      }
      clips.add(
        TimelineClipData(
          id: entry.elementId,
          type: TimelineClipType.media,
          tone: TimelineClipTone.heroMuted,
          sourceStartTime: entry.start,
          durationTime: entry.end - entry.start,
          label: entry.label,
        ),
      );
      cursor = entry.end;
    }

    return TimelineTrackData(
      kind: TimelineTrackKind.text,
      clips: clips,
      placeholderLabel: 'Text',
    );
  }

  List<_MotionTextTimelineEntry> _currentMotionTextTimelineEntries() {
    final project = _motionProject;
    if (project == null) {
      return const <_MotionTextTimelineEntry>[];
    }
    if (_hasValidCurrentMotionTimelineProjectionCache &&
        _cachedMotionTimelineEntries != null) {
      return _cachedMotionTimelineEntries!;
    }
    final entries = _buildMotionTextTimelineEntries(
      project,
      bindings: _motionTextAnimationBindings,
    );
    _cachedMotionTimelineProjectionProject = project;
    _cachedMotionTimelineProjectionBindings = _motionTextAnimationBindings;
    _cachedMotionTimelineProjectionRevision = _motionRevision;
    _cachedMotionTimelineEntries = List<_MotionTextTimelineEntry>.unmodifiable(
      entries,
    );
    _cachedMotionTimelineTrack = null;
    _cachedMotionTimelineBaseTracks = null;
    _cachedMotionDisplayTracks = null;
    return _cachedMotionTimelineEntries!;
  }

  TimelineTrackData _currentMotionTextTimelineTrack() {
    if (_hasValidCurrentMotionTimelineProjectionCache &&
        _cachedMotionTimelineTrack != null) {
      return _cachedMotionTimelineTrack!;
    }
    final track = _buildMotionTextTimelineTrackFromEntries(
      _currentMotionTextTimelineEntries(),
    );
    _cachedMotionTimelineTrack = track;
    return track;
  }

  List<MotionTransitionBindingModel> _motionTransitionBindingsForTracks(
    List<TimelineTrackData> tracks,
  ) {
    final videoTrackIndex = tracks.indexWhere(
      (track) => track.kind == TimelineTrackKind.video,
    );
    if (videoTrackIndex < 0) {
      return const <MotionTransitionBindingModel>[];
    }
    final videoTrack = tracks[videoTrackIndex];
    final transitions = _sanitizeTransitionsForTrack(videoTrack);
    if (transitions.isEmpty) {
      return const <MotionTransitionBindingModel>[];
    }
    final positionedClips = _positionedMediaClipsForTrack(videoTrack);
    final clipById = <String, _PositionedTimelineTrackClip>{
      for (final clip in positionedClips) clip.clip.id: clip,
    };
    final projectDuration = _timelineDurationForTracksTime(tracks);
    final bindings = <MotionTransitionBindingModel>[];
    for (final transition in transitions) {
      if (transition.preset == TimelineTransitionPreset.aiGenerated ||
          transition.preset == TimelineTransitionPreset.manual) {
        continue;
      }
      final leftClip = clipById[transition.leftClipId];
      final rightClip = clipById[transition.rightClipId];
      if (leftClip == null || rightClip == null) {
        continue;
      }
      final seamTime = leftClip.startTime + leftClip.clip.durationTime;
      final activeStart =
          (seamTime - transition.resolvedLeadingDurationTime).clamp(
        TimelineTime.zero,
        projectDuration,
      );
      final activeEnd =
          (seamTime + transition.resolvedTrailingDurationTime).clamp(
        TimelineTime.zero,
        projectDuration,
      );
      if (activeEnd <= activeStart) {
        continue;
      }
      bindings.add(
        MotionTransitionBindingModel(
          id: transition.id,
          kind: _motionTransitionKindForPreset(transition.preset),
          leftTargetId: transition.leftClipId,
          rightTargetId: transition.rightClipId,
          activeRange: TimelineTimeRange(
            start: activeStart,
            endExclusive: activeEnd,
          ),
          name: transition.preset.label,
          parameters: <String, MotionPropertyValue>{
            for (final entry in transition.parameterValues.entries)
              entry.key: MotionPropertyValue.scalar(entry.value),
          },
        ),
      );
    }
    return List<MotionTransitionBindingModel>.unmodifiable(bindings);
  }

  MotionTransitionKind _motionTransitionKindForPreset(
    TimelineTransitionPreset preset,
  ) {
    return switch (preset) {
      TimelineTransitionPreset.manual => MotionTransitionKind.cameraPush,
      TimelineTransitionPreset.crossDissolve => MotionTransitionKind.fade,
      TimelineTransitionPreset.fadeBlack => MotionTransitionKind.fade,
      TimelineTransitionPreset.whiteFlash => MotionTransitionKind.fade,
      TimelineTransitionPreset.zoomInCamera => MotionTransitionKind.cameraPush,
      TimelineTransitionPreset.zoomOutCamera => MotionTransitionKind.cameraPush,
      TimelineTransitionPreset.blurDissolve => MotionTransitionKind.fade,
      TimelineTransitionPreset.pushLeft ||
      TimelineTransitionPreset.pushRight ||
      TimelineTransitionPreset.whipPanLeft ||
      TimelineTransitionPreset.whipPanRight ||
      TimelineTransitionPreset.slideBlurLeft ||
      TimelineTransitionPreset.slideBlurRight ||
      TimelineTransitionPreset.flashZoom =>
        MotionTransitionKind.cameraPush,
      TimelineTransitionPreset.aiGenerated => MotionTransitionKind.fade,
    };
  }

  List<TimelineTrackData> _displayTracksForProject(
    MotionProjectModel? project, {
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    final textTrackIndex = _tracks.indexWhere(
      (track) => track.kind == TimelineTrackKind.text,
    );
    if (textTrackIndex < 0) {
      return _tracks;
    }
    if (project == null) {
      return _tracks;
    }
    final useCurrentProjection = _matchesCurrentMotionTimelineProjection(
      project,
      bindings: bindings,
    );
    if (useCurrentProjection &&
        _hasValidCurrentMotionTimelineProjectionCache &&
        identical(_cachedMotionTimelineBaseTracks, _tracks) &&
        _cachedMotionDisplayTracks != null) {
      return _cachedMotionDisplayTracks!;
    }
    final generatedTextTrack = useCurrentProjection
        ? _currentMotionTextTimelineTrack()
        : _buildMotionTextTimelineTrackForProject(
            project,
            bindings: bindings,
          );
    final baseTextTrack = _tracks[textTrackIndex];
    final nextTracks = List<TimelineTrackData>.from(_tracks);
    nextTracks[textTrackIndex] = generatedTextTrack.copyWith(
      animationLanes: baseTextTrack.animationLanes,
    );
    final resolvedTracks = List<TimelineTrackData>.unmodifiable(nextTracks);
    if (useCurrentProjection) {
      _cachedMotionTimelineBaseTracks = _tracks;
      _cachedMotionDisplayTracks = resolvedTracks;
    }
    return resolvedTracks;
  }

  List<TimelineTrackData> get _displayTracks => _displayTracksForProject(
        _motionProject,
      );

  List<TimelineTrackData> get _timelineTruthTracks => _displayTracks;

  TimelineTrackData _buildMotionTextTimelineTrackForProject(
    MotionProjectModel project, {
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    final entries = _matchesCurrentMotionTimelineProjection(
      project,
      bindings: bindings,
    )
        ? _currentMotionTextTimelineEntries()
        : _buildMotionTextTimelineEntries(project, bindings: bindings);
    return _buildMotionTextTimelineTrackFromEntries(entries);
  }

  List<_MotionTextTimelineEntry> _buildMotionTextTimelineEntries(
    MotionProjectModel project, {
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    final entries = <_MotionTextTimelineEntry>[];
    for (final scene in project.scenes) {
      for (final layer in scene.layers) {
        if (layer.kind != MotionLayerKind.text) {
          continue;
        }
        for (final element in layer.elements) {
          if (element.kind != MotionElementKind.text) {
            continue;
          }
          final timingRange = _motionTextTimingRangeForElement(
            scene: scene,
            element: element,
            bindings: bindings,
          );
          final metadata = element.sourceBinding?.metadata;
          final textLabel = metadata?['text'] ??
              element.sourceBinding?.label ??
              element.name ??
              'Text';
          entries.add(
            _MotionTextTimelineEntry(
              elementId: element.id,
              start: timingRange.start,
              end: timingRange.endExclusive,
              label: textLabel,
            ),
          );
        }
      }
    }
    return entries;
  }

  EditorAssetItem? _assetForId(String? assetId) {
    if (assetId == null) {
      return null;
    }
    for (final asset in _assetLibrary.value) {
      if (asset.id == assetId) {
        return asset;
      }
    }
    return _importedAssetsById[assetId];
  }

  Future<EditorAssetItem> _normalizeVisualAssetGeometryForInsert(
    EditorAssetItem asset,
  ) async {
    if (asset.tab != EditorMediaTab.video) {
      return asset;
    }
    final sourceUri = asset.sourceUri;
    if (sourceUri == null || sourceUri.isEmpty) {
      return asset;
    }
    final geometry = await _transportController.loadMediaDisplayGeometry(
      sourceUri: sourceUri,
    );
    if (geometry == null) {
      return asset;
    }
    if (asset.width == geometry.width && asset.height == geometry.height) {
      return asset;
    }
    final normalizedAsset = asset.copyWith(
      width: geometry.width,
      height: geometry.height,
    );
    _replaceKnownAssetMetadata(
      normalizedAsset,
      invalidatePreviewThumbnail: true,
    );
    return normalizedAsset;
  }

  void _replaceKnownAssetMetadata(
    EditorAssetItem updatedAsset, {
    bool invalidatePreviewThumbnail = false,
  }) {
    var assetLibraryChanged = false;
    final nextAssets = _assetLibrary.value.map((asset) {
      if (asset.id != updatedAsset.id) {
        return asset;
      }
      assetLibraryChanged = true;
      return updatedAsset;
    }).toList(growable: false);
    if (assetLibraryChanged) {
      _assetLibrary.value = List<EditorAssetItem>.unmodifiable(nextAssets);
    }
    if (_importedAssetsById.containsKey(updatedAsset.id) ||
        updatedAsset.isImported) {
      _importedAssetsById[updatedAsset.id] = updatedAsset;
    }
    if (invalidatePreviewThumbnail) {
      _previewThumbnailCache.remove(updatedAsset.id);
      if (_previewThumbnailAssetId == updatedAsset.id) {
        _previewThumbnailResolvedAssetId = null;
        if (_previewThumbnailNotifier.value != null) {
          _previewThumbnailNotifier.value = null;
        }
      }
    }
    _refreshLiveScrubPreviewSourceCatalog();
  }

  Future<void> _scheduleScrubFramePreparationForTimelineTracks(
    List<TimelineTrackData> tracks,
  ) async {
    _refreshLiveScrubPreviewSourceCatalog(tracks: tracks);
    final sources = _buildLiveScrubPreviewSourceDescriptors(tracks);
    if (sources.isEmpty) {
      return;
    }
    await _transportController.primeScrubPreviewSources(
      sources
          .map(
            (descriptor) => <String, Object?>{
              'sourceUri': descriptor.sourceUri,
              'previewUri': descriptor.previewUri,
            },
          )
          .toList(growable: false),
    );
  }

  Future<void> _flushNativeTimelineScrubConfig() async {
    if (!_useNativeTimelineScrubInput || !mounted) {
      return;
    }
    final targetRevision = _timelineScrubConfigRevision + 1;
    final pendingCompleter = Completer<void>();
    _pendingTimelineScrubConfigTargetRevision = targetRevision;
    _pendingTimelineScrubConfigCompleter = pendingCompleter;
    setState(() {
      _timelineScrubConfigRevision = targetRevision;
    });
    if (_lastAppliedTimelineScrubConfigRevision >= targetRevision) {
      if (!pendingCompleter.isCompleted) {
        pendingCompleter.complete();
      }
    }
    try {
      await pendingCompleter.future.timeout(const Duration(milliseconds: 350));
    } catch (_) {
      if (!pendingCompleter.isCompleted) {
        pendingCompleter.complete();
      }
    } finally {
      if (identical(_pendingTimelineScrubConfigCompleter, pendingCompleter)) {
        _pendingTimelineScrubConfigCompleter = null;
        _pendingTimelineScrubConfigTargetRevision = null;
      }
    }
  }

  Future<bool> _awaitNativeTimelineScrubReadiness(
    TimelineTime targetTime,
  ) async {
    if (!_useNativePreview || !_useNativeTimelineScrubInput || !mounted) {
      return true;
    }
    const readinessTimeoutsMs = <int>[450, 700, 950];
    final positionMs =
        targetTime.inMilliseconds < 0 ? 0 : targetTime.inMilliseconds;
    for (var index = 0; index < readinessTimeoutsMs.length; index++) {
      final isReady = await _transportController.awaitTimelineScrubReady(
        positionMs: positionMs,
        timeoutMs: readinessTimeoutsMs[index],
      );
      if (isReady) {
        return true;
      }
      if (index < readinessTimeoutsMs.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
    return false;
  }

  void _handleTimelineScrubConfigApplied(int revision) {
    if (revision <= _lastAppliedTimelineScrubConfigRevision) {
      return;
    }
    _lastAppliedTimelineScrubConfigRevision = revision;
    final pendingTargetRevision = _pendingTimelineScrubConfigTargetRevision;
    final pendingCompleter = _pendingTimelineScrubConfigCompleter;
    if (pendingTargetRevision == null ||
        pendingCompleter == null ||
        pendingCompleter.isCompleted) {
      return;
    }
    if (revision >= pendingTargetRevision) {
      pendingCompleter.complete();
    }
  }

  int _nativeTimelineScrubConfigRevisionFor(
    TimelineScrubSurfaceConfig surfaceConfig,
  ) {
    return (_timelineScrubConfigRevision * 1000000) +
        surfaceConfig.geometryRevision;
  }

  void _primeVideoAssetForLiveScrub(
    EditorAssetItem asset, {
    int? preferredPreviewPositionMs,
  }) {
    if (asset.tab == EditorMediaTab.video) {
      _refreshLiveScrubPreviewSourceCatalog();
      final sourceUri = asset.sourceUri;
      if (sourceUri != null && sourceUri.isNotEmpty) {
        unawaited(
          _transportController.primeScrubPreviewSources(
            <Map<String, Object?>>[
              <String, Object?>{
                'sourceUri': sourceUri,
                'previewUri': asset.previewUri,
              },
            ],
          ),
        );
      }
    }
  }

  _SelectedTimelineClipContext? get _selectedClipContext {
    final selectedClipId = _selectedClipId;
    if (selectedClipId == null) {
      return null;
    }
    return _selectedClipContextForTracks(_timelineTruthTracks, selectedClipId);
  }

  _SelectedTimelineClipContext? _selectedClipContextForTracks(
    List<TimelineTrackData> tracks,
    String clipId,
  ) {
    for (var trackIndex = 0; trackIndex < tracks.length; trackIndex++) {
      final track = tracks[trackIndex];
      var cursor = TimelineTime.zero;
      for (var clipIndex = 0; clipIndex < track.clips.length; clipIndex++) {
        final clip = track.clips[clipIndex];
        final clipStart = cursor;
        final clipEnd = clipStart + clip.durationTime;
        if (clip.id == clipId) {
          return _SelectedTimelineClipContext(
            trackIndex: trackIndex,
            clipIndex: clipIndex,
            track: track,
            clip: clip,
            asset: _assetForId(clip.assetId),
            clipStartTime: clipStart,
            clipEndTime: clipEnd,
          );
        }
        cursor = clipEnd;
      }
    }
    return null;
  }

  _MotionTextElementContext? _motionTextElementContextForId(String elementId) {
    final project = _motionProject;
    if (project == null) {
      return null;
    }
    for (var sceneIndex = 0; sceneIndex < project.scenes.length; sceneIndex++) {
      final scene = project.scenes[sceneIndex];
      for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
        final layer = scene.layers[layerIndex];
        for (var elementIndex = 0;
            elementIndex < layer.elements.length;
            elementIndex++) {
          final element = layer.elements[elementIndex];
          if (element.id != elementId ||
              element.kind != MotionElementKind.text) {
            continue;
          }
          return _MotionTextElementContext(
            project: project,
            sceneIndex: sceneIndex,
            layerIndex: layerIndex,
            elementIndex: elementIndex,
            scene: scene,
            layer: layer,
            element: element,
          );
        }
      }
    }
    return null;
  }

  MotionTextAnimationBindingModel? _motionTextBindingForElementId(
    String elementId, {
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    for (final binding in bindings ?? _motionTextAnimationBindings) {
      if (binding.elementTarget.targetId == elementId) {
        return binding;
      }
    }
    return null;
  }

  TimelineTimeRange _motionTextTimingRangeForElement({
    required MotionSceneModel scene,
    required MotionElementModel element,
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    final binding = _motionTextBindingForElementId(
      element.id,
      bindings: bindings,
    );
    final bindingRange = binding?.activeRange;
    if (bindingRange != null &&
        bindingRange.endExclusive > bindingRange.start) {
      return bindingRange;
    }
    return TimelineTimeRange(
      start: scene.projectRange.start + element.localRange.start,
      endExclusive: scene.projectRange.start + element.localRange.endExclusive,
    );
  }

  MotionTextPresetDefinition? _textPresetForBinding(
    MotionTextAnimationBindingModel? binding,
  ) {
    final presetId = binding?.presetId;
    if (presetId == null) {
      return null;
    }
    for (final preset in _availableTextPresets) {
      if (preset.id == presetId) {
        return preset;
      }
    }
    return null;
  }

  bool _isMotionTextElementId(String clipId) =>
      _motionTextElementContextForId(clipId) != null;

  _MotionTextTimelineEntry? _motionTextTimelineEntryForElementId(
    String elementId, {
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    final currentProject = _motionProject;
    if (currentProject == null) {
      return null;
    }
    final entries = bindings == null ||
            identical(bindings, _motionTextAnimationBindings)
        ? _currentMotionTextTimelineEntries()
        : _buildMotionTextTimelineEntries(currentProject, bindings: bindings);
    for (final entry in entries) {
      if (entry.elementId == elementId) {
        return entry;
      }
    }
    return null;
  }

  TimelineTime? _timelineTimeForMotionTextSelection(String elementId) {
    final entry = _motionTextTimelineEntryForElementId(elementId);
    if (entry == null) {
      return null;
    }
    final entryStart =
        entry.start.clamp(TimelineTime.zero, _timelineDurationTime);
    final entryEnd = entry.end.clamp(TimelineTime.zero, _timelineDurationTime);
    if (_currentTime >= entryStart && _currentTime < entryEnd) {
      return _currentTime;
    }
    return entryStart;
  }

  String? _previewAssetIdForTimelineTime(
    TimelineTime targetTime, {
    String? preferredAssetId,
  }) {
    return _resolvedPreviewAssetIdForTracks(
      _timelineTruthTracks,
      preferredAssetId: preferredAssetId,
      preferredTimelineTime: targetTime,
    );
  }

  String? _motionTextSelectionFallbackForProject(
    MotionProjectModel project,
    TimelineTime targetTime, {
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    final entries = (_matchesCurrentMotionTimelineProjection(
      project,
      bindings: bindings,
    )
            ? _currentMotionTextTimelineEntries()
            : _buildMotionTextTimelineEntries(project, bindings: bindings))
        .toList(growable: false)
      ..sort((left, right) => left.start.compareTo(right.start));
    if (entries.isEmpty) {
      return null;
    }
    for (final entry in entries) {
      if (targetTime >= entry.start && targetTime < entry.end) {
        return entry.elementId;
      }
    }
    for (final entry in entries) {
      if (entry.start >= targetTime) {
        return entry.elementId;
      }
    }
    return entries.last.elementId;
  }

  _ResolvedMotionTextTimelineState _resolveMotionTextTimelineStateForProject({
    required MotionProjectModel project,
    required TimelineTime preferredTimelineTime,
    String? preferredSelectedElementId,
    List<MotionTextAnimationBindingModel>? bindings,
  }) {
    final nextDisplayTracks = _displayTracksForProject(
      project,
      bindings: bindings,
    );
    final nextDuration = _timelineDurationForTracksTime(nextDisplayTracks);
    var resolvedTimelineTime = preferredTimelineTime.clamp(
      TimelineTime.zero,
      nextDuration,
    );
    var resolvedSelectedClipId = preferredSelectedElementId;
    if (resolvedSelectedClipId != null &&
        _selectedClipContextForTracks(
                nextDisplayTracks, resolvedSelectedClipId) ==
            null) {
      resolvedSelectedClipId = null;
    }
    resolvedSelectedClipId ??= _motionTextSelectionFallbackForProject(
      project,
      resolvedTimelineTime,
      bindings: bindings,
    );
    final selectedContext = resolvedSelectedClipId == null
        ? null
        : _selectedClipContextForTracks(
            nextDisplayTracks, resolvedSelectedClipId);
    if (selectedContext != null &&
        (resolvedTimelineTime < selectedContext.clipStartTime ||
            resolvedTimelineTime >= selectedContext.clipEndTime)) {
      resolvedTimelineTime = selectedContext.clipStartTime.clamp(
        TimelineTime.zero,
        nextDuration,
      );
    }
    final resolvedPreviewAssetId = _resolvedPreviewAssetIdForTracks(
      nextDisplayTracks,
      preferredTimelineTime: resolvedTimelineTime,
    );
    return _ResolvedMotionTextTimelineState(
      selectedClipId: resolvedSelectedClipId,
      timelineTime: resolvedTimelineTime,
      previewAssetId: resolvedPreviewAssetId,
    );
  }

  _ResolvedMotionTextTimelineState? _resolveMotionTextTrimPreviewState({
    required String clipId,
    required TimelineTrimEdge edge,
    required TimelineTime sourceStartTime,
    required TimelineTime durationTime,
    required TimelineTime preferredTimelinePreviewTime,
  }) {
    final timelineContext = _selectedClipContextForTracks(
      _timelineTruthTracks,
      clipId,
    );
    final motionContext = _motionTextElementContextForId(clipId);
    if (timelineContext == null || motionContext == null) {
      return null;
    }
    final resolvedTrim = _resolveTimelineTrimValues(
      context: timelineContext,
      edge: edge,
      sourceStartTime: sourceStartTime,
      durationTime: durationTime,
    );
    final nextProjectRange = TimelineTimeRange(
      start: resolvedTrim.sourceStartTime,
      endExclusive: resolvedTrim.sourceStartTime + resolvedTrim.durationTime,
    );
    final nextLocalRange = TimelineTimeRange(
      start: nextProjectRange.start - motionContext.scene.projectRange.start,
      endExclusive: nextProjectRange.endExclusive -
          motionContext.scene.projectRange.start,
    );
    final updatedElement = motionContext.element.copyWith(
      localRange: nextLocalRange,
    );
    final nextElements =
        List<MotionElementModel>.from(motionContext.layer.elements)
          ..[motionContext.elementIndex] = updatedElement;
    final nextLayer = motionContext.layer.copyWith(elements: nextElements);
    final nextLayers = List<MotionLayerModel>.from(motionContext.scene.layers)
      ..[motionContext.layerIndex] = nextLayer;
    final nextScene = motionContext.scene.copyWith(layers: nextLayers);
    final nextScenes = List<MotionSceneModel>.from(motionContext.project.scenes)
      ..[motionContext.sceneIndex] = nextScene;
    final nextProject = motionContext.project.copyWith(scenes: nextScenes);
    final nextBindings = _motionTextAnimationBindings.map((binding) {
      if (binding.elementTarget.targetId != clipId) {
        return binding;
      }
      return MotionTextAnimationBindingModel(
        id: binding.id,
        elementTarget: binding.elementTarget,
        activeRange: nextProjectRange,
        presetId: binding.presetId,
        animationBlocks: binding.animationBlocks,
        parameterValues: binding.parameterValues,
      );
    }).toList(growable: false);
    return _resolveMotionTextTimelineStateForProject(
      project: nextProject,
      preferredTimelineTime: preferredTimelinePreviewTime,
      preferredSelectedElementId: clipId,
      bindings: nextBindings,
    );
  }

  String _nextMotionEntityId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_motionRevision + 1}';
  }

  TimelineTimeRange _expandedTimeRange(
    TimelineTimeRange original,
    TimelineTimeRange inserted,
  ) {
    final start =
        original.start <= inserted.start ? original.start : inserted.start;
    final end = original.endExclusive >= inserted.endExclusive
        ? original.endExclusive
        : inserted.endExclusive;
    return TimelineTimeRange(start: start, endExclusive: end);
  }

  double _elementScalarPropertyOrDefault(
    MotionElementModel element,
    MotionPropertyDefinition definition,
  ) {
    for (final property in element.properties) {
      if (property.definition.id != definition.id) {
        continue;
      }
      if (property.value.kind == MotionPropertyValueKind.scalar) {
        return property.value.rawValue as double;
      }
    }
    return definition.defaultValue.rawValue as double;
  }

  double _evaluatedTextScalarPropertyOrDefault(
    _MotionTextElementContext context,
    MotionPropertyDefinition definition, {
    TimelineTime? time,
  }) {
    final fallback = _elementScalarPropertyOrDefault(
      context.element,
      definition,
    );
    final composition = _motionCompositionForCurrentState();
    if (composition == null) {
      return fallback;
    }
    final evaluatedTime = (time ?? _timelineDisplayTimeNotifier.value).clamp(
      TimelineTime.zero,
      composition.projectRange.endExclusive,
    );
    final evaluation = _motionEvaluator.evaluate(
      MotionEvaluationRequest(
        composition: composition,
        time: evaluatedTime,
        reason: MotionEvaluationReason.diagnostics,
        includeInactiveElements: true,
        includeInactiveLayers: true,
        includeInactiveScenes: true,
      ),
    );
    for (final scene in evaluation.scenes) {
      for (final layer in scene.layers) {
        for (final element in layer.elements) {
          if (element.id != context.element.id) {
            continue;
          }
          for (final property in element.properties) {
            if (property.definition.id != definition.id ||
                property.value.kind != MotionPropertyValueKind.scalar) {
              continue;
            }
            return property.value.rawValue as double;
          }
        }
      }
    }
    return fallback;
  }

  Map<String, double> _baseScalarValuesForTextElement(
    _MotionTextElementContext context,
    Iterable<MotionPropertyDefinition> definitions,
  ) {
    return <String, double>{
      for (final definition in definitions)
        definition.id: _elementScalarPropertyOrDefault(
          context.element,
          definition,
        ),
    };
  }

  List<MotionPropertyChannelModel> _setTextMotionScalarKeyframes({
    required _MotionTextElementContext context,
    required Map<MotionPropertyDefinition, double> scalarValues,
  }) {
    return _buildTextMotionKeyframeAuthoringService().setScalarKeyframes(
      TextMotionScalarKeyframeAuthoringRequest(
        channels: _manualMotionPropertyChannels,
        target: context.elementTarget,
        activeRange: _motionTextTimingRangeForElement(
          scene: context.scene,
          element: context.element,
        ),
        time: _timelineDisplayTimeNotifier.value,
        scalarValues: scalarValues,
        baseScalarValues: _baseScalarValuesForTextElement(
          context,
          scalarValues.keys,
        ),
      ),
    );
  }

  double? _bindingScalarParameter(
    MotionTextAnimationBindingModel? binding,
    String parameterId,
  ) {
    final value = binding?.parameterValues[parameterId];
    if (value == null || value.kind != MotionPropertyValueKind.scalar) {
      return null;
    }
    return value.rawValue as double;
  }

  String? _selectedCanvasTextElementIdForSnapshot(
    MotionTextRenderSnapshot snapshot,
  ) {
    final candidateElementId = _hasSelectedMotionTextClip
        ? _selectedClipId
        : _textEditSession?.elementId;
    if (candidateElementId == null) {
      return null;
    }
    for (final node in snapshot.nodes) {
      if (node.targetElementId == candidateElementId) {
        return candidateElementId;
      }
    }
    return null;
  }

  bool get _hasSelectedImportedClip =>
      _selectedClipContext?.asset?.isImported == true;

  bool get _hasSelectedMotionTextClip =>
      _selectedClipId != null && _isMotionTextElementId(_selectedClipId!);

  bool get _hasSelectedSpeedEditableClip {
    final context = _selectedClipContext;
    return _hasSelectedImportedClip &&
        context != null &&
        context.track.kind == TimelineTrackKind.video &&
        context.clip.type == TimelineClipType.media &&
        context.asset?.tab == EditorMediaTab.video;
  }

  EditorMediaTab get _effectiveDockActiveTab =>
      _activeTab == EditorMediaTab.speed && !_hasSelectedSpeedEditableClip
          ? EditorMediaTab.video
          : _activeTab;

  TimelineTrimSelection? get _timelineTrimSelection {
    final context = _selectedClipContext;
    if (context == null ||
        _activeTrimClipId != context.clip.id ||
        context.clip.type != TimelineClipType.media) {
      return null;
    }
    if (context.track.kind != TimelineTrackKind.video &&
        context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    if (context.track.kind == TimelineTrackKind.text &&
        !_isMotionTextElementId(context.clip.id)) {
      return null;
    }
    final assetDurationSeconds = context.asset?.durationSeconds;
    final clipStartTime = context.clipStartTime;
    final clipEndTime = context.clipEndTime;
    final playheadBarrierTime =
        _currentTime >= clipStartTime && _currentTime <= clipEndTime
            ? _currentTime
            : null;
    return TimelineTrimSelection(
      clipId: context.clip.id,
      trackKind: context.track.kind,
      clipStartTime: clipStartTime,
      durationTime: context.clip.durationTime,
      sourceStartTime: context.clip.sourceStartTime,
      sourceDurationTime: context.clip.sourceDurationTime,
      playbackRate: context.clip.playbackRate,
      minDurationTime: _minEditableClipDurationTime,
      playheadBarrierTime: playheadBarrierTime,
      assetDurationTime: assetDurationSeconds == null
          ? null
          : TimelineTime.fromSecondsDouble(assetDurationSeconds),
    );
  }

  bool get _canSplitSelectedClip {
    final context = _selectedClipContext;
    if (!_hasSelectedImportedClip || context == null) {
      return false;
    }
    final splitOffset = _currentTime - context.clipStartTime;
    return splitOffset > _minEditableClipDurationTime &&
        splitOffset < context.clip.durationTime - _minEditableClipDurationTime;
  }

  double get _previewAspectRatio => _workspaceAspectRatio;

  void _applyTimelineDisplayTime(TimelineTime time) {
    if (_timelineDisplayTimeNotifier.value != time) {
      _timelineDisplayTimeNotifier.value = time;
    }
    _syncTransitionFocusTimeNotifiers();
    _syncLayerScopeTimeNotifiers();
  }

  void _setTimelineDisplayTime(TimelineTime time) {
    final clamped = time.clamp(TimelineTime.zero, _timelineDurationTime);
    final zoomLockedTime = _timelineZoomLockedDisplayTime;
    if (zoomLockedTime != null) {
      _applyTimelineDisplayTime(zoomLockedTime);
      return;
    }
    _applyTimelineDisplayTime(clamped);
  }

  void _setCurrentTime(TimelineTime time) {
    final clamped = time.clamp(TimelineTime.zero, _timelineDurationTime);
    final zoomLockedTime = _timelineZoomLockedDisplayTime;
    if (zoomLockedTime != null) {
      _applyTimelineDisplayTime(zoomLockedTime);
      return;
    }
    _currentTime = clamped;
    _setTimelineDisplayTime(clamped);
    if (!_isTimelineScrubbing && (!_isPlaying || !_useNativePreview)) {
      _setPlaybackSampleTime(clamped);
    }
  }

  void _syncTimelineClockDuration() {
    _timelineClockCoordinator.setTimelineDuration(_timelineDurationTime);
  }

  void _applyTimelineClockSnapshotToUi({
    bool updatePlaybackSample = true,
  }) {
    final clockTime = _timelineClockCoordinator.time.clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    _currentTime = clockTime;
    _setTimelineDisplayTime(clockTime);
    if (updatePlaybackSample) {
      _setPlaybackSampleTime(clockTime);
    }
  }

  void _requestTimelineClockPlaybackStart(TimelineTime time) {
    _syncTimelineClockDuration();
    _timelineClockCoordinator.playFrom(time);
    _applyTimelineClockSnapshotToUi();
  }

  TimelineClockSampleDecision _applyNativePlaybackSampleToTimelineClock(
    TimelineTime reportedTransportTime,
  ) {
    _syncTimelineClockDuration();
    if (_timelineClockCoordinator.phase != TimelineClockPhase.playStarting &&
        _timelineClockCoordinator.phase != TimelineClockPhase.playing) {
      _timelineClockCoordinator.playFrom(_currentTime);
    }
    final decision =
        _timelineClockCoordinator.applyNativeSample(reportedTransportTime);
    if (decision == TimelineClockSampleDecision.accepted) {
      _applyTimelineClockSnapshotToUi();
    }
    return decision;
  }

  bool get _shouldDriveDisplayTimeFromPlaybackSample =>
      _useNativePreview &&
      _isPlaying &&
      !_isTimelineScrubbing &&
      !_isTimelineScrubHandoffInFlight &&
      !_isApplyingStructuralEdit &&
      _timelineZoomLockedDisplayTime == null &&
      _timelineTrimPreviewSession == null &&
      !_transportController.state.isScrubSettling;

  void _setPlaybackSampleTime(TimelineTime time) {
    final clamped = time.clamp(TimelineTime.zero, _timelineDurationTime);
    final shouldDriveDisplayTime = _shouldDriveDisplayTimeFromPlaybackSample;
    if (_playbackSampleTimeNotifier.value != clamped) {
      _playbackSampleTimeNotifier.value = clamped;
    }
    if (shouldDriveDisplayTime) {
      _applyTimelineDisplayTime(clamped);
      return;
    }
    _syncTransitionFocusTimeNotifiers();
    _syncLayerScopeTimeNotifiers();
  }

  void _applyTimelineZoomState({
    required bool isZooming,
    required TimelineTime globalAnchorTime,
    required int revision,
  }) {
    final anchorTime = globalAnchorTime.clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    if (isZooming) {
      _timelineZoomLockRevision = revision;
      _timelineZoomLockedDisplayTime = anchorTime;
      _applyTimelineDisplayTime(anchorTime);
      return;
    }
    if (revision < _timelineZoomLockRevision) {
      return;
    }
    final visibleTime = (_timelineZoomLockedDisplayTime ?? anchorTime).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    _timelineZoomLockedDisplayTime = null;
    _applyTimelineDisplayTime(visibleTime);
  }

  void _handleTimelineZoomStateChanged(TimelineZoomState state) {
    _applyTimelineZoomState(
      isZooming: state.isZooming,
      globalAnchorTime: state.anchorTime,
      revision: state.revision,
    );
  }

  bool _shouldUseMotionPreviewFrameClock(Stage5TransportState state) {
    if (_timelineClockCoordinatorOwnsPlaybackSamples) {
      return false;
    }
    return _useNativePreview &&
        state.isPlaying &&
        !_isTimelineScrubbing &&
        !_isTimelineScrubHandoffInFlight &&
        !_isApplyingStructuralEdit &&
        _timelineTrimPreviewSession == null &&
        !state.isScrubSettling;
  }

  void _syncMotionPreviewFrameClock(TimelineTime transportTime) {
    final elapsed = _motionPreviewClockLatestElapsed;
    if (!_motionPreviewFrameTicker.isActive) {
      final visibleSampleTime = _playbackSampleTimeNotifier.value.clamp(
        TimelineTime.zero,
        _timelineDurationTime,
      );
      final initialDriftSeconds =
          (transportTime - visibleSampleTime).inSecondsDouble.abs();
      final anchorTime =
          initialDriftSeconds <= _motionPreviewClockResyncThresholdSeconds
              ? visibleSampleTime
              : transportTime;
      _motionPreviewClockAnchorTime = anchorTime;
      _motionPreviewClockAnchorElapsed = elapsed;
      _setPlaybackSampleTime(anchorTime);
      _motionPreviewFrameTicker.start();
      return;
    }

    final predictedTime = _motionPreviewClockTimeForElapsed(elapsed);
    final driftSeconds = (transportTime - predictedTime).inSecondsDouble.abs();
    if (driftSeconds > _motionPreviewClockResyncThresholdSeconds) {
      _motionPreviewClockAnchorTime = transportTime;
      _motionPreviewClockAnchorElapsed = elapsed;
      _setPlaybackSampleTime(transportTime);
    }
  }

  void _primeMotionPreviewFrameClockForPlaybackStart(
    TimelineTime transportTime,
  ) {
    if (!_useNativePreview ||
        _isTimelineScrubbing ||
        _isApplyingStructuralEdit ||
        _timelineTrimPreviewSession != null) {
      return;
    }
    _motionPreviewClockAnchorTime = transportTime.clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    _motionPreviewClockAnchorElapsed = _motionPreviewClockLatestElapsed;
    _setPlaybackSampleTime(_motionPreviewClockAnchorTime);
    if (!_motionPreviewFrameTicker.isActive) {
      _motionPreviewFrameTicker.start();
    }
  }

  void _stopMotionPreviewFrameClock({TimelineTime? resetTo}) {
    if (_motionPreviewFrameTicker.isActive) {
      _motionPreviewFrameTicker.stop(canceled: false);
    }
    _motionPreviewClockAnchorElapsed = _motionPreviewClockLatestElapsed;
    if (resetTo != null) {
      _motionPreviewClockAnchorTime = resetTo;
      _setPlaybackSampleTime(resetTo);
    }
  }

  TimelineTime _motionPreviewClockTimeForElapsed(Duration elapsed) {
    final delta = elapsed - _motionPreviewClockAnchorElapsed;
    final deltaSeconds = delta.inMicroseconds / Duration.microsecondsPerSecond;
    return (_motionPreviewClockAnchorTime +
            TimelineTime.fromSecondsDouble(deltaSeconds))
        .clamp(TimelineTime.zero, _timelineDurationTime);
  }

  void _handleMotionPreviewFrameTick(Duration elapsed) {
    _motionPreviewClockLatestElapsed = elapsed;
    if (!mounted) {
      return;
    }
    final transportState = _transportController.state;
    if (!_shouldUseMotionPreviewFrameClock(transportState)) {
      _stopMotionPreviewFrameClock();
      return;
    }
    _setPlaybackSampleTime(_motionPreviewClockTimeForElapsed(elapsed));
  }

  void _syncTransitionFocusTimeNotifiers() {
    final session = _transitionFocusSession;
    final context = session == null
        ? null
        : _transitionFocusContextById(session.transitionId);
    if (context == null) {
      if (_transitionFocusDisplayTimeNotifier.value != TimelineTime.zero) {
        _transitionFocusDisplayTimeNotifier.value = TimelineTime.zero;
      }
      if (_transitionFocusPlaybackSampleTimeNotifier.value !=
          TimelineTime.zero) {
        _transitionFocusPlaybackSampleTimeNotifier.value = TimelineTime.zero;
      }
      return;
    }
    final localDisplayTime = _transitionFocusLocalTime(
      context,
      _timelineDisplayTimeNotifier.value,
    );
    final localPlaybackSampleTime = _transitionFocusLocalTime(
      context,
      _playbackSampleTimeNotifier.value,
    );
    if (_transitionFocusDisplayTimeNotifier.value != localDisplayTime) {
      _transitionFocusDisplayTimeNotifier.value = localDisplayTime;
    }
    if (_transitionFocusPlaybackSampleTimeNotifier.value !=
        localPlaybackSampleTime) {
      _transitionFocusPlaybackSampleTimeNotifier.value =
          localPlaybackSampleTime;
    }
  }

  void _syncLayerScopeTimeNotifiers() {
    final context = _activeLayerScopeContext;
    if (context == null) {
      if (_layerScopeDisplayTimeNotifier.value != TimelineTime.zero) {
        _layerScopeDisplayTimeNotifier.value = TimelineTime.zero;
      }
      if (_layerScopePlaybackSampleTimeNotifier.value != TimelineTime.zero) {
        _layerScopePlaybackSampleTimeNotifier.value = TimelineTime.zero;
      }
      return;
    }
    final localDisplayTime = _layerScopeLocalTime(
      context,
      _timelineDisplayTimeNotifier.value,
    );
    final localPlaybackSampleTime = _layerScopeLocalTime(
      context,
      _playbackSampleTimeNotifier.value,
    );
    if (_layerScopeDisplayTimeNotifier.value != localDisplayTime) {
      _layerScopeDisplayTimeNotifier.value = localDisplayTime;
    }
    if (_layerScopePlaybackSampleTimeNotifier.value !=
        localPlaybackSampleTime) {
      _layerScopePlaybackSampleTimeNotifier.value = localPlaybackSampleTime;
    }
  }

  void _syncPlaybackSampleToCurrentTime() {
    _setPlaybackSampleTime(_currentTime);
  }

  void _clearPlaybackStopTimeLock() {
    _playbackStopTimeLockTimer?.cancel();
    _playbackStopTimeLockTimer = null;
    _playbackStopTimeLock = null;
    _playbackStopTimeLockRevision++;
  }

  void _activatePlaybackStopTimeLock(
    TimelineTime time, {
    Duration hold = const Duration(milliseconds: 550),
  }) {
    final lockedTime = time.clamp(TimelineTime.zero, _timelineDurationTime);
    _playbackStopTimeLockTimer?.cancel();
    _playbackStopTimeLock = lockedTime;
    _playbackStopTimeLockRevision++;
    final revision = _playbackStopTimeLockRevision;
    _setCurrentTime(lockedTime);
    _setPlaybackSampleTime(lockedTime);
    _playbackStopTimeLockTimer = Timer(hold, () {
      if (!mounted || revision != _playbackStopTimeLockRevision) {
        return;
      }
      _playbackStopTimeLock = null;
      _playbackStopTimeLockTimer = null;
    });
  }

  bool _shouldApplyPlaybackStopTimeLock(
    Stage5TransportState transportState,
  ) {
    return _playbackStopTimeLock != null &&
        !transportState.isPlaying &&
        !_isTimelineScrubbing &&
        !_isTimelineScrubHandoffInFlight &&
        !_isApplyingStructuralEdit;
  }

  int _timelineDistanceMs(TimelineTime left, TimelineTime right) =>
      (left.inMilliseconds - right.inMilliseconds).abs();

  bool _transportStateMatchesTimelineTime(
    Stage5TransportState state,
    TimelineTime time, {
    int toleranceMs = _playbackStartPositionToleranceMs,
    bool requireSettled = true,
  }) {
    if (requireSettled && state.isScrubSettling) {
      return false;
    }
    final targetMs =
        time.clamp(TimelineTime.zero, _timelineDurationTime).inMilliseconds;
    return (state.positionMs - targetMs).abs() <= toleranceMs;
  }

  bool _currentTransportMatchesTimelineTime(
    TimelineTime time, {
    int toleranceMs = _playbackStartPositionToleranceMs,
    bool requireSettled = true,
  }) =>
      _transportStateMatchesTimelineTime(
        _transportController.state,
        time,
        toleranceMs: toleranceMs,
        requireSettled: requireSettled,
      );

  Future<bool> _waitForTransportTimelineTime(
    TimelineTime time, {
    Duration timeout = const Duration(milliseconds: 700),
    int toleranceMs = _playbackStartPositionToleranceMs,
    bool requireSettled = true,
  }) async {
    final target = time.clamp(TimelineTime.zero, _timelineDurationTime);
    if (_currentTransportMatchesTimelineTime(
      target,
      toleranceMs: toleranceMs,
      requireSettled: requireSettled,
    )) {
      return true;
    }

    final completer = Completer<bool>();
    Timer? timer;
    late final VoidCallback listener;

    void finish(bool matched) {
      if (completer.isCompleted) {
        return;
      }
      timer?.cancel();
      _transportController.removeListener(listener);
      completer.complete(matched);
    }

    listener = () {
      if (_transportStateMatchesTimelineTime(
        _transportController.state,
        target,
        toleranceMs: toleranceMs,
        requireSettled: requireSettled,
      )) {
        finish(true);
      }
    };

    _transportController.addListener(listener);
    timer = Timer(timeout, () => finish(false));
    listener();
    return completer.future;
  }

  void _clearTimelineScrubHandoff() {
    _isTimelineScrubHandoffInFlight = false;
    _timelineScrubHandoffTargetTime = null;
    _timelineScrubFinalTime = null;
    _timelineScrubHandoffRevision++;
  }

  void _completeTimelineScrubHandoffIfReady(
    Stage5TransportState transportState,
    TimelineTime reportedTransportTime,
  ) {
    if (!_isTimelineScrubHandoffInFlight || _isTimelineScrubbing) {
      return;
    }
    final target = _timelineScrubHandoffTargetTime;
    if (target == null || transportState.isScrubSettling) {
      return;
    }
    if (_timelineDistanceMs(reportedTransportTime, target) >
        _playbackStartPositionToleranceMs) {
      return;
    }
    _timelineClockCoordinator.confirmScrubSettled(target);
    _applyTimelineClockSnapshotToUi();
    _clearTimelineScrubHandoff();
  }

  Future<bool> _resolveTimelineScrubHandoffBeforePlayback(
    TimelineTime playbackTime,
  ) async {
    if (!_isTimelineScrubHandoffInFlight) {
      return true;
    }

    final handoffRevision = _timelineScrubHandoffRevision;
    final handoffTarget = (_timelineScrubHandoffTargetTime ?? playbackTime)
        .clamp(TimelineTime.zero, _timelineDurationTime);
    final resolvedPlaybackTime = handoffTarget;

    if (!mounted) {
      return false;
    }

    if (!_isTimelineScrubHandoffInFlight) {
      return true;
    }

    if (handoffRevision != _timelineScrubHandoffRevision) {
      return false;
    }

    final nativeSettled = await _waitForTransportTimelineTime(handoffTarget);
    if (!mounted) {
      return false;
    }
    if (!_isTimelineScrubHandoffInFlight) {
      return true;
    }
    if (handoffRevision != _timelineScrubHandoffRevision) {
      return false;
    }

    if (nativeSettled) {
      _timelineClockCoordinator.confirmScrubSettled(handoffTarget);
    }
    _timelineClockCoordinator.pauseAt(resolvedPlaybackTime);
    _applyTimelineClockSnapshotToUi();
    _clearTimelineScrubHandoff();
    return true;
  }

  Future<bool> _prepareTransportForPlaybackStart(
    TimelineTime playbackTime,
  ) async {
    if (!_useNativePreview || !_transportController.isPlatformSupported) {
      return true;
    }
    final target = playbackTime.clamp(TimelineTime.zero, _timelineDurationTime);

    if (_isTimelineScrubHandoffInFlight) {
      final handoffResolved =
          await _resolveTimelineScrubHandoffBeforePlayback(target);
      if (!handoffResolved) {
        return false;
      }
    }

    return true;
  }

  Future<void> _pausePlayback() => _transportController.pause();

  Future<void> _playPlayback() => _transportController.play();

  Future<void> _playPlaybackFrom(TimelineTime time) {
    if (!_useNativePreview || !_transportController.isPlatformSupported) {
      return _playPlayback();
    }
    final clampedTime = time.clamp(TimelineTime.zero, _timelineDurationTime);
    return _transportController.playFromPositionMs(clampedTime.inMilliseconds);
  }

  Future<void> _seekPlaybackTo(TimelineTime time) =>
      _transportController.seekToPositionMs(time.inMilliseconds);

  bool get _useNativePreview {
    if (!_transportController.isPlatformSupported) {
      return false;
    }
    final previewAsset = _previewAsset;
    if (previewAsset == null) {
      return false;
    }
    return previewAsset.tab == EditorMediaTab.video;
  }

  bool get _useNativeTimelineScrubInput =>
      _useNativePreview &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  void _handleTransportStateChanged() {
    final transportState = _transportController.state;
    final enteringPlayback = transportState.isPlaying && !_isPlaying;
    final previewRange = _textEditPreviewRange;
    if (previewRange != null &&
        !_isStoppingTextEditPreviewPlayback &&
        transportState.isPlaying &&
        transportState.positionMs >= previewRange.end.inMilliseconds) {
      unawaited(_stopTextEditPreviewPlayback(snapToEnd: true));
    }
    final transitionFocusSession = _transitionFocusSession;
    final transitionFocusContext = transitionFocusSession == null
        ? null
        : _transitionFocusContextById(transitionFocusSession.transitionId);
    if (transitionFocusContext != null &&
        !_isStoppingTransitionFocusPlayback &&
        transportState.isPlaying &&
        transportState.positionMs >=
            transitionFocusContext.endTime.inMilliseconds) {
      unawaited(
        _stopTransitionFocusPlayback(
          transitionFocusContext,
          snapToStart: false,
          snapToEnd: true,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    final previewAsset = _previewAsset;
    if (previewAsset != null &&
        previewAsset.tab == EditorMediaTab.video &&
        transportState.videoWidth > 0 &&
        transportState.videoHeight > 0 &&
        (previewAsset.width != transportState.videoWidth ||
            previewAsset.height != transportState.videoHeight)) {
      _replaceKnownAssetMetadata(
        previewAsset.copyWith(
          width: transportState.videoWidth,
          height: transportState.videoHeight,
        ),
        invalidatePreviewThumbnail: _previewAssetId == previewAsset.id &&
            !transportState.hasRenderedFirstFrame,
      );
    }
    final isTrimPreviewActive = _timelineTrimPreviewSession != null;
    final nextAspectRatio = (_lockedWorkspaceAspectRatio == null &&
            (transportState.sourceKind == 'imported' ||
                transportState.sourceKind == 'timeline') &&
            _transportController.aspectRatio != null &&
            _transportController.aspectRatio! > 0)
        ? _transportController.aspectRatio
        : _lockedWorkspaceAspectRatio;
    final reportedTransportTime = TimelineTime.fromMilliseconds(
      transportState.positionMs,
    ).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    _completeTimelineScrubHandoffIfReady(
      transportState,
      reportedTransportTime,
    );
    final shouldAdoptPlayingTransportDuringStructuralEdit =
        _isApplyingStructuralEdit && transportState.isPlaying;
    final shouldAdoptTransportTime = (!_isApplyingStructuralEdit ||
            shouldAdoptPlayingTransportDuringStructuralEdit) &&
        !_isTimelineScrubbing &&
        !_isTimelineScrubHandoffInFlight &&
        !isTrimPreviewActive &&
        !transportState.isScrubSettling;
    if (_shouldApplyPlaybackStopTimeLock(transportState)) {
      final lockedTime = _playbackStopTimeLock!.clamp(
        TimelineTime.zero,
        _timelineDurationTime,
      );
      final shouldUpdateAspect = nextAspectRatio != _lockedWorkspaceAspectRatio;
      if (shouldUpdateAspect || _isPlaying) {
        setState(() {
          _lockedWorkspaceAspectRatio = nextAspectRatio;
          _isPlaying = false;
        });
      }
      _setCurrentTime(lockedTime);
      _setPlaybackSampleTime(lockedTime);
      return;
    }
    var acceptedTransportTime = reportedTransportTime;
    var shouldAdoptClockTime = shouldAdoptTransportTime;
    if (transportState.isPlaying && shouldAdoptTransportTime) {
      final clockDecision =
          _applyNativePlaybackSampleToTimelineClock(reportedTransportTime);
      if (clockDecision == TimelineClockSampleDecision.accepted) {
        acceptedTransportTime = _timelineClockCoordinator.time;
      } else if (clockDecision == TimelineClockSampleDecision.rejectedStale) {
        shouldAdoptClockTime = false;
      }
    } else if (!transportState.isPlaying &&
        shouldAdoptTransportTime &&
        _timelineClockCoordinator.snapshot.isPlaybackActive) {
      _timelineClockCoordinator.pauseAt(reportedTransportTime);
      acceptedTransportTime = _timelineClockCoordinator.time;
    }
    final isTransientPlaybackRegression = transportState.isPlaying &&
        shouldAdoptClockTime &&
        (_currentTime - acceptedTransportTime).inSecondsDouble > 0 &&
        (_currentTime - acceptedTransportTime).inSecondsDouble <= 0.24;
    final shouldUseMotionPreviewFrameClock = shouldAdoptClockTime &&
        !isTransientPlaybackRegression &&
        _shouldUseMotionPreviewFrameClock(transportState);
    if (enteringPlayback &&
        _shouldUseMotionPreviewFrameClock(transportState) &&
        !_transportController.state.isScrubSettling) {
      _primeMotionPreviewFrameClockForPlaybackStart(acceptedTransportTime);
    }
    if (shouldAdoptClockTime && !isTransientPlaybackRegression) {
      if (shouldUseMotionPreviewFrameClock) {
        _syncMotionPreviewFrameClock(acceptedTransportTime);
      } else {
        _stopMotionPreviewFrameClock(resetTo: acceptedTransportTime);
      }
      if (!transportState.isPlaying) {
        _setTimelineDisplayTime(acceptedTransportTime);
      }
    } else if (!_shouldUseMotionPreviewFrameClock(transportState)) {
      _stopMotionPreviewFrameClock();
    }
    final shouldUpdatePlaying = (!_isApplyingStructuralEdit ||
            shouldAdoptPlayingTransportDuringStructuralEdit) &&
        transportState.isPlaying != _isPlaying;
    final nextCurrentTime =
        shouldAdoptClockTime && !isTransientPlaybackRegression
            ? acceptedTransportTime
            : _currentTime;
    final shouldUpdateAspect = nextAspectRatio != _lockedWorkspaceAspectRatio;
    final shouldUpdateTime = nextCurrentTime != _currentTime;
    if (!shouldUpdateAspect && !shouldUpdateTime && !shouldUpdatePlaying) {
      return;
    }
    if (!shouldUpdateAspect && !shouldUpdatePlaying) {
      _setCurrentTime(nextCurrentTime);
      return;
    }
    setState(() {
      _lockedWorkspaceAspectRatio = nextAspectRatio;
      _isPlaying = transportState.isPlaying;
    });
    if (shouldUpdateTime) {
      _setCurrentTime(nextCurrentTime);
    } else if (!transportState.isPlaying) {
      _syncPlaybackSampleToCurrentTime();
    }
  }

  void _handleTimelineTimeChanged(TimelineTime time) {
    if (_isApplyingStructuralEdit) {
      return;
    }
    final clampedTime = time.clamp(TimelineTime.zero, _timelineDurationTime);
    if (_isTimelineScrubbing) {
      _timelineScrubFinalTime = clampedTime;
      _timelineClockCoordinator.scrubUpdate(clampedTime);
      _applyTimelineClockSnapshotToUi();
      return;
    }
    if (_isTimelineScrubHandoffInFlight) {
      _timelineScrubFinalTime = clampedTime;
      _timelineScrubHandoffTargetTime = clampedTime;
      return;
    }
    _setCurrentTime(clampedTime);
    if (_useNativePreview && !_isTimelineScrubbing) {
      unawaited(_seekPlaybackTo(clampedTime));
    }
  }

  void _selectClip(String clipId) {
    if (_isMotionTextElementId(clipId)) {
      _selectMotionTextTimelineEntry(clipId);
      return;
    }
    if (_selectedClipId != clipId) {
      _deactivateTimelineTrimMode();
    }
    setState(() {
      _transitionFocusSession = null;
      _selectedClipId = clipId;
      _selectedTransitionId = null;
      if (_activeTab == EditorMediaTab.speed &&
          !_hasSelectedSpeedEditableClip) {
        _activeTab = EditorMediaTab.video;
      }
    });
  }

  void _selectMotionTextTimelineEntry(
    String elementId, {
    bool alignTimelineTime = true,
  }) {
    _deactivateTimelineTrimMode();
    final nextTimelineTime = alignTimelineTime
        ? (_timelineTimeForMotionTextSelection(elementId) ?? _currentTime)
        : _currentTime;
    final nextPreviewAssetId = _previewAssetIdForTimelineTime(nextTimelineTime);
    setState(() {
      _transitionFocusSession = null;
      _selectedClipId = elementId;
      _selectedTransitionId = null;
      _activeTab = EditorMediaTab.text;
      _previewAssetId = nextPreviewAssetId;
      if (alignTimelineTime) {
        _setCurrentTime(nextTimelineTime);
      }
    });
  }

  void _selectTextElement(String elementId) {
    _selectMotionTextTimelineEntry(elementId);
  }

  void _clearSelection() {
    _deactivateTimelineTrimMode();
    setState(() {
      _transitionFocusSession = null;
      _layerScopeSession = null;
      _selectedClipId = null;
      _selectedTransitionId = null;
      if (_activeTab == EditorMediaTab.speed) {
        _activeTab = EditorMediaTab.video;
      }
    });
  }

  void _handleTrimModeToggle() {
    final context = _selectedClipContext;
    if ((!_hasSelectedImportedClip && !_hasSelectedMotionTextClip) ||
        context == null) {
      return;
    }
    final clipId = context.clip.id;
    if (_activeTrimClipId == clipId) {
      _deactivateTimelineTrimMode();
      return;
    }
    setState(() {
      _activeTrimClipId = clipId;
    });
  }

  void _deactivateTimelineTrimMode({bool restoreTransport = true}) {
    final hadActiveTrimMode = _activeTrimClipId != null;
    final activeTrimPreviewSession = _timelineTrimPreviewSession;
    final hadActiveTrimPreview =
        activeTrimPreviewSession != null || _activeTrimPreviewSourceUri != null;
    if (!hadActiveTrimMode && !hadActiveTrimPreview) {
      return;
    }
    final requestId = ++_timelineTrimPreviewRequestId;
    setState(() {
      _activeTrimClipId = null;
      _timelineTrimPreviewSession = null;
      _activeTrimPreviewSourceUri = null;
    });
    if (restoreTransport &&
        hadActiveTrimPreview &&
        _useNativePreview &&
        activeTrimPreviewSession?.usesTransportPreview == true &&
        !_isApplyingStructuralEdit &&
        !_transportController.isPlaying) {
      unawaited(_restoreTimelineTransportAfterTrimPreview(requestId));
    }
  }

  void _handleTimelineClipDoubleTap(String clipId) {
    _enterLayerScope(clipId);
  }

  bool get _isLayerScopeTransitionBlocked =>
      _isTimelineScrubbing ||
      _isApplyingStructuralEdit ||
      _timelineTrimSelection != null;

  _LayerScopeContext? get _activeLayerScopeContext {
    final session = _layerScopeSession;
    if (session == null) {
      return null;
    }
    return _layerScopeContextForClipId(session.clipId);
  }

  _LayerScopeContext? _layerScopeContextForClipId(String clipId) {
    final clipContext = _selectedClipContextForTracks(
      _timelineTruthTracks,
      clipId,
    );
    if (clipContext == null || !_isSupportedLayerScopeContext(clipContext)) {
      return null;
    }
    final duration = clipContext.clip.durationTime;
    if (duration <= TimelineTime.zero) {
      return null;
    }
    return _LayerScopeContext(
      clipContext: clipContext,
      startTime: clipContext.clipStartTime,
      durationTime: duration,
    );
  }

  bool _isSupportedLayerScopeContext(_SelectedTimelineClipContext context) {
    if (context.clip.type != TimelineClipType.media) {
      return false;
    }
    return switch (context.track.kind) {
      TimelineTrackKind.text => _isMotionTextElementId(context.clip.id),
      TimelineTrackKind.image => context.asset?.tab == EditorMediaTab.image &&
          context.asset?.isVisual == true,
      TimelineTrackKind.video ||
      TimelineTrackKind.audio ||
      TimelineTrackKind.lipSync =>
        false,
    };
  }

  String _layerScopeUnavailableMessage(_SelectedTimelineClipContext? context) {
    if (context == null) {
      return 'Scoped timeline is available for text and image layers.';
    }
    return switch (context.track.kind) {
      TimelineTrackKind.video =>
        'Video scope is not enabled yet. Phase 1 supports text and image layers only.',
      TimelineTrackKind.audio =>
        'Audio scope comes later. Phase 1 supports text and image layers only.',
      TimelineTrackKind.lipSync =>
        'Lip sync scope comes later. Phase 1 supports text and image layers only.',
      TimelineTrackKind.text ||
      TimelineTrackKind.image =>
        'This layer is not currently eligible for scoped timeline.',
    };
  }

  String _layerScopeBlockedMessage() {
    if (_isTimelineScrubbing) {
      return 'Finish the current scrub first.';
    }
    if (_isApplyingStructuralEdit) {
      return 'Timeline structure is updating. Try again in a moment.';
    }
    if (_timelineTrimSelection != null) {
      return 'Finish the current trim first.';
    }
    return 'Finish the current timeline gesture first.';
  }

  TimelineTrimSelection? _layerScopeTrimSelection(_LayerScopeContext context) {
    final selection = _timelineTrimSelection;
    if (selection == null || selection.clipId != context.clip.id) {
      return null;
    }
    final localBarrierTime = selection.playheadBarrierTime == null
        ? null
        : _layerScopeLocalTime(context, selection.playheadBarrierTime!).clamp(
            TimelineTime.zero,
            context.durationTime,
          );
    return TimelineTrimSelection(
      clipId: selection.clipId,
      trackKind: selection.trackKind,
      clipStartTime: TimelineTime.zero,
      durationTime: selection.durationTime,
      sourceStartTime: selection.sourceStartTime,
      sourceDurationTime: selection.sourceDurationTime,
      playbackRate: selection.playbackRate,
      minDurationTime: selection.minDurationTime,
      playheadBarrierTime: localBarrierTime,
      assetDurationTime: selection.assetDurationTime,
    );
  }

  void _handleLayerScopeTrimPreviewChanged(
    _LayerScopeContext context,
    TimelineTrimPreviewRequest? request,
  ) {
    if (request == null) {
      _handleTimelineTrimPreviewChanged(null);
      return;
    }
    _handleTimelineTrimPreviewChanged(
      TimelineTrimPreviewRequest(
        clipId: request.clipId,
        edge: request.edge,
        sourceStartTime: request.sourceStartTime,
        durationTime: request.durationTime,
        timelinePreviewTime: _layerScopeGlobalTime(
          context,
          request.timelinePreviewTime,
        ),
        sourcePreviewTime: request.sourcePreviewTime,
      ),
    );
  }

  void _enterLayerScope(String clipId) {
    final clipContext = _selectedClipContextForTracks(
      _timelineTruthTracks,
      clipId,
    );
    final supportsScope =
        clipContext != null && _isSupportedLayerScopeContext(clipContext);
    if (!supportsScope) {
      _showStageMessage(_layerScopeUnavailableMessage(clipContext));
      return;
    }
    if (_isLayerScopeTransitionBlocked) {
      _showStageMessage(_layerScopeBlockedMessage());
      return;
    }
    final context = _layerScopeContextForClipId(clipId);
    if (context == null) {
      _showStageMessage(_layerScopeUnavailableMessage(clipContext));
      return;
    }
    final currentSession = _layerScopeSession;
    if (currentSession?.clipId == clipId) {
      return;
    }
    setState(() {
      _transitionFocusSession = null;
      _selectedTransitionId = null;
      _layerScopeSession = _LayerScopeSession(
        clipId: clipId,
        returnSelectedClipId: _selectedClipId,
      );
      _selectedLayerScopeAnimationLaneId = null;
      _selectedLayerScopeKeyframeIndex = null;
      _selectedLayerScopeKeyframeId = null;
      _isLayerScopeValueEditorOpen = false;
      _selectedClipId = clipId;
      if (_activeTab == EditorMediaTab.speed) {
        _activeTab = EditorMediaTab.video;
      }
    });
    _syncLayerScopeTimeNotifiers();
  }

  void _exitLayerScope() {
    if (_isLayerScopeTransitionBlocked) {
      _showStageMessage('Finish the current timeline gesture first.');
      return;
    }
    final session = _layerScopeSession;
    if (session == null) {
      return;
    }
    setState(() {
      _layerScopeSession = null;
      _selectedLayerScopeAnimationLaneId = null;
      _selectedLayerScopeKeyframeIndex = null;
      _selectedLayerScopeKeyframeId = null;
      _isLayerScopeValueEditorOpen = false;
      _selectedClipId = session.returnSelectedClipId ?? session.clipId;
    });
    _syncLayerScopeTimeNotifiers();
  }

  TimelineTime _layerScopeLocalTime(
    _LayerScopeContext context,
    TimelineTime timelineTime,
  ) {
    final clampedTime = timelineTime.clamp(
      context.startTime,
      context.endTime,
    );
    return (clampedTime - context.startTime).clamp(
      TimelineTime.zero,
      context.durationTime,
    );
  }

  TimelineTime _layerScopeGlobalTime(
    _LayerScopeContext context,
    TimelineTime localTime,
  ) {
    final clampedLocalTime = localTime.clamp(
      TimelineTime.zero,
      context.durationTime,
    );
    return (context.startTime + clampedLocalTime).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
  }

  List<TimelineTrackData> _buildLayerScopeTracks(_LayerScopeContext context) {
    final sourceClip = context.clip.copyWith(
      durationTime: context.durationTime,
      label: _clipPresentationLabel(
        context.clip,
        fallback: context.track.kind == TimelineTrackKind.text
            ? 'Text Layer'
            : 'Image Layer',
      ),
    );
    final layerAnimationLanes = _layerScopeAnimationLanes(context);
    return <TimelineTrackData>[
      TimelineTrackData(
        kind: context.track.kind,
        clips: <TimelineClipData>[sourceClip],
        animationLanes: layerAnimationLanes,
      ),
    ];
  }

  void _handleLayerScopeDisplayTimeChanged(
    _LayerScopeContext context,
    TimelineTime localTime,
  ) {
    _setTimelineDisplayTime(_layerScopeGlobalTime(context, localTime));
  }

  void _handleLayerScopeZoomStateChanged(
    _LayerScopeContext context,
    TimelineZoomState state,
  ) {
    _applyTimelineZoomState(
      isZooming: state.isZooming,
      globalAnchorTime: _layerScopeGlobalTime(context, state.anchorTime),
      revision: state.revision,
    );
  }

  void _handleLayerScopeClipSelected(
    _LayerScopeContext context,
    String clipId,
  ) {
    if (clipId != context.clip.id) {
      return;
    }
    setState(() {
      _selectedClipId = clipId;
      _selectedTransitionId = null;
    });
  }

  List<TimelineAnimationLaneData> _layerScopeAnimationLanes(
    _LayerScopeContext context,
  ) {
    final baseLanes = context.track.animationLanes
        .where((lane) => lane.targetClipId == context.clip.id)
        .toList(growable: true);
    for (final projectedLane in <TimelineAnimationLaneData?>[
      _projectedTextOpacityLaneForScope(context),
      _projectedTextBlurLaneForScope(context),
      _projectedTextPositionLaneForScope(context),
      _projectedTextScaleLaneForScope(context),
      _projectedTextRotationLaneForScope(context),
      _projectedTextRevealLaneForScope(context),
    ]) {
      if (projectedLane == null) {
        continue;
      }
      final laneIndex = baseLanes.indexWhere(
        (lane) => lane.matchesPropertyLabel(projectedLane.label),
      );
      if (laneIndex >= 0) {
        baseLanes[laneIndex] = projectedLane;
      } else {
        baseLanes.add(projectedLane);
      }
    }
    return List<TimelineAnimationLaneData>.unmodifiable(baseLanes);
  }

  List<double> _alignedAnimationKeyframeValues(
    TimelineAnimationLaneData lane,
  ) {
    return lane.alignedKeyframeValues(
      fallbackValue: lane.matchesPropertyLabel('opacity') ? 100.0 : 0.0,
    );
  }

  double _layerScopeProgressToSeconds(
    _LayerScopeContext context,
    double progress,
  ) {
    return context.durationTime.inSecondsDouble * progress.clamp(0.0, 1.0);
  }

  TimelineTime _layerScopeTimeForProgress(
    _LayerScopeContext context,
    double progress,
  ) {
    return _layerScopeGlobalTime(
      context,
      TimelineTime.fromSecondsDouble(
        _layerScopeProgressToSeconds(context, progress),
      ),
    );
  }

  TimelineAnimationLaneData? _layerScopeSelectedAnimationLane(
    _LayerScopeContext context,
  ) {
    final selectedLaneId = _selectedLayerScopeAnimationLaneId;
    if (selectedLaneId == null) {
      return null;
    }
    for (final lane in _layerScopeAnimationLanes(context)) {
      if (lane.id == selectedLaneId && lane.targetClipId == context.clip.id) {
        return lane;
      }
    }
    return null;
  }

  int? _nearestLayerScopeKeyframeIndex(
    _LayerScopeContext context,
    TimelineAnimationLaneData lane,
  ) {
    final stops = lane.normalizedKeyframeStops;
    if (stops.isEmpty) {
      return null;
    }
    final durationSeconds = context.durationTime.inSecondsDouble;
    final progress = durationSeconds <= 0
        ? 0.0
        : (_layerScopeLocalTime(context, _currentTime).inSecondsDouble /
                durationSeconds)
            .clamp(0.0, 1.0);
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < stops.length; index++) {
      final distance = (stops[index].clamp(0.0, 1.0) - progress).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    return nearestIndex;
  }

  bool _layerScopeLaneSupportsValueControls(
    TimelineAnimationLaneData? lane,
  ) {
    return lane != null &&
        (lane.matchesPropertyLabel('opacity') ||
            _layerScopeLaneMatchesBlur(lane) ||
            _layerScopeLaneMatchesReveal(lane) ||
            lane.matchesPropertyLabel('position') ||
            lane.matchesPropertyLabel('scale') ||
            lane.matchesPropertyLabel('rotation'));
  }

  bool _layerScopeLaneMatchesBlur(TimelineAnimationLaneData lane) =>
      lane.matchesPropertyLabel('blur') ||
      lane.matchesPropertyLabel('gaussian blur');

  bool _layerScopeLaneMatchesReveal(TimelineAnimationLaneData lane) =>
      lane.matchesPropertyLabel('type on') ||
      lane.matchesPropertyLabel('word reveal') ||
      lane.matchesPropertyLabel('letter reveal');

  MotionTextRevealUnit _layerScopeRevealUnitForBinding(
    MotionTextAnimationBindingModel? binding,
  ) {
    final value = binding?.parameterValues['revealBy'];
    if (value != null &&
        (value.kind == MotionPropertyValueKind.enumValue ||
            value.kind == MotionPropertyValueKind.stringValue)) {
      final normalized = (value.rawValue as String).trim().toLowerCase();
      if (normalized == 'word') {
        return MotionTextRevealUnit.word;
      }
      if (normalized == 'wholetext' ||
          normalized == 'whole_text' ||
          normalized == 'whole-text') {
        return MotionTextRevealUnit.wholeText;
      }
      return MotionTextRevealUnit.letter;
    }
    for (final block
        in binding?.animationBlocks ?? const <MotionTextAnimationBlock>[]) {
      if (!_isMotionTextRevealBlock(block)) {
        continue;
      }
      final revealSpec = block.revealSpec;
      if (revealSpec != null) {
        return revealSpec.unit;
      }
      if (block.kind == MotionTextAnimationKind.wordReveal) {
        return MotionTextRevealUnit.word;
      }
      if (block.kind == MotionTextAnimationKind.letterReveal ||
          block.kind == MotionTextAnimationKind.typewriter) {
        return MotionTextRevealUnit.letter;
      }
    }
    return MotionTextRevealUnit.letter;
  }

  double _layerScopeRevealByValueForBinding(
    MotionTextAnimationBindingModel? binding,
  ) {
    return _layerScopeRevealUnitForBinding(binding) == MotionTextRevealUnit.word
        ? 0
        : 1;
  }

  MotionTextRevealDirection _layerScopeRevealDirectionForBinding(
    MotionTextAnimationBindingModel? binding,
  ) {
    final value = binding?.parameterValues['revealDirection'];
    if (value != null &&
        (value.kind == MotionPropertyValueKind.enumValue ||
            value.kind == MotionPropertyValueKind.stringValue)) {
      final normalized = (value.rawValue as String).trim().toLowerCase();
      if (normalized == 'reverse' || normalized == 'backward') {
        return MotionTextRevealDirection.reverse;
      }
      return MotionTextRevealDirection.forward;
    }
    for (final block
        in binding?.animationBlocks ?? const <MotionTextAnimationBlock>[]) {
      if (!_isMotionTextRevealBlock(block)) {
        continue;
      }
      final parameterValue = block.parameters['revealDirection'];
      if (parameterValue == null ||
          (parameterValue.kind != MotionPropertyValueKind.enumValue &&
              parameterValue.kind != MotionPropertyValueKind.stringValue)) {
        continue;
      }
      final normalized =
          (parameterValue.rawValue as String).trim().toLowerCase();
      if (normalized == 'reverse' || normalized == 'backward') {
        return MotionTextRevealDirection.reverse;
      }
    }
    return MotionTextRevealDirection.forward;
  }

  double _layerScopeRevealDirectionValueForBinding(
    MotionTextAnimationBindingModel? binding,
  ) {
    return _layerScopeRevealDirectionForBinding(binding) ==
            MotionTextRevealDirection.reverse
        ? 1
        : 0;
  }

  String _formatLayerScopeRevealBy(double value) {
    return value.round() <= 0 ? 'Word' : 'Letter';
  }

  String _formatLayerScopeRevealDirection(double value) {
    return value.round() <= 0 ? 'Forward' : 'Reverse';
  }

  bool _canOpenLayerScopeValueEditor(
    _LayerScopeContext? context,
  ) {
    if (context == null) {
      return false;
    }
    final lane = _layerScopeSelectedAnimationLane(context);
    if (lane == null || !_layerScopeLaneSupportsValueControls(lane)) {
      return false;
    }
    return (_selectedLayerScopeKeyframeIndex != null &&
            _selectedLayerScopeKeyframeIndex! >= 0 &&
            _selectedLayerScopeKeyframeIndex! <
                lane.normalizedKeyframeStops.length) ||
        _nearestLayerScopeKeyframeIndex(context, lane) != null;
  }

  bool _canOpenLayerScopeGraphEditor(
    _LayerScopeContext? context,
  ) {
    if (context == null) {
      return false;
    }
    final lane = _layerScopeSelectedAnimationLane(context);
    if (lane == null || !_layerScopeLaneSupportsValueControls(lane)) {
      return false;
    }
    final keyframeIndex = _selectedLayerScopeKeyframeIndex ??
        _nearestLayerScopeKeyframeIndex(context, lane);
    if (keyframeIndex == null) {
      return false;
    }
    return keyframeIndex > 0 ||
        keyframeIndex < lane.normalizedKeyframeStops.length - 1;
  }

  bool _canAddTransitionFocusKeyframe(
    _TransitionFocusContext? context,
  ) {
    return context != null &&
        _transitionFocusSelectedAnimationLane(context) != null;
  }

  bool _canOpenTransitionFocusValueEditor(
    _TransitionFocusContext? context,
  ) {
    if (context == null) {
      return false;
    }
    final lane = _transitionFocusSelectedAnimationLane(context);
    if (lane == null) {
      return false;
    }
    return (_selectedTransitionFocusKeyframeIndex != null &&
            _selectedTransitionFocusKeyframeIndex! >= 0 &&
            _selectedTransitionFocusKeyframeIndex! <
                lane.normalizedKeyframeStops.length) ||
        lane.normalizedKeyframeStops.isNotEmpty;
  }

  bool _canMoveTransitionFocusSelectedKeyframe(
    _TransitionFocusContext? context,
  ) {
    if (context == null) {
      return false;
    }
    final lane = _transitionFocusSelectedAnimationLane(context);
    final keyframeIndex = _selectedTransitionFocusKeyframeIndex;
    if (lane == null || keyframeIndex == null) {
      return false;
    }
    return keyframeIndex >= 0 &&
        keyframeIndex < lane.normalizedKeyframeStops.length;
  }

  TimelineTime _transitionFocusVisibleGlobalTime(
    _TransitionFocusContext context,
  ) {
    final localDuration = context.endTime - context.startTime;
    final localDisplayTime = _transitionFocusDisplayTimeNotifier.value.clamp(
      TimelineTime.zero,
      localDuration,
    );
    return (context.startTime + localDisplayTime).clamp(
      context.startTime,
      context.endTime,
    );
  }

  bool _canMoveLayerScopeSelectedKeyframe(
    _LayerScopeContext? context,
  ) {
    if (context == null) {
      return false;
    }
    final lane = _layerScopeSelectedAnimationLane(context);
    final keyframeIndex = _selectedLayerScopeKeyframeIndex;
    final definitions =
        lane == null ? null : _layerScopeDefinitionsForLane(lane);
    if (lane == null || definitions == null || keyframeIndex == null) {
      return false;
    }
    return keyframeIndex >= 0 &&
        keyframeIndex < lane.normalizedKeyframeStops.length;
  }

  double _layerScopeRotationAngleForDegrees(double degrees) {
    var angle = degrees;
    while (angle > 180.0) {
      angle -= 360.0;
    }
    while (angle < -180.0) {
      angle += 360.0;
    }
    return angle;
  }

  int _layerScopeRotationTurnsForDegrees(double degrees) {
    final angle = _layerScopeRotationAngleForDegrees(degrees);
    return ((degrees - angle) / 360.0).round();
  }

  bool _motionInterpolationMatchesEasyEase(MotionInterpolationSpec spec) {
    if (spec.kind != MotionInterpolationKind.cubicBezier ||
        spec.bezier == null) {
      return false;
    }
    final bezier = spec.bezier!;
    return (bezier.x1 - 0.3333).abs() <= 0.001 &&
        bezier.y1.abs() <= 0.001 &&
        (bezier.x2 - 0.6667).abs() <= 0.001 &&
        (bezier.y2 - 1.0).abs() <= 0.001;
  }

  bool _isLayerScopeEasyEaseActive({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required int keyframeIndex,
  }) {
    final definitions = _layerScopeDefinitionsForLane(lane);
    if (definitions == null) {
      return false;
    }
    final stops = lane.normalizedKeyframeStops;
    if (keyframeIndex < 0 || keyframeIndex >= stops.length) {
      return false;
    }
    final keyframeTime =
        _layerScopeTimeForProgress(context, stops[keyframeIndex]);
    for (final definition in definitions) {
      final channel = _propertyChannelForElementInChannels(
        _manualMotionPropertyChannels,
        context.clip.id,
        definition,
      );
      if (channel == null) {
        continue;
      }
      final channelKeyframeIndex = channel.keyframes.indexWhere(
        (keyframe) =>
            keyframe.time.inProjectTicks == keyframeTime.inProjectTicks,
      );
      if (channelKeyframeIndex < 0) {
        continue;
      }
      if (channelKeyframeIndex > 0 &&
          _motionInterpolationMatchesEasyEase(
            channel.keyframes[channelKeyframeIndex - 1].interpolationToNext,
          )) {
        return true;
      }
      if (channelKeyframeIndex < channel.keyframes.length - 1 &&
          _motionInterpolationMatchesEasyEase(
            channel.keyframes[channelKeyframeIndex].interpolationToNext,
          )) {
        return true;
      }
    }
    return false;
  }

  List<LayerScopeValueControlSpec>? _layerScopeValueControlsForSelection({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required int keyframeIndex,
  }) {
    if (!_layerScopeLaneSupportsValueControls(lane)) {
      return null;
    }
    final stops = lane.normalizedKeyframeStops;
    if (keyframeIndex < 0 || keyframeIndex >= stops.length) {
      return null;
    }
    final textContext = _motionTextElementContextForId(context.clip.id);
    if (textContext == null) {
      return null;
    }
    final keyframeTime = _layerScopeTimeForProgress(
      context,
      stops[keyframeIndex],
    );
    if (lane.matchesPropertyLabel('opacity')) {
      final opacity = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.opacity,
        time: keyframeTime,
      );
      return <LayerScopeValueControlSpec>[
        LayerScopeValueControlSpec(
          id: 'opacity',
          label: 'Opacity',
          value: (opacity * 100.0).clamp(0.0, 100.0).toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          formatValue: (value) => '${value.round()}%',
        ),
      ];
    }
    if (_layerScopeLaneMatchesBlur(lane)) {
      final blurAmount = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.blurAmount,
        time: keyframeTime,
      );
      final blurMix = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.blurMix,
        time: keyframeTime,
      );
      final blurEdgeMode = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.blurEdgeMode,
        time: keyframeTime,
      );
      final blurCrop = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.blurCrop,
        time: keyframeTime,
      );
      return <LayerScopeValueControlSpec>[
        LayerScopeValueControlSpec(
          id: 'blurAmount',
          label: 'Amount',
          value: blurAmount.clamp(0.0, 100.0).toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          formatValue: (value) => value.round().toString(),
        ),
        LayerScopeValueControlSpec(
          id: 'blurMix',
          label: 'Mix',
          value: blurMix.clamp(0.0, 100.0).toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          formatValue: (value) => '${value.round()}%',
        ),
        LayerScopeValueControlSpec(
          id: 'blurEdgeMode',
          label: 'Edges',
          value: blurEdgeMode.clamp(0.0, 1.0).roundToDouble(),
          min: 0,
          max: 1,
          divisions: 1,
          formatValue: _formatLayerScopeBlurEdgeMode,
          options: const <LayerScopeValueOption>[
            LayerScopeValueOption(label: 'Transparent', value: 0),
            LayerScopeValueOption(label: 'Repeat', value: 1),
          ],
        ),
        LayerScopeValueControlSpec(
          id: 'blurCrop',
          label: 'Bounds',
          value: blurCrop.clamp(0.0, 1.0).roundToDouble(),
          min: 0,
          max: 1,
          divisions: 1,
          formatValue: _formatLayerScopeBlurBoundsMode,
          options: const <LayerScopeValueOption>[
            LayerScopeValueOption(label: 'Extend', value: 0),
            LayerScopeValueOption(label: 'Crop', value: 1),
          ],
        ),
      ];
    }
    if (_layerScopeLaneMatchesReveal(lane)) {
      final revealProgress = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.revealProgress,
        time: keyframeTime,
      );
      final binding = _motionTextBindingForElementId(textContext.element.id);
      return <LayerScopeValueControlSpec>[
        LayerScopeValueControlSpec(
          id: 'revealProgress',
          label: 'Progress',
          value: (revealProgress * 100.0).clamp(0.0, 100.0).toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          formatValue: (value) => '${value.round()}%',
        ),
        LayerScopeValueControlSpec(
          id: 'revealBy',
          label: 'By',
          value: _layerScopeRevealByValueForBinding(binding),
          min: 0,
          max: 1,
          divisions: 1,
          formatValue: _formatLayerScopeRevealBy,
          options: const <LayerScopeValueOption>[
            LayerScopeValueOption(label: 'Word', value: 0),
            LayerScopeValueOption(label: 'Letter', value: 1),
          ],
        ),
        LayerScopeValueControlSpec(
          id: 'revealDirection',
          label: 'Direction',
          value: _layerScopeRevealDirectionValueForBinding(binding),
          min: 0,
          max: 1,
          divisions: 1,
          formatValue: _formatLayerScopeRevealDirection,
          options: const <LayerScopeValueOption>[
            LayerScopeValueOption(label: 'Forward', value: 0),
            LayerScopeValueOption(label: 'Reverse', value: 1),
          ],
        ),
      ];
    }
    if (lane.matchesPropertyLabel('position')) {
      final canvasSize = textContext.project.format.canvasSize;
      final positionX = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.positionX,
        time: keyframeTime,
      );
      final positionY = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.positionY,
        time: keyframeTime,
      );
      return <LayerScopeValueControlSpec>[
        LayerScopeValueControlSpec(
          id: 'positionX',
          label: 'X',
          value: positionX,
          min: -canvasSize.width,
          max: canvasSize.width,
          formatValue: (value) => value.round().toString(),
        ),
        LayerScopeValueControlSpec(
          id: 'positionY',
          label: 'Y',
          value: positionY,
          min: -canvasSize.height,
          max: canvasSize.height,
          formatValue: (value) => value.round().toString(),
        ),
      ];
    }
    if (lane.matchesPropertyLabel('scale')) {
      final scaleX = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.scaleX,
        time: keyframeTime,
      );
      final scaleY = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.scaleY,
        time: keyframeTime,
      );
      return <LayerScopeValueControlSpec>[
        LayerScopeValueControlSpec(
          id: 'scale',
          label: 'Scale',
          value:
              (((scaleX + scaleY) / 2.0) * 100.0).clamp(20.0, 800.0).toDouble(),
          min: 20,
          max: 800,
          divisions: 780,
          formatValue: (value) => '${value.round()}%',
        ),
      ];
    }
    if (lane.matchesPropertyLabel('rotation')) {
      final rotation = _evaluatedTextScalarPropertyOrDefault(
        textContext,
        MotionPropertyCatalog.rotationDegrees,
        time: keyframeTime,
      );
      final angle = _layerScopeRotationAngleForDegrees(rotation);
      final turns =
          _layerScopeRotationTurnsForDegrees(rotation).clamp(-4, 4).toDouble();
      return <LayerScopeValueControlSpec>[
        LayerScopeValueControlSpec(
          id: 'rotationAngle',
          label: 'Angle',
          value: angle,
          min: -180,
          max: 180,
          divisions: 360,
          formatValue: (value) => '${value.round()} deg',
        ),
        LayerScopeValueControlSpec(
          id: 'rotationTurns',
          label: 'Turns',
          value: turns,
          min: -4,
          max: 4,
          divisions: 8,
          formatValue: (value) => '${value.round()}x',
        ),
      ];
    }
    return null;
  }

  String _formatLayerScopeBlurEdgeMode(double value) {
    final mode = value.round();
    if (mode <= 0) {
      return 'Transparent';
    }
    return 'Repeat';
  }

  String _formatLayerScopeBlurBoundsMode(double value) {
    return value.round() == 1 ? 'Crop' : 'Extend';
  }

  TimelineAnimationLaneData? _opacityAnimationLaneForClipContext(
    _SelectedTimelineClipContext context,
  ) {
    for (final lane in context.track.animationLanes) {
      if (lane.targetClipId == context.clip.id &&
          lane.matchesPropertyLabel('opacity')) {
        return lane;
      }
    }
    return null;
  }

  double _clipAnimationProgressAtTime(
    _SelectedTimelineClipContext context,
    TimelineTime timelineTime,
  ) {
    final durationSeconds = context.clip.durationTime.inSecondsDouble;
    if (durationSeconds <= 0) {
      return 0.0;
    }
    final clampedTime = timelineTime.clamp(
      context.clipStartTime,
      context.clipEndTime,
    );
    return ((clampedTime - context.clipStartTime).inSecondsDouble /
            durationSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _clipOpacityForTimelineTime(
    _SelectedTimelineClipContext context,
    TimelineTime timelineTime,
  ) {
    final opacityLane = _opacityAnimationLaneForClipContext(context);
    if (opacityLane == null) {
      return 1.0;
    }
    final percent = opacityLane.evaluatePercentAtProgress(
      _clipAnimationProgressAtTime(context, timelineTime),
      fallbackPercent: 100.0,
    );
    return (percent / 100.0).clamp(0.0, 1.0).toDouble();
  }

  MotionPropertyChannelModel? _manualOpacityChannelForElement(
    String elementId,
  ) {
    for (final channel in _manualMotionPropertyChannels) {
      if (channel.target.targetId == elementId &&
          channel.definition.id == MotionPropertyCatalog.opacity.id &&
          (channel.baseValue != null || channel.keyframes.isNotEmpty)) {
        return channel;
      }
    }
    return null;
  }

  bool _hasManualOpacityChannelForElement(String elementId) {
    return _manualOpacityChannelForElement(elementId) != null;
  }

  MotionPropertyChannelModel? _manualPropertyChannelForElement(
    String elementId,
    MotionPropertyDefinition definition,
  ) {
    return _propertyChannelForElementInChannels(
      _manualMotionPropertyChannels,
      elementId,
      definition,
    );
  }

  MotionPropertyChannelModel? _propertyChannelForElementInChannels(
    List<MotionPropertyChannelModel> channels,
    String elementId,
    MotionPropertyDefinition definition,
  ) {
    for (final channel in channels) {
      if (channel.target.targetId == elementId &&
          channel.definition.id == definition.id &&
          (channel.baseValue != null || channel.keyframes.isNotEmpty)) {
        return channel;
      }
    }
    return null;
  }

  TimelineAnimationLaneData? _existingLayerScopeAnimationLane(
    _LayerScopeContext context,
    String propertyLabel,
  ) {
    for (final lane in context.track.animationLanes) {
      if (lane.targetClipId == context.clip.id &&
          lane.matchesPropertyLabel(propertyLabel)) {
        return lane;
      }
    }
    return null;
  }

  ({List<double> stops, List<String> keyframeIds})
      _layerScopeKeyframesForChannels(
    _LayerScopeContext context,
    Iterable<MotionPropertyChannelModel?> channels,
  ) {
    final durationSeconds = context.durationTime.inSecondsDouble;
    final progressByTick = <int, double>{};
    final keyframeIdsByTick = <int, List<String>>{};
    if (durationSeconds <= 0) {
      return (stops: const <double>[], keyframeIds: const <String>[]);
    }
    for (final channel in channels) {
      if (channel == null) {
        continue;
      }
      for (final keyframe in channel.keyframes) {
        if (keyframe.value.kind != MotionPropertyValueKind.scalar) {
          continue;
        }
        final progress = ((keyframe.time - context.startTime).inSecondsDouble /
                durationSeconds)
            .clamp(0.0, 1.0)
            .toDouble();
        progressByTick[keyframe.time.inProjectTicks] = progress;
        keyframeIdsByTick
            .putIfAbsent(keyframe.time.inProjectTicks, () => <String>[])
            .add(keyframe.id);
      }
    }
    final sortedTicks = progressByTick.keys.toList()..sort();
    return (
      stops: <double>[
        for (final tick in sortedTicks) progressByTick[tick]!,
      ],
      keyframeIds: <String>[
        for (final tick in sortedTicks)
          _layerScopeKeyframeGroupId(
              keyframeIdsByTick[tick] ?? const <String>[]),
      ],
    );
  }

  String _layerScopeKeyframeGroupId(List<String> keyframeIds) {
    final sorted = List<String>.from(keyframeIds)..sort();
    return sorted.join('\n');
  }

  Set<String> _layerScopeKeyframeGroupMembers(String keyframeGroupId) {
    if (keyframeGroupId.isEmpty) {
      return const <String>{};
    }
    return keyframeGroupId.split('\n').toSet();
  }

  String? _layerScopeKeyframeIdAt(
    TimelineAnimationLaneData lane,
    int keyframeIndex,
  ) {
    if (keyframeIndex < 0 || keyframeIndex >= lane.keyframeIds.length) {
      return null;
    }
    return lane.keyframeIds[keyframeIndex];
  }

  int? _layerScopeKeyframeIndexForId(
    TimelineAnimationLaneData lane,
    String? keyframeId,
  ) {
    if (keyframeId == null) {
      return null;
    }
    final index = lane.keyframeIds.indexOf(keyframeId);
    return index < 0 ? null : index;
  }

  TimelineAnimationLaneData? _projectedTextScalarLaneForScope({
    required _LayerScopeContext context,
    required String label,
    required String slug,
    required Iterable<MotionPropertyChannelModel?> channels,
  }) {
    if (context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final keyframes = _layerScopeKeyframesForChannels(context, channels);
    final stops = keyframes.stops;
    final existingLane = _existingLayerScopeAnimationLane(context, label);
    if (existingLane == null && stops.isEmpty) {
      return null;
    }
    final baseLane = existingLane ??
        TimelineAnimationLaneData(
          id: 'anim-${context.track.kind.name}-${context.clip.id}-$slug',
          label: label,
          targetClipId: context.clip.id,
          normalizedKeyframeStops: const <double>[],
          keyframeValues: const <double>[],
        );
    return baseLane.copyWith(
      label: label,
      targetClipId: context.clip.id,
      normalizedKeyframeStops: List<double>.unmodifiable(stops),
      keyframeIds: List<String>.unmodifiable(keyframes.keyframeIds),
      keyframeValues: List<double>.unmodifiable(
        List<double>.filled(stops.length, 0.0, growable: false),
      ),
    );
  }

  TimelineAnimationLaneData? _projectedTextOpacityLaneForScope(
    _LayerScopeContext context,
  ) {
    if (context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final target = _layerScopeMotionAuthoringTargetForText(context);
    if (target == null) {
      return null;
    }
    final existingLane = _existingLayerScopeAnimationLane(context, 'opacity');
    final projected = _buildLayerScopeMotionAuthoringAdapter().projectOpacity(
      channels: _manualMotionPropertyChannels,
      target: target,
    );
    final projectedLane =
        projected.lanes.isEmpty ? null : projected.lanes.first;
    if (existingLane == null &&
        (projectedLane == null ||
            projectedLane.normalizedKeyframeStops.isEmpty)) {
      return null;
    }
    final baseLane = projectedLane ??
        existingLane ??
        TimelineAnimationLaneData(
          id: 'anim-${context.track.kind.name}-${context.clip.id}-opacity',
          label: 'Opacity',
          targetClipId: context.clip.id,
          normalizedKeyframeStops: const <double>[],
          keyframeValues: const <double>[],
        );
    return baseLane.copyWith(
      label: 'Opacity',
      targetClipId: context.clip.id,
    );
  }

  TimelineAnimationLaneData? _projectedTextBlurLaneForScope(
    _LayerScopeContext context,
  ) {
    final channels = <MotionPropertyChannelModel?>[
      for (final definition in _layerScopeBlurDefinitions)
        _manualPropertyChannelForElement(context.clip.id, definition),
    ];
    final hasExplicitBlurLane = context.track.animationLanes.any(
      (lane) =>
          lane.targetClipId == context.clip.id &&
          _layerScopeLaneMatchesBlur(lane),
    );
    if (!hasExplicitBlurLane && _isNoOpLayerScopeBlurProjection(channels)) {
      return null;
    }
    return _projectedTextScalarLaneForScope(
      context: context,
      label: 'Gaussian Blur',
      slug: 'gaussian-blur',
      channels: channels,
    );
  }

  bool _isNoOpLayerScopeBlurProjection(
    Iterable<MotionPropertyChannelModel?> channels,
  ) {
    var hasAuthoredBlurChannel = false;
    for (final channel in channels) {
      if (channel == null) {
        continue;
      }
      hasAuthoredBlurChannel = true;
      final defaultValue = channel.definition.defaultValue;
      final baseValue = channel.baseValue;
      if (baseValue != null &&
          !_motionScalarValuesMatch(baseValue, defaultValue)) {
        return false;
      }
      for (final keyframe in channel.keyframes) {
        if (!_motionScalarValuesMatch(keyframe.value, defaultValue)) {
          return false;
        }
      }
    }
    return hasAuthoredBlurChannel;
  }

  bool _motionScalarValuesMatch(
    MotionPropertyValue left,
    MotionPropertyValue right,
  ) {
    if (left.kind != MotionPropertyValueKind.scalar ||
        right.kind != MotionPropertyValueKind.scalar) {
      return left == right;
    }
    final leftValue = left.rawValue as double;
    final rightValue = right.rawValue as double;
    return (leftValue - rightValue).abs() <= 0.0001;
  }

  TimelineAnimationLaneData? _projectedTextPositionLaneForScope(
    _LayerScopeContext context,
  ) {
    final positionX = _manualPropertyChannelForElement(
      context.clip.id,
      MotionPropertyCatalog.positionX,
    );
    final positionY = _manualPropertyChannelForElement(
      context.clip.id,
      MotionPropertyCatalog.positionY,
    );
    return _projectedTextScalarLaneForScope(
      context: context,
      label: 'Position',
      slug: 'position',
      channels: <MotionPropertyChannelModel?>[
        positionX,
        positionY,
      ],
    );
  }

  TimelineAnimationLaneData? _projectedTextScaleLaneForScope(
    _LayerScopeContext context,
  ) {
    final scaleX = _manualPropertyChannelForElement(
      context.clip.id,
      MotionPropertyCatalog.scaleX,
    );
    final scaleY = _manualPropertyChannelForElement(
      context.clip.id,
      MotionPropertyCatalog.scaleY,
    );
    return _projectedTextScalarLaneForScope(
      context: context,
      label: 'Scale',
      slug: 'scale',
      channels: <MotionPropertyChannelModel?>[
        scaleX,
        scaleY,
      ],
    );
  }

  TimelineAnimationLaneData? _projectedTextRotationLaneForScope(
    _LayerScopeContext context,
  ) {
    final rotation = _manualPropertyChannelForElement(
      context.clip.id,
      MotionPropertyCatalog.rotationDegrees,
    );
    return _projectedTextScalarLaneForScope(
      context: context,
      label: 'Rotation',
      slug: 'rotation',
      channels: <MotionPropertyChannelModel?>[rotation],
    );
  }

  TimelineAnimationLaneData? _projectedTextRevealLaneForScope(
    _LayerScopeContext context,
  ) {
    if (context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final channel = _manualPropertyChannelForElement(
      context.clip.id,
      MotionPropertyCatalog.revealProgress,
    );
    TimelineAnimationLaneData? existingLane;
    for (final lane in context.track.animationLanes) {
      if (lane.targetClipId == context.clip.id &&
          _layerScopeLaneMatchesReveal(lane)) {
        existingLane = lane;
        break;
      }
    }
    final durationSeconds = context.durationTime.inSecondsDouble;
    final stops = <double>[];
    final keyframeIds = <String>[];
    final values = <double>[];
    if (durationSeconds > 0 && channel != null) {
      for (final keyframe in channel.keyframes) {
        if (keyframe.value.kind != MotionPropertyValueKind.scalar) {
          continue;
        }
        final progress = ((keyframe.time - context.startTime).inSecondsDouble /
                durationSeconds)
            .clamp(0.0, 1.0)
            .toDouble();
        stops.add(progress);
        keyframeIds.add(keyframe.id);
        values.add(
          ((keyframe.value.rawValue as double) * 100.0)
              .clamp(0.0, 100.0)
              .toDouble(),
        );
      }
    }
    if (existingLane == null && stops.isEmpty) {
      return null;
    }
    final binding = _motionTextBindingForElementId(context.clip.id);
    final revealUnit = _layerScopeRevealUnitForBinding(binding);
    final label = existingLane?.label ??
        (revealUnit == MotionTextRevealUnit.word ? 'Word Reveal' : 'Type On');
    final baseLane = existingLane ??
        TimelineAnimationLaneData(
          id: 'anim-${context.track.kind.name}-${context.clip.id}-reveal-progress',
          label: label,
          targetClipId: context.clip.id,
          normalizedKeyframeStops: const <double>[],
          keyframeValues: const <double>[],
        );
    return baseLane.copyWith(
      label: label,
      targetClipId: context.clip.id,
      normalizedKeyframeStops: List<double>.unmodifiable(stops),
      keyframeIds: List<String>.unmodifiable(keyframeIds),
      keyframeValues: List<double>.unmodifiable(values),
    );
  }

  List<MotionPropertyDefinition> get _layerScopeBlurDefinitions =>
      <MotionPropertyDefinition>[
        MotionPropertyCatalog.blurAmount,
        MotionPropertyCatalog.blurMix,
        MotionPropertyCatalog.blurEdgeMode,
        MotionPropertyCatalog.blurCrop,
      ];

  Set<String> get _layerScopeBlurControlIds => const <String>{
        'blurAmount',
        'blurMix',
        'blurEdgeMode',
        'blurCrop',
      };

  LayerScopeMotionAuthoringTarget? _layerScopeMotionAuthoringTargetForText(
    _LayerScopeContext context,
  ) {
    if (context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final textContext = _motionTextElementContextForId(context.clip.id);
    if (textContext == null) {
      return null;
    }
    final activeRange = _motionTextTimingRangeForElement(
      scene: textContext.scene,
      element: textContext.element,
    );
    return LayerScopeMotionAuthoringTarget(
      elementId: textContext.element.id,
      targetClipId: context.clip.id,
      motionTarget: textContext.elementTarget,
      activeRange: activeRange,
      projectionWindow: activeRange,
    );
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeOpacityKeyframeToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
    required double percent,
  }) {
    if (!lane.matchesPropertyLabel('opacity') ||
        context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final target = _layerScopeMotionAuthoringTargetForText(context);
    final keyframeTime = _layerScopeTimeForProgress(context, progress);
    if (target == null) {
      return null;
    }
    final result = _buildLayerScopeMotionAuthoringAdapter().addOpacityKeyframe(
      channels: _manualMotionPropertyChannels,
      target: target,
      time: keyframeTime,
      percent: percent,
    );
    if (result.hasIssues) {
      return null;
    }
    return result.channels;
  }

  List<MotionPropertyChannelModel>? _syncLayerScopePositionKeyframeToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
  }) {
    if (!lane.matchesPropertyLabel('position') ||
        context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final textContext = _motionTextElementContextForId(context.clip.id);
    if (textContext == null) {
      return null;
    }
    final keyframeTime = _layerScopeTimeForProgress(context, progress);
    final activeRange = _motionTextTimingRangeForElement(
      scene: textContext.scene,
      element: textContext.element,
    );
    final x = _evaluatedTextScalarPropertyOrDefault(
      textContext,
      MotionPropertyCatalog.positionX,
      time: keyframeTime,
    );
    final y = _evaluatedTextScalarPropertyOrDefault(
      textContext,
      MotionPropertyCatalog.positionY,
      time: keyframeTime,
    );
    final service = _buildCanvasTimelineAuthoringService();
    final xResult = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: _manualMotionPropertyChannels,
        target: textContext.elementTarget,
        activeRange: activeRange,
        definition: MotionPropertyCatalog.positionX,
        time: keyframeTime,
        value: MotionPropertyValue.scalar(x),
      ),
    );
    if (xResult.hasIssues) {
      return null;
    }
    final yResult = service.addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: xResult.channels,
        target: textContext.elementTarget,
        activeRange: activeRange,
        definition: MotionPropertyCatalog.positionY,
        time: keyframeTime,
        value: MotionPropertyValue.scalar(y),
      ),
    );
    if (yResult.hasIssues) {
      return null;
    }
    return yResult.channels;
  }

  List<MotionPropertyChannelModel>? _syncLayerScopePositionValueToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
    required double x,
    required double y,
  }) {
    return _syncLayerScopeTransformKeyframesToGraph(
      context: context,
      lane: lane,
      progress: progress,
      propertyLabel: 'position',
      definitions: <MotionPropertyDefinition>[
        MotionPropertyCatalog.positionX,
        MotionPropertyCatalog.positionY,
      ],
      scalarOverrides: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.positionX: x,
        MotionPropertyCatalog.positionY: y,
      },
    );
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeTransformKeyframesToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
    required String propertyLabel,
    required Iterable<MotionPropertyDefinition> definitions,
    Map<MotionPropertyDefinition, double> scalarOverrides =
        const <MotionPropertyDefinition, double>{},
  }) {
    if (!lane.matchesPropertyLabel(propertyLabel) ||
        context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final textContext = _motionTextElementContextForId(context.clip.id);
    if (textContext == null) {
      return null;
    }
    final keyframeTime = _layerScopeTimeForProgress(context, progress);
    final activeRange = _motionTextTimingRangeForElement(
      scene: textContext.scene,
      element: textContext.element,
    );
    final service = _buildCanvasTimelineAuthoringService();
    var nextChannels = _manualMotionPropertyChannels;
    for (final definition in definitions) {
      final result = service.addKeyframe(
        CanvasTimelineKeyframeRequest(
          channels: nextChannels,
          target: textContext.elementTarget,
          activeRange: activeRange,
          definition: definition,
          time: keyframeTime,
          value: MotionPropertyValue.scalar(
            scalarOverrides[definition] ??
                _evaluatedTextScalarPropertyOrDefault(
                  textContext,
                  definition,
                  time: keyframeTime,
                ),
          ),
        ),
      );
      if (result.hasIssues) {
        return null;
      }
      nextChannels = result.channels;
    }
    return nextChannels;
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeScaleKeyframeToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
  }) {
    return _syncLayerScopeTransformKeyframesToGraph(
      context: context,
      lane: lane,
      progress: progress,
      propertyLabel: 'scale',
      definitions: <MotionPropertyDefinition>[
        MotionPropertyCatalog.scaleX,
        MotionPropertyCatalog.scaleY,
      ],
    );
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeScaleValueToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
    required double percent,
  }) {
    final scale = (percent / 100.0).clamp(0.2, 8.0).toDouble();
    return _syncLayerScopeTransformKeyframesToGraph(
      context: context,
      lane: lane,
      progress: progress,
      propertyLabel: 'scale',
      definitions: <MotionPropertyDefinition>[
        MotionPropertyCatalog.scaleX,
        MotionPropertyCatalog.scaleY,
      ],
      scalarOverrides: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.scaleX: scale,
        MotionPropertyCatalog.scaleY: scale,
      },
    );
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeRotationKeyframeToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
  }) {
    return _syncLayerScopeTransformKeyframesToGraph(
      context: context,
      lane: lane,
      progress: progress,
      propertyLabel: 'rotation',
      definitions: <MotionPropertyDefinition>[
        MotionPropertyCatalog.rotationDegrees,
      ],
    );
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeRotationValueToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
    required double degrees,
  }) {
    return _syncLayerScopeTransformKeyframesToGraph(
      context: context,
      lane: lane,
      progress: progress,
      propertyLabel: 'rotation',
      definitions: <MotionPropertyDefinition>[
        MotionPropertyCatalog.rotationDegrees,
      ],
      scalarOverrides: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.rotationDegrees: degrees.toDouble(),
      },
    );
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeBlurKeyframeToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
  }) {
    if (!_layerScopeLaneMatchesBlur(lane)) {
      return null;
    }
    return _syncLayerScopeTransformKeyframesToGraph(
      context: context,
      lane: lane,
      progress: progress,
      propertyLabel: lane.label,
      definitions: _layerScopeBlurDefinitions,
    );
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeBlurValueToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
    required Map<String, double> values,
  }) {
    if (!_layerScopeLaneMatchesBlur(lane)) {
      return null;
    }
    final amount = (values['blurAmount'] ?? 0).clamp(0.0, 100.0).toDouble();
    final mix = (values['blurMix'] ?? 100).clamp(0.0, 100.0).toDouble();
    final edgeMode =
        (values['blurEdgeMode'] ?? 0).clamp(0.0, 1.0).roundToDouble();
    final crop = (values['blurCrop'] ?? 0).clamp(0.0, 1.0).roundToDouble();
    return _syncLayerScopeTransformKeyframesToGraph(
      context: context,
      lane: lane,
      progress: progress,
      propertyLabel: lane.label,
      definitions: _layerScopeBlurDefinitions,
      scalarOverrides: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.blurAmount: amount,
        MotionPropertyCatalog.blurMix: mix,
        MotionPropertyCatalog.blurEdgeMode: edgeMode,
        MotionPropertyCatalog.blurCrop: crop,
      },
    );
  }

  List<MotionPropertyChannelModel>? _syncLayerScopeRevealKeyframeToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required double progress,
    required double percent,
  }) {
    if (!_layerScopeLaneMatchesReveal(lane) ||
        context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final textContext = _motionTextElementContextForId(context.clip.id);
    if (textContext == null) {
      return null;
    }
    final keyframeTime = _layerScopeTimeForProgress(context, progress);
    final result = _buildCanvasTimelineAuthoringService().addKeyframe(
      CanvasTimelineKeyframeRequest(
        channels: _manualMotionPropertyChannels,
        target: textContext.elementTarget,
        activeRange: _motionTextTimingRangeForElement(
          scene: textContext.scene,
          element: textContext.element,
        ),
        definition: MotionPropertyCatalog.revealProgress,
        time: keyframeTime,
        value: MotionPropertyValue.scalar(
          (percent / 100.0).clamp(0.0, 1.0).toDouble(),
        ),
      ),
    );
    if (result.hasIssues) {
      return null;
    }
    return result.channels;
  }

  MotionTextRevealUnit _defaultRevealUnitForScopedTextEffectItem(
    AnimateBrowserItem item,
  ) {
    return switch (item.id) {
      'text_effect.word_reveal' ||
      'text_effect.word_rise_in' ||
      'text_effect.word_cascade' =>
        MotionTextRevealUnit.word,
      _ => MotionTextRevealUnit.letter,
    };
  }

  MotionPropertyValue _defaultRevealByParameterForScopedTextEffectItem(
    AnimateBrowserItem item,
  ) {
    final revealUnit = _defaultRevealUnitForScopedTextEffectItem(item);
    return MotionPropertyValue.enumValue(revealUnit.name);
  }

  MotionPropertyValue _defaultRevealDirectionParameterForScopedTextEffectItem(
    AnimateBrowserItem item,
  ) {
    return MotionPropertyValue.enumValue(
        MotionTextRevealDirection.forward.name);
  }

  bool _isMotionTextRevealBlock(MotionTextAnimationBlock block) =>
      block.revealSpec != null ||
      block.kind == MotionTextAnimationKind.typewriter ||
      block.kind == MotionTextAnimationKind.wordReveal ||
      block.kind == MotionTextAnimationKind.letterReveal ||
      block.kind == MotionTextAnimationKind.wordRiseIn ||
      block.kind == MotionTextAnimationKind.letterPopIn ||
      block.kind == MotionTextAnimationKind.wordCascade ||
      block.kind == MotionTextAnimationKind.letterBounce;

  bool _isScopedTextRevealEffectItem(AnimateBrowserItem item) =>
      item.id == 'text_effect.type_on' ||
      item.id == 'text_effect.word_reveal' ||
      item.id == 'text_effect.letter_reveal' ||
      item.id == 'text_effect.word_rise_in' ||
      item.id == 'text_effect.letter_pop_in' ||
      item.id == 'text_effect.word_cascade' ||
      item.id == 'text_effect.letter_bounce';

  List<MotionTextAnimationBindingModel>? _updateLayerScopeRevealBinding({
    required _LayerScopeContext context,
    MotionTextRevealUnit? revealUnit,
    MotionTextRevealDirection? revealDirection,
  }) {
    if (context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final binding = _motionTextBindingForElementId(context.clip.id);
    if (binding == null) {
      return null;
    }
    final nextRevealUnit =
        revealUnit ?? _layerScopeRevealUnitForBinding(binding);
    final nextRevealDirection =
        revealDirection ?? _layerScopeRevealDirectionForBinding(binding);
    final nextBindings = <MotionTextAnimationBindingModel>[
      for (final current in _motionTextAnimationBindings)
        if (current.id == binding.id)
          MotionTextAnimationBindingModel(
            id: current.id,
            elementTarget: current.elementTarget,
            activeRange: current.activeRange,
            presetId: current.presetId,
            animationBlocks: <MotionTextAnimationBlock>[
              for (final block in current.animationBlocks)
                if (_isMotionTextRevealBlock(block))
                  MotionTextAnimationBlock(
                    id: block.id,
                    kind: block.kind,
                    relativeRange: block.relativeRange,
                    interpolation: block.interpolation,
                    revealSpec: MotionTextRevealSpec(
                      unit: nextRevealUnit,
                      stagger: block.revealSpec?.stagger ?? TimelineTime.zero,
                    ),
                    parameters: <String, MotionPropertyValue>{
                      ...block.parameters,
                      'revealDirection': MotionPropertyValue.enumValue(
                        nextRevealDirection.name,
                      ),
                    },
                  )
                else
                  block,
            ],
            parameterValues: <String, MotionPropertyValue>{
              ...current.parameterValues,
              'revealBy': MotionPropertyValue.enumValue(nextRevealUnit.name),
              'revealDirection': MotionPropertyValue.enumValue(
                nextRevealDirection.name,
              ),
            },
          )
        else
          current,
    ];
    return List<MotionTextAnimationBindingModel>.unmodifiable(nextBindings);
  }

  List<MotionPropertyDefinition>? _layerScopeDefinitionsForLane(
    TimelineAnimationLaneData lane,
  ) {
    if (lane.matchesPropertyLabel('opacity')) {
      return <MotionPropertyDefinition>[
        MotionPropertyCatalog.opacity,
      ];
    }
    if (_layerScopeLaneMatchesBlur(lane)) {
      return _layerScopeBlurDefinitions;
    }
    if (_layerScopeLaneMatchesReveal(lane)) {
      return <MotionPropertyDefinition>[
        MotionPropertyCatalog.revealProgress,
      ];
    }
    if (lane.matchesPropertyLabel('position')) {
      return <MotionPropertyDefinition>[
        MotionPropertyCatalog.positionX,
        MotionPropertyCatalog.positionY,
      ];
    }
    if (lane.matchesPropertyLabel('scale')) {
      return <MotionPropertyDefinition>[
        MotionPropertyCatalog.scaleX,
        MotionPropertyCatalog.scaleY,
      ];
    }
    if (lane.matchesPropertyLabel('rotation')) {
      return <MotionPropertyDefinition>[
        MotionPropertyCatalog.rotationDegrees,
      ];
    }
    return null;
  }

  List<MotionPropertyChannelModel>? _moveLayerScopeKeyframesToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required int keyframeIndex,
    required String? keyframeId,
    required double progress,
    required Iterable<MotionPropertyDefinition> definitions,
  }) {
    if (context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final stops = lane.normalizedKeyframeStops;
    if (keyframeIndex < 0 || keyframeIndex >= stops.length) {
      return null;
    }
    final textContext = _motionTextElementContextForId(context.clip.id);
    if (textContext == null) {
      return null;
    }
    final sourceTime =
        _layerScopeTimeForProgress(context, stops[keyframeIndex]);
    final targetTime = _layerScopeTimeForProgress(context, progress);
    final keyframeGroupMembers = _layerScopeKeyframeGroupMembers(
      keyframeId ?? _layerScopeKeyframeIdAt(lane, keyframeIndex) ?? '',
    );
    final activeRange = _motionTextTimingRangeForElement(
      scene: textContext.scene,
      element: textContext.element,
    );
    final service = _buildCanvasTimelineAuthoringService();
    var nextChannels = _manualMotionPropertyChannels;
    var movedAny = false;
    for (final definition in definitions) {
      final channel = _propertyChannelForElementInChannels(
        nextChannels,
        context.clip.id,
        definition,
      );
      if (channel == null) {
        continue;
      }
      MotionKeyframeModel? keyframe;
      final hasKeyframeIdMatch = keyframeGroupMembers.isNotEmpty &&
          channel.keyframes.any(
            (candidate) => keyframeGroupMembers.contains(candidate.id),
          );
      for (final candidate in channel.keyframes) {
        if (keyframeGroupMembers.contains(candidate.id) ||
            (!hasKeyframeIdMatch &&
                candidate.time.inProjectTicks == sourceTime.inProjectTicks)) {
          keyframe = candidate;
          break;
        }
      }
      if (keyframe == null) {
        continue;
      }
      final result = service.moveKeyframe(
        CanvasTimelineMoveKeyframeRequest(
          channels: nextChannels,
          channelId: channel.id,
          keyframeId: keyframe.id,
          activeRange: activeRange,
          time: targetTime,
        ),
      );
      if (result.hasIssues) {
        return null;
      }
      nextChannels = result.channels;
      movedAny = true;
    }
    return movedAny ? nextChannels : null;
  }

  List<MotionPropertyChannelModel>? _setLayerScopeKeyframeInterpolationToGraph({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required int keyframeIndex,
    required MotionInterpolationSpec interpolation,
  }) {
    if (context.track.kind != TimelineTrackKind.text) {
      return null;
    }
    final definitions = _layerScopeDefinitionsForLane(lane);
    final stops = lane.normalizedKeyframeStops;
    if (definitions == null ||
        keyframeIndex < 0 ||
        keyframeIndex >= stops.length) {
      return null;
    }
    final keyframeTime =
        _layerScopeTimeForProgress(context, stops[keyframeIndex]);
    final service = _buildCanvasTimelineAuthoringService();
    var nextChannels = _manualMotionPropertyChannels;
    var changedAny = false;
    for (final definition in definitions) {
      var channel = _propertyChannelForElementInChannels(
        nextChannels,
        context.clip.id,
        definition,
      );
      if (channel == null) {
        continue;
      }
      final channelKeyframeIndex = channel.keyframes.indexWhere(
        (keyframe) =>
            keyframe.time.inProjectTicks == keyframeTime.inProjectTicks,
      );
      if (channelKeyframeIndex < 0) {
        continue;
      }
      if (channelKeyframeIndex > 0) {
        final previousKeyframe = channel.keyframes[channelKeyframeIndex - 1];
        final result = service.setKeyframeInterpolation(
          CanvasTimelineKeyframeInterpolationRequest(
            channels: nextChannels,
            channelId: channel.id,
            keyframeId: previousKeyframe.id,
            interpolation: interpolation,
          ),
        );
        if (result.hasIssues) {
          return null;
        }
        nextChannels = result.channels;
        changedAny = true;
        channel = _propertyChannelForElementInChannels(
          nextChannels,
          context.clip.id,
          definition,
        );
        if (channel == null) {
          continue;
        }
      }
      if (channelKeyframeIndex < channel.keyframes.length - 1) {
        final currentKeyframe = channel.keyframes[channelKeyframeIndex];
        final result = service.setKeyframeInterpolation(
          CanvasTimelineKeyframeInterpolationRequest(
            channels: nextChannels,
            channelId: channel.id,
            keyframeId: currentKeyframe.id,
            interpolation: interpolation,
          ),
        );
        if (result.hasIssues) {
          return null;
        }
        nextChannels = result.channels;
        changedAny = true;
      }
    }
    return changedAny ? nextChannels : null;
  }

  _SelectedTimelineClipContext? _activePreviewVisualClipContextForTime(
    TimelineTime timelineTime,
  ) {
    final tracks = _timelineTruthTracks;
    for (final kind in <TimelineTrackKind>[
      TimelineTrackKind.video,
      TimelineTrackKind.image,
    ]) {
      for (var trackIndex = 0; trackIndex < tracks.length; trackIndex++) {
        final track = tracks[trackIndex];
        if (track.kind != kind) {
          continue;
        }
        var cursor = TimelineTime.zero;
        _SelectedTimelineClipContext? lastVisualContext;
        for (var clipIndex = 0; clipIndex < track.clips.length; clipIndex++) {
          final clip = track.clips[clipIndex];
          final clipStartTime = cursor;
          final clipEndTime = clipStartTime + clip.durationTime;
          final asset = _assetForId(clip.assetId);
          if (clip.type == TimelineClipType.media && asset?.isVisual == true) {
            final context = _SelectedTimelineClipContext(
              trackIndex: trackIndex,
              clipIndex: clipIndex,
              track: track,
              clip: clip,
              asset: asset,
              clipStartTime: clipStartTime,
              clipEndTime: clipEndTime,
            );
            if (timelineTime < clipEndTime) {
              return context;
            }
            lastVisualContext = context;
          }
          cursor = clipEndTime;
        }
        if (lastVisualContext != null) {
          return lastVisualContext;
        }
      }
    }
    return null;
  }

  double _activePreviewVisualOpacityForTime(TimelineTime timelineTime) {
    final context = _activePreviewVisualClipContextForTime(timelineTime);
    if (context == null) {
      return 1.0;
    }
    return _clipOpacityForTimelineTime(context, timelineTime);
  }

  void _handleLayerScopeAnimationLaneTap(String laneId) {
    final context = _activeLayerScopeContext;
    if (context == null) {
      return;
    }
    TimelineAnimationLaneData? lane;
    for (final candidate in _layerScopeAnimationLanes(context)) {
      if (candidate.id == laneId) {
        lane = candidate;
        break;
      }
    }
    if (lane == null) {
      return;
    }
    final resolvedLane = lane;
    final keyframeIndex =
        _nearestLayerScopeKeyframeIndex(context, resolvedLane);
    setState(() {
      _selectedLayerScopeAnimationLaneId = laneId;
      _selectedLayerScopeKeyframeIndex = keyframeIndex;
      _selectedLayerScopeKeyframeId = keyframeIndex == null
          ? null
          : _layerScopeKeyframeIdAt(resolvedLane, keyframeIndex);
      _isLayerScopeValueEditorOpen = false;
    });
  }

  void _handleLayerScopeAnimationKeyframeTap(
    String laneId,
    int keyframeIndex,
    String keyframeId,
  ) {
    setState(() {
      _selectedLayerScopeAnimationLaneId = laneId;
      _selectedLayerScopeKeyframeIndex = keyframeIndex;
      _selectedLayerScopeKeyframeId = keyframeId;
      _isLayerScopeValueEditorOpen = false;
    });
  }

  void _handleLayerScopeAnimationKeyframeDrag(
    String laneId,
    int keyframeIndex,
    String keyframeId,
    double progress,
  ) {
    final context = _activeLayerScopeContext;
    if (context == null) {
      return;
    }
    TimelineAnimationLaneData? lane;
    for (final candidate in _layerScopeAnimationLanes(context)) {
      if (candidate.id == laneId) {
        lane = candidate;
        break;
      }
    }
    if (lane == null) {
      return;
    }
    _moveLayerScopeKeyframeToProgress(
      context: context,
      lane: lane,
      keyframeIndex: keyframeIndex,
      keyframeId: keyframeId,
      progress: progress,
    );
  }

  void _handleLayerScopeMoveSelectedKeyframeToPlayhead() {
    final context = _activeLayerScopeContext;
    if (context == null) {
      return;
    }
    final lane = _layerScopeSelectedAnimationLane(context);
    final keyframeIndex = _selectedLayerScopeKeyframeIndex;
    if (lane == null || keyframeIndex == null) {
      return;
    }
    final durationSeconds = context.durationTime.inSecondsDouble;
    final progress = durationSeconds <= 0
        ? 0.0
        : (_layerScopeLocalTime(context, _currentTime).inSecondsDouble /
                durationSeconds)
            .clamp(0.0, 1.0);
    final selectedKeyframeId = _selectedLayerScopeKeyframeId;
    final effectiveKeyframeId =
        _layerScopeKeyframeIndexForId(lane, selectedKeyframeId) == null
            ? _layerScopeKeyframeIdAt(lane, keyframeIndex)
            : selectedKeyframeId;
    _moveLayerScopeKeyframeToProgress(
      context: context,
      lane: lane,
      keyframeIndex: keyframeIndex,
      keyframeId: effectiveKeyframeId,
      progress: progress,
    );
  }

  void _moveLayerScopeKeyframeToProgress({
    required _LayerScopeContext context,
    required TimelineAnimationLaneData lane,
    required int keyframeIndex,
    required String? keyframeId,
    required double progress,
  }) {
    final definitions = _layerScopeDefinitionsForLane(lane);
    final stops = lane.normalizedKeyframeStops;
    if (definitions == null ||
        keyframeIndex < 0 ||
        keyframeIndex >= stops.length) {
      return;
    }
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final syncedChannels = _moveLayerScopeKeyframesToGraph(
      context: context,
      lane: lane,
      keyframeIndex: keyframeIndex,
      keyframeId: keyframeId,
      progress: clampedProgress,
      definitions: definitions,
    );
    if (syncedChannels == null) {
      return;
    }
    final values = _alignedAnimationKeyframeValues(lane);
    final selectedKeyframeId =
        keyframeId ?? _layerScopeKeyframeIdAt(lane, keyframeIndex);
    final movedEntries = <({
      double stop,
      String keyframeId,
      double value,
      bool isMoved,
    })>[
      for (var index = 0; index < stops.length; index++)
        _layerScopeMovedKeyframeEntry(
          lane: lane,
          stops: stops,
          values: values,
          index: index,
          fallbackMovedIndex: keyframeIndex,
          selectedKeyframeId: selectedKeyframeId,
          clampedProgress: clampedProgress,
        ),
    ]..sort((left, right) => left.stop.compareTo(right.stop));
    final movedIndex = movedEntries.indexWhere((entry) => entry.isMoved);
    final nextSelectedIndex = movedIndex < 0 ? keyframeIndex : movedIndex;
    _updateTimelineAnimationLane(
      lane.id,
      (currentLane) => currentLane.copyWith(
        normalizedKeyframeStops: List<double>.unmodifiable(
          <double>[
            for (final entry in movedEntries) entry.stop,
          ],
        ),
        keyframeIds: List<String>.unmodifiable(
          <String>[
            for (final entry in movedEntries) entry.keyframeId,
          ],
        ),
        keyframeValues: List<double>.unmodifiable(
          <double>[
            for (final entry in movedEntries) entry.value,
          ],
        ),
      ),
    );
    setState(() {
      _manualMotionPropertyChannels = syncedChannels;
      _markMotionAuthoringChanged();
      _selectedLayerScopeAnimationLaneId = lane.id;
      _selectedLayerScopeKeyframeIndex = nextSelectedIndex;
      _selectedLayerScopeKeyframeId = selectedKeyframeId;
      _isLayerScopeValueEditorOpen = false;
    });
  }

  ({
    double stop,
    String keyframeId,
    double value,
    bool isMoved,
  }) _layerScopeMovedKeyframeEntry({
    required TimelineAnimationLaneData lane,
    required List<double> stops,
    required List<double> values,
    required int index,
    required int fallbackMovedIndex,
    required String? selectedKeyframeId,
    required double clampedProgress,
  }) {
    final entryKeyframeId =
        _layerScopeKeyframeIdAt(lane, index) ?? '${lane.id}#$index';
    final isMoved = selectedKeyframeId != null
        ? entryKeyframeId == selectedKeyframeId
        : index == fallbackMovedIndex;
    return (
      stop: isMoved ? clampedProgress : stops[index],
      keyframeId: entryKeyframeId,
      value: values[index],
      isMoved: isMoved,
    );
  }

  void _updateTimelineAnimationLane(
    String laneId,
    TimelineAnimationLaneData Function(TimelineAnimationLaneData lane) update,
  ) {
    final nextTracks = List<TimelineTrackData>.from(_tracks);
    for (var trackIndex = 0; trackIndex < nextTracks.length; trackIndex++) {
      final track = nextTracks[trackIndex];
      final laneIndex = track.animationLanes.indexWhere(
        (lane) => lane.id == laneId,
      );
      if (laneIndex < 0) {
        continue;
      }
      final nextLanes = List<TimelineAnimationLaneData>.from(
        track.animationLanes,
      );
      nextLanes[laneIndex] = update(nextLanes[laneIndex]);
      setState(() {
        nextTracks[trackIndex] = track.copyWith(
          animationLanes: List<TimelineAnimationLaneData>.unmodifiable(
            nextLanes,
          ),
        );
        _tracks = List<TimelineTrackData>.unmodifiable(nextTracks);
      });
      return;
    }
  }

  void _handleLayerScopeAddKeyframe() {
    final context = _activeLayerScopeContext;
    if (context == null) {
      return;
    }
    final lane = _layerScopeSelectedAnimationLane(context);
    if (lane == null) {
      _showStageMessage('Select an animation or FX row before adding a key.');
      return;
    }
    final durationSeconds = context.durationTime.inSecondsDouble;
    final progress = durationSeconds <= 0
        ? 0.0
        : (_layerScopeLocalTime(context, _currentTime).inSecondsDouble /
                durationSeconds)
            .clamp(0.0, 1.0);
    final stops = lane.normalizedKeyframeStops
        .map((stop) => stop.clamp(0.0, 1.0))
        .toList();
    final keyframeIds = List<String>.from(lane.keyframeIds);
    while (keyframeIds.length < stops.length) {
      keyframeIds.add('${lane.id}#${keyframeIds.length}');
    }
    final values = _alignedAnimationKeyframeValues(lane).toList();
    const snapEpsilon = 0.006;
    for (var index = 0; index < stops.length; index++) {
      if ((stops[index] - progress).abs() <= snapEpsilon) {
        setState(() {
          _selectedLayerScopeAnimationLaneId = lane.id;
          _selectedLayerScopeKeyframeIndex = index;
          _selectedLayerScopeKeyframeId = _layerScopeKeyframeIdAt(lane, index);
          _isLayerScopeValueEditorOpen = false;
        });
        return;
      }
    }
    final selectedIndex = _selectedLayerScopeKeyframeIndex;
    final insertedValue = selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < values.length
        ? values[selectedIndex]
        : lane.evaluatePercentAtProgress(
            progress,
            fallbackPercent: lane.matchesPropertyLabel('opacity') ? 100.0 : 0.0,
          );
    var insertIndex = 0;
    while (insertIndex < stops.length && stops[insertIndex] < progress) {
      insertIndex += 1;
    }
    stops.insert(insertIndex, progress);
    final insertedKeyframeId =
        '${lane.id}@${TimelineTime.fromSecondsDouble(_layerScopeProgressToSeconds(context, progress)).inProjectTicks}';
    keyframeIds.insert(insertIndex, insertedKeyframeId);
    values.insert(insertIndex, insertedValue);
    final laneId = lane.id;
    final syncedChannels = _syncLayerScopeOpacityKeyframeToGraph(
          context: context,
          lane: lane,
          progress: progress,
          percent: insertedValue,
        ) ??
        _syncLayerScopeBlurKeyframeToGraph(
          context: context,
          lane: lane,
          progress: progress,
        ) ??
        _syncLayerScopeRevealKeyframeToGraph(
          context: context,
          lane: lane,
          progress: progress,
          percent: insertedValue,
        ) ??
        _syncLayerScopePositionKeyframeToGraph(
          context: context,
          lane: lane,
          progress: progress,
        ) ??
        _syncLayerScopeScaleKeyframeToGraph(
          context: context,
          lane: lane,
          progress: progress,
        ) ??
        _syncLayerScopeRotationKeyframeToGraph(
          context: context,
          lane: lane,
          progress: progress,
        );
    _updateTimelineAnimationLane(
      laneId,
      (currentLane) => currentLane.copyWith(
        normalizedKeyframeStops: List<double>.unmodifiable(stops),
        keyframeIds: List<String>.unmodifiable(keyframeIds),
        keyframeValues: List<double>.unmodifiable(values),
      ),
    );
    setState(() {
      if (syncedChannels != null) {
        _manualMotionPropertyChannels = syncedChannels;
        _markMotionAuthoringChanged();
      }
      _selectedLayerScopeAnimationLaneId = laneId;
      _selectedLayerScopeKeyframeIndex = insertIndex;
      _selectedLayerScopeKeyframeId = insertedKeyframeId;
      _isLayerScopeValueEditorOpen = false;
    });
  }

  Future<void> _handleLayerScopeValueToolTap() async {
    if (_isLayerScopeValueEditorOpen) {
      return;
    }
    final scopeContext = _activeLayerScopeContext;
    if (scopeContext == null) {
      return;
    }
    final lane = _layerScopeSelectedAnimationLane(scopeContext);
    if (lane == null) {
      return;
    }
    if (!_layerScopeLaneSupportsValueControls(lane)) {
      return;
    }
    final resolvedKeyframeIndex = _selectedLayerScopeKeyframeIndex ??
        _nearestLayerScopeKeyframeIndex(scopeContext, lane);
    if (resolvedKeyframeIndex == null) {
      return;
    }
    final controls = _layerScopeValueControlsForSelection(
      context: scopeContext,
      lane: lane,
      keyframeIndex: resolvedKeyframeIndex,
    );
    if (controls == null || controls.isEmpty) {
      return;
    }
    setState(() {
      _selectedLayerScopeKeyframeIndex = resolvedKeyframeIndex;
      _selectedLayerScopeKeyframeId =
          _layerScopeKeyframeIdAt(lane, resolvedKeyframeIndex);
      _isLayerScopeValueEditorOpen = true;
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaQuery.removeViewInsets(
        context: sheetContext,
        removeBottom: true,
        child: LayerScopeValueBottomSheet(
          controls: controls,
          onDone: () => Navigator.of(sheetContext).maybePop(),
          onChanged: (change) => _handleLayerScopeValueControlChanged(
            change.controlId,
            change.value,
          ),
        ),
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLayerScopeValueEditorOpen = false;
      });
    });
  }

  Future<void> _handleLayerScopeGraphToolTap() async {
    if (_isLayerScopeGraphEditorOpen) {
      return;
    }
    final scopeContext = _activeLayerScopeContext;
    if (scopeContext == null) {
      return;
    }
    final lane = _layerScopeSelectedAnimationLane(scopeContext);
    if (lane == null || !_layerScopeLaneSupportsValueControls(lane)) {
      return;
    }
    final resolvedKeyframeIndex = _selectedLayerScopeKeyframeIndex ??
        _nearestLayerScopeKeyframeIndex(scopeContext, lane);
    if (resolvedKeyframeIndex == null ||
        (resolvedKeyframeIndex <= 0 &&
            resolvedKeyframeIndex >= lane.normalizedKeyframeStops.length - 1)) {
      return;
    }
    final easyEaseEnabled = _isLayerScopeEasyEaseActive(
      context: scopeContext,
      lane: lane,
      keyframeIndex: resolvedKeyframeIndex,
    );
    setState(() {
      _selectedLayerScopeKeyframeIndex = resolvedKeyframeIndex;
      _selectedLayerScopeKeyframeId =
          _layerScopeKeyframeIdAt(lane, resolvedKeyframeIndex);
      _isLayerScopeGraphEditorOpen = true;
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaQuery.removeViewInsets(
        context: sheetContext,
        removeBottom: true,
        child: LayerScopeGraphBottomSheet(
          easyEaseEnabled: easyEaseEnabled,
          onDone: () => Navigator.of(sheetContext).maybePop(),
          onEasyEaseChanged: _handleLayerScopeEasyEaseChanged,
        ),
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLayerScopeGraphEditorOpen = false;
      });
    });
  }

  void _handleLayerScopeValueControlChanged(
    String controlId,
    double value,
  ) {
    final context = _activeLayerScopeContext;
    final keyframeIndex = _selectedLayerScopeKeyframeIndex;
    if (context == null || keyframeIndex == null) {
      return;
    }
    final lane = _layerScopeSelectedAnimationLane(context);
    if (lane == null || !_layerScopeLaneSupportsValueControls(lane)) {
      return;
    }
    final stops = lane.normalizedKeyframeStops;
    if (keyframeIndex < 0 || keyframeIndex >= stops.length) {
      return;
    }
    final controls = _layerScopeValueControlsForSelection(
      context: context,
      lane: lane,
      keyframeIndex: keyframeIndex,
    );
    if (controls == null) {
      return;
    }
    final controlValues = <String, double>{
      for (final control in controls) control.id: control.value,
    };
    final progress = stops[keyframeIndex];
    List<MotionPropertyChannelModel>? syncedChannels;
    if (controlId == 'opacity') {
      syncedChannels = _syncLayerScopeOpacityKeyframeToGraph(
        context: context,
        lane: lane,
        progress: progress,
        percent: value.clamp(0.0, 100.0).toDouble(),
      );
    } else if (_layerScopeBlurControlIds.contains(controlId)) {
      final blurValues = <String, double>{
        'blurAmount': controlValues['blurAmount'] ?? 0,
        'blurMix': controlValues['blurMix'] ?? 100,
        'blurEdgeMode': controlValues['blurEdgeMode'] ?? 0,
        'blurCrop': controlValues['blurCrop'] ?? 0,
        controlId: value,
      };
      syncedChannels = _syncLayerScopeBlurValueToGraph(
        context: context,
        lane: lane,
        progress: progress,
        values: blurValues,
      );
    } else if (controlId == 'revealProgress') {
      syncedChannels = _syncLayerScopeRevealKeyframeToGraph(
        context: context,
        lane: lane,
        progress: progress,
        percent: value.clamp(0.0, 100.0).toDouble(),
      );
    } else if (controlId == 'revealBy') {
      final nextBindings = _updateLayerScopeRevealBinding(
        context: context,
        revealUnit: value.round() <= 0
            ? MotionTextRevealUnit.word
            : MotionTextRevealUnit.letter,
      );
      if (nextBindings == null) {
        return;
      }
      setState(() {
        _motionTextAnimationBindings = nextBindings;
        _markMotionAuthoringChanged();
      });
      return;
    } else if (controlId == 'revealDirection') {
      final nextBindings = _updateLayerScopeRevealBinding(
        context: context,
        revealDirection: value.round() <= 0
            ? MotionTextRevealDirection.forward
            : MotionTextRevealDirection.reverse,
      );
      if (nextBindings == null) {
        return;
      }
      setState(() {
        _motionTextAnimationBindings = nextBindings;
        _markMotionAuthoringChanged();
      });
      return;
    } else if (controlId == 'positionX' || controlId == 'positionY') {
      syncedChannels = _syncLayerScopePositionValueToGraph(
        context: context,
        lane: lane,
        progress: progress,
        x: (controlId == 'positionX'
                ? value
                : controlValues['positionX'] ?? 0.0)
            .roundToDouble(),
        y: (controlId == 'positionY'
                ? value
                : controlValues['positionY'] ?? 0.0)
            .roundToDouble(),
      );
    } else if (controlId == 'scale') {
      syncedChannels = _syncLayerScopeScaleValueToGraph(
        context: context,
        lane: lane,
        progress: progress,
        percent: value.clamp(20.0, 800.0).toDouble(),
      );
    } else if (controlId == 'rotationAngle' || controlId == 'rotationTurns') {
      final angle = controlId == 'rotationAngle'
          ? value.clamp(-180.0, 180.0).toDouble()
          : controlValues['rotationAngle'] ?? 0.0;
      final turns = (controlId == 'rotationTurns'
              ? value.clamp(-4.0, 4.0).toDouble()
              : controlValues['rotationTurns'] ?? 0.0)
          .round();
      syncedChannels = _syncLayerScopeRotationValueToGraph(
        context: context,
        lane: lane,
        progress: progress,
        degrees: (turns * 360.0) + angle,
      );
    }
    if (syncedChannels == null) {
      return;
    }
    setState(() {
      _manualMotionPropertyChannels = syncedChannels!;
      _markMotionAuthoringChanged();
    });
  }

  void _handleLayerScopeEasyEaseChanged(bool enabled) {
    final scopeContext = _activeLayerScopeContext;
    final keyframeIndex = _selectedLayerScopeKeyframeIndex;
    if (scopeContext == null || keyframeIndex == null) {
      return;
    }
    final lane = _layerScopeSelectedAnimationLane(scopeContext);
    if (lane == null) {
      return;
    }
    final syncedChannels = _setLayerScopeKeyframeInterpolationToGraph(
      context: scopeContext,
      lane: lane,
      keyframeIndex: keyframeIndex,
      interpolation: enabled
          ? _afterEffectsEasyEaseInterpolation
          : const MotionInterpolationSpec.linear(),
    );
    if (syncedChannels == null) {
      return;
    }
    setState(() {
      _manualMotionPropertyChannels = syncedChannels;
      _markMotionAuthoringChanged();
    });
  }

  void _handleLayerScopeDockAddTap() {
    final context = _activeLayerScopeContext;
    if (context == null) {
      return;
    }
    if (context.track.kind == TimelineTrackKind.text) {
      unawaited(_handleLayerScopeTextScriptTap());
      return;
    }
    if (context.track.kind == TimelineTrackKind.image) {
      unawaited(_openMediaSheet(EditorMediaTab.image));
      return;
    }
    if (context.track.kind == TimelineTrackKind.video) {
      unawaited(_openMediaSheet(EditorMediaTab.video));
    }
  }

  Future<void> _handleLayerScopeTextScriptTap() async {
    final scopeContext = _activeLayerScopeContext;
    if (scopeContext == null ||
        scopeContext.track.kind != TimelineTrackKind.text) {
      return;
    }
    final document = await showModalBottomSheet<ScopedTextMotionScriptDocument>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const ScopedTextMotionScriptBottomSheet(),
    );
    if (!mounted || document == null) {
      return;
    }
    _applyScopedTextMotionScriptDocument(scopeContext, document);
  }

  void _applyScopedTextMotionScriptDocument(
    _LayerScopeContext scopeContext,
    ScopedTextMotionScriptDocument document,
  ) {
    if (scopeContext.track.kind != TimelineTrackKind.text) {
      _showStageMessage('Scripts are available for text layers only.');
      return;
    }
    final textContext = _motionTextElementContextForId(scopeContext.clip.id);
    if (textContext == null) {
      _showStageMessage('Unable to resolve this text layer.');
      return;
    }
    final activeRange = _motionTextTimingRangeForElement(
      scene: textContext.scene,
      element: textContext.element,
    );
    final imported = _buildManualChannelsFromScopedTextMotionScript(
      textContext: textContext,
      activeRange: activeRange,
      document: document,
    );
    if (imported.channels.isEmpty) {
      _showStageMessage('This script did not produce any editable keyframes.');
      return;
    }
    final nextChannels = <MotionPropertyChannelModel>[
      for (final channel in _manualMotionPropertyChannels)
        if (channel.target.targetId != textContext.element.id ||
            !imported.definitionIds.contains(channel.definition.id))
          channel,
      ...imported.channels,
    ];
    final nextBindings = _bindingsAfterScopedTextScriptImport(
      textContext: textContext,
      activeRange: activeRange,
      revealUnit: imported.revealUnit,
      revealDirection: imported.revealDirection,
    );
    final nextTracks = _tracksAfterScopedTextScriptImport(scopeContext);
    setState(() {
      _tracks = nextTracks;
      _manualMotionPropertyChannels =
          List<MotionPropertyChannelModel>.unmodifiable(nextChannels);
      _motionTextAnimationBindings =
          List<MotionTextAnimationBindingModel>.unmodifiable(nextBindings);
      _markMotionAuthoringChanged();
      _selectedClipId = scopeContext.clip.id;
      _selectedLayerScopeAnimationLaneId = imported.selectedLaneId;
      _selectedLayerScopeKeyframeIndex = null;
      _selectedLayerScopeKeyframeId = null;
      _isLayerScopeValueEditorOpen = false;
      _isLayerScopeGraphEditorOpen = false;
      _activeTab = EditorMediaTab.text;
    });
    _showStageMessage(
      'Applied script: ${imported.laneCount} lane(s), ${imported.keyframeCount} keyframes.',
    );
  }

  ({
    List<MotionPropertyChannelModel> channels,
    Set<String> definitionIds,
    MotionTextRevealUnit? revealUnit,
    MotionTextRevealDirection? revealDirection,
    String? selectedLaneId,
    int laneCount,
    int keyframeCount,
  }) _buildManualChannelsFromScopedTextMotionScript({
    required _MotionTextElementContext textContext,
    required TimelineTimeRange activeRange,
    required ScopedTextMotionScriptDocument document,
  }) {
    final channelsByDefinitionId = <String, MotionPropertyChannelModel>{};
    if (document.animationBlocks.isNotEmpty) {
      for (final channel in _lowerImportedAnimationBlocksToManualChannels(
        textContext: textContext,
        activeRange: activeRange,
        document: document,
      )) {
        channelsByDefinitionId[channel.definition.id] = channel;
      }
    }
    for (final channel in _explicitManualChannelsFromScopedTextMotionScript(
      textContext: textContext,
      activeRange: activeRange,
      document: document,
    )) {
      channelsByDefinitionId[channel.definition.id] = channel;
    }
    final definitionIds = channelsByDefinitionId.keys.toSet();
    final revealUnit =
        definitionIds.contains(MotionPropertyCatalog.revealProgress.id) ||
                document.revealUnit != null
            ? (document.revealUnit ?? MotionTextRevealUnit.letter)
            : null;
    final revealDirection =
        revealUnit == null ? null : document.revealDirection;
    final preferredDefinition = document.channels.isNotEmpty
        ? _scriptImportedPrimaryDefinitionForProperty(
            document.channels.first.property,
          )
        : (channelsByDefinitionId.isEmpty
            ? null
            : channelsByDefinitionId.values.first.definition);
    final selectedLaneId = preferredDefinition == null
        ? null
        : _scriptImportedLaneIdForDefinition(
            textContext.element.id,
            preferredDefinition,
          );
    final laneIds = <String>{
      for (final channel in channelsByDefinitionId.values)
        if (_scriptImportedLaneIdForDefinition(
              textContext.element.id,
              channel.definition,
            ) !=
            null)
          _scriptImportedLaneIdForDefinition(
            textContext.element.id,
            channel.definition,
          )!,
    };
    final keyframeCount = channelsByDefinitionId.values.fold<int>(
      0,
      (sum, channel) => sum + channel.keyframes.length,
    );
    return (
      channels: List<MotionPropertyChannelModel>.unmodifiable(
        channelsByDefinitionId.values,
      ),
      definitionIds: definitionIds,
      revealUnit: revealUnit,
      revealDirection: revealDirection,
      selectedLaneId: selectedLaneId,
      laneCount: laneIds.length,
      keyframeCount: keyframeCount,
    );
  }

  List<MotionPropertyChannelModel>
      _explicitManualChannelsFromScopedTextMotionScript({
    required _MotionTextElementContext textContext,
    required TimelineTimeRange activeRange,
    required ScopedTextMotionScriptDocument document,
  }) {
    final importedChannels = <MotionPropertyChannelModel>[];
    for (final channelSpec in document.channels) {
      switch (channelSpec.property) {
        case 'opacity':
          importedChannels.add(
            _scriptImportedManualChannel(
              textContext: textContext,
              activeRange: activeRange,
              definition: MotionPropertyCatalog.opacity,
              keyframes: channelSpec.keyframes.map(
                (keyframe) => _scriptImportedScalarKeyframe(
                  channelId: _scriptImportedChannelId(
                    textContext.element.id,
                    MotionPropertyCatalog.opacity,
                  ),
                  time: _scriptImportedGlobalTime(
                    activeRange,
                    keyframe.time,
                  ),
                  scalar: _scriptImportedUnitIntervalValue(
                    keyframe.value.rawValue as double,
                  ),
                  interpolation: keyframe.interpolation,
                ),
              ),
            ),
          );
          break;
        case 'position':
          for (final axisChannel in _scriptImportedPointChannels(
            textContext: textContext,
            activeRange: activeRange,
            pointKeyframes: channelSpec.keyframes,
            xDefinition: MotionPropertyCatalog.positionX,
            yDefinition: MotionPropertyCatalog.positionY,
            normalizeAxisValue: (value) => value,
          )) {
            importedChannels.add(axisChannel);
          }
          break;
        case 'positionX':
          importedChannels.add(
            _scriptImportedManualChannel(
              textContext: textContext,
              activeRange: activeRange,
              definition: MotionPropertyCatalog.positionX,
              keyframes: channelSpec.keyframes.map(
                (keyframe) => _scriptImportedScalarKeyframe(
                  channelId: _scriptImportedChannelId(
                    textContext.element.id,
                    MotionPropertyCatalog.positionX,
                  ),
                  time: _scriptImportedGlobalTime(activeRange, keyframe.time),
                  scalar: keyframe.value.rawValue as double,
                  interpolation: keyframe.interpolation,
                ),
              ),
            ),
          );
          break;
        case 'positionY':
          importedChannels.add(
            _scriptImportedManualChannel(
              textContext: textContext,
              activeRange: activeRange,
              definition: MotionPropertyCatalog.positionY,
              keyframes: channelSpec.keyframes.map(
                (keyframe) => _scriptImportedScalarKeyframe(
                  channelId: _scriptImportedChannelId(
                    textContext.element.id,
                    MotionPropertyCatalog.positionY,
                  ),
                  time: _scriptImportedGlobalTime(activeRange, keyframe.time),
                  scalar: keyframe.value.rawValue as double,
                  interpolation: keyframe.interpolation,
                ),
              ),
            ),
          );
          break;
        case 'scale':
          for (final axisChannel in _scriptImportedPointChannels(
            textContext: textContext,
            activeRange: activeRange,
            pointKeyframes: channelSpec.keyframes,
            xDefinition: MotionPropertyCatalog.scaleX,
            yDefinition: MotionPropertyCatalog.scaleY,
            normalizeAxisValue: _scriptImportedScaleValue,
          )) {
            importedChannels.add(axisChannel);
          }
          break;
        case 'scaleX':
          importedChannels.add(
            _scriptImportedManualChannel(
              textContext: textContext,
              activeRange: activeRange,
              definition: MotionPropertyCatalog.scaleX,
              keyframes: channelSpec.keyframes.map(
                (keyframe) => _scriptImportedScalarKeyframe(
                  channelId: _scriptImportedChannelId(
                    textContext.element.id,
                    MotionPropertyCatalog.scaleX,
                  ),
                  time: _scriptImportedGlobalTime(activeRange, keyframe.time),
                  scalar: _scriptImportedScaleValue(
                    keyframe.value.rawValue as double,
                  ),
                  interpolation: keyframe.interpolation,
                ),
              ),
            ),
          );
          break;
        case 'scaleY':
          importedChannels.add(
            _scriptImportedManualChannel(
              textContext: textContext,
              activeRange: activeRange,
              definition: MotionPropertyCatalog.scaleY,
              keyframes: channelSpec.keyframes.map(
                (keyframe) => _scriptImportedScalarKeyframe(
                  channelId: _scriptImportedChannelId(
                    textContext.element.id,
                    MotionPropertyCatalog.scaleY,
                  ),
                  time: _scriptImportedGlobalTime(activeRange, keyframe.time),
                  scalar: _scriptImportedScaleValue(
                    keyframe.value.rawValue as double,
                  ),
                  interpolation: keyframe.interpolation,
                ),
              ),
            ),
          );
          break;
        case 'rotation':
          importedChannels.add(
            _scriptImportedManualChannel(
              textContext: textContext,
              activeRange: activeRange,
              definition: MotionPropertyCatalog.rotationDegrees,
              keyframes: channelSpec.keyframes.map(
                (keyframe) => _scriptImportedScalarKeyframe(
                  channelId: _scriptImportedChannelId(
                    textContext.element.id,
                    MotionPropertyCatalog.rotationDegrees,
                  ),
                  time: _scriptImportedGlobalTime(activeRange, keyframe.time),
                  scalar: keyframe.value.rawValue as double,
                  interpolation: keyframe.interpolation,
                ),
              ),
            ),
          );
          break;
        case 'blur':
          importedChannels.add(
            _scriptImportedManualChannel(
              textContext: textContext,
              activeRange: activeRange,
              definition: MotionPropertyCatalog.blurAmount,
              keyframes: channelSpec.keyframes.map(
                (keyframe) => _scriptImportedScalarKeyframe(
                  channelId: _scriptImportedChannelId(
                    textContext.element.id,
                    MotionPropertyCatalog.blurAmount,
                  ),
                  time: _scriptImportedGlobalTime(activeRange, keyframe.time),
                  scalar: (keyframe.value.rawValue as double)
                      .clamp(0.0, 100.0)
                      .toDouble(),
                  interpolation: keyframe.interpolation,
                ),
              ),
            ),
          );
          break;
        case 'revealProgress':
          importedChannels.add(
            _scriptImportedManualChannel(
              textContext: textContext,
              activeRange: activeRange,
              definition: MotionPropertyCatalog.revealProgress,
              keyframes: channelSpec.keyframes.map(
                (keyframe) => _scriptImportedScalarKeyframe(
                  channelId: _scriptImportedChannelId(
                    textContext.element.id,
                    MotionPropertyCatalog.revealProgress,
                  ),
                  time: _scriptImportedGlobalTime(activeRange, keyframe.time),
                  scalar: _scriptImportedUnitIntervalValue(
                    keyframe.value.rawValue as double,
                  ),
                  interpolation: keyframe.interpolation,
                ),
              ),
            ),
          );
          break;
      }
    }
    return List<MotionPropertyChannelModel>.unmodifiable(importedChannels);
  }

  List<MotionPropertyChannelModel> _scriptImportedPointChannels({
    required _MotionTextElementContext textContext,
    required TimelineTimeRange activeRange,
    required List<ScopedTextMotionScriptKeyframeSpec> pointKeyframes,
    required MotionPropertyDefinition xDefinition,
    required MotionPropertyDefinition yDefinition,
    required double Function(double value) normalizeAxisValue,
  }) {
    final targetId = textContext.element.id;
    final xKeyframes = <MotionKeyframeModel>[];
    final yKeyframes = <MotionKeyframeModel>[];
    final xChannelId = _scriptImportedChannelId(targetId, xDefinition);
    final yChannelId = _scriptImportedChannelId(targetId, yDefinition);
    for (final keyframe in pointKeyframes) {
      if (keyframe.value.kind != MotionPropertyValueKind.point2D) {
        continue;
      }
      final point = keyframe.value.rawValue as MotionPoint2D;
      final time = _scriptImportedGlobalTime(activeRange, keyframe.time);
      xKeyframes.add(
        _scriptImportedScalarKeyframe(
          channelId: xChannelId,
          time: time,
          scalar: normalizeAxisValue(point.x),
          interpolation: keyframe.interpolation,
        ),
      );
      yKeyframes.add(
        _scriptImportedScalarKeyframe(
          channelId: yChannelId,
          time: time,
          scalar: normalizeAxisValue(point.y),
          interpolation: keyframe.interpolation,
        ),
      );
    }
    return <MotionPropertyChannelModel>[
      _scriptImportedManualChannel(
        textContext: textContext,
        activeRange: activeRange,
        definition: xDefinition,
        keyframes: xKeyframes,
      ),
      _scriptImportedManualChannel(
        textContext: textContext,
        activeRange: activeRange,
        definition: yDefinition,
        keyframes: yKeyframes,
      ),
    ];
  }

  List<MotionPropertyChannelModel>
      _lowerImportedAnimationBlocksToManualChannels({
    required _MotionTextElementContext textContext,
    required TimelineTimeRange activeRange,
    required ScopedTextMotionScriptDocument document,
  }) {
    final normalizedBlocks = <MotionTextAnimationBlock>[
      for (final block in document.animationBlocks)
        MotionTextAnimationBlock(
          id: block.id,
          kind: block.kind,
          relativeRange: block.relativeRange,
          interpolation: block.interpolation,
          revealSpec: block.revealSpec,
          parameters:
              _normalizedScriptAnimationBlockParameters(block.parameters),
        ),
    ];
    if (normalizedBlocks.isEmpty) {
      return const <MotionPropertyChannelModel>[];
    }
    final binding = MotionTextAnimationBindingModel(
      id: _nextMotionEntityId('script-binding'),
      elementTarget: textContext.elementTarget,
      activeRange: activeRange,
      animationBlocks: normalizedBlocks,
      parameterValues: const <String, MotionPropertyValue>{},
    );
    final compileResult = BasicMotionTextPresetCompiler(
      presetCatalog: _availableTextPresets,
    ).compileBindings(
      request: MotionCompileRequest(
        project: _effectiveMotionProject,
        propertyChannels: const <MotionPropertyChannelModel>[],
        textAnimationBindings: <MotionTextAnimationBindingModel>[binding],
      ),
      elementsById: <String, MotionElementModel>{
        textContext.element.id: textContext.element,
      },
    );
    return List<MotionPropertyChannelModel>.unmodifiable(
      compileResult.generatedChannels
          .map(
            (channel) => _scriptRemappedImportedChannel(
              source: channel,
              textContext: textContext,
              activeRange: activeRange,
            ),
          )
          .where((channel) => channel.keyframes.isNotEmpty),
    );
  }

  Map<String, MotionPropertyValue> _normalizedScriptAnimationBlockParameters(
    Map<String, MotionPropertyValue> parameters,
  ) {
    if (parameters.isEmpty) {
      return parameters;
    }
    return <String, MotionPropertyValue>{
      for (final entry in parameters.entries)
        entry.key: switch (entry.key) {
          'fromScale' ||
          'toScale' =>
            entry.value.kind == MotionPropertyValueKind.scalar
                ? MotionPropertyValue.scalar(
                    _scriptImportedScaleValue(entry.value.rawValue as double),
                  )
                : entry.value,
          'fromOpacity' ||
          'toOpacity' =>
            entry.value.kind == MotionPropertyValueKind.scalar
                ? MotionPropertyValue.scalar(
                    _scriptImportedUnitIntervalValue(
                        entry.value.rawValue as double),
                  )
                : entry.value,
          _ => entry.value,
        },
    };
  }

  MotionPropertyChannelModel _scriptRemappedImportedChannel({
    required MotionPropertyChannelModel source,
    required _MotionTextElementContext textContext,
    required TimelineTimeRange activeRange,
  }) {
    final channelId = _scriptImportedChannelId(
      textContext.element.id,
      source.definition,
    );
    return MotionPropertyChannelModel(
      id: channelId,
      target: textContext.elementTarget,
      definition: source.definition,
      activeRange: activeRange,
      baseValue: source.baseValue ??
          MotionPropertyValue.scalar(
            _elementScalarPropertyOrDefault(
              textContext.element,
              source.definition,
            ),
          ),
      beforeStart: source.beforeStart,
      afterEnd: source.afterEnd,
      keyframes: _normalizedScriptImportedKeyframes(
        source.keyframes.map(
          (keyframe) => MotionKeyframeModel(
            id: _scriptImportedKeyframeId(channelId, keyframe.time),
            channelId: channelId,
            time: _scriptImportedGlobalTime(
              activeRange,
              keyframe.time - activeRange.start,
            ),
            value: keyframe.value,
            interpolationToNext: keyframe.interpolationToNext,
          ),
        ),
      ),
    );
  }

  MotionPropertyChannelModel _scriptImportedManualChannel({
    required _MotionTextElementContext textContext,
    required TimelineTimeRange activeRange,
    required MotionPropertyDefinition definition,
    required Iterable<MotionKeyframeModel> keyframes,
  }) {
    final channelId =
        _scriptImportedChannelId(textContext.element.id, definition);
    return MotionPropertyChannelModel(
      id: channelId,
      target: textContext.elementTarget,
      definition: definition,
      activeRange: activeRange,
      baseValue: MotionPropertyValue.scalar(
        _elementScalarPropertyOrDefault(textContext.element, definition),
      ),
      keyframes: _normalizedScriptImportedKeyframes(keyframes),
    );
  }

  MotionKeyframeModel _scriptImportedScalarKeyframe({
    required String channelId,
    required TimelineTime time,
    required double scalar,
    required MotionInterpolationSpec interpolation,
  }) {
    return MotionKeyframeModel(
      id: _scriptImportedKeyframeId(channelId, time),
      channelId: channelId,
      time: time,
      value: MotionPropertyValue.scalar(scalar),
      interpolationToNext: interpolation,
    );
  }

  List<MotionKeyframeModel> _normalizedScriptImportedKeyframes(
    Iterable<MotionKeyframeModel> keyframes,
  ) {
    final byTick = <int, MotionKeyframeModel>{};
    for (final keyframe in keyframes) {
      byTick[keyframe.time.inProjectTicks] = keyframe;
    }
    final sortedTicks = byTick.keys.toList()..sort();
    return List<MotionKeyframeModel>.unmodifiable(
      <MotionKeyframeModel>[
        for (final tick in sortedTicks) byTick[tick]!,
      ],
    );
  }

  TimelineTime _scriptImportedGlobalTime(
    TimelineTimeRange activeRange,
    TimelineTime relativeTime,
  ) {
    final clampedRelative = relativeTime.clamp(
      TimelineTime.zero,
      activeRange.duration,
    );
    return activeRange.start + clampedRelative;
  }

  String _scriptImportedChannelId(
    String targetId,
    MotionPropertyDefinition definition,
  ) {
    return 'manual.$targetId.${definition.id}';
  }

  String _scriptImportedKeyframeId(
    String channelId,
    TimelineTime time,
  ) {
    return '$channelId@${time.inProjectTicks}';
  }

  double _scriptImportedScaleValue(double raw) {
    if (!raw.isFinite) {
      return 1.0;
    }
    if (raw.abs() > 8.0) {
      return raw / 100.0;
    }
    return raw;
  }

  double _scriptImportedUnitIntervalValue(double raw) {
    if (!raw.isFinite) {
      return 0.0;
    }
    if (raw.abs() > 1.0) {
      return (raw / 100.0).clamp(0.0, 1.0).toDouble();
    }
    return raw.clamp(0.0, 1.0).toDouble();
  }

  List<MotionTextAnimationBindingModel> _bindingsAfterScopedTextScriptImport({
    required _MotionTextElementContext textContext,
    required TimelineTimeRange activeRange,
    required MotionTextRevealUnit? revealUnit,
    required MotionTextRevealDirection? revealDirection,
  }) {
    final nextBindings = <MotionTextAnimationBindingModel>[
      for (final binding in _motionTextAnimationBindings)
        if (binding.elementTarget.targetId != textContext.element.id) binding,
    ];
    if (revealUnit == null) {
      return nextBindings;
    }
    nextBindings.add(
      MotionTextAnimationBindingModel(
        id: _nextMotionEntityId('text-script-binding'),
        elementTarget: textContext.elementTarget,
        activeRange: activeRange,
        animationBlocks: <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: 'script.reveal.${textContext.element.id}',
            kind: revealUnit == MotionTextRevealUnit.word
                ? MotionTextAnimationKind.wordReveal
                : MotionTextAnimationKind.typewriter,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: activeRange.duration,
            ),
            interpolation: const MotionInterpolationSpec.linear(),
            revealSpec: MotionTextRevealSpec(
              unit: revealUnit,
              stagger: TimelineTime.zero,
            ),
            parameters: <String, MotionPropertyValue>{
              'manualRevealProgress': const MotionPropertyValue.boolean(true),
              'revealDirection': MotionPropertyValue.enumValue(
                (revealDirection ?? MotionTextRevealDirection.forward).name,
              ),
            },
          ),
        ],
        parameterValues: <String, MotionPropertyValue>{
          'revealBy': MotionPropertyValue.enumValue(revealUnit.name),
          'revealDirection': MotionPropertyValue.enumValue(
            (revealDirection ?? MotionTextRevealDirection.forward).name,
          ),
        },
      ),
    );
    return nextBindings;
  }

  List<TimelineTrackData> _tracksAfterScopedTextScriptImport(
    _LayerScopeContext scopeContext,
  ) {
    final trackIndex = _tracks.indexWhere(
      (candidate) => candidate.kind == scopeContext.track.kind,
    );
    if (trackIndex < 0) {
      return _tracks;
    }
    final nextTracks = List<TimelineTrackData>.from(_tracks);
    final track = nextTracks[trackIndex];
    nextTracks[trackIndex] = track.copyWith(
      animationLanes: <TimelineAnimationLaneData>[
        for (final lane in track.animationLanes)
          if (!(lane.targetClipId == scopeContext.clip.id &&
              _isScopedTextScriptManagedLane(lane)))
            lane,
      ],
    );
    return List<TimelineTrackData>.unmodifiable(nextTracks);
  }

  bool _isScopedTextScriptManagedLane(TimelineAnimationLaneData lane) =>
      lane.matchesPropertyLabel('opacity') ||
      lane.matchesPropertyLabel('position') ||
      lane.matchesPropertyLabel('scale') ||
      lane.matchesPropertyLabel('rotation') ||
      _layerScopeLaneMatchesBlur(lane) ||
      _layerScopeLaneMatchesReveal(lane);

  String? _scriptImportedLaneIdForDefinition(
    String elementId,
    MotionPropertyDefinition definition,
  ) {
    if (definition.id == MotionPropertyCatalog.opacity.id) {
      return 'anim-text-$elementId-opacity';
    }
    if (definition.id == MotionPropertyCatalog.positionX.id ||
        definition.id == MotionPropertyCatalog.positionY.id) {
      return 'anim-text-$elementId-position';
    }
    if (definition.id == MotionPropertyCatalog.scaleX.id ||
        definition.id == MotionPropertyCatalog.scaleY.id) {
      return 'anim-text-$elementId-scale';
    }
    if (definition.id == MotionPropertyCatalog.rotationDegrees.id) {
      return 'anim-text-$elementId-rotation';
    }
    if (definition.id == MotionPropertyCatalog.blurAmount.id ||
        definition.id == MotionPropertyCatalog.blurMix.id ||
        definition.id == MotionPropertyCatalog.blurEdgeMode.id ||
        definition.id == MotionPropertyCatalog.blurCrop.id) {
      return 'anim-text-$elementId-gaussian-blur';
    }
    if (definition.id == MotionPropertyCatalog.revealProgress.id) {
      return 'anim-text-$elementId-reveal-progress';
    }
    return null;
  }

  MotionPropertyDefinition? _scriptImportedPrimaryDefinitionForProperty(
    String property,
  ) {
    switch (property) {
      case 'opacity':
        return MotionPropertyCatalog.opacity;
      case 'position':
      case 'positionX':
        return MotionPropertyCatalog.positionX;
      case 'positionY':
        return MotionPropertyCatalog.positionY;
      case 'scale':
      case 'scaleX':
        return MotionPropertyCatalog.scaleX;
      case 'scaleY':
        return MotionPropertyCatalog.scaleY;
      case 'rotation':
        return MotionPropertyCatalog.rotationDegrees;
      case 'blur':
        return MotionPropertyCatalog.blurAmount;
      case 'revealProgress':
        return MotionPropertyCatalog.revealProgress;
    }
    return null;
  }

  void _handleLayerScopeScrubFinalized(
    _LayerScopeContext context,
    TimelineTime localTime,
  ) {
    _handleTimelineScrubFinalized(_layerScopeGlobalTime(context, localTime));
  }

  void _handleCanvasTextSelected(String elementId) {
    _selectTextElement(elementId);
  }

  void _handleCanvasTextEditRequested(String elementId) {
    _enterLayerScope(elementId);
  }

  void _handleCanvasTextMoved(String elementId, Offset deltaCanvas) {
    final context = _motionTextElementContextForId(elementId);
    if (context == null) {
      return;
    }
    if (!_isAnimatingTextElementInScopedMode(elementId)) {
      _applyStaticTextElementScalarEdit(
        context,
        scalarProperties: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.positionX: _elementScalarPropertyOrDefault(
                context.element,
                MotionPropertyCatalog.positionX,
              ) +
              deltaCanvas.dx,
          MotionPropertyCatalog.positionY: _elementScalarPropertyOrDefault(
                context.element,
                MotionPropertyCatalog.positionY,
              ) +
              deltaCanvas.dy,
        },
      );
      return;
    }
    final nextChannels = _setTextMotionScalarKeyframes(
      context: context,
      scalarValues: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.positionX: _evaluatedTextScalarPropertyOrDefault(
              context,
              MotionPropertyCatalog.positionX,
            ) +
            deltaCanvas.dx,
        MotionPropertyCatalog.positionY: _evaluatedTextScalarPropertyOrDefault(
              context,
              MotionPropertyCatalog.positionY,
            ) +
            deltaCanvas.dy,
      },
    );
    setState(() {
      _manualMotionPropertyChannels = nextChannels;
      _markMotionAuthoringChanged();
      _selectedClipId = elementId;
      _activeTab = EditorMediaTab.text;
    });
  }

  void _handleCanvasTextScaleChanged(
    String elementId,
    double scaleX,
    double scaleY,
  ) {
    final context = _motionTextElementContextForId(elementId);
    if (context == null) {
      return;
    }
    if (!_isAnimatingTextElementInScopedMode(elementId)) {
      _applyStaticTextElementScalarEdit(
        context,
        scalarProperties: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.scaleX: scaleX.clamp(0.2, 8.0),
          MotionPropertyCatalog.scaleY: scaleY.clamp(0.2, 8.0),
        },
      );
      return;
    }
    final nextChannels = _setTextMotionScalarKeyframes(
      context: context,
      scalarValues: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.scaleX: scaleX.clamp(0.2, 8.0),
        MotionPropertyCatalog.scaleY: scaleY.clamp(0.2, 8.0),
      },
    );
    setState(() {
      _manualMotionPropertyChannels = nextChannels;
      _markMotionAuthoringChanged();
      _selectedClipId = elementId;
      _activeTab = EditorMediaTab.text;
    });
  }

  void _handleCanvasTextRotationChanged(
    String elementId,
    double rotationDegrees,
  ) {
    final context = _motionTextElementContextForId(elementId);
    if (context == null) {
      return;
    }
    if (!_isAnimatingTextElementInScopedMode(elementId)) {
      _applyStaticTextElementScalarEdit(
        context,
        scalarProperties: <MotionPropertyDefinition, double>{
          MotionPropertyCatalog.rotationDegrees: rotationDegrees,
        },
      );
      return;
    }
    final nextChannels = _setTextMotionScalarKeyframes(
      context: context,
      scalarValues: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.rotationDegrees: rotationDegrees,
      },
    );
    setState(() {
      _manualMotionPropertyChannels = nextChannels;
      _markMotionAuthoringChanged();
      _selectedClipId = elementId;
      _activeTab = EditorMediaTab.text;
    });
  }

  bool _isAnimatingTextElementInScopedMode(String elementId) =>
      _activeLayerScopeContext?.clip.id == elementId;

  void _applyStaticTextElementScalarEdit(
    _MotionTextElementContext context, {
    required Map<MotionPropertyDefinition, double> scalarProperties,
  }) {
    final nextProject = _updatedProjectForTextElement(
      context,
      scalarProperties: scalarProperties,
    );
    setState(() {
      _motionProject = nextProject;
      _markMotionAuthoringChanged();
      _selectedClipId = context.element.id;
      _activeTab = EditorMediaTab.text;
    });
  }

  void _handleDeleteSelectedClip() {
    final selectedClipId = _selectedClipId;
    if (selectedClipId != null && _isMotionTextElementId(selectedClipId)) {
      _handleDeleteSelectedMotionTextElement(selectedClipId);
      return;
    }
    final context = _selectedClipContext;
    if (!_hasSelectedImportedClip || context == null) {
      return;
    }
    final plan = _buildDeleteStructuralEditPlan(context);
    _applyStructuralEditPlan(plan);
  }

  void _handleDeleteSelectedMotionTextElement(String elementId) {
    final context = _motionTextElementContextForId(elementId);
    if (context == null) {
      return;
    }
    final shouldClearPreviewRange =
        _textEditPreviewRange?.elementId == elementId ||
            _textEditSession?.elementId == elementId;
    if (shouldClearPreviewRange) {
      _clearTextEditPreviewRange(pauseTransport: true);
    }

    final nextElements = List<MotionElementModel>.from(context.layer.elements)
      ..removeAt(context.elementIndex);
    final nextLayers = List<MotionLayerModel>.from(context.scene.layers)
      ..[context.layerIndex] = context.layer.copyWith(elements: nextElements);
    final nextScenes = List<MotionSceneModel>.from(context.project.scenes)
      ..[context.sceneIndex] = context.scene.copyWith(layers: nextLayers);
    final nextProject = context.project.copyWith(scenes: nextScenes);
    final nextBindings = _motionTextAnimationBindings
        .where((binding) => binding.elementTarget.targetId != elementId)
        .toList(growable: false);
    final nextManualChannels =
        _buildTextMotionKeyframeAuthoringService().removeChannelsForTarget(
      channels: _manualMotionPropertyChannels,
      targetId: elementId,
    );
    final resolvedState = _resolveMotionTextTimelineStateForProject(
      project: nextProject,
      preferredTimelineTime: _currentTime,
      bindings: nextBindings,
    );

    setState(() {
      _motionProject = nextProject;
      _motionTextAnimationBindings = nextBindings;
      _manualMotionPropertyChannels = nextManualChannels;
      _markMotionAuthoringChanged();
      if (_textEditSession?.elementId == elementId) {
        _textEditSession = null;
      }
      _selectedClipId = resolvedState.selectedClipId;
      _activeTab = EditorMediaTab.text;
      _previewAssetId = resolvedState.previewAssetId;
      _setCurrentTime(resolvedState.timelineTime);
    });
  }

  void _handleDuplicateSelectedClip() {
    final selectedClipId = _selectedClipId;
    if (selectedClipId != null && _isMotionTextElementId(selectedClipId)) {
      _handleDuplicateSelectedMotionTextElement(selectedClipId);
      return;
    }
    final context = _selectedClipContext;
    if (!_hasSelectedImportedClip || context == null) {
      return;
    }
    final plan = _buildDuplicateStructuralEditPlan(context);
    _applyStructuralEditPlan(plan);
  }

  void _handleDuplicateSelectedMotionTextElement(String elementId) {
    final context = _motionTextElementContextForId(elementId);
    if (context == null) {
      return;
    }
    final effectiveRange = _motionTextTimingRangeForElement(
      scene: context.scene,
      element: context.element,
    );
    final elementDuration = effectiveRange.duration;
    if (elementDuration <= TimelineTime.zero) {
      _showStageMessage('This text clip has no duplicatable duration yet.');
      return;
    }
    final shouldClearPreviewRange =
        _textEditPreviewRange?.elementId == elementId ||
            _textEditSession?.elementId == elementId;
    if (shouldClearPreviewRange) {
      _clearTextEditPreviewRange(pauseTransport: true);
    }

    final duplicatedElementId = _nextMotionEntityId('text-element');
    final duplicatedSourceId = _nextMotionEntityId('generated-text');
    final duplicatedBindingId = _nextMotionEntityId('text-binding');
    final duplicatedProjectRange = TimelineTimeRange(
      start: effectiveRange.endExclusive,
      endExclusive: effectiveRange.endExclusive + elementDuration,
    );
    final duplicatedLocalRange = TimelineTimeRange(
      start: duplicatedProjectRange.start - context.scene.projectRange.start,
      endExclusive: duplicatedProjectRange.endExclusive -
          context.scene.projectRange.start,
    );
    final duplicatedTarget = MotionPropertyTarget(
      kind: MotionTargetKind.element,
      targetId: duplicatedElementId,
      projectId: context.project.id,
      sceneId: context.scene.id,
      layerId: context.layer.id,
      elementId: duplicatedElementId,
    );
    final duplicatedSourceBinding = MotionElementSourceBinding(
      kind:
          context.element.sourceBinding?.kind ?? MotionSourceKind.generatedText,
      sourceId: duplicatedSourceId,
      assetId: context.element.sourceBinding?.assetId,
      label: context.element.sourceBinding?.label,
      sourceRange: context.element.sourceBinding?.sourceRange,
      metadata: <String, String>{...?(context.element.sourceBinding?.metadata)},
    );
    final duplicatedProperties = context.element.properties
        .map(
          (property) => MotionPropertyAssignment(
            target: duplicatedTarget,
            definition: property.definition,
            value: property.value,
          ),
        )
        .toList(growable: false);
    final duplicatedElement = context.element.copyWith(
      id: duplicatedElementId,
      localRange: duplicatedLocalRange,
      sourceBinding: duplicatedSourceBinding,
      properties: duplicatedProperties,
    );
    final nextElements = List<MotionElementModel>.from(context.layer.elements)
      ..insert(context.elementIndex + 1, duplicatedElement);
    final nextLayer = context.layer.copyWith(
      visibleRange: _expandedTimeRange(
        context.layer.visibleRange,
        duplicatedLocalRange,
      ),
      elements: nextElements,
    );
    final nextLayers = List<MotionLayerModel>.from(context.scene.layers)
      ..[context.layerIndex] = nextLayer;
    final nextScene = context.scene.copyWith(
      projectRange: _expandedTimeRange(
        context.scene.projectRange,
        duplicatedProjectRange,
      ),
      layers: nextLayers,
    );
    final nextScenes = List<MotionSceneModel>.from(context.project.scenes)
      ..[context.sceneIndex] = nextScene;
    final nextProject = context.project.copyWith(scenes: nextScenes);
    final binding = _motionTextBindingForElementId(elementId);
    final nextBindings = <MotionTextAnimationBindingModel>[
      ..._motionTextAnimationBindings,
      if (binding != null)
        MotionTextAnimationBindingModel(
          id: duplicatedBindingId,
          elementTarget: duplicatedTarget,
          activeRange: duplicatedProjectRange,
          presetId: binding.presetId,
          animationBlocks: binding.animationBlocks,
          parameterValues: binding.parameterValues,
        ),
    ];
    final nextManualChannels =
        _buildTextMotionKeyframeAuthoringService().duplicateChannelsForTarget(
      TextMotionChannelDuplicationRequest(
        channels: _manualMotionPropertyChannels,
        sourceTargetId: elementId,
        nextTarget: duplicatedTarget,
        sourceRange: effectiveRange,
        nextRange: duplicatedProjectRange,
      ),
    );
    final resolvedState = _resolveMotionTextTimelineStateForProject(
      project: nextProject,
      preferredTimelineTime: duplicatedProjectRange.start,
      preferredSelectedElementId: duplicatedElementId,
      bindings: nextBindings,
    );

    setState(() {
      _motionProject = nextProject;
      _motionTextAnimationBindings = nextBindings;
      _manualMotionPropertyChannels = nextManualChannels;
      _markMotionAuthoringChanged();
      if (_textEditSession?.elementId == elementId) {
        _textEditSession = null;
      }
      _selectedClipId = resolvedState.selectedClipId;
      _activeTab = EditorMediaTab.text;
      _previewAssetId = resolvedState.previewAssetId;
      _setCurrentTime(resolvedState.timelineTime);
    });
  }

  void _handleSplitSelectedClip() {
    final context = _selectedClipContext;
    if (!_hasSelectedImportedClip || context == null) {
      return;
    }
    if (!_canSplitSelectedClip) {
      _showStageMessage('Move the playhead inside the clip to split.');
      return;
    }
    final plan = _buildSplitStructuralEditPlan(context);
    _applyStructuralEditPlan(plan);
  }

  void _handleTimelineTrimCommit(TimelineTrimCommitRequest request) {
    _timelineTrimPreviewRequestId++;
    if (_timelineTrimPreviewSession != null ||
        _activeTrimPreviewSourceUri != null) {
      setState(() {
        _timelineTrimPreviewSession = null;
        _activeTrimPreviewSourceUri = null;
      });
    }
    _applyTimelineTrim(
      clipId: request.clipId,
      edge: request.edge,
      sourceStartTime: request.sourceStartTime,
      durationTime: request.durationTime,
    );
  }

  void _handleTimelineTrimPreviewChanged(TimelineTrimPreviewRequest? request) {
    if (request == null) {
      final activeTrimPreviewSession = _timelineTrimPreviewSession;
      final hadActiveTrimPreview = activeTrimPreviewSession != null ||
          _activeTrimPreviewSourceUri != null;
      final requestId = ++_timelineTrimPreviewRequestId;
      if (hadActiveTrimPreview) {
        setState(() {
          _timelineTrimPreviewSession = null;
          _activeTrimPreviewSourceUri = null;
          _previewAssetId = _previewAssetIdForTimelineTime(_currentTime);
        });
        _setTimelineDisplayTime(_currentTime);
      }
      if (hadActiveTrimPreview &&
          _useNativePreview &&
          !_isApplyingStructuralEdit &&
          activeTrimPreviewSession?.usesTransportPreview == true &&
          _transportController.state.sourceKind != 'timeline') {
        unawaited(_restoreTimelineTransportAfterTrimPreview(requestId));
      }
      return;
    }

    if (_isMotionTextElementId(request.clipId)) {
      final resolvedState = _resolveMotionTextTrimPreviewState(
        clipId: request.clipId,
        edge: request.edge,
        sourceStartTime: request.sourceStartTime,
        durationTime: request.durationTime,
        preferredTimelinePreviewTime: request.timelinePreviewTime,
      );
      if (resolvedState == null) {
        return;
      }
      final session = _TimelineTrimPreviewSession(
        clipId: request.clipId,
        timelinePreviewTime: resolvedState.timelineTime,
        previewAssetId: resolvedState.previewAssetId,
      );
      if (_isEquivalentTrimPreviewSession(
          _timelineTrimPreviewSession, session)) {
        return;
      }
      _setTimelineDisplayTime(resolvedState.timelineTime);
      setState(() {
        _timelineTrimPreviewSession = session;
        _activeTrimPreviewSourceUri = null;
        _selectedClipId = request.clipId;
        _activeTab = EditorMediaTab.text;
        _previewAssetId = resolvedState.previewAssetId;
      });
      return;
    }

    final context = _selectedClipContextForTracks(_tracks, request.clipId);
    final asset = context?.asset;
    final sourceUri = asset?.sourceUri;
    if (context == null ||
        asset == null ||
        sourceUri == null ||
        sourceUri.isEmpty ||
        asset.tab != EditorMediaTab.video ||
        !_transportController.isPlatformSupported ||
        _isApplyingStructuralEdit) {
      return;
    }

    final resolvedTrim = _resolveTimelineTrimValues(
      context: context,
      edge: request.edge,
      sourceStartTime: request.sourceStartTime,
      durationTime: request.durationTime,
    );
    final maxPreviewSourceTime = resolvedTrim.assetDurationTime ??
        resolvedTrim.sourceStartTime + resolvedTrim.sourceDurationTime;
    final safeTimelinePreviewTime = request.timelinePreviewTime.clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    final safeSourcePreviewTime = request.sourcePreviewTime.clamp(
      TimelineTime.zero,
      maxPreviewSourceTime,
    );
    final session = _TimelineTrimPreviewSession(
      clipId: request.clipId,
      timelinePreviewTime: safeTimelinePreviewTime,
      previewAssetId: _previewAssetId,
      sourceUri: sourceUri,
      sourceLabel: asset.label,
      sourcePreviewTime: safeSourcePreviewTime,
    );
    if (_isEquivalentTrimPreviewSession(_timelineTrimPreviewSession, session)) {
      return;
    }
    _setTimelineDisplayTime(safeTimelinePreviewTime);
    setState(() {
      _timelineTrimPreviewSession = session;
    });
    unawaited(_syncTimelineTrimPreviewTransport(session));
  }

  bool _isEquivalentTrimPreviewSession(
    _TimelineTrimPreviewSession? left,
    _TimelineTrimPreviewSession right,
  ) {
    if (left == null) {
      return false;
    }
    return left.clipId == right.clipId &&
        left.previewAssetId == right.previewAssetId &&
        left.sourceUri == right.sourceUri &&
        left.timelinePreviewTime == right.timelinePreviewTime &&
        left.sourcePreviewTime == right.sourcePreviewTime;
  }

  Future<void> _restoreTimelineTransportAfterTrimPreview(int requestId) async {
    if (!_transportController.isPlatformSupported ||
        _isApplyingStructuralEdit) {
      return;
    }
    if (!mounted || requestId != _timelineTrimPreviewRequestId) {
      return;
    }
    await _pausePlayback();
    if (!mounted || requestId != _timelineTrimPreviewRequestId) {
      return;
    }
    await _syncVideoTimelineTransport(
      tracks: _tracks,
      targetTime: _currentTime,
    );
  }

  Future<void> _syncTimelineTrimPreviewTransport(
    _TimelineTrimPreviewSession session,
  ) async {
    if (_isApplyingStructuralEdit ||
        !_transportController.isPlatformSupported ||
        !session.usesTransportPreview) {
      return;
    }
    final sourceUri = session.sourceUri;
    final sourceLabel = session.sourceLabel;
    final sourcePreviewTime = session.sourcePreviewTime;
    if (sourceUri == null || sourceLabel == null || sourcePreviewTime == null) {
      return;
    }
    final requestId = ++_timelineTrimPreviewRequestId;
    final requiresPrepare = _activeTrimPreviewSourceUri != session.sourceUri ||
        _transportController.state.sourceKind != 'imported';
    if (requiresPrepare) {
      await _pausePlayback();
      await _transportController.prepareImportedMedia(
        sourceUri: sourceUri,
        sourceLabel: sourceLabel,
      );
      if (!mounted || requestId != _timelineTrimPreviewRequestId) {
        return;
      }
      _activeTrimPreviewSourceUri = sourceUri;
    }
    await _seekPlaybackTo(sourcePreviewTime);
  }

  _ResolvedTimelineTrimValues _resolveTimelineTrimValues({
    required _SelectedTimelineClipContext context,
    required TimelineTrimEdge edge,
    required TimelineTime sourceStartTime,
    required TimelineTime durationTime,
  }) {
    final assetDurationSeconds = context.asset?.durationSeconds;
    final assetDurationTime = assetDurationSeconds == null
        ? null
        : TimelineTime.fromSecondsDouble(assetDurationSeconds);
    final minDurationTime = _minEditableClipDurationTime;
    final playbackRate =
        context.clip.playbackRate <= 0 ? 1.0 : context.clip.playbackRate;
    final minSourceDurationTime = _sourceDurationForPlaybackRate(
      minDurationTime,
      playbackRate,
    );
    final maxSourceEndTime = assetDurationTime ?? context.clip.sourceEndTime;
    final maxSourceStartTime = maxSourceEndTime - minSourceDurationTime;
    final clipStartTime = context.clipStartTime;
    final clipEndTime = context.clipEndTime;
    final playheadBarrierTime =
        _currentTime >= clipStartTime && _currentTime <= clipEndTime
            ? _currentTime
            : null;
    final barrierOffsetTime = playheadBarrierTime == null
        ? null
        : (playheadBarrierTime - clipStartTime).clamp(
            TimelineTime.zero,
            context.clip.durationTime,
          );
    final barrierOffsetSourceTime = barrierOffsetTime == null
        ? null
        : _sourceDurationForPlaybackRate(barrierOffsetTime, playbackRate).clamp(
            TimelineTime.zero,
            context.clip.sourceDurationTime,
          );
    final safeMaxSourceStartTime = maxSourceStartTime < TimelineTime.zero
        ? TimelineTime.zero
        : maxSourceStartTime;

    TimelineTime safeSourceStartTime;
    TimelineTime safeSourceDurationTime;
    TimelineTime safeDurationTime;

    if (edge == TimelineTrimEdge.start) {
      final barrierMaxSourceStartTime = barrierOffsetTime == null
          ? safeMaxSourceStartTime
          : context.clip.sourceStartTime + barrierOffsetSourceTime!;
      safeSourceStartTime = sourceStartTime.clamp(
        TimelineTime.zero,
        barrierMaxSourceStartTime < TimelineTime.zero
            ? TimelineTime.zero
            : barrierMaxSourceStartTime,
      );
      safeSourceDurationTime = context.clip.sourceEndTime - safeSourceStartTime;
      if (safeSourceDurationTime < minSourceDurationTime) {
        safeSourceDurationTime = minSourceDurationTime;
        safeSourceStartTime =
            context.clip.sourceEndTime - safeSourceDurationTime;
      }
      safeDurationTime = _timelineDurationForPlaybackRate(
        safeSourceDurationTime,
        playbackRate,
      );
    } else {
      safeSourceStartTime = context.clip.sourceStartTime.clamp(
        TimelineTime.zero,
        safeMaxSourceStartTime,
      );
      final maxSourceDurationTime = maxSourceEndTime - safeSourceStartTime;
      final minBarrierSourceDuration = barrierOffsetSourceTime == null ||
              barrierOffsetSourceTime < minSourceDurationTime
          ? minSourceDurationTime
          : barrierOffsetSourceTime;
      final requestedSourceDurationTime = _sourceDurationForPlaybackRate(
        durationTime,
        playbackRate,
      );
      safeSourceDurationTime = requestedSourceDurationTime.clamp(
        minBarrierSourceDuration,
        maxSourceDurationTime < minBarrierSourceDuration
            ? minBarrierSourceDuration
            : maxSourceDurationTime,
      );
      safeDurationTime = _timelineDurationForPlaybackRate(
        safeSourceDurationTime,
        playbackRate,
      );
    }

    return _ResolvedTimelineTrimValues(
      sourceStartTime: safeSourceStartTime,
      sourceDurationTime: safeSourceDurationTime,
      durationTime: safeDurationTime,
      assetDurationTime: assetDurationTime,
    );
  }

  void _applyTimelineTrim({
    required String clipId,
    required TimelineTrimEdge edge,
    required TimelineTime sourceStartTime,
    required TimelineTime durationTime,
  }) {
    if (_isMotionTextElementId(clipId)) {
      _applyMotionTextTimelineTrim(
        clipId: clipId,
        edge: edge,
        sourceStartTime: sourceStartTime,
        durationTime: durationTime,
      );
      return;
    }
    final context = _selectedClipContextForTracks(_tracks, clipId);
    if (context == null || context.asset == null) {
      return;
    }
    final resolvedTrim = _resolveTimelineTrimValues(
      context: context,
      edge: edge,
      sourceStartTime: sourceStartTime,
      durationTime: durationTime,
    );
    final updatedClip = context.clip.copyWith(
      sourceStartTime: resolvedTrim.sourceStartTime,
      sourceDurationTime: resolvedTrim.sourceDurationTime,
      durationTime: resolvedTrim.durationTime,
    );
    final clips = List<TimelineClipData>.from(_tracks[context.trackIndex].clips)
      ..[context.clipIndex] = updatedClip;
    final nextTracks = _replaceTrack(context.trackIndex, clips);
    final nextCurrentTime = _currentTime.clamp(
      TimelineTime.zero,
      _timelineDurationForTracksTime(nextTracks),
    );
    final updatedClipEndTime = context.clipStartTime + updatedClip.durationTime;
    final nextPreviewAssetId = _resolvedPreviewAssetIdForTracks(
      nextTracks,
      preferredAssetId: nextCurrentTime < updatedClipEndTime
          ? (_previewAssetId ?? updatedClip.assetId)
          : null,
      preferredTimelineTime: nextCurrentTime,
    );
    setState(() {
      _tracks = nextTracks;
      _selectedClipId = clipId;
      _setCurrentTime(nextCurrentTime);
      _previewAssetId = nextPreviewAssetId;
    });
    unawaited(
      _commitStructuralTimelineEdit(
        tracks: nextTracks,
        targetTime: nextCurrentTime,
        previewAssetId: nextPreviewAssetId,
      ),
    );
  }

  void _applyMotionTextTimelineTrim({
    required String clipId,
    required TimelineTrimEdge edge,
    required TimelineTime sourceStartTime,
    required TimelineTime durationTime,
  }) {
    final timelineContext = _selectedClipContextForTracks(
      _timelineTruthTracks,
      clipId,
    );
    final motionContext = _motionTextElementContextForId(clipId);
    if (timelineContext == null || motionContext == null) {
      return;
    }
    final resolvedTrim = _resolveTimelineTrimValues(
      context: timelineContext,
      edge: edge,
      sourceStartTime: sourceStartTime,
      durationTime: durationTime,
    );
    final previousProjectRange = _motionTextTimingRangeForElement(
      scene: motionContext.scene,
      element: motionContext.element,
    );
    final nextProjectRange = TimelineTimeRange(
      start: resolvedTrim.sourceStartTime,
      endExclusive: resolvedTrim.sourceStartTime + resolvedTrim.durationTime,
    );
    final nextLocalRange = TimelineTimeRange(
      start: nextProjectRange.start - motionContext.scene.projectRange.start,
      endExclusive: nextProjectRange.endExclusive -
          motionContext.scene.projectRange.start,
    );
    final updatedElement = motionContext.element.copyWith(
      localRange: nextLocalRange,
    );
    final nextElements =
        List<MotionElementModel>.from(motionContext.layer.elements)
          ..[motionContext.elementIndex] = updatedElement;
    final nextLayer = motionContext.layer.copyWith(elements: nextElements);
    final nextLayers = List<MotionLayerModel>.from(motionContext.scene.layers)
      ..[motionContext.layerIndex] = nextLayer;
    final nextScene = motionContext.scene.copyWith(layers: nextLayers);
    final nextScenes = List<MotionSceneModel>.from(motionContext.project.scenes)
      ..[motionContext.sceneIndex] = nextScene;
    final nextProject = motionContext.project.copyWith(scenes: nextScenes);
    final nextBindings = _motionTextAnimationBindings.map((binding) {
      if (binding.elementTarget.targetId != clipId) {
        return binding;
      }
      return MotionTextAnimationBindingModel(
        id: binding.id,
        elementTarget: binding.elementTarget,
        activeRange: nextProjectRange,
        presetId: binding.presetId,
        animationBlocks: binding.animationBlocks,
        parameterValues: binding.parameterValues,
      );
    }).toList(growable: false);
    final nextManualChannels =
        _buildTextMotionKeyframeAuthoringService().retimeChannelsForTarget(
      TextMotionChannelRetimingRequest(
        channels: _manualMotionPropertyChannels,
        targetId: clipId,
        previousRange: previousProjectRange,
        nextRange: nextProjectRange,
      ),
    );
    final resolvedState = _resolveMotionTextTimelineStateForProject(
      project: nextProject,
      preferredTimelineTime: _currentTime,
      preferredSelectedElementId: clipId,
      bindings: nextBindings,
    );

    setState(() {
      _motionProject = nextProject;
      _motionTextAnimationBindings = nextBindings;
      _manualMotionPropertyChannels = nextManualChannels;
      _markMotionAuthoringChanged();
      _selectedClipId = resolvedState.selectedClipId;
      _activeTab = EditorMediaTab.text;
      _previewAssetId = resolvedState.previewAssetId;
      _setCurrentTime(resolvedState.timelineTime);
    });
  }

  void _reorderClip(String clipId, int insertionIndex) {
    final context = _selectedClipContextForTracks(_tracks, clipId);
    if (context == null) {
      return;
    }
    final plan = _buildReorderStructuralEditPlan(context, insertionIndex);
    _applyStructuralEditPlan(plan);
  }

  void _shiftClipInTimeline(String clipId, TimelineTime startTime) {
    final context = _selectedClipContextForTracks(_timelineTruthTracks, clipId);
    if (context == null || context.track.kind == TimelineTrackKind.video) {
      return;
    }
    if (context.track.kind == TimelineTrackKind.text) {
      _shiftMotionTextClipInTimeline(context, startTime);
      return;
    }
    _shiftNonVideoTrackClipInTimeline(context, startTime);
  }

  void _shiftNonVideoTrackClipInTimeline(
    _SelectedTimelineClipContext context,
    TimelineTime requestedStartTime,
  ) {
    if (context.trackIndex < 0 || context.trackIndex >= _tracks.length) {
      return;
    }
    final baseTrack = _tracks[context.trackIndex];
    final positionedClips = _positionedMediaClipsForTrack(baseTrack);
    _PositionedTimelineTrackClip? movingClip;
    final occupiedClips = <_PositionedTimelineTrackClip>[];
    for (final positionedClip in positionedClips) {
      if (positionedClip.clip.id == context.clip.id) {
        movingClip = positionedClip;
      } else {
        occupiedClips.add(positionedClip);
      }
    }
    if (movingClip == null) {
      return;
    }

    final resolvedStartTime = _resolveNearestAllowedClipStartTime(
      occupiedClips: occupiedClips,
      clipDurationTime: movingClip.clip.durationTime,
      candidateStartTime: requestedStartTime,
      timelineUpperBound: _timelineDurationTime,
    );
    final nextPositionedClips = <_PositionedTimelineTrackClip>[
      ...occupiedClips,
      _PositionedTimelineTrackClip(
        clip: movingClip.clip,
        startTime: resolvedStartTime,
      ),
    ]..sort((left, right) => left.startTime.compareTo(right.startTime));
    final nextClips = _buildGappedTrackClipsFromPositionedMediaClips(
      trackKind: baseTrack.kind,
      clips: nextPositionedClips,
      placeholderLabel: baseTrack.placeholderLabel,
    );
    final nextTracks = _replaceTrackIn(_tracks, context.trackIndex, nextClips);
    final nextTimelineDuration = _timelineDurationForTracksTime(nextTracks);
    final preservedTimelineTime = _currentTime.clamp(
      TimelineTime.zero,
      nextTimelineDuration,
    );
    final nextPreviewAssetId = _resolvedPreviewAssetIdForTracks(
      nextTracks,
      preferredTimelineTime: preservedTimelineTime,
    );
    setState(() {
      _tracks = nextTracks;
      _selectedClipId = movingClip!.clip.id;
      _previewAssetId = nextPreviewAssetId;
      _activeTrimClipId = null;
      _timelineTrimPreviewSession = null;
      _activeTrimPreviewSourceUri = null;
      if (preservedTimelineTime != _currentTime) {
        _setCurrentTime(preservedTimelineTime);
      }
    });
  }

  void _shiftMotionTextClipInTimeline(
    _SelectedTimelineClipContext context,
    TimelineTime requestedStartTime,
  ) {
    final motionContext = _motionTextElementContextForId(context.clip.id);
    if (motionContext == null) {
      return;
    }
    final positionedClips = _positionedMediaClipsForTrack(context.track);
    final occupiedClips = <_PositionedTimelineTrackClip>[];
    for (final positionedClip in positionedClips) {
      if (positionedClip.clip.id == context.clip.id) {
        continue;
      }
      occupiedClips.add(positionedClip);
    }
    var resolvedStartTime = _resolveNearestAllowedClipStartTime(
      occupiedClips: occupiedClips,
      clipDurationTime: context.clip.durationTime,
      candidateStartTime: requestedStartTime,
      timelineUpperBound: _timelineDurationTime,
    );
    final maxSceneStart = (motionContext.scene.projectRange.endExclusive -
            context.clip.durationTime)
        .clamp(
      motionContext.scene.projectRange.start,
      motionContext.scene.projectRange.endExclusive,
    );
    resolvedStartTime = resolvedStartTime.clamp(
      motionContext.scene.projectRange.start,
      maxSceneStart,
    );

    final previousProjectRange = _motionTextTimingRangeForElement(
      scene: motionContext.scene,
      element: motionContext.element,
    );
    final nextProjectRange = TimelineTimeRange(
      start: resolvedStartTime,
      endExclusive: resolvedStartTime + context.clip.durationTime,
    );
    final nextLocalRange = TimelineTimeRange(
      start: nextProjectRange.start - motionContext.scene.projectRange.start,
      endExclusive: nextProjectRange.endExclusive -
          motionContext.scene.projectRange.start,
    );
    final updatedElement = motionContext.element.copyWith(
      localRange: nextLocalRange,
    );
    final nextElements =
        List<MotionElementModel>.from(motionContext.layer.elements)
          ..[motionContext.elementIndex] = updatedElement;
    final nextLayer = motionContext.layer.copyWith(
      visibleRange: _resolvedLayerVisibleRangeForElements(
        nextElements,
        fallback: motionContext.layer.visibleRange,
      ),
      elements: nextElements,
    );
    final nextLayers = List<MotionLayerModel>.from(motionContext.scene.layers)
      ..[motionContext.layerIndex] = nextLayer;
    final nextScene = motionContext.scene.copyWith(
      projectRange: _expandedTimeRange(
        motionContext.scene.projectRange,
        nextProjectRange,
      ),
      layers: nextLayers,
    );
    final nextScenes = List<MotionSceneModel>.from(motionContext.project.scenes)
      ..[motionContext.sceneIndex] = nextScene;
    final nextProject = motionContext.project.copyWith(scenes: nextScenes);
    final nextBindings = _motionTextAnimationBindings.map((binding) {
      if (binding.elementTarget.targetId != context.clip.id) {
        return binding;
      }
      return MotionTextAnimationBindingModel(
        id: binding.id,
        elementTarget: binding.elementTarget,
        activeRange: nextProjectRange,
        presetId: binding.presetId,
        animationBlocks: binding.animationBlocks,
        parameterValues: binding.parameterValues,
      );
    }).toList(growable: false);
    final nextManualChannels =
        _buildTextMotionKeyframeAuthoringService().retimeChannelsForTarget(
      TextMotionChannelRetimingRequest(
        channels: _manualMotionPropertyChannels,
        targetId: context.clip.id,
        previousRange: previousProjectRange,
        nextRange: nextProjectRange,
      ),
    );
    final nextDisplayTracks = _displayTracksForProject(
      nextProject,
      bindings: nextBindings,
    );
    final nextTimelineDuration =
        _timelineDurationForTracksTime(nextDisplayTracks);
    final preservedTimelineTime = _currentTime.clamp(
      TimelineTime.zero,
      nextTimelineDuration,
    );
    final nextPreviewAssetId = _resolvedPreviewAssetIdForTracks(
      nextDisplayTracks,
      preferredTimelineTime: preservedTimelineTime,
    );

    final shouldClearPreviewRange =
        _textEditPreviewRange?.elementId == context.clip.id;

    setState(() {
      _motionProject = nextProject;
      _motionTextAnimationBindings = nextBindings;
      _manualMotionPropertyChannels = nextManualChannels;
      _markMotionAuthoringChanged();
      if (shouldClearPreviewRange) {
        _textEditPreviewRange = null;
      }
      _selectedClipId = context.clip.id;
      _activeTab = EditorMediaTab.text;
      _previewAssetId = nextPreviewAssetId;
      if (preservedTimelineTime != _currentTime) {
        _setCurrentTime(preservedTimelineTime);
      }
    });
  }

  TimelineTimeRange _resolvedLayerVisibleRangeForElements(
    List<MotionElementModel> elements, {
    required TimelineTimeRange fallback,
  }) {
    if (elements.isEmpty) {
      return fallback;
    }
    var start = elements.first.localRange.start;
    var endExclusive = elements.first.localRange.endExclusive;
    for (final element in elements.skip(1)) {
      if (element.localRange.start < start) {
        start = element.localRange.start;
      }
      if (element.localRange.endExclusive > endExclusive) {
        endExclusive = element.localRange.endExclusive;
      }
    }
    return TimelineTimeRange(
      start: start,
      endExclusive: endExclusive,
    );
  }

  List<_PositionedTimelineTrackClip> _positionedMediaClipsForTrack(
    TimelineTrackData track,
  ) {
    final positionedClips = <_PositionedTimelineTrackClip>[];
    var cursor = TimelineTime.zero;
    for (final clip in track.clips) {
      final clipStartTime = cursor;
      cursor += clip.durationTime;
      if (clip.type != TimelineClipType.media) {
        continue;
      }
      positionedClips.add(
        _PositionedTimelineTrackClip(
          clip: clip,
          startTime: clipStartTime,
        ),
      );
    }
    return positionedClips;
  }

  TimelineTime _resolveNearestAllowedClipStartTime({
    required List<_PositionedTimelineTrackClip> occupiedClips,
    required TimelineTime clipDurationTime,
    required TimelineTime candidateStartTime,
    required TimelineTime timelineUpperBound,
  }) {
    final maxStartTime = (timelineUpperBound - clipDurationTime).clamp(
      TimelineTime.zero,
      timelineUpperBound,
    );
    final sortedOccupiedClips = List<_PositionedTimelineTrackClip>.from(
      occupiedClips,
    )..sort((left, right) => left.startTime.compareTo(right.startTime));
    final clampedCandidate =
        candidateStartTime.clamp(TimelineTime.zero, maxStartTime);
    final intervals = <_TimelineClipMoveInterval>[];
    var cursor = TimelineTime.zero;
    for (final occupiedClip in sortedOccupiedClips) {
      final intervalEnd = (occupiedClip.startTime - clipDurationTime).clamp(
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
      if (occupiedClip.endTime > cursor) {
        cursor = occupiedClip.endTime;
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

  List<TimelineClipData> _buildGappedTrackClipsFromPositionedMediaClips({
    required TimelineTrackKind trackKind,
    required List<_PositionedTimelineTrackClip> clips,
    String? placeholderLabel,
  }) {
    if (clips.isEmpty) {
      return const <TimelineClipData>[];
    }
    final sortedClips = List<_PositionedTimelineTrackClip>.from(clips)
      ..sort((left, right) => left.startTime.compareTo(right.startTime));
    final rebuiltClips = <TimelineClipData>[];
    var cursor = TimelineTime.zero;
    for (final positionedClip in sortedClips) {
      final gapDuration = positionedClip.startTime - cursor;
      if (gapDuration > TimelineTime.zero) {
        rebuiltClips.add(
          _buildGapPlaceholderClip(
            trackKind: trackKind,
            durationTime: gapDuration,
            placeholderLabel: placeholderLabel,
          ),
        );
      }
      rebuiltClips.add(positionedClip.clip);
      cursor = positionedClip.endTime;
    }
    return List<TimelineClipData>.unmodifiable(rebuiltClips);
  }

  TimelineClipData _buildGapPlaceholderClip({
    required TimelineTrackKind trackKind,
    required TimelineTime durationTime,
    String? placeholderLabel,
  }) {
    return TimelineClipData(
      id: 'gap-${trackKind.name}-${DateTime.now().microsecondsSinceEpoch}-${durationTime.inProjectTicks}',
      type: TimelineClipType.placeholder,
      tone: TimelineClipTone.placeholder,
      durationTime: durationTime,
      label: placeholderLabel == null ? '' : '',
    );
  }

  List<TimelineTrackData> _replaceTrack(
      int index, List<TimelineClipData> clips) {
    final nextTracks = List<TimelineTrackData>.from(_tracks);
    final baseTrack = nextTracks[index];
    nextTracks[index] = baseTrack.copyWith(
      clips: clips,
      transitions: _sanitizeTransitionsForTrack(baseTrack, clips: clips),
    );
    return List<TimelineTrackData>.unmodifiable(nextTracks);
  }

  List<TimelineTrackData> _replaceTrackIn(
    List<TimelineTrackData> tracks,
    int index,
    List<TimelineClipData> clips,
  ) {
    final nextTracks = List<TimelineTrackData>.from(tracks);
    final baseTrack = nextTracks[index];
    nextTracks[index] = baseTrack.copyWith(
      clips: clips,
      transitions: _sanitizeTransitionsForTrack(baseTrack, clips: clips),
    );
    return List<TimelineTrackData>.unmodifiable(nextTracks);
  }

  List<TimelineTrackData> _ensureTrackKind(
    List<TimelineTrackData> tracks,
    TimelineTrackKind kind,
  ) {
    if (tracks.any((track) => track.kind == kind)) {
      return tracks;
    }
    final nextTracks = List<TimelineTrackData>.from(tracks)
      ..add(
        TimelineTrackData(
          kind: kind,
          clips: const <TimelineClipData>[],
        ),
      );
    return List<TimelineTrackData>.unmodifiable(nextTracks);
  }

  void _handleDockTab(EditorMediaTab tab) {
    if (tab == EditorMediaTab.speed) {
      if (!_hasSelectedSpeedEditableClip) {
        _showStageMessage('Select a video clip to edit speed.');
        return;
      }
      setState(() {
        _activeTab = tab;
      });
      unawaited(_openClipSpeedSheet());
      return;
    }
    setState(() {
      _activeTab = tab;
    });
    if (tab == EditorMediaTab.text) {
      _handleTextDockTap();
    }
  }

  void _handleTextDockTap() {
    final selectedTextElementId = _selectedMainTimelineTextElementId;
    if (selectedTextElementId != null) {
      unawaited(_openTextClipEditSheet(selectedTextElementId));
      return;
    }
    if (_textPresetPickerEnabled) {
      unawaited(_openTextPresetSheet());
      return;
    }
    _insertDefaultTextLayer(openEditorOnInsert: true);
  }

  String? get _selectedMainTimelineTextElementId {
    final selectedClipId = _selectedClipId;
    if (selectedClipId == null || !_isMotionTextElementId(selectedClipId)) {
      return null;
    }
    if (_layerScopeSession != null || _transitionFocusSession != null) {
      return null;
    }
    return selectedClipId;
  }

  bool _canOpenAnimateBrowserForTrack(TimelineTrackData track) {
    if (track.kind != TimelineTrackKind.text) {
      return false;
    }
    return track.clips.any((clip) => clip.type == TimelineClipType.media);
  }

  TimelineClipData? _resolveAnimateTargetClipForTrack(TimelineTrackData track) {
    final selectedClipId = _selectedClipId;
    if (selectedClipId != null) {
      for (final clip in track.clips) {
        if (clip.id == selectedClipId && clip.type == TimelineClipType.media) {
          return clip;
        }
      }
    }
    for (final clip in track.clips) {
      if (clip.type == TimelineClipType.media) {
        return clip;
      }
    }
    return null;
  }

  List<double> _mockAnimationKeyframeStopsForItem(AnimateBrowserItem item) {
    switch (item.category) {
      case 'Transform':
        return const <double>[0.0, 0.24, 0.58, 1.0];
      case 'Visual':
        return const <double>[0.0, 0.4, 1.0];
      case 'Effects':
        return const <double>[0.0, 0.18, 0.62, 1.0];
      case 'Text':
        return const <double>[0.0, 0.33, 0.72, 1.0];
      default:
        return const <double>[0.0, 0.52, 1.0];
    }
  }

  List<double> _initialKeyframeValuesForItem(
    AnimateBrowserItem item,
    int keyframeCount,
  ) {
    final defaultValue = item.id == 'opacity' ? 100.0 : 0.0;
    return List<double>.filled(keyframeCount, defaultValue, growable: false);
  }

  String? _addAnimateLaneToTrack(
    TimelineTrackData displayTrack,
    AnimateBrowserItem item, {
    bool selectForLayerScope = false,
  }) {
    final targetClip = _resolveAnimateTargetClipForTrack(displayTrack);
    if (targetClip == null) {
      if (!selectForLayerScope) {
        _showStageMessage('Select a layer clip before adding animation.');
      }
      return null;
    }

    final trackIndex = _tracks.indexWhere(
      (candidate) => candidate.kind == displayTrack.kind,
    );
    if (trackIndex < 0) {
      return null;
    }

    final baseTrack = _tracks[trackIndex];
    TimelineAnimationLaneData? existingLane;
    for (final lane in baseTrack.animationLanes) {
      if (lane.targetClipId == targetClip.id &&
          lane.label.toLowerCase() == item.label.toLowerCase()) {
        existingLane = lane;
        break;
      }
    }
    if (existingLane != null) {
      if (selectForLayerScope) {
        setState(() {
          _selectedLayerScopeAnimationLaneId = existingLane!.id;
          _selectedLayerScopeKeyframeIndex =
              existingLane.normalizedKeyframeStops.isEmpty ? null : 0;
          _selectedLayerScopeKeyframeId =
              existingLane.normalizedKeyframeStops.isEmpty
                  ? null
                  : _layerScopeKeyframeIdAt(existingLane, 0);
          _isLayerScopeValueEditorOpen = false;
          _selectedClipId = targetClip.id;
        });
      } else {
        _showStageMessage('${item.label} already exists on this layer.');
      }
      return existingLane.id;
    }

    final keyframeStops = selectForLayerScope
        ? const <double>[]
        : _mockAnimationKeyframeStopsForItem(item);
    final nextLane = TimelineAnimationLaneData(
      id: 'anim-${displayTrack.kind.name}-${targetClip.id}-${DateTime.now().microsecondsSinceEpoch}',
      label: item.label,
      targetClipId: targetClip.id,
      normalizedKeyframeStops: keyframeStops,
      keyframeValues: selectForLayerScope
          ? const <double>[]
          : _initialKeyframeValuesForItem(
              item,
              keyframeStops.length,
            ),
    );
    final nextAnimationLanes = List<TimelineAnimationLaneData>.unmodifiable(
      <TimelineAnimationLaneData>[
        ...baseTrack.animationLanes,
        nextLane,
      ],
    );
    final nextTracks = List<TimelineTrackData>.from(_tracks);

    setState(() {
      nextTracks[trackIndex] = baseTrack.copyWith(
        animationLanes: nextAnimationLanes,
      );
      _tracks = List<TimelineTrackData>.unmodifiable(nextTracks);
      _selectedClipId = targetClip.id;
      if (selectForLayerScope) {
        _selectedLayerScopeAnimationLaneId = nextLane.id;
        _selectedLayerScopeKeyframeIndex = null;
        _selectedLayerScopeKeyframeId = null;
        _isLayerScopeValueEditorOpen = false;
      }
    });
    return nextLane.id;
  }

  Future<void> _openAnimateBrowserForTrack(TimelineTrackData track) async {
    if (!_canOpenAnimateBrowserForTrack(track)) {
      return;
    }

    setState(() {
      _isAnimateBrowserOpen = true;
    });

    final item = await showModalBottomSheet<AnimateBrowserItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: const AnimateBrowserBottomSheet(
          items: AnimateBrowserBottomSheet.defaultItems,
        ),
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnimateBrowserOpen = false;
      });
    });

    if (item == null || !mounted) {
      return;
    }

    _addAnimateLaneToTrack(track, item);
  }

  Future<void> _handleLayerScopeAnimateTap(TimelineTrackData track) async {
    final scopeContext = _activeLayerScopeContext;
    if (scopeContext == null) {
      _showStageMessage('Open a scoped layer first.');
      return;
    }
    final items = _scopedLayerAnimateItemsForContext(scopeContext);
    if (items.isEmpty) {
      _showStageMessage('Animate controls are not available for this layer.');
      return;
    }
    setState(() {
      _isAnimateBrowserOpen = true;
    });
    final item = await showModalBottomSheet<AnimateBrowserItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScopedLayerAnimateBottomSheet(
        items: items,
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnimateBrowserOpen = false;
      });
    });
    if (item == null || !mounted) {
      return;
    }
    if (_isScopedTextEffectItem(item)) {
      _applyScopedTextEffectToLayer(scopeContext, item);
      return;
    }
    _addAnimateLaneToTrack(
      track,
      item,
      selectForLayerScope: true,
    );
  }

  Future<void> _handleLayerScopeFxTap(TimelineTrackData track) async {
    final scopeContext = _activeLayerScopeContext;
    if (scopeContext == null) {
      _showStageMessage('Open a scoped layer first.');
      return;
    }
    final items = _scopedLayerFxItemsForContext(scopeContext);
    if (items.isEmpty) {
      _showStageMessage('FX controls are not available for this layer yet.');
      return;
    }
    setState(() {
      _isAnimateBrowserOpen = true;
    });
    final item = await showModalBottomSheet<AnimateBrowserItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScopedLayerAnimateBottomSheet(
        items: items,
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnimateBrowserOpen = false;
      });
    });
    if (item == null || !mounted) {
      return;
    }
    _addAnimateLaneToTrack(
      track,
      item,
      selectForLayerScope: true,
    );
  }

  List<AnimateBrowserItem> _scopedLayerAnimateItemsForContext(
    _LayerScopeContext context,
  ) {
    return switch (context.track.kind) {
      TimelineTrackKind.text => _scopedTextAnimateItems,
      TimelineTrackKind.image => _scopedImageAnimateItems,
      TimelineTrackKind.video ||
      TimelineTrackKind.audio ||
      TimelineTrackKind.lipSync =>
        const <AnimateBrowserItem>[],
    };
  }

  List<AnimateBrowserItem> _scopedLayerFxItemsForContext(
    _LayerScopeContext context,
  ) {
    return switch (context.track.kind) {
      TimelineTrackKind.text => _scopedTextFxItems,
      TimelineTrackKind.image => _scopedImageFxItems,
      TimelineTrackKind.video ||
      TimelineTrackKind.audio ||
      TimelineTrackKind.lipSync =>
        const <AnimateBrowserItem>[],
    };
  }

  bool _isScopedTextEffectItem(AnimateBrowserItem item) =>
      item.id.startsWith('text_effect.');

  void _applyScopedTextEffectToLayer(
    _LayerScopeContext scopeContext,
    AnimateBrowserItem item,
  ) {
    if (scopeContext.track.kind != TimelineTrackKind.text) {
      _showStageMessage('Text effects are available for text layers only.');
      return;
    }
    final textContext = _motionTextElementContextForId(scopeContext.clip.id);
    if (textContext == null) {
      _showStageMessage('Unable to resolve this text layer.');
      return;
    }
    final blocks = _scopedTextEffectBlocksForItem(
      item,
      layerDuration: scopeContext.durationTime,
    );
    if (blocks.isEmpty) {
      _showStageMessage('${item.label} is not ready yet.');
      return;
    }

    final blockPrefix = _scopedTextEffectBlockPrefix(item);
    final isRevealEffect = _isScopedTextRevealEffectItem(item);
    final currentBinding =
        _motionTextBindingForElementId(textContext.element.id);
    final activeRange = _motionTextTimingRangeForElement(
      scene: textContext.scene,
      element: textContext.element,
    );
    final currentBlocks =
        currentBinding?.animationBlocks ?? const <MotionTextAnimationBlock>[];
    final alreadyApplied = isRevealEffect
        ? currentBlocks.any(_isMotionTextRevealBlock)
        : currentBlocks.any(
            (block) => block.id.startsWith(blockPrefix),
          );

    final nextBindings = <MotionTextAnimationBindingModel>[
      for (final binding in _motionTextAnimationBindings)
        if (binding.elementTarget.targetId == textContext.element.id)
          MotionTextAnimationBindingModel(
            id: binding.id,
            elementTarget: binding.elementTarget,
            activeRange: binding.activeRange,
            presetId: binding.presetId,
            animationBlocks: alreadyApplied && !isRevealEffect
                ? binding.animationBlocks
                : <MotionTextAnimationBlock>[
                    for (final block in binding.animationBlocks)
                      if (isRevealEffect
                          ? !_isMotionTextRevealBlock(block)
                          : !block.id.startsWith(blockPrefix))
                        block,
                    ...blocks,
                  ],
            parameterValues: isRevealEffect
                ? <String, MotionPropertyValue>{
                    ...binding.parameterValues,
                    'revealBy':
                        _defaultRevealByParameterForScopedTextEffectItem(item),
                    'revealDirection': binding
                            .parameterValues['revealDirection'] ??
                        _defaultRevealDirectionParameterForScopedTextEffectItem(
                          item,
                        ),
                  }
                : binding.parameterValues,
          )
        else
          binding,
      if (currentBinding == null)
        MotionTextAnimationBindingModel(
          id: 'text-binding-${textContext.element.id}-${DateTime.now().microsecondsSinceEpoch}',
          elementTarget: textContext.elementTarget,
          activeRange: activeRange,
          animationBlocks: blocks,
          parameterValues: isRevealEffect
              ? <String, MotionPropertyValue>{
                  'revealBy':
                      _defaultRevealByParameterForScopedTextEffectItem(item),
                  'revealDirection':
                      _defaultRevealDirectionParameterForScopedTextEffectItem(
                    item,
                  ),
                }
              : const <String, MotionPropertyValue>{},
        ),
    ];

    final trackIndex = _tracks.indexWhere(
      (candidate) => candidate.kind == scopeContext.track.kind,
    );
    var selectedLaneId = _selectedLayerScopeAnimationLaneId;
    List<TimelineTrackData>? nextTracks;
    if (trackIndex >= 0) {
      final baseTrack = _tracks[trackIndex];
      if (isRevealEffect) {
        final existingRevealLane = baseTrack.animationLanes.where(
          (lane) =>
              lane.targetClipId == scopeContext.clip.id &&
              _layerScopeLaneMatchesReveal(lane),
        );
        final seedLane =
            existingRevealLane.isEmpty ? null : existingRevealLane.first;
        final lane = (seedLane ??
                TimelineAnimationLaneData(
                  id: 'anim-${scopeContext.track.kind.name}-${scopeContext.clip.id}-${item.id}-${DateTime.now().microsecondsSinceEpoch}',
                  label: item.label,
                  targetClipId: scopeContext.clip.id,
                  normalizedKeyframeStops: const <double>[],
                  keyframeValues: const <double>[],
                ))
            .copyWith(
          label: item.label,
          targetClipId: scopeContext.clip.id,
        );
        selectedLaneId = lane.id;
        nextTracks = List<TimelineTrackData>.from(_tracks);
        nextTracks[trackIndex] = baseTrack.copyWith(
          animationLanes: <TimelineAnimationLaneData>[
            for (final existing in baseTrack.animationLanes)
              if (!(existing.targetClipId == scopeContext.clip.id &&
                  _layerScopeLaneMatchesReveal(existing)))
                existing,
            lane,
          ],
        );
      } else {
        final existingLaneIndex = baseTrack.animationLanes.indexWhere(
          (lane) =>
              lane.targetClipId == scopeContext.clip.id &&
              lane.label.toLowerCase() == item.label.toLowerCase(),
        );
        if (existingLaneIndex >= 0) {
          selectedLaneId = baseTrack.animationLanes[existingLaneIndex].id;
        } else {
          final lane = TimelineAnimationLaneData(
            id: 'anim-${scopeContext.track.kind.name}-${scopeContext.clip.id}-${item.id}-${DateTime.now().microsecondsSinceEpoch}',
            label: item.label,
            targetClipId: scopeContext.clip.id,
            normalizedKeyframeStops: const <double>[],
            keyframeValues: const <double>[],
          );
          selectedLaneId = lane.id;
          nextTracks = List<TimelineTrackData>.from(_tracks);
          nextTracks[trackIndex] = baseTrack.copyWith(
            animationLanes: <TimelineAnimationLaneData>[
              ...baseTrack.animationLanes,
              lane,
            ],
          );
        }
      }
    }

    setState(() {
      if (nextTracks != null) {
        _tracks = List<TimelineTrackData>.unmodifiable(nextTracks);
      }
      _motionTextAnimationBindings = nextBindings;
      if (!alreadyApplied || isRevealEffect || currentBinding == null) {
        _markMotionAuthoringChanged();
      }
      _selectedClipId = scopeContext.clip.id;
      _selectedLayerScopeAnimationLaneId = selectedLaneId;
      _selectedLayerScopeKeyframeIndex = null;
      _selectedLayerScopeKeyframeId = null;
      _isLayerScopeValueEditorOpen = false;
      _activeTab = EditorMediaTab.text;
    });
  }

  String _scopedTextEffectBlockPrefix(AnimateBrowserItem item) =>
      'scoped.${item.id}.';

  List<MotionTextAnimationBlock> _scopedTextEffectBlocksForItem(
    AnimateBrowserItem item, {
    TimelineTime? layerDuration,
  }) {
    final prefix = _scopedTextEffectBlockPrefix(item);
    final revealRange = TimelineTimeRange(
      start: TimelineTime.zero,
      endExclusive: layerDuration == null || layerDuration <= TimelineTime.zero
          ? TimelineTime.fromMilliseconds(1100)
          : layerDuration,
    );
    return switch (item.id) {
      'text_effect.type_on' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}typewriter',
            kind: MotionTextAnimationKind.typewriter,
            relativeRange: revealRange,
            revealSpec: MotionTextRevealSpec(
              unit: MotionTextRevealUnit.letter,
              stagger: TimelineTime.fromMilliseconds(42),
            ),
            interpolation: const MotionInterpolationSpec.linear(),
            parameters: const <String, MotionPropertyValue>{
              'manualRevealProgress': MotionPropertyValue.boolean(true),
            },
          ),
        ],
      'text_effect.word_reveal' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}word_reveal',
            kind: MotionTextAnimationKind.wordReveal,
            relativeRange: revealRange,
            revealSpec: MotionTextRevealSpec(
              unit: MotionTextRevealUnit.word,
              stagger: TimelineTime.fromMilliseconds(90),
            ),
            interpolation: const MotionInterpolationSpec.easeOut(),
            parameters: const <String, MotionPropertyValue>{
              'manualRevealProgress': MotionPropertyValue.boolean(true),
            },
          ),
        ],
      'text_effect.letter_reveal' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}letter_reveal',
            kind: MotionTextAnimationKind.letterReveal,
            relativeRange: revealRange,
            revealSpec: MotionTextRevealSpec(
              unit: MotionTextRevealUnit.letter,
              stagger: TimelineTime.fromMilliseconds(36),
            ),
            interpolation: const MotionInterpolationSpec.easeOut(),
            parameters: const <String, MotionPropertyValue>{
              'manualRevealProgress': MotionPropertyValue.boolean(true),
            },
          ),
        ],
      'text_effect.bounce_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}bounce_in',
            kind: MotionTextAnimationKind.bounceIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(760),
            ),
            interpolation: const MotionInterpolationSpec.bounce(
              bounce: MotionBounceSpec(
                amplitude: 0.24,
                bounces: 3,
                decay: 6.5,
              ),
            ),
            parameters: const <String, MotionPropertyValue>{
              'fromScale': MotionPropertyValue.scalar(0.68),
              'toScale': MotionPropertyValue.scalar(1.0),
              'fromOffsetY': MotionPropertyValue.scalar(56),
              'toOffsetY': MotionPropertyValue.scalar(0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.rise_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}rise_in',
            kind: MotionTextAnimationKind.riseIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(680),
            ),
            interpolation: const MotionInterpolationSpec.spring(
              spring: MotionSpringSpec(
                stiffness: 210,
                damping: 22,
                mass: 1.0,
                initialVelocity: 0,
              ),
            ),
            parameters: const <String, MotionPropertyValue>{
              'fromOffsetY': MotionPropertyValue.scalar(52),
              'toOffsetY': MotionPropertyValue.scalar(0),
              'fromScale': MotionPropertyValue.scalar(0.96),
              'toScale': MotionPropertyValue.scalar(1.0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.slide_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}slide_in',
            kind: MotionTextAnimationKind.slideIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(720),
            ),
            interpolation: const MotionInterpolationSpec.spring(
              spring: MotionSpringSpec(
                stiffness: 230,
                damping: 24,
                mass: 1.0,
                initialVelocity: 0,
              ),
            ),
            parameters: const <String, MotionPropertyValue>{
              'fromOffsetX': MotionPropertyValue.scalar(-180),
              'toOffsetX': MotionPropertyValue.scalar(0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.word_rise_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}word_rise_in',
            kind: MotionTextAnimationKind.wordRiseIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(760),
            ),
            revealSpec: MotionTextRevealSpec(
              unit: MotionTextRevealUnit.word,
              stagger: TimelineTime.fromMilliseconds(90),
            ),
            interpolation: const MotionInterpolationSpec.easeOut(),
            parameters: const <String, MotionPropertyValue>{
              'fromOffsetY': MotionPropertyValue.scalar(30),
              'toOffsetY': MotionPropertyValue.scalar(0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.letter_pop_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}letter_pop_in',
            kind: MotionTextAnimationKind.letterPopIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(720),
            ),
            revealSpec: MotionTextRevealSpec(
              unit: MotionTextRevealUnit.letter,
              stagger: TimelineTime.fromMilliseconds(34),
            ),
            interpolation: const MotionInterpolationSpec.easeOut(),
            parameters: const <String, MotionPropertyValue>{
              'fromScale': MotionPropertyValue.scalar(0.92),
              'toScale': MotionPropertyValue.scalar(1.0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.word_cascade' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}word_cascade',
            kind: MotionTextAnimationKind.wordCascade,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(920),
            ),
            revealSpec: MotionTextRevealSpec(
              unit: MotionTextRevealUnit.word,
              stagger: TimelineTime.fromMilliseconds(72),
            ),
            interpolation: const MotionInterpolationSpec.easeOut(),
            parameters: const <String, MotionPropertyValue>{
              'fromOffsetY': MotionPropertyValue.scalar(38),
              'toOffsetY': MotionPropertyValue.scalar(0),
              'fromBlur': MotionPropertyValue.scalar(8),
              'toBlur': MotionPropertyValue.scalar(0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.letter_bounce' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}letter_bounce',
            kind: MotionTextAnimationKind.letterBounce,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(820),
            ),
            revealSpec: MotionTextRevealSpec(
              unit: MotionTextRevealUnit.letter,
              stagger: TimelineTime.fromMilliseconds(42),
            ),
            interpolation: const MotionInterpolationSpec.bounce(
              bounce: MotionBounceSpec(
                amplitude: 0.22,
                bounces: 3,
                decay: 7.0,
              ),
            ),
            parameters: const <String, MotionPropertyValue>{
              'fromScale': MotionPropertyValue.scalar(0.62),
              'toScale': MotionPropertyValue.scalar(1.0),
              'fromOffsetY': MotionPropertyValue.scalar(42),
              'toOffsetY': MotionPropertyValue.scalar(0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.slide_blur_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}slide_blur_in',
            kind: MotionTextAnimationKind.slideBlurIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(780),
            ),
            interpolation: const MotionInterpolationSpec.spring(
              spring: MotionSpringSpec(
                stiffness: 220,
                damping: 24,
                mass: 1.0,
                initialVelocity: 0,
              ),
            ),
            parameters: const <String, MotionPropertyValue>{
              'fromOffsetX': MotionPropertyValue.scalar(-160),
              'toOffsetX': MotionPropertyValue.scalar(0),
              'fromBlur': MotionPropertyValue.scalar(14),
              'toBlur': MotionPropertyValue.scalar(0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.blur_rise_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}blur_rise_in',
            kind: MotionTextAnimationKind.blurRiseIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(760),
            ),
            interpolation: const MotionInterpolationSpec.spring(
              spring: MotionSpringSpec(
                stiffness: 205,
                damping: 22,
                mass: 1.0,
                initialVelocity: 0,
              ),
            ),
            parameters: const <String, MotionPropertyValue>{
              'fromBlur': MotionPropertyValue.scalar(18),
              'toBlur': MotionPropertyValue.scalar(0),
              'fromOffsetY': MotionPropertyValue.scalar(44),
              'toOffsetY': MotionPropertyValue.scalar(0),
              'fromScale': MotionPropertyValue.scalar(0.98),
              'toScale': MotionPropertyValue.scalar(1.0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.rotate_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}rotate_in',
            kind: MotionTextAnimationKind.rotateIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(720),
            ),
            interpolation: const MotionInterpolationSpec.spring(
              spring: MotionSpringSpec(
                stiffness: 250,
                damping: 20,
                mass: 1.0,
                initialVelocity: 0,
              ),
            ),
            parameters: const <String, MotionPropertyValue>{
              'fromRotation': MotionPropertyValue.scalar(-12),
              'toRotation': MotionPropertyValue.scalar(0),
              'fromScale': MotionPropertyValue.scalar(0.88),
              'toScale': MotionPropertyValue.scalar(1.0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.blur_in' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}blur_in',
            kind: MotionTextAnimationKind.blurIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(760),
            ),
            interpolation: const MotionInterpolationSpec.easeOut(),
            parameters: const <String, MotionPropertyValue>{
              'fromBlur': MotionPropertyValue.scalar(24),
              'toBlur': MotionPropertyValue.scalar(0),
            },
          ),
          MotionTextAnimationBlock(
            id: '${prefix}fade_in',
            kind: MotionTextAnimationKind.fadeIn,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(340),
            ),
            interpolation: const MotionInterpolationSpec.easeOut(),
          ),
        ],
      'text_effect.blur_out' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}blur_out',
            kind: MotionTextAnimationKind.blurOut,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(620),
            ),
            interpolation: const MotionInterpolationSpec.easeInOut(),
            parameters: const <String, MotionPropertyValue>{
              'fromBlur': MotionPropertyValue.scalar(0),
              'toBlur': MotionPropertyValue.scalar(22),
            },
          ),
          MotionTextAnimationBlock(
            id: '${prefix}fade_out',
            kind: MotionTextAnimationKind.fadeOut,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.fromMilliseconds(120),
              endExclusive: TimelineTime.fromMilliseconds(620),
            ),
            interpolation: const MotionInterpolationSpec.easeOut(),
          ),
        ],
      'text_effect.scale_pop' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}scale_pop',
            kind: MotionTextAnimationKind.elasticPop,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(720),
            ),
            interpolation: const MotionInterpolationSpec.elastic(
              elastic: MotionElasticSpec(
                amplitude: 0.16,
                period: 0.30,
                decay: 7.2,
              ),
            ),
            parameters: const <String, MotionPropertyValue>{
              'fromScale': MotionPropertyValue.scalar(0.72),
              'toScale': MotionPropertyValue.scalar(1.0),
              'fromOpacity': MotionPropertyValue.scalar(0),
              'toOpacity': MotionPropertyValue.scalar(1),
            },
          ),
        ],
      'text_effect.tracking_settle' => <MotionTextAnimationBlock>[
          MotionTextAnimationBlock(
            id: '${prefix}tracking_settle',
            kind: MotionTextAnimationKind.rotationSettle,
            relativeRange: TimelineTimeRange(
              start: TimelineTime.zero,
              endExclusive: TimelineTime.fromMilliseconds(920),
            ),
            interpolation: const MotionInterpolationSpec.easeInOut(),
            parameters: const <String, MotionPropertyValue>{
              'fromLetterSpacing': MotionPropertyValue.scalar(26),
              'toLetterSpacing': MotionPropertyValue.scalar(0),
              'fromRotation': MotionPropertyValue.scalar(0),
              'toRotation': MotionPropertyValue.scalar(0),
            },
          ),
        ],
      _ => const <MotionTextAnimationBlock>[],
    };
  }

  Future<void> _openMediaSheet(EditorMediaTab tab) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MediaBottomSheet(
          initialTab: tab == EditorMediaTab.image
              ? EditorMediaTab.image
              : EditorMediaTab.video,
          assetsListenable: _assetLibrary,
          loadingListenable: _assetLibraryLoading,
          errorListenable: _assetLibraryError,
          onTabRequested: _refreshAssetsForTab,
          onLoadMoreRequested: _loadMoreAssetsForTab,
          onAssetAdd: (asset) async {
            Navigator.of(context).pop();
            await _addAssetToTimeline(asset);
          },
          thumbnailBatchLoader: _loadAssetThumbnailBatch,
        );
      },
    );
  }

  Future<void> _openTextPresetSheet() async {
    final preset = await showModalBottomSheet<MotionTextPresetDefinition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TextPresetBottomSheet(
        builtInPresets: MotionBuiltInTextPresets.all,
        customPresets: _customTextPresets,
        onPresetImported: _registerCustomTextPreset,
      ),
    );
    if (!mounted || preset == null) {
      return;
    }
    _insertTextPreset(preset);
  }

  void _insertDefaultTextLayer({bool openEditorOnInsert = false}) {
    _insertMotionTextLayer(
      text: _defaultInsertedTextValue,
      elementName: _defaultInsertedTextValue,
      initialFontSize: _defaultInsertedTextFontSize,
      failureMessage: 'Unable to insert text right now.',
      openEditorOnInsert: openEditorOnInsert,
    );
  }

  ClipSpeedDraft? _buildSelectedClipSpeedDraft() {
    final context = _selectedClipContext;
    if (!_hasSelectedSpeedEditableClip || context == null) {
      return null;
    }
    return ClipSpeedDraft(
      clipId: context.clip.id,
      speedMode: context.clip.speedMode,
      playbackRate: context.clip.playbackRate,
      sourceDurationTime: context.clip.sourceDurationTime,
    );
  }

  TimelineTime _timelineDurationForPlaybackRate(
    TimelineTime sourceDurationTime,
    double playbackRate,
  ) {
    final safeRate = playbackRate <= 0 ? 1.0 : playbackRate;
    return TimelineTime.fromSecondsDouble(
      sourceDurationTime.inSecondsDouble / safeRate,
    );
  }

  TimelineTime _sourceDurationForPlaybackRate(
    TimelineTime timelineDurationTime,
    double playbackRate,
  ) {
    final safeRate = playbackRate <= 0 ? 1.0 : playbackRate;
    return TimelineTime.fromSecondsDouble(
      timelineDurationTime.inSecondsDouble * safeRate,
    );
  }

  List<TimelineTrackData> _tracksWithAppliedClipSpeedDraft(
    ClipSpeedDraft draft,
  ) {
    final context = _selectedClipContextForTracks(_tracks, draft.clipId);
    if (context == null ||
        context.track.kind != TimelineTrackKind.video ||
        context.clip.type != TimelineClipType.media) {
      return _tracks;
    }
    final nextTimelineDuration = _timelineDurationForPlaybackRate(
      context.clip.sourceDurationTime,
      draft.playbackRate,
    );
    final updatedClip = context.clip.copyWith(
      speedMode: draft.speedMode,
      playbackRate: draft.playbackRate,
      durationTime: nextTimelineDuration,
      sourceDurationTime: context.clip.sourceDurationTime,
    );
    final clips = List<TimelineClipData>.from(_tracks[context.trackIndex].clips)
      ..[context.clipIndex] = updatedClip;
    return _replaceTrack(context.trackIndex, clips);
  }

  Future<void> _previewClipSpeedDraft(ClipSpeedDraft draft) async {
    final nextTracks = _tracksWithAppliedClipSpeedDraft(draft);
    final previewContext =
        _selectedClipContextForTracks(nextTracks, draft.clipId);
    if (previewContext == null || !_useNativePreview) {
      return;
    }
    final previewStartTime = previewContext.clipStartTime;
    _setTimelineDisplayTime(previewStartTime);
    setState(() {
      _previewAssetId = previewContext.clip.assetId;
      _selectedClipId = draft.clipId;
      _activeTab = EditorMediaTab.speed;
      _currentTime = previewStartTime;
      _playbackSampleTimeNotifier.value = previewStartTime;
    });
    await _pausePlayback();
    await _syncVideoTimelineTransport(
      tracks: nextTracks,
      targetTime: previewStartTime,
    );
    if (!mounted) {
      return;
    }
    _prepareMotionPreviewForPlaybackStart(time: previewStartTime);
    await _playPlaybackFrom(previewStartTime);
  }

  Future<void> _openClipSpeedSheet() async {
    final draft = _buildSelectedClipSpeedDraft();
    if (draft == null) {
      return;
    }
    final result = await showModalBottomSheet<ClipSpeedDraft>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipSpeedBottomSheet(
        initialDraft: draft,
        onPreviewRequested: _previewClipSpeedDraft,
      ),
    );
    if (!mounted) {
      return;
    }
    if (result == null) {
      if (_useNativePreview) {
        await _pausePlayback();
        await _syncVideoTimelineTransport(
          tracks: _tracks,
          targetTime: _currentTime,
        );
      }
      return;
    }
    await _applySelectedClipSpeedDraft(result);
  }

  Future<void> _applySelectedClipSpeedDraft(ClipSpeedDraft draft) async {
    final context = _selectedClipContextForTracks(_tracks, draft.clipId);
    if (context == null ||
        context.track.kind != TimelineTrackKind.video ||
        context.clip.type != TimelineClipType.media) {
      return;
    }
    final nextTimelineDuration = _timelineDurationForPlaybackRate(
      context.clip.sourceDurationTime,
      draft.playbackRate,
    );
    final updatedClip = context.clip.copyWith(
      speedMode: draft.speedMode,
      playbackRate: draft.playbackRate,
      durationTime: nextTimelineDuration,
      sourceDurationTime: context.clip.sourceDurationTime,
    );
    final clips = List<TimelineClipData>.from(_tracks[context.trackIndex].clips)
      ..[context.clipIndex] = updatedClip;
    final nextTracks = _replaceTrack(context.trackIndex, clips);
    final nextContext =
        _selectedClipContextForTracks(nextTracks, updatedClip.id);
    final nextCurrentTime = (nextContext?.clipStartTime ?? _currentTime).clamp(
      TimelineTime.zero,
      _timelineDurationForTracksTime(nextTracks),
    );
    final nextPreviewAssetId = _resolvedPreviewAssetIdForTracks(
      nextTracks,
      preferredAssetId: updatedClip.assetId,
      preferredTimelineTime: nextCurrentTime,
    );
    setState(() {
      _tracks = nextTracks;
      _selectedClipId = updatedClip.id;
      _activeTab = EditorMediaTab.speed;
      _previewAssetId = nextPreviewAssetId;
      _currentTime = nextCurrentTime;
      _playbackSampleTimeNotifier.value = nextCurrentTime;
    });
    _setTimelineDisplayTime(nextCurrentTime);
    await _commitStructuralTimelineEdit(
      tracks: nextTracks,
      targetTime: nextCurrentTime,
      previewAssetId: nextPreviewAssetId,
    );
  }

  // ignore: unused_element
  Future<void> _openTextClipEditSheet(String elementId) async {
    if (_textEditSession?.elementId == elementId) {
      return;
    }
    final draft = _buildTextClipEditDraft(elementId);
    final project = _motionProject;
    if (draft == null || project == null) {
      _showStageMessage('Unable to open this text clip for editing.');
      return;
    }
    final nextTimelineTime =
        _timelineTimeForMotionTextSelection(elementId) ?? _currentTime;
    final nextPreviewAssetId = _previewAssetIdForTimelineTime(nextTimelineTime);
    _clearTextEditPreviewRange(pauseTransport: true);
    setState(() {
      _selectedClipId = elementId;
      _activeTab = EditorMediaTab.text;
      _previewAssetId = nextPreviewAssetId;
      _setCurrentTime(nextTimelineTime);
      _textEditSession = _ActiveTextEditSession(
        elementId: elementId,
        originalProject: project,
        originalBindings: _motionTextAnimationBindings,
        draft: draft,
      );
    });
  }

  TextClipEditDraft? _buildTextClipEditDraft(String elementId) {
    final context = _motionTextElementContextForId(elementId);
    if (context == null) {
      return null;
    }
    final binding = _motionTextBindingForElementId(elementId);
    final preset = _textPresetForBinding(binding);
    final metadata = context.element.sourceBinding?.metadata;
    final textValue = metadata?['text'] ??
        context.element.sourceBinding?.label ??
        context.element.name ??
        preset?.defaultText ??
        'Text';
    final parameters = <TextClipEditableParameter>[
      for (final parameter in preset?.parameters ??
          const <MotionTextPresetParameterDefinition>[])
        if (parameter.defaultValue.kind == MotionPropertyValueKind.scalar)
          TextClipEditableParameter(
            id: parameter.id,
            label: parameter.label,
            value: _bindingScalarParameter(binding, parameter.id) ??
                parameter.defaultValue.rawValue as double,
            minValue: parameter.minValue ?? 0,
            maxValue: parameter.maxValue ?? _fallbackParameterMax(parameter),
            description: parameter.description,
          ),
    ];

    return TextClipEditDraft(
      elementId: elementId,
      text: textValue,
      fontSize: _elementScalarPropertyOrDefault(
        context.element,
        MotionPropertyCatalog.fontSize,
      ),
      parameters: parameters,
    );
  }

  double _fallbackParameterMax(
    MotionTextPresetParameterDefinition parameter,
  ) {
    if (parameter.defaultValue.kind != MotionPropertyValueKind.scalar) {
      return 100;
    }
    final raw = parameter.defaultValue.rawValue as double;
    if (raw <= 0) {
      return 100;
    }
    return raw * 2;
  }

  void _handleTextEditDraftChanged(TextClipEditDraft draft) {
    final session = _textEditSession;
    if (session == null || session.elementId != draft.elementId) {
      return;
    }
    final context = _motionTextElementContextForId(draft.elementId);
    if (context == null) {
      _showStageMessage('This text clip is no longer available.');
      return;
    }
    final nextProject = _updatedProjectForTextElement(
      context,
      text: draft.text,
      scalarProperties: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.fontSize: draft.fontSize,
      },
    );
    final nextBindings = _bindingsWithTextEditDraft(
      draft: draft,
      currentBindings: _motionTextAnimationBindings,
    );
    setState(() {
      _motionProject = nextProject;
      _motionTextAnimationBindings = nextBindings;
      _textEditSession = session.copyWith(draft: draft);
      _markMotionAuthoringChanged();
      _selectedClipId = draft.elementId;
      _activeTab = EditorMediaTab.text;
    });
  }

  void _commitTextEditSession(TextClipEditDraft draft) {
    _handleTextEditDraftChanged(draft);
    _clearTextEditPreviewRange(pauseTransport: true);
    setState(() {
      _textEditSession = null;
      _selectedClipId = draft.elementId;
      _activeTab = EditorMediaTab.text;
    });
  }

  void _cancelTextEditSession() {
    final session = _textEditSession;
    if (session == null) {
      return;
    }
    _clearTextEditPreviewRange(pauseTransport: true);
    setState(() {
      _motionProject = session.originalProject;
      _motionTextAnimationBindings = session.originalBindings;
      _textEditSession = null;
      _markMotionAuthoringChanged();
      _selectedClipId = session.elementId;
      _activeTab = EditorMediaTab.text;
    });
  }

  List<MotionTextAnimationBindingModel> _bindingsWithTextEditDraft({
    required TextClipEditDraft draft,
    required List<MotionTextAnimationBindingModel> currentBindings,
  }) {
    return currentBindings.map((binding) {
      if (binding.elementTarget.targetId != draft.elementId) {
        return binding;
      }
      final nextParameterValues = <String, MotionPropertyValue>{
        ...binding.parameterValues,
        for (final parameter in draft.parameters)
          parameter.id: MotionPropertyValue.scalar(parameter.value),
      };
      return MotionTextAnimationBindingModel(
        id: binding.id,
        elementTarget: binding.elementTarget,
        activeRange: binding.activeRange,
        presetId: binding.presetId,
        animationBlocks: binding.animationBlocks,
        parameterValues: nextParameterValues,
      );
    }).toList(growable: false);
  }

  MotionProjectModel _updatedProjectForTextElement(
    _MotionTextElementContext context, {
    String? text,
    Map<MotionPropertyDefinition, double> scalarProperties =
        const <MotionPropertyDefinition, double>{},
  }) {
    final nextSourceBinding = _updatedTextSourceBinding(
      context,
      text: text,
    );
    final nextProperties = _updatedTextElementProperties(
      context,
      scalarProperties: scalarProperties,
    );
    final updatedElement = context.element.copyWith(
      name: text ?? context.element.name,
      sourceBinding: nextSourceBinding,
      properties: nextProperties,
    );
    final updatedElements =
        List<MotionElementModel>.from(context.layer.elements)
          ..[context.elementIndex] = updatedElement;
    final updatedLayer = context.layer.copyWith(elements: updatedElements);
    final updatedLayers = List<MotionLayerModel>.from(context.scene.layers)
      ..[context.layerIndex] = updatedLayer;
    final updatedScene = context.scene.copyWith(layers: updatedLayers);
    final updatedScenes = List<MotionSceneModel>.from(context.project.scenes)
      ..[context.sceneIndex] = updatedScene;
    return context.project.copyWith(scenes: updatedScenes);
  }

  MotionElementSourceBinding _updatedTextSourceBinding(
    _MotionTextElementContext context, {
    String? text,
  }) {
    final currentBinding = context.element.sourceBinding;
    final metadata = <String, String>{
      ...?currentBinding?.metadata,
    };
    if (text != null) {
      metadata['text'] = text;
    }
    return MotionElementSourceBinding(
      kind: currentBinding?.kind ?? MotionSourceKind.generatedText,
      sourceId:
          currentBinding?.sourceId ?? 'generated-text:${context.element.id}',
      assetId: currentBinding?.assetId,
      label: text ?? currentBinding?.label,
      sourceRange: currentBinding?.sourceRange,
      metadata: metadata,
    );
  }

  List<MotionPropertyAssignment> _updatedTextElementProperties(
    _MotionTextElementContext context, {
    Map<MotionPropertyDefinition, double> scalarProperties =
        const <MotionPropertyDefinition, double>{},
  }) {
    final properties = List<MotionPropertyAssignment>.from(
      context.element.properties,
    );
    final target = context.elementTarget;

    for (final entry in scalarProperties.entries) {
      final nextAssignment = MotionPropertyAssignment(
        target: target,
        definition: entry.key,
        value: MotionPropertyValue.scalar(entry.value),
      );
      final propertyIndex = properties.indexWhere(
        (property) => property.definition.id == entry.key.id,
      );
      if (propertyIndex >= 0) {
        properties[propertyIndex] = nextAssignment;
      } else {
        properties.add(nextAssignment);
      }
    }

    return List<MotionPropertyAssignment>.unmodifiable(properties);
  }

  void _insertTextPreset(MotionTextPresetDefinition preset) {
    _insertMotionTextLayer(
      presetId: preset.id,
      text: preset.defaultText,
      elementName: preset.label,
      failureMessage: 'Unable to insert text preset right now.',
      openEditorOnInsert: true,
    );
  }

  void _insertMotionTextLayer({
    String? presetId,
    required String text,
    required String elementName,
    double? initialFontSize,
    required String failureMessage,
    bool openEditorOnInsert = false,
  }) {
    final insertionRange = _defaultTextPresetRange();
    final insertionStartTime = insertionRange.start;
    final insertionResult = _buildMotionTextAuthoringService().insertTextPreset(
      MotionTextElementInsertionRequest(
        project: _effectiveMotionProject,
        sceneId: _motionSceneId,
        projectRange: insertionRange,
        presetId: presetId,
        text: text,
        elementName: elementName,
        elementProperties: initialFontSize == null
            ? const <MotionPropertyAssignment>[]
            : <MotionPropertyAssignment>[
                MotionPropertyAssignment(
                  target: const MotionPropertyTarget(
                    kind: MotionTargetKind.element,
                    targetId: '__pending__',
                  ),
                  definition: MotionPropertyCatalog.fontSize,
                  value: MotionPropertyValue.scalar(initialFontSize),
                ),
              ],
      ),
    );

    if (!insertionResult.didApply) {
      _showStageMessage(failureMessage);
      return;
    }

    final nextBindings = <MotionTextAnimationBindingModel>[
      ..._motionTextAnimationBindings,
      ...insertionResult.generatedBindings,
    ];
    final resolvedState = _resolveMotionTextTimelineStateForProject(
      project: insertionResult.project,
      preferredTimelineTime: insertionStartTime,
      preferredSelectedElementId: insertionResult.elementId,
      bindings: nextBindings,
    );

    final nextTracks = _ensureTrackKind(_tracks, TimelineTrackKind.text);
    setState(() {
      _tracks = nextTracks;
      _motionProject = insertionResult.project;
      _motionTextAnimationBindings = nextBindings;
      _markMotionAuthoringChanged();
      _selectedClipId = resolvedState.selectedClipId;
      _activeTab = EditorMediaTab.text;
      _previewAssetId = resolvedState.previewAssetId;
      _setCurrentTime(resolvedState.timelineTime);
    });
    final insertedElementId = insertionResult.elementId;
    if (openEditorOnInsert && insertedElementId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_openTextClipEditSheet(insertedElementId));
      });
    }
  }

  Future<void> _registerCustomTextPreset(
    MotionTextPresetDefinition preset,
  ) async {
    if (_customTextPresets.any((candidate) => candidate.id == preset.id)) {
      return;
    }
    setState(() {
      _customTextPresets = <MotionTextPresetDefinition>[
        ..._customTextPresets,
        preset,
      ];
    });
  }

  List<MotionTextPresetDefinition> get _availableTextPresets =>
      <MotionTextPresetDefinition>[
        ...MotionBuiltInTextPresets.all,
        ..._customTextPresets,
      ];

  BasicMotionCompositionCompiler _buildMotionCompiler() {
    return BasicMotionCompositionCompiler(
      textPresetCompiler: BasicMotionTextPresetCompiler(
        presetCatalog: _availableTextPresets,
      ),
    );
  }

  BasicMotionTextPreviewBinder _buildMotionTextPreviewBinder() {
    return BasicMotionTextPreviewBinder(
      presetCatalog: _availableTextPresets,
    );
  }

  BasicMotionTextElementAuthoringService _buildMotionTextAuthoringService() {
    return BasicMotionTextElementAuthoringService(
      presetCatalog: _availableTextPresets,
    );
  }

  TextMotionKeyframeAuthoringService
      _buildTextMotionKeyframeAuthoringService() {
    return const TextMotionKeyframeAuthoringService();
  }

  ProfessionalCanvasTimelineAuthoringService
      _buildCanvasTimelineAuthoringService() {
    return const ProfessionalCanvasTimelineAuthoringService();
  }

  LayerScopeMotionAuthoringAdapter _buildLayerScopeMotionAuthoringAdapter() {
    return const LayerScopeMotionAuthoringAdapter();
  }

  TimelineTimeRange _defaultTextPresetRange() {
    final timelineDuration = _timelineDurationTime;
    if (timelineDuration <= TimelineTime.zero) {
      return TimelineTimeRange(
        start: TimelineTime.zero,
        endExclusive: _defaultTextPresetDurationTime,
      );
    }
    final duration = timelineDuration < _defaultTextPresetDurationTime
        ? timelineDuration
        : _defaultTextPresetDurationTime;
    final maxStart = timelineDuration - duration;
    final start = _currentTime > maxStart ? maxStart : _currentTime;
    return TimelineTimeRange(
      start: start.clamp(TimelineTime.zero, timelineDuration),
      endExclusive:
          (start + duration).clamp(TimelineTime.zero, timelineDuration),
    );
  }

  Future<Map<String, Uint8List?>> _loadAssetThumbnailBatch(
    List<EditorAssetItem> assets,
  ) {
    final requests = <Map<String, String>>[
      for (final asset in assets)
        if (asset.isVisual &&
            asset.sourceUri != null &&
            asset.sourceUri!.isNotEmpty)
          <String, String>{
            'assetId': asset.id,
            'sourceUri': asset.sourceUri!,
          },
    ];
    if (requests.isEmpty) {
      return Future<Map<String, Uint8List?>>.value(
        const <String, Uint8List?>{},
      );
    }
    return _transportController.loadMediaThumbnails(
      requests: requests,
      targetWidth: 192,
      targetHeight: 320,
    );
  }

  Future<MediaSheetPageResult> _refreshAssetsForTab(EditorMediaTab tab) {
    return _loadAssetsForTab(tab, reset: true);
  }

  Future<MediaSheetPageResult> _loadMoreAssetsForTab(EditorMediaTab tab) {
    return _loadAssetsForTab(tab, reset: false);
  }

  Future<MediaSheetPageResult> _loadAssetsForTab(
    EditorMediaTab tab, {
    required bool reset,
  }) async {
    if (tab != EditorMediaTab.video && tab != EditorMediaTab.image) {
      _assetLibraryError.value =
          'Only video and image import are active in this stage.';
      return const MediaSheetPageResult(hasMore: false, loadedCount: 0);
    }
    if (_assetPageRequestsInFlight.contains(tab)) {
      final loadedCount =
          _assetLibrary.value.where((item) => item.tab == tab).length;
      return MediaSheetPageResult(
        hasMore: _assetHasMore[tab] ?? false,
        loadedCount: loadedCount,
      );
    }

    _assetPageRequestsInFlight.add(tab);
    if (reset) {
      _assetLibraryLoading.value = true;
      _assetLibraryError.value = null;
      _assetOffsets[tab] = 0;
      _assetHasMore[tab] = true;
    }
    final mediaKind = tab == EditorMediaTab.image ? 'image' : 'video';
    try {
      final page = await _transportController.loadDeviceMediaPage(
        mediaKind,
        offset: reset ? 0 : (_assetOffsets[tab] ?? 0),
        limit: _deviceMediaPageSize,
      );
      final entries = page.items;
      final nextAssets =
          entries.map(EditorAssetItem.fromPlatformMap).toList(growable: false);
      if (!mounted) {
        return const MediaSheetPageResult(hasMore: false, loadedCount: 0);
      }
      final existingImported = <String, EditorAssetItem>{
        ..._importedAssetsById,
      };
      final existingSameTab = <String, EditorAssetItem>{
        for (final asset in _assetLibrary.value)
          if (asset.tab == tab) asset.id: asset,
      };
      final nextSameTab = <EditorAssetItem>[
        if (!reset)
          for (final asset in _assetLibrary.value)
            if (asset.tab == tab) asset,
        for (final asset in nextAssets)
          if (reset || !existingSameTab.containsKey(asset.id))
            if (existingImported.containsKey(asset.id))
              asset.copyWith(isImported: true)
            else
              asset,
      ];
      final merged = <EditorAssetItem>[
        for (final asset in _assetLibrary.value)
          if (asset.tab != tab) asset,
        ...nextSameTab,
      ];
      _assetLibrary.value = List<EditorAssetItem>.unmodifiable(merged);
      _assetOffsets[tab] = page.nextOffset;
      _assetHasMore[tab] = page.hasMore;
      final loadedCount = nextSameTab.length;
      if (reset && entries.isEmpty) {
        _assetLibraryError.value =
            'No ${tab.label.toLowerCase()} items are currently available.';
      }
      return MediaSheetPageResult(
        hasMore: page.hasMore,
        loadedCount: loadedCount,
      );
    } catch (error) {
      _assetLibraryError.value = error.toString();
      final loadedCount =
          _assetLibrary.value.where((item) => item.tab == tab).length;
      return MediaSheetPageResult(
        hasMore: _assetHasMore[tab] ?? false,
        loadedCount: loadedCount,
      );
    } finally {
      _assetPageRequestsInFlight.remove(tab);
      if (reset) {
        _assetLibraryLoading.value = false;
      }
    }
  }

  Future<void> _addAssetToTimeline(EditorAssetItem asset) async {
    final kind = _trackKindForTab(asset.tab);
    if (kind == null) {
      return;
    }
    var baseTracks = List<TimelineTrackData>.from(_tracks);
    var trackIndex = baseTracks.indexWhere((track) => track.kind == kind);
    if (trackIndex < 0) {
      baseTracks.add(
        TimelineTrackData(
          kind: kind,
          clips: const <TimelineClipData>[],
        ),
      );
      trackIndex = baseTracks.length - 1;
    }
    if (trackIndex < 0) {
      return;
    }
    final hadClipsBeforeInsert = baseTracks[trackIndex].clips.isNotEmpty;
    var resolvedAsset = asset;
    if (resolvedAsset.tab == EditorMediaTab.video) {
      resolvedAsset =
          await _normalizeVisualAssetGeometryForInsert(resolvedAsset);
      final sourceUri = resolvedAsset.sourceUri;
      if (sourceUri == null || sourceUri.isEmpty) {
        _showStageMessage('The selected video is missing a playable source.');
        return;
      }
    } else if (resolvedAsset.tab == EditorMediaTab.image) {
      await _pausePlayback();
    }
    final hasPreviewPosterCached =
        (_previewThumbnailCache[resolvedAsset.id]?.isNotEmpty ?? false);
    final shouldPrimePreviewBeforeInsert = resolvedAsset.isVisual &&
        _previewAsset == null &&
        !hasPreviewPosterCached;
    if (shouldPrimePreviewBeforeInsert) {
      await _primePreviewThumbnailForAsset(resolvedAsset);
    } else if (resolvedAsset.isVisual) {
      unawaited(
        _primePreviewThumbnailForAsset(
          resolvedAsset,
          publishIfNotCurrent: false,
        ),
      );
    }
    resolvedAsset = _assetForId(resolvedAsset.id) ?? resolvedAsset;
    final clipId =
        'clip-${resolvedAsset.id}-${DateTime.now().millisecondsSinceEpoch}';
    final clip = TimelineClipData(
      id: clipId,
      assetId: resolvedAsset.id,
      durationTime:
          TimelineTime.fromSecondsDouble(resolvedAsset.durationSeconds ?? 3.5),
      tone: TimelineClipTone.hero,
      type: TimelineClipType.media,
      sourceStartTime: TimelineTime.zero,
      label: resolvedAsset.label,
    );
    final clips = List<TimelineClipData>.from(baseTracks[trackIndex].clips);
    clips.add(clip);
    final nextTracks = _replaceTrackIn(baseTracks, trackIndex, clips);
    final preservedTimelineTime = _currentTime.clamp(
      TimelineTime.zero,
      _timelineDurationForTracksTime(nextTracks),
    );
    final nextPreviewAssetId = _resolvedPreviewAssetIdForTracks(
      nextTracks,
      preferredTimelineTime: preservedTimelineTime,
    );
    final nextSelectedClipId = hadClipsBeforeInsert ? _selectedClipId : clip.id;
    setState(() {
      _tracks = nextTracks;
      if (resolvedAsset.tab == EditorMediaTab.video) {
        _isApplyingStructuralEdit = true;
      }
      _selectedClipId = nextSelectedClipId;
      _previewAssetId = nextPreviewAssetId;
      _refreshLiveScrubPreviewSourceCatalog(tracks: nextTracks);
      _setCurrentTime(preservedTimelineTime);
      if (_lockedWorkspaceAspectRatio == null &&
          resolvedAsset.tab == EditorMediaTab.video &&
          resolvedAsset.aspectRatio != null &&
          resolvedAsset.aspectRatio! > 0) {
        _lockedWorkspaceAspectRatio = resolvedAsset.aspectRatio;
      }
      _activeTab = resolvedAsset.tab == EditorMediaTab.image
          ? EditorMediaTab.image
          : resolvedAsset.tab == EditorMediaTab.video
              ? EditorMediaTab.video
              : _activeTab;
    });
    _markAssetImported(
      resolvedAsset.id,
      preferredPreviewPositionMs: clip.sourceStartTime.inMilliseconds,
    );
    if (resolvedAsset.tab == EditorMediaTab.video) {
      await _commitStructuralTimelineEdit(
        tracks: nextTracks,
        targetTime: preservedTimelineTime,
        previewAssetId: nextPreviewAssetId,
      );
    }
  }

  TimelineTrackKind? _trackKindForTab(EditorMediaTab tab) {
    return switch (tab) {
      EditorMediaTab.video => TimelineTrackKind.video,
      EditorMediaTab.image => TimelineTrackKind.image,
      EditorMediaTab.audio => TimelineTrackKind.audio,
      EditorMediaTab.text => TimelineTrackKind.text,
      EditorMediaTab.speed => null,
      EditorMediaTab.lipSync => TimelineTrackKind.lipSync,
    };
  }

  Future<void> _syncVideoTimelineTransport({
    required List<TimelineTrackData> tracks,
    required TimelineTime targetTime,
  }) async {
    final videoTrackIndex = tracks.indexWhere(
      (track) => track.kind == TimelineTrackKind.video,
    );
    if (videoTrackIndex < 0) {
      await _transportController.initialize();
      return;
    }

    final segments = <Map<String, dynamic>>[];
    var totalDuration = TimelineTime.zero;
    for (final clip in tracks[videoTrackIndex].clips) {
      final asset = _assetForId(clip.assetId);
      final sourceUri = asset?.sourceUri;
      if (asset == null || sourceUri == null || sourceUri.isEmpty) {
        continue;
      }
      final startTime = clip.sourceStartTime;
      final endTime = clip.sourceEndTime;
      if (endTime <= startTime) {
        continue;
      }
      totalDuration += clip.durationTime;
      final assetDurationSeconds = asset.durationSeconds;
      final assetDurationTime = assetDurationSeconds == null
          ? null
          : TimelineTime.fromSecondsDouble(assetDurationSeconds);
      final isFullSource = clip.sourceStartTime <= TimelineTime.zero &&
          assetDurationTime != null &&
          clip.durationTime == assetDurationTime;
      segments.add(<String, dynamic>{
        'clipId': clip.id,
        'sourceUri': sourceUri,
        'sourceLabel': asset.label,
        'startMs': startTime.inMilliseconds,
        'endMs': endTime.inMilliseconds,
        'timelineDurationMs': clip.durationTime.inMilliseconds,
        'playbackRate': clip.playbackRate,
        'isFullSource': isFullSource,
      });
    }

    if (segments.isEmpty) {
      await _transportController.initialize();
      return;
    }

    await _transportController.prepareTimelineSegments(
      segments: segments,
      startPositionMs:
          targetTime.clamp(TimelineTime.zero, totalDuration).inMilliseconds,
    );
  }

  Future<void> _stabilizePreviewAfterStructuralTimelineEdit({
    required TimelineTime targetTime,
    required String? previewAssetId,
  }) async {
    if (!mounted || previewAssetId != _previewAssetId) {
      return;
    }
    final previewAsset =
        previewAssetId == null ? null : _assetForId(previewAssetId);
    if (previewAsset?.tab == EditorMediaTab.video &&
        _transportController.isPlatformSupported) {
      await _seekPlaybackTo(targetTime);
    }
    if (!mounted || previewAssetId != _previewAssetId) {
      return;
    }
    if (previewAsset != null && previewAsset.isVisual) {
      // Fallback thumbnails are non-critical after a structural edit. Keeping
      // them off the critical path prevents play/seek updates from being gated
      // behind MediaMetadataRetriever work on freshly exposed clips.
      _schedulePreviewThumbnailPrimeForAsset(
        previewAsset,
        publishIfNotCurrent: false,
      );
    }
  }

  Future<void> _commitStructuralTimelineEdit({
    required List<TimelineTrackData> tracks,
    required TimelineTime targetTime,
    String? previewAssetId,
    bool awaitPreviewStabilization = true,
    bool awaitScrubReadiness = true,
  }) {
    final completer = Completer<void>();
    final maxTimelineTime = _timelineDurationForTracksTime(tracks);
    final safeTargetTime = targetTime.clamp(TimelineTime.zero, maxTimelineTime);
    _timelineStructuralCommit = _timelineStructuralCommit.then((_) async {
      if (!mounted) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }
      setState(() {
        _isApplyingStructuralEdit = true;
        _isTimelineScrubbing = false;
        _isPlaying = false;
        _timelineTrimPreviewSession = null;
        _activeTrimPreviewSourceUri = null;
      });
      _timelineTrimPreviewRequestId++;
      try {
        if (_useNativePreview) {
          await _pausePlayback();
        }
        await _syncVideoTimelineTransport(
          tracks: tracks,
          targetTime: safeTargetTime,
        );
        if (awaitPreviewStabilization) {
          await _stabilizePreviewAfterStructuralTimelineEdit(
            targetTime: safeTargetTime,
            previewAssetId: previewAssetId,
          );
        }
        await _scheduleScrubFramePreparationForTimelineTracks(tracks);
        await _flushNativeTimelineScrubConfig();
        if (awaitScrubReadiness) {
          await _awaitNativeTimelineScrubReadiness(safeTargetTime);
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isApplyingStructuralEdit = false;
          });
        }
      }
    });
    return completer.future;
  }

  void _applyStructuralEditPlan(_TimelineStructuralEditPlan plan) {
    final canonicalPlan = _canonicalizeStructuralEditPlan(plan);
    _timelineTrimPreviewRequestId++;
    setState(() {
      _tracks = canonicalPlan.tracks;
      _isApplyingStructuralEdit = true;
      _isTimelineScrubbing = false;
      _isPlaying = false;
      _selectedClipId = canonicalPlan.selectedClipId;
      _setCurrentTime(canonicalPlan.targetTime);
      _previewAssetId = canonicalPlan.previewAssetId;
      _activeTrimClipId = null;
      _timelineTrimPreviewSession = null;
      _activeTrimPreviewSourceUri = null;
    });
    unawaited(
      _commitStructuralTimelineEdit(
        tracks: canonicalPlan.tracks,
        targetTime: canonicalPlan.targetTime,
        previewAssetId: canonicalPlan.previewAssetId,
      ),
    );
  }

  _TimelineStructuralEditPlan _canonicalizeStructuralEditPlan(
    _TimelineStructuralEditPlan plan,
  ) {
    final maxTimelineTime = _timelineDurationForTracksTime(plan.tracks);
    var targetTime = plan.targetTime.clamp(TimelineTime.zero, maxTimelineTime);
    String? selectedClipId = plan.selectedClipId;
    var selectedContext = selectedClipId == null
        ? null
        : _selectedClipContextForTracks(plan.tracks, selectedClipId);
    if (selectedContext == null &&
        plan.editedTrackIndex >= 0 &&
        plan.editedTrackIndex < plan.tracks.length) {
      selectedClipId = _resolveClipIdForGaplessTrackAtTime(
        plan.tracks[plan.editedTrackIndex].clips,
        targetTime,
      );
      selectedContext = selectedClipId == null
          ? null
          : _selectedClipContextForTracks(plan.tracks, selectedClipId);
    }
    selectedClipId = selectedContext?.clip.id;
    if (plan.selectionAnchorPolicy ==
            _TimelineSelectionAnchorPolicy.selectedClipStart &&
        selectedContext != null) {
      targetTime = selectedContext.clipStartTime;
    }
    final canonicalPreferredPreviewAssetId =
        switch (plan.selectionAnchorPolicy) {
      _TimelineSelectionAnchorPolicy.selectedClipStart =>
        selectedContext?.clip.assetId ?? plan.previewAssetId,
      _TimelineSelectionAnchorPolicy.structuralTarget => null,
    };
    return _TimelineStructuralEditPlan(
      kind: plan.kind,
      editedTrackIndex: plan.editedTrackIndex,
      gapPolicy: plan.gapPolicy,
      ripplePolicy: plan.ripplePolicy,
      selectionAnchorPolicy: plan.selectionAnchorPolicy,
      tracks: plan.tracks,
      targetTime: targetTime,
      selectedClipId: selectedClipId,
      previewAssetId: _resolveStructuralEditPreviewAssetId(
        tracks: plan.tracks,
        targetTime: targetTime,
        preferredAssetId: canonicalPreferredPreviewAssetId,
      ),
    );
  }

  List<TimelineClipData> _normalizeStructuralEditClips(
    List<TimelineClipData> clips, {
    required _TimelineGapPolicy gapPolicy,
  }) {
    switch (gapPolicy) {
      case _TimelineGapPolicy.gaplessTrack:
        return List<TimelineClipData>.unmodifiable(
          List<TimelineClipData>.generate(clips.length, (index) {
            final clip = clips[index];
            final splitGroupId = clip.splitGroupId;
            if (splitGroupId == null) {
              return clip;
            }
            final previousSharesGroup =
                index > 0 && clips[index - 1].splitGroupId == splitGroupId;
            final nextSharesGroup = index < clips.length - 1 &&
                clips[index + 1].splitGroupId == splitGroupId;
            if (previousSharesGroup || nextSharesGroup) {
              return clip;
            }
            return clip.copyWith(clearSplitGroupId: true);
          }),
        );
    }
  }

  List<TimelineTrackData> _replaceTrackForStructuralEdit(
    int index,
    List<TimelineClipData> clips, {
    required _TimelineGapPolicy gapPolicy,
  }) {
    final normalizedClips = _normalizeStructuralEditClips(
      clips,
      gapPolicy: gapPolicy,
    );
    final nextTracks = List<TimelineTrackData>.from(_tracks);
    nextTracks[index] = nextTracks[index].copyWith(clips: normalizedClips);
    return List<TimelineTrackData>.unmodifiable(nextTracks);
  }

  TimelineTime _resolveStructuralEditTargetTime({
    required _TimelineStructuralEditKind kind,
    required _TimelineRipplePolicy ripplePolicy,
    required _SelectedTimelineClipContext context,
  }) {
    switch (ripplePolicy) {
      case _TimelineRipplePolicy.none:
        return _currentTime;
      case _TimelineRipplePolicy.trackLocalDelete:
        if (kind != _TimelineStructuralEditKind.delete) {
          return _currentTime;
        }
        return _timelineTimeAfterDelete(context);
    }
  }

  String? _resolveStructuralEditPreviewAssetId({
    required List<TimelineTrackData> tracks,
    required TimelineTime targetTime,
    String? preferredAssetId,
  }) {
    return _resolvedPreviewAssetIdForTracks(
      tracks,
      preferredAssetId: preferredAssetId,
      preferredTimelineTime: targetTime,
    );
  }

  String? _resolveClipIdForGaplessTrackAtTime(
    List<TimelineClipData> clips,
    TimelineTime targetTime,
  ) {
    if (clips.isEmpty) {
      return null;
    }
    var cursor = TimelineTime.zero;
    for (final clip in clips) {
      final clipEndTime = cursor + clip.durationTime;
      if (targetTime < clipEndTime) {
        return clip.id;
      }
      cursor = clipEndTime;
    }
    return clips.last.id;
  }

  String? _resolvePreferredPreviewAssetIdForClipSelection(
    List<TimelineClipData> clips,
    String? selectedClipId,
  ) {
    if (selectedClipId == null) {
      return null;
    }
    for (final clip in clips) {
      if (clip.id == selectedClipId) {
        final assetId = clip.assetId;
        if (assetId != null && assetId.isNotEmpty) {
          return assetId;
        }
        break;
      }
    }
    return null;
  }

  _TimelineStructuralEditPlan _buildStructuralEditPlan({
    required _TimelineStructuralEditKind kind,
    required _SelectedTimelineClipContext context,
    required List<TimelineClipData> nextClips,
    required _TimelineGapPolicy gapPolicy,
    required _TimelineRipplePolicy ripplePolicy,
    required _TimelineSelectionAnchorPolicy selectionAnchorPolicy,
    required String? nextSelectedClipId,
    String? preferredPreviewAssetId,
  }) {
    final nextTracks = _replaceTrackForStructuralEdit(
      context.trackIndex,
      nextClips,
      gapPolicy: gapPolicy,
    );
    final baseTargetTime = _resolveStructuralEditTargetTime(
      kind: kind,
      ripplePolicy: ripplePolicy,
      context: context,
    );
    var targetTime = baseTargetTime;
    switch (selectionAnchorPolicy) {
      case _TimelineSelectionAnchorPolicy.structuralTarget:
        break;
      case _TimelineSelectionAnchorPolicy.selectedClipStart:
        final selectedContext = nextSelectedClipId == null
            ? null
            : _selectedClipContextForTracks(nextTracks, nextSelectedClipId);
        if (selectedContext != null) {
          targetTime = selectedContext.clipStartTime;
        }
        break;
    }
    return _TimelineStructuralEditPlan(
      kind: kind,
      editedTrackIndex: context.trackIndex,
      gapPolicy: gapPolicy,
      ripplePolicy: ripplePolicy,
      selectionAnchorPolicy: selectionAnchorPolicy,
      tracks: nextTracks,
      targetTime: targetTime,
      selectedClipId: nextSelectedClipId,
      previewAssetId: _resolveStructuralEditPreviewAssetId(
        tracks: nextTracks,
        targetTime: targetTime,
        preferredAssetId: preferredPreviewAssetId ??
            _resolvePreferredPreviewAssetIdForClipSelection(
              nextClips,
              nextSelectedClipId,
            ),
      ),
    );
  }

  _TimelineStructuralEditPlan _buildDeleteStructuralEditPlan(
    _SelectedTimelineClipContext context,
  ) {
    const gapPolicy = _TimelineGapPolicy.gaplessTrack;
    const ripplePolicy = _TimelineRipplePolicy.trackLocalDelete;
    const selectionAnchorPolicy =
        _TimelineSelectionAnchorPolicy.structuralTarget;
    final clips = List<TimelineClipData>.from(_tracks[context.trackIndex].clips)
      ..removeAt(context.clipIndex);
    final postDeleteTargetTime = _resolveStructuralEditTargetTime(
      kind: _TimelineStructuralEditKind.delete,
      ripplePolicy: ripplePolicy,
      context: context,
    );
    final nextSelectedClipId = _resolveClipIdForGaplessTrackAtTime(
      clips,
      postDeleteTargetTime,
    );
    return _buildStructuralEditPlan(
      kind: _TimelineStructuralEditKind.delete,
      context: context,
      nextClips: clips,
      gapPolicy: gapPolicy,
      ripplePolicy: ripplePolicy,
      selectionAnchorPolicy: selectionAnchorPolicy,
      nextSelectedClipId: nextSelectedClipId,
    );
  }

  _TimelineStructuralEditPlan _buildDuplicateStructuralEditPlan(
    _SelectedTimelineClipContext context,
  ) {
    const gapPolicy = _TimelineGapPolicy.gaplessTrack;
    const ripplePolicy = _TimelineRipplePolicy.none;
    const selectionAnchorPolicy =
        _TimelineSelectionAnchorPolicy.selectedClipStart;
    final clips =
        List<TimelineClipData>.from(_tracks[context.trackIndex].clips);
    final duplicatedClip = context.clip.copyWith(
      id: 'clip-${context.clip.assetId ?? context.clip.id}-${DateTime.now().millisecondsSinceEpoch}',
      clearSplitGroupId: true,
    );
    clips.insert(context.clipIndex + 1, duplicatedClip);
    return _buildStructuralEditPlan(
      kind: _TimelineStructuralEditKind.duplicate,
      context: context,
      nextClips: clips,
      gapPolicy: gapPolicy,
      ripplePolicy: ripplePolicy,
      selectionAnchorPolicy: selectionAnchorPolicy,
      nextSelectedClipId: duplicatedClip.id,
      preferredPreviewAssetId: _previewAssetId ?? duplicatedClip.assetId,
    );
  }

  _TimelineStructuralEditPlan _buildSplitStructuralEditPlan(
    _SelectedTimelineClipContext context,
  ) {
    const gapPolicy = _TimelineGapPolicy.gaplessTrack;
    const ripplePolicy = _TimelineRipplePolicy.none;
    const selectionAnchorPolicy =
        _TimelineSelectionAnchorPolicy.selectedClipStart;
    final splitOffset = _currentTime - context.clipStartTime;
    final playbackRate =
        context.clip.playbackRate <= 0 ? 1.0 : context.clip.playbackRate;
    final leftSourceDurationTime = _sourceDurationForPlaybackRate(
      splitOffset,
      playbackRate,
    ).clamp(TimelineTime.zero, context.clip.sourceDurationTime);
    final rightSourceDurationTime =
        context.clip.sourceDurationTime - leftSourceDurationTime;
    final splitGroupId =
        'split-${context.clip.id}-${DateTime.now().millisecondsSinceEpoch}';
    final leftClip = context.clip.copyWith(
      durationTime: splitOffset,
      sourceDurationTime: leftSourceDurationTime,
      splitGroupId: splitGroupId,
    );
    final rightClip = context.clip.copyWith(
      id: 'clip-${context.clip.assetId ?? context.clip.id}-${DateTime.now().millisecondsSinceEpoch}',
      durationTime: context.clip.durationTime - splitOffset,
      sourceStartTime: context.clip.sourceStartTime + leftSourceDurationTime,
      sourceDurationTime: rightSourceDurationTime,
      splitGroupId: splitGroupId,
    );
    final clips = List<TimelineClipData>.from(_tracks[context.trackIndex].clips)
      ..removeAt(context.clipIndex)
      ..insertAll(context.clipIndex, <TimelineClipData>[leftClip, rightClip]);
    return _buildStructuralEditPlan(
      kind: _TimelineStructuralEditKind.split,
      context: context,
      nextClips: clips,
      gapPolicy: gapPolicy,
      ripplePolicy: ripplePolicy,
      selectionAnchorPolicy: selectionAnchorPolicy,
      nextSelectedClipId: rightClip.id,
      preferredPreviewAssetId: _previewAssetId ?? rightClip.assetId,
    );
  }

  _TimelineStructuralEditPlan _buildReorderStructuralEditPlan(
    _SelectedTimelineClipContext context,
    int insertionIndex,
  ) {
    const gapPolicy = _TimelineGapPolicy.gaplessTrack;
    const ripplePolicy = _TimelineRipplePolicy.none;
    const selectionAnchorPolicy =
        _TimelineSelectionAnchorPolicy.selectedClipStart;
    final clips =
        List<TimelineClipData>.from(_tracks[context.trackIndex].clips);
    final clip = clips.removeAt(context.clipIndex);
    final targetIndex = insertionIndex.clamp(0, clips.length);
    clips.insert(targetIndex, clip);
    return _buildStructuralEditPlan(
      kind: _TimelineStructuralEditKind.reorder,
      context: context,
      nextClips: clips,
      gapPolicy: gapPolicy,
      ripplePolicy: ripplePolicy,
      selectionAnchorPolicy: selectionAnchorPolicy,
      nextSelectedClipId: clip.id,
      preferredPreviewAssetId: clip.assetId ?? _previewAssetId,
    );
  }

  TimelineTime _timelineTimeAfterDelete(_SelectedTimelineClipContext context) {
    if (_currentTime <= context.clipStartTime) {
      return _currentTime;
    }
    if (_currentTime < context.clipEndTime) {
      return context.clipStartTime;
    }
    return _currentTime - context.clip.durationTime;
  }

  TimelineTime _timelineDurationForTracksTime(List<TimelineTrackData> tracks) {
    var maxDuration = TimelineTime.zero;
    for (final track in tracks) {
      var cursor = TimelineTime.zero;
      for (final clip in track.clips) {
        cursor += clip.durationTime;
      }
      if (cursor > maxDuration) {
        maxDuration = cursor;
      }
    }
    return maxDuration;
  }

  String? _resolvedPreviewAssetIdForTracks(
    List<TimelineTrackData> tracks, {
    String? preferredAssetId,
    TimelineTime? preferredTimelineTime,
  }) {
    String? nearestAssetIdForTime() {
      if (preferredTimelineTime == null) {
        return null;
      }
      for (final kind in <TimelineTrackKind>[
        TimelineTrackKind.video,
        TimelineTrackKind.image,
      ]) {
        for (final track in tracks.where((item) => item.kind == kind)) {
          var cursor = TimelineTime.zero;
          TimelineClipData? lastClip;
          for (final clip in track.clips) {
            final assetId = clip.assetId;
            if (assetId == null || assetId.isEmpty) {
              cursor += clip.durationTime;
              continue;
            }
            final clipEndTime = cursor + clip.durationTime;
            if (preferredTimelineTime < clipEndTime) {
              return assetId;
            }
            lastClip = clip;
            cursor = clipEndTime;
          }
          final lastAssetId = lastClip?.assetId;
          if (lastAssetId != null && lastAssetId.isNotEmpty) {
            return lastAssetId;
          }
        }
      }
      return null;
    }

    final orderedVisualAssetIds = <String>[];
    for (final kind in <TimelineTrackKind>[
      TimelineTrackKind.video,
      TimelineTrackKind.image,
    ]) {
      for (final track in tracks.where((item) => item.kind == kind)) {
        for (final clip in track.clips) {
          final assetId = clip.assetId;
          if (assetId != null && assetId.isNotEmpty) {
            orderedVisualAssetIds.add(assetId);
          }
        }
      }
    }

    final timelineAssetId = nearestAssetIdForTime();
    if (timelineAssetId != null &&
        orderedVisualAssetIds.contains(timelineAssetId)) {
      return timelineAssetId;
    }
    if (preferredAssetId != null &&
        orderedVisualAssetIds.contains(preferredAssetId)) {
      return preferredAssetId;
    }
    if (_previewAssetId != null &&
        orderedVisualAssetIds.contains(_previewAssetId)) {
      return _previewAssetId;
    }
    if (orderedVisualAssetIds.isEmpty) {
      return null;
    }
    return orderedVisualAssetIds.first;
  }

  void _markAssetImported(
    String assetId, {
    int? preferredPreviewPositionMs,
  }) {
    EditorAssetItem? importedAsset;
    final nextAssets = _assetLibrary.value.map((asset) {
      if (asset.id != assetId) {
        return asset;
      }
      importedAsset = asset.copyWith(isImported: true);
      return importedAsset!;
    }).toList(growable: false);
    if (importedAsset != null) {
      _importedAssetsById[assetId] = importedAsset!;
    } else {
      final knownAsset = _importedAssetsById[assetId];
      if (knownAsset != null) {
        _importedAssetsById[assetId] = knownAsset.copyWith(isImported: true);
      }
    }
    _assetLibrary.value = List<EditorAssetItem>.unmodifiable(nextAssets);
    final primingAsset = importedAsset ?? _importedAssetsById[assetId];
    if (primingAsset != null && primingAsset.tab == EditorMediaTab.video) {
      _primeVideoAssetForLiveScrub(
        primingAsset,
        preferredPreviewPositionMs: preferredPreviewPositionMs,
      );
    }
  }

  String? _resolveAssetPath(String assetId) {
    final asset = _assetForId(assetId);
    if (asset == null || !asset.hasFilePath) {
      return null;
    }
    return asset.sourceUri;
  }

  List<TimelineTrackData> _buildInitialTracks() {
    return const <TimelineTrackData>[];
  }

  void _handleShare() {
    unawaited(_openExportBottomSheet());
  }

  Future<void> _openExportBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ExportBottomSheet(
          controller: _exportController,
          buildComposition: () => _buildCurrentExportComposition(
            includeMotionTextRenderTrack: true,
          ),
          onStartExport: _startExportFromCurrentTimeline,
          onCancelExport: _cancelCurrentExport,
          onOpenOutput: _openExportOutput,
          onShareOutput: _shareExportOutput,
          onSaveToGallery: _saveExportOutputToGallery,
          onStageMessage: _showStageMessage,
        );
      },
    );
  }

  Future<void> _startExportFromCurrentTimeline(
    ExportOutputProfile profile,
  ) async {
    if (_exportController.state.isActive) {
      _showStageMessage('An export is already running.');
      return;
    }
    final exportComposition = _buildCurrentExportComposition(
      includeMotionTextRenderTrack: true,
    );
    final issuesCount = exportComposition.issues.length;
    final blockers = exportComposition.firstBaselineBlockingReasons;
    if (blockers.isNotEmpty) {
      _showStageMessage(
        'Export composition built with $issuesCount issue(s) and ${blockers.length} first-baseline blocker(s).',
      );
      return;
    }
    final requestedFileName = _buildRequestedExportFileName();
    final jobId = await _exportController.startExport(
      composition: exportComposition,
      profile: profile,
      requestedFileName: requestedFileName,
    );
    final state = _exportController.state;
    if (jobId == null || state.status == ExportJobStatus.failed) {
      _showStageMessage(
        state.error ?? 'Unable to start export right now.',
      );
      return;
    }
    _showStageMessage(
      'Export started: ${exportComposition.totalClipCount} clips.',
    );
  }

  Future<void> _cancelCurrentExport() async {
    if (!_exportController.state.isActive) {
      return;
    }
    await _exportController.cancelExport();
  }

  Future<bool> _openExportOutput(String outputPath, String? mimeType) async {
    return _exportController.openExportOutput(
      outputPath: outputPath,
      mimeType: mimeType,
    );
  }

  Future<bool> _shareExportOutput(String outputPath, String? mimeType) async {
    return _exportController.shareExportOutput(
      outputPath: outputPath,
      mimeType: mimeType,
    );
  }

  Future<String?> _saveExportOutputToGallery(
    String outputPath,
    String? mimeType,
  ) async {
    return _exportController.saveExportOutputToGallery(
      outputPath: outputPath,
      mimeType: mimeType,
    );
  }

  String _buildRequestedExportFileName() {
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${now.year}${twoDigits(now.month)}${twoDigits(now.day)}-${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}';
    return 'ingene-export-$timestamp.mp4';
  }

  void _handlePlayToggle() {
    _clearTextEditPreviewRange();
    final transitionFocusSession = _transitionFocusSession;
    final transitionFocusContext = transitionFocusSession == null
        ? null
        : _transitionFocusContextById(transitionFocusSession.transitionId);
    if (transitionFocusContext != null) {
      unawaited(_toggleTransitionFocusPlayback(transitionFocusContext));
      return;
    }
    if (_canFastTogglePlayback) {
      unawaited(_toggleTimelinePlaybackFromVisibleTime());
      return;
    }
    unawaited(_togglePlayAfterStructuralCommit());
  }

  bool get _canFastTogglePlayback =>
      _useNativePreview &&
      !_isApplyingStructuralEdit &&
      _timelineTrimPreviewSession == null &&
      _transportController.state.sourceKind == 'timeline';

  TimelineTime _visibleTimelinePlaybackTime({
    TimelineTime? minTime,
    TimelineTime? maxTime,
  }) {
    final min = minTime ?? TimelineTime.zero;
    final max = maxTime ?? _timelineDurationTime;
    final handoffTarget = _timelineScrubHandoffTargetTime;
    if (_isTimelineScrubHandoffInFlight && handoffTarget != null) {
      return handoffTarget.clamp(min, max);
    }
    final displayTime = _timelineDisplayTimeNotifier.value.clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    if (displayTime >= min && displayTime <= max) {
      return displayTime;
    }
    final current = _currentTime.clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    if (current >= min && current <= max) {
      return current;
    }
    return min.clamp(TimelineTime.zero, _timelineDurationTime);
  }

  TimelineTime _authoritativeTimelinePlaybackTime({
    TimelineTime? minTime,
    TimelineTime? maxTime,
  }) {
    final min = minTime ?? TimelineTime.zero;
    final max = maxTime ?? _timelineDurationTime;
    if (_useNativePreview && _transportController.isPlaying) {
      final transportTime = TimelineTime.fromMilliseconds(
        _transportController.state.positionMs,
      ).clamp(TimelineTime.zero, _timelineDurationTime);
      if (transportTime >= min && transportTime <= max) {
        return transportTime;
      }
    }
    return _visibleTimelinePlaybackTime(minTime: min, maxTime: max);
  }

  Future<void> _toggleTimelinePlaybackFromVisibleTime() async {
    final playbackTime = _authoritativeTimelinePlaybackTime();
    if (_transportController.isPlaying) {
      _timelineClockCoordinator.pauseAt(playbackTime);
      _activatePlaybackStopTimeLock(playbackTime);
      await _pausePlayback();
      if (mounted) {
        _activatePlaybackStopTimeLock(playbackTime);
      }
      return;
    }
    _clearPlaybackStopTimeLock();
    final transportReady =
        await _prepareTransportForPlaybackStart(playbackTime);
    if (!mounted) {
      return;
    }
    if (!transportReady) {
      _setCurrentTime(playbackTime);
      _setPlaybackSampleTime(playbackTime);
      return;
    }
    _requestTimelineClockPlaybackStart(playbackTime);
    _prepareMotionPreviewForPlaybackStart(time: playbackTime);
    await _playPlaybackFrom(playbackTime);
  }

  Future<void> _toggleTransitionFocusPlayback(
    _TransitionFocusContext context,
  ) async {
    await _timelineStructuralCommit;
    if (!mounted || _isApplyingStructuralEdit || !_useNativePreview) {
      return;
    }
    if (_transportController.isPlaying) {
      _timelineClockCoordinator.pauseAt(
        _authoritativeTimelinePlaybackTime(
          minTime: context.startTime,
          maxTime: context.endTime,
        ).clamp(context.startTime, context.endTime),
      );
      await _stopTransitionFocusPlayback(
        context,
        snapToStart: false,
        snapToEnd: false,
      );
      return;
    }
    final startTime = context.startTime;
    final endTime = context.endTime;
    final effectiveStartTime = _visibleTimelinePlaybackTime(
      minTime: startTime,
      maxTime: endTime,
    ).clamp(startTime, endTime);
    _clearPlaybackStopTimeLock();
    if (_transportController.state.sourceKind != 'timeline' ||
        _timelineTrimPreviewSession != null) {
      setState(() {
        _timelineTrimPreviewSession = null;
        _activeTrimPreviewSourceUri = null;
      });
      _timelineTrimPreviewRequestId++;
      await _pausePlayback();
      await _syncVideoTimelineTransport(
        tracks: _tracks,
        targetTime: effectiveStartTime,
      );
    } else {
      await _pausePlayback();
    }
    final transportReady =
        await _prepareTransportForPlaybackStart(effectiveStartTime);
    if (!mounted) {
      return;
    }
    if (!transportReady) {
      _setCurrentTime(effectiveStartTime);
      _setPlaybackSampleTime(effectiveStartTime);
      return;
    }
    _requestTimelineClockPlaybackStart(effectiveStartTime);
    _prepareMotionPreviewForPlaybackStart(time: effectiveStartTime);
    await _playPlaybackFrom(effectiveStartTime);
  }

  Future<void> _stopTransitionFocusPlayback(
    _TransitionFocusContext context, {
    required bool snapToStart,
    bool snapToEnd = false,
  }) async {
    if (_isStoppingTransitionFocusPlayback || !_useNativePreview) {
      return;
    }
    _isStoppingTransitionFocusPlayback = true;
    try {
      final targetTime = snapToStart
          ? context.startTime
          : snapToEnd
              ? context.endTime
              : _authoritativeTimelinePlaybackTime(
                  minTime: context.startTime,
                  maxTime: context.endTime,
                ).clamp(context.startTime, context.endTime);
      _activatePlaybackStopTimeLock(targetTime);
      await _pausePlayback();
      if (snapToStart || snapToEnd) {
        await _seekPlaybackTo(targetTime);
      }
      if (!mounted) {
        return;
      }
      _activatePlaybackStopTimeLock(targetTime);
    } finally {
      _isStoppingTransitionFocusPlayback = false;
    }
  }

  bool get _canPreviewActiveTextEditRange {
    final session = _textEditSession;
    if (session == null || !_useNativePreview || _isApplyingStructuralEdit) {
      return false;
    }
    return _motionTextTimelineEntryForElementId(session.elementId) != null;
  }

  bool get _isActiveTextEditPreviewPlaying {
    final session = _textEditSession;
    final previewRange = _textEditPreviewRange;
    if (session == null || previewRange == null) {
      return false;
    }
    return previewRange.elementId == session.elementId && _isPlaying;
  }

  void _clearTextEditPreviewRange({bool pauseTransport = false}) {
    final shouldPause =
        pauseTransport && _useNativePreview && _transportController.isPlaying;
    if (_textEditPreviewRange == null && !shouldPause) {
      return;
    }
    setState(() {
      _textEditPreviewRange = null;
    });
    if (shouldPause) {
      unawaited(_pausePlayback());
    }
  }

  Future<void> _handleTextEditPreviewToggle() async {
    final session = _textEditSession;
    if (session == null) {
      return;
    }
    if (!_useNativePreview) {
      _showStageMessage('Add a video clip to preview this text motion.');
      return;
    }
    final entry = _motionTextTimelineEntryForElementId(session.elementId);
    if (entry == null) {
      _showStageMessage('Unable to resolve this text range right now.');
      return;
    }
    if (_isActiveTextEditPreviewPlaying) {
      await _stopTextEditPreviewPlayback();
      return;
    }
    await _timelineStructuralCommit;
    if (!mounted || _isApplyingStructuralEdit) {
      return;
    }
    final startMs = entry.start.inMilliseconds;
    final endMs = entry.end.inMilliseconds;
    if (endMs <= startMs) {
      _showStageMessage('This text clip has no playable duration yet.');
      return;
    }
    await _pausePlayback();
    await _transportController.seekToPositionMs(startMs);
    if (!mounted) {
      return;
    }
    setState(() {
      _textEditPreviewRange = _TextEditPreviewRange(
        elementId: session.elementId,
        start: entry.start,
        end: entry.end,
      );
    });
    _prepareMotionPreviewForPlaybackStart(time: entry.start);
    await _playPlaybackFrom(entry.start);
  }

  Future<void> _stopTextEditPreviewPlayback({bool snapToEnd = false}) async {
    final previewRange = _textEditPreviewRange;
    if (previewRange == null ||
        !_useNativePreview ||
        _isStoppingTextEditPreviewPlayback) {
      return;
    }
    _isStoppingTextEditPreviewPlayback = true;
    try {
      await _pausePlayback();
      if (snapToEnd) {
        await _seekPlaybackTo(previewRange.end);
      }
    } finally {
      _isStoppingTextEditPreviewPlayback = false;
      if (mounted) {
        setState(() {
          if (_textEditPreviewRange?.elementId == previewRange.elementId) {
            _textEditPreviewRange = null;
          }
        });
      }
    }
  }

  void _handleScrubStateChanged(bool isScrubbing) {
    if (!_useNativePreview) {
      return;
    }
    if (_isApplyingStructuralEdit) {
      return;
    }
    if (_isTimelineScrubbing == isScrubbing) {
      return;
    }
    _isTimelineScrubbing = isScrubbing;
    if (isScrubbing) {
      _clearPlaybackStopTimeLock();
      _clearTimelineScrubHandoff();
      _timelineZoomLockedDisplayTime = null;
      final scrubAnchorTime = (_timelineScrubFinalTime ??
              (_isPlaying ? _timelineDisplayTimeNotifier.value : _currentTime))
          .clamp(TimelineTime.zero, _timelineDurationTime);
      _timelineScrubFinalTime = scrubAnchorTime;
      _syncTimelineClockDuration();
      _timelineClockCoordinator.scrubStart(scrubAnchorTime);
      _applyTimelineClockSnapshotToUi();
      unawaited(_pausePlayback());
      return;
    }

    final finalTimelineTime = _timelineScrubFinalTime;
    final resolvedFinalTime = (finalTimelineTime ?? _currentTime)
        .clamp(TimelineTime.zero, _timelineDurationTime);
    _isTimelineScrubHandoffInFlight = true;
    _timelineScrubHandoffTargetTime = resolvedFinalTime;
    _timelineScrubHandoffRevision++;
    final handoffRevision = _timelineScrubHandoffRevision;
    _timelineScrubFinalTime = null;
    _syncTimelineClockDuration();
    _timelineClockCoordinator.scrubEnd(resolvedFinalTime);
    _applyTimelineClockSnapshotToUi();
    unawaited(
      _transportController
          .settleAfterScrubPositionMs(resolvedFinalTime.inMilliseconds)
          .whenComplete(() {
        if (!mounted) {
          return;
        }
        if (handoffRevision != _timelineScrubHandoffRevision) {
          return;
        }
        final transportState = _transportController.state;
        if (_transportStateMatchesTimelineTime(
          transportState,
          resolvedFinalTime,
        )) {
          _timelineClockCoordinator.confirmScrubSettled(resolvedFinalTime);
          _applyTimelineClockSnapshotToUi();
          _clearTimelineScrubHandoff();
        }
      }),
    );
  }

  void _handleTimelineScrubFinalized(TimelineTime time) {
    if (_isTimelineScrubHandoffInFlight) {
      return;
    }
    final clampedTime = time.clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    _timelineScrubFinalTime = clampedTime;
    if (_isTimelineScrubbing) {
      _timelineClockCoordinator.scrubUpdate(clampedTime);
      _applyTimelineClockSnapshotToUi();
      return;
    }
    if (!_isTimelineScrubbing) {
      setState(() {
        _setCurrentTime(clampedTime);
      });
    }
  }

  void _handleTransitionFocusScrubStateChanged(
    _TransitionFocusContext _,
    bool isScrubbing,
  ) {
    _handleScrubStateChanged(isScrubbing);
  }

  void _handleTransitionFocusDisplayTimeChanged(
    _TransitionFocusContext context,
    TimelineTime localTime,
  ) {
    final localDuration = context.endTime - context.startTime;
    final clampedLocalTime = localTime.clamp(
      TimelineTime.zero,
      localDuration,
    );
    _setTimelineDisplayTime(
      (context.startTime + clampedLocalTime).clamp(
        TimelineTime.zero,
        _timelineDurationTime,
      ),
    );
  }

  void _handleTransitionFocusZoomStateChanged(
    _TransitionFocusContext context,
    TimelineZoomState state,
  ) {
    final localDuration = context.endTime - context.startTime;
    final clampedLocalTime = state.anchorTime.clamp(
      TimelineTime.zero,
      localDuration,
    );
    _applyTimelineZoomState(
      isZooming: state.isZooming,
      globalAnchorTime: context.startTime + clampedLocalTime,
      revision: state.revision,
    );
  }

  void _handleTransitionFocusScrubFinalized(
    _TransitionFocusContext context,
    TimelineTime localTime,
  ) {
    final localDuration = context.endTime - context.startTime;
    final clampedLocalTime = localTime.clamp(
      TimelineTime.zero,
      localDuration,
    );
    _handleTimelineScrubFinalized(
      (context.startTime + clampedLocalTime).clamp(
        TimelineTime.zero,
        _timelineDurationTime,
      ),
    );
  }

  Future<void> _togglePlayAfterStructuralCommit() async {
    await _timelineStructuralCommit;
    if (!mounted || _isApplyingStructuralEdit) {
      return;
    }
    final playbackTime = _authoritativeTimelinePlaybackTime();
    if (_transportController.isPlaying) {
      _timelineClockCoordinator.pauseAt(playbackTime);
      _activatePlaybackStopTimeLock(playbackTime);
      await _pausePlayback();
      if (mounted) {
        _activatePlaybackStopTimeLock(playbackTime);
      }
      return;
    }
    _clearPlaybackStopTimeLock();
    if (_useNativePreview) {
      final transportState = _transportController.state;
      if (transportState.sourceKind != 'timeline' ||
          _timelineTrimPreviewSession != null) {
        setState(() {
          _timelineTrimPreviewSession = null;
          _activeTrimPreviewSourceUri = null;
        });
        _timelineTrimPreviewRequestId++;
        await _pausePlayback();
        await _syncVideoTimelineTransport(
          tracks: _tracks,
          targetTime: playbackTime,
        );
      } else {}
      final transportReady =
          await _prepareTransportForPlaybackStart(playbackTime);
      if (!mounted) {
        return;
      }
      if (!transportReady) {
        _setCurrentTime(playbackTime);
        _setPlaybackSampleTime(playbackTime);
        return;
      }
    }
    if (!mounted) {
      return;
    }
    _requestTimelineClockPlaybackStart(playbackTime);
    _prepareMotionPreviewForPlaybackStart(time: playbackTime);
    await _playPlaybackFrom(playbackTime);
  }

  void _showStageMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _dismissTopStageBanner() {
    _topStageBannerTimer?.cancel();
    _topStageBannerTimer = null;
    _topStageBannerEntry?.remove();
    _topStageBannerEntry = null;
  }

  void _showTopStageBanner(String message) {
    _dismissTopStageBanner();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) {
        final topInset = MediaQuery.of(context).padding.top + 12;
        return Positioned(
          top: topInset,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: _TopStageBannerCard(message: message),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    _topStageBannerEntry = entry;
    _topStageBannerTimer = Timer(
      const Duration(seconds: 3),
      _dismissTopStageBanner,
    );
  }

  void _handlePreviewViewportChanged(PreviewViewportState state) {
    if (_previewViewportState == state) {
      return;
    }
    setState(() {
      _previewViewportState = state;
    });
  }

  void _handlePreviewViewportReset() {
    if (_previewViewportState.isIdentity) {
      return;
    }
    setState(() {
      _previewViewportState = PreviewViewportState.identity;
    });
  }

  List<TimelineTrackTransitionData> _sanitizeTransitionsForTrack(
    TimelineTrackData track, {
    List<TimelineClipData>? clips,
  }) {
    if (track.kind != TimelineTrackKind.video) {
      return const <TimelineTrackTransitionData>[];
    }
    final effectiveClips = clips ?? track.clips;
    final mediaClipIds = <String>[];
    for (final clip in effectiveClips) {
      if (clip.type == TimelineClipType.media) {
        mediaClipIds.add(clip.id);
      }
    }
    if (mediaClipIds.length < 2 || track.transitions.isEmpty) {
      return const <TimelineTrackTransitionData>[];
    }
    final cleaned = <TimelineTrackTransitionData>[];
    for (final transition in track.transitions) {
      final leftIndex = mediaClipIds.indexOf(transition.leftClipId);
      final rightIndex = mediaClipIds.indexOf(transition.rightClipId);
      if (leftIndex < 0 || rightIndex < 0 || rightIndex - leftIndex != 1) {
        continue;
      }
      cleaned.add(transition);
    }
    return List<TimelineTrackTransitionData>.unmodifiable(cleaned);
  }

  TimelineTrackTransitionData? _videoTrackTransitionById(
    String transitionId, {
    List<TimelineTrackData>? tracks,
  }) {
    final sourceTracks = tracks ?? _tracks;
    for (final track in sourceTracks) {
      if (track.kind != TimelineTrackKind.video) {
        continue;
      }
      for (final transition in track.transitions) {
        if (transition.id == transitionId) {
          return transition;
        }
      }
    }
    return null;
  }

  String _normalTransitionTrackIdForTrack(TimelineTrackData track) {
    return track.kind == TimelineTrackKind.video
        ? _normalTransitionVideoTrackId
        : track.kind.name;
  }

  TimelineTrackTransitionData? _createNormalTransitionForBoundary({
    required TimelineTrackData track,
    required TimelineClipData leftClip,
    required TimelineClipData rightClip,
    required TimelineTransitionPreset preset,
  }) {
    final positionedClips = _positionedMediaClipsForTrack(track);
    _PositionedTimelineTrackClip? positionedLeftClip;
    _PositionedTimelineTrackClip? positionedRightClip;
    for (final positionedClip in positionedClips) {
      if (positionedClip.clip.id == leftClip.id) {
        positionedLeftClip = positionedClip;
      } else if (positionedClip.clip.id == rightClip.id) {
        positionedRightClip = positionedClip;
      }
    }
    if (positionedLeftClip == null || positionedRightClip == null) {
      _showStageMessage('Unable to resolve transition boundary.');
      return null;
    }
    final result =
        _normalTransitionAuthoringAdapter.createBuiltInPresetTransition(
      preset: preset,
      trackId: _normalTransitionTrackIdForTrack(track),
      leftClipId: leftClip.id,
      rightClipId: rightClip.id,
      boundaryTime: positionedLeftClip.endTime,
      leftAvailableTail: leftClip.durationTime,
      rightAvailableHead: rightClip.durationTime,
    );
    if (!result.canApply) {
      _showNormalTransitionIssues(result.issues);
      return null;
    }
    return result.transition;
  }

  void _syncNormalTransitionHistoryFromTimelineTransition(
    TimelineTrackTransitionData transition,
  ) {
    if (!_normalTransitionAuthoringAdapter.isNormalPreset(transition.preset)) {
      return;
    }
    final result =
        _normalTransitionAuthoringAdapter.rehydrateTimelineTransition(
      transition: transition,
      trackId: _normalTransitionVideoTrackId,
    );
    if (!result.canApply) {
      _showNormalTransitionIssues(result.issues);
      return;
    }
    _recordNormalTransitionState(
      node: result.node!,
      instance: result.instance!,
    );
  }

  void _recordNormalTransitionState({
    required NormalTransitionNode node,
    required NormalTransitionInstance instance,
  }) {
    final historyResult = _normalTransitionHistory.state.nodeById(node.id) ==
            null
        ? _normalTransitionHistory.addTransition(node: node, instance: instance)
        : _normalTransitionHistory.updateTransition(
            node: node,
            instance: instance,
          );
    if (!historyResult.success) {
      _showStageMessage(historyResult.issues.first.message);
    }
  }

  void _removeNormalTransitionFromHistoryIfPresent(String transitionId) {
    if (_normalTransitionHistory.state.nodeById(transitionId) == null) {
      return;
    }
    final result = _normalTransitionHistory.removeTransition(transitionId);
    if (!result.success) {
      _showStageMessage(result.issues.first.message);
    }
  }

  void _showNormalTransitionIssues(List<NormalTransitionIssue> issues) {
    if (issues.isEmpty) {
      _showStageMessage('Unable to apply transition.');
      return;
    }
    final issue = issues.firstWhere(
      (candidate) => candidate.severity == NormalTransitionIssueSeverity.error,
      orElse: () => issues.first,
    );
    _showStageMessage(issue.message);
  }

  void _upsertVideoTrackTransition(TimelineTrackTransitionData transition) {
    final videoTrackIndex = _tracks.indexWhere(
      (track) => track.kind == TimelineTrackKind.video,
    );
    if (videoTrackIndex < 0) {
      return;
    }
    _syncNormalTransitionHistoryFromTimelineTransition(transition);
    final baseTrack = _tracks[videoTrackIndex];
    final nextTransitions = <TimelineTrackTransitionData>[
      for (final candidate in baseTrack.transitions)
        if (candidate.id != transition.id &&
            !(candidate.leftClipId == transition.leftClipId &&
                candidate.rightClipId == transition.rightClipId))
          candidate,
      transition,
    ];
    final updatedTrack = baseTrack.copyWith(transitions: nextTransitions);
    final sanitizedTransitions = _sanitizeTransitionsForTrack(updatedTrack);
    final nextTracks = List<TimelineTrackData>.from(_tracks);
    nextTracks[videoTrackIndex] = updatedTrack.copyWith(
      transitions: sanitizedTransitions,
    );
    setState(() {
      _tracks = List<TimelineTrackData>.unmodifiable(nextTracks);
      _selectedClipId = null;
      _selectedTransitionId = transition.id;
      if (_activeTab == EditorMediaTab.speed) {
        _activeTab = EditorMediaTab.video;
      }
    });
  }

  void _deleteVideoTrackTransition(String transitionId) {
    final videoTrackIndex = _tracks.indexWhere(
      (track) => track.kind == TimelineTrackKind.video,
    );
    if (videoTrackIndex < 0) {
      return;
    }
    _removeNormalTransitionFromHistoryIfPresent(transitionId);
    final baseTrack = _tracks[videoTrackIndex];
    final nextTransitions = baseTrack.transitions
        .where((transition) => transition.id != transitionId)
        .toList(growable: false);
    final nextTracks = List<TimelineTrackData>.from(_tracks);
    nextTracks[videoTrackIndex] = baseTrack.copyWith(
      transitions: _sanitizeTransitionsForTrack(
        baseTrack.copyWith(transitions: nextTransitions),
      ),
    );
    setState(() {
      _tracks = List<TimelineTrackData>.unmodifiable(nextTracks);
      if (_selectedTransitionId == transitionId) {
        _selectedTransitionId = null;
      }
      if (_transitionFocusSession?.transitionId == transitionId) {
        _transitionFocusSession = null;
        _selectedTransitionFocusKeyframeIndex = null;
        _selectedTransitionFocusKeyframeId = null;
        _isTransitionFocusValueEditorOpen = false;
        _isTransitionFocusGraphEditorOpen = false;
      }
    });
  }

  _TransitionFocusContext? _transitionFocusContextById(String transitionId) {
    final videoTrack = _tracks.where(
      (track) => track.kind == TimelineTrackKind.video,
    );
    if (videoTrack.isEmpty) {
      return null;
    }
    final track = videoTrack.first;
    TimelineTrackTransitionData? transition;
    for (final candidate in _sanitizeTransitionsForTrack(track)) {
      if (candidate.id == transitionId) {
        transition = candidate;
        break;
      }
    }
    if (transition == null) {
      return null;
    }
    final positionedClips = _positionedMediaClipsForTrack(track);
    final clipById = <String, _PositionedTimelineTrackClip>{
      for (final positionedClip in positionedClips)
        positionedClip.clip.id: positionedClip,
    };
    final leftClip = clipById[transition.leftClipId];
    final rightClip = clipById[transition.rightClipId];
    if (leftClip == null || rightClip == null) {
      return null;
    }
    final seamTime = leftClip.endTime;
    final isManualTransition =
        transition.preset == TimelineTransitionPreset.manual;
    final desiredEditorLeading = isManualTransition
        ? _manualTransitionScopeSideTime
        : transition.resolvedLeadingDurationTime;
    final desiredEditorTrailing = isManualTransition
        ? _manualTransitionScopeSideTime
        : transition.resolvedTrailingDurationTime;
    final editorLeading = desiredEditorLeading.clamp(
      leftClip.clip.durationTime < _minEditableClipDurationTime
          ? TimelineTime.zero
          : _minEditableClipDurationTime,
      leftClip.clip.durationTime,
    );
    final editorTrailing = desiredEditorTrailing.clamp(
      rightClip.clip.durationTime < _minEditableClipDurationTime
          ? TimelineTime.zero
          : _minEditableClipDurationTime,
      rightClip.clip.durationTime,
    );
    final startTime = (seamTime - editorLeading).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    final endTime = (seamTime + editorTrailing).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    if (endTime <= startTime) {
      return null;
    }
    final activeStartTime =
        (seamTime - transition.resolvedLeadingDurationTime).clamp(
      startTime,
      seamTime,
    );
    final activeEndTime =
        (seamTime + transition.resolvedTrailingDurationTime).clamp(
      seamTime,
      endTime,
    );
    if (activeEndTime <= activeStartTime) {
      return null;
    }
    return _TransitionFocusContext(
      transition: transition,
      leftClip: leftClip.clip,
      rightClip: rightClip.clip,
      seamTime: seamTime,
      activeStartTime: activeStartTime,
      activeEndTime: activeEndTime,
      startTime: startTime,
      endTime: endTime,
    );
  }

  String _clipPresentationLabel(
    TimelineClipData clip, {
    required String fallback,
  }) {
    final directLabel = clip.label?.trim();
    if (directLabel != null && directLabel.isNotEmpty) {
      return directLabel;
    }
    final assetId = clip.assetId;
    if (assetId != null) {
      final assetLabel = _assetForId(assetId)?.label.trim();
      if (assetLabel != null && assetLabel.isNotEmpty) {
        return assetLabel;
      }
    }
    return fallback;
  }

  String _transitionFocusScopedClipId(
    _TransitionFocusContext context,
    _TransitionFocusClipSide side,
  ) {
    return '${context.transition.id}::focus-${side.name}';
  }

  TimelineTime _transitionFocusScopedDuration(
    _TransitionFocusContext context,
    _TransitionFocusClipSide side,
  ) {
    return switch (side) {
      _TransitionFocusClipSide.left => context.seamTime - context.startTime,
      _TransitionFocusClipSide.right => context.endTime - context.seamTime,
    };
  }

  TimelineTime _transitionFocusScopedClipStartTime(
    _TransitionFocusContext context,
    _TransitionFocusClipSide side,
  ) {
    return switch (side) {
      _TransitionFocusClipSide.left => TimelineTime.zero,
      _TransitionFocusClipSide.right => context.seamTime - context.startTime,
    };
  }

  TimelineTime _transitionFocusScopedSourceStartTime(
    _TransitionFocusContext context,
    _TransitionFocusClipSide side,
  ) {
    if (side == _TransitionFocusClipSide.right) {
      return context.rightClip.sourceStartTime;
    }
    final leftWindowDuration = _transitionFocusScopedDuration(
      context,
      _TransitionFocusClipSide.left,
    );
    final sourceWindowMs =
        (leftWindowDuration.inMilliseconds * context.leftClip.playbackRate)
            .round();
    final sourceEndTime =
        context.leftClip.sourceStartTime + context.leftClip.sourceDurationTime;
    return sourceEndTime - TimelineTime.fromMilliseconds(sourceWindowMs);
  }

  _TransitionFocusClipSide? _transitionFocusClipSideForScopedId(
    _TransitionFocusContext context,
    String clipId,
  ) {
    if (clipId ==
        _transitionFocusScopedClipId(
          context,
          _TransitionFocusClipSide.left,
        )) {
      return _TransitionFocusClipSide.left;
    }
    if (clipId ==
        _transitionFocusScopedClipId(
          context,
          _TransitionFocusClipSide.right,
        )) {
      return _TransitionFocusClipSide.right;
    }
    return null;
  }

  TimelineTrimSelection? _transitionFocusTrimSelection(
    _TransitionFocusContext context,
  ) {
    final selectedClipId = _selectedClipId;
    if (selectedClipId == null) {
      return null;
    }
    final clipSide =
        _transitionFocusClipSideForScopedId(context, selectedClipId);
    if (clipSide == null) {
      return null;
    }
    final clip = clipSide == _TransitionFocusClipSide.left
        ? context.leftClip
        : context.rightClip;
    final localClipStartTime = _transitionFocusScopedClipStartTime(
      context,
      clipSide,
    );
    final localDurationTime = _transitionFocusScopedDuration(context, clipSide);
    final localCurrentTime = _transitionFocusLocalTime(context, _currentTime);
    final localClipEndTime = localClipStartTime + localDurationTime;
    final playheadBarrierTime = localCurrentTime >= localClipStartTime &&
            localCurrentTime <= localClipEndTime
        ? localCurrentTime
        : null;
    final assetDurationSeconds = clip.assetId == null
        ? null
        : _assetForId(clip.assetId!)?.durationSeconds;
    return TimelineTrimSelection(
      clipId: selectedClipId,
      trackKind: TimelineTrackKind.video,
      clipStartTime: localClipStartTime,
      durationTime: localDurationTime,
      sourceStartTime: _transitionFocusScopedSourceStartTime(context, clipSide),
      sourceDurationTime: TimelineTime.fromMilliseconds(
        (localDurationTime.inMilliseconds * clip.playbackRate).round(),
      ),
      playbackRate: clip.playbackRate,
      minDurationTime: _minEditableClipDurationTime,
      playheadBarrierTime: playheadBarrierTime,
      assetDurationTime: assetDurationSeconds == null
          ? null
          : TimelineTime.fromSecondsDouble(assetDurationSeconds),
    );
  }

  void _handleTransitionFocusClipSelected(
    _TransitionFocusContext context,
    String clipId,
  ) {
    if (_transitionFocusClipSideForScopedId(context, clipId) == null) {
      return;
    }
    setState(() {
      _selectedClipId = clipId;
    });
  }

  void _clearTransitionFocusSelection() {
    if (_selectedClipId == null &&
        _selectedTransitionFocusKeyframeIndex == null &&
        !_isTransitionFocusValueEditorOpen) {
      return;
    }
    setState(() {
      _selectedClipId = null;
      _selectedTransitionFocusKeyframeIndex = null;
      _selectedTransitionFocusKeyframeId = null;
      _isTransitionFocusValueEditorOpen = false;
    });
  }

  void _handleTransitionFocusTrimPreviewChanged(
    _TransitionFocusContext context,
    TimelineTrimPreviewRequest? request,
  ) {
    if (request == null) {
      return;
    }
    final localDuration = context.endTime - context.startTime;
    final localTime = request.timelinePreviewTime.clamp(
      TimelineTime.zero,
      localDuration,
    );
    final nextGlobalTime = (context.startTime + localTime).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    _handleTimelineTimeChanged(nextGlobalTime);
  }

  void _handleTransitionFocusTrimCommit(
    _TransitionFocusContext context,
    TimelineTrimCommitRequest request,
  ) {
    final clipSide =
        _transitionFocusClipSideForScopedId(context, request.clipId);
    if (clipSide == null) {
      return;
    }
    TimelineTime nextStartTime = context.startTime;
    TimelineTime nextEndTime = context.endTime;
    if (clipSide == _TransitionFocusClipSide.left) {
      nextStartTime = (context.seamTime - request.durationTime).clamp(
        TimelineTime.zero,
        context.seamTime - _minEditableClipDurationTime,
      );
    } else {
      nextEndTime = (context.seamTime + request.durationTime).clamp(
        context.seamTime + _minEditableClipDurationTime,
        _timelineDurationTime,
      );
    }
    if (nextEndTime <= nextStartTime) {
      return;
    }
    final nextLeading = context.seamTime - nextStartTime;
    final nextTrailing = nextEndTime - context.seamTime;
    final nextDuration = nextLeading + nextTrailing;
    _updateTransitionFocusTransition(
      context.transition.id,
      preserveProgress: true,
      update: (current) => current.copyWith(
        durationTime: nextDuration,
        leadingDurationTime: nextLeading,
        trailingDurationTime: nextTrailing,
      ),
    );
  }

  TimelineTime _transitionFocusLocalTime(
    _TransitionFocusContext context,
    TimelineTime timelineTime,
  ) {
    final clampedTime = timelineTime.clamp(context.startTime, context.endTime);
    return clampedTime - context.startTime;
  }

  List<double> _defaultTransitionFocusLaneValues(String laneId) {
    return switch (laneId) {
      'outgoingBoostScale' => const <double>[100.0, 105.0],
      'incomingStartScale' => const <double>[118.0, 100.0],
      'outgoingOffsetX' => const <double>[0.0, -100.0],
      'incomingOffsetX' => const <double>[100.0, 0.0],
      'outgoingOffsetY' => const <double>[0.0, -36.0],
      'incomingOffsetY' => const <double>[36.0, 0.0],
      'outgoingRotation' => const <double>[0.0, -4.0],
      'incomingRotation' => const <double>[4.0, 0.0],
      'entryDelay' => const <double>[18.0],
      'bridgeDarkness' => const <double>[0.0, 22.0, 0.0],
      'blackPeak' => const <double>[0.0, 100.0, 100.0, 0.0],
      'whiteFlash' => const <double>[0.0, 88.0, 0.0],
      'blurAmount' => const <double>[0.0, 10.0, 0.0],
      'outgoingOpacity' => const <double>[100.0, 0.0],
      'incomingOpacity' => const <double>[0.0, 100.0],
      _ => const <double>[0.0, 100.0],
    };
  }

  TimelineAnimationLaneData? _emptyTransitionFocusManualLane({
    required String laneId,
    required String targetClipId,
  }) {
    final spec = _transitionLaneLibrary[laneId];
    if (spec == null) {
      return null;
    }
    return TimelineAnimationLaneData(
      id: laneId,
      label: spec.label,
      targetClipId: targetClipId,
      normalizedKeyframeStops: const <double>[],
      keyframeIds: const <String>[],
      keyframeValues: const <double>[],
      trackSpanStartProgress: 0,
      trackSpanEndProgress: 1,
    );
  }

  bool _isLegacyTriangularBlackMixLane(TimelineAnimationLaneData lane) {
    if (lane.id != 'blackPeak' || lane.normalizedKeyframeStops.length != 3) {
      return false;
    }
    final stops = lane.normalizedKeyframeStops;
    final values = lane.alignedKeyframeValues(
      fallbackValue: 0.0,
      clampToPercent: false,
    );
    if (values.length != 3) {
      return false;
    }
    bool close(double left, double right) => (left - right).abs() <= 0.0005;
    return close(stops[0], 0.0) &&
        close(stops[1], 0.5) &&
        close(stops[2], 1.0) &&
        close(values[0], 0.0) &&
        close(values[1], 100.0) &&
        close(values[2], 0.0);
  }

  bool _isDefaultTransitionFocusLane(TimelineAnimationLaneData lane) {
    final spec = _transitionLaneLibrary[lane.id];
    if (spec == null ||
        lane.normalizedKeyframeStops.length != spec.keyframeStops.length) {
      return false;
    }
    bool close(double left, double right) => (left - right).abs() <= 0.0005;
    for (var index = 0; index < spec.keyframeStops.length; index++) {
      if (!close(
          lane.normalizedKeyframeStops[index], spec.keyframeStops[index])) {
        return false;
      }
    }
    final expectedValues = _defaultTransitionFocusLaneValues(lane.id);
    final values = lane.alignedKeyframeValues(
      fallbackValue:
          expectedValues.isEmpty ? spec.fallback : expectedValues.first,
      clampToPercent: false,
    );
    if (values.length != expectedValues.length) {
      return false;
    }
    for (var index = 0; index < expectedValues.length; index++) {
      if (!close(values[index], expectedValues[index])) {
        return false;
      }
    }
    return true;
  }

  bool _isAutoSeededTransitionFocusLane(TimelineAnimationLaneData lane) {
    final stops = lane.normalizedKeyframeStops;
    if (stops.isEmpty || lane.keyframeIds.length != stops.length) {
      return false;
    }
    for (var index = 0; index < stops.length; index++) {
      final expectedId = '${lane.id}@${(stops[index] * 1000).round()}#$index';
      if (lane.keyframeIds[index] != expectedId) {
        return false;
      }
    }
    return true;
  }

  List<double> _presetTransitionFocusLaneValues(
    TimelineTrackTransitionData transition,
    String laneId,
  ) {
    final baseValues = _defaultTransitionFocusLaneValues(laneId);
    double percentParameter(
      String key, {
      required double fallback,
      double multiplier = 100.0,
    }) {
      final raw = transition.parameterValue(key, fallback: fallback);
      return raw.abs() <= 2.0 ? raw * multiplier : raw;
    }

    switch (transition.preset) {
      case TimelineTransitionPreset.crossDissolve:
        return switch (laneId) {
          'outgoingOpacity' => const <double>[100.0, 0.0],
          'incomingOpacity' => const <double>[0.0, 100.0],
          _ => baseValues,
        };
      case TimelineTransitionPreset.fadeBlack:
        final peak = percentParameter('blackPeak', fallback: 0.94);
        return laneId == 'blackPeak'
            ? <double>[0.0, peak, peak, 0.0]
            : baseValues;
      case TimelineTransitionPreset.whiteFlash:
        final peak = percentParameter('flashPeak', fallback: 0.88);
        return laneId == 'whiteFlash' ? <double>[0.0, peak, 0.0] : baseValues;
      case TimelineTransitionPreset.blurDissolve:
        final peak = transition.parameterValue('maxBlur', fallback: 10.0);
        return switch (laneId) {
          'blackPeak' => const <double>[0.0, 18.0, 18.0, 0.0],
          'blurAmount' => <double>[0.0, peak, 0.0],
          _ => baseValues,
        };
      case TimelineTransitionPreset.pushLeft:
      case TimelineTransitionPreset.slideBlurLeft:
        final distance = percentParameter('distance', fallback: 1.0);
        return switch (laneId) {
          'outgoingOffsetX' => <double>[0.0, -distance],
          'incomingOffsetX' => <double>[distance, 0.0],
          'blurAmount' => <double>[
              0.0,
              transition.parameterValue('maxBlur', fallback: 8.0),
              0.0,
            ],
          _ => baseValues,
        };
      case TimelineTransitionPreset.pushRight:
      case TimelineTransitionPreset.slideBlurRight:
        final distance = percentParameter('distance', fallback: 1.0);
        return switch (laneId) {
          'outgoingOffsetX' => <double>[0.0, distance],
          'incomingOffsetX' => <double>[-distance, 0.0],
          'blurAmount' => <double>[
              0.0,
              transition.parameterValue('maxBlur', fallback: 8.0),
              0.0,
            ],
          _ => baseValues,
        };
      case TimelineTransitionPreset.whipPanLeft:
        final distance = percentParameter('distance', fallback: 1.15);
        return switch (laneId) {
          'outgoingOffsetX' => <double>[0.0, -distance],
          'incomingOffsetX' => <double>[distance, 0.0],
          'blurAmount' => <double>[
              0.0,
              transition.parameterValue('maxBlur', fallback: 16.0),
              0.0,
            ],
          'whiteFlash' => <double>[
              0.0,
              percentParameter('flashPeak', fallback: 0.22),
              0.0,
            ],
          _ => baseValues,
        };
      case TimelineTransitionPreset.whipPanRight:
        final distance = percentParameter('distance', fallback: 1.15);
        return switch (laneId) {
          'outgoingOffsetX' => <double>[0.0, distance],
          'incomingOffsetX' => <double>[-distance, 0.0],
          'blurAmount' => <double>[
              0.0,
              transition.parameterValue('maxBlur', fallback: 16.0),
              0.0,
            ],
          'whiteFlash' => <double>[
              0.0,
              percentParameter('flashPeak', fallback: 0.22),
              0.0,
            ],
          _ => baseValues,
        };
      case TimelineTransitionPreset.zoomInCamera:
      case TimelineTransitionPreset.zoomOutCamera:
      case TimelineTransitionPreset.flashZoom:
        return switch (laneId) {
          'outgoingBoostScale' => <double>[
              100.0,
              percentParameter('outgoingBoostScale', fallback: 1.08),
            ],
          'incomingStartScale' => <double>[
              percentParameter('incomingStartScale', fallback: 1.18),
              100.0,
            ],
          'entryDelay' => <double>[
              percentParameter('entryDelay', fallback: 0.18),
            ],
          'bridgeDarkness' => <double>[
              0.0,
              percentParameter('bridgeDarkness', fallback: 0.18),
              0.0,
            ],
          'whiteFlash' => <double>[
              0.0,
              percentParameter('flashPeak', fallback: 0.72),
              0.0,
            ],
          _ => baseValues,
        };
      case TimelineTransitionPreset.manual:
      case TimelineTransitionPreset.aiGenerated:
        return baseValues;
    }
  }

  TimelineTrackTransitionData _materializeTransitionPresetForFocus(
    _TransitionFocusContext context,
  ) {
    final transition = context.transition;
    if (transition.preset == TimelineTransitionPreset.manual ||
        transition.preset == TimelineTransitionPreset.aiGenerated) {
      return transition;
    }
    final laneSpecs = _transitionFocusLaneSpecs(transition);
    if (laneSpecs.isEmpty) {
      return transition;
    }
    final manualLanes = <TimelineAnimationLaneData>[];
    for (final spec in laneSpecs) {
      final stops = _transitionFocusScopeStopsForActiveStops(
        context,
        spec.keyframeStops,
      );
      manualLanes.add(
        TimelineAnimationLaneData(
          id: spec.id,
          label: spec.label,
          targetClipId: transition.leftClipId,
          normalizedKeyframeStops: List<double>.unmodifiable(stops),
          keyframeIds: List<String>.unmodifiable(
            <String>[
              for (var index = 0; index < stops.length; index++)
                'preset.${transition.id}.${spec.id}.$index.${(stops[index] * 1000).round()}',
            ],
          ),
          keyframeValues: List<double>.unmodifiable(
            _presetTransitionFocusLaneValues(transition, spec.id),
          ),
          trackSpanStartProgress: 0,
          trackSpanEndProgress: 1,
        ),
      );
    }
    return transition.copyWith(
      preset: TimelineTransitionPreset.manual,
      manualEffectIds: List<String>.unmodifiable(
        <String>[for (final lane in manualLanes) lane.id],
      ),
      manualAnimationLanes: List<TimelineAnimationLaneData>.unmodifiable(
        manualLanes,
      ),
    );
  }

  TimelineAnimationLaneData _normalizeTransitionFocusManualLane(
    TimelineAnimationLaneData lane,
    _TransitionFocusContext? scopeContext,
  ) {
    final isAutoSeeded = _isAutoSeededTransitionFocusLane(lane);
    if (isAutoSeeded &&
        (_isLegacyTriangularBlackMixLane(lane) ||
            (scopeContext != null && _isDefaultTransitionFocusLane(lane)))) {
      final normalizedLane = _emptyTransitionFocusManualLane(
        laneId: lane.id,
        targetClipId: lane.targetClipId,
      );
      if (normalizedLane != null) {
        return normalizedLane;
      }
    }
    return lane;
  }

  TimelineTrackTransitionData _normalizeTransitionFocusManualTransition(
    TimelineTrackTransitionData transition,
    _TransitionFocusContext? scopeContext,
  ) {
    if (transition.manualAnimationLanes.isEmpty) {
      return transition;
    }
    var changed = false;
    final normalizedLanes = <TimelineAnimationLaneData>[
      for (final lane in transition.manualAnimationLanes)
        (() {
          final normalized = _normalizeTransitionFocusManualLane(
            lane,
            scopeContext,
          );
          changed = changed || normalized != lane;
          return normalized;
        })(),
    ];
    if (!changed) {
      return transition;
    }
    return transition.copyWith(
      manualAnimationLanes: List<TimelineAnimationLaneData>.unmodifiable(
        normalizedLanes,
      ),
    );
  }

  List<TimelineAnimationLaneData> _resolvedTransitionFocusManualLanes(
    TimelineTrackTransitionData transition, {
    required String targetClipId,
    _TransitionFocusContext? scopeContext,
  }) {
    final lanes = <TimelineAnimationLaneData>[];
    final seenLaneIds = <String>{};
    if (transition.manualAnimationLanes.isNotEmpty) {
      for (final lane in transition.manualAnimationLanes) {
        final normalized = _normalizeTransitionFocusManualLane(
          lane,
          scopeContext,
        ).copyWith(targetClipId: targetClipId);
        lanes.add(normalized);
        seenLaneIds.add(normalized.id);
      }
    }
    for (final laneId in transition.manualEffectIds) {
      if (seenLaneIds.contains(laneId)) {
        continue;
      }
      final lane = _emptyTransitionFocusManualLane(
        laneId: laneId,
        targetClipId: targetClipId,
      );
      if (lane != null) {
        lanes.add(lane);
        seenLaneIds.add(lane.id);
      }
    }
    return List<TimelineAnimationLaneData>.unmodifiable(lanes);
  }

  TimelineAnimationLaneData? _transitionFocusSelectedAnimationLane(
    _TransitionFocusContext context,
  ) {
    final lanes = _resolvedTransitionFocusManualLanes(
      context.transition,
      targetClipId: context.leftClip.id,
      scopeContext: context,
    );
    if (lanes.isEmpty) {
      return null;
    }
    final selectedLaneId = _transitionFocusSession?.selectedLaneId;
    final effectiveLaneId = selectedLaneId == null || selectedLaneId.isEmpty
        ? _resolvedTransitionFocusLaneId(context)
        : selectedLaneId;
    if (effectiveLaneId.isEmpty) {
      return lanes.first;
    }
    for (final lane in lanes) {
      if (lane.id == selectedLaneId) {
        return lane;
      }
    }
    for (final lane in lanes) {
      if (lane.id == effectiveLaneId) {
        return lane;
      }
    }
    return lanes.first;
  }

  List<TimelineTrackData> _buildTransitionFocusScopedTracks(
    _TransitionFocusContext context,
    List<_TransitionFocusLaneSpec> laneSpecs,
  ) {
    final leftDurationTime = _transitionFocusScopedDuration(
      context,
      _TransitionFocusClipSide.left,
    );
    final rightDurationTime = _transitionFocusScopedDuration(
      context,
      _TransitionFocusClipSide.right,
    );
    final leftScopedClipId = _transitionFocusScopedClipId(
      context,
      _TransitionFocusClipSide.left,
    );
    final rightScopedClipId = _transitionFocusScopedClipId(
      context,
      _TransitionFocusClipSide.right,
    );

    final leftScopedClip = context.leftClip.copyWith(
      id: leftScopedClipId,
      label: _clipPresentationLabel(context.leftClip, fallback: 'Clip A'),
      durationTime: leftDurationTime,
      sourceDurationTime: TimelineTime.fromMilliseconds(
        (leftDurationTime.inMilliseconds * context.leftClip.playbackRate)
            .round(),
      ),
      sourceStartTime: _transitionFocusScopedSourceStartTime(
        context,
        _TransitionFocusClipSide.left,
      ),
    );
    final rightScopedClip = context.rightClip.copyWith(
      id: rightScopedClipId,
      label: _clipPresentationLabel(context.rightClip, fallback: 'Clip B'),
      durationTime: rightDurationTime,
      sourceDurationTime: TimelineTime.fromMilliseconds(
        (rightDurationTime.inMilliseconds * context.rightClip.playbackRate)
            .round(),
      ),
      sourceStartTime: _transitionFocusScopedSourceStartTime(
        context,
        _TransitionFocusClipSide.right,
      ),
    );
    final animationLanes =
        context.transition.preset == TimelineTransitionPreset.manual
            ? _resolvedTransitionFocusManualLanes(
                context.transition,
                targetClipId: leftScopedClipId,
                scopeContext: context,
              )
            : laneSpecs.map(
                (lane) {
                  final stops = _transitionFocusScopeStopsForActiveStops(
                    context,
                    lane.keyframeStops,
                  );
                  return TimelineAnimationLaneData(
                    id: lane.id,
                    label: lane.label,
                    targetClipId: leftScopedClipId,
                    normalizedKeyframeStops: List<double>.unmodifiable(stops),
                    keyframeIds: List<String>.unmodifiable(
                      <String>[
                        for (var index = 0; index < stops.length; index++)
                          '${lane.id}@${(stops[index] * 1000).round()}#$index',
                      ],
                    ),
                    keyframeValues: List<double>.unmodifiable(
                      _defaultTransitionFocusLaneValues(lane.id),
                    ),
                    trackSpanStartProgress: 0,
                    trackSpanEndProgress: 1,
                  );
                },
              ).toList(growable: false);
    final scopedAnimationLanes = animationLanes
        .map(
          (lane) => lane.copyWith(
            trackSpanStartProgress: 0,
            trackSpanEndProgress: 1,
          ),
        )
        .toList(growable: false);

    return <TimelineTrackData>[
      TimelineTrackData(
        kind: TimelineTrackKind.video,
        clips: <TimelineClipData>[
          leftScopedClip,
          rightScopedClip,
        ],
        animationLanes: scopedAnimationLanes,
      ),
    ];
  }

  static const Map<String, _TransitionFocusLaneSpec> _transitionLaneLibrary =
      <String, _TransitionFocusLaneSpec>{
    'outgoingBoostScale': _TransitionFocusLaneSpec(
      id: 'outgoingBoostScale',
      groupLabel: 'Outgoing',
      label: 'Outgoing Scale',
      editorDescription:
          'Pushes the left clip forward before the handoff into the next shot.',
      min: 100.0,
      max: 125.0,
      fallback: 100.0,
      tint: Color(0xFF82E6FF),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionScale,
    ),
    'incomingStartScale': _TransitionFocusLaneSpec(
      id: 'incomingStartScale',
      groupLabel: 'Incoming',
      label: 'Incoming Scale',
      editorDescription:
          'Starts the next clip close, then relaxes it back to full frame.',
      min: 100.0,
      max: 145.0,
      fallback: 100.0,
      tint: Color(0xFF8DFFAE),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionScale,
    ),
    'outgoingOffsetX': _TransitionFocusLaneSpec(
      id: 'outgoingOffsetX',
      groupLabel: 'Outgoing',
      label: 'Outgoing Slide X',
      editorDescription:
          'Moves the outgoing clip horizontally across the seam.',
      min: -120.0,
      max: 120.0,
      fallback: 0.0,
      tint: Color(0xFF74D8FF),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'incomingOffsetX': _TransitionFocusLaneSpec(
      id: 'incomingOffsetX',
      groupLabel: 'Incoming',
      label: 'Incoming Slide X',
      editorDescription: 'Moves the incoming clip horizontally into the seam.',
      min: -120.0,
      max: 120.0,
      fallback: 0.0,
      tint: Color(0xFF7DFFB2),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'outgoingOffsetY': _TransitionFocusLaneSpec(
      id: 'outgoingOffsetY',
      groupLabel: 'Outgoing',
      label: 'Outgoing Slide Y',
      editorDescription: 'Moves the outgoing clip vertically across the seam.',
      min: -120.0,
      max: 120.0,
      fallback: 0.0,
      tint: Color(0xFF74D8FF),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'incomingOffsetY': _TransitionFocusLaneSpec(
      id: 'incomingOffsetY',
      groupLabel: 'Incoming',
      label: 'Incoming Slide Y',
      editorDescription: 'Moves the incoming clip vertically into the seam.',
      min: -120.0,
      max: 120.0,
      fallback: 0.0,
      tint: Color(0xFF7DFFB2),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'outgoingRotation': _TransitionFocusLaneSpec(
      id: 'outgoingRotation',
      groupLabel: 'Outgoing',
      label: 'Outgoing Rotation',
      editorDescription: 'Rotates the outgoing clip through the handoff.',
      min: -45.0,
      max: 45.0,
      fallback: 0.0,
      tint: Color(0xFF8FD8FF),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionDegrees,
    ),
    'incomingRotation': _TransitionFocusLaneSpec(
      id: 'incomingRotation',
      groupLabel: 'Incoming',
      label: 'Incoming Rotation',
      editorDescription: 'Rotates the incoming clip into final alignment.',
      min: -45.0,
      max: 45.0,
      fallback: 0.0,
      tint: Color(0xFF90FFCB),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionDegrees,
    ),
    'entryDelay': _TransitionFocusLaneSpec(
      id: 'entryDelay',
      groupLabel: 'Timing',
      label: 'Entry Delay',
      editorDescription:
          'Offsets when the incoming clip starts taking over inside the seam.',
      min: 0.0,
      max: 48.0,
      fallback: 0.0,
      tint: Color(0xFFFFD98A),
      keyframeStops: <double>[0.0, 0.3, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'bridgeDarkness': _TransitionFocusLaneSpec(
      id: 'bridgeDarkness',
      groupLabel: 'Visual',
      label: 'Bridge Darkness',
      editorDescription:
          'Adds a cinematic darkening pulse so the seam feels deeper and less abrupt.',
      min: 0.0,
      max: 65.0,
      fallback: 0.0,
      tint: Color(0xFFFFA7C9),
      keyframeStops: <double>[0.0, 0.5, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'blackPeak': _TransitionFocusLaneSpec(
      id: 'blackPeak',
      groupLabel: 'Visual',
      label: 'Black Mix',
      editorDescription:
          'Controls how hard the seam dips through black at the midpoint.',
      min: 0.0,
      max: 100.0,
      fallback: 0.0,
      tint: Color(0xFFB5C0D9),
      keyframeStops: <double>[0.0, 0.46, 0.54, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'whiteFlash': _TransitionFocusLaneSpec(
      id: 'whiteFlash',
      groupLabel: 'Visual',
      label: 'White Flash',
      editorDescription:
          'Adds a bright flash pulse to hide a hard visual seam.',
      min: 0.0,
      max: 100.0,
      fallback: 0.0,
      tint: Color(0xFFFFF5B8),
      keyframeStops: <double>[0.0, 0.5, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'blurAmount': _TransitionFocusLaneSpec(
      id: 'blurAmount',
      groupLabel: 'Visual',
      label: 'Blur Amount',
      editorDescription:
          'Softens the seam with Gaussian-style blur during fast motion.',
      min: 0.0,
      max: 24.0,
      fallback: 0.0,
      tint: Color(0xFFC5B8FF),
      keyframeStops: <double>[0.0, 0.5, 1.0],
      valueFormatter: _formatTransitionPixels,
    ),
    'outgoingOpacity': _TransitionFocusLaneSpec(
      id: 'outgoingOpacity',
      groupLabel: 'Visual',
      label: 'Outgoing Opacity',
      editorDescription: 'Fades the outgoing clip with direct opacity keys.',
      min: 0.0,
      max: 100.0,
      fallback: 100.0,
      tint: Color(0xFFB5C0D9),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
    'incomingOpacity': _TransitionFocusLaneSpec(
      id: 'incomingOpacity',
      groupLabel: 'Visual',
      label: 'Incoming Opacity',
      editorDescription: 'Fades the incoming clip with direct opacity keys.',
      min: 0.0,
      max: 100.0,
      fallback: 0.0,
      tint: Color(0xFFB5F0D0),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
  };

  List<_TransitionFocusLaneSpec> _transitionFocusLaneSpecs(
    TimelineTrackTransitionData transition,
  ) {
    final laneIds = <String>[
      if (transition.preset == TimelineTransitionPreset.manual) ...[
        ...transition.manualEffectIds,
        for (final lane in transition.manualAnimationLanes)
          if (!transition.manualEffectIds.contains(lane.id)) lane.id,
      ] else
        ...switch (transition.preset) {
          TimelineTransitionPreset.crossDissolve => const <String>[
              'outgoingOpacity',
              'incomingOpacity',
            ],
          TimelineTransitionPreset.fadeBlack => const <String>['blackPeak'],
          TimelineTransitionPreset.whiteFlash => const <String>['whiteFlash'],
          TimelineTransitionPreset.zoomInCamera => const <String>[
              'outgoingBoostScale',
              'incomingStartScale',
              'entryDelay',
              'bridgeDarkness',
            ],
          TimelineTransitionPreset.zoomOutCamera => const <String>[
              'outgoingBoostScale',
              'incomingStartScale',
              'bridgeDarkness',
            ],
          TimelineTransitionPreset.blurDissolve => const <String>[
              'blackPeak',
              'blurAmount',
            ],
          TimelineTransitionPreset.pushLeft => const <String>[
              'outgoingOffsetX',
              'incomingOffsetX',
            ],
          TimelineTransitionPreset.pushRight => const <String>[
              'outgoingOffsetX',
              'incomingOffsetX',
            ],
          TimelineTransitionPreset.whipPanLeft ||
          TimelineTransitionPreset.whipPanRight =>
            const <String>[
              'outgoingOffsetX',
              'incomingOffsetX',
              'blurAmount',
              'whiteFlash',
            ],
          TimelineTransitionPreset.slideBlurLeft ||
          TimelineTransitionPreset.slideBlurRight =>
            const <String>[
              'outgoingOffsetX',
              'incomingOffsetX',
              'blurAmount',
            ],
          TimelineTransitionPreset.flashZoom => const <String>[
              'outgoingBoostScale',
              'incomingStartScale',
              'whiteFlash',
              'bridgeDarkness',
            ],
          TimelineTransitionPreset.aiGenerated => const <String>[],
          TimelineTransitionPreset.manual => const <String>[],
        },
    ];
    final specs = <_TransitionFocusLaneSpec>[];
    for (final laneId in laneIds) {
      final baseSpec = _transitionLaneLibrary[laneId];
      if (baseSpec == null) {
        continue;
      }
      if (laneId == 'entryDelay') {
        final delay = transition
            .parameterValue(
              'entryDelay',
              fallback: baseSpec.fallback,
            )
            .clamp(0.0, 1.0);
        specs.add(
          baseSpec.copyWith(
            keyframeStops: <double>[0.0, delay, 1.0],
          ),
        );
        continue;
      }
      if (laneId == 'incomingStartScale') {
        final delay = transition
            .parameterValue(
              'entryDelay',
              fallback: 0.0,
            )
            .clamp(0.0, 1.0);
        specs.add(
          baseSpec.copyWith(
            keyframeStops: <double>[delay, 1.0],
          ),
        );
        continue;
      }
      specs.add(baseSpec);
    }
    return specs;
  }

  String _resolvedTransitionFocusLaneId(
    _TransitionFocusContext context, {
    String? preferredLaneId,
  }) {
    final lanes = _transitionFocusLaneSpecs(context.transition);
    if (lanes.isEmpty) {
      return '';
    }
    if (preferredLaneId != null &&
        lanes.any((lane) => lane.id == preferredLaneId)) {
      return preferredLaneId;
    }
    final activeLaneId = _transitionFocusSession?.selectedLaneId;
    if (activeLaneId != null && lanes.any((lane) => lane.id == activeLaneId)) {
      return activeLaneId;
    }
    return lanes.first.id;
  }

  double _transitionFocusProgressForTime(
    _TransitionFocusContext context,
    TimelineTime timelineTime,
  ) {
    final totalSpan = (context.endTime - context.startTime).inMilliseconds;
    if (totalSpan <= 0) {
      return 0.0;
    }
    final clampedTime = timelineTime.clamp(context.startTime, context.endTime);
    final elapsed = (clampedTime - context.startTime).inMilliseconds;
    return (elapsed / totalSpan).clamp(0.0, 1.0).toDouble();
  }

  ({double start, double end}) _transitionFocusActiveSpanProgress(
    _TransitionFocusContext context,
  ) {
    final editorSpanMs = (context.endTime - context.startTime).inMilliseconds;
    if (editorSpanMs <= 0) {
      return (start: 0.0, end: 1.0);
    }
    final start =
        ((context.activeStartTime - context.startTime).inMilliseconds /
                editorSpanMs)
            .clamp(0.0, 1.0)
            .toDouble();
    final end = ((context.activeEndTime - context.startTime).inMilliseconds /
            editorSpanMs)
        .clamp(0.0, 1.0)
        .toDouble();
    if (end <= start) {
      return (start: 0.0, end: 1.0);
    }
    return (start: start, end: end);
  }

  ({double start, double end})? _manualTransitionAuthoredEffectProgressRange(
    TimelineTrackTransitionData transition,
  ) {
    if (transition.preset != TimelineTransitionPreset.manual ||
        transition.manualAnimationLanes.isEmpty) {
      return null;
    }
    double? rangeStart;
    double? rangeEnd;
    const epsilon = 0.0001;

    void include(double start, double end) {
      final clampedStart = start.clamp(0.0, 1.0).toDouble();
      final clampedEnd = end.clamp(0.0, 1.0).toDouble();
      final orderedStart = math.min(clampedStart, clampedEnd);
      final orderedEnd = math.max(clampedStart, clampedEnd);
      rangeStart = rangeStart == null
          ? orderedStart
          : math.min(rangeStart!, orderedStart);
      rangeEnd =
          rangeEnd == null ? orderedEnd : math.max(rangeEnd!, orderedEnd);
    }

    for (final lane in transition.manualAnimationLanes) {
      if (!transition.manualEffectIds.contains(lane.id) ||
          lane.normalizedKeyframeStops.isEmpty) {
        continue;
      }
      final spec = _transitionLaneLibrary[lane.id];
      if (spec == null) {
        continue;
      }
      final values = lane.alignedKeyframeValues(
        fallbackValue: spec.fallback,
        clampToPercent: false,
      );
      final keyframes = <({double stop, double value})>[
        for (var index = 0;
            index < lane.normalizedKeyframeStops.length;
            index++)
          (
            stop:
                lane.normalizedKeyframeStops[index].clamp(0.0, 1.0).toDouble(),
            value: values[index],
          ),
      ]..sort((left, right) => left.stop.compareTo(right.stop));
      if (keyframes.isEmpty) {
        continue;
      }
      bool differsFromFallback(double value) =>
          (value - spec.fallback).abs() > epsilon;

      if (keyframes.length == 1) {
        if (differsFromFallback(keyframes.first.value)) {
          include(0.0, 1.0);
        }
        continue;
      }

      if (differsFromFallback(keyframes.first.value)) {
        include(0.0, keyframes.first.stop);
      }
      for (var index = 1; index < keyframes.length; index++) {
        final previous = keyframes[index - 1];
        final current = keyframes[index];
        if (differsFromFallback(previous.value) ||
            differsFromFallback(current.value) ||
            (current.value - previous.value).abs() > epsilon) {
          include(previous.stop, current.stop);
        }
      }
      if (differsFromFallback(keyframes.last.value)) {
        include(keyframes.last.stop, 1.0);
      }
    }

    if (rangeStart == null || rangeEnd == null) {
      return null;
    }
    final start = rangeStart!.clamp(0.0, 1.0).toDouble();
    final end = rangeEnd!.clamp(0.0, 1.0).toDouble();
    if (end - start <= epsilon) {
      const minWindow = 0.015;
      final center = ((start + end) / 2).clamp(0.0, 1.0).toDouble();
      return (
        start: (center - (minWindow / 2)).clamp(0.0, 1.0).toDouble(),
        end: (center + (minWindow / 2)).clamp(0.0, 1.0).toDouble(),
      );
    }
    return (start: start, end: end);
  }

  ({TimelineTime start, TimelineTime end})?
      _manualTransitionAuthoredEffectTimeRange(
    _TransitionFocusContext context,
  ) {
    final progressRange =
        _manualTransitionAuthoredEffectProgressRange(context.transition);
    if (progressRange == null) {
      return null;
    }
    final scopeSpanMs = (context.endTime - context.startTime).inMilliseconds;
    if (scopeSpanMs <= 0) {
      return null;
    }
    final start = context.startTime +
        TimelineTime.fromMilliseconds(
          (scopeSpanMs * progressRange.start).round(),
        );
    final end = context.startTime +
        TimelineTime.fromMilliseconds(
          (scopeSpanMs * progressRange.end).round(),
        );
    if (end <= start) {
      return null;
    }
    return (
      start: start.clamp(context.startTime, context.endTime),
      end: end.clamp(context.startTime, context.endTime),
    );
  }

  List<double> _transitionFocusScopeStopsForActiveStops(
    _TransitionFocusContext context,
    List<double> activeStops,
  ) {
    final span = _transitionFocusActiveSpanProgress(context);
    final width = span.end - span.start;
    return <double>[
      for (final stop in activeStops)
        (span.start + (width * stop.clamp(0.0, 1.0)))
            .clamp(0.0, 1.0)
            .toDouble(),
    ];
  }

  void _seekTransitionFocusProgress(
    _TransitionFocusContext context,
    double progress,
  ) {
    final totalSpan = (context.endTime - context.startTime).inMilliseconds;
    final nextTime = context.startTime +
        TimelineTime.fromMilliseconds(
          (totalSpan * progress.clamp(0.0, 1.0)).round(),
        );
    _handleTimelineTimeChanged(nextTime);
  }

  void _enterTransitionFocusMode(
    String transitionId, {
    String? preferredLaneId,
  }) {
    var context = _transitionFocusContextById(transitionId);
    if (context == null) {
      return;
    }
    final materializedTransition = _materializeTransitionPresetForFocus(
      context,
    );
    if (materializedTransition != context.transition) {
      _upsertVideoTrackTransition(materializedTransition);
      context = _transitionFocusContextById(transitionId);
      if (context == null) {
        return;
      }
    }
    if (context.transition.preset == TimelineTransitionPreset.manual) {
      final normalizedTransition = _normalizeTransitionFocusManualTransition(
        context.transition,
        context,
      );
      if (normalizedTransition != context.transition) {
        _upsertVideoTrackTransition(normalizedTransition);
        context = _transitionFocusContextById(transitionId);
        if (context == null) {
          return;
        }
      }
      if (context.transition.manualEffectIds.isNotEmpty &&
          context.transition.manualAnimationLanes.isEmpty) {
        final seededLanes = _resolvedTransitionFocusManualLanes(
          context.transition,
          targetClipId: context.transition.leftClipId,
          scopeContext: context,
        );
        if (seededLanes.isNotEmpty) {
          _upsertVideoTrackTransition(
            context.transition.copyWith(
              manualAnimationLanes: seededLanes,
            ),
          );
          context = _transitionFocusContextById(transitionId);
          if (context == null) {
            return;
          }
        }
      }
    }
    final resolvedLaneId = _resolvedTransitionFocusLaneId(
      context,
      preferredLaneId: preferredLaneId,
    );
    _warmTransitionFocusPreviewAssets(context);
    setState(() {
      _layerScopeSession = null;
      _transitionFocusSession = _TransitionFocusSession(
        transitionId: transitionId,
        selectedLaneId: resolvedLaneId,
      );
      _selectedClipId = null;
      _selectedTransitionId = transitionId;
      _selectedTransitionFocusKeyframeIndex = null;
      _selectedTransitionFocusKeyframeId = null;
      _isTransitionFocusValueEditorOpen = false;
      _isTransitionFocusGraphEditorOpen = false;
      if (_activeTab == EditorMediaTab.speed) {
        _activeTab = EditorMediaTab.video;
      }
    });
    _handleTimelineTimeChanged(context.activeStartTime);
    _syncTransitionFocusTimeNotifiers();
    if (_transportController.isPlaying) {
      unawaited(
        _stopTransitionFocusPlayback(
          context,
          snapToStart: true,
        ),
      );
    }
  }

  void _exitTransitionFocusMode() {
    final session = _transitionFocusSession;
    if (session == null) {
      return;
    }
    final context = _transitionFocusContextById(session.transitionId);
    setState(() {
      _transitionFocusSession = null;
      _selectedClipId = null;
      _selectedTransitionFocusKeyframeIndex = null;
      _selectedTransitionFocusKeyframeId = null;
      _isTransitionFocusValueEditorOpen = false;
      _isTransitionFocusGraphEditorOpen = false;
    });
    _syncTransitionFocusTimeNotifiers();
    if (context != null && _transportController.isPlaying) {
      unawaited(
        _stopTransitionFocusPlayback(
          context,
          snapToStart: false,
        ),
      );
    }
  }

  void _selectTransitionFocusLane(String laneId) {
    final session = _transitionFocusSession;
    if (session == null || session.selectedLaneId == laneId) {
      return;
    }
    setState(() {
      _transitionFocusSession = session.copyWith(selectedLaneId: laneId);
      _selectedTransitionFocusKeyframeIndex = null;
      _selectedTransitionFocusKeyframeId = null;
      _isTransitionFocusValueEditorOpen = false;
    });
  }

  Future<void> _openTransitionFocusAddMenu(String transitionId) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: FxPalette.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border.all(color: FxPalette.divider, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                title: const Text('Animate'),
                subtitle: const Text('Add motion lanes for the transition.'),
                onTap: () => Navigator.of(sheetContext).pop('animate'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.auto_fix_high_rounded,
                  color: Colors.white,
                ),
                title: const Text('FX'),
                subtitle: const Text('Add visual blend lanes like Black Mix.'),
                onTap: () => Navigator.of(sheetContext).pop('fx'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.code_rounded,
                  color: Colors.white,
                ),
                title: const Text('Script'),
                subtitle: const Text(
                  'Paste or upload JSON and convert it to editable lanes.',
                ),
                onTap: () => Navigator.of(sheetContext).pop('script'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'animate':
        await _openManualTransitionAnimateBrowser(transitionId);
        break;
      case 'fx':
        await _openManualTransitionFxBrowser(transitionId);
        break;
      case 'script':
        await _openTransitionScriptImportSheet(transitionId);
        break;
    }
  }

  Future<void> _openTransitionScriptImportSheet(String transitionId) async {
    setState(() {
      _isAnimateBrowserOpen = true;
    });
    final definition = await showModalBottomSheet<NormalTransitionDefinition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: const TransitionScriptImportBottomSheet(),
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnimateBrowserOpen = false;
      });
    });
    if (!mounted || definition == null) {
      return;
    }
    _applyTransitionScriptDefinition(transitionId, definition);
  }

  void _applyTransitionScriptDefinition(
    String transitionId,
    NormalTransitionDefinition definition,
  ) {
    final transition = _videoTrackTransitionById(transitionId);
    if (transition == null) {
      return;
    }
    final mapping = _normalTransitionScriptTimelineMapper.mapDefinition(
      definition: definition,
      targetClipId: transition.leftClipId,
    );
    if (!mapping.hasSupportedLanes) {
      final issueMessage = mapping.issues.isEmpty
          ? 'No editable transition lanes were found in this script.'
          : mapping.issues.first.message;
      _showStageMessage(issueMessage);
      return;
    }
    final importedLaneIds = mapping.effectIds.toSet();
    _updateTransitionFocusTransition(
      transitionId,
      preserveProgress: true,
      update: (current) {
        final nextEffectIds = <String>[
          for (final effectId in current.manualEffectIds)
            if (!importedLaneIds.contains(effectId)) effectId,
          ...mapping.effectIds,
        ];
        final nextLanes = <TimelineAnimationLaneData>[
          for (final lane in current.manualAnimationLanes)
            if (!importedLaneIds.contains(lane.id)) lane,
          ...mapping.lanes,
        ];
        return current.copyWith(
          preset: TimelineTransitionPreset.manual,
          parameterValues: <String, double>{
            ...current.parameterValues,
            ...mapping.parameterValues,
          },
          manualEffectIds: List<String>.unmodifiable(nextEffectIds),
          manualAnimationLanes:
              List<TimelineAnimationLaneData>.unmodifiable(nextLanes),
        );
      },
    );
    _selectTransitionFocusLane(mapping.effectIds.first);
    final warningCount = mapping.issues
        .where(
          (issue) => issue.severity != NormalTransitionIssueSeverity.error,
        )
        .length;
    _showStageMessage(
      warningCount == 0
          ? 'Transition script imported as editable keyframes.'
          : 'Transition script imported with $warningCount warning${warningCount == 1 ? '' : 's'}.',
    );
  }

  Future<void> _openManualTransitionAnimateBrowser(String transitionId) async {
    setState(() {
      _isAnimateBrowserOpen = true;
    });
    final item = await showModalBottomSheet<AnimateBrowserItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: const AnimateBrowserBottomSheet(
          items: _manualTransitionAnimateItems,
        ),
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnimateBrowserOpen = false;
      });
    });
    if (!mounted || item == null) {
      return;
    }
    _addManualTransitionEffect(transitionId, item);
  }

  Future<void> _openManualTransitionFxBrowser(String transitionId) async {
    setState(() {
      _isAnimateBrowserOpen = true;
    });
    final item = await showModalBottomSheet<AnimateBrowserItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: const AnimateBrowserBottomSheet(
          items: _manualTransitionFxItems,
        ),
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnimateBrowserOpen = false;
      });
    });
    if (!mounted || item == null) {
      return;
    }
    _addManualTransitionEffect(transitionId, item);
  }

  void _addManualTransitionEffect(
    String transitionId,
    AnimateBrowserItem item,
  ) {
    final transition = _videoTrackTransitionById(transitionId);
    if (transition == null) {
      return;
    }
    if (transition.manualEffectIds.contains(item.id)) {
      _showStageMessage('${item.label} already exists on this transition.');
      _selectTransitionFocusLane(item.id);
      return;
    }
    final baseSpec = _transitionLaneLibrary[item.id];
    if (baseSpec == null) {
      return;
    }
    final focusContext = _transitionFocusContextById(transitionId);
    if (focusContext != null) {
      _warmTransitionFocusPreviewAssets(focusContext);
    }
    final existingLanes = transition.manualAnimationLanes;
    final nextLane = _emptyTransitionFocusManualLane(
      laneId: item.id,
      targetClipId: transition.leftClipId,
    );
    _updateTransitionFocusTransition(
      transitionId,
      update: (current) => current.copyWith(
        manualEffectIds: <String>[
          ...current.manualEffectIds,
          item.id,
        ],
        parameterValues: <String, double>{
          ...current.parameterValues,
          item.id: current.parameterValue(item.id, fallback: baseSpec.fallback),
        },
        manualAnimationLanes: nextLane == null
            ? current.manualAnimationLanes
            : <TimelineAnimationLaneData>[
                ...existingLanes,
                nextLane,
              ],
      ),
    );
    _selectTransitionFocusLane(item.id);
  }

  void _updateTransitionFocusTransition(
    String transitionId, {
    required TimelineTrackTransitionData Function(
      TimelineTrackTransitionData current,
    ) update,
    bool preserveProgress = false,
  }) {
    final current = _videoTrackTransitionById(transitionId);
    if (current == null) {
      return;
    }
    final existingContext =
        preserveProgress ? _transitionFocusContextById(transitionId) : null;
    final preservedProgress = existingContext == null
        ? null
        : _transitionFocusProgressForTime(
            existingContext,
            _transitionFocusVisibleGlobalTime(existingContext),
          );
    _upsertVideoTrackTransition(update(current));
    if (preservedProgress != null) {
      final nextContext = _transitionFocusContextById(transitionId);
      if (nextContext != null) {
        _seekTransitionFocusProgress(nextContext, preservedProgress);
      }
    }
  }

  void _updateTransitionFocusManualLane(
    String transitionId,
    String laneId,
    TimelineAnimationLaneData Function(TimelineAnimationLaneData lane) update,
  ) {
    _updateTransitionFocusTransition(
      transitionId,
      preserveProgress: true,
      update: (current) {
        final lanes = List<TimelineAnimationLaneData>.from(
          current.manualAnimationLanes,
        );
        final laneIndex = lanes.indexWhere((lane) => lane.id == laneId);
        if (laneIndex >= 0) {
          lanes[laneIndex] = update(lanes[laneIndex]);
        } else {
          final seeded = _emptyTransitionFocusManualLane(
            laneId: laneId,
            targetClipId: current.leftClipId,
          );
          if (seeded != null) {
            lanes.add(update(seeded));
          }
        }
        return current.copyWith(
          manualEffectIds: current.manualEffectIds.contains(laneId)
              ? current.manualEffectIds
              : <String>[...current.manualEffectIds, laneId],
          manualAnimationLanes: List<TimelineAnimationLaneData>.unmodifiable(
            lanes,
          ),
        );
      },
    );
  }

  void _handleTransitionFocusAnimationKeyframeTap(
    String laneId,
    int keyframeIndex,
    String keyframeId,
  ) {
    final session = _transitionFocusSession;
    if (session == null) {
      return;
    }
    setState(() {
      _transitionFocusSession = session.copyWith(selectedLaneId: laneId);
      _selectedTransitionFocusKeyframeIndex = keyframeIndex;
      _selectedTransitionFocusKeyframeId = keyframeId;
      _isTransitionFocusValueEditorOpen = false;
    });
  }

  void _handleTransitionFocusAnimationKeyframeDrag(
    String laneId,
    int keyframeIndex,
    String keyframeId,
    double normalizedStop,
  ) {
    final session = _transitionFocusSession;
    if (session == null) {
      return;
    }
    final transitionId = session.transitionId;
    final transition = _videoTrackTransitionById(transitionId);
    if (transition == null) {
      return;
    }
    TimelineAnimationLaneData? lane =
        transition.manualAnimationLaneById(laneId);
    lane ??= _emptyTransitionFocusManualLane(
      laneId: laneId,
      targetClipId: transition.leftClipId,
    );
    if (lane == null) {
      return;
    }
    final effectiveKeyframeId =
        _selectedTransitionFocusKeyframeId ?? keyframeId;
    final stops = List<double>.from(lane.normalizedKeyframeStops);
    final values = lane.alignedKeyframeValues(
      fallbackValue: _defaultTransitionFocusLaneValues(laneId).isEmpty
          ? 0
          : _defaultTransitionFocusLaneValues(laneId).first,
      clampToPercent: false,
    );
    final keyframeIds = List<String>.from(lane.keyframeIds);
    while (keyframeIds.length < stops.length) {
      keyframeIds.add('$laneId#${keyframeIds.length}');
    }
    final resolvedKeyframeIndex = keyframeIds.indexOf(effectiveKeyframeId);
    final movedKeyframeIndex =
        resolvedKeyframeIndex >= 0 ? resolvedKeyframeIndex : keyframeIndex;
    if (movedKeyframeIndex < 0 || movedKeyframeIndex >= stops.length) {
      return;
    }
    final movedEntries =
        <({double stop, String keyframeId, double value, bool isMoved})>[
      for (var index = 0; index < stops.length; index++)
        (
          stop: index == movedKeyframeIndex
              ? normalizedStop.clamp(0.0, 1.0)
              : stops[index],
          keyframeId: keyframeIds[index],
          value: values[index],
          isMoved: index == movedKeyframeIndex,
        ),
    ]..sort((left, right) => left.stop.compareTo(right.stop));
    final nextSelectedIndex = movedEntries.indexWhere((entry) => entry.isMoved);
    _updateTransitionFocusManualLane(
      transitionId,
      laneId,
      (currentLane) => currentLane.copyWith(
        normalizedKeyframeStops: List<double>.unmodifiable(
          <double>[for (final entry in movedEntries) entry.stop],
        ),
        keyframeIds: List<String>.unmodifiable(
          <String>[for (final entry in movedEntries) entry.keyframeId],
        ),
        keyframeValues: List<double>.unmodifiable(
          <double>[for (final entry in movedEntries) entry.value],
        ),
      ),
    );
    setState(() {
      _transitionFocusSession = session.copyWith(selectedLaneId: laneId);
      _selectedTransitionFocusKeyframeIndex =
          nextSelectedIndex < 0 ? movedKeyframeIndex : nextSelectedIndex;
      _selectedTransitionFocusKeyframeId = effectiveKeyframeId;
      _isTransitionFocusValueEditorOpen = false;
    });
  }

  void _handleTransitionFocusMoveSelectedKeyframeToPlayhead() {
    final session = _transitionFocusSession;
    if (session == null) {
      return;
    }
    final context = _transitionFocusContextById(session.transitionId);
    if (context == null) {
      return;
    }
    final lane = _transitionFocusSelectedAnimationLane(context);
    final keyframeIndex = _selectedTransitionFocusKeyframeIndex;
    if (lane == null || keyframeIndex == null) {
      _showStageMessage('Select a transition keyframe first.');
      return;
    }
    final progress = _transitionFocusProgressForTime(
      context,
      _transitionFocusVisibleGlobalTime(context),
    );
    final keyframeId = keyframeIndex < lane.keyframeIds.length
        ? lane.keyframeIds[keyframeIndex]
        : '${lane.id}#$keyframeIndex';
    _handleTransitionFocusAnimationKeyframeDrag(
      lane.id,
      keyframeIndex,
      keyframeId,
      progress,
    );
  }

  void _handleTransitionFocusAddKeyframe() {
    final session = _transitionFocusSession;
    if (session == null) {
      return;
    }
    final context = _transitionFocusContextById(session.transitionId);
    if (context == null) {
      return;
    }
    final lane = _transitionFocusSelectedAnimationLane(context);
    if (lane == null) {
      _showStageMessage('Select an animation or FX row before adding a key.');
      return;
    }
    final progress = _transitionFocusProgressForTime(
      context,
      _transitionFocusVisibleGlobalTime(context),
    );
    final stops = List<double>.from(lane.normalizedKeyframeStops);
    final values = List<double>.from(
      lane.alignedKeyframeValues(
        fallbackValue: _defaultTransitionFocusLaneValues(lane.id).isEmpty
            ? 0
            : _defaultTransitionFocusLaneValues(lane.id).first,
        clampToPercent: false,
      ),
    );
    final keyframeIds = List<String>.from(lane.keyframeIds);
    while (keyframeIds.length < stops.length) {
      keyframeIds.add('${lane.id}#${keyframeIds.length}');
    }
    final scopeDurationMs =
        (context.endTime - context.startTime).inMilliseconds;
    final frameMs = 1000.0 / (_timelineFps <= 0 ? 30.0 : _timelineFps);
    final snapEpsilon = scopeDurationMs <= 0
        ? 0.0001
        : ((frameMs * 0.25) / scopeDurationMs).clamp(0.00005, 0.00075);
    for (var index = 0; index < stops.length; index++) {
      if ((stops[index] - progress).abs() <= snapEpsilon) {
        setState(() {
          _selectedTransitionFocusKeyframeIndex = index;
          _selectedTransitionFocusKeyframeId = keyframeIds[index];
          _isTransitionFocusValueEditorOpen = false;
        });
        return;
      }
    }
    final selectedIndex = _selectedTransitionFocusKeyframeIndex;
    final insertedValue = selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < values.length
        ? values[selectedIndex]
        : lane.evaluateValueAtProgress(
            progress,
            fallbackValue: values.isEmpty ? 0.0 : values.last,
          );
    var insertIndex = 0;
    while (insertIndex < stops.length && stops[insertIndex] < progress) {
      insertIndex += 1;
    }
    stops.insert(insertIndex, progress);
    values.insert(insertIndex, insertedValue);
    final insertedKeyframeId =
        '${lane.id}@${(progress * 1000).round()}#${DateTime.now().millisecondsSinceEpoch}';
    keyframeIds.insert(insertIndex, insertedKeyframeId);
    _updateTransitionFocusManualLane(
      session.transitionId,
      lane.id,
      (currentLane) => currentLane.copyWith(
        normalizedKeyframeStops: List<double>.unmodifiable(stops),
        keyframeIds: List<String>.unmodifiable(keyframeIds),
        keyframeValues: List<double>.unmodifiable(values),
      ),
    );
    setState(() {
      _selectedTransitionFocusKeyframeIndex = insertIndex;
      _selectedTransitionFocusKeyframeId = insertedKeyframeId;
      _isTransitionFocusValueEditorOpen = false;
    });
  }

  List<LayerScopeValueControlSpec>? _transitionFocusValueControlsForSelection(
    _TransitionFocusContext _,
    TimelineAnimationLaneData lane,
    int keyframeIndex,
  ) {
    if (keyframeIndex < 0 ||
        keyframeIndex >= lane.normalizedKeyframeStops.length) {
      return null;
    }
    final spec = _transitionLaneLibrary[lane.id];
    if (spec == null) {
      return null;
    }
    final values = lane.alignedKeyframeValues(
      fallbackValue: _defaultTransitionFocusLaneValues(lane.id).isEmpty
          ? 0
          : _defaultTransitionFocusLaneValues(lane.id).first,
      clampToPercent: false,
    );
    final resolvedValue =
        keyframeIndex < values.length ? values[keyframeIndex] : spec.fallback;
    return <LayerScopeValueControlSpec>[
      LayerScopeValueControlSpec(
        id: lane.id,
        label: lane.label,
        value: resolvedValue,
        min: spec.min,
        max: spec.max,
        formatValue: spec.valueFormatter,
      ),
    ];
  }

  Future<void> _handleTransitionFocusValueToolTap() async {
    if (_isTransitionFocusValueEditorOpen) {
      return;
    }
    final session = _transitionFocusSession;
    if (session == null) {
      return;
    }
    final focusContext = _transitionFocusContextById(session.transitionId);
    if (focusContext == null) {
      return;
    }
    final lane = _transitionFocusSelectedAnimationLane(focusContext);
    if (lane == null) {
      return;
    }
    final resolvedKeyframeIndex = _selectedTransitionFocusKeyframeIndex ??
        (lane.normalizedKeyframeStops.isEmpty ? null : 0);
    if (resolvedKeyframeIndex == null) {
      return;
    }
    final controls = _transitionFocusValueControlsForSelection(
      focusContext,
      lane,
      resolvedKeyframeIndex,
    );
    if (controls == null || controls.isEmpty) {
      return;
    }
    setState(() {
      _selectedTransitionFocusKeyframeIndex = resolvedKeyframeIndex;
      _selectedTransitionFocusKeyframeId =
          resolvedKeyframeIndex < lane.keyframeIds.length
              ? lane.keyframeIds[resolvedKeyframeIndex]
              : '${lane.id}#$resolvedKeyframeIndex';
      _isTransitionFocusValueEditorOpen = true;
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaQuery.removeViewInsets(
        context: sheetContext,
        removeBottom: true,
        child: LayerScopeValueBottomSheet(
          controls: controls,
          onDone: () => Navigator.of(sheetContext).maybePop(),
          onChanged: (change) => _handleTransitionFocusValueControlChanged(
            change.controlId,
            change.value,
          ),
        ),
      ),
    ).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isTransitionFocusValueEditorOpen = false;
      });
    });
  }

  void _handleTransitionFocusValueControlChanged(
    String controlId,
    double value,
  ) {
    final session = _transitionFocusSession;
    final keyframeIndex = _selectedTransitionFocusKeyframeIndex;
    if (session == null || keyframeIndex == null) {
      return;
    }
    final transition = _videoTrackTransitionById(session.transitionId);
    if (transition == null) {
      return;
    }
    final lane = transition.manualAnimationLaneById(controlId);
    if (lane == null) {
      return;
    }
    final values = lane
        .alignedKeyframeValues(
          fallbackValue: _defaultTransitionFocusLaneValues(lane.id).isEmpty
              ? 0
              : _defaultTransitionFocusLaneValues(lane.id).first,
          clampToPercent: false,
        )
        .toList();
    if (keyframeIndex < 0 || keyframeIndex >= values.length) {
      return;
    }
    values[keyframeIndex] = value;
    _updateTransitionFocusManualLane(
      session.transitionId,
      lane.id,
      (currentLane) => currentLane.copyWith(
        keyframeValues: List<double>.unmodifiable(values),
      ),
    );
  }

  void _handleTransitionFrameToolsTap() {
    _showStageMessage(
        'Keyframe tools UI is the next step in this manual mode.');
  }

  static String _formatTransitionPercent(double value) => '${value.round()}%';

  static String _formatTransitionScale(double value) => '${value.round()}%';

  static String _formatTransitionPixels(double value) =>
      '${value.toStringAsFixed(1)}px';

  static String _formatTransitionDegrees(double value) =>
      '${value.toStringAsFixed(1)}deg';

  Future<void> _handleTimelineTransitionTap(
    TimelineTrackData track,
    TimelineClipData leftClip,
    TimelineClipData rightClip,
  ) async {
    if (track.kind != TimelineTrackKind.video) {
      return;
    }
    _deactivateTimelineTrimMode();
    final existingTransition = track.transitionForBoundary(
      leftClip.id,
      rightClip.id,
    );
    setState(() {
      _selectedClipId = null;
      _selectedTransitionId = existingTransition?.id;
      if (_activeTab == EditorMediaTab.speed) {
        _activeTab = EditorMediaTab.video;
      }
    });
    if (existingTransition != null) {
      if (existingTransition.preset == TimelineTransitionPreset.manual) {
        _enterTransitionFocusMode(existingTransition.id);
        return;
      }
      if (existingTransition.preset == TimelineTransitionPreset.aiGenerated) {
        await _openAiTransitionBottomSheet(
          leftClip: leftClip,
          rightClip: rightClip,
          existingTransition: existingTransition,
        );
        return;
      }
      await _openTransitionInspector(existingTransition.id);
      return;
    }
    final browserResult = await showModalBottomSheet<TransitionBrowserResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TransitionBrowserBottomSheet(),
    );
    if (!mounted || browserResult == null) {
      return;
    }
    final preset = browserResult.preset;
    if (browserResult.action == TransitionBrowserAction.openAi) {
      await _openAiTransitionBottomSheet(
        leftClip: leftClip,
        rightClip: rightClip,
      );
      return;
    }
    final transition = _normalTransitionAuthoringAdapter.isNormalPreset(preset)
        ? _createNormalTransitionForBoundary(
            track: track,
            leftClip: leftClip,
            rightClip: rightClip,
            preset: preset,
          )
        : TimelineTrackTransitionData(
            id: 'transition-${DateTime.now().millisecondsSinceEpoch}',
            leftClipId: leftClip.id,
            rightClipId: rightClip.id,
            preset: preset,
            durationTime: preset.defaultDurationTime,
            curve: TimelineTransitionCurve.easeInOut,
            parameterValues: preset.defaultParameterValues,
            manualEffectIds: preset == TimelineTransitionPreset.manual
                ? const <String>[]
                : const <String>[],
          );
    if (transition == null) {
      return;
    }
    _upsertVideoTrackTransition(transition);
    if (browserResult.action == TransitionBrowserAction.openManual) {
      _enterTransitionFocusMode(transition.id);
      return;
    }
    await _openTransitionInspector(transition.id);
  }

  Future<void> _openAiTransitionBottomSheet({
    required TimelineClipData leftClip,
    required TimelineClipData rightClip,
    TimelineTrackTransitionData? existingTransition,
  }) async {
    await _aiTransitionService.ensureConfigured();
    _AiTransitionBoundarySeed seed;
    try {
      seed = await _buildAiTransitionBoundarySeed(
        leftClip: leftClip,
        rightClip: rightClip,
        includePreviewFrames: true,
      );
    } catch (error) {
      _showStageMessage('Unable to prepare AI transition: $error');
      return;
    }
    if (!mounted) {
      return;
    }
    final result = await showModalBottomSheet<AiTransitionBottomSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiTransitionBottomSheet(
        leftClipLabel: _timelineClipDisplayLabel(leftClip),
        rightClipLabel: _timelineClipDisplayLabel(rightClip),
        leftFrameBytes: seed.firstFrameBytes,
        rightFrameBytes: seed.lastFrameBytes,
        initialDraft: existingTransition?.aiTransition,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    final createdAtMs =
        result.draft.createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final draft = result.draft.copyWith(
      createdAtMs: createdAtMs,
      status: _aiTransitionService.isConfigured
          ? AiTransitionJobStatus.waitingForBackend
          : AiTransitionJobStatus.draft,
      clearRequestId: true,
      clearGeneratedVideoUri: true,
      clearGeneratedAssetId: true,
      clearErrorMessage: true,
      leftSourceAssetId: seed.leftAssetId,
      rightSourceAssetId: seed.rightAssetId,
      leftBoundaryFramePositionMs: seed.leftFramePositionMs,
      rightBoundaryFramePositionMs: seed.rightFramePositionMs,
      aspectRatioHint: seed.aspectRatioHint,
    );
    final clipId = await _insertAiTransitionClipBetween(
      leftClip: leftClip,
      rightClip: rightClip,
      draft: draft,
    );
    if (clipId == null || !mounted) {
      return;
    }
    if (!_aiTransitionService.isConfigured) {
      _showStageMessage(
        'AI transition clip inserted. Rebuild with KIE_API_KEY to run generation.',
      );
      return;
    }
    unawaited(
      _runAiTransitionGeneration(
        clipId,
        createdAtMs: createdAtMs,
        initialFirstFrameBytes: seed.firstFrameBytes,
        initialLastFrameBytes: seed.lastFrameBytes,
      ),
    );
  }

  String _timelineClipDisplayLabel(TimelineClipData clip) {
    final label = clip.label?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return 'Clip ${clip.id}';
  }

  Future<String?> _insertAiTransitionClipBetween({
    required TimelineClipData leftClip,
    required TimelineClipData rightClip,
    required AiTransitionDraftData draft,
  }) async {
    final videoTrackIndex = _tracks.indexWhere(
      (track) => track.kind == TimelineTrackKind.video,
    );
    if (videoTrackIndex < 0) {
      return null;
    }
    final baseTracks = List<TimelineTrackData>.from(_tracks);
    final baseTrack = baseTracks[videoTrackIndex];
    final leftIndex =
        baseTrack.clips.indexWhere((clip) => clip.id == leftClip.id);
    final rightIndex =
        baseTrack.clips.indexWhere((clip) => clip.id == rightClip.id);
    if (leftIndex < 0 || rightIndex != leftIndex + 1) {
      _showStageMessage(
        'The seam changed before generation started. Open the AI transition again from the current bridge.',
      );
      return null;
    }

    final clipId =
        'ai-transition-clip-${DateTime.now().millisecondsSinceEpoch}';
    final transitionClip = TimelineClipData(
      id: clipId,
      assetId: null,
      durationTime: TimelineTime.fromSecondsDouble(
        draft.durationSeconds.toDouble(),
      ),
      sourceDurationTime: TimelineTime.fromSecondsDouble(
        draft.durationSeconds.toDouble(),
      ),
      sourceStartTime: TimelineTime.zero,
      tone: TimelineClipTone.aiGenerated,
      type: TimelineClipType.media,
      label: 'AI Transition',
      aiTransition: draft,
    );
    final nextClips = List<TimelineClipData>.from(baseTrack.clips)
      ..insert(rightIndex, transitionClip);
    final nextTracks = _replaceTrackIn(baseTracks, videoTrackIndex, nextClips);
    final preservedTimelineTime = _currentTime.clamp(
      TimelineTime.zero,
      _timelineDurationForTracksTime(nextTracks),
    );
    final nextPreviewAssetId = _resolvedPreviewAssetIdForTracks(
      nextTracks,
      preferredTimelineTime: preservedTimelineTime,
      preferredAssetId: _previewAssetId,
    );
    setState(() {
      _tracks = nextTracks;
      _selectedTransitionId = null;
      if (_activeTab == EditorMediaTab.speed) {
        _activeTab = EditorMediaTab.video;
      }
      _isApplyingStructuralEdit = true;
      _previewAssetId = nextPreviewAssetId;
      _refreshLiveScrubPreviewSourceCatalog(tracks: nextTracks);
      _setCurrentTime(preservedTimelineTime);
    });
    await _commitStructuralTimelineEdit(
      tracks: nextTracks,
      targetTime: preservedTimelineTime,
      previewAssetId: nextPreviewAssetId,
    );
    return clipId;
  }

  void _updateAiTransitionDraft(
    String clipId,
    AiTransitionDraftData Function(AiTransitionDraftData current) transform,
  ) {
    final location = _videoTrackClipLocationById(clipId);
    final clip = location?.clip;
    final aiDraft = clip?.aiTransition;
    if (location == null || clip == null || aiDraft == null) {
      return;
    }
    final nextClips = List<TimelineClipData>.from(location.track.clips);
    nextClips[location.clipIndex] = clip.copyWith(
      aiTransition: transform(aiDraft),
    );
    final nextTracks = _replaceTrackIn(
      _tracks,
      location.trackIndex,
      nextClips,
    );
    setState(() {
      _tracks = nextTracks;
    });
  }

  Future<void> _runAiTransitionGeneration(
    String clipId, {
    required int createdAtMs,
    Uint8List? initialFirstFrameBytes,
    Uint8List? initialLastFrameBytes,
  }) async {
    final location = _videoTrackClipLocationById(clipId);
    final draft = location?.clip.aiTransition;
    if (location == null || draft == null || draft.createdAtMs != createdAtMs) {
      return;
    }

    try {
      final frames = await _extractAiTransitionBoundaryFrames(
        draft,
        cachedFirstFrameBytes: initialFirstFrameBytes,
        cachedLastFrameBytes: initialLastFrameBytes,
      );
      final result = await _aiTransitionService.generateTransition(
        draft: draft,
        firstFrameBytes: frames.firstFrameBytes,
        lastFrameBytes: frames.lastFrameBytes,
        aspectRatioHint: draft.aspectRatioHint,
        onStatus: (status, {taskId}) {
          final latest = _videoTrackClipLocationById(clipId)?.clip.aiTransition;
          if (latest == null || latest.createdAtMs != createdAtMs) {
            return;
          }
          _updateAiTransitionDraft(
            clipId,
            (current) => current.copyWith(
              status: status,
              requestId: taskId,
              clearErrorMessage: status != AiTransitionJobStatus.failed,
            ),
          );
        },
      );
      final latestClip = _videoTrackClipLocationById(clipId)?.clip;
      final latestDraft = latestClip?.aiTransition;
      if (latestClip == null ||
          latestDraft == null ||
          latestDraft.createdAtMs != createdAtMs) {
        return;
      }
      final assetId = await _registerGeneratedAiTransitionAsset(
        draft: draft,
        localVideoPath: result.localVideoPath,
        label: latestClip.label ?? 'AI Transition',
      );
      await _completeAiTransitionClip(
        clipId: clipId,
        createdAtMs: createdAtMs,
        taskId: result.taskId,
        localVideoPath: result.localVideoPath,
        assetId: assetId,
      );
      if (mounted) {
        _showTopStageBanner('AI transition generated.');
      }
    } catch (error) {
      final latest = _videoTrackClipLocationById(clipId)?.clip.aiTransition;
      if (latest == null || latest.createdAtMs != createdAtMs) {
        return;
      }
      _updateAiTransitionDraft(
        clipId,
        (current) => current.copyWith(
          status: AiTransitionJobStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      if (mounted) {
        _showTopStageBanner('AI transition failed.');
      }
    }
  }

  Future<void> _completeAiTransitionClip({
    required String clipId,
    required int createdAtMs,
    required String taskId,
    required String localVideoPath,
    required String assetId,
  }) async {
    final location = _videoTrackClipLocationById(clipId);
    final clip = location?.clip;
    final draft = clip?.aiTransition;
    if (location == null || clip == null || draft == null) {
      return;
    }
    if (draft.createdAtMs != createdAtMs) {
      return;
    }
    final asset = _assetForId(assetId);
    final resolvedDurationSeconds =
        asset?.durationSeconds ?? draft.durationSeconds.toDouble();
    final nextClips = List<TimelineClipData>.from(location.track.clips);
    nextClips[location.clipIndex] = clip.copyWith(
      assetId: assetId,
      label: asset?.label ?? clip.label,
      durationTime: TimelineTime.fromSecondsDouble(resolvedDurationSeconds),
      sourceDurationTime: TimelineTime.fromSecondsDouble(
        resolvedDurationSeconds,
      ),
      sourceStartTime: TimelineTime.zero,
      aiTransition: draft.copyWith(
        status: AiTransitionJobStatus.completed,
        requestId: taskId,
        generatedVideoUri: localVideoPath,
        generatedAssetId: assetId,
        clearErrorMessage: true,
      ),
    );
    final nextTracks = _replaceTrackIn(
      _tracks,
      location.trackIndex,
      nextClips,
    );
    final preservedTimelineTime = _currentTime.clamp(
      TimelineTime.zero,
      _timelineDurationForTracksTime(nextTracks),
    );
    final nextPreviewAssetId = _resolvedPreviewAssetIdForTracks(
      nextTracks,
      preferredTimelineTime: preservedTimelineTime,
      preferredAssetId: assetId,
    );
    setState(() {
      _tracks = nextTracks;
      _isApplyingStructuralEdit = true;
      _previewAssetId = nextPreviewAssetId;
      _refreshLiveScrubPreviewSourceCatalog(tracks: nextTracks);
      _setCurrentTime(preservedTimelineTime);
    });
    await _commitStructuralTimelineEdit(
      tracks: nextTracks,
      targetTime: preservedTimelineTime,
      previewAssetId: nextPreviewAssetId,
    );
  }

  Future<({Uint8List firstFrameBytes, Uint8List lastFrameBytes})>
      _extractAiTransitionBoundaryFrames(
    AiTransitionDraftData draft, {
    Uint8List? cachedFirstFrameBytes,
    Uint8List? cachedLastFrameBytes,
  }) async {
    final leftAssetId = draft.leftSourceAssetId;
    final rightAssetId = draft.rightSourceAssetId;
    final leftAsset = leftAssetId == null ? null : _assetForId(leftAssetId);
    final rightAsset = rightAssetId == null ? null : _assetForId(rightAssetId);
    final leftSourceUri = leftAsset?.sourceUri;
    final rightSourceUri = rightAsset?.sourceUri;
    if (leftSourceUri == null ||
        leftSourceUri.isEmpty ||
        rightSourceUri == null ||
        rightSourceUri.isEmpty) {
      throw const KieAiTransitionException(
        'The transition boundary clips are missing playable source files.',
      );
    }
    final firstFrameBytes = cachedFirstFrameBytes ??
        await _transportController.loadMediaFramePreview(
          sourceUri: leftSourceUri,
          positionMs: draft.leftBoundaryFramePositionMs ?? 0,
          targetWidth: 480,
          targetHeight: 854,
        );
    final lastFrameBytes = cachedLastFrameBytes ??
        await _transportController.loadMediaFramePreview(
          sourceUri: rightSourceUri,
          positionMs: draft.rightBoundaryFramePositionMs ?? 0,
          targetWidth: 480,
          targetHeight: 854,
        );
    if (firstFrameBytes == null || lastFrameBytes == null) {
      throw const KieAiTransitionException(
        'Unable to extract the seam boundary frames for AI generation.',
      );
    }
    return (
      firstFrameBytes: firstFrameBytes,
      lastFrameBytes: lastFrameBytes,
    );
  }

  Future<_AiTransitionBoundarySeed> _buildAiTransitionBoundarySeed({
    required TimelineClipData leftClip,
    required TimelineClipData rightClip,
    bool includePreviewFrames = false,
  }) async {
    final leftAssetId = leftClip.assetId;
    final rightAssetId = rightClip.assetId;
    final leftAsset = leftAssetId == null ? null : _assetForId(leftAssetId);
    final rightAsset = rightAssetId == null ? null : _assetForId(rightAssetId);
    final leftSourceUri = leftAsset?.sourceUri;
    final rightSourceUri = rightAsset?.sourceUri;
    if (leftAssetId == null ||
        leftAssetId.isEmpty ||
        rightAssetId == null ||
        rightAssetId.isEmpty ||
        leftSourceUri == null ||
        leftSourceUri.isEmpty ||
        rightSourceUri == null ||
        rightSourceUri.isEmpty) {
      throw const KieAiTransitionException(
        'The transition boundary clips are missing playable source files.',
      );
    }
    final leftPositionMs = (() {
      final endMs = leftClip.sourceEndTime.inMilliseconds;
      if (endMs <= 0) {
        return 0;
      }
      return (endMs - 33).clamp(0, endMs);
    })();
    final rightPositionMs = rightClip.sourceStartTime.inMilliseconds;
    Uint8List? firstFrameBytes;
    Uint8List? lastFrameBytes;
    if (includePreviewFrames) {
      firstFrameBytes = await _transportController.loadMediaFramePreview(
        sourceUri: leftSourceUri,
        positionMs: leftPositionMs,
        targetWidth: 480,
        targetHeight: 854,
      );
      lastFrameBytes = await _transportController.loadMediaFramePreview(
        sourceUri: rightSourceUri,
        positionMs: rightPositionMs,
        targetWidth: 480,
        targetHeight: 854,
      );
    }
    return _AiTransitionBoundarySeed(
      leftAssetId: leftAssetId,
      rightAssetId: rightAssetId,
      leftFramePositionMs: leftPositionMs,
      rightFramePositionMs: rightPositionMs,
      aspectRatioHint: _resolveAiTransitionAspectRatioHintForClips(
        leftClip,
        rightClip,
      ),
      firstFrameBytes: firstFrameBytes,
      lastFrameBytes: lastFrameBytes,
    );
  }

  String? _resolveAiTransitionAspectRatioHintForClips(
    TimelineClipData leftClip,
    TimelineClipData rightClip,
  ) {
    final leftAsset = _assetForId(leftClip.assetId);
    final rightAsset = _assetForId(rightClip.assetId);
    final ratio = leftAsset?.aspectRatio ??
        rightAsset?.aspectRatio ??
        _workspaceAspectRatio;
    if (ratio <= 0) {
      return null;
    }
    const ratios = <({String id, double value})>[
      (id: '2:3', value: 2 / 3),
      (id: '3:2', value: 3 / 2),
      (id: '1:1', value: 1.0),
      (id: '16:9', value: 16 / 9),
      (id: '9:16', value: 9 / 16),
    ];
    ({String id, double value})? bestMatch;
    var bestDelta = double.infinity;
    for (final candidate in ratios) {
      final delta = (candidate.value - ratio).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestMatch = candidate;
      }
    }
    return bestMatch?.id;
  }

  Future<String> _registerGeneratedAiTransitionAsset({
    required AiTransitionDraftData draft,
    required String localVideoPath,
    required String label,
  }) async {
    final assetId = 'ai-transition-${DateTime.now().millisecondsSinceEpoch}';
    var generatedAsset = EditorAssetItem(
      id: assetId,
      tab: EditorMediaTab.video,
      label: '$label • ${draft.model.label}',
      tone: 84,
      sourceUri: localVideoPath,
      previewUri: localVideoPath,
      isImported: true,
      durationSeconds: draft.durationSeconds.toDouble(),
      dateAddedSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    generatedAsset =
        await _normalizeVisualAssetGeometryForInsert(generatedAsset);
    final nextVideoAssets = <EditorAssetItem>[
      for (final asset in _assetLibrary.value)
        if (asset.id != generatedAsset.id) asset,
      generatedAsset,
    ];
    _assetLibrary.value = List<EditorAssetItem>.unmodifiable(nextVideoAssets);
    _importedAssetsById[generatedAsset.id] = generatedAsset;
    unawaited(
      _primePreviewThumbnailForAsset(
        generatedAsset,
        publishIfNotCurrent: false,
      ),
    );
    return generatedAsset.id;
  }

  _AiTransitionClipLocation? _videoTrackClipLocationById(String clipId) {
    for (var trackIndex = 0; trackIndex < _tracks.length; trackIndex += 1) {
      final track = _tracks[trackIndex];
      if (track.kind != TimelineTrackKind.video) {
        continue;
      }
      for (var clipIndex = 0; clipIndex < track.clips.length; clipIndex += 1) {
        final clip = track.clips[clipIndex];
        if (clip.id != clipId) {
          continue;
        }
        return _AiTransitionClipLocation(
          trackIndex: trackIndex,
          clipIndex: clipIndex,
          track: track,
          clip: clip,
        );
      }
    }
    return null;
  }

  Future<void> _openTransitionInspector(String transitionId) async {
    final transition = _videoTrackTransitionById(transitionId);
    if (transition == null) {
      return;
    }
    final result = await showModalBottomSheet<TransitionInspectorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransitionInspectorBottomSheet(
        initialTransition: transition,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    switch (result.action) {
      case TransitionInspectorAction.apply:
        _upsertVideoTrackTransition(result.transition);
      case TransitionInspectorAction.openManual:
        _upsertVideoTrackTransition(result.transition);
        _enterTransitionFocusMode(result.transition.id);
      case TransitionInspectorAction.delete:
        _deleteVideoTrackTransition(result.transition.id);
    }
  }

  _ActiveTimelineTransitionPreview? _activeTimelineTransitionPreviewAt(
    TimelineTime timelineTime,
  ) {
    final videoTrack =
        _tracks.where((track) => track.kind == TimelineTrackKind.video);
    if (videoTrack.isEmpty) {
      return null;
    }
    final track = videoTrack.first;
    if (track.transitions.isEmpty) {
      return null;
    }
    final positionedClips = _positionedMediaClipsForTrack(track);
    if (positionedClips.length < 2) {
      return null;
    }
    final clipById = <String, _PositionedTimelineTrackClip>{
      for (final positionedClip in positionedClips)
        positionedClip.clip.id: positionedClip,
    };
    for (final transition in _sanitizeTransitionsForTrack(track)) {
      if (transition.preset == TimelineTransitionPreset.aiGenerated) {
        continue;
      }
      if (transition.preset == TimelineTransitionPreset.manual &&
          transition.manualEffectIds.isEmpty) {
        continue;
      }
      final leftClip = clipById[transition.leftClipId];
      final rightClip = clipById[transition.rightClipId];
      if (leftClip == null || rightClip == null) {
        continue;
      }
      final focusContext = transition.preset == TimelineTransitionPreset.manual
          ? _transitionFocusContextById(transition.id)
          : null;
      final manualAuthoredRange = focusContext == null
          ? null
          : _manualTransitionAuthoredEffectTimeRange(focusContext);
      final seamTime = leftClip.startTime + leftClip.clip.durationTime;
      final start = manualAuthoredRange?.start ??
          focusContext?.activeStartTime ??
          (seamTime - transition.resolvedLeadingDurationTime).clamp(
            TimelineTime.zero,
            _timelineDurationTime,
          );
      final end = manualAuthoredRange?.end ??
          focusContext?.activeEndTime ??
          (seamTime + transition.resolvedTrailingDurationTime).clamp(
            TimelineTime.zero,
            _timelineDurationTime,
          );
      if (end <= start || timelineTime < start || timelineTime > end) {
        continue;
      }
      final totalSpan = (end - start).inMilliseconds;
      final elapsed = (timelineTime - start).inMilliseconds;
      final progress = totalSpan <= 0
          ? 0.0
          : (elapsed / totalSpan).clamp(0.0, 1.0).toDouble();
      final manualLaneProgress = focusContext == null
          ? progress
          : _transitionFocusProgressForTime(focusContext, timelineTime);
      final manualSeamProgress = focusContext == null
          ? progress
          : _transitionFocusProgressForTime(
              focusContext, focusContext.seamTime);
      return _ActiveTimelineTransitionPreview(
        transition: transition,
        leftClip: leftClip,
        rightClip: rightClip,
        progress: progress,
        manualLaneProgress: manualLaneProgress,
        manualSeamProgress: manualSeamProgress,
      );
    }
    return null;
  }

  void _warmTransitionPreviewAssets(_ActiveTimelineTransitionPreview state) {
    final assetIds = <String>{
      if (state.leftClip.clip.assetId != null &&
          state.leftClip.clip.assetId!.isNotEmpty)
        state.leftClip.clip.assetId!,
      if (state.rightClip.clip.assetId != null &&
          state.rightClip.clip.assetId!.isNotEmpty)
        state.rightClip.clip.assetId!,
    };
    for (final assetId in assetIds) {
      final asset = _assetForId(assetId);
      if (asset == null) {
        continue;
      }
      unawaited(
        _primePreviewThumbnailForAsset(
          asset,
          publishIfNotCurrent: false,
        ),
      );
    }
  }

  void _warmTransitionFocusPreviewAssets(_TransitionFocusContext context) {
    final assetIds = <String>{
      if (context.leftClip.assetId != null &&
          context.leftClip.assetId!.isNotEmpty)
        context.leftClip.assetId!,
      if (context.rightClip.assetId != null &&
          context.rightClip.assetId!.isNotEmpty)
        context.rightClip.assetId!,
    };
    for (final assetId in assetIds) {
      final asset = _assetForId(assetId);
      if (asset == null) {
        continue;
      }
      unawaited(
        _primePreviewThumbnailForAsset(
          asset,
          publishIfNotCurrent: false,
        ),
      );
    }
  }

  Uint8List? _previewThumbnailBytesForClip(TimelineClipData clip) {
    final assetId = clip.assetId;
    if (assetId == null || assetId.isEmpty) {
      return null;
    }
    return _previewThumbnailCache[assetId];
  }

  ValueListenable<TimelineTime> _previewTimeListenable({
    required bool effectiveIsPlaying,
  }) {
    return effectiveIsPlaying && _useNativePreview
        ? _playbackSampleTimeNotifier
        : _timelineDisplayTimeNotifier;
  }

  Widget _buildTransitionVideoFxPreviewHost({
    required bool effectiveIsPlaying,
    required Widget child,
  }) {
    if (_useNativePreview) {
      return ValueListenableBuilder<TimelineTime>(
        valueListenable: _previewTimeListenable(
          effectiveIsPlaying: effectiveIsPlaying,
        ),
        child: child,
        builder: (context, previewTime, livePreviewChild) {
          final command = _activeTransitionVideoFxCommandAt(previewTime);
          _scheduleNativeTransitionPreviewEffects(command);
          return livePreviewChild ?? child;
        },
      );
    }
    return ValueListenableBuilder<TimelineTime>(
      valueListenable: _previewTimeListenable(
        effectiveIsPlaying: effectiveIsPlaying,
      ),
      child: child,
      builder: (context, previewTime, livePreviewChild) {
        final command = _activeTransitionVideoFxCommandAt(previewTime);
        if (command == null || !command.hasVisibleEffect) {
          return livePreviewChild ?? child;
        }
        var result = livePreviewChild ?? child;
        if (command.blurSigma > 0.05) {
          result = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: command.blurSigma,
              sigmaY: command.blurSigma,
            ),
            child: result,
          );
        }
        return result;
      },
    );
  }

  void _scheduleNativeTransitionPreviewEffects(
    _TransitionVideoFxCommand? command,
  ) {
    if (!_useNativePreview) {
      return;
    }
    final nextBlurSigma = command?.blurSigma ?? 0.0;
    final normalizedBlurSigma =
        nextBlurSigma.isNaN || nextBlurSigma.isInfinite ? 0.0 : nextBlurSigma;
    final clampedBlurSigma = normalizedBlurSigma.clamp(0.0, 64.0).toDouble();
    final previousBlurSigma = _lastNativeTransitionBlurSigma;
    if (previousBlurSigma != null &&
        (previousBlurSigma - clampedBlurSigma).abs() <= 0.02) {
      return;
    }
    _lastNativeTransitionBlurSigma = clampedBlurSigma;
    final revision = ++_nativeTransitionEffectRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _nativeTransitionEffectRevision) {
        return;
      }
      unawaited(
        _transportController.setPreviewTransitionEffects(
          blurSigma: clampedBlurSigma,
        ),
      );
    });
  }

  _TransitionVideoFxCommand? _activeTransitionVideoFxCommandAt(
    TimelineTime previewTime,
  ) {
    final activeTransition = _activeTimelineTransitionPreviewAt(previewTime);
    if (activeTransition == null) {
      return null;
    }
    return _transitionVideoFxCommandForActiveTransition(activeTransition);
  }

  _TransitionVideoFxCommand? _transitionVideoFxCommandForActiveTransition(
    _ActiveTimelineTransitionPreview activeTransition,
  ) {
    final transition = activeTransition.transition;
    double blurSigma = 0;
    if (transition.preset == TimelineTransitionPreset.manual &&
        transition.manualEffectIds.contains('blurAmount')) {
      blurSigma = transition.manualLaneValueAtProgress(
        'blurAmount',
        activeTransition.manualLaneProgress,
        fallbackValue: transition.parameterValue('blurAmount', fallback: 0.0),
      );
    } else {
      blurSigma = switch (transition.preset) {
        TimelineTransitionPreset.blurDissolve =>
          transition.parameterValue('maxBlur', fallback: 10.0) *
              _centeredTransitionPulse(activeTransition.progress),
        TimelineTransitionPreset.whipPanLeft ||
        TimelineTransitionPreset.whipPanRight =>
          transition.parameterValue('maxBlur', fallback: 16.0) *
              _sineTransitionPulse(activeTransition.progress),
        TimelineTransitionPreset.slideBlurLeft ||
        TimelineTransitionPreset.slideBlurRight =>
          transition.parameterValue('maxBlur', fallback: 8.0) *
              _sineTransitionPulse(activeTransition.progress),
        _ => 0.0,
      };
    }
    final clampedBlur = blurSigma.clamp(0.0, 24.0).toDouble();
    if (clampedBlur <= 0.05) {
      return null;
    }
    return _TransitionVideoFxCommand(blurSigma: clampedBlur);
  }

  double _centeredTransitionPulse(double progress) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return (1 - ((t - 0.5).abs() / 0.5)).clamp(0.0, 1.0).toDouble();
  }

  double _sineTransitionPulse(double progress) {
    return math.sin(progress.clamp(0.0, 1.0).toDouble() * math.pi).abs();
  }

  Widget? _buildPreviewOverlay({
    required bool effectiveIsPlaying,
  }) {
    final previewTimeListenable = _previewTimeListenable(
      effectiveIsPlaying: effectiveIsPlaying,
    );
    return ValueListenableBuilder<TimelineTime>(
      valueListenable: previewTimeListenable,
      builder: (context, previewTime, _) {
        final activeTransition =
            _activeTimelineTransitionPreviewAt(previewTime);
        if (activeTransition != null) {
          _warmTransitionPreviewAssets(activeTransition);
        }
        final motionTextRenderSnapshot =
            _motionTextRenderSnapshotForTime(previewTime);
        return AnimatedBuilder(
          animation: _transportController,
          builder: (context, __) {
            final activeVisualOpacity = _activePreviewVisualOpacityForTime(
              previewTime,
            );
            if (motionTextRenderSnapshot == null &&
                activeTransition == null &&
                activeVisualOpacity >= 0.999) {
              return const SizedBox.shrink();
            }
            final selectedCanvasElementId = motionTextRenderSnapshot == null
                ? null
                : _selectedCanvasTextElementIdForSnapshot(
                    motionTextRenderSnapshot,
                  );
            final outgoingTransitionBytes = activeTransition == null
                ? null
                : _previewThumbnailBytesForClip(activeTransition.leftClip.clip);
            final incomingTransitionBytes = activeTransition == null
                ? null
                : _previewThumbnailBytesForClip(
                    activeTransition.rightClip.clip);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (activeTransition != null)
                  TimelineTransitionPreviewOverlay(
                    transition: activeTransition.transition,
                    progress: activeTransition.progress,
                    manualLaneProgress: activeTransition.manualLaneProgress,
                    manualSeamProgress: activeTransition.manualSeamProgress,
                    outgoingThumbnailBytes: outgoingTransitionBytes,
                    incomingThumbnailBytes: incomingTransitionBytes,
                  ),
                if (activeVisualOpacity < 0.999)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withOpacity(
                          (1 - activeVisualOpacity).clamp(0.0, 1.0).toDouble(),
                        ),
                      ),
                    ),
                  ),
                if (motionTextRenderSnapshot != null)
                  MotionTextPreviewOverlay(
                    snapshot: motionTextRenderSnapshot,
                  ),
                if (motionTextRenderSnapshot != null && !effectiveIsPlaying)
                  MotionTextTransformOverlay(
                    snapshot: motionTextRenderSnapshot,
                    selectedElementId: selectedCanvasElementId,
                    isInteractive: !_isTimelineScrubbing && !effectiveIsPlaying,
                    onNodeSelected: _handleCanvasTextSelected,
                    onNodeEditRequested: _handleCanvasTextEditRequested,
                    onNodeMoved: _handleCanvasTextMoved,
                    onNodeScaleChanged: _handleCanvasTextScaleChanged,
                    onNodeRotationChanged: _handleCanvasTextRotationChanged,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewAsset = _previewAsset;
    final hasPreviewCanvasContent =
        previewAsset != null || _hasMotionTextContent;
    _schedulePreviewThumbnailWarmup(previewAsset);
    final displayTracks = _displayTracks;
    final mainTimelineTracks = displayTracks
        .map(
          (track) => track.animationLanes.isEmpty
              ? track
              : track.copyWith(
                  animationLanes: const <TimelineAnimationLaneData>[],
                ),
        )
        .toList(growable: false);
    final effectiveIsPlaying = _useNativePreview && _isPlaying;
    final hasSelectedImportedClip = _hasSelectedImportedClip;
    final hasSelectedMotionTextClip =
        _selectedClipId != null && _isMotionTextElementId(_selectedClipId!);
    final hasSelectedSpeedEditableClip = _hasSelectedSpeedEditableClip;
    final effectiveDockActiveTab = _effectiveDockActiveTab;
    final enabledDockTabs = <EditorMediaTab>{
      EditorMediaTab.audio,
      EditorMediaTab.text,
      EditorMediaTab.lipSync,
      if (hasSelectedSpeedEditableClip) EditorMediaTab.speed,
    };
    final isTrimModeActive = _timelineTrimSelection != null;
    final activeTextEditSession = _textEditSession;
    final transitionFocusSession = _transitionFocusSession;
    final transitionFocusContext = transitionFocusSession == null
        ? null
        : _transitionFocusContextById(transitionFocusSession.transitionId);
    final transitionFocusLaneSpecs = transitionFocusContext == null
        ? const <_TransitionFocusLaneSpec>[]
        : _transitionFocusLaneSpecs(transitionFocusContext.transition);
    final resolvedTransitionFocusLaneId = transitionFocusContext == null
        ? ''
        : _resolvedTransitionFocusLaneId(
            transitionFocusContext,
            preferredLaneId: transitionFocusSession?.selectedLaneId,
          );
    final transitionFocusScopedTracks = transitionFocusContext == null
        ? const <TimelineTrackData>[]
        : _buildTransitionFocusScopedTracks(
            transitionFocusContext,
            transitionFocusLaneSpecs,
          );
    final transitionFocusLocalTime = transitionFocusContext == null
        ? TimelineTime.zero
        : _transitionFocusLocalTime(
            transitionFocusContext,
            _currentTime,
          );
    final layerScopeContext =
        transitionFocusContext == null ? _activeLayerScopeContext : null;
    final layerScopeTracks = layerScopeContext == null
        ? const <TimelineTrackData>[]
        : _buildLayerScopeTracks(layerScopeContext);
    final layerScopeTrimSelection = layerScopeContext == null
        ? null
        : _layerScopeTrimSelection(layerScopeContext);
    final layerScopeLocalTime = layerScopeContext == null
        ? TimelineTime.zero
        : _layerScopeLocalTime(layerScopeContext, _currentTime);
    final canOpenLayerScopeValueEditor =
        _canOpenLayerScopeValueEditor(layerScopeContext);
    final canOpenLayerScopeGraphEditor =
        _canOpenLayerScopeGraphEditor(layerScopeContext);
    final canAddTransitionFocusKeyframe =
        _canAddTransitionFocusKeyframe(transitionFocusContext);
    final canOpenTransitionFocusValueEditor =
        _canOpenTransitionFocusValueEditor(transitionFocusContext);
    final canMoveTransitionFocusSelectedKeyframe =
        _canMoveTransitionFocusSelectedKeyframe(transitionFocusContext);
    final canMoveLayerScopeSelectedKeyframe =
        _canMoveLayerScopeSelectedKeyframe(layerScopeContext);
    final selectedLayerScopeAnimationLane = layerScopeContext == null
        ? null
        : _layerScopeSelectedAnimationLane(layerScopeContext);
    final canAddLayerScopeKeyframe = selectedLayerScopeAnimationLane != null &&
        _layerScopeDefinitionsForLane(selectedLayerScopeAnimationLane) != null;
    final isLayerScopeActive = layerScopeContext != null;
    final isTextLayerScopeActive =
        layerScopeContext?.track.kind == TimelineTrackKind.text;
    return Scaffold(
      resizeToAvoidBottomInset: !_isAnimateBrowserOpen,
      body: SafeArea(
        bottom: false,
        child: Container(
          color: FxPalette.background,
          child: Stack(
            children: [
              Column(
                children: [
                  EditorTopBar(
                    onShare: _handleShare,
                    isExporting: _exportController.state.isActive,
                    exportProgress: _exportController.state.progress,
                  ),
                  Expanded(
                    flex: 4,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 220),
                      child: LayoutBuilder(
                        builder: (context, previewConstraints) {
                          _lastPreviewStageSize = Size(
                            previewConstraints.maxWidth,
                            previewConstraints.maxHeight,
                          );
                          final previewFallback = _CleanPreviewCanvas(
                            asset: previewAsset,
                            previewThumbnailAssetId:
                                _previewThumbnailResolvedAssetId,
                            previewThumbnailListenable:
                                _previewThumbnailNotifier,
                          );
                          final nativePreviewChild = _useNativePreview
                              ? NativePreviewSurface(
                                  controller: _transportController,
                                  previewIdentity: previewAsset?.sourceUri ??
                                      previewAsset?.id,
                                  recoveryRevision:
                                      _nativePreviewRecoveryRevision,
                                  fallback: previewFallback,
                                )
                              : previewFallback;
                          final previewChild =
                              _buildTransitionVideoFxPreviewHost(
                            effectiveIsPlaying: effectiveIsPlaying,
                            child: nativePreviewChild,
                          );
                          return PreviewStage(
                            workspaceAspectRatio: _previewAspectRatio,
                            hasVisibleContent: hasPreviewCanvasContent,
                            viewportState: _previewViewportState,
                            onViewportChanged: _handlePreviewViewportChanged,
                            onViewportReset: _handlePreviewViewportReset,
                            overlay: _buildPreviewOverlay(
                              effectiveIsPlaying: effectiveIsPlaying,
                            ),
                            child: previewChild,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    flex: 4,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(2, 0, 2, 4),
                      decoration: BoxDecoration(
                        color: FxPalette.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FxPalette.divider, width: 1),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
                            child: transitionFocusContext != null
                                ? TransitionFocusToolsBar(
                                    isPlaying: effectiveIsPlaying,
                                    onBack: _exitTransitionFocusMode,
                                    onFrameToolsTap:
                                        _handleTransitionFrameToolsTap,
                                    onScriptImport: () =>
                                        _openTransitionScriptImportSheet(
                                      transitionFocusContext.transition.id,
                                    ),
                                    onMoveToKeyframe:
                                        canMoveTransitionFocusSelectedKeyframe
                                            ? _handleTransitionFocusMoveSelectedKeyframeToPlayhead
                                            : null,
                                    onPlayToggle: _useNativePreview
                                        ? _handlePlayToggle
                                        : null,
                                  )
                                : layerScopeContext != null
                                    ? _LayerScopeToolsBar(
                                        isPlaying: effectiveIsPlaying,
                                        onBack: _exitLayerScope,
                                        onSplit: hasSelectedImportedClip
                                            ? _handleSplitSelectedClip
                                            : null,
                                        onTrimToggle: hasSelectedImportedClip ||
                                                hasSelectedMotionTextClip
                                            ? _handleTrimModeToggle
                                            : null,
                                        isTrimModeActive: isTrimModeActive,
                                        onDuplicate: hasSelectedImportedClip ||
                                                hasSelectedMotionTextClip
                                            ? _handleDuplicateSelectedClip
                                            : null,
                                        onMoveToKeyframe:
                                            canMoveLayerScopeSelectedKeyframe
                                                ? _handleLayerScopeMoveSelectedKeyframeToPlayhead
                                                : null,
                                        onPlayToggle: _useNativePreview
                                            ? _handlePlayToggle
                                            : null,
                                      )
                                    : EditorToolsBar(
                                        embedded: true,
                                        isPlaying: effectiveIsPlaying,
                                        onSplit: hasSelectedImportedClip
                                            ? _handleSplitSelectedClip
                                            : null,
                                        onTrimToggle: hasSelectedImportedClip ||
                                                hasSelectedMotionTextClip
                                            ? _handleTrimModeToggle
                                            : null,
                                        isTrimModeActive: isTrimModeActive,
                                        onDuplicate: hasSelectedImportedClip ||
                                                hasSelectedMotionTextClip
                                            ? _handleDuplicateSelectedClip
                                            : null,
                                        onDelete: hasSelectedImportedClip ||
                                                hasSelectedMotionTextClip
                                            ? _handleDeleteSelectedClip
                                            : null,
                                        onPlayToggle: _useNativePreview
                                            ? _handlePlayToggle
                                            : null,
                                      ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: FxPalette.dividerSoft.withOpacity(0.9),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                              child: transitionFocusContext != null
                                  ? TimelinePanel(
                                      embedded: true,
                                      tracks: transitionFocusScopedTracks,
                                      currentTime: transitionFocusLocalTime,
                                      displayTimeListenable:
                                          _transitionFocusDisplayTimeNotifier,
                                      onDisplayTimeChanged: (localTime) =>
                                          _handleTransitionFocusDisplayTimeChanged(
                                        transitionFocusContext,
                                        localTime,
                                      ),
                                      onZoomStateChanged: (state) =>
                                          _handleTransitionFocusZoomStateChanged(
                                        transitionFocusContext,
                                        state,
                                      ),
                                      playbackSampleTimeListenable:
                                          _transitionFocusPlaybackSampleTimeNotifier,
                                      timelineDurationTime:
                                          transitionFocusContext.endTime -
                                              transitionFocusContext.startTime,
                                      timeDisplayOffset: TimelineTime.zero,
                                      nativeTimelineOffsetTime:
                                          transitionFocusContext.startTime,
                                      timeReadoutTotalTime:
                                          transitionFocusContext.endTime -
                                              transitionFocusContext.startTime,
                                      isPlaying: effectiveIsPlaying,
                                      timelineFps: _timelineFps,
                                      selectedClipId: _selectedClipId,
                                      selectedAnimationLaneId:
                                          resolvedTransitionFocusLaneId,
                                      selectedAnimationKeyframeIndex:
                                          resolvedTransitionFocusLaneId.isEmpty
                                              ? null
                                              : _selectedTransitionFocusKeyframeIndex,
                                      trimSelection:
                                          _transitionFocusTrimSelection(
                                        transitionFocusContext,
                                      ),
                                      onClipSelected: (clipId) =>
                                          _handleTransitionFocusClipSelected(
                                        transitionFocusContext,
                                        clipId,
                                      ),
                                      onTrackAnimateTap: (_) =>
                                          _openManualTransitionAnimateBrowser(
                                        transitionFocusContext.transition.id,
                                      ),
                                      onTrackFxTap: (_) =>
                                          _openManualTransitionFxBrowser(
                                        transitionFocusContext.transition.id,
                                      ),
                                      onTransitionTap: (_, __, ___) {},
                                      onAnimationLaneTap:
                                          _selectTransitionFocusLane,
                                      onAnimationKeyframeTap:
                                          _handleTransitionFocusAnimationKeyframeTap,
                                      onAnimationKeyframeDrag:
                                          _handleTransitionFocusAnimationKeyframeDrag,
                                      onBackgroundTap:
                                          _clearTransitionFocusSelection,
                                      onTrimCommit: (request) =>
                                          _handleTransitionFocusTrimCommit(
                                        transitionFocusContext,
                                        request,
                                      ),
                                      onTrimPreviewChanged: (request) =>
                                          _handleTransitionFocusTrimPreviewChanged(
                                        transitionFocusContext,
                                        request,
                                      ),
                                      onScrubStateChanged: (isScrubbing) =>
                                          _handleTransitionFocusScrubStateChanged(
                                        transitionFocusContext,
                                        isScrubbing,
                                      ),
                                      onScrubFinalized: (localTime) =>
                                          _handleTransitionFocusScrubFinalized(
                                        transitionFocusContext,
                                        localTime,
                                      ),
                                      scrubSurfaceBuilder:
                                          !_useNativeTimelineScrubInput
                                              ? null
                                              : (surfaceConfig) =>
                                                  NativeTimelineScrubSurface(
                                                    currentTime: surfaceConfig
                                                        .currentTime,
                                                    currentTimeListenable:
                                                        surfaceConfig
                                                            .currentTimeListenable,
                                                    timelineDurationTime:
                                                        surfaceConfig
                                                            .timelineDurationTime,
                                                    timelineOffsetTime:
                                                        surfaceConfig
                                                            .timelineOffsetTime,
                                                    secondsWidth: surfaceConfig
                                                        .secondsWidth,
                                                    timelineFps: surfaceConfig
                                                        .timelineFps,
                                                    configRevision:
                                                        _nativeTimelineScrubConfigRevisionFor(
                                                      surfaceConfig,
                                                    ),
                                                    onConfigApplied: (_) =>
                                                        _handleTimelineScrubConfigApplied(
                                                      _timelineScrubConfigRevision,
                                                    ),
                                                    regions:
                                                        surfaceConfig.regions,
                                                    previewSources:
                                                        _allLiveScrubPreviewSources(),
                                                    onTap: surfaceConfig.onTap,
                                                    onScrubStart: surfaceConfig
                                                        .onScrubStart,
                                                    onScrubTimeChanged:
                                                        surfaceConfig
                                                            .onScrubTimeChanged,
                                                    onScrubEnd: surfaceConfig
                                                        .onScrubEnd,
                                                    interactionEnabled:
                                                        !_isApplyingStructuralEdit &&
                                                            surfaceConfig
                                                                .interactionEnabled,
                                                  ),
                                      assetPathResolver: _resolveAssetPath,
                                      animateTrackKinds: const <TimelineTrackKind>{
                                        TimelineTrackKind.video,
                                      },
                                      fxTrackKinds: const <TimelineTrackKind>{
                                        TimelineTrackKind.video,
                                      },
                                    )
                                  : layerScopeContext != null
                                      ? TimelinePanel(
                                          embedded: true,
                                          tracks: layerScopeTracks,
                                          currentTime: layerScopeLocalTime,
                                          displayTimeListenable:
                                              _layerScopeDisplayTimeNotifier,
                                          onDisplayTimeChanged: (localTime) =>
                                              _handleLayerScopeDisplayTimeChanged(
                                            layerScopeContext,
                                            localTime,
                                          ),
                                          onZoomStateChanged: (state) =>
                                              _handleLayerScopeZoomStateChanged(
                                            layerScopeContext,
                                            state,
                                          ),
                                          playbackSampleTimeListenable:
                                              _layerScopePlaybackSampleTimeNotifier,
                                          timelineDurationTime:
                                              layerScopeContext.durationTime,
                                          timeDisplayOffset:
                                              layerScopeContext.startTime,
                                          timeReadoutTotalTime:
                                              _timelineDurationTime,
                                          isPlaying: effectiveIsPlaying,
                                          timelineFps: _timelineFps,
                                          selectedClipId: _selectedClipId,
                                          selectedAnimationLaneId:
                                              _selectedLayerScopeAnimationLaneId,
                                          selectedAnimationKeyframeIndex:
                                              _selectedLayerScopeKeyframeIndex,
                                          trimSelection:
                                              layerScopeTrimSelection,
                                          onClipSelected: (clipId) =>
                                              _handleLayerScopeClipSelected(
                                            layerScopeContext,
                                            clipId,
                                          ),
                                          onAnimationLaneTap:
                                              _handleLayerScopeAnimationLaneTap,
                                          onAnimationKeyframeTap:
                                              _handleLayerScopeAnimationKeyframeTap,
                                          onAnimationKeyframeDrag:
                                              _handleLayerScopeAnimationKeyframeDrag,
                                          onTrimCommit:
                                              _handleTimelineTrimCommit,
                                          onTrimPreviewChanged: (request) =>
                                              _handleLayerScopeTrimPreviewChanged(
                                            layerScopeContext,
                                            request,
                                          ),
                                          onScrubStateChanged:
                                              _handleScrubStateChanged,
                                          onScrubFinalized: (localTime) =>
                                              _handleLayerScopeScrubFinalized(
                                            layerScopeContext,
                                            localTime,
                                          ),
                                          scrubSurfaceBuilder:
                                              !_useNativeTimelineScrubInput
                                                  ? null
                                                  : (surfaceConfig) =>
                                                      NativeTimelineScrubSurface(
                                                        currentTime:
                                                            surfaceConfig
                                                                .currentTime,
                                                        currentTimeListenable:
                                                            surfaceConfig
                                                                .currentTimeListenable,
                                                        timelineDurationTime:
                                                            surfaceConfig
                                                                .timelineDurationTime,
                                                        timelineOffsetTime:
                                                            surfaceConfig
                                                                .timelineOffsetTime,
                                                        secondsWidth:
                                                            surfaceConfig
                                                                .secondsWidth,
                                                        timelineFps:
                                                            surfaceConfig
                                                                .timelineFps,
                                                        configRevision:
                                                            _nativeTimelineScrubConfigRevisionFor(
                                                          surfaceConfig,
                                                        ),
                                                        onConfigApplied: (_) =>
                                                            _handleTimelineScrubConfigApplied(
                                                          _timelineScrubConfigRevision,
                                                        ),
                                                        regions: surfaceConfig
                                                            .regions,
                                                        previewSources:
                                                            _allLiveScrubPreviewSources(),
                                                        onTap:
                                                            surfaceConfig.onTap,
                                                        onScrubStart:
                                                            surfaceConfig
                                                                .onScrubStart,
                                                        onScrubTimeChanged:
                                                            surfaceConfig
                                                                .onScrubTimeChanged,
                                                        onScrubEnd:
                                                            surfaceConfig
                                                                .onScrubEnd,
                                                        interactionEnabled:
                                                            !_isApplyingStructuralEdit &&
                                                                surfaceConfig
                                                                    .interactionEnabled,
                                                      ),
                                          assetPathResolver: _resolveAssetPath,
                                          onTrackAnimateTap:
                                              _handleLayerScopeAnimateTap,
                                          onTrackFxTap: _handleLayerScopeFxTap,
                                          animateTrackKinds: const <TimelineTrackKind>{
                                            TimelineTrackKind.text,
                                            TimelineTrackKind.image,
                                          },
                                          fxTrackKinds: const <TimelineTrackKind>{
                                            TimelineTrackKind.text,
                                          },
                                        )
                                      : TimelinePanel(
                                          embedded: true,
                                          tracks: mainTimelineTracks,
                                          currentTime: _currentTime,
                                          displayTimeListenable:
                                              _timelineDisplayTimeNotifier,
                                          onDisplayTimeChanged:
                                              _setTimelineDisplayTime,
                                          onZoomStateChanged:
                                              _handleTimelineZoomStateChanged,
                                          playbackSampleTimeListenable:
                                              _playbackSampleTimeNotifier,
                                          timelineDurationTime:
                                              _timelineDurationTime,
                                          isPlaying: effectiveIsPlaying,
                                          timelineFps: _timelineFps,
                                          selectedClipId: _selectedClipId,
                                          selectedTransitionId:
                                              _selectedClipId == null
                                                  ? _selectedTransitionId
                                                  : null,
                                          trimSelection: _timelineTrimSelection,
                                          onClipSelected: _selectClip,
                                          onClipDoubleTap:
                                              _handleTimelineClipDoubleTap,
                                          onClipReorder: _reorderClip,
                                          onClipTimeShift: _shiftClipInTimeline,
                                          onTransitionTap:
                                              (track, leftClip, rightClip) {
                                            unawaited(
                                              _handleTimelineTransitionTap(
                                                track,
                                                leftClip,
                                                rightClip,
                                              ),
                                            );
                                          },
                                          onTrackAnimateTap:
                                              _openAnimateBrowserForTrack,
                                          animateTrackKinds: const <TimelineTrackKind>{},
                                          onBackgroundTap: _clearSelection,
                                          onTrimCommit:
                                              _handleTimelineTrimCommit,
                                          onTrimPreviewChanged:
                                              _handleTimelineTrimPreviewChanged,
                                          assetPathResolver: _resolveAssetPath,
                                          onScrubStateChanged:
                                              _handleScrubStateChanged,
                                          onScrubFinalized:
                                              _handleTimelineScrubFinalized,
                                          scrubSurfaceBuilder:
                                              !_useNativeTimelineScrubInput
                                                  ? null
                                                  : (surfaceConfig) =>
                                                      NativeTimelineScrubSurface(
                                                        currentTime:
                                                            surfaceConfig
                                                                .currentTime,
                                                        currentTimeListenable:
                                                            surfaceConfig
                                                                .currentTimeListenable,
                                                        timelineDurationTime:
                                                            surfaceConfig
                                                                .timelineDurationTime,
                                                        timelineOffsetTime:
                                                            surfaceConfig
                                                                .timelineOffsetTime,
                                                        secondsWidth:
                                                            surfaceConfig
                                                                .secondsWidth,
                                                        timelineFps:
                                                            surfaceConfig
                                                                .timelineFps,
                                                        configRevision:
                                                            _nativeTimelineScrubConfigRevisionFor(
                                                          surfaceConfig,
                                                        ),
                                                        onConfigApplied: (_) =>
                                                            _handleTimelineScrubConfigApplied(
                                                          _timelineScrubConfigRevision,
                                                        ),
                                                        regions: surfaceConfig
                                                            .regions,
                                                        previewSources:
                                                            _allLiveScrubPreviewSources(),
                                                        onTap:
                                                            surfaceConfig.onTap,
                                                        onScrubStart:
                                                            surfaceConfig
                                                                .onScrubStart,
                                                        onScrubTimeChanged:
                                                            surfaceConfig
                                                                .onScrubTimeChanged,
                                                        onScrubEnd:
                                                            surfaceConfig
                                                                .onScrubEnd,
                                                        interactionEnabled:
                                                            !_isApplyingStructuralEdit &&
                                                                surfaceConfig
                                                                    .interactionEnabled,
                                                      ),
                                        ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: FxPalette.dividerSoft.withOpacity(0.9),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
                            child: transitionFocusContext != null
                                ? LayerScopeKeyframeDock(
                                    addEnabled: true,
                                    keyframeEnabled:
                                        canAddTransitionFocusKeyframe,
                                    valueEnabled:
                                        canOpenTransitionFocusValueEditor,
                                    graphEnabled: false,
                                    isValueActive:
                                        _isTransitionFocusValueEditorOpen &&
                                            canOpenTransitionFocusValueEditor,
                                    isGraphActive:
                                        _isTransitionFocusGraphEditorOpen,
                                    onAddTap: () => _openTransitionFocusAddMenu(
                                      transitionFocusContext.transition.id,
                                    ),
                                    onAddKeyframeTap:
                                        canAddTransitionFocusKeyframe
                                            ? _handleTransitionFocusAddKeyframe
                                            : null,
                                    onValueTap:
                                        canOpenTransitionFocusValueEditor
                                            ? _handleTransitionFocusValueToolTap
                                            : null,
                                    onGraphTap: null,
                                    embedded: true,
                                    addLabel: 'Add',
                                    addIcon: Icons.auto_awesome_motion_rounded,
                                  )
                                : isLayerScopeActive
                                    ? LayerScopeKeyframeDock(
                                        addEnabled: true,
                                        keyframeEnabled:
                                            canAddLayerScopeKeyframe,
                                        valueEnabled:
                                            canOpenLayerScopeValueEditor,
                                        graphEnabled:
                                            canOpenLayerScopeGraphEditor,
                                        isValueActive:
                                            _isLayerScopeValueEditorOpen &&
                                                canOpenLayerScopeValueEditor,
                                        isGraphActive:
                                            _isLayerScopeGraphEditorOpen &&
                                                canOpenLayerScopeGraphEditor,
                                        onAddTap: _handleLayerScopeDockAddTap,
                                        onAddKeyframeTap:
                                            _handleLayerScopeAddKeyframe,
                                        onValueTap: canOpenLayerScopeValueEditor
                                            ? _handleLayerScopeValueToolTap
                                            : null,
                                        onGraphTap: canOpenLayerScopeGraphEditor
                                            ? _handleLayerScopeGraphToolTap
                                            : null,
                                        embedded: true,
                                        addLabel: isTextLayerScopeActive
                                            ? 'Script'
                                            : 'Add',
                                        addIcon: isTextLayerScopeActive
                                            ? Icons.code_rounded
                                            : Icons.add_rounded,
                                      )
                                    : MediaDock(
                                        activeTab: effectiveDockActiveTab,
                                        onAddTap: () {
                                          if (effectiveDockActiveTab ==
                                                  EditorMediaTab.video ||
                                              effectiveDockActiveTab ==
                                                  EditorMediaTab.image) {
                                            _openMediaSheet(
                                              effectiveDockActiveTab ==
                                                      EditorMediaTab.image
                                                  ? EditorMediaTab.image
                                                  : EditorMediaTab.video,
                                            );
                                          }
                                        },
                                        onToolTap: _handleDockTab,
                                        enabledTabs: enabledDockTabs,
                                        addEnabled: effectiveDockActiveTab ==
                                                EditorMediaTab.video ||
                                            effectiveDockActiveTab ==
                                                EditorMediaTab.image,
                                        embedded: true,
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: activeTextEditSession == null
                      ? const SizedBox.shrink(key: ValueKey('no-text-edit'))
                      : TextClipEditBottomSheet(
                          key: ValueKey(
                            'text-edit-${activeTextEditSession.elementId}',
                          ),
                          initialDraft: activeTextEditSession.draft,
                          onDraftChanged: _handleTextEditDraftChanged,
                          onPlayPreview: _handleTextEditPreviewToggle,
                          isPlayPreviewEnabled: _canPreviewActiveTextEditRange,
                          isPreviewPlaying: _isActiveTextEditPreviewPlaying,
                          onCancel: _cancelTextEditSession,
                          onDone: _commitTextEditSession,
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

class _LayerScopeSession {
  const _LayerScopeSession({
    required this.clipId,
    required this.returnSelectedClipId,
  });

  final String clipId;
  final String? returnSelectedClipId;
}

class _LayerScopeContext {
  const _LayerScopeContext({
    required this.clipContext,
    required this.startTime,
    required this.durationTime,
  });

  final _SelectedTimelineClipContext clipContext;
  final TimelineTime startTime;
  final TimelineTime durationTime;

  TimelineTrackData get track => clipContext.track;
  TimelineClipData get clip => clipContext.clip;
  TimelineTime get endTime => startTime + durationTime;
}

class _LayerScopeToolsBar extends StatelessWidget {
  const _LayerScopeToolsBar({
    required this.isPlaying,
    required this.onBack,
    required this.onSplit,
    required this.onTrimToggle,
    required this.isTrimModeActive,
    required this.onDuplicate,
    required this.onMoveToKeyframe,
    required this.onPlayToggle,
  });

  final bool isPlaying;
  final VoidCallback onBack;
  final VoidCallback? onSplit;
  final VoidCallback? onTrimToggle;
  final bool isTrimModeActive;
  final VoidCallback? onDuplicate;
  final VoidCallback? onMoveToKeyframe;
  final VoidCallback? onPlayToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          FxIconButton(
            icon: Icons.arrow_back_rounded,
            size: 30,
            iconScale: 0.46,
            foregroundColor: FxPalette.textPrimary,
            onPressed: onBack,
          ),
          const SizedBox(width: 5),
          FxIconButton(
            icon: Icons.cut_rounded,
            size: 30,
            iconScale: 0.4,
            onPressed: onSplit,
          ),
          const SizedBox(width: 5),
          FxIconButton(
            icon: Icons.fit_screen_rounded,
            size: 30,
            iconScale: 0.4,
            foregroundColor:
                isTrimModeActive ? FxPalette.background : FxPalette.textMuted,
            backgroundColor:
                isTrimModeActive ? FxPalette.accent : FxPalette.surface,
            onPressed: onTrimToggle,
          ),
          const SizedBox(width: 5),
          FxIconButton(
            icon: Icons.copy_rounded,
            size: 30,
            iconScale: 0.4,
            onPressed: onDuplicate,
          ),
          const SizedBox(width: 5),
          FxIconButton(
            icon: Icons.open_with_rounded,
            size: 30,
            iconScale: 0.4,
            onPressed: onMoveToKeyframe,
          ),
          const Spacer(),
          Container(
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 1,
            color: FxPalette.dividerSoft.withOpacity(0.9),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: FxIconButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
              iconScale: 0.48,
              foregroundColor: FxPalette.textPrimary,
              onPressed: onPlayToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedMotionTextTimelineState {
  const _ResolvedMotionTextTimelineState({
    required this.selectedClipId,
    required this.timelineTime,
    required this.previewAssetId,
  });

  final String? selectedClipId;
  final TimelineTime timelineTime;
  final String? previewAssetId;
}

class _PositionedTimelineTrackClip {
  const _PositionedTimelineTrackClip({
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

class _SelectedTimelineClipContext {
  const _SelectedTimelineClipContext({
    required this.trackIndex,
    required this.clipIndex,
    required this.track,
    required this.clip,
    required this.asset,
    required this.clipStartTime,
    required this.clipEndTime,
  });

  final int trackIndex;
  final int clipIndex;
  final TimelineTrackData track;
  final TimelineClipData clip;
  final EditorAssetItem? asset;
  final TimelineTime clipStartTime;
  final TimelineTime clipEndTime;

  double get clipStartSeconds => clipStartTime.inSecondsDouble;

  double get clipEndSeconds => clipEndTime.inSecondsDouble;
}

enum _TimelineStructuralEditKind {
  delete,
  duplicate,
  reorder,
  split,
}

enum _TimelineGapPolicy {
  gaplessTrack,
}

enum _TimelineRipplePolicy {
  none,
  trackLocalDelete,
}

enum _TimelineSelectionAnchorPolicy {
  structuralTarget,
  selectedClipStart,
}

class _TimelineStructuralEditPlan {
  const _TimelineStructuralEditPlan({
    required this.kind,
    required this.editedTrackIndex,
    required this.gapPolicy,
    required this.ripplePolicy,
    required this.selectionAnchorPolicy,
    required this.tracks,
    required this.targetTime,
    required this.selectedClipId,
    required this.previewAssetId,
  });

  final _TimelineStructuralEditKind kind;
  final int editedTrackIndex;
  final _TimelineGapPolicy gapPolicy;
  final _TimelineRipplePolicy ripplePolicy;
  final _TimelineSelectionAnchorPolicy selectionAnchorPolicy;
  final List<TimelineTrackData> tracks;
  final TimelineTime targetTime;
  final String? selectedClipId;
  final String? previewAssetId;
}

class _MotionTextElementContext {
  const _MotionTextElementContext({
    required this.project,
    required this.sceneIndex,
    required this.layerIndex,
    required this.elementIndex,
    required this.scene,
    required this.layer,
    required this.element,
  });

  final MotionProjectModel project;
  final int sceneIndex;
  final int layerIndex;
  final int elementIndex;
  final MotionSceneModel scene;
  final MotionLayerModel layer;
  final MotionElementModel element;

  MotionPropertyTarget get elementTarget => MotionPropertyTarget(
        kind: MotionTargetKind.element,
        targetId: element.id,
        projectId: project.id,
        sceneId: scene.id,
        layerId: layer.id,
        elementId: element.id,
      );
}

class _ActiveTextEditSession {
  const _ActiveTextEditSession({
    required this.elementId,
    required this.originalProject,
    required this.originalBindings,
    required this.draft,
  });

  final String elementId;
  final MotionProjectModel originalProject;
  final List<MotionTextAnimationBindingModel> originalBindings;
  final TextClipEditDraft draft;

  _ActiveTextEditSession copyWith({
    String? elementId,
    MotionProjectModel? originalProject,
    List<MotionTextAnimationBindingModel>? originalBindings,
    TextClipEditDraft? draft,
  }) {
    return _ActiveTextEditSession(
      elementId: elementId ?? this.elementId,
      originalProject: originalProject ?? this.originalProject,
      originalBindings: originalBindings ?? this.originalBindings,
      draft: draft ?? this.draft,
    );
  }
}

class _TextEditPreviewRange {
  const _TextEditPreviewRange({
    required this.elementId,
    required this.start,
    required this.end,
  });

  final String elementId;
  final TimelineTime start;
  final TimelineTime end;
}

class _ActiveTimelineTransitionPreview {
  const _ActiveTimelineTransitionPreview({
    required this.transition,
    required this.leftClip,
    required this.rightClip,
    required this.progress,
    required this.manualLaneProgress,
    required this.manualSeamProgress,
  });

  final TimelineTrackTransitionData transition;
  final _PositionedTimelineTrackClip leftClip;
  final _PositionedTimelineTrackClip rightClip;
  final double progress;
  final double manualLaneProgress;
  final double manualSeamProgress;
}

class _TransitionVideoFxCommand {
  const _TransitionVideoFxCommand({
    required this.blurSigma,
  });

  final double blurSigma;

  bool get hasVisibleEffect => blurSigma > 0.05;
}

class _TransitionFocusSession {
  const _TransitionFocusSession({
    required this.transitionId,
    required this.selectedLaneId,
  });

  final String transitionId;
  final String selectedLaneId;

  _TransitionFocusSession copyWith({
    String? transitionId,
    String? selectedLaneId,
  }) {
    return _TransitionFocusSession(
      transitionId: transitionId ?? this.transitionId,
      selectedLaneId: selectedLaneId ?? this.selectedLaneId,
    );
  }
}

class _TransitionFocusContext {
  const _TransitionFocusContext({
    required this.transition,
    required this.leftClip,
    required this.rightClip,
    required this.seamTime,
    required this.activeStartTime,
    required this.activeEndTime,
    required this.startTime,
    required this.endTime,
  });

  final TimelineTrackTransitionData transition;
  final TimelineClipData leftClip;
  final TimelineClipData rightClip;
  final TimelineTime seamTime;
  final TimelineTime activeStartTime;
  final TimelineTime activeEndTime;
  final TimelineTime startTime;
  final TimelineTime endTime;
}

enum _TransitionFocusClipSide {
  left,
  right,
}

class _TransitionFocusLaneSpec {
  const _TransitionFocusLaneSpec({
    required this.id,
    required this.groupLabel,
    required this.label,
    required this.editorDescription,
    required this.min,
    required this.max,
    required this.fallback,
    required this.valueFormatter,
    required this.keyframeStops,
    this.tint = FxPalette.accent,
  });

  final String id;
  final String groupLabel;
  final String label;
  final String editorDescription;
  final double min;
  final double max;
  final double fallback;
  final String Function(double value) valueFormatter;
  final List<double> keyframeStops;
  final Color tint;

  _TransitionFocusLaneSpec copyWith({
    String? id,
    String? groupLabel,
    String? label,
    String? editorDescription,
    double? min,
    double? max,
    double? fallback,
    String Function(double value)? valueFormatter,
    List<double>? keyframeStops,
    Color? tint,
  }) {
    return _TransitionFocusLaneSpec(
      id: id ?? this.id,
      groupLabel: groupLabel ?? this.groupLabel,
      label: label ?? this.label,
      editorDescription: editorDescription ?? this.editorDescription,
      min: min ?? this.min,
      max: max ?? this.max,
      fallback: fallback ?? this.fallback,
      valueFormatter: valueFormatter ?? this.valueFormatter,
      keyframeStops: keyframeStops ?? this.keyframeStops,
      tint: tint ?? this.tint,
    );
  }
}

class _MotionTextTimelineEntry {
  const _MotionTextTimelineEntry({
    required this.elementId,
    required this.start,
    required this.end,
    required this.label,
  });

  final String elementId;
  final TimelineTime start;
  final TimelineTime end;
  final String label;
}

class _ResolvedTimelineTrimValues {
  const _ResolvedTimelineTrimValues({
    required this.sourceStartTime,
    required this.sourceDurationTime,
    required this.durationTime,
    required this.assetDurationTime,
  });

  final TimelineTime sourceStartTime;
  final TimelineTime sourceDurationTime;
  final TimelineTime durationTime;
  final TimelineTime? assetDurationTime;
}

class _TimelineTrimPreviewSession {
  const _TimelineTrimPreviewSession({
    required this.clipId,
    required this.timelinePreviewTime,
    required this.previewAssetId,
    this.sourceUri,
    this.sourceLabel,
    this.sourcePreviewTime,
  });

  final String clipId;
  final TimelineTime timelinePreviewTime;
  final String? previewAssetId;
  final String? sourceUri;
  final String? sourceLabel;
  final TimelineTime? sourcePreviewTime;

  bool get usesTransportPreview => sourceUri != null && sourceUri!.isNotEmpty;
}

class _AiTransitionBoundarySeed {
  const _AiTransitionBoundarySeed({
    required this.leftAssetId,
    required this.rightAssetId,
    required this.leftFramePositionMs,
    required this.rightFramePositionMs,
    required this.aspectRatioHint,
    this.firstFrameBytes,
    this.lastFrameBytes,
  });

  final String leftAssetId;
  final String rightAssetId;
  final int leftFramePositionMs;
  final int rightFramePositionMs;
  final String? aspectRatioHint;
  final Uint8List? firstFrameBytes;
  final Uint8List? lastFrameBytes;
}

class _AiTransitionClipLocation {
  const _AiTransitionClipLocation({
    required this.trackIndex,
    required this.clipIndex,
    required this.track,
    required this.clip,
  });

  final int trackIndex;
  final int clipIndex;
  final TimelineTrackData track;
  final TimelineClipData clip;
}

class _TopStageBannerCard extends StatelessWidget {
  const _TopStageBannerCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.98),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: FxPalette.accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: FxPalette.accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CleanPreviewCanvas extends StatelessWidget {
  const _CleanPreviewCanvas({
    required this.asset,
    this.previewThumbnailAssetId,
    this.previewThumbnailListenable,
  });

  final EditorAssetItem? asset;
  final String? previewThumbnailAssetId;
  final ValueListenable<Uint8List?>? previewThumbnailListenable;

  @override
  Widget build(BuildContext context) {
    final previewThumbnailListenable = this.previewThumbnailListenable;
    if (previewThumbnailListenable != null) {
      return ValueListenableBuilder<Uint8List?>(
        valueListenable: previewThumbnailListenable,
        builder: (context, bytes, _) {
          return _buildCanvas(bytes);
        },
      );
    }
    return _buildCanvas(null);
  }

  Widget _buildCanvas(Uint8List? previewBytes) {
    if (asset == null) {
      return const SizedBox.expand();
    }
    final shouldShowPoster = previewBytes != null &&
        previewBytes.isNotEmpty &&
        (previewThumbnailAssetId == null ||
            previewThumbnailAssetId == asset?.id);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (shouldShowPoster)
            Image.memory(
              previewBytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
        ],
      ),
    );
  }
}
