import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_interpolation_evaluator.dart';
import '../../domain/services/motion_interpolation_truth_compiler.dart';
import '../../domain/services/professional_speed_graph_preset_catalog.dart';
import '../../domain/services/speed_graph_custom_preset_persistence_service.dart';
import 'professional_speed_graph_preset_grid.dart';

enum LayerScopeGraphMode {
  value,
  speed,
}

enum LayerScopeGraphSpeedPreset {
  linear,
  easyEase,
  easeIn,
  easeOut,
  slowFastSlow,
  fastSlow,
  slowFast,
  whip,
  custom,
  fastSlowFast,
}

enum _GraphEditorTab {
  presets,
  customCurve,
  numeric,
}

typedef GraphVelocityChanged = void Function(
  MotionKeyframeVelocity velocity, {
  required String editType,
});

class LayerScopeGraphBottomSheet extends StatefulWidget {
  const LayerScopeGraphBottomSheet({
    super.key,
    required this.easyEaseEnabled,
    required this.onEasyEaseChanged,
    this.initialMode = LayerScopeGraphMode.speed,
    this.selectedPreset = LayerScopeGraphSpeedPreset.easyEase,
    this.initialVelocity,
    this.onModeChanged,
    this.onPresetSelected,
    this.onVelocityChanged,
    this.propertyPath,
    this.customPresetPersistenceService,
    required this.onDone,
  });

  final bool easyEaseEnabled;
  final ValueChanged<bool> onEasyEaseChanged;
  final LayerScopeGraphMode initialMode;
  final LayerScopeGraphSpeedPreset selectedPreset;
  final MotionKeyframeVelocity? initialVelocity;
  final ValueChanged<LayerScopeGraphMode>? onModeChanged;
  final ValueChanged<LayerScopeGraphSpeedPreset>? onPresetSelected;
  final GraphVelocityChanged? onVelocityChanged;
  final String? propertyPath;
  final SpeedGraphCustomPresetPersistenceService?
      customPresetPersistenceService;
  final VoidCallback onDone;

  @override
  State<LayerScopeGraphBottomSheet> createState() =>
      _LayerScopeGraphBottomSheetState();
}

class _LayerScopeGraphBottomSheetState
    extends State<LayerScopeGraphBottomSheet> {
  static const MotionInterpolationTruthCompiler _truthCompiler =
      MotionInterpolationTruthCompiler();
  static const ProfessionalSpeedGraphPresetCatalog _presetCatalog =
      ProfessionalSpeedGraphPresetCatalog();

  static const MotionBezierControlPoints _defaultBezier =
      MotionBezierControlPoints(
    x1: 0.333,
    y1: 0.0,
    x2: 0.667,
    y2: 1.0,
  );

  late bool _easyEaseEnabled;
  late LayerScopeGraphMode _mode;
  late LayerScopeGraphSpeedPreset _selectedPreset;
  late _GraphEditorTab _selectedTab;
  late MotionKeyframeVelocity _velocity;
  late final SpeedGraphCustomPresetPersistenceService _customPresetService;
  MotionInterpolationSpec? _curveClipboard;
  final List<MotionInterpolationSpec> _recentCurves =
      <MotionInterpolationSpec>[];
  List<SpeedGraphCustomPresetRecord> _myPresets =
      <SpeedGraphCustomPresetRecord>[];
  _GraphHandleDragTarget? _activeHandle;

  @override
  void initState() {
    super.initState();
    _easyEaseEnabled = widget.easyEaseEnabled;
    _mode = widget.initialMode;
    _selectedPreset = widget.selectedPreset;
    _selectedTab = _GraphEditorTab.presets;
    _customPresetService = widget.customPresetPersistenceService ??
        SpeedGraphCustomPresetPersistenceService.instance;
    _velocity = widget.initialVelocity ??
        _velocityForPreset(widget.selectedPreset).copyWith(
          incomingHandleLocked: true,
          outgoingHandleLocked: true,
          continuous: true,
        );
    _myPresets = _customPresetService.listPresets();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.62).clamp(420.0, 560.0);
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: sheetHeight,
            decoration: BoxDecoration(
              color: FxPalette.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              border: Border.all(color: FxPalette.divider, width: 1),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  10,
                  14,
                  (safeBottom > 0 ? safeBottom : 12) + 8,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 36),
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: FxPalette.textFaint,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onDone,
                          icon: const Icon(
                            Icons.check_rounded,
                            color: FxPalette.textPrimary,
                            size: 20,
                          ),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _GraphEditorTabSelector(
                      selectedTab: _selectedTab,
                      onTabSelected: (tab) {
                        setState(() {
                          _selectedTab = tab;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: switch (_selectedTab) {
                        _GraphEditorTab.presets => _buildPresetsTab(),
                        _GraphEditorTab.customCurve => _buildCustomCurveTab(),
                        _GraphEditorTab.numeric => _buildNumericTab(),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetsTab() {
    final presetCards = <ProfessionalSpeedGraphPreset>[
      _presetCatalog.findById('easyEase')!,
      _presetCatalog.findById('slowFastSlow')!,
      _presetCatalog.findById('fastSlowFast')!,
      _presetCatalog.findById('slowFast')!,
      _presetCatalog.findById('fastSlow')!,
      _presetCatalog.findById('customSpeedGraph')!,
    ];
    return Column(
      children: [
        _buildPresetOperationsBar(),
        const SizedBox(height: 8),
        Expanded(
          child: ProfessionalSpeedGraphPresetGrid(
            presets: presetCards,
            selectedPresetId:
                MotionInterpolationTruthCompiler.canonicalPresetId(
                    _velocity.presetId),
            onPresetTap: (preset) {
              final mapped = _presetFromId(preset.id);
              final nextVelocity = _velocityForPreset(mapped);
              setState(() {
                _selectedPreset = mapped;
                _velocity = nextVelocity;
                _easyEaseEnabled = mapped != LayerScopeGraphSpeedPreset.linear;
              });
              widget.onEasyEaseChanged(_easyEaseEnabled);
              widget.onPresetSelected?.call(mapped);
              widget.onVelocityChanged?.call(
                nextVelocity,
                editType: 'preset',
              );
              _recordRecentCurve(_currentInterpolationSpec());
              _emitPresetProof(preset.id, nextVelocity);
            },
            onPresetDoubleTap: (_) {
              setState(() {
                _selectedTab = _GraphEditorTab.customCurve;
              });
            },
            onPresetLongPress: (_) {
              _recordRecentCurve(_currentInterpolationSpec());
            },
          ),
        ),
        if (_recentCurves.isNotEmpty) ...[
          const SizedBox(height: 8),
          _RecentCurvesStrip(
            recentCurves: _recentCurves,
            onSelect: (index) {
              if (index < 0 || index >= _recentCurves.length) {
                return;
              }
              final interpolation = _recentCurves[index];
              _applyInterpolationClipboard(
                interpolation: interpolation,
                editType: 'recentCurve',
              );
            },
          ),
        ],
        if (_myPresets.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'My Presets',
              style: TextStyle(
                color: FxPalette.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _MyPresetStrip(
            presets: _myPresets,
            onApply: (preset) {
              final interpolation =
                  _customPresetService.loadInterpolationByPresetId(
                preset.presetId,
              );
              if (interpolation == null) {
                return;
              }
              _applyInterpolationClipboard(
                interpolation: interpolation,
                editType: 'apply',
              );
              setState(() {
                _myPresets = _customPresetService.listPresets();
              });
            },
            onDelete: (preset) {
              _customPresetService.deletePreset(preset.presetId);
              setState(() {
                _myPresets = _customPresetService.listPresets();
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCustomCurveTab() {
    final interpolation = _currentInterpolationSpec();
    return Column(
      children: [
        _GraphModeSelector(
          mode: _mode,
          onChanged: (nextMode) {
            setState(() {
              _mode = nextMode;
            });
            widget.onModeChanged?.call(nextMode);
          },
        ),
        const SizedBox(height: 10),
        _GraphToolbar(
          velocity: _velocity,
          onContinuousChanged: (value) {
            final next = _velocity.copyWith(
              continuous: value,
              incomingHandleLocked: value,
              outgoingHandleLocked: value,
              presetId: 'customSpeedGraph',
            );
            setState(() {
              _selectedPreset = LayerScopeGraphSpeedPreset.custom;
              _velocity = next;
            });
            widget.onVelocityChanged?.call(
              next,
              editType: 'toggleContinuous',
            );
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasRect = Rect.fromLTWH(
                0,
                0,
                constraints.maxWidth,
                math.max(160, constraints.maxHeight - 72),
              );
              final incoming =
                  _incomingHandlePosition(canvasRect, interpolation);
              final outgoing =
                  _outgoingHandlePosition(canvasRect, interpolation);
              return Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        _activeHandle = _resolveHandle(
                          details.localPosition,
                          incoming: incoming,
                          outgoing: outgoing,
                        );
                      },
                      onPanUpdate: (details) {
                        if (_activeHandle == null) {
                          return;
                        }
                        final editType = switch (_activeHandle!) {
                          _GraphHandleDragTarget.incoming => 'dragIncoming',
                          _GraphHandleDragTarget.outgoing => 'dragOutgoing',
                          _GraphHandleDragTarget.both => 'dragBoth',
                        };
                        _applyBezierHandleDrag(
                          details.localPosition,
                          canvasRect,
                          target: _activeHandle!,
                          editType: editType,
                        );
                      },
                      onPanEnd: (_) => _activeHandle = null,
                      child: CustomPaint(
                        painter: _SpeedGraphPainter(
                          mode: _mode,
                          interpolation: interpolation,
                          velocity: _velocity,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _VelocityReadout(
                    velocity: _velocity,
                    unitLabel: _speedUnitLabelForProperty(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNumericTab() {
    Widget slider({
      required String label,
      required double value,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${value.toStringAsFixed(1)}',
            style: const TextStyle(
              color: FxPalette.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: FxPalette.accent,
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          slider(
            label: 'Incoming Speed',
            value: _velocity.incomingSpeed ?? 0.0,
            min: 0,
            max: 220,
            onChanged: (next) {
              final updated = _velocity.copyWith(
                incomingSpeed: next,
                presetId: 'customSpeedGraph',
              );
              _applyNumericVelocityEdit(updated, editType: 'dragIncoming');
            },
          ),
          slider(
            label: 'Outgoing Speed',
            value: _velocity.outgoingSpeed ?? 0.0,
            min: 0,
            max: 220,
            onChanged: (next) {
              final updated = _velocity.copyWith(
                outgoingSpeed: next,
                presetId: 'customSpeedGraph',
              );
              _applyNumericVelocityEdit(updated, editType: 'dragOutgoing');
            },
          ),
          slider(
            label: 'Incoming Influence',
            value: _velocity.incomingInfluence ?? 33.333,
            min: 0,
            max: _supportsOvershootForProperty() ? 200 : 100,
            onChanged: (next) {
              final updated = _velocity.copyWith(
                incomingInfluence: next,
                presetId: 'customSpeedGraph',
              );
              _applyNumericVelocityEdit(updated, editType: 'dragIncoming');
            },
          ),
          slider(
            label: 'Outgoing Influence',
            value: _velocity.outgoingInfluence ?? 33.333,
            min: 0,
            max: _supportsOvershootForProperty() ? 200 : 100,
            onChanged: (next) {
              final updated = _velocity.copyWith(
                outgoingInfluence: next,
                presetId: 'customSpeedGraph',
              );
              _applyNumericVelocityEdit(updated, editType: 'dragOutgoing');
            },
          ),
          const SizedBox(height: 8),
          _GraphToolbar(
            velocity: _velocity,
            onContinuousChanged: (value) {
              final next = _velocity.copyWith(
                continuous: value,
                incomingHandleLocked: value,
                outgoingHandleLocked: value,
                presetId: 'customSpeedGraph',
              );
              setState(() {
                _velocity = next;
                _selectedPreset = LayerScopeGraphSpeedPreset.custom;
              });
              widget.onVelocityChanged
                  ?.call(next, editType: 'toggleContinuous');
            },
          ),
          const SizedBox(height: 8),
          _VelocityReadout(
            velocity: _velocity,
            unitLabel: _speedUnitLabelForProperty(),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetOperationsBar() {
    Widget actionButton({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      bool enabled = true,
    }) {
      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? FxPalette.surfaceRaised.withOpacity(0.82)
                : FxPalette.surfaceRaised.withOpacity(0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: enabled
                    ? FxPalette.textPrimary
                    : FxPalette.textFaint.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? FxPalette.textPrimary
                      : FxPalette.textFaint.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final canPaste = _curveClipboard != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          actionButton(
            label: 'Copy Curve',
            icon: Icons.copy_rounded,
            onTap: () {
              final current = _currentInterpolationSpec();
              setState(() {
                _curveClipboard = current;
              });
              _recordRecentCurve(current);
            },
          ),
          const SizedBox(width: 8),
          actionButton(
            label: 'Paste Curve',
            icon: Icons.paste_rounded,
            enabled: canPaste,
            onTap: () {
              final interpolation = _curveClipboard;
              if (interpolation == null) {
                return;
              }
              _applyInterpolationClipboard(
                interpolation: interpolation,
                editType: 'paste',
              );
            },
          ),
          const SizedBox(width: 8),
          actionButton(
            label: 'Paste Selected',
            icon: Icons.playlist_add_check_rounded,
            enabled: canPaste,
            onTap: () {
              final interpolation = _curveClipboard;
              if (interpolation == null) {
                return;
              }
              _applyInterpolationClipboard(
                interpolation: interpolation,
                editType: 'pasteSelected',
              );
            },
          ),
          const SizedBox(width: 8),
          actionButton(
            label: 'Paste Lane',
            icon: Icons.view_stream_rounded,
            enabled: canPaste,
            onTap: () {
              final interpolation = _curveClipboard;
              if (interpolation == null) {
                return;
              }
              _applyInterpolationClipboard(
                interpolation: interpolation,
                editType: 'pasteLane',
              );
            },
          ),
          const SizedBox(width: 8),
          actionButton(
            label: 'Save Preset',
            icon: Icons.bookmark_add_rounded,
            onTap: () {
              final saved = _customPresetService.saveInterpolation(
                interpolation: _currentInterpolationSpec(),
                selectedLaneId: 'unknown',
                selectedKeyframeId: 'unknown',
              );
              if (saved == null) {
                return;
              }
              setState(() {
                _myPresets = _customPresetService.listPresets();
              });
            },
          ),
        ],
      ),
    );
  }

  MotionInterpolationSpec _currentInterpolationSpec() {
    final preset = _graphPresetForVelocity(_velocity);
    final fallback = _interpolationForGraphPreset(
      preset == LayerScopeGraphSpeedPreset.linear
          ? LayerScopeGraphSpeedPreset.custom
          : preset,
    );
    return _truthCompiler
        .compileFromVelocity(
          velocity: _velocity.copyWith(
            presetId: _velocity.presetId ?? 'customSpeedGraph',
          ),
          fallback: _sanitizeInterpolationForProperty(fallback),
          inputMode: MotionInterpolationCompileInputMode.velocityNumbers,
        )
        .interpolation;
  }

  MotionInterpolationSpec _interpolationForGraphPreset(
    LayerScopeGraphSpeedPreset preset,
  ) {
    final presetId = switch (preset) {
      LayerScopeGraphSpeedPreset.linear => 'linear',
      LayerScopeGraphSpeedPreset.easyEase => 'easyEase',
      LayerScopeGraphSpeedPreset.easeIn => 'easyEaseIn',
      LayerScopeGraphSpeedPreset.easeOut => 'easyEaseOut',
      LayerScopeGraphSpeedPreset.slowFastSlow => 'slowFastSlow',
      LayerScopeGraphSpeedPreset.fastSlow => 'fastSlow',
      LayerScopeGraphSpeedPreset.slowFast => 'slowFast',
      LayerScopeGraphSpeedPreset.whip => 'whipSnap',
      LayerScopeGraphSpeedPreset.custom => 'customSpeedGraph',
      LayerScopeGraphSpeedPreset.fastSlowFast => 'fastSlowFast',
    };
    return _truthCompiler.compileFromPresetId(presetId).interpolation;
  }

  LayerScopeGraphSpeedPreset _graphPresetForVelocity(
    MotionKeyframeVelocity? velocity,
  ) {
    switch (velocity?.presetId) {
      case 'easyEase':
        return LayerScopeGraphSpeedPreset.easyEase;
      case 'easyEaseIn':
        return LayerScopeGraphSpeedPreset.easeIn;
      case 'easyEaseOut':
        return LayerScopeGraphSpeedPreset.easeOut;
      case 'slowFastSlow':
        return LayerScopeGraphSpeedPreset.slowFastSlow;
      case 'fastSlow':
        return LayerScopeGraphSpeedPreset.fastSlow;
      case 'slowFast':
        return LayerScopeGraphSpeedPreset.slowFast;
      case 'whipSnap':
        return LayerScopeGraphSpeedPreset.whip;
      case 'customSpeedGraph':
        return LayerScopeGraphSpeedPreset.custom;
      case 'fastSlowFast':
        return LayerScopeGraphSpeedPreset.fastSlowFast;
      default:
        return LayerScopeGraphSpeedPreset.linear;
    }
  }

  void _applyInterpolationClipboard({
    required MotionInterpolationSpec interpolation,
    required String editType,
  }) {
    final compiled = _truthCompiler.compileFromInterpolation(
      interpolation: _sanitizeInterpolationForProperty(interpolation),
      inputMode: MotionInterpolationCompileInputMode.existingSpec,
    );
    final nextVelocity = compiled.interpolation.velocity ?? _velocity;
    setState(() {
      _velocity = nextVelocity.copyWith(
        presetId: nextVelocity.presetId ?? 'customSpeedGraph',
      );
      _selectedPreset = _presetFromId(
        nextVelocity.presetId ?? 'customSpeedGraph',
      );
    });
    widget.onVelocityChanged?.call(_velocity, editType: editType);
    _recordRecentCurve(compiled.interpolation);
  }

  void _recordRecentCurve(MotionInterpolationSpec interpolation) {
    final normalized = _truthCompiler.compileFromInterpolation(
      interpolation: _sanitizeInterpolationForProperty(interpolation),
      inputMode: MotionInterpolationCompileInputMode.existingSpec,
    );
    final signature = normalized.curveHash;
    _recentCurves.removeWhere((candidate) {
      final compiled = _truthCompiler.compileFromInterpolation(
        interpolation: candidate,
        inputMode: MotionInterpolationCompileInputMode.existingSpec,
      );
      return compiled.curveHash == signature;
    });
    _recentCurves.insert(0, normalized.interpolation);
    if (_recentCurves.length > 8) {
      _recentCurves.removeRange(8, _recentCurves.length);
    }
    if (mounted) {
      setState(() {});
    }
  }

  LayerScopeGraphSpeedPreset _presetFromId(String presetId) {
    return switch (
        MotionInterpolationTruthCompiler.canonicalPresetId(presetId)) {
      'linear' => LayerScopeGraphSpeedPreset.linear,
      'easyEase' => LayerScopeGraphSpeedPreset.easyEase,
      'easyEaseIn' => LayerScopeGraphSpeedPreset.easeIn,
      'easyEaseOut' => LayerScopeGraphSpeedPreset.easeOut,
      'slowFastSlow' => LayerScopeGraphSpeedPreset.slowFastSlow,
      'fastSlow' => LayerScopeGraphSpeedPreset.fastSlow,
      'slowFast' => LayerScopeGraphSpeedPreset.slowFast,
      'whipSnap' => LayerScopeGraphSpeedPreset.whip,
      'fastSlowFast' => LayerScopeGraphSpeedPreset.fastSlowFast,
      _ => LayerScopeGraphSpeedPreset.custom,
    };
  }

  void _emitPresetProof(String presetId, MotionKeyframeVelocity velocity) {
    final canonical = MotionInterpolationTruthCompiler.canonicalPresetId(
      presetId,
    );
    final compiled = _truthCompiler.compileFromPresetId(canonical);
    developer.log(
      'TF_SPEED_GRAPH_PRESET_PROOF '
      'scope=layer_scope_graph '
      'presetId=$canonical '
      'aliasesResolved=true '
      'selectedLaneId=unknown '
      'selectedKeyframeId=unknown '
      'bezier='
      '${compiled.interpolation.bezier?.x1.toStringAsFixed(4) ?? 'na'},'
      '${compiled.interpolation.bezier?.y1.toStringAsFixed(4) ?? 'na'},'
      '${compiled.interpolation.bezier?.x2.toStringAsFixed(4) ?? 'na'},'
      '${compiled.interpolation.bezier?.y2.toStringAsFixed(4) ?? 'na'} '
      'curveHash=${compiled.curveHash} '
      'velocityHash=${compiled.velocityHash} '
      'applied=true '
      'fallbackReason=none '
      'velocityPreset=${velocity.presetId ?? 'none'}',
      name: 'ReFusionXx.SpeedGraph',
    );
  }

  Offset _incomingHandlePosition(
    Rect canvasRect,
    MotionInterpolationSpec interpolation,
  ) {
    final bezier = interpolation.bezier ??
        const MotionBezierControlPoints(
          x1: 0.333,
          y1: 0.0,
          x2: 0.667,
          y2: 1.0,
        );
    final clampedX = bezier.x1.clamp(0.0, 1.0);
    final clampedY = bezier.y1.clamp(-1.0, 2.0);
    final x = canvasRect.left + canvasRect.width * clampedX;
    final y = canvasRect.bottom - canvasRect.height * clampedY;
    return Offset(x, y);
  }

  Offset _outgoingHandlePosition(
    Rect canvasRect,
    MotionInterpolationSpec interpolation,
  ) {
    final bezier = interpolation.bezier ??
        const MotionBezierControlPoints(
          x1: 0.333,
          y1: 0.0,
          x2: 0.667,
          y2: 1.0,
        );
    final clampedX = bezier.x2.clamp(0.0, 1.0);
    final clampedY = bezier.y2.clamp(-1.0, 2.0);
    final x = canvasRect.left + canvasRect.width * clampedX;
    final y = canvasRect.bottom - canvasRect.height * clampedY;
    return Offset(x, y);
  }

  _GraphHandleDragTarget _resolveHandle(
    Offset position, {
    required Offset incoming,
    required Offset outgoing,
  }) {
    const handleHitRadius = 24.0; // 48dp touch-safe target
    final incomingDistance = (position - incoming).distance;
    final outgoingDistance = (position - outgoing).distance;
    final incomingHit = incomingDistance <= handleHitRadius;
    final outgoingHit = outgoingDistance <= handleHitRadius;
    if (_velocity.continuous) {
      if (incomingHit || outgoingHit) {
        return _GraphHandleDragTarget.both;
      }
      return _GraphHandleDragTarget.both;
    }
    if (incomingHit && !outgoingHit) {
      return _GraphHandleDragTarget.incoming;
    }
    if (outgoingHit && !incomingHit) {
      return _GraphHandleDragTarget.outgoing;
    }
    return incomingDistance <= outgoingDistance
        ? _GraphHandleDragTarget.incoming
        : _GraphHandleDragTarget.outgoing;
  }

  void _applyBezierHandleDrag(
    Offset position,
    Rect canvasRect, {
    required _GraphHandleDragTarget target,
    required String editType,
  }) {
    final before = _currentInterpolationSpec();
    final currentBezier = before.bezier ?? _defaultBezier;
    final nx =
        ((position.dx - canvasRect.left) / canvasRect.width).clamp(0.0, 1.0);
    final rawNy =
        (1.0 - ((position.dy - canvasRect.top) / canvasRect.height)).clamp(
      -1.0,
      2.0,
    );
    final ny = _supportsOvershootForProperty()
        ? rawNy
        : rawNy.clamp(0.0, 1.0).toDouble();
    MotionBezierControlPoints nextBezier;
    switch (target) {
      case _GraphHandleDragTarget.incoming:
        nextBezier = MotionBezierControlPoints(
          x1: nx.clamp(0.0, currentBezier.x2),
          y1: ny,
          x2: currentBezier.x2,
          y2: currentBezier.y2,
        );
        break;
      case _GraphHandleDragTarget.outgoing:
        nextBezier = MotionBezierControlPoints(
          x1: currentBezier.x1,
          y1: currentBezier.y1,
          x2: nx.clamp(currentBezier.x1, 1.0),
          y2: ny,
        );
        break;
      case _GraphHandleDragTarget.both:
        final mirroredX = (1.0 - nx).clamp(0.0, 1.0);
        final mirroredY = (1.0 - ny).clamp(-1.0, 2.0);
        final inX = math.min(nx, mirroredX);
        final outX = math.max(nx, mirroredX);
        nextBezier = MotionBezierControlPoints(
          x1: inX,
          y1: ny,
          x2: outX,
          y2: mirroredY,
        );
        break;
    }
    final compiled = _truthCompiler.compileFromInterpolation(
      interpolation: _sanitizeInterpolationForProperty(
        MotionInterpolationSpec.cubicBezier(bezier: nextBezier),
      ),
      inputMode: MotionInterpolationCompileInputMode.existingSpec,
    );
    final nextVelocity =
        (compiled.interpolation.velocity ?? _velocity).copyWith(
      presetId: 'customSpeedGraph',
    );
    setState(() {
      _selectedPreset = LayerScopeGraphSpeedPreset.custom;
      _velocity = nextVelocity;
    });
    widget.onVelocityChanged?.call(nextVelocity, editType: editType);
    _emitCanvasProof(
      before: before,
      after: compiled.interpolation,
      editType: editType,
    );
  }

  void _emitCanvasProof({
    required MotionInterpolationSpec before,
    required MotionInterpolationSpec after,
    required String editType,
  }) {
    final beforeCompiled = _truthCompiler.compileFromInterpolation(
      interpolation: before,
      inputMode: MotionInterpolationCompileInputMode.existingSpec,
    );
    final afterCompiled = _truthCompiler.compileFromInterpolation(
      interpolation: after,
      inputMode: MotionInterpolationCompileInputMode.existingSpec,
    );
    final beforeBezier = beforeCompiled.interpolation.bezier;
    final afterBezier = afterCompiled.interpolation.bezier;
    developer.log(
      'TF_SPEED_GRAPH_CANVAS_PROOF '
      'scope=layer_scope_graph '
      'graphMode=${_mode.name} '
      'selectedLaneId=unknown '
      'selectedKeyframeId=unknown '
      'selectedSegmentId=unknown '
      'editType=$editType '
      'beforeBezier='
      '${beforeBezier?.x1.toStringAsFixed(4) ?? 'na'},'
      '${beforeBezier?.y1.toStringAsFixed(4) ?? 'na'},'
      '${beforeBezier?.x2.toStringAsFixed(4) ?? 'na'},'
      '${beforeBezier?.y2.toStringAsFixed(4) ?? 'na'} '
      'afterBezier='
      '${afterBezier?.x1.toStringAsFixed(4) ?? 'na'},'
      '${afterBezier?.y1.toStringAsFixed(4) ?? 'na'},'
      '${afterBezier?.x2.toStringAsFixed(4) ?? 'na'},'
      '${afterBezier?.y2.toStringAsFixed(4) ?? 'na'} '
      'curveHashBefore=${beforeCompiled.curveHash} '
      'curveHashAfter=${afterCompiled.curveHash} '
      'sampledFromEvaluator=true '
      'wroteBezierTruth=true '
      'repositioned=false '
      'fallbackReason=none',
      name: 'ReFusionXx.SpeedGraph',
    );
  }

  void _applyNumericVelocityEdit(
    MotionKeyframeVelocity velocity, {
    required String editType,
  }) {
    final fallback =
        _sanitizeInterpolationForProperty(_currentInterpolationSpec());
    final safeVelocity = !_supportsOvershootForProperty()
        ? velocity.copyWith(
            incomingInfluence:
                (velocity.incomingInfluence ?? 0.0).clamp(0.0, 100.0),
            outgoingInfluence:
                (velocity.outgoingInfluence ?? 0.0).clamp(0.0, 100.0),
          )
        : velocity;
    final compiled = _truthCompiler.compileFromVelocity(
      velocity: safeVelocity,
      fallback: fallback,
      inputMode: MotionInterpolationCompileInputMode.velocityNumbers,
    );
    final nextVelocity =
        (compiled.interpolation.velocity ?? safeVelocity).copyWith(
      presetId: 'customSpeedGraph',
    );
    setState(() {
      _selectedPreset = LayerScopeGraphSpeedPreset.custom;
      _velocity = nextVelocity;
    });
    widget.onVelocityChanged?.call(nextVelocity, editType: editType);
  }

  MotionInterpolationSpec _sanitizeInterpolationForProperty(
    MotionInterpolationSpec interpolation,
  ) {
    if (_supportsOvershootForProperty()) {
      return interpolation;
    }
    final bezier = interpolation.bezier;
    if (bezier == null) {
      return interpolation;
    }
    return interpolation.copyWith(
      bezier: MotionBezierControlPoints(
        x1: bezier.x1.clamp(0.0, 1.0),
        y1: bezier.y1.clamp(0.0, 1.0),
        x2: bezier.x2.clamp(0.0, 1.0),
        y2: bezier.y2.clamp(0.0, 1.0),
      ),
    );
  }

  bool _supportsOvershootForProperty() {
    final path = widget.propertyPath?.toLowerCase() ?? '';
    if (path.contains('opacity')) {
      return false;
    }
    if (path.contains('blur')) {
      return false;
    }
    return true;
  }

  String _speedUnitLabelForProperty() {
    final path = widget.propertyPath?.toLowerCase() ?? '';
    if (path.contains('position') ||
        path.endsWith('.x') ||
        path.endsWith('.y')) {
      return 'px/sec';
    }
    if (path.contains('rotation') || path.contains('angle')) {
      return 'deg/sec';
    }
    if (path.contains('scale')) {
      return '%/sec';
    }
    if (path.contains('opacity')) {
      return '%/sec';
    }
    if (path.contains('blur')) {
      return 'px/sec';
    }
    return 'units/sec';
  }

  MotionKeyframeVelocity _velocityForPreset(LayerScopeGraphSpeedPreset preset) {
    switch (preset) {
      case LayerScopeGraphSpeedPreset.linear:
        return const MotionKeyframeVelocity(
          incomingSpeed: 0.0,
          outgoingSpeed: 0.0,
          incomingInfluence: 0.0,
          outgoingInfluence: 0.0,
          incomingHandleLocked: true,
          outgoingHandleLocked: true,
          continuous: true,
          presetId: 'linear',
        );
      case LayerScopeGraphSpeedPreset.easyEase:
        return const MotionKeyframeVelocity(
          incomingSpeed: 0.0,
          outgoingSpeed: 0.0,
          incomingInfluence: 33.333,
          outgoingInfluence: 33.333,
          incomingHandleLocked: true,
          outgoingHandleLocked: true,
          continuous: true,
          presetId: 'easyEase',
        );
      case LayerScopeGraphSpeedPreset.easeIn:
        return const MotionKeyframeVelocity(
          incomingSpeed: 0.0,
          incomingInfluence: 33.333,
          incomingHandleLocked: true,
          outgoingHandleLocked: false,
          continuous: false,
          presetId: 'easyEaseIn',
        );
      case LayerScopeGraphSpeedPreset.easeOut:
        return const MotionKeyframeVelocity(
          outgoingSpeed: 0.0,
          outgoingInfluence: 33.333,
          incomingHandleLocked: false,
          outgoingHandleLocked: true,
          continuous: false,
          presetId: 'easyEaseOut',
        );
      case LayerScopeGraphSpeedPreset.slowFastSlow:
        return const MotionKeyframeVelocity(
          incomingSpeed: 0.0,
          outgoingSpeed: 0.0,
          incomingInfluence: 85.0,
          outgoingInfluence: 85.0,
          incomingHandleLocked: true,
          outgoingHandleLocked: true,
          continuous: true,
          presetId: 'slowFastSlow',
        );
      case LayerScopeGraphSpeedPreset.fastSlow:
        return const MotionKeyframeVelocity(
          incomingSpeed: 70.0,
          outgoingSpeed: 20.0,
          incomingInfluence: 15.0,
          outgoingInfluence: 75.0,
          continuous: false,
          presetId: 'fastSlow',
        );
      case LayerScopeGraphSpeedPreset.slowFast:
        return const MotionKeyframeVelocity(
          incomingSpeed: 20.0,
          outgoingSpeed: 70.0,
          incomingInfluence: 75.0,
          outgoingInfluence: 15.0,
          continuous: false,
          presetId: 'slowFast',
        );
      case LayerScopeGraphSpeedPreset.whip:
        return const MotionKeyframeVelocity(
          incomingSpeed: 30.0,
          outgoingSpeed: 120.0,
          incomingInfluence: 10.0,
          outgoingInfluence: 95.0,
          continuous: false,
          presetId: 'whipSnap',
        );
      case LayerScopeGraphSpeedPreset.custom:
        return _velocity.copyWith(presetId: 'customSpeedGraph');
      case LayerScopeGraphSpeedPreset.fastSlowFast:
        return const MotionKeyframeVelocity(
          incomingSpeed: 95.0,
          outgoingSpeed: 95.0,
          incomingInfluence: 88.0,
          outgoingInfluence: 88.0,
          continuous: false,
          presetId: 'fastSlowFast',
        );
    }
  }
}

class _GraphModeSelector extends StatelessWidget {
  const _GraphModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final LayerScopeGraphMode mode;
  final ValueChanged<LayerScopeGraphMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModePill(
            label: 'Value Graph',
            isSelected: mode == LayerScopeGraphMode.value,
            onTap: () => onChanged(LayerScopeGraphMode.value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModePill(
            label: 'Speed Graph',
            isSelected: mode == LayerScopeGraphMode.speed,
            onTap: () => onChanged(LayerScopeGraphMode.speed),
          ),
        ),
      ],
    );
  }
}

class _GraphEditorTabSelector extends StatelessWidget {
  const _GraphEditorTabSelector({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final _GraphEditorTab selectedTab;
  final ValueChanged<_GraphEditorTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    Widget tab({
      required _GraphEditorTab tab,
      required String label,
    }) {
      final selected = selectedTab == tab;
      return Expanded(
        child: InkWell(
          onTap: () => onTabSelected(tab),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? FxPalette.accent.withOpacity(0.16)
                  : FxPalette.surfaceRaised.withOpacity(0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? FxPalette.accent.withOpacity(0.65)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? FxPalette.accent : FxPalette.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(tab: _GraphEditorTab.presets, label: 'Presets'),
        const SizedBox(width: 8),
        tab(tab: _GraphEditorTab.customCurve, label: 'Custom Curve'),
        const SizedBox(width: 8),
        tab(tab: _GraphEditorTab.numeric, label: 'Numeric'),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? FxPalette.accent.withOpacity(0.16)
              : FxPalette.surfaceRaised.withOpacity(0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? FxPalette.accent.withOpacity(0.65)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? FxPalette.accent : FxPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GraphToolbar extends StatelessWidget {
  const _GraphToolbar({
    required this.velocity,
    required this.onContinuousChanged,
  });

  final MotionKeyframeVelocity velocity;
  final ValueChanged<bool> onContinuousChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Continuous',
          style: TextStyle(
            color: FxPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: velocity.continuous,
          onChanged: onContinuousChanged,
          activeColor: FxPalette.accent,
        ),
        const Spacer(),
        const Text(
          'Selected Keyframe',
          style: TextStyle(
            color: FxPalette.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SpeedGraphPainter extends CustomPainter {
  const _SpeedGraphPainter({
    required this.mode,
    required this.interpolation,
    required this.velocity,
  });

  final LayerScopeGraphMode mode;
  final MotionInterpolationSpec interpolation;
  final MotionKeyframeVelocity velocity;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white.withOpacity(0.03);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(14),
      ),
      bg,
    );

    final grid = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i < 6; i++) {
      final x = size.width * (i / 6);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    final centerX = size.width * 0.5;
    final selectedPaint = Paint()
      ..color = FxPalette.accent.withOpacity(0.6)
      ..strokeWidth = 1.8;
    canvas.drawLine(
        Offset(centerX, 0), Offset(centerX, size.height), selectedPaint);

    final playheadPaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..strokeWidth = 1.2;
    final playheadX = size.width * 0.57;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );

    final bezier = interpolation.bezier ??
        const MotionBezierControlPoints(
          x1: 0.333,
          y1: 0.0,
          x2: 0.667,
          y2: 1.0,
        );
    final incomingX = size.width * bezier.x1.clamp(0.0, 1.0);
    final outgoingX = size.width * bezier.x2.clamp(0.0, 1.0);
    final incomingY = size.height * (1.0 - bezier.y1.clamp(-1.0, 2.0));
    final outgoingY = size.height * (1.0 - bezier.y2.clamp(-1.0, 2.0));

    final path = Path();
    const samples = 72;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final progress = evaluateMotionCurveProgress(interpolation, t);
      final x = size.width * t;
      final y = size.height * (1.0 - progress.clamp(-1.0, 2.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final curvePaint = Paint()
      ..color = mode == LayerScopeGraphMode.speed
          ? FxPalette.accent
          : Colors.orangeAccent.withOpacity(0.95)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, curvePaint);

    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.4;
    final start = Offset(0, size.height);
    final end = Offset(size.width, 0);
    canvas.drawLine(start, Offset(incomingX, incomingY), guidePaint);
    canvas.drawLine(end, Offset(outgoingX, outgoingY), guidePaint);

    final inHandlePaint = Paint()..color = Colors.cyanAccent;
    final outHandlePaint = Paint()..color = Colors.pinkAccent;
    canvas.drawCircle(Offset(incomingX, incomingY), 7, inHandlePaint);
    canvas.drawCircle(Offset(outgoingX, outgoingY), 7, outHandlePaint);
    canvas.drawCircle(
      Offset(centerX, size.height * 0.5),
      5.5,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedGraphPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.velocity != velocity ||
        oldDelegate.interpolation != interpolation;
  }
}

class _VelocityReadout extends StatelessWidget {
  const _VelocityReadout({
    required this.velocity,
    required this.unitLabel,
  });

  final MotionKeyframeVelocity velocity;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    String fmt(double? value) =>
        value == null ? '0.0' : value.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.74),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'In ${fmt(velocity.incomingSpeed)} $unitLabel | ${fmt(velocity.incomingInfluence)}%',
              style: const TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Out ${fmt(velocity.outgoingSpeed)} $unitLabel | ${fmt(velocity.outgoingInfluence)}%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCurvesStrip extends StatelessWidget {
  const _RecentCurvesStrip({
    required this.recentCurves,
    required this.onSelect,
  });

  final List<MotionInterpolationSpec> recentCurves;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < recentCurves.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            InkWell(
              onTap: () => onSelect(index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FxPalette.surfaceRaised.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  'Recent ${index + 1}',
                  style: const TextStyle(
                    color: FxPalette.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MyPresetStrip extends StatelessWidget {
  const _MyPresetStrip({
    required this.presets,
    required this.onApply,
    required this.onDelete,
  });

  final List<SpeedGraphCustomPresetRecord> presets;
  final ValueChanged<SpeedGraphCustomPresetRecord> onApply;
  final ValueChanged<SpeedGraphCustomPresetRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < presets.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            InkWell(
              onTap: () => onApply(presets[index]),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FxPalette.surfaceRaised.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      presets[index].label,
                      style: const TextStyle(
                        color: FxPalette.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => onDelete(presets[index]),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: FxPalette.textFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _GraphHandleDragTarget {
  incoming,
  outgoing,
  both,
}
