import 'dart:collection';

enum SceneRuntimeNodeType {
  sceneRoot,
  beatScope,
  group,
  component,
  slot,
  shape,
  text,
  icon,
  image,
  video,
  effectAttachment,
}

class SceneRuntimeNode {
  SceneRuntimeNode({
    required this.id,
    required this.nodeType,
    this.parentId,
    this.zOrder = 0,
    this.sourceComponentId,
    this.sourceLayerId,
    this.slotId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = UnmodifiableMapView<String, Object?>(metadata);

  final String id;
  final SceneRuntimeNodeType nodeType;
  final String? parentId;
  final int zOrder;
  final String? sourceComponentId;
  final String? sourceLayerId;
  final String? slotId;
  final Map<String, Object?> metadata;

  SceneRuntimeNode copyWith({
    String? id,
    SceneRuntimeNodeType? nodeType,
    String? parentId,
    bool clearParentId = false,
    int? zOrder,
    String? sourceComponentId,
    bool clearSourceComponentId = false,
    String? sourceLayerId,
    bool clearSourceLayerId = false,
    String? slotId,
    bool clearSlotId = false,
    Map<String, Object?>? metadata,
  }) {
    return SceneRuntimeNode(
      id: id ?? this.id,
      nodeType: nodeType ?? this.nodeType,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      zOrder: zOrder ?? this.zOrder,
      sourceComponentId: clearSourceComponentId
          ? null
          : (sourceComponentId ?? this.sourceComponentId),
      sourceLayerId:
          clearSourceLayerId ? null : (sourceLayerId ?? this.sourceLayerId),
      slotId: clearSlotId ? null : (slotId ?? this.slotId),
      metadata: metadata ?? this.metadata,
    );
  }
}
