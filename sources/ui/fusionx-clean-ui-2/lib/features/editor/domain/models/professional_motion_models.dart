import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../presentation/models/timeline_time.dart';

enum MotionTargetKind {
  project,
  scene,
  layer,
  element,
}

enum MotionLayerKind {
  video,
  image,
  text,
  shape,
  audio,
  camera,
  effectControl,
}

enum MotionElementKind {
  videoClip,
  image,
  text,
  shape,
  audioClip,
  camera,
  mask,
  effectControl,
}

enum MotionShapeKind {
  rectangle,
  roundedRectangle,
  circle,
  line,
  mask,
  customPath,
}

enum MotionBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  plus,
}

enum MotionPropertyGroup {
  transform,
  visual,
  crop,
  shape,
  text,
  camera,
  audio,
  effect,
}

enum MotionPropertyValueKind {
  scalar,
  integer,
  boolean,
  stringValue,
  colorArgb,
  point2D,
  size2D,
  rect,
  enumValue,
}

enum MotionSourceKind {
  video,
  image,
  audio,
  generatedText,
  generatedShape,
  generatedCamera,
  generatedControl,
}

@immutable
class MotionPoint2D {
  const MotionPoint2D({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  MotionPoint2D copyWith({
    double? x,
    double? y,
  }) {
    return MotionPoint2D(
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

@immutable
class MotionSize2D {
  const MotionSize2D({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  MotionSize2D copyWith({
    double? width,
    double? height,
  }) {
    return MotionSize2D(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

@immutable
class MotionRect {
  const MotionRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  MotionRect copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    return MotionRect(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

@immutable
class MotionProjectFormat {
  const MotionProjectFormat({
    required this.canvasSize,
    this.pixelAspectRatio = 1.0,
  });

  final MotionSize2D canvasSize;
  final double pixelAspectRatio;
}

@immutable
class MotionFrameRate {
  const MotionFrameRate({
    required this.numerator,
    required this.denominator,
  })  : assert(numerator > 0),
        assert(denominator > 0);

  final int numerator;
  final int denominator;

  double get framesPerSecond => numerator / denominator;
}

@immutable
class MotionPropertyValue {
  const MotionPropertyValue._({
    required this.kind,
    required this.rawValue,
  });

  const MotionPropertyValue.scalar(double value)
      : this._(kind: MotionPropertyValueKind.scalar, rawValue: value);

  const MotionPropertyValue.integer(int value)
      : this._(kind: MotionPropertyValueKind.integer, rawValue: value);

  const MotionPropertyValue.boolean(bool value)
      : this._(kind: MotionPropertyValueKind.boolean, rawValue: value);

  const MotionPropertyValue.stringValue(String value)
      : this._(kind: MotionPropertyValueKind.stringValue, rawValue: value);

  const MotionPropertyValue.colorArgb(int value)
      : this._(kind: MotionPropertyValueKind.colorArgb, rawValue: value);

  const MotionPropertyValue.point2D(MotionPoint2D value)
      : this._(kind: MotionPropertyValueKind.point2D, rawValue: value);

  const MotionPropertyValue.size2D(MotionSize2D value)
      : this._(kind: MotionPropertyValueKind.size2D, rawValue: value);

  const MotionPropertyValue.rect(MotionRect value)
      : this._(kind: MotionPropertyValueKind.rect, rawValue: value);

  const MotionPropertyValue.enumValue(String value)
      : this._(kind: MotionPropertyValueKind.enumValue, rawValue: value);

  final MotionPropertyValueKind kind;
  final Object rawValue;
}

@immutable
class MotionPropertyPath {
  const MotionPropertyPath({
    required this.group,
    required this.name,
    this.component,
  });

  final MotionPropertyGroup group;
  final String name;
  final String? component;

  String get canonicalKey {
    if (component == null || component!.isEmpty) {
      return '${group.name}.$name';
    }
    return '${group.name}.$name.$component';
  }
}

@immutable
class MotionPropertyDefinition {
  MotionPropertyDefinition({
    required this.id,
    required this.path,
    required this.valueKind,
    required List<MotionTargetKind> supportedTargets,
    required this.defaultValue,
    this.isAnimatable = true,
  }) : supportedTargets = List.unmodifiable(supportedTargets);

  final String id;
  final MotionPropertyPath path;
  final MotionPropertyValueKind valueKind;
  final List<MotionTargetKind> supportedTargets;
  final MotionPropertyValue defaultValue;
  final bool isAnimatable;
}

@immutable
class MotionPropertyTarget {
  const MotionPropertyTarget({
    required this.kind,
    required this.targetId,
    this.projectId,
    this.sceneId,
    this.layerId,
    this.elementId,
  });

  final MotionTargetKind kind;
  final String targetId;
  final String? projectId;
  final String? sceneId;
  final String? layerId;
  final String? elementId;

  String get canonicalAddress {
    switch (kind) {
      case MotionTargetKind.project:
        return 'project:$targetId';
      case MotionTargetKind.scene:
        return 'scene:$targetId';
      case MotionTargetKind.layer:
        return 'layer:$targetId';
      case MotionTargetKind.element:
        return 'element:$targetId';
    }
  }
}

@immutable
class MotionPropertyAssignment {
  const MotionPropertyAssignment({
    required this.target,
    required this.definition,
    required this.value,
  });

  final MotionPropertyTarget target;
  final MotionPropertyDefinition definition;
  final MotionPropertyValue value;
}

@immutable
class MotionElementSourceBinding {
  MotionElementSourceBinding({
    required this.kind,
    required this.sourceId,
    this.assetId,
    this.label,
    this.sourceRange,
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = Map.unmodifiable(metadata);

  final MotionSourceKind kind;
  final String sourceId;
  final String? assetId;
  final String? label;
  final TimelineTimeRange? sourceRange;
  final Map<String, String> metadata;
}

@immutable
class MotionElementModel {
  MotionElementModel({
    required this.id,
    required this.layerId,
    required this.kind,
    required this.localRange,
    this.name,
    this.isEnabled = true,
    this.shapeKind,
    this.sourceBinding,
    List<MotionPropertyAssignment> properties =
        const <MotionPropertyAssignment>[],
  }) : properties = List.unmodifiable(properties);

  final String id;
  final String layerId;
  final MotionElementKind kind;
  final TimelineTimeRange localRange;
  final String? name;
  final bool isEnabled;
  final MotionShapeKind? shapeKind;
  final MotionElementSourceBinding? sourceBinding;
  final List<MotionPropertyAssignment> properties;

  MotionElementModel copyWith({
    String? id,
    String? layerId,
    MotionElementKind? kind,
    TimelineTimeRange? localRange,
    String? name,
    bool? isEnabled,
    MotionShapeKind? shapeKind,
    MotionElementSourceBinding? sourceBinding,
    List<MotionPropertyAssignment>? properties,
  }) {
    return MotionElementModel(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      kind: kind ?? this.kind,
      localRange: localRange ?? this.localRange,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      shapeKind: shapeKind ?? this.shapeKind,
      sourceBinding: sourceBinding ?? this.sourceBinding,
      properties: properties ?? this.properties,
    );
  }
}

@immutable
class MotionLayerModel {
  MotionLayerModel({
    required this.id,
    required this.sceneId,
    required this.kind,
    required this.visibleRange,
    required List<MotionElementModel> elements,
    this.name,
    this.zIndex = 0,
    this.isEnabled = true,
    this.blendMode = MotionBlendMode.normal,
    List<MotionPropertyAssignment> properties =
        const <MotionPropertyAssignment>[],
  })  : elements = List.unmodifiable(elements),
        properties = List.unmodifiable(properties);

  final String id;
  final String sceneId;
  final MotionLayerKind kind;
  final TimelineTimeRange visibleRange;
  final String? name;
  final int zIndex;
  final bool isEnabled;
  final MotionBlendMode blendMode;
  final List<MotionElementModel> elements;
  final List<MotionPropertyAssignment> properties;

  MotionLayerModel copyWith({
    String? id,
    String? sceneId,
    MotionLayerKind? kind,
    TimelineTimeRange? visibleRange,
    String? name,
    int? zIndex,
    bool? isEnabled,
    MotionBlendMode? blendMode,
    List<MotionElementModel>? elements,
    List<MotionPropertyAssignment>? properties,
  }) {
    return MotionLayerModel(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      kind: kind ?? this.kind,
      visibleRange: visibleRange ?? this.visibleRange,
      name: name ?? this.name,
      zIndex: zIndex ?? this.zIndex,
      isEnabled: isEnabled ?? this.isEnabled,
      blendMode: blendMode ?? this.blendMode,
      elements: elements ?? this.elements,
      properties: properties ?? this.properties,
    );
  }
}

@immutable
class MotionSceneModel {
  MotionSceneModel({
    required this.id,
    required this.projectRange,
    required List<MotionLayerModel> layers,
    this.name,
    this.cameraLayerId,
    this.isEnabled = true,
    List<MotionPropertyAssignment> properties =
        const <MotionPropertyAssignment>[],
    Map<String, String> metadata = const <String, String>{},
  })  : layers = List.unmodifiable(layers),
        properties = List.unmodifiable(properties),
        metadata = Map.unmodifiable(metadata);

  final String id;
  final TimelineTimeRange projectRange;
  final List<MotionLayerModel> layers;
  final String? name;
  final String? cameraLayerId;
  final bool isEnabled;
  final List<MotionPropertyAssignment> properties;
  final Map<String, String> metadata;

  TimelineTime get durationTime => projectRange.duration;

  MotionSceneModel copyWith({
    String? id,
    TimelineTimeRange? projectRange,
    List<MotionLayerModel>? layers,
    String? name,
    String? cameraLayerId,
    bool? isEnabled,
    List<MotionPropertyAssignment>? properties,
    Map<String, String>? metadata,
  }) {
    return MotionSceneModel(
      id: id ?? this.id,
      projectRange: projectRange ?? this.projectRange,
      layers: layers ?? this.layers,
      name: name ?? this.name,
      cameraLayerId: cameraLayerId ?? this.cameraLayerId,
      isEnabled: isEnabled ?? this.isEnabled,
      properties: properties ?? this.properties,
      metadata: metadata ?? this.metadata,
    );
  }
}

@immutable
class MotionProjectModel {
  MotionProjectModel({
    required this.id,
    required this.format,
    required this.frameRate,
    required List<MotionSceneModel> scenes,
    this.name,
    Map<String, String> metadata = const <String, String>{},
  })  : scenes = List.unmodifiable(scenes),
        metadata = Map.unmodifiable(metadata);

  final String id;
  final MotionProjectFormat format;
  final MotionFrameRate frameRate;
  final List<MotionSceneModel> scenes;
  final String? name;
  final Map<String, String> metadata;

  TimelineTime get durationTime {
    var duration = TimelineTime.zero;
    for (final scene in scenes) {
      if (scene.projectRange.endExclusive > duration) {
        duration = scene.projectRange.endExclusive;
      }
    }
    return duration;
  }

  MotionProjectModel copyWith({
    String? id,
    MotionProjectFormat? format,
    MotionFrameRate? frameRate,
    List<MotionSceneModel>? scenes,
    String? name,
    Map<String, String>? metadata,
  }) {
    return MotionProjectModel(
      id: id ?? this.id,
      format: format ?? this.format,
      frameRate: frameRate ?? this.frameRate,
      scenes: scenes ?? this.scenes,
      name: name ?? this.name,
      metadata: metadata ?? this.metadata,
    );
  }
}

class MotionPropertyCatalog {
  MotionPropertyCatalog._();

  static final MotionPropertyDefinition positionX = MotionPropertyDefinition(
    id: 'transform.position.x',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.transform,
      name: 'position',
      component: 'x',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition positionY = MotionPropertyDefinition(
    id: 'transform.position.y',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.transform,
      name: 'position',
      component: 'y',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition scaleX = MotionPropertyDefinition(
    id: 'transform.scale.x',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.transform,
      name: 'scale',
      component: 'x',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(1),
  );

  static final MotionPropertyDefinition scaleY = MotionPropertyDefinition(
    id: 'transform.scale.y',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.transform,
      name: 'scale',
      component: 'y',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(1),
  );

  static final MotionPropertyDefinition rotationDegrees =
      MotionPropertyDefinition(
    id: 'transform.rotation.degrees',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.transform,
      name: 'rotation',
      component: 'degrees',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition opacity = MotionPropertyDefinition(
    id: 'visual.opacity',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'opacity',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[
      MotionTargetKind.layer,
      MotionTargetKind.element,
    ],
    defaultValue: const MotionPropertyValue.scalar(1),
  );

  static final MotionPropertyDefinition blurAmount = MotionPropertyDefinition(
    id: 'visual.blur.amount',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'blur',
      component: 'amount',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition blurHorizontal =
      MotionPropertyDefinition(
    id: 'visual.blur.horizontal',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'blur',
      component: 'horizontal',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(100),
  );

  static final MotionPropertyDefinition blurVertical = MotionPropertyDefinition(
    id: 'visual.blur.vertical',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'blur',
      component: 'vertical',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(100),
  );

  static final MotionPropertyDefinition blurMix = MotionPropertyDefinition(
    id: 'visual.blur.mix',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'blur',
      component: 'mix',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(100),
  );

  static final MotionPropertyDefinition blurEdgeMode = MotionPropertyDefinition(
    id: 'visual.blur.edgeMode',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'blur',
      component: 'edgeMode',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition blurCrop = MotionPropertyDefinition(
    id: 'visual.blur.crop',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.visual,
      name: 'blur',
      component: 'crop',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition cropRect = MotionPropertyDefinition(
    id: 'crop.rect',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.crop,
      name: 'rect',
    ),
    valueKind: MotionPropertyValueKind.rect,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.rect(
      MotionRect(left: 0, top: 0, width: 1, height: 1),
    ),
  );

  static final MotionPropertyDefinition width = MotionPropertyDefinition(
    id: 'shape.width',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.shape,
      name: 'width',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition height = MotionPropertyDefinition(
    id: 'shape.height',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.shape,
      name: 'height',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition cornerRadius = MotionPropertyDefinition(
    id: 'shape.cornerRadius',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.shape,
      name: 'cornerRadius',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition fontSize = MotionPropertyDefinition(
    id: 'text.fontSize',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.text,
      name: 'fontSize',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(16),
  );

  static final MotionPropertyDefinition fontWeight = MotionPropertyDefinition(
    id: 'text.fontWeight',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.text,
      name: 'fontWeight',
    ),
    valueKind: MotionPropertyValueKind.integer,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.integer(700),
  );

  static final MotionPropertyDefinition letterSpacing =
      MotionPropertyDefinition(
    id: 'text.letterSpacing',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.text,
      name: 'letterSpacing',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition revealProgress =
      MotionPropertyDefinition(
    id: 'text.revealProgress',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.text,
      name: 'revealProgress',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[MotionTargetKind.element],
    defaultValue: const MotionPropertyValue.scalar(1),
  );

  static final MotionPropertyDefinition cameraPanX = MotionPropertyDefinition(
    id: 'camera.pan.x',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.camera,
      name: 'pan',
      component: 'x',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[
      MotionTargetKind.scene,
      MotionTargetKind.layer,
      MotionTargetKind.element,
    ],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition cameraPanY = MotionPropertyDefinition(
    id: 'camera.pan.y',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.camera,
      name: 'pan',
      component: 'y',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[
      MotionTargetKind.scene,
      MotionTargetKind.layer,
      MotionTargetKind.element,
    ],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition cameraZoom = MotionPropertyDefinition(
    id: 'camera.zoom',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.camera,
      name: 'zoom',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[
      MotionTargetKind.scene,
      MotionTargetKind.layer,
      MotionTargetKind.element,
    ],
    defaultValue: const MotionPropertyValue.scalar(1),
  );

  static final MotionPropertyDefinition cameraRotation =
      MotionPropertyDefinition(
    id: 'camera.rotation',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.camera,
      name: 'rotation',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[
      MotionTargetKind.scene,
      MotionTargetKind.layer,
      MotionTargetKind.element,
    ],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final MotionPropertyDefinition shakeAmount = MotionPropertyDefinition(
    id: 'effect.shake.amount',
    path: const MotionPropertyPath(
      group: MotionPropertyGroup.effect,
      name: 'shake',
      component: 'amount',
    ),
    valueKind: MotionPropertyValueKind.scalar,
    supportedTargets: const <MotionTargetKind>[
      MotionTargetKind.layer,
      MotionTargetKind.element,
    ],
    defaultValue: const MotionPropertyValue.scalar(0),
  );

  static final UnmodifiableListView<MotionPropertyDefinition> all =
      UnmodifiableListView<MotionPropertyDefinition>(<MotionPropertyDefinition>[
    positionX,
    positionY,
    scaleX,
    scaleY,
    rotationDegrees,
    opacity,
    blurAmount,
    blurHorizontal,
    blurVertical,
    blurMix,
    blurEdgeMode,
    blurCrop,
    cropRect,
    width,
    height,
    cornerRadius,
    fontSize,
    letterSpacing,
    revealProgress,
    cameraPanX,
    cameraPanY,
    cameraZoom,
    cameraRotation,
    shakeAmount,
  ]);
}
