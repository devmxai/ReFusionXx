import 'package:flutter/foundation.dart';

import 'refusion_mcp_capability.dart';

@immutable
class RefusionMcpToolDescriptor {
  const RefusionMcpToolDescriptor({
    required this.name,
    required this.title,
    required this.description,
    required this.capability,
    this.mutating = false,
  });

  final String name;
  final String title;
  final String description;
  final RefusionMcpCapability capability;
  final bool mutating;
}

class RefusionMcpToolRegistry {
  RefusionMcpToolRegistry({
    List<RefusionMcpToolDescriptor> tools = _defaultTools,
  }) : _tools = Map<String, RefusionMcpToolDescriptor>.fromEntries(
          tools.map((tool) => MapEntry<String, RefusionMcpToolDescriptor>(
                tool.name,
                tool,
              )),
        );

  final Map<String, RefusionMcpToolDescriptor> _tools;

  static const List<RefusionMcpToolDescriptor> _defaultTools =
      <RefusionMcpToolDescriptor>[
    RefusionMcpToolDescriptor(
      name: 'refusion.get_project_state',
      title: 'Get Project State',
      description: 'Return active project metadata and revision.',
      capability: RefusionMcpCapability.projectRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_timeline_summary',
      title: 'Get Timeline Summary',
      description: 'Return compact timeline rows and durations.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_selection',
      title: 'Get Selection',
      description: 'Return selected objects and editable capabilities.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.capture_preview_frame',
      title: 'Capture Preview Frame',
      description: 'Capture preview frame for visual inspection.',
      capability: RefusionMcpCapability.previewRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.validate_scene_program',
      title: 'Validate Scene Program',
      description: 'Validate SceneProgram schema and safety.',
      capability: RefusionMcpCapability.sceneWrite,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.author_scene_program',
      title: 'Author Scene Program',
      description: 'Author scene program using ReFusion pipeline.',
      capability: RefusionMcpCapability.sceneWrite,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.apply_scene_program',
      title: 'Apply Scene Program',
      description: 'Apply a valid scene program transactionally.',
      capability: RefusionMcpCapability.sceneWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.apply_motion_patch',
      title: 'Apply Motion Patch',
      description: 'Apply declarative motion patch to selected targets.',
      capability: RefusionMcpCapability.motionWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.keyframe_edit',
      title: 'Keyframe Edit',
      description: 'Add or modify keyframes through unified operations.',
      capability: RefusionMcpCapability.motionWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.set_element_transform',
      title: 'Set Element Transform',
      description: 'Set static or keyframed transform values.',
      capability: RefusionMcpCapability.motionWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.undo_transaction',
      title: 'Undo Transaction',
      description: 'Undo last committed MCP transaction.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.redo_transaction',
      title: 'Redo Transaction',
      description: 'Redo last undone MCP transaction.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
  ];

  List<RefusionMcpToolDescriptor> list() {
    final descriptors = _tools.values.toList(growable: false);
    descriptors.sort((left, right) => left.name.compareTo(right.name));
    return descriptors;
  }

  RefusionMcpToolDescriptor? find(String name) {
    return _tools[name];
  }
}
