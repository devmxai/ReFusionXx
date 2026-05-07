import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

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
}

class LayerScopeGraphBottomSheet extends StatefulWidget {
  const LayerScopeGraphBottomSheet({
    super.key,
    required this.easyEaseEnabled,
    required this.onEasyEaseChanged,
    this.initialMode = LayerScopeGraphMode.speed,
    this.selectedPreset = LayerScopeGraphSpeedPreset.easyEase,
    this.onModeChanged,
    this.onPresetSelected,
    required this.onDone,
  });

  final bool easyEaseEnabled;
  final ValueChanged<bool> onEasyEaseChanged;
  final LayerScopeGraphMode initialMode;
  final LayerScopeGraphSpeedPreset selectedPreset;
  final ValueChanged<LayerScopeGraphMode>? onModeChanged;
  final ValueChanged<LayerScopeGraphSpeedPreset>? onPresetSelected;
  final VoidCallback onDone;

  @override
  State<LayerScopeGraphBottomSheet> createState() =>
      _LayerScopeGraphBottomSheetState();
}

class _LayerScopeGraphBottomSheetState
    extends State<LayerScopeGraphBottomSheet> {
  late bool _easyEaseEnabled;
  late LayerScopeGraphMode _mode;
  late LayerScopeGraphSpeedPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _easyEaseEnabled = widget.easyEaseEnabled;
    _mode = widget.initialMode;
    _selectedPreset = widget.selectedPreset;
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.30).clamp(220.0, 280.0);
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
                    const SizedBox(height: 12),
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
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final preset
                                in LayerScopeGraphSpeedPreset.values)
                              _PresetChip(
                                preset: preset,
                                isSelected: _selectedPreset == preset,
                                onTap: () {
                                  setState(() {
                                    _selectedPreset = preset;
                                    _easyEaseEnabled = preset !=
                                        LayerScopeGraphSpeedPreset.linear;
                                  });
                                  widget.onEasyEaseChanged(_easyEaseEnabled);
                                  widget.onPresetSelected?.call(preset);
                                },
                              ),
                          ],
                        ),
                      ),
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

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final LayerScopeGraphSpeedPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          _labelForPreset(preset),
          style: TextStyle(
            color: isSelected ? FxPalette.accent : FxPalette.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static String _labelForPreset(LayerScopeGraphSpeedPreset preset) {
    switch (preset) {
      case LayerScopeGraphSpeedPreset.linear:
        return 'Linear';
      case LayerScopeGraphSpeedPreset.easyEase:
        return 'Easy Ease';
      case LayerScopeGraphSpeedPreset.easeIn:
        return 'Ease In';
      case LayerScopeGraphSpeedPreset.easeOut:
        return 'Ease Out';
      case LayerScopeGraphSpeedPreset.slowFastSlow:
        return 'Slow-Fast-Slow';
      case LayerScopeGraphSpeedPreset.fastSlow:
        return 'Fast-Slow';
      case LayerScopeGraphSpeedPreset.slowFast:
        return 'Slow-Fast';
      case LayerScopeGraphSpeedPreset.whip:
        return 'Whip';
      case LayerScopeGraphSpeedPreset.custom:
        return 'Custom';
    }
  }
}
