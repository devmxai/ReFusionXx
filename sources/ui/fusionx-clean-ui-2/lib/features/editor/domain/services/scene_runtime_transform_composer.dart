import 'dart:math' as math;

import '../models/scene_runtime_node.dart';
import 'scene_runtime_component_tree.dart';
import 'scene_runtime_lifecycle_rules.dart';

class SceneRuntimeTransform {
  const SceneRuntimeTransform({
    required this.m00,
    required this.m01,
    required this.m02,
    required this.m10,
    required this.m11,
    required this.m12,
  });

  static const SceneRuntimeTransform identity = SceneRuntimeTransform(
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

  SceneRuntimeTransform multiply(SceneRuntimeTransform rhs) {
    return SceneRuntimeTransform(
      m00: (m00 * rhs.m00) + (m01 * rhs.m10),
      m01: (m00 * rhs.m01) + (m01 * rhs.m11),
      m02: (m00 * rhs.m02) + (m01 * rhs.m12) + m02,
      m10: (m10 * rhs.m00) + (m11 * rhs.m10),
      m11: (m10 * rhs.m01) + (m11 * rhs.m11),
      m12: (m10 * rhs.m02) + (m11 * rhs.m12) + m12,
    );
  }

  ({double x, double y}) apply(double x, double y) {
    return (
      x: (m00 * x) + (m01 * y) + m02,
      y: (m10 * x) + (m11 * y) + m12,
    );
  }

  static SceneRuntimeTransform fromNode(SceneRuntimeNode node) {
    final tx = _readDouble(node.metadata['x']) ?? 0.0;
    final ty = _readDouble(node.metadata['y']) ?? 0.0;
    final sx = _readDouble(node.metadata['scaleX']) ?? 1.0;
    final sy = _readDouble(node.metadata['scaleY']) ?? 1.0;
    final rotationDeg = _readDouble(node.metadata['rotationDeg']) ?? 0.0;
    final radians = rotationDeg * (math.pi / 180.0);
    final cosTheta = math.cos(radians);
    final sinTheta = math.sin(radians);
    return SceneRuntimeTransform(
      m00: cosTheta * sx,
      m01: -sinTheta * sy,
      m02: tx,
      m10: sinTheta * sx,
      m11: cosTheta * sy,
      m12: ty,
    );
  }

  static double? _readDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}

class SceneRuntimeRect {
  const SceneRuntimeRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
}

class SceneRuntimeCompositionRecord {
  const SceneRuntimeCompositionRecord({
    required this.nodeId,
    required this.worldTransform,
    required this.worldBounds,
    required this.effectiveOpacity,
    required this.active,
  });

  final String nodeId;
  final SceneRuntimeTransform worldTransform;
  final SceneRuntimeRect worldBounds;
  final double effectiveOpacity;
  final bool active;
}

class SceneRuntimeCompositionResult {
  const SceneRuntimeCompositionResult({
    required this.recordsByNodeId,
  });

  final Map<String, SceneRuntimeCompositionRecord> recordsByNodeId;
}

class SceneRuntimeTransformComposer {
  const SceneRuntimeTransformComposer({
    SceneRuntimeLifecycleRules? lifecycleRules,
  }) : _lifecycleRules = lifecycleRules ?? const SceneRuntimeLifecycleRules();

  final SceneRuntimeLifecycleRules _lifecycleRules;

  SceneRuntimeCompositionResult compose({
    required SceneRuntimeComponentTree tree,
    required int timelineTimeMs,
  }) {
    final output = <String, SceneRuntimeCompositionRecord>{};
    final ordered = tree.depthFirstNodes();
    for (final node in ordered) {
      final parentId = tree.parentOf[node.id];
      final parentRecord = parentId == null ? null : output[parentId];
      final localTransform = SceneRuntimeTransform.fromNode(node);
      final localOpacity = _readDouble(node.metadata['opacity']) ?? 1.0;
      final worldTransform = parentRecord == null
          ? localTransform
          : parentRecord.worldTransform.multiply(localTransform);
      final effectiveOpacity = (parentRecord?.effectiveOpacity ?? 1.0) *
          localOpacity.clamp(0.0, 1.0);
      final parentActive = parentRecord?.active ?? true;
      final active = _lifecycleRules.isActive(
        node: node,
        timelineTimeMs: timelineTimeMs,
        parentActive: parentActive,
      );
      final localBounds = _localBounds(node);
      final worldBounds = _toWorldBounds(
        localBounds: localBounds,
        transform: worldTransform,
      );
      output[node.id] = SceneRuntimeCompositionRecord(
        nodeId: node.id,
        worldTransform: worldTransform,
        worldBounds: worldBounds,
        effectiveOpacity: effectiveOpacity,
        active: active,
      );
    }
    return SceneRuntimeCompositionResult(recordsByNodeId: output);
  }

  SceneRuntimeRect _localBounds(SceneRuntimeNode node) {
    final width = _readDouble(node.metadata['width']) ?? 0.0;
    final height = _readDouble(node.metadata['height']) ?? 0.0;
    final left = _readDouble(node.metadata['localLeft']) ?? (-width / 2.0);
    final top = _readDouble(node.metadata['localTop']) ?? (-height / 2.0);
    return SceneRuntimeRect(
      left: left,
      top: top,
      width: width,
      height: height,
    );
  }

  SceneRuntimeRect _toWorldBounds({
    required SceneRuntimeRect localBounds,
    required SceneRuntimeTransform transform,
  }) {
    final p1 = transform.apply(localBounds.left, localBounds.top);
    final p2 = transform.apply(localBounds.right, localBounds.top);
    final p3 = transform.apply(localBounds.left, localBounds.bottom);
    final p4 = transform.apply(localBounds.right, localBounds.bottom);
    final xs = <double>[p1.x, p2.x, p3.x, p4.x]..sort();
    final ys = <double>[p1.y, p2.y, p3.y, p4.y]..sort();
    final left = xs.first;
    final top = ys.first;
    return SceneRuntimeRect(
      left: left,
      top: top,
      width: xs.last - left,
      height: ys.last - top,
    );
  }

  double? _readDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}
