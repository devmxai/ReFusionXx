import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/services/scoped_text_motion_script_import_service.dart';

class ScopedTextMotionScriptBottomSheet extends StatefulWidget {
  const ScopedTextMotionScriptBottomSheet({super.key});

  @override
  State<ScopedTextMotionScriptBottomSheet> createState() =>
      _ScopedTextMotionScriptBottomSheetState();
}

class _ScopedTextMotionScriptBottomSheetState
    extends State<ScopedTextMotionScriptBottomSheet> {
  static const String _scriptGuidePath = 'docs/scoped_text_motion_script_v1.md';

  final ScopedTextMotionScriptImportService _importService =
      const ScopedTextMotionScriptImportService();
  late final TextEditingController _controller;
  String? _fileName;
  ScopedTextMotionScriptValidationResult? _validation;
  bool _isUploading = false;

  static const String _sampleScript = '''
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Pop Bounce In",
  "channels": [
    {
      "property": "opacity",
      "keyframes": [
        { "timeMs": 0, "value": 0, "easing": "linear" },
        { "timeMs": 220, "value": 100, "easing": "easeOut" }
      ]
    },
    {
      "property": "scale",
      "keyframes": [
        { "timeMs": 0, "value": 74, "easing": "easeOut" },
        { "timeMs": 360, "value": 116, "easing": "easeOut" },
        { "timeMs": 760, "value": 100, "easing": "easyEase" }
      ]
    },
    {
      "property": "positionY",
      "keyframes": [
        { "timeMs": 0, "value": 46, "easing": "easeOut" },
        { "timeMs": 760, "value": 0, "easing": "easyEase" }
      ]
    }
  ]
}
''';

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
        source: _controller.text.trim(),
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
        allowedExtensions: const <String>[
          'json',
          'yaml',
          'yml',
          'jsx',
          'js',
          'tsx',
          'ts',
        ],
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _validation = const ScopedTextMotionScriptValidationResult(
            format: ScopedTextMotionScriptFormat.unknown,
            issues: <ScopedTextMotionScriptIssue>[
              ScopedTextMotionScriptIssue(
                severity: ScopedTextMotionScriptIssueSeverity.error,
                message: 'Unable to read the selected file.',
                path: 'source',
              ),
            ],
          );
        });
        return;
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        _fileName = file.name;
        _controller.text = text;
        _validation = _importService.validate(
          source: text.trim(),
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
      source: _controller.text.trim(),
      fileName: _fileName,
    );
    setState(() {
      _validation = validation;
    });
    if (!validation.canApply || validation.document == null) {
      return;
    }
    Navigator.of(context).pop(validation.document);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.78).clamp(460.0, 760.0);
    final validation = _validation;
    final canApply = validation?.canApply ?? false;
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
                      onPressed: canApply ? _apply : null,
                      icon: Icon(
                        Icons.check_rounded,
                        color: canApply
                            ? FxPalette.textPrimary
                            : FxPalette.textMuted.withOpacity(0.4),
                        size: 20,
                      ),
                      splashRadius: 18,
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
                        'Add Script',
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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _fileName == null
                        ? 'Target: current scoped text layer'
                        : 'File: $_fileName',
                    style: const TextStyle(
                      color: FxPalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Use canonical JSON or YAML. Target IDs are not required. The script is applied to the currently opened scoped text layer. Guide: $_scriptGuidePath',
                    style: TextStyle(
                      color: FxPalette.textFaint,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    (safeBottom > 0 ? safeBottom : 12) + 12,
                  ),
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 240),
                      decoration: BoxDecoration(
                        color: FxPalette.surfaceRaised.withOpacity(0.84),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: FxPalette.dividerSoft),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: TextField(
                        controller: _controller,
                        onChanged: (_) {
                          setState(() {
                            _validation = null;
                          });
                        },
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: null,
                        minLines: 14,
                        style: const TextStyle(
                          color: FxPalette.textPrimary,
                          fontSize: 13,
                          height: 1.45,
                          fontFamily: 'monospace',
                        ),
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Paste your motion script here...',
                          hintStyle: TextStyle(
                            color: FxPalette.textFaint,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ValidationCard(validation: validation),
                  ],
                ),
              ),
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

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(onTap == null ? 0.04 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FxPalette.dividerSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: onTap == null
                    ? FxPalette.textMuted.withOpacity(0.5)
                    : FxPalette.textPrimary,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: onTap == null
                    ? FxPalette.textMuted.withOpacity(0.5)
                    : FxPalette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({
    required this.validation,
  });

  final ScopedTextMotionScriptValidationResult? validation;

  @override
  Widget build(BuildContext context) {
    final validation = this.validation;
    final issues = validation?.issues ?? const <ScopedTextMotionScriptIssue>[];
    final hasValidation = validation != null;
    final canApply = validation?.canApply ?? false;
    final statusColor = canApply
        ? const Color(0xFF5AD1C8)
        : issues.any(
            (issue) =>
                issue.severity == ScopedTextMotionScriptIssueSeverity.error,
          )
            ? const Color(0xFFFF7D7D)
            : FxPalette.textMuted;
    final statusText = !hasValidation
        ? 'Validation has not been run yet.'
        : canApply
            ? 'Script is valid and ready to apply.'
            : 'Script needs fixes before it can be applied.';
    return Container(
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FxPalette.dividerSoft),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: canApply ? FxPalette.textPrimary : statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (validation != null) ...[
            const SizedBox(height: 10),
            Text(
              'Detected ${validation.channelCount} channel row(s) and ${validation.animationBlockCount} animation block(s).',
              style: const TextStyle(
                color: FxPalette.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '- ${issue.message}',
                  style: TextStyle(
                    color: switch (issue.severity) {
                      ScopedTextMotionScriptIssueSeverity.error =>
                        const Color(0xFFFF9A9A),
                      ScopedTextMotionScriptIssueSeverity.warning =>
                        const Color(0xFFFFD27A),
                      ScopedTextMotionScriptIssueSeverity.info =>
                        FxPalette.textMuted,
                    },
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: issue.severity ==
                            ScopedTextMotionScriptIssueSeverity.error
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
