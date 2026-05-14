import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/professional_motion_models.dart';
import '../models/timeline_time.dart';

class McpEditorLayerSnapshotBuilder {
  const McpEditorLayerSnapshotBuilder();

  List<Map<String, Object?>> buildProjectLayerSnapshots({
    required MotionProjectModel project,
    required MotionSize2D canvasSize,
  }) {
    final snapshots = <Map<String, Object?>>[];
    for (final scene in project.scenes) {
      if (!scene.isEnabled) {
        continue;
      }
      for (final layer in scene.layers) {
        if (!layer.isEnabled) {
          continue;
        }
        for (final element in layer.elements) {
          if (!element.isEnabled) {
            continue;
          }
          if (element.kind != MotionElementKind.text &&
              element.kind != MotionElementKind.shape) {
            continue;
          }
          final timingRange = _timingRangeForElement(
            scene: scene,
            element: element,
          );
          if (timingRange.endExclusive <= timingRange.start) {
            continue;
          }
          snapshots.add(
            _snapshotForElement(
              scene: scene,
              layer: layer,
              element: element,
              timingRange: timingRange,
              canvasSize: canvasSize,
            ),
          );
        }
      }
    }
    return List<Map<String, Object?>>.unmodifiable(snapshots);
  }

  Map<String, Object?> _snapshotForElement({
    required MotionSceneModel scene,
    required MotionLayerModel layer,
    required MotionElementModel element,
    required TimelineTimeRange timingRange,
    required MotionSize2D canvasSize,
  }) {
    final binding = element.sourceBinding;
    final metadata = binding?.metadata ?? const <String, String>{};
    final isText = element.kind == MotionElementKind.text;
    final isBackgroundRole = metadata['mcp.backgroundRole'] == 'canvas';
    final layerKind = isText
        ? 'text'
        : isBackgroundRole
            ? 'solid'
            : 'shape';
    final textValue = _textValueForElement(element);
    final label = _labelForElement(
      element: element,
      metadata: metadata,
      textValue: textValue,
      isBackgroundRole: isBackgroundRole,
    );
    final aliasSet = <String>{
      if ((metadata['mcp.remoteLayerAliases'] ?? '').trim().isNotEmpty)
        ...metadata['mcp.remoteLayerAliases']!
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      if ((metadata['mcp.remoteLayerId'] ?? '').trim().isNotEmpty)
        metadata['mcp.remoteLayerId']!,
      if ((metadata['mcp.remoteLayerName'] ?? '').trim().isNotEmpty)
        metadata['mcp.remoteLayerName']!,
      element.id,
      layer.id,
    };
    final positionX = _scalar(
      element,
      MotionPropertyCatalog.positionX,
      canvasSize.width / 2.0,
    );
    final positionY = _scalar(
      element,
      MotionPropertyCatalog.positionY,
      canvasSize.height / 2.0,
    );
    final width = isText
        ? _textWidthForElement(element)
        : isBackgroundRole
            ? canvasSize.width
            : _scalar(
                element,
                MotionPropertyCatalog.width,
                math.max(160.0, canvasSize.width * 0.22),
              );
    final height = isText
        ? _textHeightForElement(element)
        : isBackgroundRole
            ? canvasSize.height
            : _scalar(
                element,
                MotionPropertyCatalog.height,
                math.max(120.0, canvasSize.height * 0.12),
              );
    final colorArgb = _colorArgb(
      element,
      fallback: isText ? const Color(0xFF111111).value : 0xFFFFFFFF,
    );
    final colorHex = _hexColorFromArgb(colorArgb);
    final startMs = timingRange.start.inMilliseconds;
    final durationMs =
        math.max(1, timingRange.endExclusive.inMilliseconds - startMs);
    return <String, Object?>{
      'layerKind': layerKind,
      'type': layerKind,
      'kind': layerKind,
      'name': label,
      'startMs': startMs,
      'durationMs': durationMs,
      'zIndex': layer.zIndex,
      'payload': <String, Object?>{
        'syncSource': 'editorTimeline',
        'localLayerId': element.id,
        'elementId': element.id,
        'layerId': layer.id,
        'sceneId': scene.id,
        'kind': layerKind,
        'layerKind': layerKind,
        'type': layerKind,
        'name': label,
        'label': label,
        if (isText) 'text': textValue,
        if (isText) 'content': textValue,
        'sourceKind': binding?.kind.name ??
            (isText
                ? MotionSourceKind.generatedText.name
                : MotionSourceKind.generatedShape.name),
        'sourceId': binding?.sourceId ?? element.id,
        'timelineStartMs': startMs,
        'timelineDurationMs': durationMs,
        'startMs': startMs,
        'durationMs': durationMs,
        'trackIndex': layer.zIndex,
        'x': positionX,
        'y': positionY,
        'width': width,
        'height': height,
        'scaleX': _scalar(element, MotionPropertyCatalog.scaleX, 1.0),
        'scaleY': _scalar(element, MotionPropertyCatalog.scaleY, 1.0),
        'rotationDeg':
            _scalar(element, MotionPropertyCatalog.rotationDegrees, 0),
        'opacity': _scalar(element, MotionPropertyCatalog.opacity, 1.0),
        if (isText)
          'fontSize': _scalar(element, MotionPropertyCatalog.fontSize, 16),
        if (isText)
          'lineHeight': _scalar(element, MotionPropertyCatalog.lineHeight, 1.0),
        if (isText)
          'letterSpacing':
              _scalar(element, MotionPropertyCatalog.letterSpacing, 0.0),
        if (!isText)
          'cornerRadius':
              _scalar(element, MotionPropertyCatalog.cornerRadius, 0),
        if (!isText)
          'shapeKind':
              element.shapeKind?.name ?? MotionShapeKind.rectangle.name,
        'color': colorHex,
        'colorArgb': colorArgb,
        'style': <String, Object?>{
          'fill': colorHex,
          'color': colorHex,
        },
        if (isBackgroundRole) 'mcp.backgroundRole': 'canvas',
        if (metadata['mcp.remoteLayerId']?.trim().isNotEmpty ?? false)
          'mcp.remoteLayerId': metadata['mcp.remoteLayerId']!,
        if (metadata['mcp.remoteLayerName']?.trim().isNotEmpty ?? false)
          'mcp.remoteLayerName': metadata['mcp.remoteLayerName']!,
        if (aliasSet.isNotEmpty) 'mcp.remoteLayerAliases': aliasSet.join(','),
        'canUseInMcp': true,
      },
    };
  }

  TimelineTimeRange _timingRangeForElement({
    required MotionSceneModel scene,
    required MotionElementModel element,
  }) {
    return TimelineTimeRange(
      start: scene.projectRange.start + element.localRange.start,
      endExclusive: scene.projectRange.start + element.localRange.endExclusive,
    );
  }

  String _labelForElement({
    required MotionElementModel element,
    required Map<String, String> metadata,
    required String textValue,
    required bool isBackgroundRole,
  }) {
    if (isBackgroundRole) {
      return 'Background';
    }
    final remoteName = metadata['mcp.remoteLayerName']?.trim();
    if (remoteName != null && remoteName.isNotEmpty) {
      return remoteName;
    }
    final bindingLabel = element.sourceBinding?.label?.trim();
    if (bindingLabel != null && bindingLabel.isNotEmpty) {
      return bindingLabel;
    }
    final elementName = element.name?.trim();
    if (elementName != null && elementName.isNotEmpty) {
      return elementName;
    }
    return textValue.isNotEmpty
        ? textValue
        : (element.kind == MotionElementKind.text ? 'Text' : 'Shape');
  }

  String _textValueForElement(MotionElementModel element) {
    final metadata = element.sourceBinding?.metadata;
    final textValue = metadata?['text']?.trim();
    if (textValue != null && textValue.isNotEmpty) {
      return textValue;
    }
    final bindingLabel = element.sourceBinding?.label?.trim();
    if (bindingLabel != null && bindingLabel.isNotEmpty) {
      return bindingLabel;
    }
    final elementName = element.name?.trim();
    if (elementName != null && elementName.isNotEmpty) {
      return elementName;
    }
    return 'Text';
  }

  double _textWidthForElement(MotionElementModel element) {
    final textValue = _textValueForElement(element);
    final fontSize = _scalar(element, MotionPropertyCatalog.fontSize, 16);
    return math.max(36.0, textValue.length * fontSize * 0.58);
  }

  double _textHeightForElement(MotionElementModel element) {
    final fontSize = _scalar(element, MotionPropertyCatalog.fontSize, 16);
    final lineHeight = _scalar(element, MotionPropertyCatalog.lineHeight, 1);
    return math.max(18.0, fontSize * lineHeight * 1.2);
  }

  double _scalar(
    MotionElementModel element,
    MotionPropertyDefinition definition,
    double fallback,
  ) {
    for (final property in element.properties) {
      if (property.definition.id != definition.id) {
        continue;
      }
      if (property.value.kind == MotionPropertyValueKind.scalar) {
        return property.value.rawValue as double;
      }
    }
    return fallback;
  }

  int _colorArgb(
    MotionElementModel element, {
    required int fallback,
  }) {
    for (final property in element.properties) {
      if (property.definition.id != 'visual.color') {
        continue;
      }
      if (property.value.kind == MotionPropertyValueKind.colorArgb) {
        return property.value.rawValue as int;
      }
    }
    return fallback;
  }

  String _hexColorFromArgb(int argb) {
    final rgb = (argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${rgb.toUpperCase()}';
  }
}
