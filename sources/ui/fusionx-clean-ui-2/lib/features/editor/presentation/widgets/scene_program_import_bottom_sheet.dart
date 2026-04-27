import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/models/refusion_scene_program_models.dart';
import '../../domain/services/refusion_scene_program_authoring_service.dart';

class SceneProgramImportBottomSheet extends StatefulWidget {
  const SceneProgramImportBottomSheet({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.canvasSize,
  });

  final String projectId;
  final String sceneId;
  final MotionSize2D canvasSize;

  @override
  State<SceneProgramImportBottomSheet> createState() =>
      _SceneProgramImportBottomSheetState();
}

class SceneProgramImportSheetResult {
  const SceneProgramImportSheetResult({
    required this.name,
    required this.layerCount,
    required this.channelCount,
    required this.warningCount,
    required this.project,
    required this.channels,
  });

  factory SceneProgramImportSheetResult.fromAuthoringResult(
    ReFusionSceneProgramAuthoringResult result,
  ) {
    final scenes = result.project?.scenes ?? const [];
    final scene = scenes.length == 1 ? scenes.single : null;
    final warningCount = result.issues
        .where(
          (issue) =>
              issue.severity == ReFusionSceneProgramIssueSeverity.warning,
        )
        .length;
    return SceneProgramImportSheetResult(
      name: result.program?.name ?? 'Scene Program',
      layerCount: scene?.layers.length ?? 0,
      channelCount: result.channels.length,
      warningCount: warningCount,
      project: result.project!,
      channels: result.channels,
    );
  }

  final String name;
  final int layerCount;
  final int channelCount;
  final int warningCount;
  final MotionProjectModel project;
  final List<MotionPropertyChannelModel> channels;
}

class _SceneProgramImportBottomSheetState
    extends State<SceneProgramImportBottomSheet> {
  final ReFusionSceneProgramAuthoringService _authoringService =
      const ReFusionSceneProgramAuthoringService();
  late final TextEditingController _controller;
  String? _fileName;
  ReFusionSceneProgramAuthoringResult? _result;
  bool _isUploading = false;

  static const String _basicSceneProgram = '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "First Generated Scene",
  "durationMs": 3000,
  "frameRate": 30,
  "layers": [
    {
      "id": "background-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3000,
      "elements": [
        {
          "id": "background-solid",
          "kind": "solid",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#101820",
            "opacity": 1
          }
        }
      ]
    },
    {
      "id": "title-layer",
      "kind": "text",
      "startMs": 300,
      "durationMs": 2100,
      "elements": [
        {
          "id": "hero-title",
          "kind": "text",
          "text": "ReFusion",
          "properties": {
            "fontSize": 118,
            "color": "#FFFFFF"
          },
          "channels": [
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 0, "value": { "x": 0, "y": 120 }, "easing": "spring" },
                { "timeMs": 720, "value": { "x": 0, "y": 0 }, "easing": "easeOut" }
              ]
            },
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "easeOut" },
                { "timeMs": 420, "value": 1.0, "easing": "linear" },
                { "timeMs": 2100, "value": 0.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

  static const String _shapeTextWipeSceneProgram = '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Shape Text Wipe Demo",
  "durationMs": 5200,
  "frameRate": 30,
  "layers": [
    {
      "id": "midnight-bg-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 5200,
      "elements": [
        {
          "id": "midnight-bg",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#0B1020",
            "opacity": 1
          }
        }
      ]
    },
    {
      "id": "first-word-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 5200,
      "elements": [
        {
          "id": "first-word",
          "kind": "text",
          "text": "MOTION",
          "properties": {
            "fontSize": 128,
            "color": "#FFFFFF",
            "opacity": 0
          },
          "channels": [
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 0, "value": { "x": -18, "y": 0 }, "easing": "easeOut" },
                { "timeMs": 1200, "value": { "x": -6, "y": 0 }, "easing": "easeOut" },
                { "timeMs": 2400, "value": { "x": 24, "y": 0 }, "easing": "easeIn" },
                { "timeMs": 3000, "value": { "x": 24, "y": 0 }, "easing": "linear" },
                { "timeMs": 3600, "value": { "x": 46, "y": 0 }, "easing": "easeIn" }
              ]
            },
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 850, "value": 0.0, "easing": "easeOut" },
                { "timeMs": 1280, "value": 1.0, "easing": "easeOut" },
                { "timeMs": 2850, "value": 1.0, "easing": "linear" },
                { "timeMs": 3450, "value": 0.0, "easing": "easeIn" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 0, "value": 0.96, "easing": "linear" },
                { "timeMs": 1280, "value": 1.0, "easing": "easeOut" },
                { "timeMs": 3450, "value": 0.98, "easing": "easeIn" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "second-word-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 5200,
      "elements": [
        {
          "id": "second-word",
          "kind": "text",
          "text": "GRAPHICS",
          "properties": {
            "fontSize": 108,
            "color": "#101820",
            "opacity": 0
          },
          "channels": [
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 0, "value": { "x": -32, "y": 150 }, "easing": "linear" },
                { "timeMs": 3250, "value": { "x": -32, "y": 150 }, "easing": "easeOut" },
                { "timeMs": 3860, "value": { "x": 0, "y": 150 }, "easing": "easeOut" },
                { "timeMs": 4550, "value": { "x": 0, "y": 150 }, "easing": "linear" }
              ]
            },
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 3200, "value": 0.0, "easing": "easeOut" },
                { "timeMs": 3820, "value": 1.0, "easing": "easeOut" },
                { "timeMs": 4700, "value": 1.0, "easing": "linear" },
                { "timeMs": 5200, "value": 0.0, "easing": "easeIn" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 0, "value": 0.92, "easing": "linear" },
                { "timeMs": 3820, "value": 1.0, "easing": "easeOut" },
                { "timeMs": 4700, "value": 1.04, "easing": "easeIn" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "wipe-circle-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 5200,
      "elements": [
        {
          "id": "wipe-circle",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 330,
            "height": 330,
            "color": "#FFFFFF",
            "opacity": 1
          },
          "channels": [
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 0, "value": { "x": -460, "y": 0 }, "easing": "easeOut" },
                { "timeMs": 720, "value": { "x": 360, "y": 0 }, "easing": "spring" },
                { "timeMs": 1680, "value": { "x": -360, "y": 0 }, "easing": "easeInOut" },
                { "timeMs": 3050, "value": { "x": -360, "y": 0 }, "easing": "linear" },
                { "timeMs": 3650, "value": { "x": 410, "y": 0 }, "easing": "easeOut" },
                { "timeMs": 4550, "value": { "x": 0, "y": 0 }, "easing": "easeInOut" },
                { "timeMs": 5200, "value": { "x": 0, "y": 0 }, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 0, "value": 0.78, "easing": "easeOut" },
                { "timeMs": 720, "value": 1.0, "easing": "spring" },
                { "timeMs": 1680, "value": 0.86, "easing": "easeInOut" },
                { "timeMs": 3650, "value": 1.05, "easing": "easeOut" },
                { "timeMs": 4550, "value": 1.18, "easing": "easeInOut" },
                { "timeMs": 5200, "value": 7.8, "easing": "easeIn" }
              ]
            },
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 1.0, "easing": "linear" },
                { "timeMs": 5000, "value": 1.0, "easing": "linear" },
                { "timeMs": 5200, "value": 1.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "white-finish-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 5200,
      "elements": [
        {
          "id": "white-finish",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#FFFFFF",
            "opacity": 0
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 4720, "value": 0.0, "easing": "linear" },
                { "timeMs": 5200, "value": 1.0, "easing": "easeIn" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _shapeTextWipeSceneProgram);
    _result = _importCurrentSource(_shapeTextWipeSceneProgram);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ReFusionSceneProgramAuthoringResult _importCurrentSource(String source) {
    return _authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: source.trim(),
        fileName: _fileName,
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        canvasSize: widget.canvasSize,
      ),
    );
  }

  void _validate() {
    setState(() {
      _result = _importCurrentSource(_controller.text);
    });
  }

  void _loadPreset(String source) {
    setState(() {
      _fileName = null;
      _controller.text = source;
      _result = _importCurrentSource(source);
    });
  }

  Future<void> _uploadSceneProgram() async {
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
          _fileName = file.name;
          _result = ReFusionSceneProgramAuthoringResult(
            issues: const <ReFusionSceneProgramIssue>[
              ReFusionSceneProgramIssue(
                severity: ReFusionSceneProgramIssueSeverity.error,
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
        _result = _importCurrentSource(text);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _done() {
    final result = _importCurrentSource(_controller.text);
    setState(() {
      _result = result;
    });
    if (!result.isValid) {
      return;
    }
    Navigator.of(context).pop(
      SceneProgramImportSheetResult.fromAuthoringResult(result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.82).clamp(500.0, 780.0);
    final result = _result;
    final isValid = result?.isValid ?? false;
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
                      onPressed: isValid ? _done : null,
                      icon: Icon(
                        Icons.check_rounded,
                        color: isValid
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
                        'Import Scene Program',
                        style: TextStyle(
                          color: FxPalette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _SceneProgramActionButton(
                      icon: _isUploading ? null : Icons.upload_file_rounded,
                      label: _isUploading ? 'Loading' : 'Upload',
                      onTap: _isUploading ? null : _uploadSceneProgram,
                    ),
                    const SizedBox(width: 8),
                    _SceneProgramActionButton(
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
                        ? 'JSON only. Validate, then tap the check mark to apply editable scene layers.'
                        : 'File: $_fileName',
                    style: const TextStyle(
                      color: FxPalette.textMuted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SceneProgramActionButton(
                        icon: Icons.auto_awesome_motion_rounded,
                        label: 'Shape Text Wipe',
                        onTap: () => _loadPreset(_shapeTextWipeSceneProgram),
                      ),
                      _SceneProgramActionButton(
                        icon: Icons.text_fields_rounded,
                        label: 'Basic Text',
                        onTap: () => _loadPreset(_basicSceneProgram),
                      ),
                    ],
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
                      constraints: const BoxConstraints(minHeight: 260),
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
                            _result = null;
                          });
                        },
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: null,
                        minLines: 15,
                        style: const TextStyle(
                          color: FxPalette.textPrimary,
                          fontSize: 13,
                          height: 1.45,
                          fontFamily: 'monospace',
                        ),
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Paste a ReFusion Scene Program JSON...',
                          hintStyle: TextStyle(
                            color: FxPalette.textFaint,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SceneProgramResultCard(result: result),
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

class _SceneProgramActionButton extends StatelessWidget {
  const _SceneProgramActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

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

class _SceneProgramResultCard extends StatelessWidget {
  const _SceneProgramResultCard({required this.result});

  final ReFusionSceneProgramAuthoringResult? result;

  @override
  Widget build(BuildContext context) {
    final value = result;
    if (value == null) {
      return const _SceneProgramInfoCard(
        icon: Icons.pending_actions_rounded,
        title: 'Waiting for validation',
        message: 'Tap Validate to inspect the JSON before applying anything.',
      );
    }
    final errors = value.issues
        .where(
          (issue) => issue.severity == ReFusionSceneProgramIssueSeverity.error,
        )
        .toList(growable: false);
    if (errors.isNotEmpty) {
      return _SceneProgramIssueList(
        icon: Icons.error_outline_rounded,
        title: 'Scene program rejected',
        issues: errors,
        accent: const Color(0xFFFF6B6B),
      );
    }
    final warnings = value.issues
        .where(
          (issue) =>
              issue.severity == ReFusionSceneProgramIssueSeverity.warning,
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SceneProgramInfoCard(
          icon: Icons.verified_rounded,
          title: value.hasWarnings ? 'Valid with warnings' : 'Ready',
          message:
              '${value.program?.name ?? 'Scene'} -> ${value.project?.scenes.single.layers.length ?? 0} layers, ${value.channels.length} channels. Tap the check mark to place it on the editable timeline.',
          accent: value.hasWarnings
              ? const Color(0xFFFFC857)
              : const Color(0xFF45D483),
        ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SceneProgramIssueList(
            icon: Icons.warning_amber_rounded,
            title: 'Warnings',
            issues: warnings,
            accent: const Color(0xFFFFC857),
          ),
        ],
      ],
    );
  }
}

class _SceneProgramInfoCard extends StatelessWidget {
  const _SceneProgramInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.accent = FxPalette.textMuted,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FxPalette.dividerSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FxPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: FxPalette.textMuted,
                    fontSize: 12,
                    height: 1.35,
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

class _SceneProgramIssueList extends StatelessWidget {
  const _SceneProgramIssueList({
    required this.icon,
    required this.title,
    required this.issues,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final List<ReFusionSceneProgramIssue> issues;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FxPalette.dividerSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 19),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final issue in issues.take(8)) ...[
            Text(
              issue.path == null
                  ? issue.message
                  : '${issue.path}: ${issue.message}',
              style: const TextStyle(
                color: FxPalette.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (issues.length > 8)
            Text(
              '+${issues.length - 8} more',
              style: const TextStyle(
                color: FxPalette.textFaint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
