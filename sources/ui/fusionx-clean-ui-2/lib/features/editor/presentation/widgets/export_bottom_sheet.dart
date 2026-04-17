import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/engine/stage6_export_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/export_composition_models.dart';
import '../../domain/models/export_output_profile.dart';

class ExportBottomSheet extends StatefulWidget {
  const ExportBottomSheet({
    super.key,
    required this.controller,
    required this.buildComposition,
    required this.onStartExport,
    required this.onCancelExport,
    required this.onOpenOutput,
    required this.onShareOutput,
    required this.onSaveToGallery,
    required this.onStageMessage,
  });

  final Stage6ExportController controller;
  final ExportComposition Function() buildComposition;
  final Future<void> Function(ExportOutputProfile profile) onStartExport;
  final Future<void> Function() onCancelExport;
  final Future<bool> Function(String outputPath, String? mimeType) onOpenOutput;
  final Future<bool> Function(String outputPath, String? mimeType)
      onShareOutput;
  final Future<String?> Function(String outputPath, String? mimeType)
      onSaveToGallery;
  final ValueChanged<String> onStageMessage;

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  static const List<ExportFrameRatePreset> _visibleFrameRatePresets = [
    ExportFrameRatePreset.fps30,
    ExportFrameRatePreset.fps60,
    ExportFrameRatePreset.fps90,
    ExportFrameRatePreset.fps120,
  ];

  ExportResolutionPreset _selectedPreset = ExportResolutionPreset.fullHd1080p;
  late ExportFrameRatePreset _selectedFrameRate;
  final ExportVideoCodecPreset _selectedVideoCodec =
      ExportVideoCodecPreset.automatic;
  final ExportBitrateMode _selectedBitrateMode = ExportBitrateMode.auto;
  final ExportAudioBitratePreset _selectedAudioBitrate =
      ExportAudioBitratePreset.kbps256;
  late final TextEditingController _manualVideoBitrateController;

  @override
  void initState() {
    super.initState();
    final composition = widget.buildComposition();
    _selectedFrameRate =
        _closestVisibleFrameRate(composition.format.framesPerSecond);
    _manualVideoBitrateController = TextEditingController(text: '12');
  }

  @override
  void dispose() {
    _manualVideoBitrateController.dispose();
    super.dispose();
  }

  Future<void> _copyOutputPath(String outputPath) async {
    await Clipboard.setData(ClipboardData(text: outputPath));
    widget.onStageMessage('Export path copied.');
  }

  Future<void> _openOutput(String outputPath, String? mimeType) async {
    final didOpen = await widget.onOpenOutput(outputPath, mimeType);
    if (!didOpen) {
      widget.onStageMessage('Unable to open export output right now.');
    }
  }

  Future<void> _shareOutput(String outputPath, String? mimeType) async {
    final didShare = await widget.onShareOutput(outputPath, mimeType);
    if (!didShare) {
      widget.onStageMessage('Unable to share export output right now.');
    }
  }

  Future<void> _saveToGallery(String outputPath, String? mimeType) async {
    final savedUri = await widget.onSaveToGallery(outputPath, mimeType);
    if (savedUri == null || savedUri.isEmpty) {
      widget.onStageMessage('Unable to save export output to gallery.');
      return;
    }
    widget.onStageMessage('Export saved to gallery.');
  }

  ExportFrameRatePreset _closestVisibleFrameRate(double framesPerSecond) {
    return _visibleFrameRatePresets.reduce((currentBest, candidate) {
      final currentDelta =
          (currentBest.framesPerSecond - framesPerSecond).abs();
      final candidateDelta =
          (candidate.framesPerSecond - framesPerSecond).abs();
      return candidateDelta < currentDelta ? candidate : currentBest;
    });
  }

  String _titleForState(ExportJobState state) {
    if (state.isActive) {
      return 'Exporting';
    }
    return switch (state.status) {
      ExportJobStatus.completed => 'Export Ready',
      ExportJobStatus.failed => 'Export Failed',
      ExportJobStatus.cancelled => 'Export Cancelled',
      _ => 'Export',
    };
  }

  String _subtitleForState(
      ExportComposition composition, ExportJobState state) {
    if (state.isActive) {
      final phase = state.phase;
      if (phase != null && phase.isNotEmpty) {
        return phase;
      }
      return 'Preparing output...';
    }
    final targetSize =
        _resolvedOutputSizeForPreset(composition, _selectedPreset);
    return '${composition.totalClipCount} clip(s) • '
        '${targetSize.$1}x${targetSize.$2}';
  }

  int? _parseManualVideoBitrate() {
    final rawValue = _manualVideoBitrateController.text.trim();
    if (rawValue.isEmpty) {
      return null;
    }
    final parsedMbps = double.tryParse(rawValue);
    if (parsedMbps == null || parsedMbps <= 0) {
      return null;
    }
    return (parsedMbps * 1000 * 1000).round();
  }

  ExportOutputProfile? _buildSelectedProfile() {
    final manualVideoBitrate = _selectedBitrateMode == ExportBitrateMode.manual
        ? _parseManualVideoBitrate()
        : null;
    if (_selectedBitrateMode == ExportBitrateMode.manual &&
        manualVideoBitrate == null) {
      widget.onStageMessage('Enter a valid manual bitrate in Mbps.');
      return null;
    }
    return ExportOutputProfile(
      resolutionPreset: _selectedPreset,
      frameRate: _selectedFrameRate,
      videoCodec: _selectedVideoCodec,
      bitrateMode: _selectedBitrateMode,
      audioBitrate: _selectedAudioBitrate,
      manualVideoBitrate: manualVideoBitrate,
    );
  }

  (int, int) _resolvedOutputSizeForPreset(
    ExportComposition composition,
    ExportResolutionPreset preset,
  ) {
    int roundEven(int value) {
      final clamped = value < 2 ? 2 : value;
      return clamped.isEven ? clamped : clamped - 1;
    }

    (int, int) scaledCanvasToFit(int maxWidth, int maxHeight) {
      final canvasWidth = composition.format.canvasWidth;
      final canvasHeight = composition.format.canvasHeight;
      final scale = [
        maxWidth / canvasWidth,
        maxHeight / canvasHeight,
      ].reduce((value, element) => value < element ? value : element);
      return (
        roundEven((canvasWidth * scale).round()),
        roundEven((canvasHeight * scale).round()),
      );
    }

    (int, int) resolveSourceMatchSize() {
      final visualAssets = composition.assets.where((asset) {
        final hasDimensions = (asset.width ?? 0) > 0 && (asset.height ?? 0) > 0;
        return hasDimensions &&
            (asset.kind == ExportAssetKind.video ||
                asset.kind == ExportAssetKind.image);
      }).toList(growable: false);
      if (visualAssets.isEmpty) {
        return (
          roundEven(composition.format.canvasWidth),
          roundEven(composition.format.canvasHeight),
        );
      }
      final largestAsset = visualAssets.reduce((currentBest, candidate) {
        final currentArea =
            (currentBest.width ?? 0) * (currentBest.height ?? 0);
        final candidateArea = (candidate.width ?? 0) * (candidate.height ?? 0);
        return candidateArea > currentArea ? candidate : currentBest;
      });
      return scaledCanvasToFit(
        largestAsset.width ?? composition.format.canvasWidth,
        largestAsset.height ?? composition.format.canvasHeight,
      );
    }

    final canvasWidth = composition.format.canvasWidth;
    final canvasHeight = composition.format.canvasHeight;
    if (preset == ExportResolutionPreset.originalCanvas) {
      return (roundEven(canvasWidth), roundEven(canvasHeight));
    }
    if (preset == ExportResolutionPreset.sourceMatch) {
      return resolveSourceMatchSize();
    }
    final isLandscape = canvasWidth >= canvasHeight;
    final (maxWidth, maxHeight) = switch (preset) {
      ExportResolutionPreset.draft720p =>
        isLandscape ? (1280, 720) : (720, 1280),
      ExportResolutionPreset.fullHd1080p =>
        isLandscape ? (1920, 1080) : (1080, 1920),
      ExportResolutionPreset.quadHd1440p =>
        isLandscape ? (2560, 1440) : (1440, 2560),
      ExportResolutionPreset.ultraHd2160p =>
        isLandscape ? (3840, 2160) : (2160, 3840),
      ExportResolutionPreset.originalCanvas => (canvasWidth, canvasHeight),
      ExportResolutionPreset.sourceMatch => (canvasWidth, canvasHeight),
    };
    return scaledCanvasToFit(maxWidth, maxHeight);
  }

  String _labelForPreset(ExportResolutionPreset preset) {
    return switch (preset) {
      ExportResolutionPreset.draft720p => '720p',
      ExportResolutionPreset.fullHd1080p => '1080p',
      ExportResolutionPreset.quadHd1440p => '2K',
      ExportResolutionPreset.ultraHd2160p => '4K',
      ExportResolutionPreset.originalCanvas => 'Original',
      ExportResolutionPreset.sourceMatch => 'Source',
    };
  }

  String _formatSelectedVideoCodec(String? value) {
    return switch (value) {
      'automatic' => 'Auto',
      'h264Avc' => 'H.264 / AVC',
      'h265Hevc' => 'H.265 / HEVC',
      _ => '-',
    };
  }

  String _formatPercent(double progress) =>
      '${(progress.clamp(0.0, 1.0) * 100).round()}%';

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatBitrate(int bitsPerSecond) {
    if (bitsPerSecond >= 1000 * 1000) {
      return '${(bitsPerSecond / (1000 * 1000)).toStringAsFixed(1)} Mbps';
    }
    if (bitsPerSecond >= 1000) {
      return '${(bitsPerSecond / 1000).toStringAsFixed(0)} kbps';
    }
    return '$bitsPerSecond bps';
  }

  String _formatDurationMs(int durationMs) {
    if (durationMs < 60 * 1000) {
      return '${(durationMs / 1000).toStringAsFixed(2)}s';
    }
    final totalSeconds = (durationMs / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSignedDeltaMs(int deltaMs) {
    final prefix = deltaMs > 0 ? '+' : '';
    return '$prefix${deltaMs}ms';
  }

  String _formatDecimal(double value) => value.toStringAsFixed(3);

  String _formatParityPathKind(String value) {
    return switch (value) {
      'sampled_track' => 'sampled_track',
      'raster_program' => 'raster_program',
      'program' => 'program',
      _ => value,
    };
  }

  String _formatBlurExecutionMode(String value) {
    return switch (value) {
      'software_local' => 'software_local',
      'media3_gl_sequence' => 'media3_gl_sequence',
      _ => value,
    };
  }

  String _formatBlurDecisionCode(String value) {
    return switch (value) {
      'enabled_uniform_sequence_blur' => 'enabled_uniform_sequence_blur',
      'overlay_sequence_unavailable' => 'overlay_sequence_unavailable',
      'missing_output_size' => 'missing_output_size',
      'missing_raster_program' => 'missing_raster_program',
      'unsupported_blur_contract' => 'unsupported_blur_contract',
      'empty_raster_program' => 'empty_raster_program',
      'unsupported_blend_mode' => 'unsupported_blend_mode',
      'time_varying_blur_amount' => 'time_varying_blur_amount',
      'blur_below_threshold' => 'blur_below_threshold',
      'blur_not_requested' => 'blur_not_requested',
      'non_uniform_blur_amount' => 'non_uniform_blur_amount',
      'sigma_below_threshold' => 'sigma_below_threshold',
      'software_local_default' => 'software_local_default',
      _ => value,
    };
  }

  String _formatCanonicalEffectsBackendId(String value) {
    return switch (value) {
      'media3CanvasOverlayRenderer' => 'media3CanvasOverlayRenderer',
      'media3GlEffectsRenderer' => 'media3GlEffectsRenderer',
      'flutterPreviewRenderer' => 'flutterPreviewRenderer',
      'bmfRenderGraph' => 'bmfRenderGraph',
      _ => value,
    };
  }

  String _formatCanonicalKinds(List<String> values) {
    if (values.isEmpty) {
      return '-';
    }
    return values.join(', ');
  }

  String _formatRemainingMs(int remainingMs) {
    final totalSeconds = (remainingMs / 1000).ceil().clamp(0, 360000);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes <= 0) {
      return '$seconds sec left';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s left';
  }

  String _formatPresetName(String? preset) {
    return switch (preset) {
      'draft720p' => '720p',
      'fullHd1080p' => '1080p',
      'quadHd1440p' => '1440p',
      'ultraHd2160p' => '2160p',
      'originalCanvas' => 'Original Canvas',
      'sourceMatch' => 'Source Match',
      _ => '-',
    };
  }

  String _formatBitrateModeName(String? value) {
    return switch (value) {
      'auto' => 'Auto',
      'qualityPriority' => 'Quality',
      'sizePriority' => 'Size',
      'manual' => 'Manual',
      _ => '-',
    };
  }

  String _formatVisualAssemblyRoutes(
    ExportVisualAssemblyDiagnostics diagnostics,
  ) {
    if (diagnostics.routes.isEmpty) {
      return 'No per-route data was emitted for this export job yet.';
    }
    final buffer = StringBuffer();
    final routes = diagnostics.routes;
    final visibleRoutes = routes.take(6);
    var index = 0;
    for (final route in visibleRoutes) {
      if (index > 0) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write('Clip: ${route.clipId}\n');
      buffer.write('Route: ${route.route}\n');
      buffer.write(
        'Window: ${route.graphWindowId ?? '-'} (${route.timelineStartMs}-${route.timelineEndExclusiveMs}ms)\n',
      );
      buffer.write('Segment: ${route.graphSegmentId ?? '-'}\n');
      buffer.write('Layer: ${route.graphLayerId ?? '-'}\n');
      buffer.write('Z: ${route.graphZOrder?.toString() ?? '-'}\n');
      buffer.write(
        'Assembly Order: ${route.graphAssemblyOrder?.toString() ?? '-'}\n',
      );
      buffer.write(
        'Covered Windows: ${route.coveredWindowIds.isEmpty ? '-' : route.coveredWindowIds.join(', ')}\n',
      );
      buffer.write(
        'Active Layers: ${route.activeLayerIds.isEmpty ? '-' : route.activeLayerIds.join(', ')}\n',
      );
      buffer.write(
        'Active Segments: ${route.activeSegmentIds.isEmpty ? '-' : route.activeSegmentIds.join(', ')}',
      );
      index += 1;
    }
    if (routes.length > 6) {
      buffer.writeln();
      buffer.writeln();
      buffer.write('+ ${routes.length - 6} more routes');
    }
    return buffer.toString();
  }

  String _formatVisualCompositorRoutes(
    ExportVisualAssemblyDiagnostics diagnostics,
  ) {
    if (diagnostics.compositorRoutes.isEmpty) {
      return 'No compositor-window execution data was emitted for this export job yet.';
    }
    final buffer = StringBuffer();
    final visibleRoutes = diagnostics.compositorRoutes.take(4);
    var index = 0;
    for (final route in visibleRoutes) {
      if (index > 0) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write('Window: ${route.windowId}\n');
      buffer.write('Owner: ${route.executionOwner}\n');
      buffer.write('Result: ${route.result}\n');
      buffer.write('Executable: ${route.isExecutable ? 'yes' : 'no'}\n');
      buffer.write('Base Clip: ${route.baseClipId ?? '-'}\n');
      buffer.write(
        'Overlay Clips: ${route.overlayClipIds.isEmpty ? '-' : route.overlayClipIds.join(', ')}\n',
      );
      buffer.write(
        'Ordered Layers: ${route.orderedLayerIds.isEmpty ? '-' : route.orderedLayerIds.join(', ')}\n',
      );
      buffer.write(
        'Ordered Segments: ${route.orderedSegmentIds.isEmpty ? '-' : route.orderedSegmentIds.join(', ')}\n',
      );
      buffer.write(
        'Authored Nodes: ${route.authoredNodeIds.isEmpty ? '-' : route.authoredNodeIds.join(', ')}\n',
      );
      buffer.write('Detail: ${route.detail}');
      index += 1;
    }
    if (diagnostics.compositorRoutes.length > 4) {
      buffer.writeln();
      buffer.writeln();
      buffer.write(
          '+ ${diagnostics.compositorRoutes.length - 4} more compositor windows');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.62;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final composition = widget.buildComposition();
        final state = widget.controller.state;
        final blockers = composition.firstBaselineBlockingReasons;
        final parityLimitations = composition.currentParityLimitations;
        final issues = composition.issues;
        final validation = state.validation;
        final motionTextParity = state.motionTextParity;
        final canonicalEffectsDiagnostics = state.canonicalEffectsDiagnostics;
        final authoredVisualSurfaceDiagnostics =
            state.authoredVisualSurfaceDiagnostics;
        final visualAssemblyDiagnostics = state.visualAssemblyDiagnostics;
        final cleanupPerformed = state.cleanupPerformed;
        final hasSessionSummary = state.preset != null ||
            state.clipCount != null ||
            state.requestedDurationMs != null ||
            (state.phase != null && state.phase!.isNotEmpty);
        final hasRemainingEstimate = state.estimatedRemainingMs != null &&
            state.estimatedRemainingMs! > 0;

        return Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: sheetHeight + bottomInset + safeBottom,
              padding: EdgeInsets.only(bottom: bottomInset + safeBottom),
              decoration: const BoxDecoration(
                color: FxPalette.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: FxPalette.textFaint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titleForState(state),
                                style: const TextStyle(
                                  color: FxPalette.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _subtitleForState(composition, state),
                                style: const TextStyle(
                                  color: FxPalette.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: FxPalette.accentSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _formatPercent(state.progress),
                              style: const TextStyle(
                                color: FxPalette.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Resolution',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: FxPalette.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ExportResolutionPreset.values.map((preset) {
                        final isSelected = preset == _selectedPreset;
                        return InkWell(
                          onTap: state.isActive
                              ? null
                              : () => setState(() {
                                    _selectedPreset = preset;
                                  }),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FxPalette.accent
                                  : FxPalette.surfaceRaised,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _labelForPreset(preset),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? FxPalette.background
                                    : FxPalette.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'FPS',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: FxPalette.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _visibleFrameRatePresets.map((preset) {
                        final isSelected = preset == _selectedFrameRate;
                        return InkWell(
                          onTap: state.isActive
                              ? null
                              : () => setState(() {
                                    _selectedFrameRate = preset;
                                  }),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FxPalette.accent
                                  : FxPalette.surfaceRaised,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              preset.framesPerSecond.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? FxPalette.background
                                    : FxPalette.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.isActive) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value:
                                    state.progress <= 0 || state.progress >= 1
                                        ? null
                                        : state.progress,
                                backgroundColor: FxPalette.surfaceRaised,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  FxPalette.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ExportInfoCard(
                              toneColor: FxPalette.accent,
                              title: 'Progress',
                              body:
                                  'Completion: ${_formatPercent(state.progress)}\n'
                                  '${hasRemainingEstimate ? _formatRemainingMs(state.estimatedRemainingMs!) : 'Estimating remaining time...'}',
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (hasSessionSummary) ...[
                            _ExportInfoCard(
                              toneColor: FxPalette.accent,
                              title: 'Session',
                              body:
                                  'Preset: ${_formatPresetName(state.preset)}\n'
                                  'Target FPS: ${state.requestedFrameRate?.toString() ?? _selectedFrameRate.framesPerSecond} fps\n'
                                  'Video Codec: ${_formatSelectedVideoCodec(state.selectedVideoCodec)}\n'
                                  'Bitrate Mode: ${_formatBitrateModeName(state.bitrateMode)}\n'
                                  'Video Bitrate: ${state.requestedVideoBitrate == null ? '-' : _formatBitrate(state.requestedVideoBitrate!)}\n'
                                  'Audio Bitrate: ${state.requestedAudioBitrate == null ? '-' : _formatBitrate(state.requestedAudioBitrate!)}\n'
                                  'Encoder: ${state.selectedEncoderName ?? '-'}\n'
                                  'Clips: ${state.clipCount?.toString() ?? '-'}\n'
                                  'Execution Target: ${state.requestedDurationMs == null ? '-' : _formatDurationMs(state.requestedDurationMs!)}\n'
                                  '${state.timelineDurationMs == null || state.timelineDurationMs == state.requestedDurationMs ? '' : 'Timeline Target: ${_formatDurationMs(state.timelineDurationMs!)}\n'}'
                                  'Phase: ${state.phase ?? '-'}',
                            ),
                            const SizedBox(height: 10),
                          ],
                          _ExportInfoCard(
                            toneColor: blockers.isEmpty
                                ? FxPalette.accent
                                : FxPalette.danger,
                            title: 'Preflight',
                            body:
                                'Profile: ${composition.baselineProfileLabel}\n'
                                'Tracks: ${composition.nonEmptyVisualTrackCount} video'
                                '${composition.nonEmptyAudioTrackCount > 0 ? ' + audio' : ''}\n'
                                'Status: ${composition.isFirstBaselineEligible ? 'Ready' : 'Blocked'}'
                                '${composition.firstBlockedVisualAssemblyWindow == null ? '' : '\nFirst Blocked Window: ${composition.firstBlockedVisualAssemblyWindow!.id} (${composition.firstBlockedVisualAssemblyWindow!.timelineRange.start.inMilliseconds}-${composition.firstBlockedVisualAssemblyWindow!.timelineRange.endExclusive.inMilliseconds}ms)\nBlocked Detail: ${composition.firstBlockedVisualAssemblyWindow!.detail}'}',
                          ),
                          const SizedBox(height: 10),
                          if (composition.hasMotionContract) ...[
                            _ExportInfoCard(
                              toneColor: FxPalette.accent,
                              title: 'Motion/Text Contract',
                              body: 'Scenes: ${composition.motionSceneCount}\n'
                                  'Elements: ${composition.motionElementCount}\n'
                                  'Channels: ${composition.motionChannelCount}\n'
                                  'Cameras: ${composition.motionCameraCount}\n'
                                  'Render Samples: ${composition.motionTextRenderSampleCount}\n'
                                  'Text Animations: ${composition.motionTextAnimationCount}\n'
                                  'Effects: ${composition.motionEffectCount}\n'
                                  'Transitions: ${composition.motionTransitionCount}\n'
                                  'Status: text-only renderer path is wired, wider parity still pending',
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (canonicalEffectsDiagnostics != null) ...[
                            _ExportInfoCard(
                              toneColor: canonicalEffectsDiagnostics
                                              .blockedNodeCount ==
                                          0 &&
                                      canonicalEffectsDiagnostics
                                              .blockedOperationCount ==
                                          0
                                  ? FxPalette.accent
                                  : const Color(0xFFE0A13B),
                              title: 'Canonical Effects',
                              body:
                                  'Current Backend: ${_formatCanonicalEffectsBackendId(canonicalEffectsDiagnostics.currentBackendId)}\n'
                                  'Nodes: ${canonicalEffectsDiagnostics.nodeCount} (${canonicalEffectsDiagnostics.relevantNodeCount} relevant)\n'
                                  'Operations: ${canonicalEffectsDiagnostics.operationCount} (${canonicalEffectsDiagnostics.relevantOperationCount} relevant)\n'
                                  'Supported Nodes: ${canonicalEffectsDiagnostics.supportedNodeCount}\n'
                                  'Baseline-only Nodes: ${canonicalEffectsDiagnostics.baselineOnlyNodeCount}\n'
                                  'Approx Nodes: ${canonicalEffectsDiagnostics.approximationNodeCount}\n'
                                  'Blocked Nodes: ${canonicalEffectsDiagnostics.blockedNodeCount}\n'
                                  'Supported Ops: ${canonicalEffectsDiagnostics.supportedOperationCount}\n'
                                  'Baseline-only Ops: ${canonicalEffectsDiagnostics.baselineOnlyOperationCount}\n'
                                  'Approx Ops: ${canonicalEffectsDiagnostics.approximationOperationCount}\n'
                                  'Blocked Ops: ${canonicalEffectsDiagnostics.blockedOperationCount}\n'
                                  'Node Kinds: ${_formatCanonicalKinds(canonicalEffectsDiagnostics.nodeKinds)}\n'
                                  'Operation Kinds: ${_formatCanonicalKinds(canonicalEffectsDiagnostics.operationKinds)}\n'
                                  'First Blocked Node: ${canonicalEffectsDiagnostics.firstBlockedNodeId ?? '-'}\n'
                                  'First Blocked Operation: ${canonicalEffectsDiagnostics.firstBlockedOperationId ?? '-'}\n'
                                  'Detail: ${canonicalEffectsDiagnostics.firstBlockedDetail ?? '-'}',
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (motionTextParity != null) ...[
                            _ExportInfoCard(
                              toneColor: motionTextParity.status == 'matched'
                                  ? FxPalette.accent
                                  : const Color(0xFFE0A13B),
                              title: 'Motion/Text Parity',
                              body: 'Status: ${motionTextParity.status}\n'
                                  'Reference Path: ${_formatParityPathKind(motionTextParity.referencePathKind)}\n'
                                  'Runtime Path: ${_formatParityPathKind(motionTextParity.runtimePathKind)}\n'
                                  'Blur Execution: ${_formatBlurExecutionMode(motionTextParity.blurExecutionMode)}\n'
                                  'Blur Decision: ${_formatBlurDecisionCode(motionTextParity.glBlurDecisionCode)}\n'
                                  'Blur Detail: ${motionTextParity.glBlurDecisionDetail ?? '-'}\n'
                                  'GL Blur Sigma: ${motionTextParity.glBlurSigmaPx == null ? '-' : _formatDecimal(motionTextParity.glBlurSigmaPx!)}\n'
                                  'Samples: ${motionTextParity.sampleCount}\n'
                                  'Compared Nodes: ${motionTextParity.comparedNodeCount}\n'
                                  'Drift Nodes: ${motionTextParity.driftNodeCount}\n'
                                  'Missing Runtime Nodes: ${motionTextParity.missingRuntimeNodeCount}\n'
                                  'Unexpected Runtime Nodes: ${motionTextParity.unexpectedRuntimeNodeCount}\n'
                                  'Text Mismatches: ${motionTextParity.textMismatchCount}\n'
                                  'Reveal Mismatches: ${motionTextParity.revealUnitMismatchCount}\n'
                                  'Anchor Mismatches: ${motionTextParity.anchorMismatchCount}\n'
                                  'Alignment Mismatches: ${motionTextParity.alignmentMismatchCount}\n'
                                  'Blend Mismatches: ${motionTextParity.blendModeMismatchCount}\n'
                                  'Max Position Delta: ${_formatDecimal(motionTextParity.maxPositionDeltaPx)}\n'
                                  'Max Scale Delta: ${_formatDecimal(motionTextParity.maxScaleDelta)}\n'
                                  'Max Rotation Delta: ${_formatDecimal(motionTextParity.maxRotationDelta)}\n'
                                  'Max Opacity Delta: ${_formatDecimal(motionTextParity.maxOpacityDelta)}\n'
                                  'Max Blur Delta: ${_formatDecimal(motionTextParity.maxBlurDelta)}\n'
                                  'Max Font Size Delta: ${_formatDecimal(motionTextParity.maxFontSizeDelta)}\n'
                                  'Max Letter Spacing Delta: ${_formatDecimal(motionTextParity.maxLetterSpacingDelta)}\n'
                                  'Max Reveal Delta: ${_formatDecimal(motionTextParity.maxRevealProgressDelta)}\n'
                                  'Worst Node: ${motionTextParity.worstNodeId ?? '-'}\n'
                                  'Worst Time: ${motionTextParity.worstTimeMs?.toString() ?? '-'}ms',
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (authoredVisualSurfaceDiagnostics != null) ...[
                            _ExportInfoCard(
                              toneColor: authoredVisualSurfaceDiagnostics
                                          .missingProgramNodeCount ==
                                      0
                                  ? FxPalette.accent
                                  : const Color(0xFFE0A13B),
                              title: 'Authored Surfaces',
                              body:
                                  'Status: ${authoredVisualSurfaceDiagnostics.status}\n'
                                  'Runtime Path: ${authoredVisualSurfaceDiagnostics.runtimePathKind}\n'
                                  'Nodes: ${authoredVisualSurfaceDiagnostics.nodeCount}\n'
                                  'Images: ${authoredVisualSurfaceDiagnostics.imageNodeCount}\n'
                                  'Shapes: ${authoredVisualSurfaceDiagnostics.shapeNodeCount}\n'
                                  'Masks: ${authoredVisualSurfaceDiagnostics.maskNodeCount}\n'
                                  'Video Surfaces: ${authoredVisualSurfaceDiagnostics.videoNodeCount}\n'
                                  'Animated Nodes: ${authoredVisualSurfaceDiagnostics.animatedNodeCount}\n'
                                  'Blur-capable Nodes: ${authoredVisualSurfaceDiagnostics.blurCapableNodeCount}\n'
                                  'Compositor-owned Segments: ${authoredVisualSurfaceDiagnostics.compositorOwnedSegmentCount}\n'
                                  'Program-backed Segments: ${authoredVisualSurfaceDiagnostics.programBackedSegmentCount}\n'
                                  'Missing Program Nodes: ${authoredVisualSurfaceDiagnostics.missingProgramNodeCount}\n'
                                  'Runtime Samples: ${authoredVisualSurfaceDiagnostics.sampleCount}\n'
                                  'Active Nodes: ${authoredVisualSurfaceDiagnostics.activeNodeCount}\n'
                                  'Active Animated Nodes: ${authoredVisualSurfaceDiagnostics.activeAnimatedNodeCount}\n'
                                  'Active Blur Nodes: ${authoredVisualSurfaceDiagnostics.activeBlurNodeCount}\n'
                                  'Normal Blend Nodes: ${authoredVisualSurfaceDiagnostics.normalBlendNodeCount}\n'
                                  'Surface-effect Eligible Nodes: ${authoredVisualSurfaceDiagnostics.surfaceEffectEligibleNodeCount}\n'
                                  'Max Concurrent Active Nodes: ${authoredVisualSurfaceDiagnostics.maxConcurrentActiveNodeCount}\n'
                                  'Max Resolved Blur: ${authoredVisualSurfaceDiagnostics.maxResolvedBlurAmount.toStringAsFixed(2)}\n'
                                  'First Missing Node: ${authoredVisualSurfaceDiagnostics.firstMissingProgramNodeId ?? '-'}\n'
                                  'First Resolved Node: ${authoredVisualSurfaceDiagnostics.firstResolvedNodeId ?? '-'}\n'
                                  'Source Kinds: ${_formatCanonicalKinds(authoredVisualSurfaceDiagnostics.sourceKinds)}\n'
                                  'Detail: ${authoredVisualSurfaceDiagnostics.detail ?? '-'}',
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (visualAssemblyDiagnostics != null) ...[
                            _ExportInfoCard(
                              toneColor: (visualAssemblyDiagnostics
                                              .blockedRouteCount ==
                                          0 &&
                                      visualAssemblyDiagnostics
                                              .blockedCompositorWindowCount ==
                                          0)
                                  ? FxPalette.accent
                                  : const Color(0xFFE0A13B),
                              title: 'Visual Assembly',
                              body:
                                  'Status: ${visualAssemblyDiagnostics.status}\n'
                                  'Routes: ${visualAssemblyDiagnostics.routeCount}\n'
                                  'Media-only Routes: ${visualAssemblyDiagnostics.mediaOnlyRouteCount}\n'
                                  'Overlay Routes: ${visualAssemblyDiagnostics.overlayRouteCount}\n'
                                  'Blocked Routes: ${visualAssemblyDiagnostics.blockedRouteCount}\n'
                                  'Compositor Windows: ${visualAssemblyDiagnostics.compositorWindowCount}\n'
                                  'Executable Compositor Windows: ${visualAssemblyDiagnostics.executableCompositorWindowCount}\n'
                                  'Blocked Compositor Windows: ${visualAssemblyDiagnostics.blockedCompositorWindowCount}\n'
                                  'First Blocked Window: ${visualAssemblyDiagnostics.firstBlockedWindowId ?? '-'}\n'
                                  'First Blocked Clip: ${visualAssemblyDiagnostics.firstBlockedClipId ?? '-'}\n'
                                  'Detail: ${visualAssemblyDiagnostics.firstBlockedDetail ?? '-'}',
                            ),
                            const SizedBox(height: 10),
                            _ExportInfoCard(
                              toneColor: (visualAssemblyDiagnostics
                                              .blockedRouteCount ==
                                          0 &&
                                      visualAssemblyDiagnostics
                                              .blockedCompositorWindowCount ==
                                          0)
                                  ? FxPalette.accent
                                  : const Color(0xFFE0A13B),
                              title: 'Visual Routes',
                              body: _formatVisualAssemblyRoutes(
                                visualAssemblyDiagnostics,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (visualAssemblyDiagnostics
                                .compositorRoutes.isNotEmpty) ...[
                              _ExportInfoCard(
                                toneColor: visualAssemblyDiagnostics
                                            .blockedCompositorWindowCount ==
                                        0
                                    ? FxPalette.accent
                                    : const Color(0xFFE0A13B),
                                title: 'Compositor Routes',
                                body: _formatVisualCompositorRoutes(
                                  visualAssemblyDiagnostics,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                          if (state.status == ExportJobStatus.completed &&
                              state.outputPath != null) ...[
                            _ExportInfoCard(
                              toneColor: FxPalette.accent,
                              title: 'Output File',
                              body: state.outputPath!,
                            ),
                            const SizedBox(height: 10),
                            if (validation != null) ...[
                              _ExportInfoCard(
                                toneColor: FxPalette.accent,
                                title: 'Validation',
                                body:
                                    'Size: ${_formatFileSize(validation.fileSizeBytes)}\n'
                                    'Duration: ${_formatDurationMs(validation.durationMs)}\n'
                                    'Expected Execution: ${_formatDurationMs(validation.expectedDurationMs)}\n'
                                    '${validation.timelineDurationMs > 0 && validation.timelineDurationMs != validation.expectedDurationMs ? 'Timeline Target: ${_formatDurationMs(validation.timelineDurationMs)}\n' : ''}'
                                    'Delta: ${_formatSignedDeltaMs(validation.durationDeltaMs)}\n'
                                    'Expected Resolution: ${validation.expectedWidth ?? '-'}x${validation.expectedHeight ?? '-'}\n'
                                    'Resolution: ${validation.width ?? '-'}x${validation.height ?? '-'}\n'
                                    'Expected FPS: ${validation.expectedFrameRate?.toString() ?? '-'}\n'
                                    'Actual FPS: ${validation.actualFrameRate?.toString() ?? '-'}\n'
                                    'Frame Rate Check: ${validation.isFrameRateWithinTolerance == null ? '-' : (validation.isFrameRateWithinTolerance! ? 'OK' : 'Mismatch')}\n'
                                    'Expected Video Codec: ${validation.expectedVideoTrackMime ?? '-'}\n'
                                    'Expected Audio Codec: ${validation.expectedAudioTrackMime ?? '-'}\n'
                                    'Video Tracks: ${validation.videoTrackCount}\n'
                                    'Audio Tracks: ${validation.audioTrackCount}\n'
                                    'Video: ${validation.hasVideo ? 'Yes' : 'No'}\n'
                                    'Expected Audio: ${validation.expectedHasAudio ? 'Yes' : 'No'}\n'
                                    'Audio: ${validation.hasAudio == null ? '-' : (validation.hasAudio! ? 'Yes' : 'No')}\n'
                                    'Actual Video Codec: ${validation.actualVideoTrackMime ?? '-'}\n'
                                    'Actual Audio Codec: ${validation.actualAudioTrackMime ?? '-'}\n'
                                    'Duration Check: ${validation.isDurationWithinTolerance ? 'OK' : 'Mismatch'}\n'
                                    'Mime: ${validation.mimeType ?? '-'}\n'
                                    'Track Mimes: ${validation.trackMimeTypes.isEmpty ? '-' : validation.trackMimeTypes.join(', ')}',
                              ),
                              const SizedBox(height: 10),
                            ],
                          ] else if (state.status == ExportJobStatus.failed &&
                              state.error != null) ...[
                            _ExportInfoCard(
                              toneColor: FxPalette.danger,
                              title: 'Failure',
                              body: cleanupPerformed
                                  ? '${state.error!}\nPartial output was cleaned up.'
                                  : state.error!,
                            ),
                            const SizedBox(height: 10),
                            if (validation != null)
                              _ExportInfoCard(
                                toneColor: FxPalette.danger,
                                title: 'Failure Diagnostics',
                                body:
                                    'Expected Execution: ${_formatDurationMs(validation.expectedDurationMs)}\n'
                                    '${validation.timelineDurationMs > 0 && validation.timelineDurationMs != validation.expectedDurationMs ? 'Timeline Target: ${_formatDurationMs(validation.timelineDurationMs)}\n' : ''}'
                                    'Reported Duration: ${_formatDurationMs(validation.durationMs)}\n'
                                    'Duration Delta: ${_formatSignedDeltaMs(validation.durationDeltaMs)}\n'
                                    'Expected Resolution: ${validation.expectedWidth ?? '-'}x${validation.expectedHeight ?? '-'}\n'
                                    'Reported Resolution: ${validation.width ?? '-'}x${validation.height ?? '-'}\n'
                                    'Expected FPS: ${validation.expectedFrameRate?.toString() ?? '-'}\n'
                                    'Reported FPS: ${validation.actualFrameRate?.toString() ?? '-'}\n'
                                    'Frame Rate Check: ${validation.isFrameRateWithinTolerance == null ? '-' : (validation.isFrameRateWithinTolerance! ? 'OK' : 'Mismatch')}\n'
                                    'Reported Rotation: ${validation.videoRotationDegrees?.toString() ?? '-'}\n'
                                    'Video Tracks: ${validation.videoTrackCount}\n'
                                    'Audio Tracks: ${validation.audioTrackCount}\n'
                                    'Track MIME Types: ${validation.trackMimeTypes.isEmpty ? '-' : validation.trackMimeTypes.join(', ')}',
                              ),
                            if (validation != null) const SizedBox(height: 10),
                          ] else if (state.status ==
                              ExportJobStatus.cancelled) ...[
                            _ExportInfoCard(
                              toneColor: FxPalette.danger,
                              title: 'Cancelled',
                              body: cleanupPerformed
                                  ? 'Export was cancelled and partial output was removed.'
                                  : 'Export was cancelled.',
                            ),
                            const SizedBox(height: 10),
                          ] else if (blockers.isNotEmpty) ...[
                            _ExportInfoCard(
                              toneColor: FxPalette.danger,
                              title: 'Baseline Blockers',
                              body: blockers.join('\n'),
                            ),
                            const SizedBox(height: 10),
                          ] else ...[
                            const _ExportInfoCard(
                              toneColor: FxPalette.accent,
                              title: 'Baseline Ready',
                              body: 'Ready for export.',
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (parityLimitations.isNotEmpty) ...[
                            _ExportInfoCard(
                              toneColor: const Color(0xFFE0A13B),
                              title: 'Non-blocking Parity Limitations',
                              body: parityLimitations.join('\n'),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (issues.isNotEmpty) ...[
                            const Text(
                              'Diagnostics',
                              style: TextStyle(
                                color: FxPalette.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...issues.take(4).map(
                                  (issue) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _ExportIssueRow(issue: issue),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: state.isActive
                                    ? widget.onCancelExport
                                    : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: FxPalette.textPrimary,
                                  side: BorderSide(
                                    color: state.isActive
                                        ? FxPalette.danger
                                        : FxPalette.divider,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child:
                                    Text(state.isActive ? 'Cancel' : 'Close'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (state.status == ExportJobStatus.completed &&
                                state.outputPath != null)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _shareOutput(
                                    state.outputPath!,
                                    validation?.mimeType,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FxPalette.accent,
                                    foregroundColor: FxPalette.background,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Share File'),
                                ),
                              )
                            else
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: state.isActive
                                      ? null
                                      : () {
                                          final profile =
                                              _buildSelectedProfile();
                                          if (profile == null) {
                                            return;
                                          }
                                          widget.onStartExport(profile);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FxPalette.accent,
                                    foregroundColor: FxPalette.background,
                                    disabledBackgroundColor:
                                        FxPalette.surfaceRaised,
                                    disabledForegroundColor:
                                        FxPalette.textMuted,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    blockers.isNotEmpty
                                        ? 'Review Blockers'
                                        : state.status == ExportJobStatus.failed
                                            ? 'Retry Export'
                                            : 'Export',
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (state.status == ExportJobStatus.completed &&
                            state.outputPath != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _copyOutputPath(state.outputPath!),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: FxPalette.textPrimary,
                                    side: const BorderSide(
                                      color: FxPalette.accent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Copy Path'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _saveToGallery(
                                    state.outputPath!,
                                    validation?.mimeType,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: FxPalette.textPrimary,
                                    side: const BorderSide(
                                      color: FxPalette.accent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Save To Gallery'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _openOutput(
                                    state.outputPath!,
                                    validation?.mimeType,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FxPalette.accent,
                                    foregroundColor: FxPalette.background,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Open File'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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
}

class _ExportInfoCard extends StatelessWidget {
  const _ExportInfoCard({
    required this.toneColor,
    required this.title,
    required this.body,
  });

  final Color toneColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: toneColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: FxPalette.textMuted,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportIssueRow extends StatelessWidget {
  const _ExportIssueRow({required this.issue});

  final ExportCompositionIssue issue;

  @override
  Widget build(BuildContext context) {
    final isError = issue.severity == ExportCompositionIssueSeverity.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 16,
            color: isError ? FxPalette.danger : FxPalette.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              issue.message,
              style: const TextStyle(
                color: FxPalette.textMuted,
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
