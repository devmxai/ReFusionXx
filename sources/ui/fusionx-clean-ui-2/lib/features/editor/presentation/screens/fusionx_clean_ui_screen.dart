import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/engine/live_scrub_preview_sources.dart';
import '../../../../core/engine/stage5_native_transport_controller.dart';
import '../../../../core/engine/stage6_export_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/export_composition_builder.dart';
import '../../domain/models/export_composition_models.dart';
import '../../domain/models/export_output_profile.dart';
import '../../domain/models/export_motion_text_program_models.dart';
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
import '../models/editor_asset_item.dart';
import '../models/editor_media_tab.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';
import '../widgets/editor_tools_bar.dart';
import '../widgets/editor_top_bar.dart';
import '../widgets/animate_browser_bottom_sheet.dart';
import '../widgets/clip_speed_bottom_sheet.dart';
import '../widgets/export_bottom_sheet.dart';
import '../widgets/media_bottom_sheet.dart';
import '../widgets/media_dock.dart';
import '../widgets/motion_text_preview_overlay.dart';
import '../widgets/motion_text_transform_overlay.dart';
import '../widgets/native_timeline_scrub_surface.dart';
import '../widgets/native_preview_surface.dart';
import '../widgets/preview_stage.dart';
import '../widgets/text_clip_edit_bottom_sheet.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/timeline_transition_preview_overlay.dart';
import '../widgets/transition_browser_bottom_sheet.dart';
import '../widgets/transition_focus_panel.dart';
import '../widgets/transition_inspector_bottom_sheet.dart';
import '../widgets/text_preset_bottom_sheet.dart';

class FusionXCleanUiScreen extends StatefulWidget {
  const FusionXCleanUiScreen({super.key});

  @override
  State<FusionXCleanUiScreen> createState() => _FusionXCleanUiScreenState();
}

class _FusionXCleanUiScreenState extends State<FusionXCleanUiScreen> {
  static const double _minEditableClipDuration = 0.25;
  static const int _deviceMediaPageSize = 24;
  static const String _motionProjectId = 'motion-project';
  static const String _motionSceneId = 'scene-main';
  static const String _exportContractVersion = 'v1alpha1';
  static final TimelineTime _manualTransitionMinimumScopeSideTime =
      TimelineTime.fromSecondsDouble(10);
  static const bool _textPresetPickerEnabled = false;
  static const String _defaultInsertedTextValue = 'Text';
  static const double _defaultInsertedTextFontSize = 56;
  static final TimelineTime _defaultTextPresetDurationTime =
      TimelineTime.fromSecondsDouble(3);
  static const List<AnimateBrowserItem> _manualTransitionEffectItems =
      <AnimateBrowserItem>[
    AnimateBrowserItem(
      id: 'outgoingBoostScale',
      label: 'Outgoing Scale',
      category: 'Transform',
      summary: 'Push the outgoing clip forward before the handoff.',
      keywords: <String>['zoom out', 'scale', 'push'],
    ),
    AnimateBrowserItem(
      id: 'incomingStartScale',
      label: 'Incoming Scale',
      category: 'Transform',
      summary: 'Start the incoming clip close, then relax to full frame.',
      keywords: <String>['zoom in', 'scale', 'size'],
    ),
    AnimateBrowserItem(
      id: 'blackPeak',
      label: 'Black Mix',
      category: 'Visual',
      summary: 'Dip through black around the seam midpoint.',
      keywords: <String>['fade', 'opacity', 'black'],
    ),
    AnimateBrowserItem(
      id: 'bridgeDarkness',
      label: 'Bridge Darkness',
      category: 'Visual',
      summary: 'Add a dark cinematic bridge between the two clips.',
      keywords: <String>['dark', 'bridge', 'shade'],
    ),
    AnimateBrowserItem(
      id: 'entryDelay',
      label: 'Entry Delay',
      category: 'Timing',
      summary: 'Delay when the incoming clip starts taking over.',
      keywords: <String>['timing', 'delay', 'handoff'],
    ),
  ];

  late final Stage5NativeTransportController _transportController;
  late final InMemoryLiveScrubPreviewSourceCatalog
      _liveScrubPreviewSourceCatalog;
  late final Stage6ExportController _exportController;
  late final ValueNotifier<List<EditorAssetItem>> _assetLibrary;
  late final ValueNotifier<bool> _assetLibraryLoading;
  late final ValueNotifier<String?> _assetLibraryError;
  late final ValueNotifier<TimelineTime> _timelineDisplayTimeNotifier;
  late final ValueNotifier<TimelineTime> _playbackSampleTimeNotifier;
  late final ValueNotifier<TimelineTime> _transitionFocusDisplayTimeNotifier;
  late final ValueNotifier<TimelineTime>
      _transitionFocusPlaybackSampleTimeNotifier;
  late final ValueNotifier<Uint8List?> _previewThumbnailNotifier;
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
  String? _previewAssetId;
  PreviewViewportState _previewViewportState = PreviewViewportState.identity;
  double? _lockedWorkspaceAspectRatio;
  TimelineTime _currentTime = TimelineTime.zero;
  bool _isPlaying = false;
  bool _isTimelineScrubbing = false;
  bool _isTimelineScrubHandoffInFlight = false;
  bool _isAnimateBrowserOpen = false;
  TimelineTime? _timelineScrubFinalTime;
  bool _isApplyingStructuralEdit = false;
  Future<void> _timelineStructuralCommit = Future<void>.value();
  int _timelineScrubReadinessRequestId = 0;
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
  MotionNormalizedComposition? _cachedMotionComposition;
  int _motionRevision = 0;
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

  @override
  void initState() {
    super.initState();
    final transportController = Stage5NativeTransportController();
    transportController.addListener(_handleTransportStateChanged);
    _transportController = transportController;
    _liveScrubPreviewSourceCatalog = InMemoryLiveScrubPreviewSourceCatalog();
    final exportController = Stage6ExportController();
    exportController.addListener(_handleExportStateChanged);
    _exportController = exportController;
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
    _previewThumbnailNotifier = ValueNotifier<Uint8List?>(null);
    _assetOffsets[EditorMediaTab.video] = 0;
    _assetOffsets[EditorMediaTab.image] = 0;
    _assetHasMore[EditorMediaTab.video] = true;
    _assetHasMore[EditorMediaTab.image] = true;
    _tracks = _buildInitialTracks();
    _motionProject = _buildInitialMotionProject();
    unawaited(_transportController.initialize());
    unawaited(_exportController.ensureInitialized());
  }

  @override
  void dispose() {
    _exportController
      ..removeListener(_handleExportStateChanged)
      ..dispose();
    _transportController
      ..removeListener(_handleTransportStateChanged)
      ..dispose();
    _assetLibrary.dispose();
    _assetLibraryLoading.dispose();
    _assetLibraryError.dispose();
    _timelineDisplayTimeNotifier.dispose();
    _playbackSampleTimeNotifier.dispose();
    _transitionFocusDisplayTimeNotifier.dispose();
    _transitionFocusPlaybackSampleTimeNotifier.dispose();
    _previewThumbnailNotifier.dispose();
    super.dispose();
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
                isPlaceholder: clip.type != TimelineClipType.media,
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
      if (transition.preset == TimelineTransitionPreset.manual &&
          transition.manualEffectIds.isEmpty) {
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
      TimelineTransitionPreset.fadeBlack => MotionTransitionKind.fade,
      TimelineTransitionPreset.zoomInCamera => MotionTransitionKind.cameraPush,
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

  void _scheduleNativeTimelineScrubReadiness(TimelineTime targetTime) {
    final requestId = ++_timelineScrubReadinessRequestId;
    unawaited(() async {
      await _awaitNativeTimelineScrubReadiness(targetTime);
      if (!mounted || requestId != _timelineScrubReadinessRequestId) {
        return;
      }
    }());
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
  }

  void _setTimelineDisplayTime(TimelineTime time) {
    final clamped = time.clamp(TimelineTime.zero, _timelineDurationTime);
    _applyTimelineDisplayTime(clamped);
  }

  void _setCurrentTime(TimelineTime time) {
    final clamped = time.clamp(TimelineTime.zero, _timelineDurationTime);
    _currentTime = clamped;
    _setTimelineDisplayTime(clamped);
    if (!_isTimelineScrubbing && (!_isPlaying || !_useNativePreview)) {
      _setPlaybackSampleTime(clamped);
    }
  }

  void _setPlaybackSampleTime(TimelineTime time) {
    final clamped = time.clamp(TimelineTime.zero, _timelineDurationTime);
    if (_playbackSampleTimeNotifier.value != clamped) {
      _playbackSampleTimeNotifier.value = clamped;
    }
    _syncTransitionFocusTimeNotifiers();
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

  void _syncPlaybackSampleToCurrentTime() {
    _setPlaybackSampleTime(_currentTime);
  }

  Future<void> _pausePlayback() => _transportController.pause();

  Future<void> _playPlayback() => _transportController.play();

  Future<void> _togglePlayback() => _transportController.togglePlayPause();

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
    final shouldAdoptPlayingTransportDuringStructuralEdit =
        _isApplyingStructuralEdit && transportState.isPlaying;
    final shouldAdoptTransportTime = (!_isApplyingStructuralEdit ||
            shouldAdoptPlayingTransportDuringStructuralEdit) &&
        !_isTimelineScrubbing &&
        !_isTimelineScrubHandoffInFlight &&
        !isTrimPreviewActive &&
        !transportState.isScrubSettling;
    final reportedTransportTime = TimelineTime.fromMilliseconds(
      transportState.positionMs,
    ).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    final isTransientPlaybackRegression = transportState.isPlaying &&
        shouldAdoptTransportTime &&
        (_currentTime - reportedTransportTime).inSecondsDouble > 0 &&
        (_currentTime - reportedTransportTime).inSecondsDouble <= 0.24;
    if (shouldAdoptTransportTime && !isTransientPlaybackRegression) {
      _setPlaybackSampleTime(reportedTransportTime);
      if (!transportState.isPlaying) {
        _setTimelineDisplayTime(reportedTransportTime);
      }
    }
    final shouldUpdatePlaying = (!_isApplyingStructuralEdit ||
            shouldAdoptPlayingTransportDuringStructuralEdit) &&
        transportState.isPlaying != _isPlaying;
    final nextCurrentTime =
        shouldAdoptTransportTime && !isTransientPlaybackRegression
            ? reportedTransportTime
            : _currentTime;
    final shouldUpdateAspect = nextAspectRatio != _lockedWorkspaceAspectRatio;
    final shouldUpdateTime = nextCurrentTime != _currentTime;
    if (!shouldUpdateAspect && !shouldUpdateTime && !shouldUpdatePlaying) {
      return;
    }
    if (!shouldUpdateAspect && !shouldUpdatePlaying) {
      _setCurrentTime(nextCurrentTime);
      if (_isTimelineScrubHandoffInFlight &&
          !_isTimelineScrubbing &&
          !transportState.isScrubSettling) {
        _isTimelineScrubHandoffInFlight = false;
      }
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
    if (_isTimelineScrubHandoffInFlight &&
        !_isTimelineScrubbing &&
        !transportState.isScrubSettling) {
      _isTimelineScrubHandoffInFlight = false;
    }
  }

  void _handleTimelineTimeChanged(TimelineTime time) {
    if (_isApplyingStructuralEdit) {
      return;
    }
    final clampedTime = time.clamp(TimelineTime.zero, _timelineDurationTime);
    if (_isTimelineScrubbing) {
      _timelineScrubFinalTime = clampedTime;
    }
    if (_isTimelineScrubHandoffInFlight) {
      _timelineScrubFinalTime = clampedTime;
      return;
    }
    if (_isTimelineScrubbing && _useNativeTimelineScrubInput) {
      _setCurrentTime(clampedTime);
      _setPlaybackSampleTime(clampedTime);
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
    if (!_isMotionTextElementId(clipId)) {
      return;
    }
    _selectTextElement(clipId);
    unawaited(_openTextClipEditSheet(clipId));
  }

  void _handleCanvasTextSelected(String elementId) {
    _selectTextElement(elementId);
  }

  void _handleCanvasTextEditRequested(String elementId) {
    _selectTextElement(elementId);
    unawaited(_openTextClipEditSheet(elementId));
  }

  void _handleCanvasTextMoved(String elementId, Offset deltaCanvas) {
    final context = _motionTextElementContextForId(elementId);
    if (context == null) {
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
      _motionRevision += 1;
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
    final nextChannels = _setTextMotionScalarKeyframes(
      context: context,
      scalarValues: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.scaleX: scaleX.clamp(0.2, 8.0),
        MotionPropertyCatalog.scaleY: scaleY.clamp(0.2, 8.0),
      },
    );
    setState(() {
      _manualMotionPropertyChannels = nextChannels;
      _motionRevision += 1;
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
    final nextChannels = _setTextMotionScalarKeyframes(
      context: context,
      scalarValues: <MotionPropertyDefinition, double>{
        MotionPropertyCatalog.rotationDegrees: rotationDegrees,
      },
    );
    setState(() {
      _manualMotionPropertyChannels = nextChannels;
      _motionRevision += 1;
      _selectedClipId = elementId;
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
      _motionRevision += 1;
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
      _motionRevision += 1;
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
      _motionRevision += 1;
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
      _motionRevision += 1;
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
    if (_textPresetPickerEnabled) {
      unawaited(_openTextPresetSheet());
      return;
    }
    _insertDefaultTextLayer();
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

  void _addAnimateLaneToTrack(
    TimelineTrackData displayTrack,
    AnimateBrowserItem item,
  ) {
    final targetClip = _resolveAnimateTargetClipForTrack(displayTrack);
    if (targetClip == null) {
      _showStageMessage('Select a layer clip before adding animation.');
      return;
    }

    final trackIndex = _tracks.indexWhere(
      (candidate) => candidate.kind == displayTrack.kind,
    );
    if (trackIndex < 0) {
      return;
    }

    final baseTrack = _tracks[trackIndex];
    final alreadyExists = baseTrack.animationLanes.any(
      (lane) =>
          lane.targetClipId == targetClip.id &&
          lane.label.toLowerCase() == item.label.toLowerCase(),
    );
    if (alreadyExists) {
      _showStageMessage('${item.label} already exists on this layer.');
      return;
    }

    final nextLane = TimelineAnimationLaneData(
      id: 'anim-${displayTrack.kind.name}-${targetClip.id}-${DateTime.now().microsecondsSinceEpoch}',
      label: item.label,
      targetClipId: targetClip.id,
      normalizedKeyframeStops: _mockAnimationKeyframeStopsForItem(item),
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
    });
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

  void _insertDefaultTextLayer() {
    _insertMotionTextLayer(
      text: _defaultInsertedTextValue,
      elementName: _defaultInsertedTextValue,
      initialFontSize: _defaultInsertedTextFontSize,
      failureMessage: 'Unable to insert text right now.',
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
    await _playPlayback();
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
      _motionRevision += 1;
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
      _motionRevision += 1;
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
    );
  }

  void _insertMotionTextLayer({
    String? presetId,
    required String text,
    required String elementName,
    double? initialFontSize,
    required String failureMessage,
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
      _motionRevision += 1;
      _selectedClipId = resolvedState.selectedClipId;
      _activeTab = EditorMediaTab.text;
      _previewAssetId = resolvedState.previewAssetId;
      _setCurrentTime(resolvedState.timelineTime);
    });
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
          _scheduleNativeTimelineScrubReadiness(safeTargetTime);
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

    if (preferredAssetId != null &&
        orderedVisualAssetIds.contains(preferredAssetId)) {
      return preferredAssetId;
    }
    final timelineAssetId = nearestAssetIdForTime();
    if (timelineAssetId != null &&
        orderedVisualAssetIds.contains(timelineAssetId)) {
      return timelineAssetId;
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
      _setTimelineDisplayTime(_currentTime);
      _syncPlaybackSampleToCurrentTime();
      unawaited(_togglePlayback());
      return;
    }
    unawaited(_togglePlayAfterStructuralCommit());
  }

  bool get _canFastTogglePlayback =>
      _useNativePreview &&
      !_isApplyingStructuralEdit &&
      _timelineTrimPreviewSession == null &&
      _transportController.state.sourceKind == 'timeline';

  Future<void> _toggleTransitionFocusPlayback(
    _TransitionFocusContext context,
  ) async {
    await _timelineStructuralCommit;
    if (!mounted || _isApplyingStructuralEdit || !_useNativePreview) {
      return;
    }
    if (_transportController.isPlaying) {
      await _stopTransitionFocusPlayback(
        context,
        snapToStart: false,
      );
      return;
    }
    final startTime = context.startTime;
    final endTime = context.endTime;
    final effectiveStartTime =
        _currentTime >= startTime && _currentTime < endTime
            ? _currentTime
            : startTime;
    _setCurrentTime(effectiveStartTime);
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
      await _seekPlaybackTo(effectiveStartTime);
    }
    if (!mounted) {
      return;
    }
    await _playPlayback();
  }

  Future<void> _stopTransitionFocusPlayback(
    _TransitionFocusContext context, {
    required bool snapToStart,
  }) async {
    if (_isStoppingTransitionFocusPlayback || !_useNativePreview) {
      return;
    }
    _isStoppingTransitionFocusPlayback = true;
    try {
      await _pausePlayback();
      final targetTime = snapToStart ? context.startTime : context.endTime;
      await _seekPlaybackTo(targetTime);
      if (!mounted) {
        return;
      }
      setState(() {
        _setCurrentTime(targetTime);
      });
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
    await _playPlayback();
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
      _isTimelineScrubHandoffInFlight = false;
      final scrubAnchorTime = (_timelineScrubFinalTime ??
              (_isPlaying ? _timelineDisplayTimeNotifier.value : _currentTime))
          .clamp(TimelineTime.zero, _timelineDurationTime);
      _timelineScrubFinalTime = scrubAnchorTime;
      _setCurrentTime(scrubAnchorTime);
      unawaited(_pausePlayback());
      return;
    }

    final finalTimelineTime = _timelineScrubFinalTime;
    final resolvedFinalTime = (finalTimelineTime ?? _currentTime)
        .clamp(TimelineTime.zero, _timelineDurationTime);
    _isTimelineScrubHandoffInFlight = true;
    _timelineScrubFinalTime = null;
    if ((resolvedFinalTime - _currentTime).inSecondsDouble.abs() > 0.002) {
      setState(() {
        _setCurrentTime(resolvedFinalTime);
      });
    }
    _setPlaybackSampleTime(resolvedFinalTime);
    unawaited(
      _transportController
          .settleAfterScrubPositionMs(resolvedFinalTime.inMilliseconds)
          .whenComplete(() {
        if (!mounted) {
          return;
        }
        if (!_transportController.state.isScrubSettling) {
          _isTimelineScrubHandoffInFlight = false;
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

  void _handleTransitionFocusScrubFinalized(
    _TransitionFocusContext context,
    TimelineTime localTime,
  ) {
    _handleTimelineScrubFinalized(
      (context.startTime + localTime).clamp(
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
    _setTimelineDisplayTime(_currentTime);
    _syncPlaybackSampleToCurrentTime();
    if (!_transportController.isPlaying && _useNativePreview) {
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
          targetTime: _currentTime,
        );
      }
    }
    await _togglePlayback();
  }

  void _showStageMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  void _upsertVideoTrackTransition(TimelineTrackTransitionData transition) {
    final videoTrackIndex = _tracks.indexWhere(
      (track) => track.kind == TimelineTrackKind.video,
    );
    if (videoTrackIndex < 0) {
      return;
    }
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
    final startTime = (seamTime - transition.resolvedLeadingDurationTime).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    final endTime = (seamTime + transition.resolvedTrailingDurationTime).clamp(
      TimelineTime.zero,
      _timelineDurationTime,
    );
    if (endTime <= startTime) {
      return null;
    }
    return _TransitionFocusContext(
      transition: transition,
      leftClip: leftClip.clip,
      rightClip: rightClip.clip,
      seamTime: seamTime,
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
    if (_selectedClipId == null) {
      return;
    }
    setState(() {
      _selectedClipId = null;
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

    final animationLanes = laneSpecs
        .map(
          (lane) => TimelineAnimationLaneData(
            id: lane.id,
            label: lane.label,
            targetClipId: leftScopedClipId,
            normalizedKeyframeStops: lane.keyframeStops,
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
        animationLanes: animationLanes,
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
      min: 1.0,
      max: 1.25,
      fallback: 1.0,
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
      min: 1.0,
      max: 1.45,
      fallback: 1.0,
      tint: Color(0xFF8DFFAE),
      keyframeStops: <double>[0.0, 1.0],
      valueFormatter: _formatTransitionScale,
    ),
    'entryDelay': _TransitionFocusLaneSpec(
      id: 'entryDelay',
      groupLabel: 'Timing',
      label: 'Entry Delay',
      editorDescription:
          'Offsets when the incoming clip starts taking over inside the seam.',
      min: 0.0,
      max: 0.48,
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
      max: 0.65,
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
      max: 1.0,
      fallback: 0.0,
      tint: Color(0xFFB5C0D9),
      keyframeStops: <double>[0.0, 0.5, 1.0],
      valueFormatter: _formatTransitionPercent,
    ),
  };

  List<_TransitionFocusLaneSpec> _transitionFocusLaneSpecs(
    TimelineTrackTransitionData transition,
  ) {
    final laneIds = switch (transition.preset) {
      TimelineTransitionPreset.manual => transition.manualEffectIds,
      TimelineTransitionPreset.fadeBlack => const <String>['blackPeak'],
      TimelineTransitionPreset.zoomInCamera => const <String>[
          'outgoingBoostScale',
          'incomingStartScale',
          'entryDelay',
          'bridgeDarkness',
        ],
    };
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
    if (context.transition.preset == TimelineTransitionPreset.manual) {
      final shouldSeedBalancedScope =
          context.transition.manualEffectIds.isEmpty &&
              (context.transition.leadingDurationTime == null ||
                  context.transition.trailingDurationTime == null ||
                  (context.transition.resolvedLeadingDurationTime <
                          _manualTransitionMinimumScopeSideTime &&
                      context.transition.resolvedTrailingDurationTime <
                          _manualTransitionMinimumScopeSideTime));
      final sharedManualScopeDuration =
          _manualTransitionMinimumScopeSideTime.clamp(
        _minEditableClipDurationTime,
        context.leftClip.durationTime <= context.rightClip.durationTime
            ? context.leftClip.durationTime
            : context.rightClip.durationTime,
      );
      final desiredLeading = shouldSeedBalancedScope
          ? sharedManualScopeDuration
          : context.transition.resolvedLeadingDurationTime;
      final desiredTrailing = shouldSeedBalancedScope
          ? sharedManualScopeDuration
          : context.transition.resolvedTrailingDurationTime;
      if (desiredLeading != context.transition.resolvedLeadingDurationTime ||
          desiredTrailing != context.transition.resolvedTrailingDurationTime) {
        final updatedTransition = context.transition.copyWith(
          durationTime: desiredLeading + desiredTrailing,
          leadingDurationTime: desiredLeading,
          trailingDurationTime: desiredTrailing,
        );
        _upsertVideoTrackTransition(updatedTransition);
        context = _transitionFocusContextById(transitionId);
        if (context == null) {
          return;
        }
      }
    }
    final resolvedLaneId = _resolvedTransitionFocusLaneId(
      context,
      preferredLaneId: preferredLaneId,
    );
    setState(() {
      _transitionFocusSession = _TransitionFocusSession(
        transitionId: transitionId,
        selectedLaneId: resolvedLaneId,
      );
      _selectedClipId = null;
      _selectedTransitionId = transitionId;
      if (_activeTab == EditorMediaTab.speed) {
        _activeTab = EditorMediaTab.video;
      }
    });
    _seekTransitionFocusProgress(context, 0.0);
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
    });
  }

  Future<void> _openManualTransitionEffectBrowser(String transitionId) async {
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
          items: _manualTransitionEffectItems,
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
        : _transitionFocusProgressForTime(existingContext, _currentTime);
    _upsertVideoTrackTransition(update(current));
    if (preservedProgress != null) {
      final nextContext = _transitionFocusContextById(transitionId);
      if (nextContext != null) {
        _seekTransitionFocusProgress(nextContext, preservedProgress);
      }
    }
  }

  void _handleTransitionFrameToolsTap() {
    _showStageMessage(
        'Keyframe tools UI is the next step in this manual mode.');
  }

  static String _formatTransitionPercent(double value) =>
      '${(value * 100).round()}%';

  static String _formatTransitionScale(double value) =>
      '${(value * 100).round()}%';

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
    final transition = TimelineTrackTransitionData(
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
    _upsertVideoTrackTransition(transition);
    if (browserResult.action == TransitionBrowserAction.openManual) {
      _enterTransitionFocusMode(transition.id);
      return;
    }
    await _openTransitionInspector(transition.id);
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
      if (transition.preset == TimelineTransitionPreset.manual &&
          transition.manualEffectIds.isEmpty) {
        continue;
      }
      final leftClip = clipById[transition.leftClipId];
      final rightClip = clipById[transition.rightClipId];
      if (leftClip == null || rightClip == null) {
        continue;
      }
      final seamTime = leftClip.startTime + leftClip.clip.durationTime;
      final start = (seamTime - transition.resolvedLeadingDurationTime).clamp(
        TimelineTime.zero,
        _timelineDurationTime,
      );
      final end = (seamTime + transition.resolvedTrailingDurationTime).clamp(
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
      return _ActiveTimelineTransitionPreview(
        transition: transition,
        leftClip: leftClip,
        rightClip: rightClip,
        progress: progress,
      );
    }
    return null;
  }

  void _warmTransitionPreviewAssets(_ActiveTimelineTransitionPreview state) {
    final assetId = state.rightClip.clip.assetId;
    if (assetId == null || assetId.isEmpty) {
      return;
    }
    final asset = _assetForId(assetId);
    if (asset == null) {
      return;
    }
    unawaited(
      _primePreviewThumbnailForAsset(
        asset,
        publishIfNotCurrent: false,
      ),
    );
  }

  Widget? _buildPreviewOverlay({
    required bool effectiveIsPlaying,
  }) {
    final previewTimeListenable = effectiveIsPlaying && _useNativePreview
        ? _playbackSampleTimeNotifier
        : _timelineDisplayTimeNotifier;
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
            if (motionTextRenderSnapshot == null && activeTransition == null) {
              return const SizedBox.shrink();
            }
            final selectedCanvasElementId = motionTextRenderSnapshot == null
                ? null
                : _selectedCanvasTextElementIdForSnapshot(
                    motionTextRenderSnapshot,
                  );
            final incomingTransitionAssetId =
                activeTransition?.rightClip.clip.assetId;
            final incomingTransitionBytes = incomingTransitionAssetId == null
                ? null
                : _previewThumbnailCache[incomingTransitionAssetId];
            return Stack(
              fit: StackFit.expand,
              children: [
                if (activeTransition != null)
                  TimelineTransitionPreviewOverlay(
                    transition: activeTransition.transition,
                    progress: activeTransition.progress,
                    incomingThumbnailBytes: incomingTransitionBytes,
                  ),
                if (motionTextRenderSnapshot != null)
                  MotionTextPreviewOverlay(
                    snapshot: motionTextRenderSnapshot,
                  ),
                if (motionTextRenderSnapshot != null)
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
                      child: Builder(
                        builder: (context) {
                          final previewFallback = _CleanPreviewCanvas(
                            asset: previewAsset,
                            previewThumbnailAssetId:
                                _previewThumbnailResolvedAssetId,
                            previewThumbnailListenable:
                                _previewThumbnailNotifier,
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
                            child: _useNativePreview
                                ? NativePreviewSurface(
                                    controller: _transportController,
                                    previewIdentity: previewAsset?.sourceUri ??
                                        previewAsset?.id,
                                    fallback: previewFallback,
                                  )
                                : previewFallback,
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
                                      playbackSampleTimeListenable:
                                          _transitionFocusPlaybackSampleTimeNotifier,
                                      timelineDurationTime:
                                          transitionFocusContext.endTime -
                                              transitionFocusContext.startTime,
                                      timeDisplayOffset:
                                          transitionFocusContext.startTime,
                                      timeReadoutTotalTime:
                                          _timelineDurationTime,
                                      isPlaying: effectiveIsPlaying,
                                      timelineFps: _timelineFps,
                                      selectedClipId: _selectedClipId,
                                      selectedAnimationLaneId:
                                          resolvedTransitionFocusLaneId,
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
                                          _openManualTransitionEffectBrowser(
                                        transitionFocusContext.transition.id,
                                      ),
                                      onAnimationLaneTap:
                                          _selectTransitionFocusLane,
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
                                                    configRevision:
                                                        _timelineScrubConfigRevision,
                                                    onConfigApplied:
                                                        _handleTimelineScrubConfigApplied,
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
                                                        !_isApplyingStructuralEdit,
                                                  ),
                                      assetPathResolver: _resolveAssetPath,
                                      animateTrackKinds: const <TimelineTrackKind>{
                                        TimelineTrackKind.video,
                                      },
                                    )
                                  : TimelinePanel(
                                      embedded: true,
                                      tracks: displayTracks,
                                      currentTime: _currentTime,
                                      displayTimeListenable:
                                          _timelineDisplayTimeNotifier,
                                      onDisplayTimeChanged:
                                          _setTimelineDisplayTime,
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
                                      onBackgroundTap: _clearSelection,
                                      onTrimCommit: _handleTimelineTrimCommit,
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
                                                    configRevision:
                                                        _timelineScrubConfigRevision,
                                                    onConfigApplied:
                                                        _handleTimelineScrubConfigApplied,
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
                                                        !_isApplyingStructuralEdit,
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
                            child: MediaDock(
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
  });

  final TimelineTrackTransitionData transition;
  final _PositionedTimelineTrackClip leftClip;
  final _PositionedTimelineTrackClip rightClip;
  final double progress;
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
    required this.startTime,
    required this.endTime,
  });

  final TimelineTrackTransitionData transition;
  final TimelineClipData leftClip;
  final TimelineClipData rightClip;
  final TimelineTime seamTime;
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
