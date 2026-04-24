import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

@immutable
class LayerScopeValueControlSpec {
  const LayerScopeValueControlSpec({
    required this.id,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.formatValue,
    this.divisions,
    this.options = const <LayerScopeValueOption>[],
  });

  final String id;
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double value) formatValue;
  final List<LayerScopeValueOption> options;
}

@immutable
class LayerScopeValueOption {
  const LayerScopeValueOption({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

@immutable
class LayerScopeValueChange {
  const LayerScopeValueChange({
    required this.controlId,
    required this.value,
  });

  final String controlId;
  final double value;
}

class LayerScopeValueBottomSheet extends StatefulWidget {
  const LayerScopeValueBottomSheet({
    super.key,
    required this.controls,
    required this.onDone,
    required this.onChanged,
  });

  final List<LayerScopeValueControlSpec> controls;
  final VoidCallback onDone;
  final ValueChanged<LayerScopeValueChange> onChanged;

  @override
  State<LayerScopeValueBottomSheet> createState() =>
      _LayerScopeValueBottomSheetState();
}

class _LayerScopeValueBottomSheetState
    extends State<LayerScopeValueBottomSheet> {
  late Map<String, double> _values;

  @override
  void initState() {
    super.initState();
    _values = <String, double>{
      for (final control in widget.controls) control.id: control.value,
    };
  }

  @override
  void didUpdateWidget(covariant LayerScopeValueBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controls != widget.controls) {
      _values = <String, double>{
        for (final control in widget.controls) control.id: control.value,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.52).clamp(330.0, 500.0);
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                    child: Row(
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
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        0,
                        14,
                        (safeBottom > 0 ? safeBottom : 12) + 10,
                      ),
                      itemBuilder: (context, index) {
                        final control = widget.controls[index];
                        final value = (_values[control.id] ?? control.value)
                            .clamp(control.min, control.max)
                            .toDouble();
                        if (control.options.isNotEmpty) {
                          return _LayerScopeValueSegmentedCard(
                            label: control.label,
                            valueText: control.formatValue(value),
                            value: value,
                            options: control.options,
                            onChanged: (nextValue) {
                              setState(() {
                                _values[control.id] = nextValue;
                              });
                              widget.onChanged(
                                LayerScopeValueChange(
                                  controlId: control.id,
                                  value: nextValue,
                                ),
                              );
                            },
                          );
                        }
                        return _LayerScopeValueSliderCard(
                          label: control.label,
                          valueText: control.formatValue(value),
                          min: control.min,
                          max: control.max,
                          divisions: control.divisions,
                          value: value,
                          onChanged: (nextValue) {
                            setState(() {
                              _values[control.id] = nextValue;
                            });
                            widget.onChanged(
                              LayerScopeValueChange(
                                controlId: control.id,
                                value: nextValue,
                              ),
                            );
                          },
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemCount: widget.controls.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerScopeValueSliderCard extends StatelessWidget {
  const _LayerScopeValueSliderCard({
    required this.label,
    required this.valueText,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final String valueText;
  final double min;
  final double max;
  final int? divisions;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: FxPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  color: FxPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: FxPalette.accent,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: FxPalette.accent,
              overlayColor: FxPalette.accent.withOpacity(0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              min: min,
              max: max,
              divisions: divisions,
              value: value.clamp(min, max).toDouble(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerScopeValueSegmentedCard extends StatelessWidget {
  const _LayerScopeValueSegmentedCard({
    required this.label,
    required this.valueText,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final List<LayerScopeValueOption> options;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: FxPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  color: FxPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                for (final option in options)
                  Expanded(
                    child: _LayerScopeValueSegment(
                      label: option.label,
                      selected: (option.value - value).abs() < 0.5,
                      onTap: () => onChanged(option.value),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerScopeValueSegment extends StatelessWidget {
  const _LayerScopeValueSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 34),
          decoration: BoxDecoration(
            color: selected ? FxPalette.accent.withOpacity(0.18) : null,
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? Border.all(color: FxPalette.accent.withOpacity(0.45))
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? FxPalette.textPrimary : FxPalette.textMuted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
