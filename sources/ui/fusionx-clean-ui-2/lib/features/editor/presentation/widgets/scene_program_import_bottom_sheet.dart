import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, rootBundle;

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/models/professional_motion_text_models.dart';
import '../../domain/models/refusion_scene_program_models.dart';
import '../../domain/services/kie_scene_program_agent_service.dart';
import '../../domain/services/refusion_scene_agent_provider_catalog.dart';
import '../../domain/services/refusion_scene_program_authoring_service.dart';
import '../../domain/services/scene_semantic_blueprint_compiler.dart';
import '../../domain/services/scene_semantic_blueprint_service.dart';

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
    required this.textAnimationBindings,
    required this.authoringResult,
    this.replaceExistingComposition = false,
  });

  factory SceneProgramImportSheetResult.fromAuthoringResult(
      ReFusionSceneProgramAuthoringResult result,
      {bool replaceExistingComposition = false}) {
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
      textAnimationBindings: result.textAnimationBindings,
      authoringResult: result,
      replaceExistingComposition: replaceExistingComposition,
    );
  }

  final String name;
  final int layerCount;
  final int channelCount;
  final int warningCount;
  final MotionProjectModel project;
  final List<MotionPropertyChannelModel> channels;
  final List<MotionTextAnimationBindingModel> textAnimationBindings;
  final ReFusionSceneProgramAuthoringResult authoringResult;
  final bool replaceExistingComposition;
}

class SceneProgramPresentBottomSheet extends StatelessWidget {
  const SceneProgramPresentBottomSheet({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.canvasSize,
  });

  final String projectId;
  final String sceneId;
  final MotionSize2D canvasSize;

  static const ReFusionSceneProgramAuthoringService _authoringService =
      ReFusionSceneProgramAuthoringService();
  static final KieSceneProgramAgentService _sceneAgentService =
      KieSceneProgramAgentService();

  static const List<_SceneProgramPresentPreset> _presets =
      <_SceneProgramPresentPreset>[
    _SceneProgramPresentPreset(
      title: 'Professional Prompt Bar Clean',
      subtitle:
          'Clean white prompt bar: circle pop, pill stretch, visible border, icon spring, and keyboard typing.',
      assetPath:
          'assets/scene_programs/professional_prompt_bar_clean_scene.json',
      icon: Icons.keyboard_command_key_rounded,
      status: 'New',
    ),
  ];

  Future<void> _applyPreset(
    BuildContext context,
    _SceneProgramPresentPreset preset,
  ) async {
    final String source;
    try {
      source = _sceneProgramSourceForImport(await preset.loadSource());
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Present preset could not be loaded: $error'),
        ),
      );
      return;
    }
    final result = _authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: source,
        fileName: preset.fileName,
        projectId: projectId,
        sceneId: sceneId,
        canvasSize: canvasSize,
      ),
    );
    if (!result.isValid) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.issues.isEmpty
                ? 'Present preset could not be imported.'
                : result.issues.first.message,
          ),
        ),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop(
      SceneProgramImportSheetResult.fromAuthoringResult(
        result,
        replaceExistingComposition: true,
      ),
    );
  }

  static String _sceneProgramSourceForImport(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return trimmed;
      }
      final directSceneProgram = decoded['sceneProgram'];
      if (directSceneProgram is Map) {
        return const JsonEncoder.withIndent('  ').convert(directSceneProgram);
      }
      final directProgram = decoded['program'];
      if (directProgram is Map) {
        return const JsonEncoder.withIndent('  ').convert(directProgram);
      }
      final hasSceneWrapper = decoded.containsKey('directorPlan') ||
          decoded.containsKey('directorBrief') ||
          decoded.containsKey('motionDirector') ||
          decoded.containsKey('sceneProgram') ||
          decoded.containsKey('program');
      if (!hasSceneWrapper) {
        return trimmed;
      }
      return _sceneAgentService
          .extractSceneProgramPayloadFromContent(content: trimmed)
          .sceneProgramJson;
    } on KieSceneProgramAgentException {
      return trimmed;
    } catch (_) {
      return trimmed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.72,
        padding: EdgeInsets.fromLTRB(18, 12, 18, 16 + safeBottom),
        decoration: const BoxDecoration(
          color: FxPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 54,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Present',
              style: TextStyle(
                color: FxPalette.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Curated tutorial-derived scene demos. Each item applies as one editable Scene Clip; open it to inspect layers, elements, and keyframes.',
              style: TextStyle(
                color: FxPalette.textMuted.withOpacity(0.88),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _presets.isEmpty
                  ? const _SceneProgramPresentEmptyState()
                  : ListView.separated(
                      itemCount: _presets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final preset = _presets[index];
                        return _SceneProgramPresentCard(
                          preset: preset,
                          onTap: () => _applyPreset(context, preset),
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

class _SceneProgramPresentEmptyState extends StatelessWidget {
  const _SceneProgramPresentEmptyState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Icon(
                  Icons.movie_filter_rounded,
                  color: FxPalette.textMuted.withOpacity(0.86),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No clean present scene yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The mixed preset was removed. The next scene will be added fresh after the new screen-by-screen brief.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FxPalette.textMuted.withOpacity(0.86),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneProgramPresentPreset {
  const _SceneProgramPresentPreset({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    this.source,
    this.assetPath,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String status;
  final String? source;
  final String? assetPath;

  String get fileName {
    final path = assetPath;
    if (path == null) {
      return '$title.json';
    }
    return path.split('/').last;
  }

  Future<String> loadSource() async {
    final inlineSource = source;
    if (inlineSource != null) {
      return inlineSource;
    }
    final path = assetPath;
    if (path == null) {
      throw StateError('Preset `$title` has no scene source.');
    }
    return rootBundle.loadString(path);
  }
}

class _SceneProgramPresentCard extends StatelessWidget {
  const _SceneProgramPresentCard({
    required this.preset,
    required this.onTap,
  });

  final _SceneProgramPresentPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.045),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Icon(
                  preset.icon,
                  color: FxPalette.textPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: onTap,
                            child: Text(
                              preset.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FxPalette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            preset.status,
                            style: TextStyle(
                              color: FxPalette.textMuted.withOpacity(0.92),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      preset.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FxPalette.textMuted.withOpacity(0.82),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.add_circle_outline_rounded,
                color: FxPalette.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SceneProgramSheetTab {
  script,
  generate,
}

class _SceneImportPayload {
  const _SceneImportPayload({
    required this.inputKind,
    required this.payload,
  });

  final String inputKind;
  final Map<String, Object?>? payload;
}

class _SceneProgramImportBottomSheetState
    extends State<SceneProgramImportBottomSheet> {
  static const String _blueprintEntryProofTag =
      'TF_SCENE_BLUEPRINT_ENTRY_PROOF';
  final ReFusionSceneProgramAuthoringService _authoringService =
      const ReFusionSceneProgramAuthoringService();
  final SceneSemanticBlueprintCompiler _semanticBlueprintCompiler =
      SceneSemanticBlueprintCompiler();
  final ReFusionSceneAgentProviderCatalog _sceneAgentCatalog =
      const ReFusionSceneAgentProviderCatalog();
  late final KieSceneProgramAgentService _sceneAgentService;
  late final TextEditingController _controller;
  late final TextEditingController _promptController;
  late ReFusionSceneAgentProfile _selectedSceneAgentProfile;
  _SceneProgramSheetTab _selectedTab = _SceneProgramSheetTab.script;
  String? _fileName;
  ReFusionSceneProgramAuthoringResult? _result;
  bool _isUploading = false;
  bool _isGenerating = false;
  String? _generationErrorMessage;
  ReFusionSceneAgentRequestPreview? _generationPreview;

  static const String _lineRevealSceneProgram = '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Line Reveal Refusion Demo",
  "durationMs": 3600,
  "frameRate": 30,
  "layers": [
    {
      "id": "deep-bg-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3600,
      "elements": [
        {
          "id": "deep-bg",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#070A12",
            "opacity": 1
          }
        }
      ]
    },
    {
      "id": "reveal-line-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3600,
      "elements": [
        {
          "id": "reveal-line",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 8,
            "height": 16,
            "cornerRadius": 999,
            "color": "#FFFFFF",
            "opacity": 1
          },
          "channels": [
            {
              "property": "width",
              "keyframes": [
                { "timeMs": 0, "value": 8, "easing": "easeOut" },
                { "timeMs": 140, "value": 18, "easing": "easeOut" },
                { "timeMs": 880, "value": 720, "easing": "spring" },
                { "timeMs": 2100, "value": 720, "easing": "linear" },
                { "timeMs": 3000, "value": 820, "easing": "easeInOut" },
                { "timeMs": 3600, "value": 1080, "easing": "easeIn" }
              ]
            },
            {
              "property": "height",
              "keyframes": [
                { "timeMs": 0, "value": 16, "easing": "linear" },
                { "timeMs": 2820, "value": 16, "easing": "linear" },
                { "timeMs": 3600, "value": 1920, "easing": "easeIn" }
              ]
            },
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 0, "value": { "x": 0, "y": 0 }, "easing": "easeOut" },
                { "timeMs": 980, "value": { "x": 0, "y": 0 }, "easing": "linear" },
                { "timeMs": 1420, "value": { "x": 0, "y": 112 }, "easing": "easeOut" },
                { "timeMs": 3000, "value": { "x": 0, "y": 112 }, "easing": "linear" },
                { "timeMs": 3600, "value": { "x": 0, "y": 0 }, "easing": "easeIn" }
              ]
            },
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 1.0, "easing": "linear" },
                { "timeMs": 3600, "value": 1.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "refusion-title-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 3600,
      "elements": [
        {
          "id": "refusion-title",
          "kind": "text",
          "text": "Refusion",
          "properties": {
            "fontSize": 122,
            "color": "#FFFFFF",
            "opacity": 0,
            "letterSpacing": 18
          },
          "channels": [
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 0, "value": { "x": 0, "y": 18 }, "easing": "linear" },
                { "timeMs": 1120, "value": { "x": 0, "y": 18 }, "easing": "linear" },
                { "timeMs": 1650, "value": { "x": 0, "y": -16 }, "easing": "easeOut" },
                { "timeMs": 2800, "value": { "x": 0, "y": -16 }, "easing": "linear" },
                { "timeMs": 3400, "value": { "x": 0, "y": -4 }, "easing": "easeIn" }
              ]
            },
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 1160, "value": 0.0, "easing": "easeOut" },
                { "timeMs": 1700, "value": 1.0, "easing": "easeOut" },
                { "timeMs": 2980, "value": 1.0, "easing": "linear" },
                { "timeMs": 3520, "value": 0.0, "easing": "easeIn" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 0, "value": 0.92, "easing": "linear" },
                { "timeMs": 1700, "value": 1.0, "easing": "spring" },
                { "timeMs": 3000, "value": 1.0, "easing": "linear" },
                { "timeMs": 3520, "value": 1.08, "easing": "easeIn" }
              ]
            },
            {
              "property": "letterSpacing",
              "keyframes": [
                { "timeMs": 0, "value": 18, "easing": "linear" },
                { "timeMs": 1700, "value": 0, "easing": "easeOut" },
                { "timeMs": 3000, "value": 0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

  static const String _designRevealSceneProgram = '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Design Reveal Study",
  "durationMs": 4300,
  "frameRate": 30,
  "layers": [
    {
      "id": "design-red-field-layer",
      "name": "Red Gradient Field Study",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 4300,
      "elements": [
        {
          "id": "design-red-base",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#F53D4E",
            "opacity": 1
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 360, "value": 1.0, "easing": "easeOutCubic" }
              ]
            }
          ]
        },
        {
          "id": "design-red-glow-left",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 1380,
            "height": 1380,
            "color": "#FF7B85",
            "position": { "x": -240, "y": -300 },
            "opacity": 0.22,
            "blur": 80
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 620, "value": 0.22, "easing": "easeOutCubic" },
                { "timeMs": 4300, "value": 0.22, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 0, "value": 0.92, "easing": "linear" },
                { "timeMs": 1800, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 4300, "value": 1.04, "easing": "linear" }
              ]
            }
          ]
        },
        {
          "id": "design-red-vignette-right",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 1760,
            "height": 1760,
            "color": "#BD1630",
            "position": { "x": 340, "y": 260 },
            "opacity": 0.18,
            "blur": 120
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 860, "value": 0.18, "easing": "easeOutCubic" },
                { "timeMs": 4300, "value": 0.18, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "design-shadow-layer",
      "name": "Reusable Soft Shadow",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 4300,
      "elements": [
        {
          "id": "design-title-shadow",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 640,
            "height": 72,
            "cornerRadius": 999,
            "color": "#96172B",
            "position": { "x": 0, "y": 252 },
            "opacity": 0,
            "scale": 0.52,
            "blur": 42
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 740, "value": 0.0, "easing": "linear" },
                { "timeMs": 1500, "value": 0.26, "easing": "easeOutCubic" },
                { "timeMs": 3180, "value": 0.26, "easing": "linear" },
                { "timeMs": 3920, "value": 0.12, "easing": "easeInOut" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 740, "value": 0.52, "easing": "linear" },
                { "timeMs": 1720, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 3920, "value": 1.08, "easing": "easeInOut" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "design-title-layer",
      "name": "Design Title",
      "kind": "text",
      "startMs": 0,
      "durationMs": 4300,
      "elements": [
        {
          "id": "design-title",
          "kind": "text",
          "text": "design",
          "properties": {
            "fontSize": 184,
            "letterSpacing": -2,
            "color": "#FFFFFF",
            "position": { "x": -42, "y": -26 },
            "opacity": 0,
            "scale": 0.98
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 1040, "value": 0.0, "easing": "linear" },
                { "timeMs": 1120, "value": 1.0, "easing": "linear" },
                { "timeMs": 4300, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 1040, "value": 0.98, "easing": "linear" },
                { "timeMs": 1860, "value": 1.0, "easing": "spring" },
                { "timeMs": 4300, "value": 1.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "design-title-matte-cover-layer",
      "name": "Moving Background Matte Approximation",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 4300,
      "elements": [
        {
          "id": "design-title-matte-cover",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 880,
            "height": 250,
            "color": "#F53D4E",
            "position": { "x": 0, "y": -22 },
            "opacity": 0
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 1080, "value": 1.0, "easing": "linear" },
                { "timeMs": 2500, "value": 1.0, "easing": "linear" },
                { "timeMs": 2580, "value": 0.0, "easing": "linear" }
              ]
            },
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 1080, "value": { "x": 0, "y": -22 }, "easing": "linear" },
                { "timeMs": 1480, "value": { "x": 0, "y": -22 }, "easing": "linear" },
                { "timeMs": 2380, "value": { "x": 454, "y": -22 }, "easing": "easeOutCubic" }
              ]
            },
            {
              "property": "width",
              "keyframes": [
                { "timeMs": 1080, "value": 880, "easing": "linear" },
                { "timeMs": 1480, "value": 880, "easing": "linear" },
                { "timeMs": 2380, "value": 0, "easing": "easeOutCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "design-driver-layer",
      "name": "Circle To Reveal Driver",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 4300,
      "elements": [
        {
          "id": "design-reveal-driver",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 86,
            "height": 86,
            "cornerRadius": 999,
            "color": "#FFFFFF",
            "position": { "x": -360, "y": 360 },
            "opacity": 0,
            "scale": 1
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 360, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 3300, "value": 1.0, "easing": "linear" },
                { "timeMs": 3820, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 0, "value": { "x": 0, "y": 410 }, "easing": "linear" },
                { "timeMs": 760, "value": { "x": 0, "y": 18 }, "easing": "easeOutCubic" },
                { "timeMs": 1320, "value": { "x": -430, "y": 18 }, "easing": "easeInOut" },
                { "timeMs": 1480, "value": { "x": -430, "y": 18 }, "easing": "linear" },
                { "timeMs": 2380, "value": { "x": 430, "y": 18 }, "easing": "easeOutCubic" },
                { "timeMs": 3300, "value": { "x": 430, "y": 18 }, "easing": "linear" },
                { "timeMs": 3820, "value": { "x": 430, "y": 92 }, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "width",
              "keyframes": [
                { "timeMs": 0, "value": 86, "easing": "linear" },
                { "timeMs": 760, "value": 86, "easing": "linear" },
                { "timeMs": 1320, "value": 620, "easing": "easeOutCubic" },
                { "timeMs": 1480, "value": 620, "easing": "linear" },
                { "timeMs": 2380, "value": 86, "easing": "easeInOut" },
                { "timeMs": 3300, "value": 86, "easing": "linear" }
              ]
            },
            {
              "property": "height",
              "keyframes": [
                { "timeMs": 0, "value": 86, "easing": "linear" },
                { "timeMs": 1320, "value": 42, "easing": "easeOutCubic" },
                { "timeMs": 2380, "value": 86, "easing": "easeInOut" },
                { "timeMs": 3300, "value": 86, "easing": "linear" }
              ]
            },
            {
              "property": "cornerRadius",
              "keyframes": [
                { "timeMs": 0, "value": 999, "easing": "linear" },
                { "timeMs": 1320, "value": 24, "easing": "easeOutCubic" },
                { "timeMs": 2380, "value": 999, "easing": "easeInOut" },
                { "timeMs": 3300, "value": 999, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 0, "value": 0.72, "easing": "linear" },
                { "timeMs": 760, "value": 1.0, "easing": "spring" },
                { "timeMs": 3300, "value": 1.0, "easing": "linear" },
                { "timeMs": 3820, "value": 0.72, "easing": "easeInCubic" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

  static const String _codexIntroSceneProgram = '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Codex Prompt Intro",
  "durationMs": 6200,
  "frameRate": 30,
  "layers": [
    {
      "id": "codex-bg-layer",
      "name": "White Cinema Background",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "codex-bg",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#FFFFFF",
            "opacity": 1
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 420, "value": 1.0, "easing": "easeOutCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "codex-logo-layer",
      "name": "Mac Starter Icon",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "macIcon",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 154,
            "height": 154,
            "cornerRadius": 38,
            "color": "#050505",
            "position": { "x": 0, "y": -18 },
            "opacity": 0,
            "scale": 0.62,
            "rotation": -8
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 160, "value": 0.0, "easing": "linear" },
                { "timeMs": 520, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 1280, "value": 1.0, "easing": "linear" },
                { "timeMs": 1680, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 160, "value": 0.62, "easing": "linear" },
                { "timeMs": 900, "value": 1.0, "easing": "spring" },
                { "timeMs": 1280, "value": 1.0, "easing": "linear" },
                { "timeMs": 1680, "value": 0.82, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "rotation",
              "keyframes": [
                { "timeMs": 160, "value": -8, "easing": "linear" },
                { "timeMs": 900, "value": 0, "easing": "easeOutCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "codex-logo-mark-layer",
      "name": "Codex Logo Mark",
      "kind": "text",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "codexLogoMark",
          "kind": "text",
          "text": "C",
          "properties": {
            "fontSize": 78,
            "letterSpacing": 0,
            "color": "#FFFFFF",
            "position": { "x": 0, "y": -21 },
            "opacity": 0,
            "scale": 0.84
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 300, "value": 0.0, "easing": "linear" },
                { "timeMs": 620, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 1280, "value": 1.0, "easing": "linear" },
                { "timeMs": 1620, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 300, "value": 0.84, "easing": "linear" },
                { "timeMs": 900, "value": 1.0, "easing": "spring" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "prompt-shell-layer",
      "name": "Prompt Input Bar",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "promptShell",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 154,
            "height": 112,
            "cornerRadius": 56,
            "color": "#050505",
            "position": { "x": 0, "y": 0 },
            "opacity": 0,
            "scale": 0.86
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 1160, "value": 0.0, "easing": "linear" },
                { "timeMs": 1420, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 4920, "value": 1.0, "easing": "linear" },
                { "timeMs": 5200, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "width",
              "keyframes": [
                { "timeMs": 1160, "value": 154, "easing": "linear" },
                { "timeMs": 2280, "value": 900, "easing": "easeOutQuint" }
              ]
            },
            {
              "property": "height",
              "keyframes": [
                { "timeMs": 1160, "value": 112, "easing": "linear" },
                { "timeMs": 2280, "value": 118, "easing": "easeOutCubic" }
              ]
            },
            {
              "property": "cornerRadius",
              "keyframes": [
                { "timeMs": 1160, "value": 56, "easing": "linear" },
                { "timeMs": 2280, "value": 58, "easing": "easeOutCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 1160, "value": 0.86, "easing": "linear" },
                { "timeMs": 2280, "value": 1.0, "easing": "spring" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "attach-control-layer",
      "name": "Attach Control",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "attachButton",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 74,
            "height": 74,
            "color": "#111111",
            "position": { "x": -370, "y": 0 },
            "opacity": 0,
            "scale": 0.74
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 2020, "value": 0.0, "easing": "linear" },
                { "timeMs": 2540, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 4920, "value": 1.0, "easing": "linear" },
                { "timeMs": 5200, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 2020, "value": 0.74, "easing": "linear" },
                { "timeMs": 2540, "value": 1.0, "easing": "spring" }
              ]
            }
          ]
        },
        {
          "id": "attachIcon",
          "kind": "icon",
          "properties": {
            "icon": "paperclip",
            "width": 34,
            "height": 34,
            "color": "#FFFFFF",
            "position": { "x": -370, "y": 0 },
            "opacity": 0,
            "scale": 0.82
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 2140, "value": 0.0, "easing": "linear" },
                { "timeMs": 2620, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 4920, "value": 1.0, "easing": "linear" },
                { "timeMs": 5200, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 2140, "value": 0.82, "easing": "linear" },
                { "timeMs": 2620, "value": 1.0, "easing": "spring" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "prompt-text-layer",
      "name": "Typed Prompt",
      "kind": "text",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "promptText",
          "kind": "text",
          "text": "Build up for my business",
          "properties": {
            "fontSize": 42,
            "letterSpacing": 0,
            "color": "#FFFFFF",
            "position": { "x": -58, "y": 0 },
            "opacity": 0,
            "typewriterProgress": 0
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 2440, "value": 0.0, "easing": "linear" },
                { "timeMs": 2680, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 4920, "value": 1.0, "easing": "linear" },
                { "timeMs": 5200, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "typewriterProgress",
              "keyframes": [
                { "timeMs": 2680, "value": 0.0, "easing": "linear" },
                { "timeMs": 4220, "value": 1.0, "easing": "linear" },
                { "timeMs": 4920, "value": 1.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "send-control-layer",
      "name": "Send Control",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "sendButton",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 82,
            "height": 82,
            "color": "#FFFFFF",
            "position": { "x": 372, "y": 0 },
            "opacity": 0,
            "scale": 0.72
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 2100, "value": 0.0, "easing": "linear" },
                { "timeMs": 2660, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 5050, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 2100, "value": 0.72, "easing": "linear" },
                { "timeMs": 2660, "value": 1.0, "easing": "spring" },
                { "timeMs": 4340, "value": 1.0, "easing": "linear" },
                { "timeMs": 4500, "value": 0.86, "easing": "easeInCubic" },
                { "timeMs": 4680, "value": 1.08, "easing": "easeOutCubic" },
                { "timeMs": 5000, "value": 1.0, "easing": "easeOutCubic" }
              ]
            }
          ]
        },
        {
          "id": "sendIcon",
          "kind": "icon",
          "properties": {
            "icon": "send",
            "width": 42,
            "height": 42,
            "color": "#050505",
            "position": { "x": 372, "y": 0 },
            "opacity": 0,
            "scale": 0.78
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 2220, "value": 0.0, "easing": "linear" },
                { "timeMs": 2740, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 5050, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 2220, "value": 0.78, "easing": "linear" },
                { "timeMs": 2740, "value": 1.0, "easing": "spring" },
                { "timeMs": 4340, "value": 1.0, "easing": "linear" },
                { "timeMs": 4500, "value": 0.82, "easing": "easeInCubic" },
                { "timeMs": 4680, "value": 1.0, "easing": "easeOutCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "screen-cover-layer",
      "name": "Send Circle Screen Cover",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "coverCircle",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 82,
            "height": 82,
            "color": "#FFFFFF",
            "position": { "x": 372, "y": 0 },
            "opacity": 0,
            "scale": 1
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 4680, "value": 0.0, "easing": "linear" },
                { "timeMs": 4740, "value": 1.0, "easing": "linear" },
                { "timeMs": 6200, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 4680, "value": 1.0, "easing": "linear" },
                { "timeMs": 5220, "value": 8.0, "easing": "easeOutCubic" },
                { "timeMs": 5900, "value": 28.0, "easing": "easeOutQuint" },
                { "timeMs": 6200, "value": 30.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "welcome-text-layer",
      "name": "Welcome Title",
      "kind": "text",
      "startMs": 0,
      "durationMs": 6200,
      "elements": [
        {
          "id": "welcomeText",
          "kind": "text",
          "text": "Welcome to Codex",
          "properties": {
            "fontSize": 74,
            "letterSpacing": 0,
            "color": "#050505",
            "position": { "x": 0, "y": 0 },
            "opacity": 0,
            "scale": 0.92
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 5380, "value": 0.0, "easing": "linear" },
                { "timeMs": 5840, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 6200, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 5380, "value": 0.92, "easing": "linear" },
                { "timeMs": 5840, "value": 1.0, "easing": "spring" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

  static const String _codexPromptBloomSceneProgram = '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Codex Prompt Bloom",
  "durationMs": 7800,
  "frameRate": 30,
  "layers": [
    {
      "id": "bloom-bg-layer",
      "name": "Clean White Background",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "bloom-bg",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#FFFFFF",
            "opacity": 1
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 0, "value": 0.0, "easing": "linear" },
                { "timeMs": 460, "value": 1.0, "easing": "easeOutCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "welcome-word-layer",
      "name": "Welcome Word",
      "kind": "text",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "welcome-word",
          "kind": "text",
          "text": "Welcome",
          "properties": {
            "fontSize": 64,
            "fontWeight": 900,
            "letterSpacing": 0,
            "color": "#050505",
            "position": { "x": -170, "y": 0 },
            "opacity": 0,
            "scale": 0.72
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 180, "value": 0.0, "easing": "linear" },
                { "timeMs": 520, "value": 1.0, "easing": "spring" },
                { "timeMs": 1940, "value": 1.0, "easing": "linear" },
                { "timeMs": 2300, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 180, "value": 0.72, "easing": "linear" },
                { "timeMs": 520, "value": 1.16, "easing": "spring" },
                { "timeMs": 760, "value": 0.98, "easing": "easeOutCubic" },
                { "timeMs": 940, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 1940, "value": 1.0, "easing": "linear" },
                { "timeMs": 2300, "value": 0.86, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 180, "value": { "x": -170, "y": 34 }, "easing": "linear" },
                { "timeMs": 520, "value": { "x": -170, "y": -3 }, "easing": "spring" },
                { "timeMs": 760, "value": { "x": -170, "y": 0 }, "easing": "easeOutCubic" },
                { "timeMs": 1940, "value": { "x": -170, "y": 0 }, "easing": "linear" },
                { "timeMs": 2300, "value": { "x": -170, "y": -26 }, "easing": "easeInCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "to-word-layer",
      "name": "To Word",
      "kind": "text",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "to-word",
          "kind": "text",
          "text": "to",
          "properties": {
            "fontSize": 64,
            "fontWeight": 900,
            "letterSpacing": 0,
            "color": "#050505",
            "position": { "x": 18, "y": 0 },
            "opacity": 0,
            "scale": 0.72,
            "rotation": -3
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 560, "value": 0.0, "easing": "linear" },
                { "timeMs": 880, "value": 1.0, "easing": "spring" },
                { "timeMs": 1940, "value": 1.0, "easing": "linear" },
                { "timeMs": 2300, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 560, "value": 0.72, "easing": "linear" },
                { "timeMs": 880, "value": 1.14, "easing": "spring" },
                { "timeMs": 1080, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 1940, "value": 1.0, "easing": "linear" },
                { "timeMs": 2300, "value": 0.86, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "rotation",
              "keyframes": [
                { "timeMs": 560, "value": -3, "easing": "linear" },
                { "timeMs": 880, "value": 0, "easing": "spring" },
                { "timeMs": 1940, "value": 0, "easing": "linear" },
                { "timeMs": 2300, "value": 3, "easing": "easeInCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "codex-word-layer",
      "name": "Codex Word",
      "kind": "text",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "codex-word",
          "kind": "text",
          "text": "Codex",
          "properties": {
            "fontSize": 64,
            "fontWeight": 900,
            "letterSpacing": 0,
            "color": "#050505",
            "position": { "x": 180, "y": 0 },
            "opacity": 0,
            "scale": 0.72
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 900, "value": 0.0, "easing": "linear" },
                { "timeMs": 1220, "value": 1.0, "easing": "spring" },
                { "timeMs": 1940, "value": 1.0, "easing": "linear" },
                { "timeMs": 2300, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 900, "value": 0.72, "easing": "linear" },
                { "timeMs": 1220, "value": 1.14, "easing": "spring" },
                { "timeMs": 1440, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 1940, "value": 1.0, "easing": "linear" },
                { "timeMs": 2300, "value": 0.86, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "position",
              "keyframes": [
                { "timeMs": 900, "value": { "x": 180, "y": -30 }, "easing": "linear" },
                { "timeMs": 1220, "value": { "x": 180, "y": 3 }, "easing": "spring" },
                { "timeMs": 1440, "value": { "x": 180, "y": 0 }, "easing": "easeOutCubic" },
                { "timeMs": 1940, "value": { "x": 180, "y": 0 }, "easing": "linear" },
                { "timeMs": 2300, "value": { "x": 180, "y": -26 }, "easing": "easeInCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "prompt-shell-layer",
      "name": "Icon To Prompt Shell",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "prompt-shell",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 148,
            "height": 148,
            "cornerRadius": 38,
            "color": "#050505",
            "position": { "x": 0, "y": 0 },
            "opacity": 0,
            "scale": 0.78
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 2300, "value": 0.0, "easing": "linear" },
                { "timeMs": 2660, "value": 1.0, "easing": "spring" },
                { "timeMs": 6640, "value": 1.0, "easing": "linear" },
                { "timeMs": 6800, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "width",
              "keyframes": [
                { "timeMs": 2300, "value": 148, "easing": "linear" },
                { "timeMs": 3300, "value": 148, "easing": "linear" },
                { "timeMs": 3600, "value": 148, "easing": "easeOutCubic" },
                { "timeMs": 4100, "value": 900, "easing": "easeOutQuint" },
                { "timeMs": 6640, "value": 900, "easing": "linear" }
              ]
            },
            {
              "property": "height",
              "keyframes": [
                { "timeMs": 2300, "value": 148, "easing": "linear" },
                { "timeMs": 3300, "value": 148, "easing": "linear" },
                { "timeMs": 3600, "value": 148, "easing": "easeOutCubic" },
                { "timeMs": 4100, "value": 116, "easing": "easeOutQuint" },
                { "timeMs": 6640, "value": 116, "easing": "linear" }
              ]
            },
            {
              "property": "cornerRadius",
              "keyframes": [
                { "timeMs": 2300, "value": 38, "easing": "linear" },
                { "timeMs": 3300, "value": 38, "easing": "linear" },
                { "timeMs": 3600, "value": 74, "easing": "easeOutCubic" },
                { "timeMs": 4100, "value": 58, "easing": "easeOutQuint" },
                { "timeMs": 6640, "value": 58, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 2300, "value": 0.62, "easing": "linear" },
                { "timeMs": 2620, "value": 1.12, "easing": "spring" },
                { "timeMs": 2840, "value": 0.96, "easing": "easeOutCubic" },
                { "timeMs": 3020, "value": 1.0, "easing": "spring" },
                { "timeMs": 3300, "value": 1.0, "easing": "linear" },
                { "timeMs": 3460, "value": 0.86, "easing": "easeInCubic" },
                { "timeMs": 3600, "value": 1.04, "easing": "spring" },
                { "timeMs": 4100, "value": 1.0, "easing": "easeOutCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "codex-mark-layer",
      "name": "Codex Mark In Icon",
      "kind": "text",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "codex-mark",
          "kind": "text",
          "text": "C",
          "properties": {
            "fontSize": 76,
            "letterSpacing": 0,
            "color": "#FFFFFF",
            "position": { "x": 0, "y": -2 },
            "opacity": 0,
            "scale": 0.86
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 2400, "value": 0.0, "easing": "linear" },
                { "timeMs": 2720, "value": 1.0, "easing": "spring" },
                { "timeMs": 3300, "value": 1.0, "easing": "linear" },
                { "timeMs": 3600, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 2400, "value": 0.78, "easing": "linear" },
                { "timeMs": 2720, "value": 1.0, "easing": "spring" },
                { "timeMs": 3300, "value": 1.0, "easing": "linear" },
                { "timeMs": 3460, "value": 0.82, "easing": "easeInCubic" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "send-button-layer",
      "name": "Right Send Button",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "send-button",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 78,
            "height": 78,
            "color": "#FFFFFF",
            "position": { "x": 360, "y": 0 },
            "opacity": 0,
            "scale": 0.7
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 4020, "value": 0.0, "easing": "linear" },
                { "timeMs": 4480, "value": 1.0, "easing": "spring" },
                { "timeMs": 6800, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 4020, "value": 0.7, "easing": "linear" },
                { "timeMs": 4480, "value": 1.0, "easing": "spring" },
                { "timeMs": 6400, "value": 1.0, "easing": "linear" },
                { "timeMs": 6580, "value": 0.82, "easing": "easeInCubic" },
                { "timeMs": 6740, "value": 1.12, "easing": "spring" },
                { "timeMs": 6900, "value": 1.0, "easing": "easeOutCubic" }
              ]
            }
          ]
        },
        {
          "id": "send-arrow",
          "kind": "icon",
          "properties": {
            "icon": "arrow-up",
            "width": 36,
            "height": 36,
            "color": "#050505",
            "position": { "x": 360, "y": 0 },
            "opacity": 0,
            "scale": 0.82
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 4140, "value": 0.0, "easing": "linear" },
                { "timeMs": 4560, "value": 1.0, "easing": "spring" },
                { "timeMs": 6800, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 4140, "value": 0.82, "easing": "linear" },
                { "timeMs": 4560, "value": 1.0, "easing": "spring" },
                { "timeMs": 6400, "value": 1.0, "easing": "linear" },
                { "timeMs": 6580, "value": 0.82, "easing": "easeInCubic" },
                { "timeMs": 6740, "value": 1.0, "easing": "spring" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "plus-icon-layer",
      "name": "Left Plus Icon",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "plus-icon",
          "kind": "icon",
          "properties": {
            "icon": "plus",
            "width": 36,
            "height": 36,
            "color": "#FFFFFF",
            "position": { "x": -360, "y": 0 },
            "opacity": 0,
            "scale": 0.72
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 4160, "value": 0.0, "easing": "linear" },
                { "timeMs": 4580, "value": 1.0, "easing": "spring" },
                { "timeMs": 6640, "value": 1.0, "easing": "linear" },
                { "timeMs": 6800, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 4160, "value": 0.72, "easing": "linear" },
                { "timeMs": 4580, "value": 1.0, "easing": "spring" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "prompt-copy-layer",
      "name": "Typed Business Prompt",
      "kind": "text",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "prompt-copy",
          "kind": "text",
          "text": "Build a new app for my business",
          "properties": {
            "fontSize": 35,
            "letterSpacing": 0,
            "color": "#FFFFFF",
            "position": { "x": 0, "y": 0 },
            "opacity": 0,
            "typewriterProgress": 0
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 4380, "value": 0.0, "easing": "linear" },
                { "timeMs": 4580, "value": 1.0, "easing": "easeOutCubic" },
                { "timeMs": 6640, "value": 1.0, "easing": "linear" },
                { "timeMs": 6800, "value": 0.0, "easing": "easeInCubic" }
              ]
            },
            {
              "property": "typewriterProgress",
              "keyframes": [
                { "timeMs": 4580, "value": 0.0, "easing": "linear" },
                { "timeMs": 6080, "value": 1.0, "easing": "linear" },
                { "timeMs": 6640, "value": 1.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "send-cover-layer",
      "name": "Send Button Cover Resolve",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 7800,
      "elements": [
        {
          "id": "send-cover-circle",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 78,
            "height": 78,
            "color": "#FFFFFF",
            "position": { "x": 360, "y": 0 },
            "opacity": 0,
            "scale": 1
          },
          "channels": [
            {
              "property": "opacity",
              "keyframes": [
                { "timeMs": 6740, "value": 0.0, "easing": "linear" },
                { "timeMs": 6800, "value": 1.0, "easing": "linear" },
                { "timeMs": 7800, "value": 1.0, "easing": "linear" }
              ]
            },
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 6740, "value": 1.0, "easing": "linear" },
                { "timeMs": 7240, "value": 12.0, "easing": "easeOutCubic" },
                { "timeMs": 7600, "value": 30.0, "easing": "easeOutQuint" },
                { "timeMs": 7800, "value": 30.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

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

  static const String _promptInputSceneProgram = '''
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Prompt Input Core Pack Demo",
  "durationMs": 3200,
  "frameRate": 30,
  "layers": [
    {
      "id": "prompt-bg-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "prompt-bg",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#090A0F",
            "opacity": 1
          }
        }
      ]
    },
    {
      "id": "input-shell-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "input-shell",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 900,
            "height": 132,
            "cornerRadius": 54,
            "color": "#191B24",
            "opacity": 1
          },
          "channels": [
            {
              "property": "scale",
              "keyframes": [
                { "timeMs": 0, "value": 0.92, "easing": "easeOut" },
                { "timeMs": 520, "value": 1.0, "easing": "spring" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "attach-icon-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "attach-icon",
          "kind": "icon",
          "properties": {
            "icon": "plus",
            "width": 54,
            "height": 54,
            "color": "#DDE2F2",
            "position": { "x": -360, "y": 0 }
          }
        }
      ]
    },
    {
      "id": "prompt-text-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "prompt-text",
          "kind": "text",
          "text": "hello world",
          "properties": {
            "fontSize": 58,
            "color": "#FFFFFF",
            "position": { "x": -74, "y": 2 },
            "opacity": 1,
            "reveal": 0
          },
          "channels": [
            {
              "property": "reveal",
              "keyframes": [
                { "timeMs": 620, "value": 0.0, "easing": "linear" },
                { "timeMs": 2050, "value": 1.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "mic-icon-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "mic-icon",
          "kind": "icon",
          "properties": {
            "icon": "mic",
            "width": 48,
            "height": 48,
            "color": "#DDE2F2",
            "position": { "x": 258, "y": 0 }
          }
        }
      ]
    },
    {
      "id": "send-button-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "send-button-bg",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 76,
            "height": 76,
            "color": "#FFFFFF",
            "position": { "x": 364, "y": 0 },
            "opacity": 1
          }
        },
        {
          "id": "send-icon",
          "kind": "icon",
          "properties": {
            "icon": "send",
            "width": 42,
            "height": 42,
            "color": "#090A0F",
            "position": { "x": 364, "y": 0 },
            "opacity": 1
          }
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
    _sceneAgentService = KieSceneProgramAgentService(
      catalog: _sceneAgentCatalog,
    );
    _controller = TextEditingController();
    _promptController = TextEditingController(
      text:
          'Create a cinematic native SaaS product launch promo with three beats: a premium hire-card click, scattered feedback cards, then a dark Revival hub that brings projects, feedback, files, and communication into one place.',
    );
    _selectedSceneAgentProfile =
        ReFusionSceneAgentProviderCatalog.profiles.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    _promptController.dispose();
    super.dispose();
  }

  ReFusionSceneProgramAuthoringResult _importCurrentSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return ReFusionSceneProgramAuthoringResult(
        issues: <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: 'Scene source is empty.',
            path: 'source',
          ),
        ],
      );
    }

    final extracted = _extractCandidatePayload(trimmed);
    if (extracted.payload != null &&
        _looksLikeBlueprintMap(extracted.payload!)) {
      return _compileBlueprintPayload(
        blueprintPayload: extracted.payload!,
        inputKind: extracted.inputKind,
        migrationTier: 'none',
      );
    }
    return ReFusionSceneProgramAuthoringResult(
      issues: <ReFusionSceneProgramIssue>[
        const ReFusionSceneProgramIssue(
          severity: ReFusionSceneProgramIssueSeverity.error,
          message:
              'Professional import expects Semantic Blueprint input only. Raw SceneProgram payloads are blocked in strict mode.',
          path: 'source',
        ),
        _buildBlueprintEntryIssue(
          inputKind: extracted.inputKind,
          parsedAsBlueprint: false,
          legacyMode: false,
          migrationTier: 'tierD',
          blocked: true,
          reason: 'raw_scene_program_blocked',
          severity: ReFusionSceneProgramIssueSeverity.error,
        ),
      ],
    );
  }

  ReFusionSceneProgramAuthoringResult _compileBlueprintPayload({
    required Map<String, Object?> blueprintPayload,
    required String inputKind,
    required String migrationTier,
  }) {
    final compile =
        _semanticBlueprintCompiler.compile(payload: blueprintPayload);
    if (!compile.isValid || compile.program == null) {
      return ReFusionSceneProgramAuthoringResult(
        issues: <ReFusionSceneProgramIssue>[
          ...compile.issues,
          _buildBlueprintEntryIssue(
            inputKind: inputKind,
            parsedAsBlueprint: true,
            legacyMode: false,
            migrationTier: migrationTier,
            blocked: true,
            reason: 'blueprint_compile_failed',
            severity: ReFusionSceneProgramIssueSeverity.error,
          ),
        ],
      );
    }
    final compiledProgramSource =
        jsonEncode(_sceneProgramToMap(compile.program!));
    final authored = _authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: compiledProgramSource,
        fileName: _fileName,
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        canvasSize: widget.canvasSize,
      ),
    );
    return ReFusionSceneProgramAuthoringResult(
      program: authored.program,
      project: authored.project,
      channels: authored.channels,
      textAnimationBindings: authored.textAnimationBindings,
      issues: <ReFusionSceneProgramIssue>[
        ...compile.issues,
        ...authored.issues,
        _buildBlueprintEntryIssue(
          inputKind: inputKind,
          parsedAsBlueprint: true,
          legacyMode: false,
          migrationTier: migrationTier,
          blocked: !authored.isValid,
          reason: authored.isValid ? 'accepted' : 'authoring_validation_failed',
          severity: authored.isValid
              ? ReFusionSceneProgramIssueSeverity.info
              : ReFusionSceneProgramIssueSeverity.error,
        ),
      ],
    );
  }

  ReFusionSceneProgramIssue _buildBlueprintEntryIssue({
    required String inputKind,
    required bool parsedAsBlueprint,
    required bool legacyMode,
    required String migrationTier,
    required bool blocked,
    required String reason,
    required ReFusionSceneProgramIssueSeverity severity,
  }) {
    return ReFusionSceneProgramIssue(
      severity: severity,
      message: '$_blueprintEntryProofTag '
          'inputKind=$inputKind '
          'parsedAsBlueprint=${parsedAsBlueprint.toString()} '
          'legacyMode=${legacyMode.toString()} '
          'migrationTier=$migrationTier '
          'blocked=${blocked.toString()} '
          'reason=$reason '
          'severity=${severity.name}',
      path: 'source',
    );
  }

  _SceneImportPayload _extractCandidatePayload(String source) {
    final decoded = _decodeJsonMap(source);
    if (decoded == null) {
      return const _SceneImportPayload(
        inputKind: 'text.raw',
        payload: null,
      );
    }
    final semantic = decoded['semanticBlueprint'];
    if (semantic is Map<String, Object?>) {
      return _SceneImportPayload(
        inputKind: 'wrapper.semanticBlueprint',
        payload: semantic,
      );
    }
    final blueprint = decoded['blueprint'];
    if (blueprint is Map<String, Object?>) {
      return _SceneImportPayload(
        inputKind: 'wrapper.blueprint',
        payload: blueprint,
      );
    }
    final sceneProgram = decoded['sceneProgram'];
    if (sceneProgram is Map<String, Object?>) {
      return _SceneImportPayload(
        inputKind: 'wrapper.sceneProgram',
        payload: sceneProgram,
      );
    }
    final program = decoded['program'];
    if (program is Map<String, Object?>) {
      return _SceneImportPayload(
        inputKind: 'wrapper.program',
        payload: program,
      );
    }
    return _SceneImportPayload(inputKind: 'map.root', payload: decoded);
  }

  Map<String, Object?>? _decodeJsonMap(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeBlueprintMap(Map<String, Object?> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is String &&
        schemaVersion.trim() == SceneSemanticBlueprintService.schemaVersion) {
      return true;
    }
    final hasComponents = map['components'] is List;
    final hasLayers = map['layers'] is List;
    final hasBeats = map['beats'] is List;
    return hasComponents && hasBeats && !hasLayers;
  }

  Map<String, Object?> _sceneProgramToMap(ReFusionSceneProgram program) {
    return <String, Object?>{
      'schemaVersion': program.schemaVersion,
      'name': program.name,
      'durationMs': program.durationMs,
      'frameRate': program.frameRate,
      'layers': program.layers
          .map((layer) => <String, Object?>{
                'id': layer.id,
                if (layer.name != null) 'name': layer.name,
                'kind': layer.kind,
                'startMs': layer.startMs,
                'durationMs': layer.durationMs,
                'elements': layer.elements
                    .map((element) => <String, Object?>{
                          'id': element.id,
                          if (element.name != null) 'name': element.name,
                          'kind': element.kind,
                          if (element.text != null) 'text': element.text,
                          'properties': element.properties,
                          if (element.channels.isNotEmpty)
                            'channels': element.channels
                                .map((channel) => <String, Object?>{
                                      'target': channel.target,
                                      'property': channel.property,
                                      'keyframes': channel.keyframes
                                          .map((keyframe) => <String, Object?>{
                                                'timeMs': keyframe.timeMs,
                                                'value': keyframe.value,
                                                if (keyframe.easing != 'linear')
                                                  'easing': keyframe.easing,
                                              })
                                          .toList(growable: false),
                                    })
                                .toList(growable: false),
                        })
                    .toList(growable: false),
                if (layer.channels.isNotEmpty)
                  'channels': layer.channels
                      .map((channel) => <String, Object?>{
                            'target': channel.target,
                            'property': channel.property,
                            'keyframes': channel.keyframes
                                .map((keyframe) => <String, Object?>{
                                      'timeMs': keyframe.timeMs,
                                      'value': keyframe.value,
                                      if (keyframe.easing != 'linear')
                                        'easing': keyframe.easing,
                                    })
                                .toList(growable: false),
                          })
                      .toList(growable: false),
              })
          .toList(growable: false),
    };
  }

  void _validate() {
    setState(() {
      _result = _importCurrentSource(_controller.text);
    });
  }

  void _loadPreset(String source, {String? fileName}) {
    setState(() {
      _fileName = fileName;
      _controller.value = TextEditingValue(
        text: source,
        selection: TextSelection.collapsed(offset: source.length),
      );
      _result = _importCurrentSource(source);
      _selectedTab = _SceneProgramSheetTab.script;
    });
  }

  Future<void> _pasteSceneProgramFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final source = clipboard?.text?.trim();
    if (!mounted) {
      return;
    }
    if (source == null || source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard is empty. Copy a Scene Program JSON first.'),
        ),
      );
      return;
    }
    setState(() {
      _fileName = null;
      _controller.value = TextEditingValue(
        text: source,
        selection: TextSelection.collapsed(offset: source.length),
      );
      _result = _importCurrentSource(source);
      _selectedTab = _SceneProgramSheetTab.script;
    });
  }

  Future<void> _loadAssetPreset(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
    if (!mounted) {
      return;
    }
    _loadPreset(source, fileName: assetPath.split('/').last);
  }

  void _selectTab(_SceneProgramSheetTab tab) {
    setState(() {
      _selectedTab = tab;
      _generationErrorMessage = null;
    });
  }

  void _selectSceneAgentProfile(ReFusionSceneAgentProfile profile) {
    setState(() {
      _selectedSceneAgentProfile = profile;
      _generationPreview = null;
      _generationErrorMessage = null;
    });
  }

  Future<void> _generateSceneProgram() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _generationErrorMessage = 'Write a scene prompt before Generate.';
      });
      return;
    }
    final preview = _sceneAgentCatalog.buildRequestPreview(
      profile: _selectedSceneAgentProfile,
      prompt: prompt,
      durationMs: 4200,
      canvasWidth: widget.canvasSize.width.round(),
      canvasHeight: widget.canvasSize.height.round(),
      frameRate: 30,
    );
    setState(() {
      _isGenerating = true;
      _generationPreview = preview;
      _generationErrorMessage = null;
    });
    try {
      final generated = await _sceneAgentService.generateSceneProgram(
        profile: _selectedSceneAgentProfile,
        prompt: prompt,
        durationMs: 4200,
        canvasWidth: widget.canvasSize.width.round(),
        canvasHeight: widget.canvasSize.height.round(),
        frameRate: 30,
      );
      if (!mounted) {
        return;
      }
      final imported = _importCurrentSource(generated.sceneProgramJson);
      setState(() {
        _isGenerating = false;
        _fileName = null;
        _controller.value = TextEditingValue(
          text: generated.sceneProgramJson,
          selection: TextSelection.collapsed(
            offset: generated.sceneProgramJson.length,
          ),
        );
        _result = imported;
        _selectedTab = _SceneProgramSheetTab.script;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isGenerating = false;
        _generationErrorMessage =
            'Scene generation timed out. The model did not finish in time; try a shorter prompt or switch provider, then Generate again.';
      });
    } on KieSceneProgramAgentException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isGenerating = false;
        _generationErrorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isGenerating = false;
        _generationErrorMessage = 'Scene generation failed: $error';
      });
    }
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
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
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
    if (_selectedTab != _SceneProgramSheetTab.script || _isGenerating) {
      return;
    }
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
    final canApply = _selectedTab == _SceneProgramSheetTab.script &&
        isValid &&
        !_isGenerating;
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
                      onPressed: canApply ? _done : null,
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
                        'Import Scene Program',
                        style: TextStyle(
                          color: FxPalette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_selectedTab == _SceneProgramSheetTab.script) ...[
                      _SceneProgramActionButton(
                        icon: Icons.content_paste_rounded,
                        label: 'Paste',
                        onTap: _pasteSceneProgramFromClipboard,
                      ),
                      const SizedBox(width: 8),
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
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: _SceneProgramTabButton(
                        selected: _selectedTab == _SceneProgramSheetTab.script,
                        icon: Icons.data_object_rounded,
                        label: 'Script',
                        onTap: () => _selectTab(_SceneProgramSheetTab.script),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SceneProgramTabButton(
                        selected:
                            _selectedTab == _SceneProgramSheetTab.generate,
                        icon: Icons.auto_awesome_rounded,
                        label: 'Generate',
                        onTap: () => _selectTab(_SceneProgramSheetTab.generate),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedTab == _SceneProgramSheetTab.generate
                        ? 'Generate a full editable scene with Codex or Claude Opus. The generated JSON appears in Script after completion.'
                        : _fileName == null
                            ? 'Semantic Blueprint is the professional path. Raw SceneProgram import is blocked in strict mode.'
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
              const SizedBox(height: 12),
              Expanded(
                child: _selectedTab == _SceneProgramSheetTab.generate
                    ? _SceneGeneratePane(
                        safeBottom: safeBottom,
                        promptController: _promptController,
                        profiles: ReFusionSceneAgentProviderCatalog.profiles,
                        selectedProfile: _selectedSceneAgentProfile,
                        onSelectProfile: _selectSceneAgentProfile,
                        onGenerate:
                            _isGenerating ? null : _generateSceneProgram,
                        isGenerating: _isGenerating,
                        generationErrorMessage: _generationErrorMessage,
                        preview: _generationPreview,
                      )
                    : _SceneScriptPane(
                        safeBottom: safeBottom,
                        controller: _controller,
                        result: result,
                        onChanged: () {
                          setState(() {
                            _result = null;
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneScriptPane extends StatelessWidget {
  const _SceneScriptPane({
    required this.safeBottom,
    required this.controller,
    required this.result,
    required this.onChanged,
  });

  final double safeBottom;
  final TextEditingController controller;
  final ReFusionSceneProgramAuthoringResult? result;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
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
            controller: controller,
            onChanged: (_) => onChanged(),
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
    );
  }
}

class _SceneGeneratePane extends StatelessWidget {
  const _SceneGeneratePane({
    required this.safeBottom,
    required this.promptController,
    required this.profiles,
    required this.selectedProfile,
    required this.onSelectProfile,
    required this.onGenerate,
    required this.isGenerating,
    required this.generationErrorMessage,
    required this.preview,
  });

  final double safeBottom;
  final TextEditingController promptController;
  final List<ReFusionSceneAgentProfile> profiles;
  final ReFusionSceneAgentProfile selectedProfile;
  final ValueChanged<ReFusionSceneAgentProfile> onSelectProfile;
  final VoidCallback? onGenerate;
  final bool isGenerating;
  final String? generationErrorMessage;
  final ReFusionSceneAgentRequestPreview? preview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        (safeBottom > 0 ? safeBottom : 12) + 12,
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final profile in profiles)
              _SceneProgramTabButton(
                selected: profile.id == selectedProfile.id,
                icon: profile.id.contains('claude')
                    ? Icons.psychology_alt_rounded
                    : Icons.terminal_rounded,
                label: profile.shortLabel,
                onTap: () => onSelectProfile(profile),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: FxPalette.surfaceRaised.withOpacity(0.84),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FxPalette.dividerSoft),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: TextField(
            controller: promptController,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            maxLines: null,
            minLines: 7,
            style: const TextStyle(
              color: FxPalette.textPrimary,
              fontSize: 14,
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration.collapsed(
              hintText: 'Describe the full editable scene...',
              hintStyle: TextStyle(
                color: FxPalette.textFaint,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SceneProgramActionButton(
          icon: isGenerating ? null : Icons.auto_awesome_rounded,
          label: isGenerating ? 'Generating...' : 'Generate',
          isBusy: isGenerating,
          onTap: onGenerate,
        ),
        if (isGenerating) ...[
          const SizedBox(height: 10),
          const _SceneProgramProgressCard(
            title: 'Generating scene',
            message:
                'The selected model is writing a Director Plan and editable Scene Program. Keep this sheet open until the generated JSON appears in Script.',
          ),
        ],
        const SizedBox(height: 14),
        _SceneProgramInfoCard(
          icon: Icons.memory_rounded,
          title: selectedProfile.label,
          message: selectedProfile.recommendedUse,
          accent: const Color(0xFF8DD7FF),
        ),
        if (preview != null) ...[
          const SizedBox(height: 10),
          _SceneProgramInfoCard(
            icon: Icons.rule_folder_rounded,
            title: 'Director contract ready',
            message:
                'Generate will request ordered beats, semantic components, and editable Scene Program JSON from ${preview!.profile.shortLabel}.',
            accent: const Color(0xFF45D483),
          ),
        ],
        if (generationErrorMessage != null) ...[
          const SizedBox(height: 10),
          _SceneProgramInfoCard(
            icon: Icons.error_outline_rounded,
            title: 'Generation failed',
            message: generationErrorMessage!,
            accent: const Color(0xFFFF6B6B),
          ),
        ],
      ],
    );
  }
}

class _SceneProgramTabButton extends StatelessWidget {
  const _SceneProgramTabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.13)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? FxPalette.textMuted : FxPalette.dividerSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? FxPalette.textPrimary : FxPalette.textMuted,
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? FxPalette.textPrimary : FxPalette.textMuted,
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

class _SceneProgramActionButton extends StatelessWidget {
  const _SceneProgramActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isBusy = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool isBusy;

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
            ] else if (isBusy) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FxPalette.textPrimary,
                ),
              ),
              const SizedBox(width: 7),
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
          title: value.hasWarnings ? 'Ready with notes' : 'Ready',
          message:
              '${value.program?.name ?? 'Scene'} -> ${value.project?.scenes.single.layers.length ?? 0} layers, ${value.channels.length} channels. '
              '${value.hasWarnings ? 'Only non-blocking notes remain.' : 'Geometry and readability checks passed.'} '
              'Tap the check mark to place it on the editable timeline.',
          accent: value.hasWarnings
              ? const Color(0xFF9BC1FF)
              : const Color(0xFF45D483),
        ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SceneProgramIssueList(
            icon: Icons.warning_amber_rounded,
            title: 'Non-blocking notes',
            issues: warnings,
            accent: const Color(0xFF9BC1FF),
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

class _SceneProgramProgressCard extends StatelessWidget {
  const _SceneProgramProgressCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

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
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFF8DD7FF),
            ),
          ),
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
