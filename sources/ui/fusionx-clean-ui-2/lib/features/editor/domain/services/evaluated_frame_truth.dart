import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'scene_coordinate_system.dart';

@immutable
class EvaluatedTransform2D {
  const EvaluatedTransform2D({
    required this.m00,
    required this.m01,
    required this.m02,
    required this.m10,
    required this.m11,
    required this.m12,
  });

  static const EvaluatedTransform2D identity = EvaluatedTransform2D(
    m00: 1.0,
    m01: 0.0,
    m02: 0.0,
    m10: 0.0,
    m11: 1.0,
    m12: 0.0,
  );

  final double m00;
  final double m01;
  final double m02;
  final double m10;
  final double m11;
  final double m12;

  Map<String, Object?> toDiagnosticMap() {
    return <String, Object?>{
      'm00': m00,
      'm01': m01,
      'm02': m02,
      'm10': m10,
      'm11': m11,
      'm12': m12,
    };
  }
}

@immutable
class EvaluatedTextMetrics {
  const EvaluatedTextMetrics({
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.maxLines,
    required this.typewriterProgress,
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final int maxLines;
  final double typewriterProgress;

  Map<String, Object?> toDiagnosticMap() {
    return <String, Object?>{
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'maxLines': maxLines,
      'typewriterProgress': typewriterProgress,
    };
  }
}

@immutable
class EvaluatedSceneNode {
  const EvaluatedSceneNode({
    required this.nodeId,
    required this.nodeType,
    required this.localTransform,
    required this.worldTransform,
    required this.localBoundsCenter,
    required this.worldBoundsCenter,
    required this.viewportBounds,
    required this.effectiveOpacity,
    required this.active,
    required this.visible,
    required this.zOrder,
    this.sourceLayerId,
    this.sourceElementId,
    this.sourceComponentId,
    this.parentNodeId,
    this.slotId,
    this.slotBoundsCenter,
    this.contentBoundsCenter,
    this.textMetrics,
  });

  final String nodeId;
  final String? sourceLayerId;
  final String? sourceElementId;
  final String? sourceComponentId;
  final String? parentNodeId;
  final String nodeType;
  final String? slotId;
  final EvaluatedTransform2D localTransform;
  final EvaluatedTransform2D worldTransform;
  final SceneRectCenter localBoundsCenter;
  final SceneRectCenter worldBoundsCenter;
  final SceneViewportRect viewportBounds;
  final SceneRectCenter? slotBoundsCenter;
  final SceneRectCenter? contentBoundsCenter;
  final double effectiveOpacity;
  final bool active;
  final bool visible;
  final EvaluatedTextMetrics? textMetrics;
  final int zOrder;

  Map<String, Object?> toDiagnosticMap() {
    return <String, Object?>{
      'nodeId': nodeId,
      'sourceLayerId': sourceLayerId,
      'sourceElementId': sourceElementId,
      'sourceComponentId': sourceComponentId,
      'parentNodeId': parentNodeId,
      'nodeType': nodeType,
      'slotId': slotId,
      'localTransform': localTransform.toDiagnosticMap(),
      'worldTransform': worldTransform.toDiagnosticMap(),
      'localBoundsCenter': _rectCenterMap(localBoundsCenter),
      'worldBoundsCenter': _rectCenterMap(worldBoundsCenter),
      'viewportBounds': _viewportRectMap(viewportBounds),
      'slotBoundsCenter':
          slotBoundsCenter == null ? null : _rectCenterMap(slotBoundsCenter!),
      'contentBoundsCenter': contentBoundsCenter == null
          ? null
          : _rectCenterMap(contentBoundsCenter!),
      'effectiveOpacity': effectiveOpacity,
      'active': active,
      'visible': visible,
      'textMetrics': textMetrics?.toDiagnosticMap(),
      'zOrder': zOrder,
    };
  }

  static Map<String, Object?> _rectCenterMap(SceneRectCenter rect) {
    return <String, Object?>{
      'centerX': rect.centerX,
      'centerY': rect.centerY,
      'width': rect.width,
      'height': rect.height,
    };
  }

  static Map<String, Object?> _viewportRectMap(SceneViewportRect rect) {
    return <String, Object?>{
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
    };
  }
}

@immutable
class EvaluatedFrameTruth {
  EvaluatedFrameTruth({
    required this.coordinateSystem,
    required this.canvas,
    required this.globalTimeMs,
    required this.sceneId,
    required Map<String, EvaluatedSceneNode> nodesById,
    this.sourceMaps = const <String, Object?>{},
    this.diagnostics = const <String, Object?>{},
  })  : nodesById = UnmodifiableMapView<String, EvaluatedSceneNode>(
          SplayTreeMap<String, EvaluatedSceneNode>.from(nodesById),
        ),
        frameHash = _computeFrameHash(
          nodesById: nodesById,
          sceneId: sceneId,
          globalTimeMs: globalTimeMs,
          coordinateSystem: coordinateSystem,
        ),
        geometryHash = _computeGeometryHash(nodesById: nodesById);

  final SceneCoordinateSpace coordinateSystem;
  final SceneCanvasMetrics canvas;
  final int globalTimeMs;
  final String sceneId;
  final Map<String, EvaluatedSceneNode> nodesById;
  final Map<String, Object?> sourceMaps;
  final Map<String, Object?> diagnostics;
  final String frameHash;
  final String geometryHash;

  Map<String, Object?> toDiagnosticMap() {
    return <String, Object?>{
      'coordinateSystem': coordinateSystem.name,
      'canvas': <String, Object?>{
        'width': canvas.width,
        'height': canvas.height,
      },
      'globalTimeMs': globalTimeMs,
      'sceneId': sceneId,
      'frameHash': frameHash,
      'geometryHash': geometryHash,
      'nodeCount': nodesById.length,
      'nodes': nodesById.values
          .map((node) => node.toDiagnosticMap())
          .toList(growable: false),
      'sourceMaps': sourceMaps,
      'diagnostics': diagnostics,
    };
  }

  static String _computeFrameHash({
    required Map<String, EvaluatedSceneNode> nodesById,
    required String sceneId,
    required int globalTimeMs,
    required SceneCoordinateSpace coordinateSystem,
  }) {
    final keys = nodesById.keys.toList(growable: false)..sort();
    final buffer = StringBuffer()
      ..write('scene=')
      ..write(sceneId)
      ..write('|time=')
      ..write(globalTimeMs)
      ..write('|space=')
      ..write(coordinateSystem.name);
    for (final key in keys) {
      final node = nodesById[key]!;
      buffer
        ..write('|')
        ..write(node.nodeId)
        ..write(':')
        ..write(node.effectiveOpacity.toStringAsFixed(6))
        ..write(':')
        ..write(node.active ? '1' : '0')
        ..write(':')
        ..write(node.visible ? '1' : '0')
        ..write(':')
        ..write(node.viewportBounds.left.toStringAsFixed(4))
        ..write(',')
        ..write(node.viewportBounds.top.toStringAsFixed(4))
        ..write(',')
        ..write(node.viewportBounds.width.toStringAsFixed(4))
        ..write(',')
        ..write(node.viewportBounds.height.toStringAsFixed(4));
    }
    return _fnv1a64Hex(buffer.toString());
  }

  static String _computeGeometryHash({
    required Map<String, EvaluatedSceneNode> nodesById,
  }) {
    final keys = nodesById.keys.toList(growable: false)..sort();
    final buffer = StringBuffer();
    for (final key in keys) {
      final node = nodesById[key]!;
      buffer
        ..write(node.nodeId)
        ..write(':')
        ..write(node.worldBoundsCenter.centerX.toStringAsFixed(4))
        ..write(',')
        ..write(node.worldBoundsCenter.centerY.toStringAsFixed(4))
        ..write(',')
        ..write(node.worldBoundsCenter.width.toStringAsFixed(4))
        ..write(',')
        ..write(node.worldBoundsCenter.height.toStringAsFixed(4))
        ..write(';');
    }
    return _fnv1a64Hex(buffer.toString());
  }

  static String _fnv1a64Hex(String input) {
    const int offset = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    var hash = offset;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
