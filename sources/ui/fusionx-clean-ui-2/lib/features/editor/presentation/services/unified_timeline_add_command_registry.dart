import 'package:flutter/material.dart';

enum UnifiedTimelineAddScope {
  root,
  scene,
  layer,
}

class UnifiedTimelineAddCommand {
  const UnifiedTimelineAddCommand({
    required this.id,
    required this.scope,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isReady = true,
  });

  final String id;
  final UnifiedTimelineAddScope scope;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isReady;
}

class UnifiedTimelineAddCommandRegistry {
  const UnifiedTimelineAddCommandRegistry();

  static const UnifiedTimelineAddCommand newScene = UnifiedTimelineAddCommand(
    id: 'newScene',
    scope: UnifiedTimelineAddScope.root,
    icon: Icons.auto_awesome_motion_rounded,
    title: 'New Scene',
    subtitle: 'Insert an empty scene clip in the composition timeline.',
  );

  static const UnifiedTimelineAddCommand sceneScript =
      UnifiedTimelineAddCommand(
    id: 'sceneScript',
    scope: UnifiedTimelineAddScope.root,
    icon: Icons.auto_fix_high_rounded,
    title: 'Scene Script',
    subtitle: 'Generate and insert a scripted scene clip.',
  );

  static const UnifiedTimelineAddCommand videoLayer = UnifiedTimelineAddCommand(
    id: 'videoLayer',
    scope: UnifiedTimelineAddScope.root,
    icon: Icons.video_library_rounded,
    title: 'Video Layer',
    subtitle: 'Import video as a composition layer.',
  );

  static const UnifiedTimelineAddCommand imageLayer = UnifiedTimelineAddCommand(
    id: 'imageLayer',
    scope: UnifiedTimelineAddScope.root,
    icon: Icons.image_rounded,
    title: 'Image Layer',
    subtitle: 'Import image as a composition layer.',
  );

  static const UnifiedTimelineAddCommand textLayer = UnifiedTimelineAddCommand(
    id: 'textLayer',
    scope: UnifiedTimelineAddScope.root,
    icon: Icons.text_fields_rounded,
    title: 'Text Layer',
    subtitle: 'Add editable text to the active timeline scope.',
  );

  static const UnifiedTimelineAddCommand audioLayer = UnifiedTimelineAddCommand(
    id: 'audioLayer',
    scope: UnifiedTimelineAddScope.root,
    icon: Icons.graphic_eq_rounded,
    title: 'Audio Layer',
    subtitle: 'Import music or voice as an audio layer.',
  );

  static const UnifiedTimelineAddCommand shapeLayer = UnifiedTimelineAddCommand(
    id: 'shapeLayer',
    scope: UnifiedTimelineAddScope.scene,
    icon: Icons.square_outlined,
    title: 'Shape Layer',
    subtitle: 'Add shape primitives inside the active scene.',
  );

  static const UnifiedTimelineAddCommand adjustmentLayer =
      UnifiedTimelineAddCommand(
    id: 'adjustmentLayer',
    scope: UnifiedTimelineAddScope.layer,
    icon: Icons.tune_rounded,
    title: 'Adjustment Layer',
    subtitle: 'Create a time-bounded effect container.',
    isReady: true,
  );

  static const List<UnifiedTimelineAddCommand> _root =
      <UnifiedTimelineAddCommand>[
    newScene,
    sceneScript,
    videoLayer,
    imageLayer,
    textLayer,
    audioLayer,
  ];

  static const List<UnifiedTimelineAddCommand> _scene =
      <UnifiedTimelineAddCommand>[
    videoLayer,
    imageLayer,
    textLayer,
    shapeLayer,
    audioLayer,
  ];

  static const List<UnifiedTimelineAddCommand> _layer =
      <UnifiedTimelineAddCommand>[
    textLayer,
    adjustmentLayer,
  ];

  List<UnifiedTimelineAddCommand> commandsForScope(
    UnifiedTimelineAddScope scope,
  ) {
    switch (scope) {
      case UnifiedTimelineAddScope.root:
        return _root;
      case UnifiedTimelineAddScope.scene:
        return _scene;
      case UnifiedTimelineAddScope.layer:
        return _layer;
    }
  }
}
