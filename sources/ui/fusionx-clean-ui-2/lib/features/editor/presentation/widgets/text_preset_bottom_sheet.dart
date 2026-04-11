import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_text_models.dart';
import '../../domain/models/professional_motion_text_preset_serialization.dart';

typedef MotionTextPresetImportHandler =
    Future<void> Function(MotionTextPresetDefinition preset);

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

  @override
  void initState() {
    super.initState();
    _customPresets = List<MotionTextPresetDefinition>.from(widget.customPresets);
  }

  List<MotionTextPresetDefinition> get _allPresets => <MotionTextPresetDefinition>[
    ...widget.builtInPresets,
    ..._customPresets,
  ];

  Future<void> _handleAddPreset() async {
    final importedPreset = await showModalBottomSheet<MotionTextPresetDefinition>(
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
          content: Text('Preset id `${importedPreset.id}` already exists.'),
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
    final sheetHeight = MediaQuery.of(context).size.height * 0.5;
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Text(
                    'Text Presets',
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
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.06,
                ),
                itemCount: _allPresets.length + 1,
                itemBuilder: (context, index) {
                  if (index == _allPresets.length) {
                    return _AddPresetCard(onTap: _handleAddPreset);
                  }
                  final preset = _allPresets[index];
                  final isCustom = _customPresets.any(
                    (candidate) => candidate.id == preset.id,
                  );
                  return _TextPresetGridCard(
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

class _TextPresetGridCard extends StatelessWidget {
  const _TextPresetGridCard({
    required this.preset,
    required this.isCustom,
  });

  final MotionTextPresetDefinition preset;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.of(context).pop(preset),
      child: Ink(
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  preset.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: FxPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            if (isCustom)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FxPalette.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Custom',
                    style: TextStyle(
                      color: FxPalette.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddPresetCard extends StatelessWidget {
  const _AddPresetCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: FxPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: FxPalette.accent.withOpacity(0.28),
            width: 1.2,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: FxPalette.textPrimary,
              size: 28,
            ),
            SizedBox(height: 10),
            Text(
              'Add Preset',
              style: TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        _error = 'Unable to parse preset JSON.';
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
                    'Add Preset',
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
                'Paste full preset JSON or a simpler motion-only JSON. The app can auto-generate id, kind, label, and defaultText when they are omitted.',
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
                      child: const Text('Add'),
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
