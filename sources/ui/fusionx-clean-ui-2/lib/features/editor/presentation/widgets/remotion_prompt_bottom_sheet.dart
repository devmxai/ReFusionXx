import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/services/scene_mention_index.dart';
import '../../domain/services/scene_mention_prompt_context.dart';

class RemotionPromptBottomSheet extends StatefulWidget {
  const RemotionPromptBottomSheet({
    super.key,
    required this.mentionEntities,
    required this.scopeDurationMs,
  });

  final List<SceneMentionEntity> mentionEntities;
  final int scopeDurationMs;

  @override
  State<RemotionPromptBottomSheet> createState() =>
      _RemotionPromptBottomSheetState();
}

class _RemotionPromptBottomSheetState extends State<RemotionPromptBottomSheet> {
  final SceneMentionPromptContextBuilder _contextBuilder =
      const SceneMentionPromptContextBuilder();
  late final TextEditingController _promptController;
  final Set<String> _selectedMentionIds = <String>{};
  String _mentionQuery = '';
  bool _showMentionSuggestions = false;
  SceneMentionPromptContext? _context;
  String? _generatedPayloadPreview;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _context = _buildContext();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  SceneMentionPromptContext _buildContext() {
    return _contextBuilder.build(
      prompt: _promptController.text,
      entities: widget.mentionEntities,
      selectedMentionIds: _selectedMentionIds.toList(growable: false),
    );
  }

  List<SceneMentionEntity> get _matchingEntities {
    if (!_showMentionSuggestions) {
      return const <SceneMentionEntity>[];
    }
    final query = _mentionQuery;
    final matches = widget.mentionEntities.where((entity) {
      if (query.isEmpty) {
        return true;
      }
      return entity.displayName.toLowerCase().contains(query) ||
          entity.typeLabel.toLowerCase().contains(query);
    }).toList(growable: false);
    return matches.take(7).toList(growable: false);
  }

  void _handlePromptChanged(String _) {
    setState(() {
      _updateMentionQuery();
      _context = _buildContext();
      _generatedPayloadPreview = null;
    });
  }

  void _updateMentionQuery() {
    final selection = _promptController.selection;
    final text = _promptController.text;
    final cursor =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (cursor > text.length) {
      _mentionQuery = '';
      _showMentionSuggestions = false;
      return;
    }
    final beforeCursor = text.substring(0, cursor);
    final triggerIndex = beforeCursor.lastIndexOf('@');
    if (triggerIndex < 0) {
      _mentionQuery = '';
      _showMentionSuggestions = false;
      return;
    }
    final afterTrigger = beforeCursor.substring(triggerIndex + 1);
    if (afterTrigger.contains(RegExp(r'\s')) || afterTrigger.contains('}')) {
      _mentionQuery = '';
      _showMentionSuggestions = false;
      return;
    }
    _mentionQuery = afterTrigger.replaceFirst('{', '').trim().toLowerCase();
    _showMentionSuggestions = true;
  }

  void _insertMention(SceneMentionEntity entity) {
    final token = _contextBuilder.mentionTokenFor(entity);
    final text = _promptController.text;
    final selection = _promptController.selection;
    final cursor =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final safeCursor = cursor.clamp(0, text.length).toInt();
    final beforeCursor = text.substring(0, safeCursor);
    final triggerIndex = beforeCursor.lastIndexOf('@');
    final replaceStart = triggerIndex >= 0 ? triggerIndex : safeCursor;
    final before = text.substring(0, replaceStart);
    final after = text.substring(safeCursor);
    final separator = after.startsWith(' ') || after.isEmpty ? '' : ' ';
    final nextText = '$before$token $separator$after';
    final nextCursor =
        (before.length + token.length + 1).clamp(0, nextText.length).toInt();
    _promptController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    setState(() {
      _selectedMentionIds.add(entity.mentionId);
      _mentionQuery = '';
      _showMentionSuggestions = false;
      _context = _buildContext();
      _generatedPayloadPreview = null;
    });
  }

  void _generatePayload() {
    final nextContext = _buildContext();
    final payload = <String, Object?>{
      'provider': 'kie.ai',
      'intent': 'generate-refusion-motion-patch',
      'expectedSchema': 'refusion.motion-patch/v1',
      'prompt': nextContext.prompt,
      'timeline': <String, Object?>{
        'scopeDurationMs': widget.scopeDurationMs,
        'timeBasis': 'scope',
      },
      'targets': nextContext.mentions
          .map((mention) => mention.toJson())
          .toList(growable: false),
      'constraints': const <String, Object?>{
        'jsonOnly': true,
        'noExecutableCode': true,
        'useOnlyMentionedTargets': true,
        'outputMustValidateBeforeApply': true,
      },
    };
    const encoder = JsonEncoder.withIndent('  ');
    setState(() {
      _context = nextContext;
      _generatedPayloadPreview = encoder.convert(payload);
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.78).clamp(500.0, 760.0);
    final currentContext = _context ?? _buildContext();
    final suggestions = _matchingEntities;
    final canGenerate = currentContext.mentions.isNotEmpty &&
        !currentContext.hasBrokenMentions &&
        currentContext.prompt.trim().isNotEmpty;
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: FxPalette.textPrimary,
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
                        'Remotion',
                        style: TextStyle(
                          color: FxPalette.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _RemotionGenerateButton(
                      enabled: canGenerate,
                      onTap: canGenerate ? _generatePayload : null,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Animate existing scene layers with @mentions. This checkpoint prepares the KIE.ai request payload; apply is gated by motion-patch validation.',
                    style: TextStyle(
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
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    (safeBottom > 0 ? safeBottom : 12) + 12,
                  ),
                  children: [
                    _PromptEditorCard(
                      controller: _promptController,
                      onChanged: _handlePromptChanged,
                      hasTargets: widget.mentionEntities.isNotEmpty,
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _MentionSuggestionList(
                        entities: suggestions,
                        onTap: _insertMention,
                      ),
                    ],
                    if (currentContext.mentions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final mention in currentContext.mentions)
                            _MentionChip(entity: mention.entity),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    _MentionPayloadSummary(context: currentContext),
                    if (_generatedPayloadPreview != null) ...[
                      const SizedBox(height: 12),
                      _GeneratedPayloadPreview(
                        payload: _generatedPayloadPreview!,
                      ),
                    ],
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

class _PromptEditorCard extends StatelessWidget {
  const _PromptEditorCard({
    required this.controller,
    required this.onChanged,
    required this.hasTargets,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool hasTargets;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FxPalette.surfaceRaised.withOpacity(0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FxPalette.dividerSoft),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: 6,
        maxLines: 9,
        style: const TextStyle(
          color: FxPalette.textPrimary,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration.collapsed(
          hintText: hasTargets
              ? 'Type @ and choose a layer, then describe the exact motion...'
              : 'No mentionable scene layers yet. Add/open a scene first.',
          hintStyle: const TextStyle(
            color: FxPalette.textFaint,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RemotionGenerateButton extends StatelessWidget {
  const _RemotionGenerateButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? FxPalette.accent.withOpacity(0.18)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? FxPalette.accent.withOpacity(0.42)
                : FxPalette.dividerSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: enabled
                  ? FxPalette.textPrimary
                  : FxPalette.textMuted.withOpacity(0.55),
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              'Generate',
              style: TextStyle(
                color: enabled
                    ? FxPalette.textPrimary
                    : FxPalette.textMuted.withOpacity(0.55),
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

class _MentionSuggestionList extends StatelessWidget {
  const _MentionSuggestionList({
    required this.entities,
    required this.onTap,
  });

  final List<SceneMentionEntity> entities;
  final ValueChanged<SceneMentionEntity> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FxPalette.dividerSoft),
      ),
      child: Column(
        children: [
          for (final entity in entities)
            _MentionSuggestionTile(
              entity: entity,
              onTap: () => onTap(entity),
            ),
        ],
      ),
    );
  }
}

class _MentionSuggestionTile extends StatelessWidget {
  const _MentionSuggestionTile({
    required this.entity,
    required this.onTap,
  });

  final SceneMentionEntity entity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              _iconFor(entity),
              color: FxPalette.textPrimary,
              size: 17,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FxPalette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entity.typeLabel} · ${entity.supportedProperties.length} properties',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FxPalette.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline_rounded,
              color: FxPalette.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MentionChip extends StatelessWidget {
  const _MentionChip({required this.entity});

  final SceneMentionEntity entity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FxPalette.accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FxPalette.accent.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconFor(entity),
            color: FxPalette.textPrimary,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            entity.displayName,
            style: const TextStyle(
              color: FxPalette.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MentionPayloadSummary extends StatelessWidget {
  const _MentionPayloadSummary({required this.context});

  final SceneMentionPromptContext context;

  @override
  Widget build(BuildContext context) {
    if (this.context.hasBrokenMentions) {
      return _RemotionStatusCard(
        icon: Icons.warning_amber_rounded,
        title: 'Broken mention',
        message: this.context.issues.first.message,
        accent: const Color(0xFFFFC857),
      );
    }
    if (this.context.mentions.isEmpty) {
      return const _RemotionStatusCard(
        icon: Icons.alternate_email_rounded,
        title: 'Choose motion targets',
        message:
            'Type @ to attach real scene layers before generating a motion patch.',
      );
    }
    return _RemotionStatusCard(
      icon: Icons.verified_rounded,
      title: 'Payload ready',
      message:
          '${this.context.mentions.length} target${this.context.mentions.length == 1 ? '' : 's'} resolved. Generate will prepare a KIE.ai request for `refusion.motion-patch/v1`.',
      accent: const Color(0xFF45D483),
    );
  }
}

class _GeneratedPayloadPreview extends StatelessWidget {
  const _GeneratedPayloadPreview({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FxPalette.dividerSoft),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.integration_instructions_rounded,
                color: FxPalette.textPrimary,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'KIE.ai request payload',
                style: TextStyle(
                  color: FxPalette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            payload,
            style: const TextStyle(
              color: FxPalette.textMuted,
              fontSize: 10,
              height: 1.35,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemotionStatusCard extends StatelessWidget {
  const _RemotionStatusCard({
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FxPalette.dividerSoft),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
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
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

IconData _iconFor(SceneMentionEntity entity) {
  switch (entity.entityKind) {
    case SceneMentionEntityKind.sceneClip:
      return Icons.auto_awesome_motion_rounded;
    case SceneMentionEntityKind.element:
      switch (entity.typeLabel) {
        case 'Text':
          return Icons.text_fields_rounded;
        case 'Image':
          return Icons.image_outlined;
        case 'Video':
          return Icons.videocam_rounded;
        case 'Camera':
          return Icons.photo_camera_outlined;
        case 'Audio':
          return Icons.music_note_rounded;
        default:
          return Icons.category_rounded;
      }
  }
}
