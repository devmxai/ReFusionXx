import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/timeline_mock_models.dart';
import '../models/timeline_time.dart';

@immutable
class ClipSpeedDraft {
  const ClipSpeedDraft({
    required this.clipId,
    required this.speedMode,
    required this.playbackRate,
    required this.sourceDurationTime,
  });

  final String clipId;
  final TimelineClipSpeedMode speedMode;
  final double playbackRate;
  final TimelineTime sourceDurationTime;

  TimelineTime get resultingDurationTime => TimelineTime.fromSecondsDouble(
        sourceDurationTime.inSecondsDouble /
            math.max(0.001, playbackRate.clamp(0.01, 100.0)),
      );

  ClipSpeedDraft copyWith({
    String? clipId,
    TimelineClipSpeedMode? speedMode,
    double? playbackRate,
    TimelineTime? sourceDurationTime,
  }) {
    return ClipSpeedDraft(
      clipId: clipId ?? this.clipId,
      speedMode: speedMode ?? this.speedMode,
      playbackRate: playbackRate ?? this.playbackRate,
      sourceDurationTime: sourceDurationTime ?? this.sourceDurationTime,
    );
  }
}

class ClipSpeedBottomSheet extends StatefulWidget {
  const ClipSpeedBottomSheet({
    super.key,
    required this.initialDraft,
    this.onPreviewRequested,
  });

  final ClipSpeedDraft initialDraft;
  final ValueChanged<ClipSpeedDraft>? onPreviewRequested;

  @override
  State<ClipSpeedBottomSheet> createState() => _ClipSpeedBottomSheetState();
}

class _ClipSpeedBottomSheetState extends State<ClipSpeedBottomSheet> {
  late ClipSpeedDraft _draft;
  late TimelineClipSpeedMode _activeTab;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _activeTab = widget.initialDraft.speedMode;
  }

  double get _sliderValue => _sliderValueFromPlaybackRate(_draft.playbackRate);

  void _setPlaybackRate(double playbackRate) {
    setState(() {
      _draft = _draft.copyWith(
        speedMode: TimelineClipSpeedMode.normal,
        playbackRate: playbackRate,
      );
      _activeTab = TimelineClipSpeedMode.normal;
    });
  }

  double _sliderValueFromPlaybackRate(double playbackRate) {
    final clampedRate = playbackRate.clamp(0.25, 4.0).toDouble();
    if (clampedRate >= 1.0) {
      return (clampedRate - 1.0) / 3.0;
    }
    return -((1.0 - clampedRate) / 0.75);
  }

  double _playbackRateFromSliderValue(double sliderValue) {
    final clampedSlider = sliderValue.clamp(-1.0, 1.0).toDouble();
    if (clampedSlider >= 0) {
      return 1.0 + (clampedSlider * 3.0);
    }
    return 1.0 - ((-clampedSlider) * 0.75);
  }

  String _formatSpeed(double value) {
    final fixed = value >= 10
        ? value.toStringAsFixed(0)
        : value >= 2
            ? value.toStringAsFixed(1)
            : value.toStringAsFixed(2);
    final normalized =
        fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
    return '${normalized}x';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.46;
    final isCurve = _activeTab == TimelineClipSpeedMode.curve;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: sheetHeight + bottomInset + safeBottom,
          padding: EdgeInsets.only(bottom: bottomInset + safeBottom),
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
              const SizedBox(height: 11),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SpeedTabChip(
                      label: 'Normal',
                      isActive: _activeTab == TimelineClipSpeedMode.normal,
                      onTap: () {
                        setState(() {
                          _activeTab = TimelineClipSpeedMode.normal;
                          _draft = _draft.copyWith(
                            speedMode: TimelineClipSpeedMode.normal,
                          );
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _SpeedTabChip(
                      label: 'Curve',
                      icon: Icons.show_chart_rounded,
                      isActive: _activeTab == TimelineClipSpeedMode.curve,
                      onTap: () {
                        setState(() {
                          _activeTab = TimelineClipSpeedMode.curve;
                          _draft = _draft.copyWith(
                            speedMode: TimelineClipSpeedMode.curve,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: isCurve ? _buildCurvePlaceholder() : _buildNormalTab(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FxPalette.textPrimary,
                          side: const BorderSide(color: FxPalette.divider),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isCurve
                            ? null
                            : () => widget.onPreviewRequested?.call(
                                  _draft.copyWith(
                                    speedMode: TimelineClipSpeedMode.normal,
                                  ),
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FxPalette.textPrimary,
                          side: const BorderSide(color: FxPalette.accent),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Play'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isCurve
                            ? null
                            : () => Navigator.of(context).pop(
                                  _draft.copyWith(
                                    speedMode: TimelineClipSpeedMode.normal,
                                  ),
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FxPalette.accent,
                          foregroundColor: FxPalette.background,
                          disabledBackgroundColor:
                              FxPalette.surfaceRaised.withOpacity(0.7),
                          disabledForegroundColor:
                              FxPalette.textMuted.withOpacity(0.7),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(isCurve ? 'Coming Soon' : 'Apply'),
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

  Widget _buildNormalTab() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatSpeed(_draft.playbackRate),
                style: const TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: FxPalette.accent,
                  inactiveTrackColor: FxPalette.dividerSoft.withOpacity(0.92),
                  thumbColor: FxPalette.textPrimary,
                  overlayColor: FxPalette.accent.withOpacity(0.1),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: -1,
                  max: 1,
                  value: _sliderValue,
                  onChanged: (value) =>
                      _setPlaybackRate(_playbackRateFromSliderValue(value)),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Slow',
                    style: TextStyle(
                      color: FxPalette.textMuted.withOpacity(0.88),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '1x',
                    style: TextStyle(
                      color: FxPalette.textMuted.withOpacity(0.88),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Fast',
                    style: TextStyle(
                      color: FxPalette.textMuted.withOpacity(0.88),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurvePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FxPalette.dividerSoft, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 18,
                color: FxPalette.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'Curve Speed',
                style: TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Curve speed will be built in the next slice with real timeline points and speed ramps.',
            style: TextStyle(
              color: FxPalette.textMuted.withOpacity(0.94),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedTabChip extends StatelessWidget {
  const _SpeedTabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.025),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? FxPalette.accent : FxPalette.dividerSoft,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isActive ? FxPalette.textPrimary : FxPalette.textMuted,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive ? FxPalette.textPrimary : FxPalette.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
