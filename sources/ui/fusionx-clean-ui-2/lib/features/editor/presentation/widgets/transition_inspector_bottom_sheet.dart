import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

enum TransitionInspectorAction {
  apply,
  openManual,
  delete,
}

class TransitionInspectorResult {
  const TransitionInspectorResult({
    required this.action,
    required this.transition,
  });

  final TransitionInspectorAction action;
  final TimelineTrackTransitionData transition;
}

class TransitionInspectorBottomSheet extends StatefulWidget {
  const TransitionInspectorBottomSheet({
    super.key,
    required this.initialTransition,
  });

  final TimelineTrackTransitionData initialTransition;

  @override
  State<TransitionInspectorBottomSheet> createState() =>
      _TransitionInspectorBottomSheetState();
}

class _TransitionInspectorBottomSheetState
    extends State<TransitionInspectorBottomSheet> {
  late TimelineTrackTransitionData _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialTransition;
  }

  double _parameter(String key, {required double fallback}) {
    return _draft.parameterValue(key, fallback: fallback);
  }

  void _updateParameter(String key, double value) {
    final nextValues = <String, double>{
      ..._draft.parameterValues,
      key: value,
    };
    setState(() {
      _draft = _draft.copyWith(parameterValues: nextValues);
    });
  }

  void _updateDurationMilliseconds(double value) {
    setState(() {
      _draft = _draft.copyWith(
        durationTime: TimelineTime.fromMilliseconds(value.round()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.48,
          padding: EdgeInsets.only(bottom: safeBottom),
          decoration: const BoxDecoration(
            color: FxPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FxPalette.textFaint,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _draft.preset.label,
                        style: const TextStyle(
                          color: FxPalette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          TransitionInspectorResult(
                            action: TransitionInspectorAction.delete,
                            transition: _draft,
                          ),
                        );
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: FxPalette.danger),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _InspectorSection(
                      label: 'Duration',
                      child: _InspectorSliderRow(
                        valueLabel:
                            '${(_draft.durationTime.inMilliseconds / 1000).toStringAsFixed(2)}s',
                        slider: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: FxPalette.accent,
                            inactiveTrackColor:
                                FxPalette.accent.withOpacity(0.16),
                            thumbColor: Colors.white,
                            overlayColor: FxPalette.accent.withOpacity(0.12),
                          ),
                          child: Slider(
                            min: 220,
                            max: 1600,
                            value: _draft.durationTime.inMilliseconds
                                .clamp(220, 1600)
                                .toDouble(),
                            onChanged: _updateDurationMilliseconds,
                          ),
                        ),
                      ),
                    ),
                    _InspectorSection(
                      label: 'Curve',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TimelineTransitionCurve.values.map((curve) {
                          final isActive = curve == _draft.curve;
                          return _CurveChip(
                            label: curve.label,
                            isActive: isActive,
                            onTap: () {
                              setState(() {
                                _draft = _draft.copyWith(curve: curve);
                              });
                            },
                          );
                        }).toList(growable: false),
                      ),
                    ),
                    if (_draft.preset == TimelineTransitionPreset.fadeBlack)
                      _InspectorSection(
                        label: 'Black Peak',
                        child: _InspectorSliderRow(
                          valueLabel: _formatPercent(
                              _parameter('blackPeak', fallback: 0.94)),
                          slider: Slider(
                            min: 0.2,
                            max: 1.0,
                            value: _parameter('blackPeak', fallback: 0.94)
                                .clamp(0.2, 1.0),
                            onChanged: (value) =>
                                _updateParameter('blackPeak', value),
                          ),
                        ),
                      ),
                    if (_draft.preset ==
                        TimelineTransitionPreset.zoomInCamera) ...[
                      _InspectorSection(
                        label: 'Incoming Zoom',
                        child: _InspectorSliderRow(
                          valueLabel: _formatScale(
                            _parameter('incomingStartScale', fallback: 1.18),
                          ),
                          slider: Slider(
                            min: 1.02,
                            max: 1.45,
                            value: _parameter(
                              'incomingStartScale',
                              fallback: 1.18,
                            ).clamp(1.02, 1.45),
                            onChanged: (value) => _updateParameter(
                              'incomingStartScale',
                              value,
                            ),
                          ),
                        ),
                      ),
                      _InspectorSection(
                        label: 'Outgoing Push',
                        child: _InspectorSliderRow(
                          valueLabel: _formatScale(
                            _parameter('outgoingBoostScale', fallback: 1.05),
                          ),
                          slider: Slider(
                            min: 1.0,
                            max: 1.25,
                            value: _parameter(
                              'outgoingBoostScale',
                              fallback: 1.05,
                            ).clamp(1.0, 1.25),
                            onChanged: (value) =>
                                _updateParameter('outgoingBoostScale', value),
                          ),
                        ),
                      ),
                      _InspectorSection(
                        label: 'Entry Delay',
                        child: _InspectorSliderRow(
                          valueLabel: _formatPercent(
                              _parameter('entryDelay', fallback: 0.18)),
                          slider: Slider(
                            min: 0.0,
                            max: 0.48,
                            value: _parameter('entryDelay', fallback: 0.18)
                                .clamp(0.0, 0.48),
                            onChanged: (value) =>
                                _updateParameter('entryDelay', value),
                          ),
                        ),
                      ),
                      _InspectorSection(
                        label: 'Bridge Darkness',
                        child: _InspectorSliderRow(
                          valueLabel: _formatPercent(
                            _parameter('bridgeDarkness', fallback: 0.22),
                          ),
                          slider: Slider(
                            min: 0.0,
                            max: 0.65,
                            value: _parameter(
                              'bridgeDarkness',
                              fallback: 0.22,
                            ).clamp(0.0, 0.65),
                            onChanged: (value) =>
                                _updateParameter('bridgeDarkness', value),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            TransitionInspectorResult(
                              action: TransitionInspectorAction.openManual,
                              transition: _draft,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FxPalette.textPrimary,
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.12),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Manual',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            TransitionInspectorResult(
                              action: TransitionInspectorAction.apply,
                              transition: _draft,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FxPalette.accent,
                          foregroundColor: FxPalette.background,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPercent(double value) => '${(value * 100).round()}%';

  String _formatScale(double value) =>
      '${lerpDouble(0, value * 100, 1)!.toStringAsFixed(0)}%';
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FxPalette.dividerSoft, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorSliderRow extends StatelessWidget {
  const _InspectorSliderRow({
    required this.valueLabel,
    required this.slider,
  });

  final String valueLabel;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            Text(
              valueLabel,
              style: TextStyle(
                color: FxPalette.textMuted.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        slider,
      ],
    );
  }
}

class _CurveChip extends StatelessWidget {
  const _CurveChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? FxPalette.accent.withOpacity(0.14)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? FxPalette.accent.withOpacity(0.46)
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? FxPalette.accent : FxPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
