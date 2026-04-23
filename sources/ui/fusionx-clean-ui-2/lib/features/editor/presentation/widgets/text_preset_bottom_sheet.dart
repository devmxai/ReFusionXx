import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_text_models.dart';
import '../../domain/models/professional_motion_text_preset_serialization.dart';

typedef MotionTextPresetImportHandler = Future<void> Function(
    MotionTextPresetDefinition preset);

class TextPresetBottomSheet extends StatefulWidget {
  const TextPresetBottomSheet({
    super.key,
    required this.builtInPresets,
    this.customPresets = const <MotionTextPresetDefinition>[],
    this.onPresetImported,
  });

  final List<MotionTextPresetDefinition> builtInPresets;
  final List<MotionTextPresetDefinition> customPresets;
  final MotionTextPresetImportHandler? onPresetImported;

  @override
  State<TextPresetBottomSheet> createState() => _TextPresetBottomSheetState();
}

class _TextPresetBottomSheetState extends State<TextPresetBottomSheet> {
  late List<MotionTextPresetDefinition> _customPresets;
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _customPresets =
        List<MotionTextPresetDefinition>.from(widget.customPresets);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MotionTextPresetDefinition> get _allPresets =>
      <MotionTextPresetDefinition>[
        ...widget.builtInPresets,
        ..._customPresets,
      ];

  List<MotionTextPresetDefinition> get _filteredPresets {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _allPresets;
    }
    return _allPresets.where((preset) {
      final searchable = <String>[
        preset.label,
        preset.description ?? '',
        preset.defaultText,
        _effectFamilyLabel(preset),
        ...preset.animationBlocks.map((block) => block.kind.name),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList(growable: false);
  }

  Future<void> _handleAddPreset() async {
    final importedPreset =
        await showModalBottomSheet<MotionTextPresetDefinition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTextPresetSheet(),
    );
    if (!mounted || importedPreset == null) {
      return;
    }

    if (_allPresets.any((preset) => preset.id == importedPreset.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Text effect id `${importedPreset.id}` already exists.',
          ),
        ),
      );
      return;
    }

    await widget.onPresetImported?.call(importedPreset);
    if (!mounted) {
      return;
    }
    setState(() {
      _customPresets = <MotionTextPresetDefinition>[
        ..._customPresets,
        importedPreset,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.68;
    final filteredPresets = _filteredPresets;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Text Effects',
                          style: TextStyle(
                            color: FxPalette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Choose a real text motion effect.',
                          style: TextStyle(
                            color: FxPalette.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Import effect',
                    onPressed: _handleAddPreset,
                    icon: const Icon(
                      Icons.add_rounded,
                      color: FxPalette.textPrimary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TextEffectSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: filteredPresets.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == filteredPresets.length) {
                    return _ImportTextEffectCard(onTap: _handleAddPreset);
                  }
                  final preset = filteredPresets[index];
                  final isCustom = _customPresets.any(
                    (candidate) => candidate.id == preset.id,
                  );
                  return _TextEffectListCard(
                    preset: preset,
                    isCustom: isCustom,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextEffectSearchField extends StatelessWidget {
  const _TextEffectSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: FxPalette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: FxPalette.surfaceRaised,
          hintText: 'Search text effects',
          hintStyle: const TextStyle(
            color: FxPalette.textFaint,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: FxPalette.textMuted,
            size: 20,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: FxPalette.textMuted,
                    size: 18,
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: FxPalette.accent,
              width: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextEffectListCard extends StatelessWidget {
  const _TextEffectListCard({
    required this.preset,
    required this.isCustom,
  });

  final MotionTextPresetDefinition preset;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).pop(preset),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          children: [
            _TextEffectIcon(preset: preset),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preset.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FxPalette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 8),
                        const _TextEffectBadge(label: 'Custom'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    preset.description ?? 'Generated text motion effect.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FxPalette.textMuted,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _TextEffectBadge(label: _effectFamilyLabel(preset)),
                      for (final label in _effectBlockLabels(preset))
                        _TextEffectBadge(label: label, muted: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: FxPalette.textPrimary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextEffectIcon extends StatelessWidget {
  const _TextEffectIcon({required this.preset});

  final MotionTextPresetDefinition preset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: FxPalette.accent.withOpacity(0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FxPalette.accent.withOpacity(0.18)),
      ),
      child: Icon(
        _iconForPreset(preset),
        color: FxPalette.textPrimary,
        size: 23,
      ),
    );
  }
}

class _TextEffectBadge extends StatelessWidget {
  const _TextEffectBadge({
    required this.label,
    this.muted = false,
  });

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: muted
            ? Colors.white.withOpacity(0.045)
            : FxPalette.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: muted
              ? Colors.white.withOpacity(0.05)
              : FxPalette.accent.withOpacity(0.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? FxPalette.textMuted : FxPalette.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImportTextEffectCard extends StatelessWidget {
  const _ImportTextEffectCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: FxPalette.accent.withOpacity(0.28),
            width: 1.2,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.add_rounded,
              color: FxPalette.textPrimary,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Import Text Effect',
                style: TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: FxPalette.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

String _effectFamilyLabel(MotionTextPresetDefinition preset) {
  if (preset.animationBlocks.any(
    (block) => block.kind == MotionTextAnimationKind.typewriter,
  )) {
    return 'Type On';
  }
  if (preset.animationBlocks.any(
    (block) =>
        block.kind == MotionTextAnimationKind.wordReveal ||
        block.revealSpec?.unit == MotionTextRevealUnit.word,
  )) {
    return 'Word Reveal';
  }
  if (preset.animationBlocks.any(
    (block) =>
        block.kind == MotionTextAnimationKind.letterReveal ||
        block.revealSpec?.unit == MotionTextRevealUnit.letter,
  )) {
    return 'Letter Reveal';
  }
  if (preset.animationBlocks.any(
    (block) =>
        block.kind == MotionTextAnimationKind.blurIn ||
        block.kind == MotionTextAnimationKind.cinematicEntrance,
  )) {
    return 'Cinematic';
  }
  if (preset.animationBlocks.any(
    (block) => block.kind == MotionTextAnimationKind.bounceIn,
  )) {
    return 'Bounce In';
  }
  return 'Text Motion';
}

List<String> _effectBlockLabels(MotionTextPresetDefinition preset) {
  final labels = <String>[];
  for (final block in preset.animationBlocks) {
    final label = switch (block.kind) {
      MotionTextAnimationKind.fadeIn ||
      MotionTextAnimationKind.fadeOut =>
        'Fade',
      MotionTextAnimationKind.wordReveal => 'Words',
      MotionTextAnimationKind.letterReveal => 'Letters',
      MotionTextAnimationKind.typewriter => 'Type',
      MotionTextAnimationKind.bounceIn => 'Bounce',
      MotionTextAnimationKind.elasticPop => 'Pop',
      MotionTextAnimationKind.scaleIn ||
      MotionTextAnimationKind.scaleOut =>
        'Scale',
      MotionTextAnimationKind.blurIn ||
      MotionTextAnimationKind.blurOut =>
        'Blur',
      MotionTextAnimationKind.rotationSettle => 'Settle',
      MotionTextAnimationKind.cinematicEntrance ||
      MotionTextAnimationKind.cinematicExit =>
        'Cinematic',
    };
    if (!labels.contains(label)) {
      labels.add(label);
    }
    if (labels.length >= 3) {
      break;
    }
  }
  return labels;
}

IconData _iconForPreset(MotionTextPresetDefinition preset) {
  final family = _effectFamilyLabel(preset);
  if (family == 'Type On') {
    return Icons.keyboard_rounded;
  }
  if (family == 'Word Reveal' || family == 'Letter Reveal') {
    return Icons.text_fields_rounded;
  }
  if (family == 'Cinematic') {
    return Icons.auto_awesome_motion_rounded;
  }
  return Icons.auto_awesome_rounded;
}

class _AddTextPresetSheet extends StatefulWidget {
  const _AddTextPresetSheet();

  @override
  State<_AddTextPresetSheet> createState() => _AddTextPresetSheetState();
}

class _AddTextPresetSheetState extends State<_AddTextPresetSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _samplePresetJson);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final preset = MotionTextPresetJsonCodec.parsePresetString(
        _controller.text.trim(),
      );
      Navigator.of(context).pop(preset);
    } on MotionTextPresetJsonException catch (error) {
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to parse text effect JSON.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.72;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight + bottomInset,
        padding: EdgeInsets.only(bottom: bottomInset),
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
                    'Import Text Effect',
                    style: TextStyle(
                      color: FxPalette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Paste full text-effect JSON or a simpler motion-only JSON. The app can auto-generate id, kind, label, and defaultText when they are omitted.',
                style: TextStyle(
                  color: FxPalette.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Minimal supported shape: {"text":"Your Text","animationBlocks":[{"kind":"fadeIn","startMs":0,"durationMs":700}]}\nSupported kinds: fadeIn, fadeOut, wordReveal, letterReveal, typewriter, elasticPop, scaleIn, scaleOut, blurIn, blurOut, rotationSettle, cinematicEntrance, cinematicExit',
                style: TextStyle(
                  color: FxPalette.textFaint,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  style: const TextStyle(
                    color: FxPalette.textPrimary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: FxPalette.surfaceRaised,
                    hintText: _samplePresetJson,
                    hintStyle: const TextStyle(
                      color: FxPalette.textFaint,
                      fontSize: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: FxPalette.accent,
                        width: 1.1,
                      ),
                    ),
                    errorText: _error,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FxPalette.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Import'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const String _samplePresetJson = '''
{
  "text": "Your Text Here",
  "animationBlocks": [
    {
      "kind": "fadeIn",
      "startMs": 0,
      "durationMs": 320,
      "interpolation": "easeOut"
    },
    {
      "kind": "blurIn",
      "startMs": 0,
      "durationMs": 700,
      "interpolation": "easeOut",
      "parameters": {
        "fromBlur": 16,
        "toBlur": 0
      }
    },
    {
      "kind": "scaleIn",
      "startMs": 0,
      "durationMs": 820,
      "interpolation": "easeOut",
      "parameters": {
        "fromScale": 1.12,
        "toScale": 1.0
      }
    }
  ]
}
''';
