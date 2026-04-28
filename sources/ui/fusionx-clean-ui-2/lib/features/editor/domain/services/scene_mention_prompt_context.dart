import 'package:flutter/foundation.dart';

import 'scene_mention_index.dart';

enum SceneMentionPromptIssueCode {
  unresolvedMention,
}

@immutable
class SceneMentionPromptIssue {
  const SceneMentionPromptIssue({
    required this.code,
    required this.message,
    required this.token,
  });

  final SceneMentionPromptIssueCode code;
  final String message;
  final String token;
}

@immutable
class SceneMentionPromptResolvedEntity {
  const SceneMentionPromptResolvedEntity({
    required this.token,
    required this.entity,
  });

  final String token;
  final SceneMentionEntity entity;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'token': token,
      'mentionId': entity.mentionId,
      'entityKind': entity.entityKind.name,
      'targetId': entity.targetId,
      'sceneId': entity.sceneId,
      'layerId': entity.layerId,
      'elementId': entity.elementId,
      'sceneClipId': entity.sceneClipId,
      'type': entity.typeLabel,
      'supportedProperties': entity.supportedProperties
          .map((property) => property.id)
          .toList(growable: false),
    };
  }
}

@immutable
class SceneMentionPromptContext {
  SceneMentionPromptContext({
    required this.prompt,
    required List<SceneMentionPromptResolvedEntity> mentions,
    List<SceneMentionPromptIssue> issues = const <SceneMentionPromptIssue>[],
  })  : mentions = List.unmodifiable(mentions),
        issues = List.unmodifiable(issues);

  final String prompt;
  final List<SceneMentionPromptResolvedEntity> mentions;
  final List<SceneMentionPromptIssue> issues;

  bool get hasBrokenMentions => issues.isNotEmpty;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'prompt': prompt,
      'mentions':
          mentions.map((mention) => mention.toJson()).toList(growable: false),
      'brokenMentions': issues
          .map((issue) => <String, Object?>{
                'token': issue.token,
                'message': issue.message,
              })
          .toList(growable: false),
    };
  }
}

class SceneMentionPromptContextBuilder {
  const SceneMentionPromptContextBuilder();

  static final RegExp _mentionTokenPattern =
      RegExp(r'@\{([^}]+)\}|@([A-Za-z0-9_.-]+)');

  SceneMentionPromptContext build({
    required String prompt,
    required List<SceneMentionEntity> entities,
    List<String> selectedMentionIds = const <String>[],
  }) {
    final entitiesByMentionId = <String, SceneMentionEntity>{
      for (final entity in entities) entity.mentionId: entity,
    };
    final entitiesByDisplayName = <String, SceneMentionEntity>{
      for (final entity in entities) _normalize(entity.displayName): entity,
      for (final entity in entities) _normalize(entity.baseDisplayName): entity,
    };

    final resolvedById = <String, SceneMentionPromptResolvedEntity>{};
    final issues = <SceneMentionPromptIssue>[];
    for (final match in _mentionTokenPattern.allMatches(prompt)) {
      final token = match.group(0)!;
      final rawLabel = match.group(1) ?? match.group(2) ?? '';
      final entity = entitiesByDisplayName[_normalize(rawLabel)];
      if (entity == null) {
        issues.add(
          SceneMentionPromptIssue(
            code: SceneMentionPromptIssueCode.unresolvedMention,
            message: 'Mention `$token` does not match an element in scope.',
            token: token,
          ),
        );
        continue;
      }
      resolvedById[entity.mentionId] = SceneMentionPromptResolvedEntity(
        token: token,
        entity: entity,
      );
    }

    for (final mentionId in selectedMentionIds) {
      final entity = entitiesByMentionId[mentionId];
      if (entity == null) {
        issues.add(
          SceneMentionPromptIssue(
            code: SceneMentionPromptIssueCode.unresolvedMention,
            message: 'Selected mention `$mentionId` no longer exists.',
            token: mentionId,
          ),
        );
        continue;
      }
      resolvedById.putIfAbsent(
        entity.mentionId,
        () => SceneMentionPromptResolvedEntity(
          token: '@{${entity.displayName}}',
          entity: entity,
        ),
      );
    }

    return SceneMentionPromptContext(
      prompt: prompt,
      mentions: resolvedById.values.toList(growable: false),
      issues: issues,
    );
  }

  String mentionTokenFor(SceneMentionEntity entity) {
    return '@{${entity.displayName}}';
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}
