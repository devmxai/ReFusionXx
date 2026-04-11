import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

@immutable
class TextClipEditableParameter {
  const TextClipEditableParameter({
    required this.id,
    required this.label,
    required this.value,
    required this.minValue,
    required this.maxValue,
    this.description,
  });

  final String id;
  final String label;
  final double value;
  final double minValue;
  final double maxValue;
  final String? description;

  TextClipEditableParameter copyWith({
    String? id,
    String? label,
    double? value,
    double? minValue,
    double? maxValue,
    String? description,
  }) {
    return TextClipEditableParameter(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      description: description ?? this.description,
    );
  }
}

@immutable
class TextClipEditDraft {
  const TextClipEditDraft({
    required this.elementId,
    required this.text,
    required this.fontSize,
    required this.parameters,
  });

  final String elementId;
  final String text;
  final double fontSize;
  final List<TextClipEditableParameter> parameters;

  TextClipEditDraft copyWith({
    String? elementId,
    String? text,
    double? fontSize,
    List<TextClipEditableParameter>? parameters,
  }) {
    return TextClipEditDraft(
      elementId: elementId ?? this.elementId,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      parameters: parameters ?? this.parameters,
    );
  }
}

class TextClipEditBottomSheet extends StatefulWidget {
  const TextClipEditBottomSheet({
    super.key,
    required this.initialDraft,
    required this.onDraftChanged,
    required this.onPlayPreview,
    required this.onCancel,
    required this.onDone,
    this.isPlayPreviewEnabled = false,
    this.isPreviewPlaying = false,
  });

  final TextClipEditDraft initialDraft;
  final ValueChanged<TextClipEditDraft> onDraftChanged;
  final VoidCallback onPlayPreview;
  final VoidCallback onCancel;
  final ValueChanged<TextClipEditDraft> onDone;
  final bool isPlayPreviewEnabled;
  final bool isPreviewPlaying;

  @override
  State<TextClipEditBottomSheet> createState() =>
      _TextClipEditBottomSheetState();
}

class _TextClipEditBottomSheetState extends State<TextClipEditBottomSheet> {
  late final TextEditingController _textController;
  late double _fontSize;
  late List<TextClipEditableParameter> _parameters;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialDraft.text);
    _fontSize = widget.initialDraft.fontSize;
    _parameters = List<TextClipEditableParameter>.from(
      widget.initialDraft.parameters,
    );
  }

  @override
  void didUpdateWidget(covariant TextClipEditBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDraft.elementId != widget.initialDraft.elementId) {
      _replaceLocalDraft(widget.initialDraft);
      return;
    }

    if ((_fontSize - widget.initialDraft.fontSize).abs() > 0.001) {
      _fontSize = widget.initialDraft.fontSize;
    }

    final nextText = widget.initialDraft.text;
    if (nextText != _textController.text &&
        nextText != oldWidget.initialDraft.text) {
      _textController.value = _textController.value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
        composing: TextRange.empty,
      );
    }

    if (!_sameParameterValues(_parameters, widget.initialDraft.parameters)) {
      _parameters = List<TextClipEditableParameter>.from(
        widget.initialDraft.parameters,
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _replaceLocalDraft(TextClipEditDraft draft) {
    _textController.value = TextEditingValue(
      text: draft.text,
      selection: TextSelection.collapsed(offset: draft.text.length),
    );
    _fontSize = draft.fontSize;
    _parameters = List<TextClipEditableParameter>.from(draft.parameters);
    _error = null;
  }

  bool _sameParameterValues(
    List<TextClipEditableParameter> left,
    List<TextClipEditableParameter> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id ||
          (left[i].value - right[i].value).abs() > 0.001) {
        return false;
      }
    }
    return true;
  }

  TextClipEditDraft get _draft => widget.initialDraft.copyWith(
        text: _textController.text,
        fontSize: _fontSize,
        parameters: _parameters,
      );

  void _emitDraftChanged() {
    widget.onDraftChanged(_draft);
  }

  void _submit() {
    final trimmedText = _textController.text.trim();
    if (trimmedText.isEmpty) {
      setState(() {
        _error = 'Required';
      });
      return;
    }

    final nextDraft = _draft.copyWith(text: trimmedText);
    widget.onDraftChanged(nextDraft);
    widget.onDone(nextDraft);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.5;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: sheetHeight + bottomInset + safeBottom,
          padding: EdgeInsets.only(bottom: bottomInset + safeBottom),
          decoration: BoxDecoration(
            color: FxPalette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: FxPalette.divider, width: 1),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: FxPalette.textFaint,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      'Edit Text',
                      style: TextStyle(
                        color: FxPalette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      _CompactTextCard(
                        textController: _textController,
                        error: _error,
                        onChanged: (_) {
                          if (_error != null) {
                            setState(() {
                              _error = null;
                            });
                          }
                          _emitDraftChanged();
                        },
                      ),
                      const SizedBox(height: 10),
                      _CompactSliderCard(
                        label: 'Size',
                        value: _fontSize,
                        minValue: 12,
                        maxValue: 180,
                        displayValue: '${_fontSize.round()}',
                        onChanged: (value) {
                          setState(() {
                            _fontSize = value;
                          });
                          _emitDraftChanged();
                        },
                      ),
                      for (var i = 0; i < _parameters.length; i++) ...[
                        const SizedBox(height: 10),
                        _CompactSliderCard(
                          label: _shortParameterLabel(_parameters[i].label),
                          value: _parameters[i].value,
                          minValue: _parameters[i].minValue,
                          maxValue: _parameters[i].maxValue,
                          displayValue:
                              _formatParameterValue(_parameters[i].value),
                          onChanged: (value) {
                            setState(() {
                              _parameters =
                                  List<TextClipEditableParameter>.from(
                                _parameters,
                              );
                              _parameters[i] =
                                  _parameters[i].copyWith(value: value);
                            });
                            _emitDraftChanged();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FxPalette.textPrimary,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 54,
                      child: OutlinedButton(
                        onPressed: widget.isPlayPreviewEnabled
                            ? widget.onPlayPreview
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FxPalette.textPrimary,
                          side: BorderSide(
                            color: widget.isPlayPreviewEnabled
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white.withOpacity(0.04),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Icon(
                          widget.isPreviewPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FxPalette.accent,
                          foregroundColor: FxPalette.background,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w700),
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

  String _shortParameterLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.contains('blur')) {
      return 'Blur';
    }
    if (normalized.contains('spacing')) {
      return 'Spacing';
    }
    if (normalized.contains('speed')) {
      return 'Speed';
    }
    return label.trim();
  }

  String _formatParameterValue(double value) {
    final rounded = value.roundToDouble();
    if ((rounded - value).abs() < 0.001) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _CompactTextCard extends StatelessWidget {
  const _CompactTextCard({
    required this.textController,
    required this.onChanged,
    this.error,
  });

  final TextEditingController textController;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return _CompactCardFrame(
      label: 'Text',
      child: TextField(
        controller: textController,
        maxLines: 2,
        style: const TextStyle(
          color: FxPalette.textPrimary,
          fontSize: 13,
          height: 1.15,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Type',
          hintStyle: const TextStyle(
            color: FxPalette.textFaint,
            fontSize: 13,
          ),
          errorText: error,
          errorStyle: const TextStyle(fontSize: 10),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _CompactSliderCard extends StatelessWidget {
  const _CompactSliderCard({
    required this.label,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double minValue;
  final double maxValue;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CompactCardFrame(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: FxPalette.accent,
                inactiveTrackColor: Colors.white.withOpacity(0.08),
                thumbColor: FxPalette.accent,
                overlayColor: Colors.transparent,
                trackHeight: 2.2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
              ),
              child: Slider(
                value: value.clamp(minValue, maxValue),
                min: minValue,
                max: maxValue,
                onChanged: onChanged,
              ),
            ),
          ),
          Container(
            width: 42,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 0.7,
              ),
            ),
            child: Text(
              displayValue,
              style: const TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCardFrame extends StatelessWidget {
  const _CompactCardFrame({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.055),
          width: 0.8,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: -12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: FxPalette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 0.7,
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: FxPalette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
