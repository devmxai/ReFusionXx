import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_normal_transition_models.dart';
import '../../domain/services/normal_transition_script_import_service.dart';

class TransitionScriptImportBottomSheet extends StatefulWidget {
  const TransitionScriptImportBottomSheet({super.key});

  @override
  State<TransitionScriptImportBottomSheet> createState() =>
      _TransitionScriptImportBottomSheetState();
}

class _TransitionScriptImportBottomSheetState
    extends State<TransitionScriptImportBottomSheet> {
  static const String _sampleScript = '''
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "custom_black_blur_mix",
  "name": "Custom Black Blur Mix",
  "rendererType": "primitive",
  "category": "custom",
  "defaultDurationMs": 900,
  "parameters": [
    { "name": "intensity", "type": "number", "default": 1, "range": [0, 1] }
  ],
  "channels": [
    {
      "target": "transition",
      "property": "blackPeak",
      "keyframes": [
        { "t": 0, "value": 0, "easing": "easeInOut" },
        { "t": 0.42, "value": 100, "easing": "easeInOut" },
        { "t": 0.58, "value": 100, "easing": "easeInOut" },
        { "t": 1, "value": 0, "easing": "easeInOut" }
      ]
    },
    {
      "target": "transition",
      "property": "blurAmount",
      "keyframes": [
        { "t": 0, "value": 0, "easing": "easeOut" },
        { "t": 0.5, "value": 12, "easing": "easeInOut" },
        { "t": 1, "value": 0, "easing": "easeIn" }
      ]
    },
    {
      "target": "to",
      "property": "opacity",
      "keyframes": [
        { "t": 0, "value": 0, "easing": "easeOut" },
        { "t": 1, "value": 1, "easing": "easeOut" }
      ]
    }
  ]
}
''';

  final NormalTransitionScriptImportService _importService =
      const NormalTransitionScriptImportService();
  late final TextEditingController _controller;
  NormalTransitionScriptImportResult? _validation;
  String? _fileName;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _sampleScript);
    _validation = _importService.validate(source: _sampleScript);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    setState(() {
      _validation = _importService.validate(
        source: _controller.text,
        fileName: _fileName,
      );
    });
  }

  Future<void> _uploadScript() async {
    setState(() {
      _isUploading = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: const <String>['json'],
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _validation = const NormalTransitionScriptImportResult(
            issues: <NormalTransitionIssue>[
              NormalTransitionIssue(
                severity: NormalTransitionIssueSeverity.error,
                message: 'Unable to read the selected transition script.',
                path: 'source',
              ),
            ],
          );
        });
        return;
      }
      final source = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        _fileName = file.name;
        _controller.text = source;
        _validation = _importService.validate(
          source: source,
          fileName: file.name,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _apply() {
    final validation = _importService.validate(
      source: _controller.text,
      fileName: _fileName,
    );
    setState(() {
      _validation = validation;
    });
    if (!validation.canImport || validation.definition == null) {
      return;
    }
    Navigator.of(context).pop(validation.definition);
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    final canApply = validation?.canImport ?? false;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.76).clamp(460.0, 760.0);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight + viewInsets,
        padding: EdgeInsets.only(bottom: viewInsets),
        decoration: BoxDecoration(
          color: FxPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: FxPalette.divider, width: 1),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  children: [
                    const SizedBox(width: 36),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: FxPalette.textFaint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: canApply ? _apply : null,
                      icon: Icon(
                        Icons.check_rounded,
                        color: canApply
                            ? FxPalette.textPrimary
                            : FxPalette.textMuted.withOpacity(0.38),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Transition Script',
                        style: TextStyle(
                          color: FxPalette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _TopActionButton(
                      icon: _isUploading ? null : Icons.upload_file_rounded,
                      label: _isUploading ? 'Loading' : 'Upload',
                      onTap: _isUploading ? null : _uploadScript,
                    ),
                    const SizedBox(width: 8),
                    _TopActionButton(
                      icon: Icons.rule_rounded,
                      label: 'Validate',
                      onTap: _validate,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _fileName == null
                        ? 'Paste declarative JSON. It will become editable transition keyframes.'
                        : 'Loaded $_fileName',
                    style: const TextStyle(
                      color: FxPalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: FxPalette.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.18),
                      hintText: 'Paste transition JSON here',
                      hintStyle: const TextStyle(color: FxPalette.textFaint),
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: FxPalette.divider.withOpacity(0.75),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: FxPalette.accent,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _ValidationStrip(validation: validation),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FxPalette.divider, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                icon,
                color: enabled ? FxPalette.textPrimary : FxPalette.textFaint,
                size: 16,
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? FxPalette.textPrimary : FxPalette.textFaint,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationStrip extends StatelessWidget {
  const _ValidationStrip({required this.validation});

  final NormalTransitionScriptImportResult? validation;

  @override
  Widget build(BuildContext context) {
    final issues = validation?.issues ?? const <NormalTransitionIssue>[];
    final canImport = validation?.canImport ?? false;
    final statusText = canImport
        ? 'Ready: ${validation!.definition!.channels.length} channels'
        : issues.isEmpty
            ? 'Validate the script before importing.'
            : issues.first.message;
    final statusColor = canImport
        ? FxPalette.accent
        : issues.any(
            (issue) => issue.severity == NormalTransitionIssueSeverity.error,
          )
            ? FxPalette.danger
            : FxPalette.textMuted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FxPalette.divider, width: 1),
      ),
      child: Text(
        statusText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
