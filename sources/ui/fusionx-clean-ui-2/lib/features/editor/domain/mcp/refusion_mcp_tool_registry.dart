import 'package:meta/meta.dart';

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
  static const Map<String, String> _toolAliases = <String, String>{
    'get_active_context': 'refusion.get_active_context',
    'get_project_state': 'refusion.get_project_state',
    'get_timeline_summary': 'refusion.get_timeline_summary',
    'get_selection': 'refusion.get_selection',
    'get_command_status': 'refusion.get_command_status',
    'capture_preview_frame': 'refusion.capture_preview_frame',
    'get_security_profile': 'refusion.get_security_profile',
    'get_host_compatibility': 'refusion.get_host_compatibility',
    'validate_scene_program': 'refusion.validate_scene_program',
    'author_scene_program': 'refusion.author_scene_program',
    'apply_scene_program': 'refusion.apply_scene_program',
    'create_project': 'refusion.create_project',
    'apply_motion_patch': 'refusion.apply_motion_patch',
    'keyframe_edit': 'refusion.keyframe_edit',
    'set_element_transform': 'refusion.set_element_transform',
    'insert_layer': 'refusion.insert_layer',
    'split_at_playhead': 'refusion.split_at_playhead',
    'trim_layer': 'refusion.trim_layer',
    'move_layer': 'refusion.move_layer',
    'delete_layer': 'refusion.delete_layer',
    'dry_run_command': 'refusion.dry_run_command',
    'commit_transaction': 'refusion.commit_transaction',
    'undo_transaction': 'refusion.undo_transaction',
    'redo_transaction': 'refusion.redo_transaction',
    'list_recent_transactions': 'refusion.list_recent_transactions',
  };

  static const List<RefusionMcpToolDescriptor> _defaultTools =
      <RefusionMcpToolDescriptor>[
    RefusionMcpToolDescriptor(
      name: 'refusion.get_active_context',
      title: 'Get Active Context',
      description:
          'Return active project/composition context and live editor status.',
      capability: RefusionMcpCapability.projectRead,
    ),
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
      name: 'refusion.get_command_status',
      title: 'Get Command Status',
      description: 'Return command/transaction status in the active session.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.capture_preview_frame',
      title: 'Capture Preview Frame',
      description: 'Capture preview frame for visual inspection.',
      capability: RefusionMcpCapability.previewRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_security_profile',
      title: 'Get Security Profile',
      description:
          'Return MCP hardening profile such as limits and restricted capabilities.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_host_compatibility',
      title: 'Get Host Compatibility',
      description:
          'Return host support matrix and connection requirements (Codex/Claude/ChatGPT).',
      capability: RefusionMcpCapability.timelineRead,
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
      name: 'refusion.create_project',
      title: 'Create Project',
      description: 'Create a new active project context for MCP authoring.',
      capability: RefusionMcpCapability.projectRead,
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
      name: 'refusion.insert_layer',
      title: 'Insert Layer',
      description: 'Insert a new timeline layer in the active scene.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.split_at_playhead',
      title: 'Split At Playhead',
      description: 'Split a layer at playhead or an explicit split time.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.trim_layer',
      title: 'Trim Layer',
      description: 'Trim layer start and end time in timeline.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.move_layer',
      title: 'Move Layer',
      description: 'Move layer order or time position in timeline.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.delete_layer',
      title: 'Delete Layer',
      description: 'Delete a layer after explicit confirmation.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.dry_run_command',
      title: 'Dry Run Command',
      description: 'Execute any registered command in dry-run mode.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.commit_transaction',
      title: 'Commit Transaction',
      description: 'Commit a pending transaction by transactionId.',
      capability: RefusionMcpCapability.timelineWrite,
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
    RefusionMcpToolDescriptor(
      name: 'refusion.list_recent_transactions',
      title: 'List Recent Transactions',
      description: 'Return committed and pending transaction summaries.',
      capability: RefusionMcpCapability.timelineRead,
    ),
  ];

  List<RefusionMcpToolDescriptor> list() {
    final descriptors = _tools.values.toList(growable: false);
    descriptors.sort((left, right) => left.name.compareTo(right.name));
    return descriptors;
  }

  RefusionMcpToolDescriptor? find(String name) {
    final normalizedName = normalizeToolName(name);
    if (normalizedName == null) {
      return null;
    }
    return _tools[normalizedName];
  }

  String? normalizeToolName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final aliasMatch = _toolAliases[trimmed];
    if (aliasMatch != null) {
      return aliasMatch;
    }
    if (trimmed.startsWith('refusion.')) {
      return _tools.containsKey(trimmed) ? trimmed : null;
    }
    final prefixed = 'refusion.$trimmed';
    return _tools.containsKey(prefixed) ? prefixed : null;
  }
}
