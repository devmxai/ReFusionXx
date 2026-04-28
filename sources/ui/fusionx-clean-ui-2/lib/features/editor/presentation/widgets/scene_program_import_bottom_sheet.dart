import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/professional_motion_animation_models.dart';
import '../../domain/models/professional_motion_models.dart';
import '../../domain/models/professional_motion_text_models.dart';
import '../../domain/models/refusion_scene_program_models.dart';
import '../../domain/services/kie_scene_program_agent_service.dart';
import '../../domain/services/refusion_scene_agent_provider_catalog.dart';
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
    required this.textAnimationBindings,
    required this.authoringResult,
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
      textAnimationBindings: result.textAnimationBindings,
      authoringResult: result,
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
}

enum _SceneProgramSheetTab {
  script,
  generate,
}

class _SceneProgramImportBottomSheetState
    extends State<SceneProgramImportBottomSheet> {
  final ReFusionSceneProgramAuthoringService _authoringService =
      const ReFusionSceneProgramAuthoringService();
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
    _controller = TextEditingController(text: _codexIntroSceneProgram);
    _promptController = TextEditingController(
      text:
          'Create a cinematic Codex intro on a white canvas. A black Mac-style app icon appears, morphs into a prompt input bar, types "Build up for my business", presses send, then the send circle expands into a clean white screen with "Welcome to Codex".',
    );
    _selectedSceneAgentProfile =
        ReFusionSceneAgentProviderCatalog.profiles.first;
    _result = _importCurrentSource(_codexIntroSceneProgram);
  }

  @override
  void dispose() {
    _controller.dispose();
    _promptController.dispose();
    super.dispose();
  }

  ReFusionSceneProgramAuthoringResult _importCurrentSource(String source) {
    final String normalizedSource;
    try {
      normalizedSource = _sceneProgramSourceForImport(source);
    } on KieSceneProgramAgentException catch (error) {
      return ReFusionSceneProgramAuthoringResult(
        issues: <ReFusionSceneProgramIssue>[
          ReFusionSceneProgramIssue(
            severity: ReFusionSceneProgramIssueSeverity.error,
            message: error.message,
            path: 'source',
          ),
        ],
      );
    }
    return _authoringService.importSceneProgram(
      ReFusionSceneProgramAuthoringRequest(
        source: normalizedSource,
        fileName: _fileName,
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        canvasSize: widget.canvasSize,
      ),
    );
  }

  String _sceneProgramSourceForImport(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (!_looksLikeScenePayloadWrapper(trimmed)) {
      return trimmed;
    }
    try {
      return _sceneAgentService
          .extractSceneProgramPayloadFromContent(content: trimmed)
          .sceneProgramJson;
    } on KieSceneProgramAgentException {
      rethrow;
    } catch (_) {
      return trimmed;
    }
  }

  bool _looksLikeScenePayloadWrapper(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        return false;
      }
      return decoded.containsKey('directorPlan') ||
          decoded.containsKey('motionDirector') ||
          decoded.containsKey('sceneProgram') ||
          decoded.containsKey('program');
    } catch (_) {
      return false;
    }
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
      _selectedTab = _SceneProgramSheetTab.script;
    });
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
        _controller.text = generated.sceneProgramJson;
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
              if (_selectedTab == _SceneProgramSheetTab.script) ...[
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
                          icon: Icons.terminal_rounded,
                          label: 'Codex Intro',
                          onTap: () => _loadPreset(_codexIntroSceneProgram),
                        ),
                        _SceneProgramActionButton(
                          icon: Icons.horizontal_rule_rounded,
                          label: 'Line Reveal',
                          onTap: () => _loadPreset(_lineRevealSceneProgram),
                        ),
                        _SceneProgramActionButton(
                          icon: Icons.auto_awesome_motion_rounded,
                          label: 'Shape Text Wipe',
                          onTap: () => _loadPreset(_shapeTextWipeSceneProgram),
                        ),
                        _SceneProgramActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Prompt Bar',
                          onTap: () => _loadPreset(_promptInputSceneProgram),
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
              ],
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
