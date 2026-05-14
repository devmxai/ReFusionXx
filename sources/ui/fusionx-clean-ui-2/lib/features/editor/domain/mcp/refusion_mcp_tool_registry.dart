import 'refusion_mcp_capability.dart';

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
    'update_layer': 'refusion.update_layer',
    'update_text': 'refusion.update_layer',
    'edit_text': 'refusion.update_layer',
    'set_text_style': 'refusion.set_text_style',
    'update_exposed_control': 'refusion.update_exposed_control',
    'set_template_control': 'refusion.update_exposed_control',
    'apply_motion_patch': 'refusion.apply_motion_patch',
    'keyframe_edit': 'refusion.keyframe_edit',
    'set_element_transform': 'refusion.set_element_transform',
    'trim_clip': 'refusion.trim_clip',
    'split_clip': 'refusion.split_clip',
    'set_layer_mask': 'refusion.set_layer_mask',
    'set_border': 'refusion.set_border',
    'set_glow': 'refusion.set_glow',
    'set_layer_style': 'refusion.set_layer_style',
    'position_at_anchor': 'refusion.position_at_anchor',
    'align_to_anchor': 'refusion.position_at_anchor',
    'place_at_anchor': 'refusion.position_at_anchor',
    'align_to': 'refusion.align_to',
    'fit_in_zone': 'refusion.fit_in_zone',
    'scale_to': 'refusion.scale_to',
    'center_in': 'refusion.center_in',
    'preview_change': 'refusion.layout.preview_change',
    'validate_intent': 'refusion.layout.validate_intent',
    'detect_overlaps': 'refusion.layout.detect_overlaps',
    'get_project_snapshot': 'refusion.get_project_snapshot',
    'get_composition_spec': 'refusion.get_composition_spec',
    'get_timeline_graph': 'refusion.get_timeline_graph',
    'get_media_assets': 'refusion.get_media_assets',
    'get_scene_layers': 'refusion.get_scene_layers',
    'get_canvas_metadata': 'refusion.get_canvas_metadata',
    'get_element_geometry': 'refusion.get_element_geometry',
    'get_visual_layout_summary': 'refusion.get_visual_layout_summary',
    'evaluate_frame': 'refusion.evaluate_frame',
    'explain_capabilities': 'refusion.explain_capabilities',
    'list_components': 'refusion.list_components',
    'describe_component': 'refusion.describe_component',
    'list_effects': 'refusion.list_effects',
    'describe_effect': 'refusion.describe_effect',
    'list_motion_recipes': 'refusion.list_motion_recipes',
    'describe_motion_recipe': 'refusion.describe_motion_recipe',
    'list_templates': 'refusion.list_templates',
    'describe_template': 'refusion.describe_template',
    'list_icons': 'refusion.list_icons',
    'describe_icon': 'refusion.describe_icon',
    'get_launch_readiness': 'refusion.get_launch_readiness',
    'insert_layer': 'refusion.insert_layer',
    'split_at_playhead': 'refusion.split_clip',
    'trim_layer': 'refusion.trim_clip',
    'split_layer': 'refusion.split_clip',
    'trim_layer_clip': 'refusion.trim_clip',
    'set_mask': 'refusion.set_layer_mask',
    'apply_mask': 'refusion.set_layer_mask',
    'set_rounded_crop': 'refusion.set_layer_mask',
    'set_layer_border': 'refusion.set_border',
    'set_layer_glow': 'refusion.set_glow',
    'surface.position.at_anchor': 'refusion.position_at_anchor',
    'surface.align_to': 'refusion.align_to',
    'surface.fit_in_zone': 'refusion.fit_in_zone',
    'surface.scale_to': 'refusion.scale_to',
    'surface.center_in': 'refusion.center_in',
    'refusion.surface.position.at_anchor': 'refusion.position_at_anchor',
    'refusion.surface.align_to': 'refusion.align_to',
    'refusion.surface.fit_in_zone': 'refusion.fit_in_zone',
    'refusion.surface.scale_to': 'refusion.scale_to',
    'refusion.surface.center_in': 'refusion.center_in',
    'refusion.layout.preview_change': 'refusion.layout.preview_change',
    'refusion.layout.validate_intent': 'refusion.layout.validate_intent',
    'refusion.layout.detect_overlaps': 'refusion.layout.detect_overlaps',
    'refusion.update_text': 'refusion.update_layer',
    'refusion.edit_text': 'refusion.update_layer',
    'refusion.set_template_control': 'refusion.update_exposed_control',
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
      name: 'refusion.get_project_snapshot',
      title: 'Get Project Snapshot',
      description:
          'Return composition truth graph including assets, timeline, scene layers, and motion channels.',
      capability: RefusionMcpCapability.projectRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_composition_spec',
      title: 'Get Composition Spec',
      description: 'Return composition dimensions, duration, and fps.',
      capability: RefusionMcpCapability.projectRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_timeline_graph',
      title: 'Get Timeline Graph',
      description:
          'Return timeline tracks, clips, source ranges, and ordering for active composition.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_media_assets',
      title: 'Get Media Assets',
      description: 'Return media asset inventory with duration and dimensions.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_scene_layers',
      title: 'Get Scene Layers',
      description:
          'Return scene layer graph with transforms, masks, style, and source bindings.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_canvas_metadata',
      title: 'Get Canvas Metadata',
      description:
          'Return canvas dimensions, safe zones, anchors, and coordinate metadata.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_element_geometry',
      title: 'Get Element Geometry',
      description:
          'Return evaluated bounds and spatial diagnostics for a target layer or clip.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.get_visual_layout_summary',
      title: 'Get Visual Layout Summary',
      description:
          'Return layout summary with overlap and safe-area diagnostics.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.evaluate_frame',
      title: 'Evaluate Frame',
      description: 'Return visibility/layout summary at a timeline time.',
      capability: RefusionMcpCapability.previewRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.explain_capabilities',
      title: 'Explain Capabilities',
      description: 'Return supported and blocked MCP operations.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.list_components',
      title: 'List Components',
      description: 'List registry-backed semantic components.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.describe_component',
      title: 'Describe Component',
      description: 'Describe one component by id from creative registry.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.list_effects',
      title: 'List Effects',
      description: 'List registry-backed effects.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.describe_effect',
      title: 'Describe Effect',
      description: 'Describe one effect by id from creative registry.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.list_motion_recipes',
      title: 'List Motion Recipes',
      description: 'List registry-backed motion recipes.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.describe_motion_recipe',
      title: 'Describe Motion Recipe',
      description: 'Describe one motion recipe by id from creative registry.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.list_templates',
      title: 'List Templates',
      description: 'List registry-backed templates.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.describe_template',
      title: 'Describe Template',
      description: 'Describe one template by id from creative registry.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.list_icons',
      title: 'List Icons',
      description: 'List registry-backed icon tokens.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.describe_icon',
      title: 'Describe Icon',
      description: 'Describe one icon token by id from creative registry.',
      capability: RefusionMcpCapability.timelineRead,
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
      name: 'refusion.update_layer',
      title: 'Update Layer',
      description:
          'Patch an existing layer after target resolution; never inserts duplicates for edit intent.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.set_text_style',
      title: 'Set Text Style',
      description:
          'Patch typography, color, transform, or motion intent on a resolved text layer.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.update_exposed_control',
      title: 'Update Exposed Control',
      description:
          'Update a template exposed control value through canonical template command flow.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.split_at_playhead',
      title: 'Split At Playhead',
      description: 'Split the selected clip at the current playhead time.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.trim_layer',
      title: 'Trim Layer',
      description: 'Trim the selected layer or clip in the timeline.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.split_clip',
      title: 'Split Clip',
      description: 'Split a clip at an explicit timeline time.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.trim_clip',
      title: 'Trim Clip',
      description:
          'Trim clip timeline/source ranges in the active composition.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.set_layer_mask',
      title: 'Set Layer Mask',
      description: 'Apply circle/rounded/rect mask metadata on a target layer.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.set_border',
      title: 'Set Border',
      description: 'Apply border style metadata on a target layer.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.set_glow',
      title: 'Set Glow',
      description: 'Apply glow style metadata on a target layer.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.set_layer_style',
      title: 'Set Layer Style',
      description: 'Apply style patch metadata on a target layer.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.position_at_anchor',
      title: 'Position At Anchor',
      description:
          'Place a target layer at semantic anchors with safe-area and padding options.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.align_to',
      title: 'Align To',
      description:
          'Align target layer to canvas/zone/anchor/another layer using semantic alignment tokens.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.fit_in_zone',
      title: 'Fit In Zone',
      description:
          'Fit target layer into layout zone (contain/cover/fill/stretch) with optional safe-area guards.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.scale_to',
      title: 'Scale To',
      description:
          'Scale target layer via exact/percent/fitWidth/fitHeight/contain/cover modes.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.center_in',
      title: 'Center In',
      description:
          'Center target layer in canvas/title-safe/action-safe or custom zone.',
      capability: RefusionMcpCapability.timelineWrite,
      mutating: true,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.layout.preview_change',
      title: 'Layout Preview Change',
      description:
          'Simulate geometry impact of a proposed patch without mutating project state.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.layout.validate_intent',
      title: 'Layout Validate Intent',
      description:
          'Validate current/proposed layout intent and return blockers with suggestions.',
      capability: RefusionMcpCapability.timelineRead,
    ),
    RefusionMcpToolDescriptor(
      name: 'refusion.layout.detect_overlaps',
      title: 'Layout Detect Overlaps',
      description:
          'Return overlap diagnostics for visible layers at a target timeline time.',
      capability: RefusionMcpCapability.timelineRead,
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
    RefusionMcpToolDescriptor(
      name: 'refusion.get_launch_readiness',
      title: 'Get Launch Readiness',
      description:
          'Evaluate launch readiness gates from registry, skill validity, and parity contracts.',
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
