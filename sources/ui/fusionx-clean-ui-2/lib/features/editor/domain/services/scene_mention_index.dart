import 'package:flutter/foundation.dart';

import '../models/composition_scene_clip_models.dart';
import '../models/professional_motion_models.dart';

enum SceneMentionEntityKind {
  sceneClip,
  element,
}

enum SceneMentionIndexIssueCode {
  missingScene,
  duplicateDisplayName,
}

@immutable
class SceneMentionIndexIssue {
  const SceneMentionIndexIssue({
    required this.code,
    required this.message,
    this.sceneId,
    this.mentionId,
  });

  final SceneMentionIndexIssueCode code;
  final String message;
  final String? sceneId;
  final String? mentionId;
}

@immutable
class SceneMentionEntity {
  SceneMentionEntity({
    required this.mentionId,
    required this.entityKind,
    required this.targetId,
    required this.displayName,
    required this.baseDisplayName,
    required this.typeLabel,
    required this.sceneId,
    this.layerId,
    this.elementId,
    this.sceneClipId,
    this.thumbnailKey,
    List<MotionPropertyDefinition> supportedProperties =
        const <MotionPropertyDefinition>[],
  }) : supportedProperties = List.unmodifiable(supportedProperties);

  final String mentionId;
  final SceneMentionEntityKind entityKind;
  final String targetId;
  final String displayName;
  final String baseDisplayName;
  final String typeLabel;
  final String sceneId;
  final String? layerId;
  final String? elementId;
  final String? sceneClipId;
  final String? thumbnailKey;
  final List<MotionPropertyDefinition> supportedProperties;

  bool get isAnimatable => supportedProperties.isNotEmpty;
}

@immutable
class SceneMentionIndexResult {
  SceneMentionIndexResult({
    required List<SceneMentionEntity> entities,
    List<SceneMentionIndexIssue> issues = const <SceneMentionIndexIssue>[],
  })  : entities = List.unmodifiable(entities),
        issues = List.unmodifiable(issues);

  final List<SceneMentionEntity> entities;
  final List<SceneMentionIndexIssue> issues;

  bool get hasIssues => issues.isNotEmpty;

  SceneMentionEntity? entityByMentionId(String mentionId) {
    for (final entity in entities) {
      if (entity.mentionId == mentionId) {
        return entity;
      }
    }
    return null;
  }

  bool containsMentionId(String mentionId) =>
      entityByMentionId(mentionId) != null;
}

class SceneMentionIndex {
  const SceneMentionIndex();

  SceneMentionIndexResult buildForScene({
    required MotionProjectModel project,
    required String sceneId,
    List<CompositionSceneClipModel> sceneClips =
        const <CompositionSceneClipModel>[],
  }) {
    final scene = _sceneById(project, sceneId);
    if (scene == null) {
      return SceneMentionIndexResult(
        entities: const <SceneMentionEntity>[],
        issues: <SceneMentionIndexIssue>[
          SceneMentionIndexIssue(
            code: SceneMentionIndexIssueCode.missingScene,
            message: 'Scene `$sceneId` does not exist.',
            sceneId: sceneId,
          ),
        ],
      );
    }

    final draftEntities = <SceneMentionEntity>[
      for (final clip in sceneClips)
        _sceneClipEntity(
          sceneId: scene.id,
          clip: clip,
        ),
      for (final layer in scene.layers)
        for (final element in layer.elements)
          _elementEntity(
            project: project,
            scene: scene,
            layer: layer,
            element: element,
          ),
    ];

    return _disambiguateDisplayNames(
      entities: draftEntities,
      sceneId: scene.id,
    );
  }

  MotionSceneModel? _sceneById(MotionProjectModel project, String sceneId) {
    for (final scene in project.scenes) {
      if (scene.id == sceneId) {
        return scene;
      }
    }
    return null;
  }

  SceneMentionEntity _sceneClipEntity({
    required String sceneId,
    required CompositionSceneClipModel clip,
  }) {
    final label = _firstNonEmpty(
      <String?>[
        clip.name,
        clip.metadata['label'],
        'Scene ${clip.id}',
      ],
    );
    return SceneMentionEntity(
      mentionId: 'sceneClip:${clip.id}',
      entityKind: SceneMentionEntityKind.sceneClip,
      targetId: clip.id,
      displayName: label,
      baseDisplayName: label,
      typeLabel: 'Scene Clip',
      sceneId: sceneId,
      sceneClipId: clip.id,
      thumbnailKey: clip.metadata['thumbnail'],
    );
  }

  SceneMentionEntity _elementEntity({
    required MotionProjectModel project,
    required MotionSceneModel scene,
    required MotionLayerModel layer,
    required MotionElementModel element,
  }) {
    final label = _firstNonEmpty(
      <String?>[
        element.name,
        element.sourceBinding?.label,
        layer.name,
        _fallbackElementName(element),
      ],
    );
    return SceneMentionEntity(
      mentionId: 'element:${element.id}',
      entityKind: SceneMentionEntityKind.element,
      targetId: element.id,
      displayName: label,
      baseDisplayName: label,
      typeLabel: _elementTypeLabel(element),
      sceneId: scene.id,
      layerId: layer.id,
      elementId: element.id,
      thumbnailKey: element.sourceBinding?.assetId,
      supportedProperties: _supportedPropertiesForElement(element),
    );
  }

  SceneMentionIndexResult _disambiguateDisplayNames({
    required List<SceneMentionEntity> entities,
    required String sceneId,
  }) {
    final countsByName = <String, int>{};
    for (final entity in entities) {
      final key = entity.baseDisplayName.trim().toLowerCase();
      countsByName[key] = (countsByName[key] ?? 0) + 1;
    }

    final seenByName = <String, int>{};
    final issues = <SceneMentionIndexIssue>[];
    final resolved = <SceneMentionEntity>[];
    for (final entity in entities) {
      final key = entity.baseDisplayName.trim().toLowerCase();
      final count = countsByName[key] ?? 0;
      if (count <= 1) {
        resolved.add(entity);
        continue;
      }

      final nextIndex = (seenByName[key] ?? 0) + 1;
      seenByName[key] = nextIndex;
      if (nextIndex == 1) {
        issues.add(
          SceneMentionIndexIssue(
            code: SceneMentionIndexIssueCode.duplicateDisplayName,
            message:
                'Mention display name `${entity.baseDisplayName}` is used by '
                '$count entities and was disambiguated.',
            sceneId: sceneId,
            mentionId: entity.mentionId,
          ),
        );
      }
      resolved.add(
        SceneMentionEntity(
          mentionId: entity.mentionId,
          entityKind: entity.entityKind,
          targetId: entity.targetId,
          displayName: '${entity.baseDisplayName} ($nextIndex)',
          baseDisplayName: entity.baseDisplayName,
          typeLabel: entity.typeLabel,
          sceneId: entity.sceneId,
          layerId: entity.layerId,
          elementId: entity.elementId,
          sceneClipId: entity.sceneClipId,
          thumbnailKey: entity.thumbnailKey,
          supportedProperties: entity.supportedProperties,
        ),
      );
    }

    return SceneMentionIndexResult(
      entities: resolved,
      issues: issues,
    );
  }

  List<MotionPropertyDefinition> _supportedPropertiesForElement(
    MotionElementModel element,
  ) {
    final properties = <MotionPropertyDefinition>[
      MotionPropertyCatalog.positionX,
      MotionPropertyCatalog.positionY,
      MotionPropertyCatalog.scaleX,
      MotionPropertyCatalog.scaleY,
      MotionPropertyCatalog.rotationDegrees,
      MotionPropertyCatalog.opacity,
      MotionPropertyCatalog.blurAmount,
    ];

    switch (element.kind) {
      case MotionElementKind.text:
        properties.addAll(<MotionPropertyDefinition>[
          MotionPropertyCatalog.fontSize,
          MotionPropertyCatalog.letterSpacing,
          MotionPropertyCatalog.revealProgress,
        ]);
      case MotionElementKind.shape:
      case MotionElementKind.mask:
        properties.addAll(<MotionPropertyDefinition>[
          MotionPropertyCatalog.width,
          MotionPropertyCatalog.height,
          MotionPropertyCatalog.cornerRadius,
          MotionPropertyCatalog.shadowOpacity,
          MotionPropertyCatalog.shadowBlur,
          MotionPropertyCatalog.shadowOffsetX,
          MotionPropertyCatalog.shadowOffsetY,
          MotionPropertyCatalog.shadowSpread,
        ]);
      case MotionElementKind.image:
      case MotionElementKind.videoClip:
        properties.add(MotionPropertyCatalog.cropRect);
      case MotionElementKind.camera:
        properties
          ..clear()
          ..addAll(<MotionPropertyDefinition>[
            MotionPropertyCatalog.cameraPanX,
            MotionPropertyCatalog.cameraPanY,
            MotionPropertyCatalog.cameraZoom,
            MotionPropertyCatalog.cameraRotation,
          ]);
      case MotionElementKind.audioClip:
        properties
          ..clear()
          ..add(MotionPropertyCatalog.opacity);
      case MotionElementKind.effectControl:
        properties
          ..clear()
          ..add(MotionPropertyCatalog.shakeAmount);
    }

    return properties;
  }

  String _fallbackElementName(MotionElementModel element) {
    switch (element.kind) {
      case MotionElementKind.videoClip:
        return 'Video ${element.id}';
      case MotionElementKind.image:
        return 'Image ${element.id}';
      case MotionElementKind.text:
        return 'Text ${element.id}';
      case MotionElementKind.shape:
        return 'Shape ${element.id}';
      case MotionElementKind.audioClip:
        return 'Audio ${element.id}';
      case MotionElementKind.camera:
        return 'Camera ${element.id}';
      case MotionElementKind.mask:
        return 'Mask ${element.id}';
      case MotionElementKind.effectControl:
        return 'Control ${element.id}';
    }
  }

  String _elementTypeLabel(MotionElementModel element) {
    switch (element.kind) {
      case MotionElementKind.videoClip:
        return 'Video';
      case MotionElementKind.image:
        return 'Image';
      case MotionElementKind.text:
        return 'Text';
      case MotionElementKind.shape:
        return _shapeTypeLabel(element.shapeKind);
      case MotionElementKind.audioClip:
        return 'Audio';
      case MotionElementKind.camera:
        return 'Camera';
      case MotionElementKind.mask:
        return 'Mask';
      case MotionElementKind.effectControl:
        return 'Control';
    }
  }

  String _shapeTypeLabel(MotionShapeKind? shapeKind) {
    switch (shapeKind) {
      case MotionShapeKind.rectangle:
        return 'Rectangle';
      case MotionShapeKind.roundedRectangle:
        return 'Rounded Rectangle';
      case MotionShapeKind.circle:
        return 'Circle';
      case MotionShapeKind.line:
        return 'Line';
      case MotionShapeKind.mask:
        return 'Shape Mask';
      case MotionShapeKind.customPath:
        return 'Custom Shape';
      case null:
        return 'Shape';
    }
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return 'Untitled';
  }
}
